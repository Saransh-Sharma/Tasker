import Foundation

public final class AssistantActionPipelineUseCase {
    private struct ExecutionTrace: Codable {
        var runID: UUID?
        var commandCount: Int
        var startedAt: Date
        var finishedAt: Date?
        var durationMillis: Int?
        var status: String
        var rollbackVerified: Bool?
        var failureReason: String?
    }

    private struct TransactionResult {
        let undoCommands: [AssistantCommand]
        let traceData: Data?
    }

    private struct TransactionFailure: Error {
        let underlying: Error
        let rollbackVerified: Bool
        let traceData: Data?
    }

    private let supportedSchemaVersion = 3
    private let minimumSupportedSchemaVersion = 1
    private let undoWindowSeconds: TimeInterval = 60 * 30
    private let commandTimeoutSeconds: TimeInterval = 10
    private let runTimeoutSeconds: TimeInterval = 90
    private let repository: AssistantActionRepositoryProtocol
    private let taskRepository: TaskDefinitionRepositoryProtocol
    private let commandExecutor: AssistantCommandExecutor

    /// Initializes a new instance.
    public init(
        repository: AssistantActionRepositoryProtocol,
        taskRepository: TaskDefinitionRepositoryProtocol,
        commandExecutor: AssistantCommandExecutor = AssistantCommandExecutor()
    ) {
        self.repository = repository
        self.taskRepository = taskRepository
        self.commandExecutor = commandExecutor
    }

    /// Executes propose.
    public func propose(threadID: String, envelope: AssistantCommandEnvelope, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard envelope.schemaVersion >= minimumSupportedSchemaVersion && envelope.schemaVersion <= supportedSchemaVersion else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported assistant schema version \(envelope.schemaVersion)"]
            )))
            return
        }
        guard envelope.commands.isEmpty == false else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Assistant proposal must include at least one command"]
            )))
            return
        }
        logWarning(
            event: "assistant_propose_started",
            message: "Assistant proposal received",
            fields: [
                "thread_id": threadID,
                "command_count": String(envelope.commands.count)
            ]
        )
        let payload = try? JSONEncoder().encode(envelope)
        let run = AssistantActionRunDefinition(
            id: UUID(),
            threadID: threadID,
            proposalData: payload,
            status: .pending,
            confirmedAt: nil,
            appliedAt: nil,
            rejectedAt: nil,
            resultSummary: nil,
            createdAt: Date()
        )
        repository.createRun(run, completion: completion)
    }

    /// Executes confirm.
    public func confirm(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        repository.fetchRun(id: runID) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                switch run.status {
                case .applied, .undone, .rejected, .failed:
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Run is already \(run.status.rawValue)"]
                    )))
                    return
                default:
                    break
                }
                run.status = .confirmed
                run.confirmedAt = Date()
                logWarning(
                    event: "assistant_confirmed",
                    message: "Assistant action run confirmed",
                    fields: ["run_id": runID.uuidString]
                )
                self.repository.updateRun(run, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchRun.
    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        repository.fetchRun(id: id, completion: completion)
    }

    /// Executes applyConfirmedRun.
    public func applyConfirmedRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.assistantApplyEnabled else {
            completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 403, userInfo: [NSLocalizedDescriptionKey: "Assistant apply disabled by feature flag"])))
            return
        }
        repository.fetchRun(id: id) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                guard run.status != .applied else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 409, userInfo: [NSLocalizedDescriptionKey: "Run has already been applied"])))
                    return
                }
                guard run.status == .confirmed else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 409, userInfo: [NSLocalizedDescriptionKey: "Run must be confirmed before apply"])))
                    return
                }
                let envelope = (run.proposalData).flatMap { try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: $0) }
                guard let envelope else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid proposal payload"])))
                    return
                }
                guard envelope.schemaVersion >= self.minimumSupportedSchemaVersion && envelope.schemaVersion <= self.supportedSchemaVersion else {
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Unsupported assistant schema version \(envelope.schemaVersion)"]
                    )))
                    return
                }
                guard self.isAllowlisted(commands: envelope.commands) else {
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Proposal contains unsupported commands"]
                    )))
                    return
                }

                self.executeTransaction(runID: id, commands: envelope.commands) { execResult in
                    switch execResult {
                    case .success(let transaction):
                        var persistedEnvelope = envelope
                        persistedEnvelope.schemaVersion = self.supportedSchemaVersion
                        guard self.validateUndoPlan(forward: envelope.commands, inverse: transaction.undoCommands) else {
                            completion(.failure(NSError(
                                domain: "AssistantActionPipelineUseCase",
                                code: 422,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to generate deterministic undo plan"]
                            )))
                            return
                        }
                        persistedEnvelope.undoCommands = transaction.undoCommands
                        run.status = .applied
                        run.appliedAt = Date()
                        run.proposalData = try? JSONEncoder().encode(persistedEnvelope)
                        run.resultSummary = "Applied \(envelope.commands.count) commands transactionally"
                        run.executionTraceData = transaction.traceData
                        run.rollbackStatus = .notNeeded
                        run.rollbackVerifiedAt = nil
                        run.lastErrorCode = nil
                        logWarning(
                            event: "assistant_apply_completed",
                            message: "Assistant action run applied",
                            fields: [
                                "run_id": id.uuidString,
                                "command_count": String(envelope.commands.count)
                            ]
                        )
                        self.repository.updateRun(run, completion: completion)
                    case .failure(let error):
                        let transactionFailure = error as? TransactionFailure
                        run.status = .failed
                        run.resultSummary = transactionFailure?.underlying.localizedDescription ?? error.localizedDescription
                        run.executionTraceData = transactionFailure?.traceData
                        run.rollbackStatus = (transactionFailure?.rollbackVerified == true) ? .verified : .failed
                        run.rollbackVerifiedAt = Date()
                        run.lastErrorCode = "assistant_apply_failed"
                        logError(
                            event: "assistant_apply_failed",
                            message: "Assistant action run apply failed",
                            fields: [
                                "run_id": id.uuidString,
                                "error": transactionFailure?.underlying.localizedDescription ?? error.localizedDescription
                            ]
                        )
                        self.repository.updateRun(run) { _ in }
                        completion(.failure(transactionFailure?.underlying ?? error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes reject.
    public func reject(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        repository.fetchRun(id: runID) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                run.status = .rejected
                run.rejectedAt = Date()
                run.resultSummary = "Rejected by user"
                logWarning(
                    event: "assistant_rejected",
                    message: "Assistant action run rejected",
                    fields: ["run_id": runID.uuidString]
                )
                self.repository.updateRun(run, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes undoAppliedRun.
    public func undoAppliedRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.assistantUndoEnabled else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Assistant undo disabled by feature flag"]
            )))
            return
        }
        repository.fetchRun(id: id) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
                }
                guard run.status == .applied else {
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Only applied runs can be undone"]
                    )))
                    return
                }
                guard let appliedAt = run.appliedAt, Date().timeIntervalSince(appliedAt) <= self.undoWindowSeconds else {
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 410,
                        userInfo: [NSLocalizedDescriptionKey: "Undo window expired"]
                    )))
                    return
                }
                guard
                    let payload = run.proposalData,
                    let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: payload),
                    let undoCommands = envelope.undoCommands,
                    undoCommands.isEmpty == false
                else {
                    completion(.failure(NSError(
                        domain: "AssistantActionPipelineUseCase",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "No compensating undo commands available"]
                    )))
                    return
                }

                self.executeTransaction(runID: id, commands: undoCommands) { undoResult in
                    switch undoResult {
                    case .success:
                        run.status = .undone
                        run.resultSummary = "Undo applied (\(undoCommands.count) commands)"
                        run.rollbackStatus = .verified
                        run.rollbackVerifiedAt = Date()
                        run.lastErrorCode = nil
                        logWarning(
                            event: "assistant_undo_completed",
                            message: "Assistant action run undo completed",
                            fields: ["run_id": id.uuidString]
                        )
                        self.repository.updateRun(run, completion: completion)
                    case .failure(let error):
                        logError(
                            event: "assistant_undo_failed",
                            message: "Assistant action run undo failed",
                            fields: [
                                "run_id": id.uuidString,
                                "error": error.localizedDescription
                            ]
                        )
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    /// Executes executeTransaction.
    private func executeTransaction(
        runID: UUID,
        commands: [AssistantCommand],
        completion: @escaping (Result<TransactionResult, Error>) -> Void
    ) {
        _Concurrency.Task {
            let result = await self.executeTransactionResult(runID: runID, commands: commands)
            await MainActor.run {
                completion(result)
            }
        }
    }

    private func executeTransactionResult(
        runID: UUID,
        commands: [AssistantCommand]
    ) async -> Result<TransactionResult, Error> {
        do {
            let result = try await commandExecutor.enqueue {
                try await self.executeTransactionAsync(runID: runID, commands: commands)
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Executes executeTransactionAsync.
    private func executeTransactionAsync(
        runID: UUID,
        commands: [AssistantCommand]
    ) async throws -> TransactionResult {
        var trace = ExecutionTrace(
            runID: runID,
            commandCount: commands.count,
            startedAt: Date(),
            finishedAt: nil,
            durationMillis: nil,
            status: "running",
            rollbackVerified: nil,
            failureReason: nil
        )
        let baselineTasks = try await fetchAllTasksAsync()
        let baselineMap = Dictionary(uniqueKeysWithValues: baselineTasks.map { ($0.id, $0) })
        var taskMap = baselineMap
        var inverses: [AssistantCommand] = []
        var touchedTaskIDs = Set<UUID>()

        do {
            for command in commands {
                try _Concurrency.Task.checkCancellation()
                if Date().timeIntervalSince(trace.startedAt) > runTimeoutSeconds {
                    throw runTimedOutError()
                }
                let inverse = try await apply(command: command, taskMap: &taskMap, touchedTaskIDs: &touchedTaskIDs)
                inverses.insert(inverse, at: 0)
            }
            trace.finishedAt = Date()
            trace.durationMillis = Int((trace.finishedAt?.timeIntervalSince(trace.startedAt) ?? 0) * 1_000)
            trace.status = "success"
            return TransactionResult(undoCommands: inverses, traceData: encodeTrace(trace))
        } catch {
            let rollbackVerified = await rollbackAndVerify(
                commands: inverses,
                baselineMap: baselineMap,
                touchedTaskIDs: touchedTaskIDs
            )
            trace.finishedAt = Date()
            trace.durationMillis = Int((trace.finishedAt?.timeIntervalSince(trace.startedAt) ?? 0) * 1_000)
            trace.status = "failed"
            trace.rollbackVerified = rollbackVerified
            trace.failureReason = error.localizedDescription
            throw TransactionFailure(
                underlying: error,
                rollbackVerified: rollbackVerified,
                traceData: encodeTrace(trace)
            )
        }
    }

    /// Executes runTimedOutError.
    private func runTimedOutError() -> NSError {
        NSError(
            domain: "AssistantActionPipelineUseCase",
            code: 408,
            userInfo: [NSLocalizedDescriptionKey: "Assistant run timed out"]
        )
    }

    /// Executes rollbackAndVerify.
    private func rollbackAndVerify(
        commands: [AssistantCommand],
        baselineMap: [UUID: TaskDefinition],
        touchedTaskIDs: Set<UUID>
    ) async -> Bool {
        do {
            let current = try await fetchAllTasksAsync()
            var taskMap = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            var rollbackTouched = Set<UUID>()
            for command in commands {
                _ = try await apply(command: command, taskMap: &taskMap, touchedTaskIDs: &rollbackTouched)
            }
            let afterRollback = Dictionary(uniqueKeysWithValues: (try await fetchAllTasksAsync()).map { ($0.id, $0) })
            return touchedTaskIDs.allSatisfy { taskID in
                let baseline = baselineMap[taskID]
                let candidate = afterRollback[taskID]
                switch (baseline, candidate) {
                case (nil, nil):
                    return true
                case let (lhs?, rhs?):
                    return tasksEquivalent(lhs, rhs)
                default:
                    return false
                }
            }
        } catch {
            return false
        }
    }

    /// Executes tasksEquivalent.
    private func tasksEquivalent(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        AssistantTaskSnapshot(task: lhs) == AssistantTaskSnapshot(task: rhs)
    }

    /// Executes apply.
    private func apply(
        command: AssistantCommand,
        taskMap: inout [UUID: TaskDefinition],
        touchedTaskIDs: inout Set<UUID>
    ) async throws -> AssistantCommand {
        switch command {
        case .createTask(let projectID, let title):
            let task = TaskDefinition(
                projectID: projectID,
                projectName: ProjectConstants.inboxProjectName,
                title: title,
                dueDate: nil
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            return .deleteTask(taskID: createdTask.id)

        case let .restoreTask(taskID, projectID, title, dueDate, isComplete, dateCompleted):
            let snapshot = AssistantTaskSnapshot(task: TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: ProjectConstants.inboxProjectName,
                title: title,
                dueDate: dueDate,
                isComplete: isComplete,
                dateAdded: Date(),
                dateCompleted: dateCompleted
            ))
            return try await apply(
                command: .restoreTaskSnapshot(snapshot: snapshot),
                taskMap: &taskMap,
                touchedTaskIDs: &touchedTaskIDs
            )

        case .restoreTaskSnapshot(let snapshot):
            let task = snapshot.toTaskDefinition()
            if taskMap[task.id] == nil {
                let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                    try await self.createTaskAsync(task)
                }
                taskMap[task.id] = createdTask
                touchedTaskIDs.insert(task.id)
                return .deleteTask(taskID: task.id)
            }

            let previous = taskMap[task.id]
            let updatedTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[task.id] = updatedTask
            touchedTaskIDs.insert(task.id)
            if let previous {
                return .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: previous))
            }
            return .deleteTask(taskID: task.id)

        case .deleteTask(let taskID):
            let previous = taskMap[taskID]
            guard let previous else {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Delete command is not invertible without pre-state for task \(taskID)"]
                )
            }
            try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.deleteTaskAsync(id: taskID)
            }
            taskMap.removeValue(forKey: taskID)
            touchedTaskIDs.insert(taskID)
            return .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: previous))

        case .updateTask(let taskID, let title, let dueDate):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            if let title {
                task.title = title
            }
            if let dueDate {
                task.dueDate = dueDate
            }
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .setTaskCompletion(let taskID, let isComplete, let dateCompleted):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.isComplete = isComplete
            task.dateCompleted = dateCompleted
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .completeTask(let taskID):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.isComplete = true
            task.dateCompleted = Date()
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .moveTask(let taskID, let targetProjectID):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.projectID = targetProjectID
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .createScheduledTask(
            let projectID,
            let title,
            let scheduledStartAt,
            let scheduledEndAt,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let energy,
            let category,
            let context,
            let details,
            let tagIDs
        ):
            guard scheduledEndAt > scheduledStartAt else {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Scheduled task end must be after start"]
                )
            }
            let duration = estimatedDuration ?? scheduledEndAt.timeIntervalSince(scheduledStartAt)
            let task = TaskDefinition(
                projectID: projectID,
                projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : nil,
                lifeAreaID: lifeAreaID,
                title: title,
                details: details,
                priority: priority ?? .low,
                energy: energy ?? .medium,
                category: category ?? .general,
                context: context ?? .anywhere,
                dueDate: scheduledStartAt,
                scheduledStartAt: scheduledStartAt,
                scheduledEndAt: scheduledEndAt,
                tagIDs: tagIDs,
                estimatedDuration: duration,
                planningBucket: .thisWeek
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            return .deleteTask(taskID: createdTask.id)

        case .createInboxTask(
            let projectID,
            let title,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let category,
            let details,
            let tagIDs
        ):
            let task = TaskDefinition(
                projectID: projectID,
                projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : nil,
                lifeAreaID: lifeAreaID,
                title: title,
                details: details,
                priority: priority ?? .low,
                category: category ?? .general,
                dueDate: nil,
                tagIDs: tagIDs,
                estimatedDuration: estimatedDuration,
                planningBucket: .thisWeek
            )
            let createdTask = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.createTaskAsync(task)
            }
            taskMap[createdTask.id] = createdTask
            touchedTaskIDs.insert(createdTask.id)
            return .deleteTask(taskID: createdTask.id)

        case .updateTaskSchedule(let taskID, let scheduledStartAt, let scheduledEndAt, let estimatedDuration, let dueDate):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            if let scheduledStartAt, let scheduledEndAt, scheduledEndAt <= scheduledStartAt {
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "Scheduled task end must be after start"]
                )
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.scheduledStartAt = scheduledStartAt
            task.scheduledEndAt = scheduledEndAt
            task.estimatedDuration = estimatedDuration ?? scheduledEndAt.flatMap { end in
                scheduledStartAt.map { end.timeIntervalSince($0) }
            } ?? task.estimatedDuration
            task.dueDate = dueDate ?? scheduledStartAt ?? task.dueDate
            task.isAllDay = false
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .updateTaskFields(
            let taskID,
            let title,
            let details,
            let priority,
            let energy,
            let category,
            let context,
            let lifeAreaID,
            let tagIDs
        ):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            if let title { task.title = title }
            if let details { task.details = details }
            if let priority { task.priority = priority }
            if let energy { task.energy = energy }
            if let category { task.category = category }
            if let context { task.context = context }
            if let lifeAreaID { task.lifeAreaID = lifeAreaID }
            if let tagIDs { task.tagIDs = tagIDs }
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .deferTask(let taskID, let targetDate, _):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.dueDate = targetDate
            task.scheduledStartAt = nil
            task.scheduledEndAt = nil
            task.isAllDay = true
            task.deferredCount = max(0, task.deferredCount) + 1
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse

        case .dropTaskFromToday(let taskID, let destination, _):
            guard var task = taskMap[taskID] else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
            }
            let inverse = AssistantCommand.restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: task))
            task.dueDate = nil
            task.scheduledStartAt = nil
            task.scheduledEndAt = nil
            task.isAllDay = false
            switch destination {
            case .inbox:
                task.projectID = ProjectConstants.inboxProjectID
                task.projectName = ProjectConstants.inboxProjectName
            case .later:
                task.planningBucket = .later
            case .someday:
                task.planningBucket = .someday
            }
            task.deferredCount = max(0, task.deferredCount) + 1
            task.replanCount = max(0, task.replanCount) + 1
            task.updatedAt = Date()
            let updated = try await withTimeout(seconds: commandTimeoutSeconds) {
                try await self.updateTaskAsync(task)
            }
            taskMap[taskID] = updated
            touchedTaskIDs.insert(taskID)
            return inverse
        }
    }

    /// Executes validateUndoPlan.
    private func validateUndoPlan(forward: [AssistantCommand], inverse: [AssistantCommand]) -> Bool {
        guard inverse.isEmpty == false, inverse.count == forward.count else {
            return false
        }
        return isAllowlisted(commands: inverse)
    }

    /// Executes encodeTrace.
    private func encodeTrace(_ trace: ExecutionTrace) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(trace)
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await _Concurrency.Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "Assistant command timed out"]
                )
            }
            let first = try await group.next()
            group.cancelAll()
            guard let first else {
                throw NSError(domain: "AssistantActionPipelineUseCase", code: 500)
            }
            return first
        }
    }

    /// Executes fetchAllTasksAsync.
    private func fetchAllTasksAsync() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes createTaskAsync.
    private func createTaskAsync(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.create(task) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes updateTaskAsync.
    private func updateTaskAsync(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.update(task) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes deleteTaskAsync.
    private func deleteTaskAsync(id: UUID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            taskRepository.delete(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Executes isAllowlisted.
    private func isAllowlisted(commands: [AssistantCommand]) -> Bool {
        for command in commands {
            switch command {
            case .createTask,
                 .restoreTask,
                 .restoreTaskSnapshot,
                 .deleteTask,
                 .updateTask,
                 .setTaskCompletion,
                 .completeTask,
                 .moveTask,
                 .createScheduledTask,
                 .createInboxTask,
                 .updateTaskSchedule,
                 .updateTaskFields,
                 .deferTask,
                 .dropTaskFromToday:
                continue
            }
        }
        return true
    }

}
