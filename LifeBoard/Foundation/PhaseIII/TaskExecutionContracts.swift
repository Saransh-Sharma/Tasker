import Foundation

/// Querying and projecting task execution.
///
/// Composes the existing `TaskDefinition` and `PlanningTaskMetadata` rather than
/// introducing a second task representation: `TaskDefinition` already carries
/// tags, subtasks, dependencies, sections, recurrence and estimates, and
/// planning state already lives in metadata. What was missing is a way to *ask*
/// for a slice of that without every caller hand-rolling predicates.

// MARK: - Query

public struct TaskExecutionQuery: Equatable, Sendable {
    /// The named views the plan calls for. Each is a saved question, not a
    /// separate store.
    public enum Scope: String, CaseIterable, Sendable {
        case inbox
        case today
        case upcoming
        case waiting
        case someday
        case completed
        case all
    }

    public enum SortOrder: String, CaseIterable, Sendable {
        /// Deadline first, then planned day. What "what's urgent" means.
        case deadline
        /// Planned day first. What "what's on deck" means.
        case plannedDay
        /// Most recently touched. What "where was I" means.
        case recentlyUpdated
        case manual
    }

    public var scope: Scope
    public var projectID: UUID?
    public var lifeAreaID: UUID?
    public var tagIDs: Set<UUID>
    public var context: TaskContext?
    public var sort: SortOrder
    public var limit: Int
    public var offset: Int

    public init(
        scope: Scope = .today,
        projectID: UUID? = nil,
        lifeAreaID: UUID? = nil,
        tagIDs: Set<UUID> = [],
        context: TaskContext? = nil,
        sort: SortOrder = .deadline,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.scope = scope
        self.projectID = projectID
        self.lifeAreaID = lifeAreaID
        self.tagIDs = tagIDs
        self.context = context
        self.sort = sort
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }

    /// Whether a task belongs in this query's scope.
    ///
    /// Expressed as a pure predicate over values the caller already has, so the
    /// same rule can drive an in-memory projection, a test, and eventually a
    /// fetch request — instead of three definitions of "today" that drift.
    public func matches(
        _ task: PlanningTaskSummary,
        today: PlanningDay,
        tagIDsForTask: Set<UUID> = [],
        lifeAreaForTask: UUID? = nil,
        contextForTask: TaskContext? = nil,
        isComplete: Bool = false
    ) -> Bool {
        // Tombstones never appear in any scope. A deleted task is gone, and a
        // "saved filter" that resurrects one would be a data-loss bug wearing a
        // feature's clothes.
        guard task.metadata.unscheduledDisposition != .deleted else { return false }

        if let projectID, task.projectID != projectID { return false }
        if let lifeAreaID, lifeAreaForTask != lifeAreaID { return false }
        if let context, contextForTask != context { return false }
        if tagIDs.isEmpty == false, tagIDs.isDisjoint(with: tagIDsForTask) { return false }

        switch scope {
        case .all:
            return true
        case .completed:
            return isComplete
        case .inbox:
            return isComplete == false
                && task.metadata.unscheduledDisposition == .inbox
                && task.metadata.planningDay == nil
        case .today:
            // Overdue work counts as today's problem. Anything still planned for
            // a past day is due now, not quietly filed under a day that passed.
            guard isComplete == false, task.metadata.availability == .actionable else { return false }
            // A task that cannot start yet is not today's work, however it is
            // scheduled. Without this a start date would be decoration and the
            // day would look fuller than it can actually be.
            if let start = task.metadata.startDay, start > today { return false }
            guard let day = task.metadata.planningDay else { return false }
            return day <= today
        case .upcoming:
            guard isComplete == false, task.metadata.availability == .actionable else { return false }
            guard let day = task.metadata.planningDay else { return false }
            return day > today
        case .waiting:
            return isComplete == false && task.metadata.availability == .waiting
        case .someday:
            return isComplete == false && task.metadata.unscheduledDisposition == .someday
        }
    }

    /// Deterministic ordering. Ties break on stable id so pagination cannot
    /// repeat or drop a row between pages.
    public func sorted(_ tasks: [PlanningTaskSummary]) -> [PlanningTaskSummary] {
        tasks.sorted { lhs, rhs in
            switch sort {
            case .deadline:
                let l = lhs.dueDate ?? .distantFuture
                let r = rhs.dueDate ?? .distantFuture
                if l != r { return l < r }
            case .plannedDay:
                let l = lhs.metadata.planningDay
                let r = rhs.metadata.planningDay
                if l != r {
                    guard let l else { return false }
                    guard let r else { return true }
                    return l < r
                }
            case .recentlyUpdated:
                if lhs.metadata.updatedAt != rhs.metadata.updatedAt {
                    return lhs.metadata.updatedAt > rhs.metadata.updatedAt
                }
            case .manual:
                let l = lhs.metadata.pinOrder ?? Int.max
                let r = rhs.metadata.pinOrder ?? Int.max
                if l != r { return l < r }
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func paginated(_ tasks: [PlanningTaskSummary]) -> [PlanningTaskSummary] {
        Array(sorted(tasks).dropFirst(offset).prefix(limit))
    }
}

// MARK: - Project projection

/// A milestone within a project.
///
/// Distinct from a task: a milestone is a point a project passes through, not
/// work someone does. Modelling it as a task would put it in Today and ask the
/// user to "complete" an event.
public struct ProjectMilestone: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var title: String
    public var targetDay: PlanningDay?
    public var completedAt: Date?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        title: String,
        targetDay: PlanningDay? = nil,
        completedAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.targetDay = targetDay
        self.completedAt = completedAt
        self.sortOrder = sortOrder
    }

    public var isComplete: Bool { completedAt != nil }
}

/// Everything a project detail screen needs, resolved once.
public struct ProjectExecutionSnapshot: Equatable, Sendable {
    public let projectID: UUID
    public let name: String
    public let isArchived: Bool
    public let executionMode: ProjectExecutionMode
    public let sections: [LifeBoardProjectSection]
    public let milestones: [ProjectMilestone]
    public let tasks: [PlanningTaskSummary]
    public let completedTaskCount: Int
    public let generatedAt: Date

    public init(
        projectID: UUID,
        name: String,
        isArchived: Bool,
        executionMode: ProjectExecutionMode,
        sections: [LifeBoardProjectSection],
        milestones: [ProjectMilestone],
        tasks: [PlanningTaskSummary],
        completedTaskCount: Int,
        generatedAt: Date
    ) {
        self.projectID = projectID
        self.name = name
        self.isArchived = isArchived
        self.executionMode = executionMode
        self.sections = sections
        self.milestones = milestones
        self.tasks = tasks
        self.completedTaskCount = completedTaskCount
        self.generatedAt = generatedAt
    }

    /// The single task to do next, or `nil` when the project is blocked or done.
    ///
    /// Sequential projects expose exactly one: that is what "sequential" means,
    /// and showing five when only the first is actionable is how a plan starts
    /// lying. Parallel projects surface the most urgent ready task.
    public var nextAction: PlanningTaskSummary? {
        let ready = tasks.filter {
            $0.metadata.availability == .actionable
                && $0.dependenciesReady
                && $0.metadata.unscheduledDisposition != .deleted
                && $0.metadata.unscheduledDisposition != .archived
        }
        switch executionMode {
        case .sequential:
            // Ordered by the user's arrangement, not by urgency: in a sequential
            // project the next step is the next step.
            return ready.min { lhs, rhs in
                (lhs.metadata.pinOrder ?? Int.max, lhs.id.uuidString)
                    < (rhs.metadata.pinOrder ?? Int.max, rhs.id.uuidString)
            }
        case .parallel:
            return ready.min { lhs, rhs in
                (lhs.dueDate ?? .distantFuture, lhs.id.uuidString)
                    < (rhs.dueDate ?? .distantFuture, rhs.id.uuidString)
            }
        }
    }

    /// Blocked means "has work, none of it startable" — distinct from finished.
    public var isBlocked: Bool {
        tasks.isEmpty == false && nextAction == nil && completedTaskCount < totalTaskCount
    }

    public var totalTaskCount: Int { tasks.count + completedTaskCount }

    /// `nil` rather than 0 when there is nothing to measure.
    ///
    /// A brand-new project showing "0%" reads as failure; showing nothing reads
    /// as what it is — not started.
    public var completionFraction: Double? {
        guard totalTaskCount > 0 else { return nil }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    public var nextMilestone: ProjectMilestone? {
        milestones
            .filter { $0.isComplete == false }
            .min { lhs, rhs in
                switch (lhs.targetDay, rhs.targetDay) {
                case let (l?, r?) where l != r: return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.sortOrder < rhs.sortOrder
                }
            }
    }
}

// MARK: - Projection

/// Answers `TaskExecutionQuery` against the canonical planning repository.
///
/// Owns no storage. `fetchOpenPlanningTasks()` is the single source for open
/// work, so every named view — Today, Upcoming, Waiting, Someday — is the same
/// data asked a different question, and none of them can drift from Plan.
public struct TaskExecutionProjection: Sendable {
    private let openTasks: @Sendable () async throws -> [PlanningTaskSummary]
    private let projects: @Sendable () async throws -> [PlanningProjectSummary]
    private let today: @Sendable () -> PlanningDay

    public init(
        openTasks: @escaping @Sendable () async throws -> [PlanningTaskSummary],
        projects: @escaping @Sendable () async throws -> [PlanningProjectSummary] = { [] },
        today: @escaping @Sendable () -> PlanningDay = { PlanningDay(date: Date()) }
    ) {
        self.openTasks = openTasks
        self.projects = projects
        self.today = today
    }

    public init(repository: any PlanningProjectionRepository) {
        self.init(
            openTasks: { try await repository.fetchOpenPlanningTasks() },
            projects: { try await repository.fetchPlanningProjects() }
        )
    }

    public func tasks(for query: TaskExecutionQuery) async throws -> [PlanningTaskSummary] {
        let reference = today()
        let matching = try await openTasks().filter { query.matches($0, today: reference) }
        return query.paginated(matching)
    }

    /// Counts per scope for badges and tab labels.
    ///
    /// One fetch for all scopes rather than one per scope: a task list header
    /// showing five counts should not cost five round trips.
    public func counts(
        for scopes: [TaskExecutionQuery.Scope] = TaskExecutionQuery.Scope.allCases
    ) async throws -> [TaskExecutionQuery.Scope: Int] {
        let reference = today()
        let all = try await openTasks()
        var result: [TaskExecutionQuery.Scope: Int] = [:]
        for scope in scopes {
            let query = TaskExecutionQuery(scope: scope)
            result[scope] = all.count { query.matches($0, today: reference) }
        }
        return result
    }

    /// A project's execution snapshot.
    ///
    /// `completedTaskCount` is supplied rather than derived: `fetchOpenPlanningTasks`
    /// returns only open work by definition, so counting completions from it
    /// would always yield zero and quietly report every project as 0% done.
    public func projectSnapshot(
        projectID: UUID,
        completedTaskCount: Int,
        sections: [LifeBoardProjectSection] = [],
        milestones: [ProjectMilestone] = []
    ) async throws -> ProjectExecutionSnapshot? {
        guard let project = try await projects().first(where: { $0.id == projectID }) else {
            return nil
        }
        let tasks = try await openTasks().filter {
            $0.projectID == projectID
                && $0.metadata.unscheduledDisposition != .deleted
        }
        return ProjectExecutionSnapshot(
            projectID: projectID,
            name: project.name,
            isArchived: project.isArchived,
            executionMode: tasks.first?.projectExecutionMode ?? .parallel,
            sections: sections.sorted { $0.sortOrder < $1.sortOrder },
            milestones: milestones.sorted { $0.sortOrder < $1.sortOrder },
            tasks: tasks,
            completedTaskCount: completedTaskCount,
            generatedAt: Date()
        )
    }
}
