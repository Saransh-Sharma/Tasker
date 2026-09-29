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

public struct ProjectTemplateInstantiationMap: Equatable, Sendable {
    public let projectIDs: [UUID: UUID]
    public let sectionIDs: [UUID: UUID]
    public let taskIDs: [UUID: UUID]
    public let milestoneIDs: [UUID: UUID]
    public let dependencyIDs: [UUID: UUID]
    public let recurrenceSeriesIDs: [UUID: UUID]

    public init(
        projectIDs: [UUID: UUID],
        sectionIDs: [UUID: UUID],
        taskIDs: [UUID: UUID],
        milestoneIDs: [UUID: UUID],
        dependencyIDs: [UUID: UUID],
        recurrenceSeriesIDs: [UUID: UUID]
    ) {
        self.projectIDs = projectIDs
        self.sectionIDs = sectionIDs
        self.taskIDs = taskIDs
        self.milestoneIDs = milestoneIDs
        self.dependencyIDs = dependencyIDs
        self.recurrenceSeriesIDs = recurrenceSeriesIDs
    }
}

public struct ProjectTemplateCreationReceipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceProjectID: UUID
    public let createdProject: Project
    public let createdSections: [TaskerProjectSection]
    public let createdTasks: [TaskDefinition]
    public let createdMilestones: [ProjectMilestone]
    public let createdPlanningMetadata: [PlanningTaskMetadata]
    public let planningReceiptID: UUID?
    public let identityMap: ProjectTemplateInstantiationMap
    public let createdAt: Date
}

public enum ProjectTemplateInstantiationError: LocalizedError, Equatable, Sendable {
    case sourceNotFound
    case sourceIsNotArchivedTemplate
    case sourceGraphEscapesTemplate(taskID: UUID, dependencyID: UUID)
    case creationFailed(String)
    case rollbackFailed(original: String, rollback: String)

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound:
            String(localized: "Couldn’t find that template.")
        case .sourceIsNotArchivedTemplate:
            String(localized: "Only archived template projects can be used.")
        case .sourceGraphEscapesTemplate:
            String(localized: "A template task depends on a task outside it.")
        case .creationFailed(let message):
            String(localized: "Couldn’t create project. \(message)")
        case .rollbackFailed(_, let rollback):
            String(localized: "Couldn’t undo project creation. \(rollback)")
        }
    }
}

/// Deep-copies the existing project graph without introducing a second
/// template store. Every copied identity is allocated before the first write,
/// allowing hierarchy and dependency edges to be remapped deterministically.
public actor ProjectTemplateInstantiationService {
    private let projects: any ProjectRepositoryProtocol
    private let sections: (any SectionRepositoryProtocol)?
    private let tasks: any TaskDefinitionRepositoryProtocol
    private let tagLinks: (any TaskTagLinkRepositoryProtocol)?
    private let dependencyLinks: (any TaskDependencyRepositoryProtocol)?
    private let milestones: any ProjectMilestoneRepository
    private let planning: (any PlanningRepository & PlanningMutationRepository)?

    public init(
        projects: any ProjectRepositoryProtocol,
        sections: (any SectionRepositoryProtocol)?,
        tasks: any TaskDefinitionRepositoryProtocol,
        tagLinks: (any TaskTagLinkRepositoryProtocol)?,
        dependencyLinks: (any TaskDependencyRepositoryProtocol)?,
        milestones: any ProjectMilestoneRepository,
        planning: (any PlanningRepository & PlanningMutationRepository)? = nil
    ) {
        self.projects = projects
        self.sections = sections
        self.tasks = tasks
        self.tagLinks = tagLinks
        self.dependencyLinks = dependencyLinks
        self.milestones = milestones
        self.planning = planning
    }

    public func templates() async throws -> [Project] {
        try await fetchProjects()
            .filter { $0.isArchived && $0.templateId != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func instantiate(
        sourceProjectID: UUID,
        name: String? = nil
    ) async throws -> ProjectTemplateCreationReceipt {
        guard let source = try await fetchProject(id: sourceProjectID) else {
            throw ProjectTemplateInstantiationError.sourceNotFound
        }
        guard source.isArchived, source.templateId != nil else {
            throw ProjectTemplateInstantiationError.sourceIsNotArchivedTemplate
        }

        async let sourceSectionsValue = fetchSections(projectID: sourceProjectID)
        async let sourceTasksValue = fetchTasks(projectID: sourceProjectID)
        async let sourceMilestonesValue = milestones.milestones(projectID: sourceProjectID)
        let sourceSections = try await sourceSectionsValue
        let sourceTasks = try await sourceTasksValue
        let sourceMilestones = try await sourceMilestonesValue
        let sourcePlanning = try await fetchPlanningMetadata(
            taskIDs: Set(sourceTasks.map(\.id))
        )

        let projectID = UUID()
        let sectionIDs = Dictionary(
            uniqueKeysWithValues: sourceSections.map { ($0.id, UUID()) }
        )
        let taskIDs = Dictionary(
            uniqueKeysWithValues: sourceTasks.map { ($0.id, UUID()) }
        )
        let milestoneIDs = Dictionary(
            uniqueKeysWithValues: sourceMilestones.map { ($0.id, UUID()) }
        )
        let dependencyIDs = Dictionary(
            uniqueKeysWithValues: sourceTasks
                .flatMap(\.dependencies)
                .map { ($0.id, UUID()) }
        )
        let recurrenceSeriesIDs = Dictionary(
            uniqueKeysWithValues: Set(sourceTasks.compactMap(\.recurrenceSeriesID))
                .map { ($0, UUID()) }
        )
        for sourceTask in sourceTasks {
            for dependency in sourceTask.dependencies
            where taskIDs[dependency.dependsOnTaskID] == nil {
                throw ProjectTemplateInstantiationError.sourceGraphEscapesTemplate(
                    taskID: sourceTask.id,
                    dependencyID: dependency.id
                )
            }
        }

        let now = Date()
        let createdProject = Project(
            id: projectID,
            lifeAreaID: source.lifeAreaID,
            name: resolvedProjectName(name, source: source),
            projectDescription: source.projectDescription,
            createdDate: now,
            modifiedDate: now,
            isDefault: false,
            color: source.color,
            icon: source.icon,
            status: .active,
            priority: source.priority,
            parentProjectId: nil,
            subprojectIds: [],
            tags: source.tags,
            dueDate: source.dueDate,
            estimatedTaskCount: source.estimatedTaskCount,
            isArchived: false,
            templateId: source.id,
            settings: source.settings,
            motivationWhy: source.motivationWhy,
            motivationSuccessLooksLike: source.motivationSuccessLooksLike,
            motivationCostOfNeglect: source.motivationCostOfNeglect
        )
        let createdSections = sourceSections.map {
            TaskerProjectSection(
                id: sectionIDs[$0.id]!,
                projectID: projectID,
                name: $0.name,
                sortOrder: $0.sortOrder,
                isCollapsed: false,
                createdAt: now,
                updatedAt: now
            )
        }
        let createdTasks = sourceTasks.map {
            copyTask(
                $0,
                project: createdProject,
                sectionIDs: sectionIDs,
                taskIDs: taskIDs,
                dependencyIDs: dependencyIDs,
                recurrenceSeriesIDs: recurrenceSeriesIDs,
                at: now
            )
        }
        let createdMilestones = sourceMilestones.map {
            ProjectMilestone(
                id: milestoneIDs[$0.id]!,
                projectID: projectID,
                title: $0.title,
                targetDay: $0.targetDay,
                completedAt: nil,
                sortOrder: $0.sortOrder
            )
        }
        let createdPlanningMetadata = sourcePlanning.compactMap {
            sourceValue -> PlanningTaskMetadata? in
            guard
                sourceValue.pinOrder != nil,
                let copiedTaskID = taskIDs[sourceValue.taskID]
            else { return nil }
            return PlanningTaskMetadata(
                taskID: copiedTaskID,
                pinOrder: sourceValue.pinOrder,
                updatedAt: now
            )
        }
        let identityMap = ProjectTemplateInstantiationMap(
            projectIDs: [source.id: projectID],
            sectionIDs: sectionIDs,
            taskIDs: taskIDs,
            milestoneIDs: milestoneIDs,
            dependencyIDs: dependencyIDs,
            recurrenceSeriesIDs: recurrenceSeriesIDs
        )

        var wroteProject = false
        var wroteSections: [TaskerProjectSection] = []
        var wroteTasks: [TaskDefinition] = []
        var wroteMilestones: [ProjectMilestone] = []
        var planningReceiptID: UUID?
        do {
            _ = try await createProject(createdProject)
            wroteProject = true
            for section in createdSections {
                _ = try await createSection(section)
                wroteSections.append(section)
            }
            for task in createdTasks.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                _ = try await createTask(task)
                wroteTasks.append(task)
                try await replaceLinks(for: task)
            }
            planningReceiptID = try await applyPlanningOrder(createdPlanningMetadata)
            for milestone in createdMilestones {
                try await milestones.saveMilestone(milestone)
                wroteMilestones.append(milestone)
            }
        } catch {
            do {
                try await removeCreatedGraph(
                    projectID: wroteProject ? projectID : nil,
                    sections: wroteSections,
                    tasks: wroteTasks,
                    milestones: wroteMilestones,
                    planningReceiptID: planningReceiptID
                )
            } catch let rollbackError {
                throw ProjectTemplateInstantiationError.rollbackFailed(
                    original: String(describing: error),
                    rollback: String(describing: rollbackError)
                )
            }
            throw ProjectTemplateInstantiationError.creationFailed(
                String(describing: error)
            )
        }

        return ProjectTemplateCreationReceipt(
            id: UUID(),
            sourceProjectID: source.id,
            createdProject: createdProject,
            createdSections: createdSections,
            createdTasks: createdTasks,
            createdMilestones: createdMilestones,
            createdPlanningMetadata: createdPlanningMetadata,
            planningReceiptID: planningReceiptID,
            identityMap: identityMap,
            createdAt: now
        )
    }

    public func undo(_ receipt: ProjectTemplateCreationReceipt) async throws {
        try await removeCreatedGraph(
            projectID: receipt.createdProject.id,
            sections: receipt.createdSections,
            tasks: receipt.createdTasks,
            milestones: receipt.createdMilestones,
            planningReceiptID: receipt.planningReceiptID
        )
    }

    private func resolvedProjectName(_ requested: String?, source: Project) -> String {
        let trimmed = requested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty == false { return trimmed }
        return source.name.replacingOccurrences(of: " Template", with: "")
    }

    private func copyTask(
        _ source: TaskDefinition,
        project: Project,
        sectionIDs: [UUID: UUID],
        taskIDs: [UUID: UUID],
        dependencyIDs: [UUID: UUID],
        recurrenceSeriesIDs: [UUID: UUID],
        at now: Date
    ) -> TaskDefinition {
        TaskDefinition(
            id: taskIDs[source.id]!,
            recurrenceSeriesID: source.recurrenceSeriesID.flatMap {
                recurrenceSeriesIDs[$0]
            },
            habitDefinitionID: nil,
            projectID: project.id,
            projectName: project.name,
            iconSymbolName: source.iconSymbolName,
            lifeAreaID: source.lifeAreaID,
            sectionID: source.sectionID.flatMap { sectionIDs[$0] },
            parentTaskID: source.parentTaskID.flatMap { taskIDs[$0] },
            title: source.title,
            details: source.details,
            priority: source.priority,
            type: source.type,
            energy: source.energy,
            category: source.category,
            context: source.context,
            dueDate: source.dueDate,
            scheduledStartAt: source.scheduledStartAt,
            scheduledEndAt: source.scheduledEndAt,
            isAllDay: source.isAllDay,
            isComplete: false,
            dateAdded: now,
            dateCompleted: nil,
            isEveningTask: source.isEveningTask,
            alertReminderTime: source.alertReminderTime,
            tagIDs: source.tagIDs,
            dependencies: source.dependencies.map {
                TaskDependencyLinkDefinition(
                    id: dependencyIDs[$0.id]!,
                    taskID: taskIDs[source.id]!,
                    dependsOnTaskID: taskIDs[$0.dependsOnTaskID]!,
                    kind: $0.kind,
                    createdAt: now
                )
            },
            estimatedDuration: source.estimatedDuration,
            actualDuration: nil,
            subtasks: source.subtasks.compactMap { taskIDs[$0] },
            repeatPattern: source.repeatPattern,
            recurrenceAnchor: source.recurrenceAnchor,
            planningBucket: source.planningBucket,
            weeklyOutcomeID: nil,
            deferredFromWeekStart: nil,
            deferredCount: 0,
            replanCount: 0,
            createdAt: now,
            updatedAt: now
        )
    }

    private func removeCreatedGraph(
        projectID: UUID?,
        sections: [TaskerProjectSection],
        tasks: [TaskDefinition],
        milestones: [ProjectMilestone],
        planningReceiptID: UUID?
    ) async throws {
        if let planningReceiptID, let planning {
            try await planning.undo(receiptID: planningReceiptID)
        }
        for milestone in milestones.reversed() {
            try await self.milestones.deleteMilestone(id: milestone.id)
        }
        for task in tasks.reversed() {
            try await deleteTask(id: task.id)
        }
        for section in sections.reversed() {
            try await deleteSection(id: section.id)
        }
        if let projectID {
            try await deleteProject(id: projectID)
        }
    }

    private func fetchPlanningMetadata(
        taskIDs: Set<UUID>
    ) async throws -> [PlanningTaskMetadata] {
        guard let planning, taskIDs.isEmpty == false else { return [] }
        return try await planning.fetchTaskMetadata(taskIDs: taskIDs)
    }

    private func applyPlanningOrder(
        _ values: [PlanningTaskMetadata]
    ) async throws -> UUID? {
        guard let planning, values.isEmpty == false else { return nil }
        let mutations = values.map {
            PlanMutation.saveTaskMetadata(
                before: PlanningTaskMetadata(taskID: $0.taskID),
                after: $0
            )
        }
        let receipt = try await planning.prepare(
            .batch(mutations),
            source: "project.template.manual-order",
            summary: "Copied project task order"
        )
        try await planning.apply(receiptID: receipt.id)
        return receipt.id
    }

    private func fetchProjects() async throws -> [Project] {
        try await withCheckedThrowingContinuation { continuation in
            projects.fetchAllProjects { continuation.resume(with: $0) }
        }
    }

    private func fetchProject(id: UUID) async throws -> Project? {
        try await withCheckedThrowingContinuation { continuation in
            projects.fetchProject(withId: id) { continuation.resume(with: $0) }
        }
    }

    private func fetchSections(projectID: UUID) async throws -> [TaskerProjectSection] {
        guard let sections else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            sections.fetchSections(projectID: projectID) {
                continuation.resume(with: $0)
            }
        }
    }

    private func fetchTasks(projectID: UUID) async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            tasks.fetchAll(query: TaskDefinitionQuery(projectID: projectID)) {
                continuation.resume(with: $0)
            }
        }
    }

    private func createProject(_ project: Project) async throws -> Project {
        try await withCheckedThrowingContinuation { continuation in
            projects.createProject(project) { continuation.resume(with: $0) }
        }
    }

    private func createSection(
        _ section: TaskerProjectSection
    ) async throws -> TaskerProjectSection {
        guard let sections else { return section }
        return try await withCheckedThrowingContinuation { continuation in
            sections.create(section) { continuation.resume(with: $0) }
        }
    }

    private func createTask(_ task: TaskDefinition) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            tasks.create(task) { continuation.resume(with: $0) }
        }
    }

    private func replaceLinks(for task: TaskDefinition) async throws {
        if let tagLinks {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                tagLinks.replaceTagLinks(taskID: task.id, tagIDs: task.tagIDs) {
                    continuation.resume(with: $0)
                }
            }
        }
        if let dependencyLinks {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                dependencyLinks.replaceDependencies(
                    taskID: task.id,
                    dependencies: task.dependencies
                ) {
                    continuation.resume(with: $0)
                }
            }
        }
    }

    private func deleteTask(id: UUID) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            tasks.delete(id: id) { continuation.resume(with: $0) }
        }
    }

    private func deleteSection(id: UUID) async throws {
        guard let sections else { return }
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            sections.delete(id: id) { continuation.resume(with: $0) }
        }
    }

    private func deleteProject(id: UUID) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            projects.deleteProject(withId: id, deleteTasks: false) {
                continuation.resume(with: $0)
            }
        }
    }
}

/// Everything a project detail screen needs, resolved once.
public struct ProjectExecutionSnapshot: Equatable, Sendable {
    public let projectID: UUID
    public let name: String
    public let isArchived: Bool
    public let executionMode: ProjectExecutionMode
    public let sections: [ProjectSectionDefinition]
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
        sections: [ProjectSectionDefinition],
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
        sections: [ProjectSectionDefinition] = [],
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

public enum TaskEditorValidationError: LocalizedError, Equatable, Sendable {
    case invalidScheduledInterval
    case duplicateSubtask
    case subtaskAlreadyHasParent
    case circularSubtask
    case circularDependency

    public var errorDescription: String? {
        switch self {
        case .invalidScheduledInterval:
            String(localized: "End time must be after start time.")
        case .duplicateSubtask:
            String(localized: "A task can appear only once in the steps.")
        case .subtaskAlreadyHasParent:
            String(localized: "That task is already a step of another task.")
        case .circularSubtask:
            String(localized: "A task can’t be a step of itself.")
        case .circularDependency:
            String(localized: "A task can’t wait on itself.")
        }
    }
}

public struct TaskEditorReceipt: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let beforeTask: TaskDefinition
    public let afterTask: TaskDefinition
    public let beforePlanning: PlanningTaskMetadata
    public let afterPlanning: PlanningTaskMetadata
    public let beforeRelatedTasks: [TaskDefinition]
    public let afterRelatedTasks: [TaskDefinition]
    public let planningReceiptID: UUID?
    public let createdAt: Date
}

/// The complete editable task contract shown by every task route.
///
/// Keeping planning metadata beside the canonical task row prevents a form
/// from submitting only the fields that happen to be visible in one route.
/// Relationship arrays live on `task` and are committed by `TaskEditorStore`
/// together with their repository sidecars.
@dynamicMemberLookup
public struct TaskEditorDraft: Equatable, Sendable {
    public var task: TaskDefinition
    public var planning: PlanningTaskMetadata

    public init(task: TaskDefinition, planning: PlanningTaskMetadata) {
        precondition(task.id == planning.taskID, "A task draft must share one stable identity")
        self.task = task
        self.planning = planning
    }

    public subscript<Value>(
        dynamicMember keyPath: WritableKeyPath<TaskDefinition, Value>
    ) -> Value {
        get { task[keyPath: keyPath] }
        set { task[keyPath: keyPath] = newValue }
    }
}

/// Scheduling changes never manufacture or rewrite a deadline.
public enum TaskWhenSelection: Equatable, Sendable {
    case anytime
    case day(Date)
    case timed(Date)

    public func applying(to source: TaskEditorDraft, calendar: Calendar = .current) -> TaskEditorDraft {
        var result = source
        switch self {
        case .anytime:
            result.planning.planningDay = nil
            result.scheduledStartAt = nil
            result.scheduledEndAt = nil
            result.isAllDay = false
        case .day(let date):
            result.planning.planningDay = PlanningDay(date: date, timeZone: calendar.timeZone, calendar: calendar)
            result.scheduledStartAt = nil
            result.scheduledEndAt = nil
            result.isAllDay = true
        case .timed(let date):
            result.planning.planningDay = PlanningDay(date: date, timeZone: calendar.timeZone, calendar: calendar)
            result.scheduledStartAt = date
            result.scheduledEndAt = date.addingTimeInterval(max(source.estimatedDuration ?? 30 * 60, 60))
            result.isAllDay = false
        }
        return result
    }

    /// Where a new time lands when someone switches a task from "Day" to
    /// "Day + time". The planning day's own start is midnight, which is never
    /// what they meant: today it is the next quarter hour, any other day 9 AM.
    public static func defaultStart(on day: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        if calendar.isDate(day, inSameDayAs: now) {
            // Rebuilt from components: `date(bySetting:)` searches *forward*
            // for a match, so zeroing the seconds of 14:07:42 yields 14:08.
            var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let minute = parts.minute ?? 0
            parts.minute = (minute / 15 + 1) * 15
            let roundedUp = calendar.date(from: parts) ?? now
            // Late evening can round past midnight; keep the task on the day chosen.
            return calendar.isDate(roundedUp, inSameDayAs: day) ? roundedUp : now
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }
}

/// Runs async work one piece at a time, on the main actor.
///
/// The task editor autosaves from several triggers — a debounce, a field
/// change, losing focus, leaving the screen. `save()` used to return early when
/// another save was in flight, so a flush on leave could be silently dropped
/// and the last edit lost. Callers now wait their turn instead.
@MainActor
final class SerializedWork {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var isRunning: Bool { isBusy }

    func run<T>(_ work: () async -> T) async -> T {
        await waitForIdle()
        isBusy = true
        defer {
            isBusy = false
            let resumed = waiters
            waiters = []
            resumed.forEach { $0.resume() }
        }
        return await work()
    }

    func waitForIdle() async {
        while isBusy {
            await withCheckedContinuation { waiters.append($0) }
        }
    }
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
    public private(set) var sections: [TaskerProjectSection] = []
    public private(set) var lifeAreas: [LifeArea] = []
    public private(set) var tags: [TagDefinition] = []
    public private(set) var taskCandidates: [TaskDefinition] = []
    public private(set) var activeReceipt: TaskEditorReceipt?
    public var draft: TaskEditorDraft

    let taskID: UUID
    private let dependencies: PlanFeatureDependencies
    var persistedTask: TaskDefinition?
    private var persistedPlanning: PlanningTaskMetadata?
    private var autosaveTask: Task<Void, Never>?
    private let saveQueue = SerializedWork()
    private var saveIsRunning = false
    private var undoAfterSave = false

    public func scheduleAutosave(textOnly: Bool) {
        autosaveTask?.cancel()
        guard hasUnsavedChanges else { return }
        autosaveTask = Task { @MainActor [weak self] in
            if textOnly {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
            guard !Task.isCancelled, let self else { return }
            _ = await self.save()
        }
    }

    public func flushAutosave() async {
        autosaveTask?.cancel()
        // Let a save already in flight finish first; checking for unsaved
        // changes before it lands would compare against the old persisted copy.
        await saveQueue.waitForIdle()
        if hasUnsavedChanges { _ = await save() }
    }


    init(taskID: UUID, dependencies: PlanFeatureDependencies) {
        self.taskID = taskID
        self.dependencies = dependencies
        draft = TaskEditorDraft(
            task: TaskDefinition(id: taskID, title: ""),
            planning: PlanningTaskMetadata(taskID: taskID)
        )
    }

    public var planning: PlanningTaskMetadata {
        get { draft.planning }
        set { draft.planning = newValue }
    }

    public var hasUnsavedChanges: Bool {
        guard let persistedTask, let persistedPlanning else { return false }
        return draft != TaskEditorDraft(task: persistedTask, planning: persistedPlanning)
    }

    public var commitPhase: AsyncActionPhase<TaskEditorReceipt> {
        switch mutationState {
        case .idle, .undoing:
            return .idle
        case .saving:
            return .running(progress: nil)
        case .saved:
            if hasUnsavedChanges { return .idle }
            return activeReceipt.map(AsyncActionPhase.success(receipt:)) ?? .idle
        case .failed(let message):
            return .recoverableFailure(.init(message: message, recovery: .edit))
        }
    }

    public func load() async {
        loadState = .loading
        do {
            async let taskValue = fetchTask()
            async let planningValue = dependencies.planningRepository.fetchPlanningTasks(includeCompleted: true)
            async let projectValues = fetchProjects()
            async let tagValues = fetchTags()
            async let lifeAreaValues = fetchLifeAreas()
            async let candidateValues = fetchTasks()
            guard let loadedTask = try await taskValue else {
                loadState = .missing
                return
            }
            let summaries = try await planningValue
            let metadata = summaries.first(where: { $0.id == taskID })?.metadata
                ?? PlanningTaskMetadata(taskID: taskID)
            draft = TaskEditorDraft(task: loadedTask, planning: metadata)
            persistedTask = loadedTask
            persistedPlanning = metadata
            let loadedProjects = try await projectValues
            projects = loadedProjects
                .filter { $0.isArchived == false }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            sections = try await fetchSections(for: loadedProjects)
            lifeAreas = try await lifeAreaValues
                .filter { $0.isArchived == false }
                .sorted {
                    if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            tags = try await tagValues.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            taskCandidates = try await candidateValues
                .filter { $0.id != taskID }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            mutationState = .idle
            loadState = .ready
        } catch {
            loadState = .failed(message: error.localizedDescription)
        }
    }

    @discardableResult
    public func save() async -> TaskEditorReceipt? {
        await saveQueue.run {
            // A save that waited its turn may find the one ahead of it already
            // persisted everything; writing again would only replace the Undo.
            guard hasUnsavedChanges else { return nil }
            return await performSave()
        }
    }

    private func performSave() async -> TaskEditorReceipt? {
        guard let beforeTask = persistedTask, let beforePlanning = persistedPlanning else {
            return nil
        }
        guard !saveIsRunning else { return nil }
        saveIsRunning = true
        defer { saveIsRunning = false }
        let submittedDraft = draft
        mutationState = .saving
        do {
            var afterTask = submittedDraft.task
            afterTask.title = afterTask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            try afterTask.validate()
            if let start = afterTask.scheduledStartAt,
               let end = afterTask.scheduledEndAt,
               end <= start {
                throw TaskEditorValidationError.invalidScheduledInterval
            }
            if Set(afterTask.subtasks).count != afterTask.subtasks.count
                || afterTask.subtasks.contains(afterTask.id) {
                throw TaskEditorValidationError.duplicateSubtask
            }
            let relatedTaskChanges = try relatedTaskChanges(
                before: beforeTask,
                after: afterTask
            )
            if dependencyGraphContainsCycle(
                proposed: Set(afterTask.dependencies.map(\.dependsOnTaskID))
            ) {
                throw TaskEditorValidationError.circularDependency
            }
            afterTask.updatedAt = Date()

            var afterPlanning = submittedDraft.planning
            let planningChanged = afterPlanning != beforePlanning
            if planningChanged { afterPlanning.updatedAt = Date() }

            var appliedRelatedTasks: [TaskDefinition] = []
            try await updateTask(afterTask)
            do {
                try await replaceLinks(for: afterTask)
                for relatedTask in relatedTaskChanges.after
                where relatedTaskChanges.before.first(
                    where: { $0.id == relatedTask.id }
                ) != relatedTask {
                    try await updateTask(relatedTask)
                    appliedRelatedTasks.append(relatedTask)
                }
            } catch {
                await restoreRelatedTasks(
                    relatedTaskChanges.before,
                    limitedTo: Set(appliedRelatedTasks.map(\.id))
                )
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
                    await restoreRelatedTasks(
                        relatedTaskChanges.before,
                        limitedTo: Set(relatedTaskChanges.after.map(\.id))
                    )
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
                beforeRelatedTasks: relatedTaskChanges.before,
                afterRelatedTasks: relatedTaskChanges.after,
                planningReceiptID: planningReceiptID,
                createdAt: Date()
            )
            if draft == submittedDraft {
                draft = TaskEditorDraft(task: afterTask, planning: afterPlanning)
            }
            persistedTask = afterTask
            persistedPlanning = afterPlanning
            replaceTaskCandidates(with: relatedTaskChanges.after)
            activeReceipt = receipt
            mutationState = .saved(receiptID: receipt.id)
            saveIsRunning = false
            if undoAfterSave {
                undoAfterSave = false
                await undo()
            } else if hasUnsavedChanges {
                scheduleAutosave(textOnly: true)
            }
            return receipt
        } catch {
            mutationState = .failed(message: error.localizedDescription)
            return nil
        }
    }

    public func undo() async {
        autosaveTask?.cancel()
        if saveIsRunning { undoAfterSave = true; return }
        guard let receipt = activeReceipt else { return }
        mutationState = .undoing
        do {
            try await updateTask(receipt.beforeTask)
            do {
                try await replaceLinks(for: receipt.beforeTask)
                for relatedTask in receipt.beforeRelatedTasks {
                    try await updateTask(relatedTask)
                }
                if let planningReceiptID = receipt.planningReceiptID {
                    try await dependencies.planningRepository.undo(receiptID: planningReceiptID)
                }
            } catch {
                try? await updateTask(receipt.afterTask)
                try? await replaceLinks(for: receipt.afterTask)
                for relatedTask in receipt.afterRelatedTasks {
                    try? await updateTask(relatedTask)
                }
                throw error
            }
            draft = TaskEditorDraft(
                task: receipt.beforeTask,
                planning: receipt.beforePlanning
            )
            persistedTask = receipt.beforeTask
            persistedPlanning = receipt.beforePlanning
            replaceTaskCandidates(with: receipt.beforeRelatedTasks)
            activeReceipt = nil
            mutationState = .idle
        } catch {
            mutationState = .failed(message: error.localizedDescription)
        }
    }

    public func archive() async {
        draft.planning.unscheduledDisposition = .archived
        _ = await save()
    }

    public func delete() async {
        draft.planning.unscheduledDisposition = .deleted
        _ = await save()
    }

    public func toggleDependency(on candidateID: UUID, kind: TaskDependencyKind = .blocks) {
        if let index = draft.task.dependencies.firstIndex(
            where: { $0.dependsOnTaskID == candidateID }
        ) {
            draft.task.dependencies.remove(at: index)
            return
        }
        guard dependencyWouldCreateCycle(candidateID) == false else {
            mutationState = .failed(message: String(localized: "A task can’t wait on itself."))
            return
        }
        draft.task.dependencies.append(
            TaskDependencyLinkDefinition(
                taskID: taskID,
                dependsOnTaskID: candidateID,
                kind: kind
            )
        )
    }

    public func toggleSubtask(_ candidateID: UUID) {
        if let index = draft.task.subtasks.firstIndex(of: candidateID) {
            draft.task.subtasks.remove(at: index)
        } else if candidateID != taskID {
            draft.task.subtasks.append(candidateID)
        }
    }

    public func moveSubtask(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.compactMap { index in
            draft.task.subtasks.indices.contains(index)
                ? draft.task.subtasks[index]
                : nil
        }
        guard moving.isEmpty == false else { return }
        for index in fromOffsets.sorted(by: >)
        where draft.task.subtasks.indices.contains(index) {
            draft.task.subtasks.remove(at: index)
        }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(
            max(0, toOffset - removedBeforeDestination),
            draft.task.subtasks.count
        )
        draft.task.subtasks.insert(contentsOf: moving, at: destination)
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

    private func fetchLifeAreas() async throws -> [LifeArea] {
        guard let repository = dependencies.lifeAreaRepository else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            repository.fetchAll { continuation.resume(with: $0) }
        }
    }

    private func fetchTasks() async throws -> [TaskDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            dependencies.taskDefinitionRepository.fetchAll {
                continuation.resume(with: $0)
            }
        }
    }

    private func fetchSections(
        for projects: [Project]
    ) async throws -> [TaskerProjectSection] {
        guard let repository = dependencies.sectionRepository else { return [] }
        return try await withThrowingTaskGroup(
            of: [TaskerProjectSection].self,
            returning: [TaskerProjectSection].self
        ) { group in
            for project in projects {
                group.addTask {
                    try await withCheckedThrowingContinuation { continuation in
                        repository.fetchSections(projectID: project.id) {
                            continuation.resume(with: $0)
                        }
                    }
                }
            }
            var values: [TaskerProjectSection] = []
            for try await result in group { values.append(contentsOf: result) }
            return values.sorted {
                if $0.projectID != $1.projectID {
                    return $0.projectID.uuidString < $1.projectID.uuidString
                }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func restoreRelatedTasks(
        _ snapshots: [TaskDefinition],
        limitedTo taskIDs: Set<UUID>
    ) async {
        for task in snapshots.reversed() where taskIDs.contains(task.id) {
            try? await updateTask(task)
        }
    }

    private func replaceTaskCandidates(with replacements: [TaskDefinition]) {
        let replacementByID = Dictionary(
            uniqueKeysWithValues: replacements.map { ($0.id, $0) }
        )
        taskCandidates = taskCandidates.map { replacementByID[$0.id] ?? $0 }
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
