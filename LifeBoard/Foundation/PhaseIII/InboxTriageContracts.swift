import Foundation

/// Reading and triaging the Inbox.
///
/// Deliberately *not* a new store. The Inbox is a view over two things that
/// already exist — canonical tasks carrying `UnscheduledDisposition.inbox` in
/// `PlanningTaskMetadata`, and out-of-process `PendingCapture` rows waiting in
/// the App Group queue. A second task database would immediately be able to
/// disagree with the first about what the user still owes themselves, which is
/// the one thing an inbox must never do.
///
/// Lives beside `PlanningCoreModels` rather than in `LifeOSFoundationContracts`
/// only because that file is already 2,600 lines; every type here composes with
/// the planning contracts rather than paralleling them.

// MARK: - Query

public struct LifeBoardInboxQuery: Equatable, Sendable {
    /// What the user is looking at, not how it is stored.
    public enum Scope: String, CaseIterable, Sendable {
        /// Untriaged work: the actual Inbox.
        case untriaged
        /// Deliberately deferred, reviewed on purpose rather than nagged about.
        case someday
        /// Kept for lookup, never scheduled.
        case reference
    }

    public var scope: Scope
    /// Paginated because a neglected inbox is exactly where an unbounded fetch
    /// becomes the slowest screen in the app.
    public var limit: Int
    public var offset: Int

    public init(scope: Scope = .untriaged, limit: Int = 50, offset: Int = 0) {
        self.scope = scope
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }

    /// The dispositions a scope matches. `archived` and `deleted` are absent by
    /// construction: neither is untriaged work, and surfacing a tombstone in the
    /// Inbox would invite the user to "triage" something already gone.
    public var matchingDispositions: Set<UnscheduledDisposition> {
        switch scope {
        case .untriaged: return [.inbox]
        case .someday: return [.someday]
        case .reference: return [.reference]
        }
    }
}

/// One row in the Inbox, from either origin.
public struct InboxItem: Identifiable, Equatable, Sendable {
    /// Which side of the funnel this came from.
    ///
    /// Kept explicit rather than normalized away, because the two have genuinely
    /// different affordances: a canonical task can be scheduled immediately,
    /// while a pending capture has not been parsed or committed yet and may
    /// still turn out to be a duplicate.
    public enum Origin: Equatable, Sendable {
        case task(UUID)
        case pendingCapture(UUID)
    }

    public let id: UUID
    public let origin: Origin
    public let title: String
    public let capturedAt: Date
    /// Free-text origin label from `PendingCapture.source` ("widget", "control",
    /// "share-extension"), or nil for work that started inside the app.
    public let captureSource: String?
    /// Parsed metadata awaiting confirmation. Never applied silently — the plan's
    /// rule is that nothing uncertain commits without review.
    public let proposedDueDate: Date?

    public init(
        id: UUID,
        origin: Origin,
        title: String,
        capturedAt: Date,
        captureSource: String? = nil,
        proposedDueDate: Date? = nil
    ) {
        self.id = id
        self.origin = origin
        self.title = title
        self.capturedAt = capturedAt
        self.captureSource = captureSource
        self.proposedDueDate = proposedDueDate
    }

    /// A pending capture has not been committed to the canonical store yet, so
    /// it cannot be scheduled until it is.
    public var requiresCommitBeforeScheduling: Bool {
        if case .pendingCapture = origin { return true }
        return false
    }
}

// MARK: - Triage

/// A reversible triage decision.
///
/// Every case carries the *previous* disposition so the mutation can be undone
/// exactly, rather than being undone into a guessed default. This mirrors how
/// `PlanMutation` already pairs before/after, and it is what lets triage produce
/// a real `LifeBoardActionReceipt` instead of a one-way trip.
public enum InboxTriageMutation: Equatable, Sendable {
    case schedule(taskID: UUID, before: PlanningDay?, after: PlanningDay)
    /// `after` is optional because "no project" is a destination a user can
    /// choose *and* the state an Undo must be able to restore. With a
    /// non-optional `after`, inverting a move for a task that had no project
    /// was inexpressible, and the old code returned
    /// `.moveToProject(before: after, after: after)` — a no-op that left the
    /// task in the project it was supposed to be pulled out of.
    case moveToProject(taskID: UUID, before: UUID?, after: UUID?)
    case setDisposition(taskID: UUID, before: UnscheduledDisposition, after: UnscheduledDisposition)
    /// Committing a pending capture into a canonical task. Its inverse removes
    /// the created task and restores the queued capture, so an accidental
    /// commit is recoverable rather than merely deletable.
    case commitCapture(captureID: UUID, createdTaskID: UUID)
    /// Applied in order; inverted in reverse order.
    indirect case batch([InboxTriageMutation])

    public var inverse: InboxTriageMutation {
        switch self {
        case let .schedule(taskID, before, after):
            // Inverting to a nil planning day is meaningful: it returns the task
            // to unscheduled rather than pinning it to today.
            guard let before else {
                return .setDisposition(taskID: taskID, before: .inbox, after: .inbox)
            }
            return .schedule(taskID: taskID, before: after, after: before)
        case let .moveToProject(taskID, before, after):
            return .moveToProject(taskID: taskID, before: after, after: before)
        case let .setDisposition(taskID, before, after):
            return .setDisposition(taskID: taskID, before: after, after: before)
        case let .commitCapture(captureID, createdTaskID):
            return .commitCapture(captureID: captureID, createdTaskID: createdTaskID)
        case let .batch(mutations):
            return .batch(mutations.reversed().map(\.inverse))
        }
    }

    /// Copy for the receipt. Plain language, because it is shown in an Undo
    /// affordance rather than a log.
    public var summary: String {
        switch self {
        case .schedule: return "Scheduled"
        case .moveToProject: return "Moved to project"
        case let .setDisposition(_, _, after):
            switch after {
            case .someday: return "Moved to Someday"
            case .reference: return "Kept as reference"
            case .deleted: return "Deleted"
            case .archived: return "Archived"
            case .inbox: return "Returned to Inbox"
            }
        case .commitCapture: return "Added to your tasks"
        case let .batch(mutations): return "\(mutations.count) items triaged"
        }
    }
}

// MARK: - Duplicate detection

/// How a new capture relates to what is already in the Inbox.
///
/// Resolution is always the user's: the plan's rule is Keep Both / Merge /
/// Cancel, never a silent merge. This type only reports the similarity.
public struct InboxDuplicateCandidate: Equatable, Sendable {
    public let existing: InboxItem
    /// 0…1. Not a probability — a normalized title similarity used only to
    /// decide whether to *ask*.
    public let similarity: Double

    public init(existing: InboxItem, similarity: Double) {
        self.existing = existing
        self.similarity = similarity
    }
}

public enum InboxDuplicatePolicy: Sendable {
    /// Below this, the captures are different enough that asking would be noise.
    public static let askThreshold = 0.82

    /// Case- and punctuation-insensitive token overlap (Jaccard).
    ///
    /// Deliberately simple and deterministic: capture happens under 100 ms on a
    /// warm launch, and a user who types the same reminder twice does so with
    /// near-identical words, not paraphrase. Anything cleverer would be slower
    /// and harder to explain when it asks.
    public static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = tokens(lhs)
        let right = tokens(rhs)
        guard left.isEmpty == false, right.isEmpty == false else { return 0 }
        let union = left.union(right).count
        guard union > 0 else { return 0 }
        return Double(left.intersection(right).count) / Double(union)
    }

    public static func candidates(
        for title: String,
        among items: [InboxItem]
    ) -> [InboxDuplicateCandidate] {
        items
            .map { InboxDuplicateCandidate(existing: $0, similarity: similarity(title, $0.title)) }
            .filter { $0.similarity >= askThreshold }
            .sorted { $0.similarity > $1.similarity }
    }

    private static func tokens(_ value: String) -> Set<String> {
        Set(
            value
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.isEmpty == false }
        )
    }
}

// MARK: - Reading

/// Assembles the Inbox from the two places untriaged work actually lives.
///
/// Composed from `PlanningProjectionRepository` (canonical tasks) and the App
/// Group `PendingCapture` queue rather than owning storage of its own, so the
/// Inbox can never drift from what Plan and Backlog believe.
public struct InboxReader: Sendable {
    private let openTasks: @Sendable () async throws -> [PlanningTaskSummary]
    private let pendingCaptures: @Sendable () -> [PendingCapture]

    public init(
        openTasks: @escaping @Sendable () async throws -> [PlanningTaskSummary],
        pendingCaptures: @escaping @Sendable () -> [PendingCapture] = { PendingCaptureInbox.read() }
    ) {
        self.openTasks = openTasks
        self.pendingCaptures = pendingCaptures
    }

    public init(repository: any PlanningProjectionRepository) {
        self.init(openTasks: { try await repository.fetchOpenPlanningTasks() })
    }

    /// Newest first, and pending captures always lead.
    ///
    /// An out-of-process capture is the item most likely to be forgotten — it
    /// was made in a hurry from a widget or the lock screen and has not been
    /// looked at since. Canonical tasks are at least already in the system.
    public func items(for query: LifeBoardInboxQuery) async throws -> [InboxItem] {
        var results: [InboxItem] = []

        if query.scope == .untriaged {
            results = pendingCaptures()
                .sorted { $0.createdAt > $1.createdAt }
                .map { capture in
                    InboxItem(
                        id: capture.id,
                        origin: .pendingCapture(capture.id),
                        title: capture.rawText,
                        capturedAt: capture.createdAt,
                        captureSource: capture.source,
                        // Parsed on demand at review time, not here: capture must
                        // stay under the 100 ms budget, and a proposal the user
                        // has not seen yet has no business being precomputed.
                        proposedDueDate: nil
                    )
                }
        }

        let matching = query.matchingDispositions
        let tasks = try await openTasks()
            .filter { matching.contains($0.metadata.unscheduledDisposition) }
            // A task with a planning day has been triaged by definition, even if
            // its disposition still reads `.inbox`.
            .filter { query.scope != .untriaged || $0.metadata.planningDay == nil }
            .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
            .map { task in
                InboxItem(
                    id: task.id,
                    origin: .task(task.id),
                    title: task.title,
                    capturedAt: task.metadata.updatedAt,
                    captureSource: nil,
                    proposedDueDate: task.dueDate
                )
            }

        results.append(contentsOf: tasks)
        return Array(results.dropFirst(query.offset).prefix(query.limit))
    }

    /// The count for a badge. Separate from `items` so a badge never pays for a
    /// full page fetch, and capped so a neglected inbox shows "99+" rather than
    /// scanning thousands of rows to render a number nobody reads precisely.
    public func untriagedCount(cap: Int = 99) async throws -> Int {
        let captures = pendingCaptures().count
        guard captures < cap else { return cap }
        let tasks = try await openTasks()
            .filter { $0.metadata.unscheduledDisposition == .inbox && $0.metadata.planningDay == nil }
            .count
        return min(captures + tasks, cap)
    }
}

// MARK: - Routing triage through the canonical ledger

extension InboxTriageMutation {
    /// Why a triage decision cannot be expressed as a `PlanMutation`.
    ///
    /// Surfaced as a typed value rather than a silent `nil` so a caller cannot
    /// accidentally drop a user's decision on the floor and still look like it
    /// succeeded.
    public enum TranslationFailure: Error, Equatable, Sendable {
        /// The task's planning metadata was not found, so there is no `before`
        /// state to invert to. Applying without it would make Undo a guess.
        case unknownTask(UUID)
        /// Project membership lives on the canonical `TaskDefinition`, not on
        /// `PlanningTaskMetadata`, so it needs the task repository rather than
        /// the planning receipt ledger.
        case requiresTaskRepository
        /// Committing a capture creates a task; there is nothing to mutate yet.
        case requiresCaptureCommit
    }

    /// Translates into the canonical `PlanMutation` so triage reuses the
    /// existing receipt ledger, Undo, and Insights projection instead of
    /// growing a second mutation path with its own half-implemented history.
    ///
    /// `resolve` supplies current metadata for a task; the returned mutation
    /// always carries a real `before`, never a synthesized default.
    public func planMutation(
        resolve: (UUID) -> PlanningTaskMetadata?
    ) -> Result<PlanMutation, TranslationFailure> {
        switch self {
        case let .schedule(taskID, _, after):
            guard let current = resolve(taskID) else { return .failure(.unknownTask(taskID)) }
            var updated = current
            updated.planningDay = after
            // Scheduling is itself a triage decision, so the item stops being
            // untriaged even though the user never touched the disposition.
            if updated.unscheduledDisposition == .inbox {
                updated.unscheduledDisposition = .inbox
            }
            updated.updatedAt = Date()
            return .success(.saveTaskMetadata(before: current, after: updated))

        case let .setDisposition(taskID, _, after):
            guard let current = resolve(taskID) else { return .failure(.unknownTask(taskID)) }
            var updated = current
            updated.unscheduledDisposition = after
            // Someday, Reference and Deleted all mean "not on a day". Leaving a
            // stale planning day behind would keep the item on the Day spine
            // after the user deliberately took it off.
            if after != .inbox { updated.planningDay = nil }
            updated.updatedAt = Date()
            return .success(.saveTaskMetadata(before: current, after: updated))

        case .moveToProject:
            return .failure(.requiresTaskRepository)

        case .commitCapture:
            return .failure(.requiresCaptureCommit)

        case let .batch(mutations):
            var translated: [PlanMutation] = []
            for mutation in mutations {
                switch mutation.planMutation(resolve: resolve) {
                case .success(let value): translated.append(value)
                // A batch is all-or-nothing: applying the half that translated
                // would leave the user with a partially triaged selection and a
                // receipt that cannot undo what it did not record.
                case .failure(let failure): return .failure(failure)
                }
            }
            return .success(.batch(translated))
        }
    }
}
