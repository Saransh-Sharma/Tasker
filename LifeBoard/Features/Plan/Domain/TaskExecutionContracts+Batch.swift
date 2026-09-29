import Foundation

// MARK: - Atomic task batches

public enum TaskBatchMutation: Equatable, Sendable {
    case schedule(planningDay: PlanningDay, startAt: Date?, endAt: Date?)
    case addTags(Set<UUID>)
    case move(projectID: UUID, projectName: String?, sectionID: UUID?)
    case deferTo(PlanningDay)
    case setCompletion(Bool)
    case archive
    case delete
}

public struct TaskBatchMutationRequest: Equatable, Sendable {
    public let taskIDs: Set<UUID>
    public let mutation: TaskBatchMutation
    public let source: String

    public init(
        taskIDs: Set<UUID>,
        mutation: TaskBatchMutation,
        source: String = "task.batch"
    ) {
        self.taskIDs = taskIDs
        self.mutation = mutation
        self.source = source
    }
}

public struct TaskBatchSnapshot: Equatable, Sendable {
    public let task: TaskDefinition
    public let planning: PlanningTaskMetadata

    public init(task: TaskDefinition, planning: PlanningTaskMetadata) {
        self.task = task
        self.planning = planning
    }
}

public struct TaskBatchReceipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let request: TaskBatchMutationRequest
    public let before: [TaskBatchSnapshot]
    public let after: [TaskBatchSnapshot]
    public let directlyUpdatedTaskIDs: Set<UUID>
    public let planningReceiptID: UUID?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        request: TaskBatchMutationRequest,
        before: [TaskBatchSnapshot],
        after: [TaskBatchSnapshot],
        directlyUpdatedTaskIDs: Set<UUID>,
        planningReceiptID: UUID?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.request = request
        self.before = before
        self.after = after
        self.directlyUpdatedTaskIDs = directlyUpdatedTaskIDs
        self.planningReceiptID = planningReceiptID
        self.createdAt = createdAt
    }
}

public enum TaskBatchMutationError: Error, Equatable, Sendable {
    case emptySelection
    case missingTasks([UUID])
    case invalidSchedule
    case applyFailed(String)
    case rollbackFailed(original: String, rollback: String)
}

/// Coordinates definition/link and planning writes as one reversible action.
///
/// Repository protocols do not expose a cross-store transaction. This actor
/// therefore snapshots every member, writes in stable-ID order, and
/// compensates already-applied members in reverse order before reporting any
/// partial failure.
public actor TaskBatchMutationCoordinator {
    private let tasks: any TaskDefinitionRepositoryProtocol
    private let planning: any PlanningRepository & PlanningMutationRepository
    private let tagLinks: (any TaskTagLinkRepositoryProtocol)?

    public init(
        tasks: any TaskDefinitionRepositoryProtocol,
        planning: any PlanningRepository & PlanningMutationRepository,
        tagLinks: (any TaskTagLinkRepositoryProtocol)? = nil
    ) {
        self.tasks = tasks
        self.planning = planning
        self.tagLinks = tagLinks
    }

    public func apply(_ request: TaskBatchMutationRequest) async throws -> TaskBatchReceipt {
        guard request.taskIDs.isEmpty == false else {
            throw TaskBatchMutationError.emptySelection
        }

        let orderedIDs = request.taskIDs.sorted { $0.uuidString < $1.uuidString }
        async let allTasksValue = fetchAllTasks()
        async let metadataValue = planning.fetchTaskMetadata(taskIDs: request.taskIDs)
        let allTasks = try await allTasksValue
        let metadata = try await metadataValue
        let taskByID = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })
        let metadataByID = Dictionary(uniqueKeysWithValues: metadata.map { ($0.taskID, $0) })
        let missing = orderedIDs.filter { taskByID[$0] == nil }
        guard missing.isEmpty else { throw TaskBatchMutationError.missingTasks(missing) }

        let before = orderedIDs.map { id in
            TaskBatchSnapshot(
                task: taskByID[id]!,
                planning: metadataByID[id] ?? PlanningTaskMetadata(taskID: id)
            )
        }
        let after = try before.map { try projected($0, through: request.mutation) }
        let directlyUpdatedIDs = Set(zip(before, after).compactMap { before, after in
            directlyUpdatesTaskDefinition(request.mutation) && before.task != after.task
                ? before.task.id
                : nil
        })

        var appliedDefinitions: [TaskBatchSnapshot] = []
        do {
            for snapshot in after where directlyUpdatedIDs.contains(snapshot.task.id) {
                try await updateTask(snapshot.task)
                // Record the definition write before applying relationship
                // sidecars so a link failure compensates the row as well.
                appliedDefinitions.append(snapshot)
                if case .addTags = request.mutation {
                    try await replaceTagLinks(for: snapshot.task)
                }
            }
        } catch {
            try await rollbackDefinitions(
                appliedDefinitions,
                to: before,
                operation: request.mutation,
                originalError: error
            )
            throw TaskBatchMutationError.applyFailed(String(describing: error))
        }

        let planningMutations = zip(before, after).compactMap {
            planningMutation(before: $0.0, after: $0.1, operation: request.mutation)
        }
        var planningReceiptID: UUID?
        if planningMutations.isEmpty == false {
            do {
                let receipt = try await planning.prepare(
                    .batch(planningMutations),
                    source: request.source,
                    summary: summary(for: request.mutation, count: before.count)
                )
                try await planning.apply(receiptID: receipt.id)
                planningReceiptID = receipt.id
            } catch {
                try await rollbackDefinitions(
                    appliedDefinitions,
                    to: before,
                    operation: request.mutation,
                    originalError: error
                )
                throw TaskBatchMutationError.applyFailed(String(describing: error))
            }
        }

        return TaskBatchReceipt(
            request: request,
            before: before,
            after: after,
            directlyUpdatedTaskIDs: directlyUpdatedIDs,
            planningReceiptID: planningReceiptID
        )
    }

    public func undo(_ receipt: TaskBatchReceipt) async throws {
        var restored: [TaskBatchSnapshot] = []
        do {
            // Planning unwinds first so the definition restore below has the
            // last word on the row. `.setTaskCompletion` re-stamps `updatedAt`
            // and `dateCompleted` with `Date()` because the mutation only
            // carries booleans — it cannot know the prior timestamps, and it
            // cannot be taught them without changing a payload that is already
            // JSON-encoded into persisted receipts. Restoring the snapshot
            // afterwards makes Undo a true inverse without touching that
            // format.
            if let planningReceiptID = receipt.planningReceiptID {
                try await planning.undo(receiptID: planningReceiptID)
            }
            // Any task row the batch changed is restored, not just the ones
            // written through the definition path: `.setCompletion` reaches the
            // row solely through planning, so gating on `directlyUpdatedTaskIDs`
            // left its `updatedAt` bumped to now while `.schedule` and `.move`
            // restored theirs exactly.
            let afterByID = Dictionary(
                uniqueKeysWithValues: receipt.after.map { ($0.task.id, $0.task) }
            )
            for snapshot in receipt.before.reversed()
            where afterByID[snapshot.task.id] != snapshot.task {
                try await updateTask(snapshot.task)
                if case .addTags = receipt.request.mutation {
                    try await replaceTagLinks(for: snapshot.task)
                }
                restored.append(snapshot)
            }
        } catch {
            // Put definition rows back into their post-batch state if planning
            // Undo failed, keeping the UI-visible batch coherent.
            let afterByID = Dictionary(
                uniqueKeysWithValues: receipt.after.map { ($0.task.id, $0) }
            )
            var compensationFailure: Error?
            for snapshot in restored {
                guard let after = afterByID[snapshot.task.id] else { continue }
                do {
                    try await updateTask(after.task)
                    if case .addTags = receipt.request.mutation {
                        try await replaceTagLinks(for: after.task)
                    }
                } catch {
                    compensationFailure = error
                }
            }
            if let compensationFailure {
                throw TaskBatchMutationError.rollbackFailed(
                    original: String(describing: error),
                    rollback: String(describing: compensationFailure)
                )
            }
            throw TaskBatchMutationError.applyFailed(String(describing: error))
        }
    }

    private func projected(
        _ snapshot: TaskBatchSnapshot,
        through mutation: TaskBatchMutation
    ) throws -> TaskBatchSnapshot {
        var task = snapshot.task
        var planning = snapshot.planning
        let now = Date()

        switch mutation {
        case let .schedule(planningDay, startAt, endAt):
            if let startAt, let endAt, endAt <= startAt {
                throw TaskBatchMutationError.invalidSchedule
            }
            task.scheduledStartAt = startAt
            task.scheduledEndAt = endAt
            task.isAllDay = startAt == nil
            planning.planningDay = planningDay
            planning.unscheduledDisposition = .inbox
            planning.availability = .actionable
            planning.resumeDate = nil
        case let .addTags(tagIDs):
            task.tagIDs = Array(Set(task.tagIDs).union(tagIDs))
                .sorted { $0.uuidString < $1.uuidString }
        case let .move(projectID, projectName, sectionID):
            task.projectID = projectID
            task.projectName = projectName
            task.sectionID = sectionID
        case let .deferTo(day):
            planning.planningDay = day
            planning.startDay = day
            planning.unscheduledDisposition = .inbox
            planning.availability = .actionable
            planning.resumeDate = day.startDate()
        case let .setCompletion(isComplete):
            task.isComplete = isComplete
            task.dateCompleted = isComplete ? now : nil
        case .archive:
            planning.planningDay = nil
            planning.unscheduledDisposition = .archived
        case .delete:
            planning.planningDay = nil
            planning.unscheduledDisposition = .deleted
        }

        task.updatedAt = now
        planning.updatedAt = now
        return TaskBatchSnapshot(task: task, planning: planning)
    }

    private func planningMutation(
        before: TaskBatchSnapshot,
        after: TaskBatchSnapshot,
        operation: TaskBatchMutation
    ) -> PlanMutation? {
        switch operation {
        case .setCompletion(let value):
            guard before.task.isComplete != value else { return nil }
            return .setTaskCompletion(
                taskID: before.task.id,
                before: before.task.isComplete,
                after: value
            )
        default:
            guard before.planning != after.planning else { return nil }
            return .saveTaskMetadata(before: before.planning, after: after.planning)
        }
    }

    private func directlyUpdatesTaskDefinition(_ operation: TaskBatchMutation) -> Bool {
        switch operation {
        case .schedule, .addTags, .move: true
        case .deferTo, .setCompletion, .archive, .delete: false
        }
    }

    private func summary(for mutation: TaskBatchMutation, count: Int) -> String {
        let action: String = switch mutation {
        case .schedule: String(localized: "Scheduled")
        case .addTags: String(localized: "Tagged")
        case .move: String(localized: "Moved")
        case .deferTo: String(localized: "Rescheduled")
        case .setCompletion(let complete): complete ? String(localized: "Completed") : String(localized: "Reopened")
        case .archive: String(localized: "Archived")
        case .delete: String(localized: "Deleted")
        }
        return count == 1 ? String(localized: "\(action) 1 task") : String(localized: "\(action) \(count) tasks")
    }

    private func fetchAllTasks() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            tasks.fetchAll { continuation.resume(with: $0) }
        }
    }

    private func updateTask(_ task: TaskDefinition) async throws {
        _ = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<TaskDefinition, any Error>) in
            tasks.update(task) { continuation.resume(with: $0) }
        }
    }

    private func replaceTagLinks(for task: TaskDefinition) async throws {
        guard let tagLinks else { return }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            tagLinks.replaceTagLinks(taskID: task.id, tagIDs: task.tagIDs) {
                continuation.resume(with: $0)
            }
        }
    }

    private func rollbackDefinitions(
        _ applied: [TaskBatchSnapshot],
        to before: [TaskBatchSnapshot],
        operation: TaskBatchMutation,
        originalError: Error
    ) async throws {
        guard applied.isEmpty == false else { return }
        let beforeByID = Dictionary(uniqueKeysWithValues: before.map { ($0.task.id, $0) })
        var rollbackFailure: Error?
        for appliedSnapshot in applied.reversed() {
            guard let snapshot = beforeByID[appliedSnapshot.task.id] else { continue }
            do {
                try await updateTask(snapshot.task)
                if case .addTags = operation {
                    try await replaceTagLinks(for: snapshot.task)
                }
            } catch {
                rollbackFailure = error
            }
        }
        if let rollbackFailure {
            throw TaskBatchMutationError.rollbackFailed(
                original: String(describing: originalError),
                rollback: String(describing: rollbackFailure)
            )
        }
    }
}
