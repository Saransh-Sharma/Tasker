import Foundation
import Observation

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

public protocol ProjectMilestoneRepository: Sendable {
    func milestones(projectID: UUID) async throws -> [ProjectMilestone]
    func saveMilestone(_ milestone: ProjectMilestone) async throws
    func deleteMilestone(id: UUID) async throws
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
    public let sectionIDByTaskID: [UUID: UUID]
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
        sectionIDByTaskID: [UUID: UUID] = [:],
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
        self.sectionIDByTaskID = sectionIDByTaskID
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
    private let tasks: @Sendable () async throws -> [PlanningTaskSummary]
    private let taskDefinitions: @Sendable () async throws -> [TaskDefinition]
    private let projects: @Sendable () async throws -> [PlanningProjectSummary]
    private let today: @Sendable () -> PlanningDay

    public init(
        openTasks: @escaping @Sendable () async throws -> [PlanningTaskSummary],
        taskDefinitions: @escaping @Sendable () async throws -> [TaskDefinition] = { [] },
        projects: @escaping @Sendable () async throws -> [PlanningProjectSummary] = { [] },
        today: @escaping @Sendable () -> PlanningDay = { PlanningDay(date: Date()) }
    ) {
        self.tasks = openTasks
        self.taskDefinitions = taskDefinitions
        self.projects = projects
        self.today = today
    }

    public init(
        repository: any PlanningProjectionRepository,
        taskDefinitions: @escaping @Sendable () async throws -> [TaskDefinition] = { [] }
    ) {
        self.init(
            openTasks: { try await repository.fetchPlanningTasks(includeCompleted: true) },
            taskDefinitions: taskDefinitions,
            projects: { try await repository.fetchPlanningProjects() }
        )
    }

    public func tasks(for query: TaskExecutionQuery) async throws -> [PlanningTaskSummary] {
        let reference = today()
        async let fetchedTasks = tasks()
        async let fetchedDefinitions = taskDefinitions()
        let definitions = try await Dictionary(
            uniqueKeysWithValues: fetchedDefinitions.map { ($0.id, $0) }
        )
        let matching = try await fetchedTasks.filter { task in
            let definition = definitions[task.id]
            return query.matches(
                task,
                today: reference,
                tagIDsForTask: Set(definition?.tagIDs ?? []),
                lifeAreaForTask: definition?.lifeAreaID,
                contextForTask: definition?.context,
                isComplete: definition?.isComplete ?? false
            )
        }
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
        async let fetchedTasks = tasks()
        async let fetchedDefinitions = taskDefinitions()
        let all = try await fetchedTasks
        let definitions = try await Dictionary(
            uniqueKeysWithValues: fetchedDefinitions.map { ($0.id, $0) }
        )
        var result: [TaskExecutionQuery.Scope: Int] = [:]
        for scope in scopes {
            let query = TaskExecutionQuery(scope: scope)
            result[scope] = all.count { task in
                let definition = definitions[task.id]
                return query.matches(
                    task,
                    today: reference,
                    tagIDsForTask: Set(definition?.tagIDs ?? []),
                    lifeAreaForTask: definition?.lifeAreaID,
                    contextForTask: definition?.context,
                    isComplete: definition?.isComplete ?? false
                )
            }
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
        async let taskValues = tasks()
        async let definitionValues = taskDefinitions()
        let definitions = try await Dictionary(
            uniqueKeysWithValues: definitionValues.map { ($0.id, $0) }
        )
        let projectTasks = try await taskValues.filter {
            $0.projectID == projectID
                && $0.metadata.unscheduledDisposition != .deleted
        }
        let tasks = projectTasks.filter { definitions[$0.id]?.isComplete != true }
        let derivedCompletedCount = projectTasks.count { definitions[$0.id]?.isComplete == true }
        let sectionIDs: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: definitions.values.compactMap { definition -> (UUID, UUID)? in
                guard definition.projectID == projectID, let sectionID = definition.sectionID else {
                    return nil
                }
                return (definition.id, sectionID)
            }
        )
        return ProjectExecutionSnapshot(
            projectID: projectID,
            name: project.name,
            isArchived: project.isArchived,
            executionMode: tasks.first?.projectExecutionMode ?? .parallel,
            sections: sections.sorted { $0.sortOrder < $1.sortOrder },
            milestones: milestones.sorted { $0.sortOrder < $1.sortOrder },
            tasks: tasks,
            sectionIDByTaskID: sectionIDs,
            completedTaskCount: max(completedTaskCount, derivedCompletedCount),
            generatedAt: Date()
        )
    }
}

public enum TaskExecutionLoadState: Equatable, Sendable {
    case loading
    case empty
    case loaded
    case stale(lastUpdatedAt: Date)
    case permissionDenied
    case failed(message: String)
}

/// Production state holder for all named task scopes.
///
/// It owns no task data and performs no mutation. Every load is projected from
/// the canonical repositories, which keeps Inbox, Today, Upcoming, Waiting,
/// Someday, Completed and All aligned even as filters change.
@MainActor
@Observable
public final class TaskExecutionStore {
    public private(set) var state: TaskExecutionLoadState = .loading
    public private(set) var tasks: [PlanningTaskSummary] = []
    public private(set) var counts: [TaskExecutionQuery.Scope: Int] = [:]
    public private(set) var lastUpdatedAt: Date?
    public var query: TaskExecutionQuery

    private let projection: TaskExecutionProjection

    public init(
        query: TaskExecutionQuery = .init(),
        projection: TaskExecutionProjection
    ) {
        self.query = query
        self.projection = projection
    }

    public func load() async {
        state = .loading
        do {
            async let projectedTasks = projection.tasks(for: query)
            async let projectedCounts = projection.counts()
            tasks = try await projectedTasks
            counts = try await projectedCounts
            lastUpdatedAt = Date()
            state = tasks.isEmpty ? .empty : .loaded
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func markStale() {
        guard let lastUpdatedAt else { return }
        state = .stale(lastUpdatedAt: lastUpdatedAt)
    }
}

// MARK: - Canonical task editor

public enum TaskEditorLoadState: Equatable, Sendable {
    case loading
    case ready
    case missing
    case failed(message: String)
}

public enum TaskEditorMutationState: Equatable, Sendable {
    case idle
    case saving
    case saved(receiptID: UUID)
    case undoing
    case failed(message: String)
}

public struct TaskEditorReceipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let beforeTask: TaskDefinition
    public let afterTask: TaskDefinition
    public let beforePlanning: PlanningTaskMetadata
    public let afterPlanning: PlanningTaskMetadata
    public let planningReceiptID: UUID?
    public let createdAt: Date
}

/// One editor state holder for every task route.
///
/// The editor coordinates the canonical definition row, tag/dependency links,
/// and planning metadata as one user-visible mutation. If a later repository
/// fails, earlier writes are restored before the failure reaches the UI.
@MainActor
@Observable
public final class TaskEditorStore {
    public private(set) var loadState: TaskEditorLoadState = .loading
    public private(set) var mutationState: TaskEditorMutationState = .idle
    public private(set) var projects: [Project] = []
    public private(set) var tags: [TagDefinition] = []
    public private(set) var activeReceipt: TaskEditorReceipt?
    public var draft = TaskDefinition(title: "")
    public var planning = PlanningTaskMetadata(taskID: UUID())

    private let taskID: UUID
    private let dependencies: PlanFeatureDependencies
    private var persistedTask: TaskDefinition?
    private var persistedPlanning: PlanningTaskMetadata?

    init(taskID: UUID, dependencies: PlanFeatureDependencies) {
        self.taskID = taskID
        self.dependencies = dependencies
        planning = PlanningTaskMetadata(taskID: taskID)
    }

    public var hasUnsavedChanges: Bool {
        guard let persistedTask, let persistedPlanning else { return false }
        return draft != persistedTask || planning != persistedPlanning
    }

    public func load() async {
        loadState = .loading
        do {
            async let taskValue = fetchTask()
            async let planningValue = dependencies.planningRepository.fetchPlanningTasks(includeCompleted: true)
            async let projectValues = fetchProjects()
            async let tagValues = fetchTags()
            guard let loadedTask = try await taskValue else {
                loadState = .missing
                return
            }
            let summaries = try await planningValue
            let metadata = summaries.first(where: { $0.id == taskID })?.metadata
                ?? PlanningTaskMetadata(taskID: taskID)
            draft = loadedTask
            planning = metadata
            persistedTask = loadedTask
            persistedPlanning = metadata
            projects = try await projectValues
                .filter { $0.isArchived == false }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            tags = try await tagValues.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            mutationState = .idle
            loadState = .ready
        } catch {
            loadState = .failed(message: error.localizedDescription)
        }
    }

    @discardableResult
    public func save() async -> TaskEditorReceipt? {
        guard let beforeTask = persistedTask, let beforePlanning = persistedPlanning else {
            return nil
        }
        mutationState = .saving
        do {
            var afterTask = draft
            afterTask.title = afterTask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            try afterTask.validate()
            afterTask.updatedAt = Date()

            var afterPlanning = planning
            let planningChanged = afterPlanning != beforePlanning
            if planningChanged { afterPlanning.updatedAt = Date() }

            try await updateTask(afterTask)
            do {
                try await replaceLinks(for: afterTask)
            } catch {
                try? await updateTask(beforeTask)
                try? await replaceLinks(for: beforeTask)
                throw error
            }

            var planningReceiptID: UUID?
            if planningChanged {
                do {
                    let receipt = try await dependencies.planningRepository.prepare(
                        .saveTaskMetadata(before: beforePlanning, after: afterPlanning),
                        source: "task.editor.\(taskID.uuidString)",
                        summary: "Updated \(afterTask.title)"
                    )
                    try await dependencies.planningRepository.apply(receiptID: receipt.id)
                    planningReceiptID = receipt.id
                } catch {
                    try? await updateTask(beforeTask)
                    try? await replaceLinks(for: beforeTask)
                    throw error
                }
            }

            let receipt = TaskEditorReceipt(
                id: UUID(),
                beforeTask: beforeTask,
                afterTask: afterTask,
                beforePlanning: beforePlanning,
                afterPlanning: afterPlanning,
                planningReceiptID: planningReceiptID,
                createdAt: Date()
            )
            draft = afterTask
            planning = afterPlanning
            persistedTask = afterTask
            persistedPlanning = afterPlanning
            activeReceipt = receipt
            mutationState = .saved(receiptID: receipt.id)
            return receipt
        } catch {
            mutationState = .failed(message: error.localizedDescription)
            return nil
        }
    }

    public func undo() async {
        guard let receipt = activeReceipt else { return }
        mutationState = .undoing
        do {
            try await updateTask(receipt.beforeTask)
            do {
                try await replaceLinks(for: receipt.beforeTask)
                if let planningReceiptID = receipt.planningReceiptID {
                    try await dependencies.planningRepository.undo(receiptID: planningReceiptID)
                }
            } catch {
                try? await updateTask(receipt.afterTask)
                try? await replaceLinks(for: receipt.afterTask)
                throw error
            }
            draft = receipt.beforeTask
            planning = receipt.beforePlanning
            persistedTask = receipt.beforeTask
            persistedPlanning = receipt.beforePlanning
            activeReceipt = nil
            mutationState = .idle
        } catch {
            mutationState = .failed(message: error.localizedDescription)
        }
    }

    public func archive() async {
        planning.unscheduledDisposition = .archived
        _ = await save()
    }

    public func delete() async {
        planning.unscheduledDisposition = .deleted
        _ = await save()
    }

    private func fetchTask() async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            dependencies.taskDefinitionRepository.fetchTaskDefinition(
                id: taskID,
                completion: { continuation.resume(with: $0) }
            )
        }
    }

    private func fetchProjects() async throws -> [Project] {
        try await withCheckedThrowingContinuation { continuation in
            dependencies.projectRepository.fetchAllProjects { continuation.resume(with: $0) }
        }
    }

    private func fetchTags() async throws -> [TagDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            dependencies.tagRepository.fetchAll { continuation.resume(with: $0) }
        }
    }

    private func updateTask(_ task: TaskDefinition) async throws {
        _ = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<TaskDefinition, any Error>) in
            dependencies.taskDefinitionRepository.update(task) {
                continuation.resume(with: $0)
            }
        }
    }

    private func replaceLinks(for task: TaskDefinition) async throws {
        if let repository = dependencies.taskTagLinkRepository {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                repository.replaceTagLinks(taskID: task.id, tagIDs: task.tagIDs) {
                    continuation.resume(with: $0)
                }
            }
        }
        if let repository = dependencies.taskDependencyRepository {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                repository.replaceDependencies(taskID: task.id, dependencies: task.dependencies) {
                    continuation.resume(with: $0)
                }
            }
        }
    }
}
