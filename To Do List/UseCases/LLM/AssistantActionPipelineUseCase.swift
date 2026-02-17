import Foundation

public final class AssistantActionPipelineUseCase {
    private let supportedSchemaVersion = 1
    private let undoWindowSeconds: TimeInterval = 60 * 30
    private let repository: AssistantActionRepositoryProtocol
    private let taskRepository: TaskDefinitionRepositoryProtocol

    public init(repository: AssistantActionRepositoryProtocol, taskRepository: TaskDefinitionRepositoryProtocol) {
        self.repository = repository
        self.taskRepository = taskRepository
    }

    public func propose(threadID: String, envelope: AssistantCommandEnvelope, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled else {
            completion(.failure(v2DisabledError(action: "propose")))
            return
        }
        guard envelope.schemaVersion == supportedSchemaVersion else {
            completion(.failure(NSError(
                domain: "AssistantActionPipelineUseCase",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported assistant schema version \(envelope.schemaVersion)"]
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

    public func confirm(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled else {
            completion(.failure(v2DisabledError(action: "confirm")))
            return
        }
        repository.fetchRun(id: runID) { result in
            switch result {
            case .success(let run):
                guard var run else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 404)))
                    return
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

    public func applyConfirmedRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled else {
            completion(.failure(v2DisabledError(action: "apply")))
            return
        }
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
                guard run.status == .confirmed else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 409, userInfo: [NSLocalizedDescriptionKey: "Run must be confirmed before apply"])))
                    return
                }
                let envelope = (run.proposalData).flatMap { try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: $0) }
                guard let envelope else {
                    completion(.failure(NSError(domain: "AssistantActionPipelineUseCase", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid proposal payload"])))
                    return
                }
                guard envelope.schemaVersion == self.supportedSchemaVersion else {
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

                self.executeTransaction(commands: envelope.commands) { execResult in
                    switch execResult {
                    case .success(let undoCommands):
                        var persistedEnvelope = envelope
                        persistedEnvelope.undoCommands = undoCommands
                        run.status = .applied
                        run.appliedAt = Date()
                        run.proposalData = try? JSONEncoder().encode(persistedEnvelope)
                        run.resultSummary = "Applied \(envelope.commands.count) commands transactionally"
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
                        run.status = .failed
                        run.resultSummary = error.localizedDescription
                        logError(
                            event: "assistant_apply_failed",
                            message: "Assistant action run apply failed",
                            fields: [
                                "run_id": id.uuidString,
                                "error": error.localizedDescription
                            ]
                        )
                        self.repository.updateRun(run) { _ in }
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func reject(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled else {
            completion(.failure(v2DisabledError(action: "reject")))
            return
        }
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

    public func undoAppliedRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        guard V2FeatureFlags.v2Enabled else {
            completion(.failure(v2DisabledError(action: "undo")))
            return
        }
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

                self.executeTransaction(commands: undoCommands) { undoResult in
                    switch undoResult {
                    case .success:
                        run.status = .confirmed
                        run.resultSummary = "Undo applied (\(undoCommands.count) commands)"
                        run.appliedAt = nil
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

    private func executeTransaction(
        commands: [AssistantCommand],
        completion: @escaping (Result<[AssistantCommand], Error>) -> Void
    ) {
        taskRepository.fetchAll { result in
            switch result {
            case .success(let tasks):
                var taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                var inverses: [AssistantCommand] = []
                for command in commands {
                    let applyResult = self.apply(command: command, taskMap: &taskMap)
                    switch applyResult {
                    case .success(let inverse):
                        inverses.insert(inverse, at: 0)
                    case .failure(let error):
                        self.rollback(commands: inverses) { _ in
                            completion(.failure(error))
                        }
                        return
                    }
                }

                completion(.success(inverses))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func rollback(commands: [AssistantCommand], completion: @escaping (Result<Void, Error>) -> Void) {
        taskRepository.fetchAll { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let tasks):
                var taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                for command in commands {
                    if case .failure(let error) = self.apply(command: command, taskMap: &taskMap) {
                        completion(.failure(error))
                        return
                    }
                }
                completion(.success(()))
            }
        }
    }

    private func apply(
        command: AssistantCommand,
        taskMap: inout [UUID: Task]
    ) -> Result<AssistantCommand, Error> {
        switch command {
        case .createTask(let projectID, let title):
            let task = Task(projectID: projectID, name: title, dueDate: nil, project: ProjectConstants.inboxProjectName)
            let semaphore = DispatchSemaphore(value: 0)
            var createdTask: Task?
            var taskError: Error?
            taskRepository.create(task) { result in
                switch result {
                case .success(let created):
                    createdTask = created
                case .failure(let error):
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            guard let createdTask else {
                let error = NSError(domain: "AssistantActionPipelineUseCase", code: 500, userInfo: [NSLocalizedDescriptionKey: "Task create returned no data"])
                return .failure(error)
            }
            taskMap[createdTask.id] = createdTask
            return .success(.deleteTask(taskID: createdTask.id))

        case let .restoreTask(taskID, projectID, title, dueDate, isComplete, dateCompleted):
            guard taskMap[taskID] == nil else {
                let error = NSError(
                    domain: "AssistantActionPipelineUseCase",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot restore task \(taskID) because it already exists"]
                )
                return .failure(error)
            }
            let task = Task(
                id: taskID,
                projectID: projectID,
                name: title,
                dueDate: dueDate,
                project: ProjectConstants.inboxProjectName,
                isComplete: isComplete,
                dateAdded: Date(),
                dateCompleted: dateCompleted
            )
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.create(task) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap[taskID] = task
            return .success(.deleteTask(taskID: taskID))

        case .deleteTask(let taskID):
            let previous = taskMap[taskID]
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.delete(id: taskID) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap.removeValue(forKey: taskID)
            if let previous {
                return .success(
                    .restoreTask(
                        taskID: previous.id,
                        projectID: previous.projectID,
                        title: previous.name,
                        dueDate: previous.dueDate,
                        isComplete: previous.isComplete,
                        dateCompleted: previous.dateCompleted
                    )
                )
            }
            return .success(.updateTask(taskID: taskID, title: nil, dueDate: nil))

        case .updateTask(let taskID, let title, let dueDate):
            guard var task = taskMap[taskID] else {
                let error = NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
                return .failure(error)
            }
            let inverse = AssistantCommand.updateTask(taskID: taskID, title: task.name, dueDate: task.dueDate)
            if let title {
                task.name = title
            }
            if let dueDate {
                task.dueDate = dueDate
            }
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.update(task) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap[taskID] = task
            return .success(inverse)

        case .setTaskCompletion(let taskID, let isComplete, let dateCompleted):
            guard var task = taskMap[taskID] else {
                let error = NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
                return .failure(error)
            }
            let inverse = AssistantCommand.setTaskCompletion(taskID: taskID, isComplete: task.isComplete, dateCompleted: task.dateCompleted)
            task.isComplete = isComplete
            task.dateCompleted = dateCompleted
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.update(task) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap[taskID] = task
            return .success(inverse)

        case .completeTask(let taskID):
            guard var task = taskMap[taskID] else {
                let error = NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
                return .failure(error)
            }
            let inverse = AssistantCommand.setTaskCompletion(taskID: taskID, isComplete: task.isComplete, dateCompleted: task.dateCompleted)
            task.isComplete = true
            task.dateCompleted = Date()
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.update(task) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap[taskID] = task
            return .success(inverse)

        case .moveTask(let taskID, let targetProjectID):
            guard var task = taskMap[taskID] else {
                let error = NSError(domain: "AssistantActionPipelineUseCase", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found: \(taskID)"])
                return .failure(error)
            }
            let inverse = AssistantCommand.moveTask(taskID: taskID, targetProjectID: task.projectID)
            task.projectID = targetProjectID
            let semaphore = DispatchSemaphore(value: 0)
            var taskError: Error?
            taskRepository.update(task) { result in
                if case .failure(let error) = result {
                    taskError = error
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + .seconds(10))
            if let taskError {
                return .failure(taskError)
            }
            taskMap[taskID] = task
            return .success(inverse)
        }
    }

    private func isAllowlisted(commands: [AssistantCommand]) -> Bool {
        for command in commands {
            switch command {
            case .createTask, .restoreTask, .deleteTask, .updateTask, .setTaskCompletion, .completeTask, .moveTask:
                continue
            }
        }
        return true
    }

    private func v2DisabledError(action: String) -> Error {
        NSError(
            domain: "AssistantActionPipelineUseCase",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "V2 assistant \(action) is disabled by feature flag"]
        )
    }
}
