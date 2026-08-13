import Foundation

/// Committing a reviewed capture into a canonical task, reversibly.
///
/// `InboxTriageMutation.planMutation` deliberately refuses `.commitCapture` and
/// `.moveToProject` with `requiresCaptureCommit` / `requiresTaskRepository`:
/// both need the task repository, and `PlanMutation` only speaks
/// `PlanningTaskMetadata`. Rather than widen `PlanMutation` — which would let
/// the planning ledger create tasks and blur which layer owns identity — this
/// coordinator performs the task-repository half and leaves the scheduling half
/// on the existing receipt path.
///
/// The ordering rule throughout: **never remove the capture until the task
/// exists.** A capture is the only copy of something the user typed once, often
/// from a lock screen, and losing it to a failed write is unrecoverable.

// MARK: - What the user reviewed

/// Mutable review state whose values are rendered by the Inbox review sheet.
///
/// Parsing happens once when this value is created. Every later edit changes
/// this value directly, and the commit request is derived from it without
/// consulting the raw capture again.
public struct InboxCaptureReviewDraft: Equatable, Sendable {
    public let captureID: UUID
    public var title: String
    public var dueDate: Date?
    public var isAllDay: Bool
    public var estimatedDuration: TimeInterval?
    public var repeatPattern: TaskRepeatPattern?
    public var priority: TaskPriorityConfig.Priority?
    public var projectName: String?
    public var tagNames: [String]
    public var contextName: String?

    public init(
        captureID: UUID,
        title: String,
        dueDate: Date? = nil,
        isAllDay: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        priority: TaskPriorityConfig.Priority? = nil,
        projectName: String? = nil,
        tagNames: [String] = [],
        contextName: String? = nil
    ) {
        self.captureID = captureID
        self.title = title
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.estimatedDuration = estimatedDuration
        self.repeatPattern = repeatPattern
        self.priority = priority
        self.projectName = projectName
        self.tagNames = tagNames
        self.contextName = contextName
    }

    public init(captureID: UUID, parsed: ParsedCapture, fallbackTitle: String) {
        let parsedTitle = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            captureID: captureID,
            title: parsedTitle.isEmpty ? fallbackTitle : parsedTitle,
            dueDate: parsed.dueDate,
            isAllDay: parsed.isAllDay,
            estimatedDuration: parsed.duration,
            repeatPattern: parsed.repeatPattern,
            priority: parsed.priority,
            projectName: parsed.projectName,
            tagNames: parsed.tags,
            contextName: parsed.context
        )
    }

    public var commitRequest: InboxCaptureCommitRequest {
        InboxCaptureCommitRequest(
            captureID: captureID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            isAllDay: dueDate == nil ? false : isAllDay,
            estimatedDuration: estimatedDuration,
            repeatPattern: repeatPattern,
            priority: priority,
            projectName: Self.trimmed(projectName),
            tagNames: Self.normalizedNames(tagNames),
            contextName: Self.trimmed(contextName)
        )
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let trimmed = trimmed(value) else { return nil }
            let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(key).inserted ? trimmed : nil
        }
    }
}

/// A commit request built from what the user actually saw and agreed to.
///
/// Carries names rather than IDs for project, tags and context because the
/// parser produces text and resolution needs the repository. Keeping the
/// unresolved form here means the review UI and the writer agree on exactly one
/// description of the user's decision.
public struct InboxCaptureCommitRequest: Equatable, Sendable {
    public let captureID: UUID
    public let title: String
    public let dueDate: Date?
    public let isAllDay: Bool
    public let estimatedDuration: TimeInterval?
    public let repeatPattern: TaskRepeatPattern?
    public let priority: TaskPriorityConfig.Priority?
    public let projectName: String?
    public let tagNames: [String]
    public let contextName: String?

    public init(
        captureID: UUID,
        title: String,
        dueDate: Date? = nil,
        isAllDay: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        priority: TaskPriorityConfig.Priority? = nil,
        projectName: String? = nil,
        tagNames: [String] = [],
        contextName: String? = nil
    ) {
        self.captureID = captureID
        self.title = title
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.estimatedDuration = estimatedDuration
        self.repeatPattern = repeatPattern
        self.priority = priority
        self.projectName = projectName
        self.tagNames = tagNames
        self.contextName = contextName
    }

    /// Built from a parse the user has seen and not corrected.
    ///
    /// Takes the `ParsedCapture` rather than re-parsing the raw text, so what is
    /// committed is exactly what the review chips displayed. Re-parsing here
    /// would reintroduce the silent-commit problem in a subtler form: the chips
    /// would show one proposal and the commit could compute another, because
    /// the parser resolves relative dates against a reference that has moved.
    public static func reviewed(
        captureID: UUID,
        parsed: ParsedCapture,
        fallbackTitle: String
    ) -> Self {
        InboxCaptureReviewDraft(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: fallbackTitle
        ).commitRequest
    }
}

public struct InboxMergeDestinationSnapshot: Equatable, Sendable {
    public let title: String
    public let dueDate: Date?
    public let isAllDay: Bool
    public let estimatedDuration: TimeInterval?
    public let repeatPattern: TaskRepeatPattern?
    public let priority: TaskPriorityConfig.Priority?
    public let projectName: String?
    public let tagNames: [String]
    public let contextName: String?

    public init(
        title: String,
        dueDate: Date? = nil,
        isAllDay: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        priority: TaskPriorityConfig.Priority? = nil,
        projectName: String? = nil,
        tagNames: [String] = [],
        contextName: String? = nil
    ) {
        self.title = title
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.estimatedDuration = estimatedDuration
        self.repeatPattern = repeatPattern
        self.priority = priority
        self.projectName = projectName
        self.tagNames = tagNames
        self.contextName = contextName
    }
}

/// Explicit decisions for metadata where both the reviewed capture and the
/// destination already contain different values.
public struct DuplicateMergeResolution: Equatable, Sendable {
    public enum Field: String, CaseIterable, Hashable, Sendable {
        case date
        case project
        case priority
        case recurrence
    }

    public enum Choice: String, CaseIterable, Sendable {
        case destination
        case reviewed
    }

    public var finalTitle: String
    public var choices: [Field: Choice]
    public var acknowledgedFields: Set<Field>

    public init(
        finalTitle: String,
        choices: [Field: Choice] = [:],
        acknowledgedFields: Set<Field> = []
    ) {
        self.finalTitle = finalTitle
        self.choices = choices
        self.acknowledgedFields = acknowledgedFields
    }

    public mutating func select(_ choice: Choice, for field: Field) {
        choices[field] = choice
        acknowledgedFields.insert(field)
    }

    public func conflicts(
        reviewed: InboxCaptureReviewDraft,
        destination: InboxMergeDestinationSnapshot
    ) -> Set<Field> {
        var result = Set<Field>()
        if let destinationDate = destination.dueDate,
           let reviewedDate = reviewed.dueDate,
           destinationDate != reviewedDate || destination.isAllDay != reviewed.isAllDay {
            result.insert(.date)
        }
        if let destinationProject = normalized(destination.projectName),
           let reviewedProject = normalized(reviewed.projectName),
           destinationProject != reviewedProject {
            result.insert(.project)
        }
        if let destinationPriority = destination.priority,
           destinationPriority != .none,
           let reviewedPriority = reviewed.priority,
           reviewedPriority != .none,
           destinationPriority != reviewedPriority {
            result.insert(.priority)
        }
        if let destinationRecurrence = destination.repeatPattern,
           let reviewedRecurrence = reviewed.repeatPattern,
           destinationRecurrence != reviewedRecurrence {
            result.insert(.recurrence)
        }
        return result
    }

    public func isComplete(
        reviewed: InboxCaptureReviewDraft,
        destination: InboxMergeDestinationSnapshot
    ) -> Bool {
        let titleIsValid = finalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let conflicts = conflicts(reviewed: reviewed, destination: destination)
        return titleIsValid &&
            conflicts.isSubset(of: Set(choices.keys)) &&
            conflicts.isSubset(of: acknowledgedFields)
    }

    public func commitRequest(
        reviewed: InboxCaptureReviewDraft,
        destination: InboxMergeDestinationSnapshot
    ) -> InboxCaptureCommitRequest? {
        guard isComplete(reviewed: reviewed, destination: destination) else { return nil }

        let dateChoice = choices[.date] ?? .destination
        let projectChoice = choices[.project] ?? .destination
        let priorityChoice = choices[.priority] ?? .destination
        let recurrenceChoice = choices[.recurrence] ?? .destination

        let dueDate = destination.dueDate == nil || dateChoice == .reviewed
            ? reviewed.dueDate
            : destination.dueDate
        let isAllDay = destination.dueDate == nil || dateChoice == .reviewed
            ? reviewed.isAllDay
            : destination.isAllDay
        let projectName = destination.projectName == nil || projectChoice == .reviewed
            ? reviewed.projectName
            : destination.projectName
        let destinationHasPriority = destination.priority.map { $0 != .none } ?? false
        let priority = destinationHasPriority == false || priorityChoice == .reviewed
            ? reviewed.priority
            : destination.priority
        let recurrence = destination.repeatPattern == nil || recurrenceChoice == .reviewed
            ? reviewed.repeatPattern
            : destination.repeatPattern

        return InboxCaptureReviewDraft(
            captureID: reviewed.captureID,
            title: finalTitle,
            dueDate: dueDate,
            isAllDay: isAllDay,
            estimatedDuration: destination.estimatedDuration ?? reviewed.estimatedDuration,
            repeatPattern: recurrence,
            priority: priority,
            projectName: projectName,
            tagNames: destination.tagNames + reviewed.tagNames,
            contextName: destination.contextName ?? reviewed.contextName
        ).commitRequest
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

// MARK: - The repository seam

/// The task-repository operations a commit needs.
///
/// Deliberately narrow. The coordinator's job is ordering and reversal, not
/// task construction, so this protocol exposes only what reversal requires and
/// leaves name-to-ID resolution to the adapter that has the repositories.
public protocol InboxTaskWriting: Sendable {
    /// Creates the task and returns its stable ID.
    func createTask(_ request: InboxCaptureCommitRequest) async throws -> UUID
    /// Removes a task created by `createTask`. Used only to unwind a commit.
    func deleteTask(id: UUID) async throws
    /// Moves a task between projects. `nil` means no project.
    func moveTask(id: UUID, toProject projectID: UUID?) async throws
    func task(id: UUID) async throws -> TaskDefinition?
    func mergeDestination(id: UUID) async throws -> InboxMergeDestinationSnapshot?
    func mergeTask(id: UUID, request: InboxCaptureCommitRequest) async throws -> TaskDefinition
    func restoreTask(_ snapshot: TaskDefinition) async throws
}

public extension InboxTaskWriting {
    func task(id: UUID) async throws -> TaskDefinition? { nil }
    func mergeDestination(id: UUID) async throws -> InboxMergeDestinationSnapshot? {
        guard let task = try await task(id: id) else { return nil }
        return InboxMergeDestinationSnapshot(
            title: task.title,
            dueDate: task.dueDate,
            isAllDay: task.isAllDay,
            estimatedDuration: task.estimatedDuration,
            repeatPattern: task.repeatPattern,
            priority: task.priority == .none ? nil : task.priority,
            projectName: task.projectName,
            contextName: task.context == .anywhere ? nil : task.context.rawValue
        )
    }
    func mergeTask(id: UUID, request: InboxCaptureCommitRequest) async throws -> TaskDefinition {
        throw InboxCommitFailure.mergeUnavailable
    }
    func restoreTask(_ snapshot: TaskDefinition) async throws {
        throw InboxCommitFailure.mergeUnavailable
    }
}

/// Reading and writing the App Group capture queue, injectable for tests.
public struct InboxCaptureQueueAccess: Sendable {
    public var read: @Sendable () -> [PendingCapture]
    public var remove: @Sendable (Set<UUID>) throws -> Void
    public var restore: @Sendable ([PendingCapture]) throws -> Void

    public init(
        read: @escaping @Sendable () -> [PendingCapture] = { PendingCaptureInbox.read() },
        remove: @escaping @Sendable (Set<UUID>) throws -> Void = {
            guard PendingCaptureInbox.remove(ids: $0) else {
                throw InboxCaptureQueueFailure.writeFailed
            }
        },
        restore: @escaping @Sendable ([PendingCapture]) throws -> Void = {
            guard PendingCaptureInbox.upsert($0) else {
                throw InboxCaptureQueueFailure.writeFailed
            }
        }
    ) {
        self.read = read
        self.remove = remove
        self.restore = restore
    }
}

public enum InboxCaptureQueueFailure: Error, Equatable, Sendable {
    case writeFailed
}

// MARK: - Coordinator

public enum InboxCommitFailure: Error, Equatable, Sendable {
    /// The capture is no longer in the queue — already committed, or discarded
    /// on another device. Surfaced rather than ignored so the caller does not
    /// create a duplicate task for something already filed.
    case captureNotFound(UUID)
    /// The task write failed. The capture is left in the queue.
    case taskWriteFailed(String)
    case mergeUnavailable
}

public enum InboxMergeReceipt: Equatable, Sendable {
    case created(taskID: UUID, captures: [PendingCapture])
    case updated(before: TaskDefinition, after: TaskDefinition, captures: [PendingCapture])
}

/// Performs the two triage decisions the planning ledger cannot express.
public struct InboxCommitCoordinator: Sendable {
    private let writer: any InboxTaskWriting
    private let queue: InboxCaptureQueueAccess

    public init(writer: any InboxTaskWriting, queue: InboxCaptureQueueAccess = InboxCaptureQueueAccess()) {
        self.writer = writer
        self.queue = queue
    }

    /// Creates the task, then clears the capture.
    ///
    /// Strictly in that order. Clearing first would be faster to write and would
    /// lose the user's text on any write failure — and a capture is frequently
    /// the only record of a thought. On failure the queue is untouched, so the
    /// item simply stays in the Inbox and can be reviewed again.
    @discardableResult
    public func commit(_ request: InboxCaptureCommitRequest) async throws -> InboxTriageMutation {
        guard queue.read().contains(where: { $0.id == request.captureID }) else {
            throw InboxCommitFailure.captureNotFound(request.captureID)
        }

        let taskID: UUID
        do {
            taskID = try await writer.createTask(request)
        } catch {
            throw InboxCommitFailure.taskWriteFailed(String(describing: error))
        }

        do {
            try queue.remove([request.captureID])
        } catch {
            // The canonical task and the queue row form one user-visible
            // transaction. If the queue cannot durably finalize, remove the
            // task we just created so retrying cannot create a duplicate.
            do {
                try await writer.deleteTask(id: taskID)
            } catch {
                throw InboxCommitFailure.taskWriteFailed(
                    "Queue finalization and task compensation both failed: \(error)"
                )
            }
            throw InboxCommitFailure.taskWriteFailed("Capture queue finalization failed")
        }
        return .commitCapture(captureID: request.captureID, createdTaskID: taskID)
    }

    /// Unwinds a commit: deletes the created task and puts the capture back.
    ///
    /// The restored capture keeps its original id, text, timestamp and source.
    /// Re-queuing it as a new capture would move it to the top of an
    /// age-ordered Inbox and make an undo look like a fresh capture, which is
    /// precisely the confusion Undo is supposed to prevent.
    public func undoCommit(
        _ mutation: InboxTriageMutation,
        restoring capture: PendingCapture
    ) async throws {
        guard case let .commitCapture(captureID, createdTaskID) = mutation else { return }
        guard captureID == capture.id else {
            throw InboxCommitFailure.captureNotFound(captureID)
        }
        do {
            try await writer.deleteTask(id: createdTaskID)
        } catch {
            throw InboxCommitFailure.taskWriteFailed(String(describing: error))
        }
        do {
            try queue.restore([capture])
        } catch {
            throw InboxCommitFailure.taskWriteFailed("Capture queue restoration failed")
        }
    }

    /// Resolves either pending-to-pending or pending-to-task duplicates. Queue
    /// rows are removed only after the canonical write succeeds.
    public func merge(
        _ request: InboxCaptureCommitRequest,
        with duplicate: InboxItem.Origin
    ) async throws -> InboxMergeReceipt {
        guard let capture = queue.read().first(where: { $0.id == request.captureID }) else {
            throw InboxCommitFailure.captureNotFound(request.captureID)
        }

        switch duplicate {
        case .pendingCapture(let duplicateCaptureID):
            guard let duplicateCapture = queue.read().first(where: { $0.id == duplicateCaptureID }) else {
                throw InboxCommitFailure.captureNotFound(duplicateCaptureID)
            }
            let taskID: UUID
            do {
                taskID = try await writer.createTask(request)
            } catch {
                throw InboxCommitFailure.taskWriteFailed(String(describing: error))
            }
            let captures = [capture, duplicateCapture]
            do {
                try queue.remove(Set(captures.map(\.id)))
            } catch {
                do {
                    try await writer.deleteTask(id: taskID)
                } catch {
                    throw InboxCommitFailure.taskWriteFailed(
                        "Queue finalization and task compensation both failed: \(error)"
                    )
                }
                throw InboxCommitFailure.taskWriteFailed("Capture queue finalization failed")
            }
            return .created(taskID: taskID, captures: captures)

        case .task(let taskID):
            guard let before = try await writer.task(id: taskID) else {
                throw InboxCommitFailure.mergeUnavailable
            }
            let after: TaskDefinition
            do {
                after = try await writer.mergeTask(id: taskID, request: request)
            } catch {
                throw InboxCommitFailure.taskWriteFailed(String(describing: error))
            }
            do {
                try queue.remove([capture.id])
            } catch {
                do {
                    try await writer.restoreTask(before)
                } catch {
                    throw InboxCommitFailure.taskWriteFailed(
                        "Queue finalization and task compensation both failed: \(error)"
                    )
                }
                throw InboxCommitFailure.taskWriteFailed("Capture queue finalization failed")
            }
            return .updated(before: before, after: after, captures: [capture])
        }
    }

    public func mergeDestination(for origin: InboxItem.Origin) async throws -> InboxMergeDestinationSnapshot {
        switch origin {
        case .pendingCapture(let captureID):
            guard let capture = queue.read().first(where: { $0.id == captureID }) else {
                throw InboxCommitFailure.captureNotFound(captureID)
            }
            let parsed = TaskCaptureParser.parse(capture.rawText, now: capture.createdAt)
            let draft = InboxCaptureReviewDraft(
                captureID: capture.id,
                parsed: parsed,
                fallbackTitle: capture.rawText
            )
            let request = draft.commitRequest
            return InboxMergeDestinationSnapshot(
                title: request.title,
                dueDate: request.dueDate,
                isAllDay: request.isAllDay,
                estimatedDuration: request.estimatedDuration,
                repeatPattern: request.repeatPattern,
                priority: request.priority,
                projectName: request.projectName,
                tagNames: request.tagNames,
                contextName: request.contextName
            )
        case .task(let taskID):
            guard let snapshot = try await writer.mergeDestination(id: taskID) else {
                throw InboxCommitFailure.mergeUnavailable
            }
            return snapshot
        }
    }

    public func undoMerge(_ receipt: InboxMergeReceipt) async throws {
        do {
            switch receipt {
            case let .created(taskID, captures):
                try await writer.deleteTask(id: taskID)
                try queue.restore(captures)
            case let .updated(before, _, captures):
                try await writer.restoreTask(before)
                try queue.restore(captures)
            }
        } catch {
            throw InboxCommitFailure.taskWriteFailed(String(describing: error))
        }
    }

    /// Moves a task between projects, returning the mutation that records it.
    ///
    /// `before` is supplied by the caller rather than read here, because the
    /// caller already holds the task and a second read could observe a value
    /// changed by another surface — which would make Undo restore a project the
    /// user never had.
    @discardableResult
    public func moveToProject(
        taskID: UUID,
        from before: UUID?,
        to after: UUID?
    ) async throws -> InboxTriageMutation {
        do {
            try await writer.moveTask(id: taskID, toProject: after)
        } catch {
            throw InboxCommitFailure.taskWriteFailed(String(describing: error))
        }
        return .moveToProject(taskID: taskID, before: before, after: after)
    }

    /// Applies the inverse of a `.moveToProject`.
    public func undoMoveToProject(_ mutation: InboxTriageMutation) async throws {
        guard case let .moveToProject(taskID, before, _) = mutation else { return }
        do {
            try await writer.moveTask(id: taskID, toProject: before)
        } catch {
            throw InboxCommitFailure.taskWriteFailed(String(describing: error))
        }
    }
}
