import Foundation
import Combine
import SwiftUI

public struct TaskDetailMetadataPayload {
    public let projects: [Project]
    public let sections: [TaskerProjectSection]
    public let weeklyOutcomes: [WeeklyOutcome]
    public let projectMotivation: ProjectWeeklyMotivation?

    /// Initializes a new instance.
    public init(
        projects: [Project],
        sections: [TaskerProjectSection],
        weeklyOutcomes: [WeeklyOutcome] = [],
        projectMotivation: ProjectWeeklyMotivation? = nil
    ) {
        self.projects = projects
        self.sections = sections
        self.weeklyOutcomes = weeklyOutcomes
        self.projectMotivation = projectMotivation
    }
}

public struct TaskDetailRelationshipMetadataPayload {
    public let lifeAreas: [LifeArea]
    public let tags: [TagDefinition]
    public let availableTasks: [TaskDefinition]
    public let recentReflectionNotes: [ReflectionNote]

    public init(
        lifeAreas: [LifeArea],
        tags: [TagDefinition],
        availableTasks: [TaskDefinition],
        recentReflectionNotes: [ReflectionNote] = []
    ) {
        self.lifeAreas = lifeAreas
        self.tags = tags
        self.availableTasks = availableTasks
        self.recentReflectionNotes = recentReflectionNotes
    }
}

public struct ProjectWeeklyMotivation: Equatable {
    public let why: String?
    public let successLooksLike: String?
    public let costOfNeglect: String?

    public init(
        why: String? = nil,
        successLooksLike: String? = nil,
        costOfNeglect: String? = nil
    ) {
        self.why = why
        self.successLooksLike = successLooksLike
        self.costOfNeglect = costOfNeglect
    }

    public var isEmpty: Bool {
        [why, successLooksLike, costOfNeglect]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .allSatisfy(\.isEmpty)
    }
}

public enum TaskDetailAutosaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)

    public var label: String {
        switch self {
        case .idle:
            return ""
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed(let message):
            return message
        }
    }
}

public enum TaskDetailDisclosureSection: String, Hashable {
    case steps
    case details
    case relationships
    case context
}

@MainActor
public final class TaskDetailViewModel: ObservableObject {
    public typealias UpdateHandler = (UUID, UpdateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    public typealias CompletionHandler = (UUID, Bool, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    public typealias DeleteHandler = (UUID, TaskDeleteScope, @escaping (Result<Void, Error>) -> Void) -> Void
    public typealias RescheduleHandler = (UUID, Date?, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    public typealias MetadataHandler = (UUID, @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void) -> Void
    public typealias RelationshipMetadataHandler = (UUID, @escaping (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void) -> Void
    public typealias ChildrenHandler = (UUID, @escaping (Result<[TaskDefinition], Error>) -> Void) -> Void
    public typealias CreateTaskHandler = (CreateTaskDefinitionRequest, @escaping (Result<TaskDefinition, Error>) -> Void) -> Void
    public typealias CreateTagHandler = (String, @escaping (Result<TagDefinition, Error>) -> Void) -> Void
    public typealias CreateProjectHandler = (String, @escaping (Result<Project, Error>) -> Void) -> Void
    public typealias TaskFitHintHandler = (TaskDefinition, @escaping (TaskerTaskFitHintResult) -> Void) -> Void

    @Published public private(set) var persistedTask: TaskDefinition
    @Published public private(set) var projects: [Project]
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var sections: [TaskerProjectSection] = []
    @Published public private(set) var tags: [TagDefinition] = []
    @Published public private(set) var availableTasks: [TaskDefinition] = []
    @Published public private(set) var childSteps: [TaskDefinition] = []
    @Published public private(set) var weeklyOutcomes: [WeeklyOutcome] = []
    @Published public private(set) var projectMotivation: ProjectWeeklyMotivation?
    @Published public private(set) var recentReflectionNotes: [ReflectionNote] = []
    @Published public private(set) var displayProjectName: String

    @Published public var taskName: String
    @Published public var taskDescription: String
    @Published public var selectedPriority: TaskPriority
    @Published public var selectedType: TaskType
    @Published public var selectedProjectID: UUID
    @Published public var dueDate: Date?
    @Published public var reminderTime: Date?
    @Published public var isComplete: Bool

    @Published public var selectedLifeAreaID: UUID?
    @Published public var selectedSectionID: UUID?
    @Published public var selectedTagIDs: Set<UUID>

    @Published public var selectedParentTaskID: UUID?
    @Published public var selectedDependencyTaskIDs: Set<UUID>
    @Published public var selectedDependencyKind: TaskDependencyKind
    @Published public var selectedEnergy: TaskEnergy
    @Published public var selectedCategory: TaskCategory
    @Published public var selectedContext: TaskContext
    @Published public var selectedPlanningBucket: TaskPlanningBucket
    @Published public var selectedWeeklyOutcomeID: UUID?
    @Published public var estimatedDuration: TimeInterval?
    @Published public var repeatPattern: TaskRepeatPattern?

    @Published public var expandedDisclosureSections: Set<TaskDetailDisclosureSection>
    @Published public var autosaveState: TaskDetailAutosaveState = .idle
    @Published public var errorMessage: String?
    @Published public private(set) var aiBreakdownSteps: [String] = []
    @Published public private(set) var aiBreakdownRouteBanner: String?
    @Published public private(set) var isGeneratingAIBreakdown = false
    @Published public private(set) var taskFitHint: TaskerTaskFitHintResult = .unknown
    @Published public private(set) var isLoadingTaskFitHint = false

    private let onUpdate: UpdateHandler
    private let onSetCompletion: CompletionHandler
    private let onDelete: DeleteHandler
    private let onReschedule: RescheduleHandler
    private let onLoadMetadata: MetadataHandler
    private let onLoadRelationshipMetadata: RelationshipMetadataHandler
    private let onLoadChildren: ChildrenHandler
    private let onCreateTask: CreateTaskHandler
    private let onCreateTag: CreateTagHandler
    private let onCreateProject: CreateProjectHandler
    private let onLoadTaskFitHint: TaskFitHintHandler

    private var autosaveWorkItem: DispatchWorkItem?
    private var isSaving = false
    private var needsSaveAfterCurrentRequest = false
    private var suppressAutosave = false
    private let textAutosaveDebounceSeconds: TimeInterval = 0.4

    private var editingMetadataRequestID: UUID?
    private var relationshipMetadataRequestID: UUID?
    private var childrenRequestID: UUID?
    private var breakdownRequestToken = UUID()
    private var taskFitHintRequestToken = UUID()
    private var hasScheduledInitialEnrichment = false
    private var hasLoadedChildren = false
    private var hasManuallyToggledDisclosure = false
    private var pendingEditingMetadataTask: Task<Void, Never>?
    private var pendingSecondaryEnrichmentTask: Task<Void, Never>?
    private var pendingProjectScopedRefreshWorkItem: DispatchWorkItem?

    /// Initializes a new instance.
    public init(
        task: TaskDefinition,
        projects: [Project],
        onUpdate: @escaping UpdateHandler,
        onSetCompletion: @escaping CompletionHandler,
        onDelete: @escaping DeleteHandler,
        onReschedule: @escaping RescheduleHandler,
        onLoadMetadata: @escaping MetadataHandler,
        onLoadRelationshipMetadata: @escaping RelationshipMetadataHandler,
        onLoadChildren: @escaping ChildrenHandler,
        onCreateTask: @escaping CreateTaskHandler,
        onCreateTag: @escaping CreateTagHandler,
        onCreateProject: @escaping CreateProjectHandler,
        onLoadTaskFitHint: @escaping TaskFitHintHandler = { _, completion in
            completion(.unknown)
        }
    ) {
        self.persistedTask = task
        self.projects = projects

        self.taskName = task.title
        self.taskDescription = task.details ?? ""
        self.selectedPriority = task.priority
        self.selectedType = task.type
        self.selectedProjectID = task.projectID
        self.dueDate = task.dueDate
        self.reminderTime = task.alertReminderTime
        self.isComplete = task.isComplete

        self.selectedLifeAreaID = task.lifeAreaID
        self.selectedSectionID = task.sectionID
        self.selectedTagIDs = Set(task.tagIDs)

        self.selectedParentTaskID = task.parentTaskID
        self.selectedDependencyTaskIDs = Set(task.dependencies.map(\.dependsOnTaskID))
        self.selectedDependencyKind = task.dependencies.first?.kind ?? .related
        self.selectedEnergy = task.energy
        self.selectedCategory = task.category
        self.selectedContext = task.context
        self.selectedPlanningBucket = task.planningBucket
        self.selectedWeeklyOutcomeID = task.weeklyOutcomeID
        self.estimatedDuration = task.estimatedDuration
        self.repeatPattern = task.repeatPattern
        self.displayProjectName = task.projectName ?? ProjectConstants.inboxProjectName
        self.expandedDisclosureSections = TaskDetailViewModel.defaultExpandedDisclosureSections(for: task)

        self.onUpdate = onUpdate
        self.onSetCompletion = onSetCompletion
        self.onDelete = onDelete
        self.onReschedule = onReschedule
        self.onLoadMetadata = onLoadMetadata
        self.onLoadRelationshipMetadata = onLoadRelationshipMetadata
        self.onLoadChildren = onLoadChildren
        self.onCreateTask = onCreateTask
        self.onCreateTag = onCreateTag
        self.onCreateProject = onCreateProject
        self.onLoadTaskFitHint = onLoadTaskFitHint
    }

    deinit {
        autosaveWorkItem?.cancel()
        pendingEditingMetadataTask?.cancel()
        pendingSecondaryEnrichmentTask?.cancel()
        pendingProjectScopedRefreshWorkItem?.cancel()
    }

    public var selectedProjectName: String {
        displayProjectName
    }

    public var availableParentTasks: [TaskDefinition] {
        availableTasks.filter { $0.id != persistedTask.id }
    }

    public var availableDependencyTasks: [TaskDefinition] {
        availableTasks.filter { $0.id != persistedTask.id }
    }

    public var scheduleSummary: String {
        var parts: [String] = []
        if let dueDate {
            parts.append(DateUtils.formatDate(dueDate))
        } else {
            parts.append("No due date")
        }
        if let reminderTime {
            parts.append(Self.timeLabel(for: reminderTime))
        }
        if selectedType != .morning {
            parts.append(selectedType.displayName)
        }
        if let repeatPattern {
            parts.append(repeatPattern.displayName)
        }
        return parts.joined(separator: ", ")
    }

    public var scheduleExtrasSummary: String {
        var parts: [String] = []
        if let reminderTime {
            parts.append("Reminder \(Self.timeLabel(for: reminderTime))")
        }
        if selectedType != .morning {
            parts.append(selectedType.displayName)
        }
        if let repeatPattern {
            parts.append(repeatPattern.displayName)
        }
        return parts.joined(separator: " · ")
    }

    public var organizeSummary: String {
        var parts = [selectedProjectName]
        if let selectedLifeAreaID,
           let lifeArea = lifeAreas.first(where: { $0.id == selectedLifeAreaID }) {
            parts.append(lifeArea.name)
        }
        if let selectedSectionID,
           let section = sections.first(where: { $0.id == selectedSectionID }) {
            parts.append(section.name)
        }
        if selectedTagIDs.isEmpty == false {
            parts.append(selectedTagIDs.count == 1 ? "1 tag" : "\(selectedTagIDs.count) tags")
        }
        return parts.joined(separator: ", ")
    }

    public var executionSummary: String {
        var parts = ["\(selectedPriority.displayName) priority"]
        if let estimatedDuration {
            parts.append(Self.durationLabel(for: estimatedDuration))
        }
        if selectedEnergy != .medium {
            parts.append(selectedEnergy.displayName)
        }
        if selectedContext != .anywhere {
            parts.append(selectedContext.displayName)
        }
        if selectedCategory != .general {
            parts.append(selectedCategory.displayName)
        }
        if selectedPlanningBucket != .today {
            parts.append(selectedPlanningBucket.displayName)
        }
        if selectedWeeklyOutcomeID != nil {
            parts.append("Linked to outcome")
        }
        return parts.joined(separator: ", ")
    }

    public var relationshipsSummary: String {
        var parts: [String] = []
        if let selectedParentTaskID,
           let task = availableParentTasks.first(where: { $0.id == selectedParentTaskID }) {
            parts.append("Parent: \(task.title)")
        }
        if selectedDependencyTaskIDs.isEmpty == false {
            parts.append(selectedDependencyTaskIDs.count == 1 ? "1 dependency" : "\(selectedDependencyTaskIDs.count) dependencies")
        }
        return parts.isEmpty ? "No linked tasks" : parts.joined(separator: ", ")
    }

    public var stepsSummary: String {
        if childSteps.isEmpty {
            return persistedTask.subtasks.isEmpty ? "No steps yet" : "Loading steps..."
        }
        return childSteps.count == 1 ? "1 step" : "\(childSteps.count) steps"
    }

    public var detailsSummary: String {
        var parts = [selectedProjectName]
        if selectedPriority != .low {
            parts.append(selectedPriority.displayName)
        }
        if let estimatedDuration {
            parts.append(Self.durationLabel(for: estimatedDuration))
        }
        if selectedType != .morning {
            parts.append(selectedType.displayName)
        }
        if let repeatPattern {
            parts.append(repeatPattern.displayName)
        }
        if selectedTagIDs.isEmpty == false {
            parts.append(selectedTagIDs.count == 1 ? "1 tag" : "\(selectedTagIDs.count) tags")
        }
        if selectedWeeklyOutcomeID != nil {
            parts.append("Linked to outcome")
        }
        return parts.joined(separator: " · ")
    }

    public var contextSummary: String {
        var parts: [String] = []
        if recentReflectionNotes.isEmpty == false {
            parts.append(recentReflectionNotes.count == 1 ? "1 reflection" : "\(recentReflectionNotes.count) reflections")
        }
        if projectMotivation?.isEmpty == false {
            parts.append("Project motivation")
        }
        return parts.isEmpty ? "Extra context is hidden" : parts.joined(separator: " · ")
    }

    public var hasRelationshipContent: Bool {
        selectedParentTaskID != nil || selectedDependencyTaskIDs.isEmpty == false
    }

    public var hasContextContent: Bool {
        recentReflectionNotes.isEmpty == false || projectMotivation?.isEmpty == false
    }

    public var compactStatusSummary: String {
        if isComplete {
            return "Completed"
        }
        if let dueDate {
            return "Due \(DateUtils.formatDate(dueDate))"
        }
        return "No due date"
    }

    public var headerSummary: String {
        [selectedProjectName, compactStatusSummary]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    public var stepCreationHint: String {
        childSteps.isEmpty ? "Break the task into tiny steps to make starting easier." : "Add the next small step."
    }

    public var shouldShowRelationshipsSection: Bool {
        hasRelationshipContent
    }

    public var shouldShowContextSection: Bool {
        hasContextContent
    }

    /// Executes onAppear.
    public func onAppear() {
        guard hasScheduledInitialEnrichment == false else { return }
        hasScheduledInitialEnrichment = true
        pendingEditingMetadataTask?.cancel()
        pendingSecondaryEnrichmentTask?.cancel()
        pendingEditingMetadataTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, Task.isCancelled == false else { return }
            self.refreshMetadata()
            self.pendingEditingMetadataTask = nil
        }
        pendingSecondaryEnrichmentTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard let self, Task.isCancelled == false else { return }
            self.refreshRelationshipMetadata()
            self.refreshTaskFitHint()
            self.pendingSecondaryEnrichmentTask = nil
        }
    }

    public func refreshTaskFitHint() {
        let requestToken = UUID()
        taskFitHintRequestToken = requestToken
        let draftTask = makeTaskDraftForFitHint()
        isLoadingTaskFitHint = true
        onLoadTaskFitHint(draftTask) { [weak self] hint in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.taskFitHintRequestToken == requestToken else { return }
                self.isLoadingTaskFitHint = false
                self.taskFitHint = hint
            }
        }
    }

    public func isSectionExpanded(_ section: TaskDetailDisclosureSection) -> Bool {
        expandedDisclosureSections.contains(section)
    }

    public func toggleSection(_ section: TaskDetailDisclosureSection) {
        hasManuallyToggledDisclosure = true
        if expandedDisclosureSections.contains(section) {
            expandedDisclosureSections.remove(section)
        } else {
            expandedDisclosureSections.insert(section)
        }
    }

    public func summary(for section: TaskDetailDisclosureSection) -> String {
        switch section {
        case .steps:
            return stepsSummary
        case .details:
            return detailsSummary
        case .relationships:
            return relationshipsSummary
        case .context:
            return contextSummary
        }
    }

    public func handleDisappear() {
        pendingEditingMetadataTask?.cancel()
        pendingSecondaryEnrichmentTask?.cancel()
        pendingProjectScopedRefreshWorkItem?.cancel()
        taskFitHintRequestToken = UUID()
        pendingEditingMetadataTask = nil
        pendingSecondaryEnrichmentTask = nil
        pendingProjectScopedRefreshWorkItem = nil
        editingMetadataRequestID = UUID()
        relationshipMetadataRequestID = UUID()
        childrenRequestID = UUID()
        hasLoadedChildren = false
    }

    public func refreshProjectScopedMetadata() {
        pendingProjectScopedRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refreshMetadata()
            self.refreshRelationshipMetadata()
        }
        pendingProjectScopedRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    /// Executes refreshMetadata.
    public func refreshMetadata() {
        refreshDisplayProjectName()
        let requestID = UUID()
        editingMetadataRequestID = requestID
        let interval = TaskerPerformanceTrace.begin("TaskDetailEditingMetadataLoad")
        onLoadMetadata(selectedProjectID) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.editingMetadataRequestID == requestID else { return }
                switch result {
                case .success(let payload):
                    let nextProjects = self.dedupeProjects(payload.projects)
                    let nextSections = payload.sections.sorted { $0.sortOrder < $1.sortOrder }
                    if self.projects != nextProjects {
                        self.projects = nextProjects
                    }
                    if self.sections != nextSections {
                        self.sections = nextSections
                    }
                    if self.weeklyOutcomes != payload.weeklyOutcomes {
                        self.weeklyOutcomes = payload.weeklyOutcomes
                    }
                    if self.projectMotivation != payload.projectMotivation {
                        self.projectMotivation = payload.projectMotivation?.isEmpty == true ? nil : payload.projectMotivation
                    }
                    self.refreshDisplayProjectName()
                    self.reconcileSelectionAfterMetadataRefresh()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func refreshRelationshipMetadata() {
        let requestID = UUID()
        relationshipMetadataRequestID = requestID
        let interval = TaskerPerformanceTrace.begin("TaskDetailRelationshipMetadataLoad")
        onLoadRelationshipMetadata(selectedProjectID) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.relationshipMetadataRequestID == requestID else { return }
                switch result {
                case .success(let payload):
                    let nextLifeAreas = payload.lifeAreas
                        .filter { !$0.isArchived }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    let nextTags = payload.tags.sorted {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    let nextAvailableTasks = payload.availableTasks
                        .filter { !$0.isComplete && $0.id != self.persistedTask.id }
                        .sorted(by: Self.sortTasksByDueThenName)
                    if self.lifeAreas != nextLifeAreas {
                        self.lifeAreas = nextLifeAreas
                    }
                    if self.tags != nextTags {
                        self.tags = nextTags
                    }
                    if self.availableTasks != nextAvailableTasks {
                        self.availableTasks = nextAvailableTasks
                    }
                    if self.recentReflectionNotes != payload.recentReflectionNotes {
                        self.recentReflectionNotes = payload.recentReflectionNotes
                    }
                    self.reconcileSelectionAfterMetadataRefresh()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes refreshChildren.
    public func refreshChildren() {
        let requestID = UUID()
        childrenRequestID = requestID
        let interval = TaskerPerformanceTrace.begin("TaskDetailChildrenLoad")
        onLoadChildren(persistedTask.id) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.childrenRequestID == requestID else { return }
                switch result {
                case .success(let children):
                    let nextChildren = children.sorted(by: Self.sortSteps)
                    if self.childSteps != nextChildren {
                        self.childSteps = nextChildren
                    }
                    if nextChildren.isEmpty == false,
                       self.hasManuallyToggledDisclosure == false,
                       self.expandedDisclosureSections.contains(.steps) == false {
                        self.expandedDisclosureSections.insert(.steps)
                    }
                    self.hasLoadedChildren = true
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func ensureChildrenLoaded() {
        guard hasLoadedChildren == false else { return }
        refreshChildren()
    }

    /// Executes scheduleAutosave.
    public func scheduleAutosave(debounced: Bool) {
        guard !suppressAutosave else { return }

        autosaveWorkItem?.cancel()

        if isSaving {
            needsSaveAfterCurrentRequest = true
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.performAutosave()
        }
        autosaveWorkItem = workItem

        if debounced {
            DispatchQueue.main.asyncAfter(deadline: .now() + textAutosaveDebounceSeconds, execute: workItem)
        } else {
            DispatchQueue.main.async(execute: workItem)
        }
    }

    /// Executes toggleRootCompletion.
    public func toggleRootCompletion() {
        let target = !isComplete
        withAnimation(TaskerAnimation.bouncy) {
            isComplete = target
        }

        onSetCompletion(persistedTask.id, target) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let updatedTask):
                    self.syncDraftFromTask(updatedTask)
                    self.autosaveState = .saved
                case .failure(let error):
                    self.isComplete.toggle()
                    self.autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Executes applyReschedule.
    public func applyReschedule(to date: Date?) {
        onReschedule(persistedTask.id, date) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let updatedTask):
                    self.syncDraftFromTask(updatedTask)
                    self.autosaveState = .saved
                case .failure(let error):
                    self.autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Executes deleteTask.
    public func deleteTask(scope: TaskDeleteScope, completion: @escaping (Result<Void, Error>) -> Void) {
        onDelete(persistedTask.id, scope) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Executes createProject.
    public func createProject(name: String, completion: @escaping (Bool) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false)
            return
        }
        onCreateProject(trimmed) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                switch result {
                case .success(let project):
                    self.projects = self.dedupeProjects(self.projects + [project])
                    self.selectedProjectID = project.id
                    self.refreshMetadata()
                    self.scheduleAutosave(debounced: false)
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }

    /// Executes createTag.
    public func createTag(name: String, completion: @escaping (Bool) -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false)
            return
        }

        onCreateTag(trimmed) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                switch result {
                case .success(let tag):
                    if let existingIndex = self.tags.firstIndex(where: { $0.id == tag.id }) {
                        self.tags[existingIndex] = tag
                    } else {
                        self.tags.append(tag)
                    }
                    self.tags.sort {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    self.selectedTagIDs.insert(tag.id)
                    self.scheduleAutosave(debounced: false)
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }

    /// Executes createStep.
    public func createStep(title: String, completion: @escaping (Bool) -> Void) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false)
            return
        }

        let request = CreateTaskDefinitionRequest(
            title: trimmed,
            details: nil,
            projectID: selectedProjectID,
            projectName: selectedProjectName,
            lifeAreaID: selectedLifeAreaID,
            sectionID: selectedSectionID,
            dueDate: nil,
            parentTaskID: persistedTask.id,
            tagIDs: Array(selectedTagIDs),
            dependencies: [],
            priority: .low,
            type: selectedType,
            energy: selectedEnergy,
            category: selectedCategory,
            context: selectedContext,
            isEveningTask: selectedType == .evening,
            alertReminderTime: nil,
            estimatedDuration: nil,
            repeatPattern: nil
        )

        onCreateTask(request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false)
                    return
                }
                switch result {
                case .success:
                    self.refreshChildren()
                    completion(true)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }

    /// Executes generateAIBreakdown.
    public func generateAIBreakdown(completion: @escaping () -> Void = {}) {
        guard V2FeatureFlags.assistantBreakdownEnabled else {
            aiBreakdownSteps = []
            aiBreakdownRouteBanner = nil
            completion()
            return
        }

        let service = TaskBreakdownService.shared
        let requestToken = UUID()
        breakdownRequestToken = requestToken
        let surfaceStartedAt = Date()

        let immediate = service.immediateHeuristicSteps(
            taskTitle: taskName,
            taskDetails: taskDescription,
            projectName: selectedProjectName
        )
        aiBreakdownSteps = immediate.steps
        aiBreakdownRouteBanner = immediate.routeBanner
        isGeneratingAIBreakdown = true
        completion()

        logWarning(
            event: "assistant_fast_fallback_used",
            message: "Task breakdown heuristic steps shown instantly",
            fields: [
                "surface": "task_breakdown",
                "used_fallback": "true"
            ]
        )

        Task { [weak self] in
            guard let self else { return }
            let result = await service.refine(
                taskTitle: self.taskName,
                taskDetails: self.taskDescription,
                projectName: self.selectedProjectName
            )
            await MainActor.run {
                guard self.breakdownRequestToken == requestToken else {
                    self.isGeneratingAIBreakdown = false
                    return
                }
                self.aiBreakdownSteps = result.steps
                self.aiBreakdownRouteBanner = result.routeBanner
                self.isGeneratingAIBreakdown = false
                let durationMS = Int(Date().timeIntervalSince(surfaceStartedAt) * 1_000)
                logWarning(
                    event: "assistant_surface_latency",
                    message: "Task breakdown surface updated",
                    fields: [
                        "surface": "task_breakdown",
                        "model": result.modelName ?? "none",
                        "is_cold_start": "unknown",
                        "duration_ms": String(durationMS),
                        "used_fallback": result.modelName == nil ? "true" : "false",
                        "timeout_ms": String(Int(LLMGenerationProfile.breakdown.timeoutSeconds * 1_000))
                    ]
                )
                if result.modelName != nil && service.lastGenerationTimedOut {
                    logWarning(
                        event: "assistant_surface_timeout",
                        message: "Task breakdown refinement timed out",
                        fields: [
                            "surface": "task_breakdown",
                            "model": result.modelName ?? "none",
                            "is_cold_start": "unknown",
                            "duration_ms": String(durationMS),
                            "used_fallback": result.modelName == nil ? "true" : "false",
                            "timeout_ms": String(Int(LLMGenerationProfile.breakdown.timeoutSeconds * 1_000))
                        ]
                    )
                }
                logWarning(
                    event: "assistant_breakdown_generated",
                    message: "Generated task breakdown suggestions",
                    fields: [
                        "count": String(result.steps.count),
                        "model": result.modelName ?? "none"
                    ]
                )
            }
        }
    }

    /// Executes addBreakdownSteps.
    public func addBreakdownSteps(_ steps: [String], completion: @escaping () -> Void = {}) {
        let cleaned = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard cleaned.isEmpty == false else {
            completion()
            return
        }

        let group = DispatchGroup()
        for step in cleaned {
            group.enter()
            createStep(title: step) { _ in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }

    /// Executes toggleStepCompletion.
    public func toggleStepCompletion(_ step: TaskDefinition) {
        onSetCompletion(step.id, !step.isComplete) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let updated):
                    if let index = self.childSteps.firstIndex(where: { $0.id == updated.id }) {
                        self.childSteps[index] = updated
                    }
                    self.childSteps.sort(by: Self.sortSteps)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes deleteStep.
    public func deleteStep(_ step: TaskDefinition) {
        onDelete(step.id, .single) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.childSteps.removeAll { $0.id == step.id }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes moveStepUp.
    public func moveStepUp(_ step: TaskDefinition) {
        guard let index = childSteps.firstIndex(where: { $0.id == step.id }), index > 0 else { return }
        childSteps.swapAt(index, index - 1)
    }

    /// Executes moveStepDown.
    public func moveStepDown(_ step: TaskDefinition) {
        guard let index = childSteps.firstIndex(where: { $0.id == step.id }), index < childSteps.count - 1 else { return }
        childSteps.swapAt(index, index + 1)
    }

    /// Executes performAutosave.
    private func performAutosave() {
        guard !suppressAutosave else { return }

        let trimmedTitle = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            autosaveState = .failed("Task name cannot be empty")
            return
        }

        guard let request = makeUpdateRequest() else {
            autosaveState = .saved
            return
        }

        autosaveState = .saving
        isSaving = true

        onUpdate(persistedTask.id, request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false

                switch result {
                case .success(let updatedTask):
                    self.syncDraftFromTask(updatedTask)
                    self.autosaveState = .saved
                case .failure(let error):
                    self.autosaveState = .failed(error.localizedDescription)
                }

                if self.needsSaveAfterCurrentRequest {
                    self.needsSaveAfterCurrentRequest = false
                    self.scheduleAutosave(debounced: false)
                }
            }
        }
    }

    /// Executes makeUpdateRequest.
    private func makeUpdateRequest() -> UpdateTaskDefinitionRequest? {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDetails = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailsForStorage: String? = normalizedDetails.isEmpty ? "" : taskDescription

        var title: String?
        var details: String?
        var projectID: UUID?
        var lifeAreaID: UUID?
        var clearLifeArea = false
        var sectionID: UUID?
        var clearSection = false
        var dueDateChange: Date?
        var clearDueDate = false
        var parentTaskID: UUID?
        var clearParentTaskLink = false
        var tagIDs: [UUID]?
        var dependencies: [TaskDependencyLinkDefinition]?
        var priority: TaskPriority?
        var type: TaskType?
        var energy: TaskEnergy?
        var category: TaskCategory?
        var context: TaskContext?
        var planningBucket: TaskPlanningBucket?
        var weeklyOutcomeID: UUID?
        var clearWeeklyOutcomeLink = false
        var reminderTimeChange: Date?
        var clearReminderTime = false
        var estimatedDurationChange: TimeInterval?
        var clearEstimatedDuration = false
        var repeatPatternChange: TaskRepeatPattern?
        var clearRepeatPattern = false

        if trimmedName != persistedTask.title {
            title = trimmedName
        }

        if detailsForStorage != persistedTask.details {
            details = detailsForStorage
        }

        if selectedProjectID != persistedTask.projectID {
            projectID = selectedProjectID
        }

        if selectedLifeAreaID != persistedTask.lifeAreaID {
            if let selectedLifeAreaID {
                lifeAreaID = selectedLifeAreaID
            } else if persistedTask.lifeAreaID != nil {
                clearLifeArea = true
            }
        }

        if selectedSectionID != persistedTask.sectionID {
            if let selectedSectionID {
                sectionID = selectedSectionID
            } else if persistedTask.sectionID != nil {
                clearSection = true
            }
        }

        if areDatesDifferent(dueDate, persistedTask.dueDate) {
            if let dueDate {
                dueDateChange = dueDate
            } else if persistedTask.dueDate != nil {
                clearDueDate = true
            }
        }

        if selectedParentTaskID != persistedTask.parentTaskID {
            if let selectedParentTaskID {
                parentTaskID = selectedParentTaskID
            } else if persistedTask.parentTaskID != nil {
                clearParentTaskLink = true
            }
        }

        let normalizedTagIDs = Array(selectedTagIDs).sorted { $0.uuidString < $1.uuidString }
        let persistedTagIDs = persistedTask.tagIDs.sorted { $0.uuidString < $1.uuidString }
        if normalizedTagIDs != persistedTagIDs {
            tagIDs = normalizedTagIDs
        }

        let dependencyIDs = selectedDependencyTaskIDs.sorted { $0.uuidString < $1.uuidString }
        let persistedDependencyIDs = persistedTask.dependencies.map(\.dependsOnTaskID).sorted { $0.uuidString < $1.uuidString }
        let persistedDependencyKinds = Set(persistedTask.dependencies.map(\.kind))
        let dependencyKindChanged = !persistedTask.dependencies.isEmpty && (persistedDependencyKinds.count != 1 || !persistedDependencyKinds.contains(selectedDependencyKind))
        if dependencyIDs != persistedDependencyIDs || dependencyKindChanged {
            dependencies = dependencyIDs.map { dependsOnID in
                TaskDependencyLinkDefinition(
                    taskID: persistedTask.id,
                    dependsOnTaskID: dependsOnID,
                    kind: selectedDependencyKind
                )
            }
        }

        if selectedPriority != persistedTask.priority {
            priority = selectedPriority
        }

        if selectedType != persistedTask.type {
            type = selectedType
        }

        if selectedEnergy != persistedTask.energy {
            energy = selectedEnergy
        }

        if selectedCategory != persistedTask.category {
            category = selectedCategory
        }

        if selectedContext != persistedTask.context {
            context = selectedContext
        }

        if selectedPlanningBucket != persistedTask.planningBucket {
            planningBucket = selectedPlanningBucket
        }

        if selectedWeeklyOutcomeID != persistedTask.weeklyOutcomeID {
            if let selectedWeeklyOutcomeID {
                weeklyOutcomeID = selectedWeeklyOutcomeID
            } else if persistedTask.weeklyOutcomeID != nil {
                clearWeeklyOutcomeLink = true
            }
        }

        if areDatesDifferent(reminderTime, persistedTask.alertReminderTime) {
            if let reminderTime {
                reminderTimeChange = reminderTime
            } else if persistedTask.alertReminderTime != nil {
                clearReminderTime = true
            }
        }

        if areDurationsDifferent(estimatedDuration, persistedTask.estimatedDuration) {
            if let estimatedDuration {
                estimatedDurationChange = estimatedDuration
            } else if persistedTask.estimatedDuration != nil {
                clearEstimatedDuration = true
            }
        }

        if repeatPattern != persistedTask.repeatPattern {
            if let repeatPattern {
                repeatPatternChange = repeatPattern
            } else if persistedTask.repeatPattern != nil {
                clearRepeatPattern = true
            }
        }

        let hasChanges =
            title != nil ||
            details != nil ||
            projectID != nil ||
            lifeAreaID != nil ||
            clearLifeArea ||
            sectionID != nil ||
            clearSection ||
            dueDateChange != nil ||
            clearDueDate ||
            parentTaskID != nil ||
            clearParentTaskLink ||
            tagIDs != nil ||
            dependencies != nil ||
            priority != nil ||
            type != nil ||
            energy != nil ||
            category != nil ||
            context != nil ||
            planningBucket != nil ||
            weeklyOutcomeID != nil ||
            clearWeeklyOutcomeLink ||
            reminderTimeChange != nil ||
            clearReminderTime ||
            estimatedDurationChange != nil ||
            clearEstimatedDuration ||
            repeatPatternChange != nil ||
            clearRepeatPattern

        guard hasChanges else { return nil }

        return UpdateTaskDefinitionRequest(
            id: persistedTask.id,
            title: title,
            details: details,
            projectID: projectID,
            lifeAreaID: lifeAreaID,
            clearLifeArea: clearLifeArea,
            sectionID: sectionID,
            clearSection: clearSection,
            dueDate: dueDateChange,
            clearDueDate: clearDueDate,
            parentTaskID: parentTaskID,
            clearParentTaskLink: clearParentTaskLink,
            tagIDs: tagIDs,
            dependencies: dependencies,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            alertReminderTime: reminderTimeChange,
            clearReminderTime: clearReminderTime,
            estimatedDuration: estimatedDurationChange,
            clearEstimatedDuration: clearEstimatedDuration,
            repeatPattern: repeatPatternChange,
            clearRepeatPattern: clearRepeatPattern,
            planningBucket: planningBucket,
            weeklyOutcomeID: weeklyOutcomeID,
            clearWeeklyOutcomeLink: clearWeeklyOutcomeLink,
            updatedAt: Date()
        )
    }

    /// Executes syncDraftFromTask.
    private func syncDraftFromTask(_ updatedTask: TaskDefinition) {
        suppressAutosave = true

        persistedTask = updatedTask
        taskName = updatedTask.title
        taskDescription = updatedTask.details ?? ""
        selectedPriority = updatedTask.priority
        selectedType = updatedTask.type
        selectedProjectID = updatedTask.projectID
        dueDate = updatedTask.dueDate
        reminderTime = updatedTask.alertReminderTime
        isComplete = updatedTask.isComplete

        selectedLifeAreaID = updatedTask.lifeAreaID
        selectedSectionID = updatedTask.sectionID
        selectedTagIDs = Set(updatedTask.tagIDs)

        selectedParentTaskID = updatedTask.parentTaskID
        selectedDependencyTaskIDs = Set(updatedTask.dependencies.map(\.dependsOnTaskID))
        selectedDependencyKind = updatedTask.dependencies.first?.kind ?? .related
        selectedEnergy = updatedTask.energy
        selectedCategory = updatedTask.category
        selectedContext = updatedTask.context
        selectedPlanningBucket = updatedTask.planningBucket
        selectedWeeklyOutcomeID = updatedTask.weeklyOutcomeID
        estimatedDuration = updatedTask.estimatedDuration
        repeatPattern = updatedTask.repeatPattern
        refreshDisplayProjectName()
        refreshTaskFitHint()

        DispatchQueue.main.async {
            self.suppressAutosave = false
        }
    }

    private func makeTaskDraftForFitHint() -> TaskDefinition {
        var draft = persistedTask
        draft.dueDate = dueDate
        draft.estimatedDuration = estimatedDuration
        draft.updatedAt = Date()
        return draft
    }

    /// Executes dedupeProjects.
    private func dedupeProjects(_ projects: [Project]) -> [Project] {
        var byID: [UUID: Project] = [:]
        for project in projects {
            if let existing = byID[project.id] {
                let keepIncoming =
                    (project.isDefault && !existing.isDefault) ||
                    (project.isInbox && !existing.isInbox)
                if keepIncoming {
                    byID[project.id] = project
                }
            } else {
                byID[project.id] = project
            }
        }
        return Array(byID.values).sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Executes reconcileSelectionAfterMetadataRefresh.
    private func reconcileSelectionAfterMetadataRefresh() {
        if !projects.contains(where: { $0.id == selectedProjectID }) {
            selectedProjectID = projects.first(where: { $0.id == ProjectConstants.inboxProjectID })?.id
                ?? projects.first?.id
                ?? ProjectConstants.inboxProjectID
        }

        if let selectedLifeAreaID, !lifeAreas.contains(where: { $0.id == selectedLifeAreaID }) {
            self.selectedLifeAreaID = nil
        }

        if let selectedSectionID, !sections.contains(where: { $0.id == selectedSectionID }) {
            self.selectedSectionID = nil
        }

        let validTaskIDs = Set(availableTasks.map(\.id))
        if let selectedParentTaskID, !validTaskIDs.contains(selectedParentTaskID) {
            self.selectedParentTaskID = nil
        }

        selectedDependencyTaskIDs = selectedDependencyTaskIDs.intersection(validTaskIDs)
        if let selectedParentTaskID {
            selectedDependencyTaskIDs.remove(selectedParentTaskID)
        }

        let validOutcomeIDs = Set(weeklyOutcomes.map(\.id))
        if let selectedWeeklyOutcomeID, !validOutcomeIDs.contains(selectedWeeklyOutcomeID) {
            self.selectedWeeklyOutcomeID = nil
        }
        if selectedWeeklyOutcomeID != nil && selectedPlanningBucket != .thisWeek {
            selectedPlanningBucket = .thisWeek
        }
    }

    private func refreshDisplayProjectName() {
        displayProjectName = projects.first(where: { $0.id == selectedProjectID })?.name
            ?? persistedTask.projectName
            ?? ProjectConstants.inboxProjectName
    }

    private static func defaultExpandedDisclosureSections(for task: TaskDefinition) -> Set<TaskDetailDisclosureSection> {
        var sections: Set<TaskDetailDisclosureSection> = []
        if task.subtasks.isEmpty == false {
            sections.insert(.steps)
        }
        return sections
    }

    private static func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func durationLabel(for duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainder) min"
    }

    /// Executes sortTasksByDueThenName.
    private static func sortTasksByDueThenName(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        let lhsDue = lhs.dueDate ?? Date.distantFuture
        let rhsDue = rhs.dueDate ?? Date.distantFuture
        if lhsDue == rhsDue {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhsDue < rhsDue
    }

    /// Executes sortSteps.
    private static func sortSteps(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.isComplete != rhs.isComplete {
            return !lhs.isComplete
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    /// Executes areDatesDifferent.
    private func areDatesDifferent(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case let (left?, right?):
            return abs(left.timeIntervalSince(right)) > 0.5
        default:
            return true
        }
    }

    /// Executes areDurationsDifferent.
    private func areDurationsDifferent(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case let (left?, right?):
            return abs(left - right) > 0.5
        default:
            return true
        }
    }
}
