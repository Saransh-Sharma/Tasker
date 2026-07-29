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
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return InboxCaptureCommitRequest(
            captureID: captureID,
            title: title.isEmpty ? fallbackTitle : title,
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
    func mergeTask(id: UUID, request: InboxCaptureCommitRequest) async throws -> TaskDefinition
    func restoreTask(_ snapshot: TaskDefinition) async throws
}

public extension InboxTaskWriting {
    func task(id: UUID) async throws -> TaskDefinition? { nil }
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
    public var remove: @Sendable (Set<UUID>) -> Void
    public var restore: @Sendable (PendingCapture) -> Void

    public init(
        read: @escaping @Sendable () -> [PendingCapture] = { PendingCaptureInbox.read() },
        remove: @escaping @Sendable (Set<UUID>) -> Void = { PendingCaptureInbox.remove(ids: $0) },
        restore: @escaping @Sendable (PendingCapture) -> Void = { PendingCaptureInbox.append($0) }
    ) {
        self.read = read
        self.remove = remove
        self.restore = restore
    }
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

        queue.remove([request.captureID])
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
        queue.restore(capture)
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
            queue.remove(Set(captures.map(\.id)))
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
            queue.remove([capture.id])
            return .updated(before: before, after: after, captures: [capture])
        }
    }

    public func undoMerge(_ receipt: InboxMergeReceipt) async throws {
        do {
            switch receipt {
            case let .created(taskID, captures):
                try await writer.deleteTask(id: taskID)
                captures.forEach(queue.restore)
            case let .updated(before, _, captures):
                try await writer.restoreTask(before)
                captures.forEach(queue.restore)
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
