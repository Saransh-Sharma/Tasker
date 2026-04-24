//
//  AddTaskViewModel.swift
//  Tasker
//
//  ViewModel for Add Task screen - manages task creation workflow
//

import Foundation
import Combine

public enum AddTaskPrefillDueIntent: Equatable {
    case none
    case today
    case exact(Date)

    func resolvedDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .today:
            return DatePreset.today.resolvedDueDate(anchorDate: now, calendar: calendar)
        case .exact(let date):
            return date
        }
    }
}

public struct AddTaskPrefillTemplate: Equatable {
    public let title: String
    public let details: String?
    public let projectID: UUID?
    public let projectName: String?
    public let lifeAreaID: UUID?
    public let priority: TaskPriority
    public let type: TaskType
    public let dueDateIntent: AddTaskPrefillDueIntent
    public let estimatedDuration: TimeInterval?
    public let energy: TaskEnergy
    public let category: TaskCategory
    public let context: TaskContext
    public let expandedSections: Set<TaskEditorSection>?
    public let showMoreDetails: Bool
    public let showAdvancedPlanning: Bool

    /// Initializes a new instance.
    public init(
        title: String,
        details: String? = nil,
        projectID: UUID? = nil,
        projectName: String? = nil,
        lifeAreaID: UUID? = nil,
        priority: TaskPriority = .low,
        type: TaskType = .morning,
        dueDateIntent: AddTaskPrefillDueIntent? = nil,
        dueDate: Date? = Date(),
        estimatedDuration: TimeInterval? = nil,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        expandedSections: Set<TaskEditorSection>? = nil,
        showMoreDetails: Bool = false,
        showAdvancedPlanning: Bool = false
    ) {
        self.title = title
        self.details = details
        self.projectID = projectID
        self.projectName = projectName
        self.lifeAreaID = lifeAreaID
        self.priority = priority
        self.type = type
        if let dueDateIntent {
            self.dueDateIntent = dueDateIntent
        } else if let dueDate {
            self.dueDateIntent = .exact(dueDate)
        } else {
            self.dueDateIntent = .none
        }
        self.estimatedDuration = estimatedDuration
        self.energy = energy
        self.category = category
        self.context = context
        self.expandedSections = expandedSections
        self.showMoreDetails = showMoreDetails
        self.showAdvancedPlanning = showAdvancedPlanning
    }

    public var dueDate: Date? {
        dueDateIntent.resolvedDate()
    }
}

/// ViewModel for the Add Task screen
/// Manages task creation state and validation
public final class AddTaskViewModel: ObservableObject {
    public static let defaultEstimatedDuration: TimeInterval = 15 * 60

    private struct TaskIconSearchCacheKey: Equatable {
        let query: String
        let preferredSymbols: [String]
    }
    
    // MARK: - Published Properties (Observable State)
    
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var sections: [TaskerProjectSection] = []
    @Published public private(set) var tags: [TagDefinition] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isTaskCreated: Bool = false
    @Published public private(set) var validationErrors: [ValidationError] = []
    @Published public private(set) var todayXPSoFar: Int? = nil
    @Published public private(set) var availableWeeklyOutcomes: [WeeklyOutcome] = []
    @Published var aiSuggestion: TaskFieldSuggestion?
    @Published var isGeneratingSuggestion: Bool = false
    @Published public private(set) var aiSuggestionIsRefined: Bool = false
    @Published var taskIconSearchQuery: String = ""
    @Published private(set) var selectedTaskIconSymbolName: String = "checklist"
    @Published private(set) var autoSuggestedTaskIconSymbolName: String?
    @Published private(set) var taskIconSelectionSource: TaskIconSelectionSource = .auto
    @Published private(set) var suggestedTaskIcons: [TaskIconOption] = []
    
    // Form state — Primary Capture
    @Published public var taskName: String = ""
    @Published public var taskDetails: String = ""
    @Published public var selectedPriority: TaskPriority = .low
    @Published public var selectedType: TaskType = .morning
    @Published public var selectedProject: String = "Inbox"
    @Published public var dueDate: Date?
    @Published public var scheduledStartAt: Date?
    @Published public var hasReminder: Bool = false
    @Published public var reminderTime: Date = Date()

    // Form state — Organize
    @Published public var selectedLifeAreaID: UUID?
    @Published public var selectedSectionID: UUID?
    @Published public var selectedTagIDs: Set<UUID> = []

    // Form state — Relationships / Execution
    @Published public var selectedParentTaskID: UUID?
    @Published public var selectedDependencyTaskIDs: Set<UUID> = []
    @Published public var selectedDependencyKind: TaskDependencyKind = .related
    @Published public var selectedEnergy: TaskEnergy = .medium
    @Published public var selectedCategory: TaskCategory = .general
    @Published public var selectedContext: TaskContext = .anywhere
    @Published public var estimatedDuration: TimeInterval?
    @Published public var repeatPattern: TaskRepeatPattern? = nil
    @Published public var selectedPlanningBucket: TaskPlanningBucket = .thisWeek
    @Published public var selectedWeeklyOutcomeID: UUID? {
        didSet {
            if selectedWeeklyOutcomeID != nil {
                selectedPlanningBucket = .thisWeek
            }
        }
    }

    // UI state
    @Published public var expandedSections: Set<TaskEditorSection> = []
    @Published public var isCoreDetailsExpanded: Bool = false
    @Published public private(set) var lastCreatedTaskID: UUID? = nil

    // Read-only loaded data
    @Published public private(set) var availableParentTasks: [TaskDefinition] = []
    @Published public private(set) var availableDependencyTasks: [TaskDefinition] = []

    public var scheduledEndAt: Date? {
        guard let scheduledStartAt,
              let estimatedDuration,
              estimatedDuration > 0 else { return nil }
        return scheduledStartAt.addingTimeInterval(estimatedDuration)
    }

    /// True when the form has any user-entered content (used for discard confirmation)
    public var hasUnsavedChanges: Bool {
        !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || selectedPriority != .low
        || selectedType != .morning
        || selectedProject != "Inbox"
        || areDatesDifferent(scheduledStartAt, pristineScheduledStartAt)
        || hasReminder
        || selectedLifeAreaID != nil
        || selectedTagIDs.isEmpty == false
        || selectedParentTaskID != nil
        || selectedDependencyTaskIDs.isEmpty == false
        || areDurationsDifferent(estimatedDuration, pristineEstimatedDuration)
        || repeatPattern != nil
        || selectedPlanningBucket != .thisWeek
        || selectedWeeklyOutcomeID != nil
    }

    public var scheduleSummary: String {
        var parts: [String] = []
        if let scheduledStartAt {
            parts.append(Self.scheduleDateTimeSummary(start: scheduledStartAt, end: scheduledEndAt))
        } else if let dueDate {
            parts.append(DateUtils.formatDate(dueDate))
        } else {
            parts.append("No schedule")
        }
        if hasReminder {
            parts.append(formatTime(reminderTime))
        }
        if selectedType != .morning {
            parts.append(selectedType.displayName)
        }
        if let repeatPattern {
            parts.append(repeatPattern.displayName)
        }
        return parts.joined(separator: ", ")
    }

    public var organizeSummary: String {
        var parts = [selectedProject]
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
        if selectedPlanningBucket != .thisWeek || selectedWeeklyOutcomeID != nil {
            parts.append(selectedPlanningBucket.rawValue.replacingOccurrences(of: "Week", with: " Week").capitalized)
        }
        return parts.joined(separator: ", ")
    }

    var displayedTaskIconSymbolName: String {
        selectedTaskIconSymbolName
    }

    var displayedTaskIconLabel: String {
        taskIconResolver.option(for: displayedTaskIconSymbolName)?.displayName
            ?? DefaultTaskIconResolver.humanizedDisplayName(for: displayedTaskIconSymbolName)
    }

    var preferredTaskIconSearchSymbols: [String] {
        [
            selectedTaskIconSymbolName,
            autoSuggestedTaskIconSymbolName,
            selectedProjectObject?.icon.systemImageName,
            categoryFallbackTaskIconSymbolName
        ]
        .compactMap { $0 }
    }

    var availableTaskIconOptions: [TaskIconOption] {
        let cacheKey = TaskIconSearchCacheKey(
            query: taskIconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            preferredSymbols: preferredTaskIconSearchSymbols
        )
        if let taskIconSearchCache, taskIconSearchCache.key == cacheKey {
            return taskIconSearchCache.options
        }

        let options = taskIconResolver.search(
            query: taskIconSearchQuery,
            preferredSymbols: preferredTaskIconSearchSymbols,
            limit: 60
        )
        taskIconSearchCache = (cacheKey, options)
        return options
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

    public var inboxProject: Project? {
        projects.first(where: { $0.id == ProjectConstants.inboxProjectID })
    }

    var selectedProjectObject: Project? {
        projects.first(where: { $0.name == selectedProject })
    }

    var categoryFallbackTaskIconSymbolName: String? {
        switch selectedCategory {
        case .work:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .personal:
            return "person.fill"
        case .learning:
            return "book.fill"
        case .creative:
            return "paintpalette.fill"
        case .social:
            return "person.2.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .shopping:
            return "cart.fill"
        case .finance:
            return "dollarsign.circle.fill"
        case .general:
            return nil
        }
    }

    public var filteredProjectsForSelectedLifeArea: [Project] {
        projects.filter { project in
            guard project.id != ProjectConstants.inboxProjectID else { return false }
            guard let selectedLifeAreaID else { return true }
            return project.lifeAreaID == selectedLifeAreaID
        }
    }
    
    // MARK: - Dependencies
    
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase
    private let buildWeeklyPlanSnapshotUseCase: BuildWeeklyPlanSnapshotUseCase?
    private let rescheduleTaskDefinitionUseCase: RescheduleTaskDefinitionUseCase?
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase?
    private let manageSectionsUseCase: ManageSectionsUseCase?
    private let manageTagsUseCase: ManageTagsUseCase?
    private let gamificationEngine: GamificationEngine?
    private let aiSuggestionService: AISuggestionService?
    private let taskIconResolver: TaskIconResolver
    private let isAISuggestionRefinementReady: @MainActor () -> Bool
    private let nowProvider: () -> Date
    private let taskIconResolutionQueue = DispatchQueue(label: "tasker.add-task-icon-resolution", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var suggestionTask: Task<Void, Never>?
    private var suggestionRequestToken = UUID()
    private var pendingPrefillTemplate: AddTaskPrefillTemplate?
    private let suggestionDebounceMilliseconds = 650
    private let taskIconDebounceMilliseconds = 140
    private var loadedTaskMetadataProjectID: UUID?
    private var pristineScheduledStartAt: Date?
    private var pristineEstimatedDuration: TimeInterval?
    private var taskIconSearchCache: (key: TaskIconSearchCacheKey, options: [TaskIconOption])?
    private var lastTaskIconLogSignature: String?
    private var taskIconResolutionToken: Int = 0
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        manageProjectsUseCase: ManageProjectsUseCase,
        createTaskDefinitionUseCase: CreateTaskDefinitionUseCase,
        buildWeeklyPlanSnapshotUseCase: BuildWeeklyPlanSnapshotUseCase? = nil,
        rescheduleTaskDefinitionUseCase: RescheduleTaskDefinitionUseCase? = nil,
        manageLifeAreasUseCase: ManageLifeAreasUseCase? = nil,
        manageSectionsUseCase: ManageSectionsUseCase? = nil,
        manageTagsUseCase: ManageTagsUseCase? = nil,
        gamificationEngine: GamificationEngine? = nil,
        aiSuggestionService: AISuggestionService? = nil,
        taskIconResolver: TaskIconResolver = DefaultTaskIconResolver.shared,
        nowProvider: @escaping () -> Date = Date.init,
        isAISuggestionRefinementReady: (@MainActor () -> Bool)? = nil
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.manageProjectsUseCase = manageProjectsUseCase
        self.createTaskDefinitionUseCase = createTaskDefinitionUseCase
        self.buildWeeklyPlanSnapshotUseCase = buildWeeklyPlanSnapshotUseCase
        self.rescheduleTaskDefinitionUseCase = rescheduleTaskDefinitionUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageSectionsUseCase = manageSectionsUseCase
        self.manageTagsUseCase = manageTagsUseCase
        self.gamificationEngine = gamificationEngine
        self.aiSuggestionService = aiSuggestionService
        self.taskIconResolver = taskIconResolver
        self.nowProvider = nowProvider
        self.isAISuggestionRefinementReady = isAISuggestionRefinementReady ?? {
            let evaluator = LLMRuntimeCoordinator.shared.evaluator
            return evaluator.loadedModelName != nil && evaluator.runtimePhase != .preparing
        }

        applyDefaultScheduleAsPristine()
        reminderTime = nowProvider()

        setupValidation()
        setupAISuggestionPipeline()
        setupTaskIconPipeline()
        setupGamificationXPObservation()
        if V2FeatureFlags.autoTaskIconsEnabled {
            taskIconResolver.warmIfNeeded()
        }
        loadProjects()
        loadLifeAreas()
        loadTags()
        loadWeeklyPlanningOptions()
        refreshTaskIcon(using: taskName, logEvents: false)
    }

    deinit {
        suggestionTask?.cancel()
    }
    
    // MARK: - Public Methods

    public func setScheduledDate(_ date: Date, calendar: Calendar = .current) {
        let currentStart = scheduledStartAt ?? Self.defaultScheduledStart(now: nowProvider(), calendar: calendar)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: currentStart)
        let day = calendar.startOfDay(for: date)
        let updated = calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: day
        ) ?? currentStart
        scheduledStartAt = Self.clearingSubminuteComponents(updated, calendar: calendar)
        dueDate = scheduledStartAt
    }

    public func setScheduledStartTime(_ time: Date, calendar: Calendar = .current) {
        let currentStart = scheduledStartAt ?? Self.defaultScheduledStart(now: nowProvider(), calendar: calendar)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let updated = calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: currentStart
        ) ?? currentStart
        scheduledStartAt = Self.clearingSubminuteComponents(updated, calendar: calendar)
        dueDate = scheduledStartAt
    }

    public func setEstimatedDuration(_ duration: TimeInterval?) {
        guard let duration else {
            estimatedDuration = nil
            return
        }
        estimatedDuration = max(60, duration)
    }

    public func clearSchedule() {
        scheduledStartAt = nil
        dueDate = nil
    }

    public func restoreDefaultSchedule() {
        let start = Self.defaultScheduledStart(now: nowProvider())
        scheduledStartAt = start
        dueDate = start
        estimatedDuration = Self.defaultEstimatedDuration
    }
    
    /// Create a new task
    public func createTask() {
        guard validateInput() else {
            return
        }

        lastCreatedTaskID = nil
        isTaskCreated = false
        isLoading = true
        errorMessage = nil
        
        // Resolve projectID from selectedProject name
        let projectID = projects.first(where: { $0.name == selectedProject })?.id ?? ProjectConstants.inboxProjectID

        let resolvedTagIDs = selectedTagIDs.isEmpty ? parseImplicitTagIDs(from: taskName) : selectedTagIDs
        let requestID = UUID()
        let resolvedScheduledStartAt = scheduledStartAt
        let resolvedScheduledEndAt = scheduledEndAt
        let definitionRequest = CreateTaskDefinitionRequest(
            id: requestID,
            title: taskName,
            details: taskDetails.isEmpty ? nil : taskDetails,
            projectID: projectID,
            projectName: selectedProject,
            iconSymbolName: V2FeatureFlags.autoTaskIconsEnabled ? displayedTaskIconSymbolName : nil,
            lifeAreaID: selectedLifeAreaID,
            sectionID: selectedSectionID,
            dueDate: resolvedScheduledStartAt ?? dueDate,
            scheduledStartAt: resolvedScheduledStartAt,
            scheduledEndAt: resolvedScheduledEndAt,
            isAllDay: false,
            parentTaskID: selectedParentTaskID,
            tagIDs: Array(resolvedTagIDs),
            dependencies: selectedDependencyTaskIDs.map { dependsOnTaskID in
                TaskDependencyLinkDefinition(
                    taskID: requestID,
                    dependsOnTaskID: dependsOnTaskID,
                    kind: selectedDependencyKind
                )
            },
            priority: selectedPriority,
            type: selectedType,
            energy: selectedEnergy,
            category: selectedCategory,
            context: selectedContext,
            isEveningTask: selectedType == .evening,
            alertReminderTime: hasReminder ? reminderTime : nil,
            estimatedDuration: estimatedDuration,
            repeatPattern: repeatPattern,
            planningBucket: selectedPlanningBucket,
            weeklyOutcomeID: selectedWeeklyOutcomeID
        )

        createTaskDefinitionUseCase.execute(
            request: definitionRequest
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    self?.lastCreatedTaskID = requestID
                    self?.isTaskCreated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes parseImplicitTagIDs.
    private func parseImplicitTagIDs(from title: String) -> Set<UUID> {
        let tokens = title
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { $0.hasPrefix("#") && $0.count > 1 }
            .map { String($0.dropFirst()).lowercased() }
        guard tokens.isEmpty == false else { return [] }
        let tokenSet = Set(tokens)
        return Set(tags.compactMap { tag in
            tokenSet.contains(tag.name.lowercased()) ? tag.id : nil
        })
    }
    
    /// Load available projects
    public func loadProjects() {
        manageProjectsUseCase.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectsWithStats):
                    let mappedProjects = projectsWithStats.map { $0.project }
                    let dedupedProjects = self?.dedupeProjects(mappedProjects) ?? mappedProjects
                    if dedupedProjects.count != mappedProjects.count {
                        logWarning(
                            event: "add_task_projects_deduped",
                            message: "Duplicate project IDs detected in AddTaskViewModel; using deduped project list",
                            fields: [
                                "before_count": String(mappedProjects.count),
                                "after_count": String(dedupedProjects.count)
                            ]
                        )
                    }
                    self?.projects = dedupedProjects
                    if self?.selectedProject == "Inbox",
                       let inbox = self?.projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
                        self?.selectedProject = inbox.name
                    }
                    if let strongSelf = self,
                       let selectedProjectID = strongSelf.projects.first(where: { $0.name == strongSelf.selectedProject })?.id {
                        strongSelf.loadSections(projectID: selectedProjectID)
                    } else {
                        self?.clearDeferredTaskMetadataOptions()
                    }
                    self?.refreshTaskIcon(using: self?.taskName ?? "", logEvents: false)
                    self?.applyPendingPrefillIfPossible()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new project
    public func createProject(name: String) {
        let request = CreateProjectRequest(name: name)
        
        manageProjectsUseCase.createProject(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.selectedProject = name
                    self?.loadProjects()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Apply a prefill template without bypassing the normal create-task flow.
    @MainActor
    public func applyPrefill(_ template: AddTaskPrefillTemplate) {
        pendingPrefillTemplate = template
        applyPendingPrefillIfPossible()
    }

    /// Create a tag inline from Add Task and select it on success.
    public func createTag(name: String, completion: @escaping (Bool) -> Void) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            completion(false)
            return
        }
        guard let manageTagsUseCase else {
            completion(false)
            return
        }

        manageTagsUseCase.create(name: normalized, color: nil, icon: nil) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdTag):
                    guard let self else {
                        completion(false)
                        return
                    }
                    if let existingIndex = self.tags.firstIndex(where: { $0.id == createdTag.id }) {
                        self.tags[existingIndex] = createdTag
                    } else {
                        self.tags.append(createdTag)
                    }
                    self.tags.sort {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    self.selectedTagIDs.insert(createdTag.id)
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    /// Reschedule task (for editing existing tasks)
    public func rescheduleTask(_ taskId: UUID, to newDate: Date) {
        guard let rescheduleTaskDefinitionUseCase else {
            errorMessage = "Task rescheduling is not configured."
            return
        }

        isLoading = true

        rescheduleTaskDefinitionUseCase.execute(taskID: taskId, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    // Task rescheduled successfully
                    break
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Reset form to initial state
    public func resetForm() {
        if aiSuggestion != nil {
            logWarning(
                event: "assistant_suggestion_dismissed",
                message: "Add-task suggestion dismissed during form reset",
                fields: ["reason": "form_reset"]
            )
        }
        suggestionTask?.cancel()
        taskName = ""
        taskDetails = ""
        selectedPriority = .low
        selectedType = .morning
        selectedProject = "Inbox"
        selectedLifeAreaID = nil
        selectedSectionID = nil
        selectedTagIDs = []
        selectedParentTaskID = nil
        selectedDependencyTaskIDs = []
        selectedDependencyKind = .related
        selectedEnergy = .medium
        selectedCategory = .general
        selectedContext = .anywhere
        repeatPattern = nil
        selectedPlanningBucket = .thisWeek
        selectedWeeklyOutcomeID = nil
        applyDefaultScheduleAsPristine()
        hasReminder = false
        reminderTime = nowProvider()
        expandedSections = []
        isCoreDetailsExpanded = false
        validationErrors = []
        errorMessage = nil
        isTaskCreated = false
        lastCreatedTaskID = nil
        pendingPrefillTemplate = nil
        aiSuggestion = nil
        isGeneratingSuggestion = false
        aiSuggestionIsRefined = false
        taskIconSearchQuery = ""
        autoSuggestedTaskIconSymbolName = nil
        taskIconSelectionSource = .auto
        suggestedTaskIcons = []
        taskIconSearchCache = nil
        lastTaskIconLogSignature = nil
        refreshTaskIcon(using: taskName, logEvents: false)
    }

    private func loadWeeklyPlanningOptions() {
        buildWeeklyPlanSnapshotUseCase?.execute(referenceDate: Date()) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let snapshot):
                    self?.availableWeeklyOutcomes = snapshot.outcomes
                case .failure:
                    self?.availableWeeklyOutcomes = []
                }
            }
        }
    }

    /// Executes applyAISuggestion.
    func applyAISuggestion(_ suggestion: TaskFieldSuggestion) {
        selectedPriority = suggestion.priority
        selectedEnergy = suggestion.energy
        selectedType = suggestion.type
        selectedContext = suggestion.context
        logWarning(
            event: "assistant_suggestion_accepted",
            message: "Add-task suggestion accepted",
            fields: [
                "priority": String(suggestion.priority.rawValue),
                "energy": suggestion.energy.rawValue,
                "context": suggestion.context.rawValue,
                "type": String(suggestion.type.rawValue),
                "model": suggestion.modelName ?? "none"
            ]
        )
    }

    public func isSectionExpanded(_ section: TaskEditorSection) -> Bool {
        expandedSections.contains(section)
    }

    public func toggleSection(_ section: TaskEditorSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    public func summary(for section: TaskEditorSection) -> String {
        switch section {
        case .schedule:
            return scheduleSummary
        case .organize:
            return organizeSummary
        case .execution:
            return executionSummary
        case .relationships:
            return relationshipsSummary
        }
    }

    public func loadRelationshipTaskOptionsIfNeeded() {
        guard let projectID = projects.first(where: { $0.name == selectedProject })?.id else {
            clearDeferredTaskMetadataOptions()
            return
        }
        guard loadedTaskMetadataProjectID != projectID else { return }
        loadTaskMetadataOptions(projectID: projectID)
    }
    
    /// Validate input and update validation errors
    @discardableResult
    public func validateInput() -> Bool {
        validationErrors = []
        let now = nowProvider()
        
        // Validate task name
        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(.emptyTaskName)
        } else if taskName.count > 200 {
            validationErrors.append(.taskNameTooLong)
        }
        
        // Validate due date/schedule (nil is valid — "Someday")
        if let scheduledStartAt, scheduledStartAt < now {
            validationErrors.append(.pastDueDate)
        } else if let dueDate, dueDate < Calendar.current.startOfDay(for: now) {
            validationErrors.append(.pastDueDate)
        }
        
        // Validate reminder time
        if hasReminder && reminderTime < now {
            validationErrors.append(.pastReminderTime)
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Executes setupValidation.
    private func setupValidation() {
        // Validate input whenever relevant fields change
        Publishers.CombineLatest4($taskName, $dueDate, $hasReminder, $reminderTime)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateInput()
            }
            .store(in: &cancellables)

        $selectedProject
            .removeDuplicates()
            .sink { [weak self] projectName in
                guard let self else { return }
                if let project = self.projects.first(where: { $0.name == projectName }),
                   project.id != ProjectConstants.inboxProjectID,
                   let projectLifeAreaID = project.lifeAreaID,
                   self.selectedLifeAreaID != projectLifeAreaID {
                    self.selectedLifeAreaID = projectLifeAreaID
                }
                guard let projectID = self.projects.first(where: { $0.name == projectName })?.id else {
                    self.sections = []
                    self.selectedSectionID = nil
                    self.clearDeferredTaskMetadataOptions()
                    return
                }
                self.loadSections(projectID: projectID)
                if self.loadedTaskMetadataProjectID != projectID {
                    self.clearDeferredTaskMetadataOptions()
                    if self.expandedSections.contains(.relationships) {
                        self.loadRelationshipTaskOptionsIfNeeded()
                    }
                }
                self.refreshTaskIcon(using: self.taskName, logEvents: false)
            }
            .store(in: &cancellables)

        $selectedLifeAreaID
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] _ in
                self?.normalizeProjectSelectionForSelectedLifeArea()
                self?.refreshTaskIcon(using: self?.taskName ?? "", logEvents: false)
            }
            .store(in: &cancellables)

        $selectedParentTaskID
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] selectedParentTaskID in
                guard let selectedParentTaskID else { return }
                self?.selectedDependencyTaskIDs.remove(selectedParentTaskID)
            }
            .store(in: &cancellables)
    }

    private func setupTaskIconPipeline() {
        guard V2FeatureFlags.autoTaskIconsEnabled else {
            selectedTaskIconSymbolName = "checklist"
            autoSuggestedTaskIconSymbolName = nil
            suggestedTaskIcons = []
            taskIconSelectionSource = .auto
            return
        }

        Publishers.CombineLatest($taskName, $selectedCategory)
            .debounce(for: .milliseconds(taskIconDebounceMilliseconds), scheduler: RunLoop.main)
            .sink { [weak self] taskName, _ in
                self?.refreshTaskIcon(using: taskName)
            }
            .store(in: &cancellables)
    }

    /// Executes setupAISuggestionPipeline.
    private func setupAISuggestionPipeline() {
        guard V2FeatureFlags.assistantCopilotEnabled, aiSuggestionService != nil else {
            aiSuggestion = nil
            isGeneratingSuggestion = false
            return
        }
        $taskName
            .debounce(for: .milliseconds(suggestionDebounceMilliseconds), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] taskName in
                guard let self else { return }
                Task { @MainActor in
                    self.requestAISuggestionIfNeeded(for: taskName)
                }
            }
            .store(in: &cancellables)
    }

    /// Executes setupGamificationXPObservation.
    private func setupGamificationXPObservation() {
        NotificationCenter.default.publisher(for: .gamificationLedgerDidMutate)
            .compactMap { $0.gamificationLedgerMutation?.dailyXPSoFar }
            .sink { [weak self] dailyXP in
                self?.todayXPSoFar = max(0, dailyXP)
            }
            .store(in: &cancellables)

        guard let gamificationEngine else { return }
        gamificationEngine.fetchTodayXP { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if let dailyXP = try? result.get() {
                    self.todayXPSoFar = max(0, dailyXP)
                }
            }
        }
    }

    /// Executes requestAISuggestionIfNeeded.
    @MainActor
    private func requestAISuggestionIfNeeded(for taskName: String) {
        guard V2FeatureFlags.assistantCopilotEnabled, let aiSuggestionService else {
            aiSuggestion = nil
            isGeneratingSuggestion = false
            aiSuggestionIsRefined = false
            return
        }
        suggestionTask?.cancel()
        let normalized = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 5 else {
            if aiSuggestion != nil {
                logWarning(
                    event: "assistant_suggestion_dismissed",
                    message: "Add-task suggestion dismissed after input change",
                    fields: ["reason": "input_short"]
                )
            }
            aiSuggestion = nil
            isGeneratingSuggestion = false
            aiSuggestionIsRefined = false
            return
        }

        let titleAtRequestStart = normalized
        let requestToken = UUID()
        suggestionRequestToken = requestToken
        let surfaceStartedAt = Date()

        let instant = aiSuggestionService.immediateFieldSuggestion(
            for: titleAtRequestStart,
            projectName: selectedProject
        )
        if let instant {
            aiSuggestion = instant
            aiSuggestionIsRefined = false
            logWarning(
                event: "assistant_fast_fallback_used",
                message: "Add-task instant heuristic suggestion shown",
                fields: [
                    "surface": "add_task",
                    "used_fallback": "true"
                ]
            )
        }

        guard isAISuggestionRefinementReady() else {
            isGeneratingSuggestion = false
            aiSuggestionIsRefined = false
            logWarning(
                event: "assistant_refine_deferred",
                message: "Add-task suggestion refine skipped until AI runtime is warm",
                fields: [
                    "surface": "add_task",
                    "reason": "runtime_not_ready"
                ]
            )
            return
        }

        isGeneratingSuggestion = true
        let refineInterval = TaskerPerformanceTrace.begin("AddTaskSuggestionRefine")
        suggestionTask = Task { [weak self] in
            guard let self else {
                TaskerPerformanceTrace.end(refineInterval)
                return
            }
            let suggestion = await aiSuggestionService.refineFieldSuggestion(
                for: titleAtRequestStart,
                projectName: self.selectedProject
            )
            guard Task.isCancelled == false else {
                TaskerPerformanceTrace.end(refineInterval)
                return
            }

            await MainActor.run {
                defer { TaskerPerformanceTrace.end(refineInterval) }
                guard self.suggestionRequestToken == requestToken else {
                    self.isGeneratingSuggestion = false
                    return
                }
                guard self.taskName.trimmingCharacters(in: .whitespacesAndNewlines) == titleAtRequestStart else {
                    self.isGeneratingSuggestion = false
                    return
                }
                self.aiSuggestion = suggestion
                self.aiSuggestionIsRefined = suggestion?.modelName != nil
                self.isGeneratingSuggestion = false
                let durationMS = Int(Date().timeIntervalSince(surfaceStartedAt) * 1_000)
                logWarning(
                    event: "assistant_surface_latency",
                    message: "Add-task suggestion surface updated",
                    fields: [
                        "surface": "add_task",
                        "model": suggestion?.modelName ?? "none",
                        "is_cold_start": "unknown",
                        "duration_ms": String(durationMS),
                        "used_fallback": self.aiSuggestionIsRefined ? "false" : "true",
                        "timeout_ms": String(Int(LLMGenerationProfile.addTaskSuggestion.timeoutSeconds * 1_000))
                    ]
                )
                if suggestion?.modelName != nil && aiSuggestionService.lastGenerationTimedOut {
                    logWarning(
                        event: "assistant_surface_timeout",
                        message: "Add-task suggestion refine timed out",
                        fields: [
                            "surface": "add_task",
                            "model": suggestion?.modelName ?? "none",
                            "is_cold_start": "unknown",
                            "duration_ms": String(durationMS),
                            "used_fallback": self.aiSuggestionIsRefined ? "false" : "true",
                            "timeout_ms": String(Int(LLMGenerationProfile.addTaskSuggestion.timeoutSeconds * 1_000))
                        ]
                    )
                }
                if let suggestion {
                    logWarning(
                        event: "assistant_suggestion_shown",
                        message: "Add-task suggestion shown",
                        fields: [
                            "confidence": String(format: "%.2f", suggestion.confidence),
                            "priority": String(suggestion.priority.rawValue),
                            "energy": suggestion.energy.rawValue,
                            "context": suggestion.context.rawValue,
                            "type": String(suggestion.type.rawValue),
                            "model": suggestion.modelName ?? "none",
                            "has_route_banner": suggestion.routeBanner == nil ? "false" : "true"
                        ]
                    )
                }
            }
        }
    }

    public func applyManualTaskIconSelection(symbolName: String) {
        selectedTaskIconSymbolName = symbolName
        taskIconSelectionSource = .manual
        taskIconSearchCache = nil
        logWarning(
            event: "task_icon_manual_override",
            message: "Task icon manually overridden in add-task flow",
            fields: ["symbol_name": symbolName]
        )
    }

    public func resetTaskIconToAuto() {
        taskIconSelectionSource = .auto
        taskIconSearchCache = nil
        refreshTaskIcon(using: taskName)
    }

    private func refreshTaskIcon(using taskName: String, logEvents: Bool = true) {
        guard V2FeatureFlags.autoTaskIconsEnabled else {
            selectedTaskIconSymbolName = "checklist"
            autoSuggestedTaskIconSymbolName = nil
            suggestedTaskIcons = []
            taskIconSearchCache = nil
            return
        }

        let projectName = selectedProjectObject?.name
        let projectIconSymbolName = selectedProjectObject?.icon.systemImageName
        let lifeAreaName = selectedLifeAreaID.flatMap { id in
            lifeAreas.first(where: { $0.id == id })?.name
        }
        let category = selectedCategory
        let selectionSource = taskIconSelectionSource
        let currentSymbolName = selectionSource == .auto ? selectedTaskIconSymbolName : autoSuggestedTaskIconSymbolName
        taskIconResolutionToken += 1
        let token = taskIconResolutionToken

        taskIconResolutionQueue.async { [weak self] in
            guard let self else { return }
            let interval = TaskerPerformanceTrace.begin("AddTaskIconResolve")
            let resolution = self.taskIconResolver.resolve(
                title: taskName,
                projectName: projectName,
                projectIconSymbolName: projectIconSymbolName,
                lifeAreaName: lifeAreaName,
                category: category,
                currentSymbolName: currentSymbolName,
                selectionSource: selectionSource
            )
            TaskerPerformanceTrace.end(interval)

            DispatchQueue.main.async {
                guard self.taskIconResolutionToken == token else { return }
                self.autoSuggestedTaskIconSymbolName = resolution.autoSuggestedSymbolName
                self.suggestedTaskIcons = resolution.rankedSuggestions
                self.taskIconSearchCache = nil

                if self.taskIconSelectionSource == .auto {
                    self.selectedTaskIconSymbolName = resolution.selectedSymbolName
                }

                guard logEvents else { return }
                let logSignature = [
                    self.selectedTaskIconSymbolName,
                    self.autoSuggestedTaskIconSymbolName ?? "none",
                    resolution.fallbackReason.rawValue,
                    String(format: "%.2f", resolution.confidence),
                    self.taskIconSelectionSource == .manual ? "manual" : "auto"
                ].joined(separator: "|")
                guard logSignature != self.lastTaskIconLogSignature else { return }
                self.lastTaskIconLogSignature = logSignature

                if resolution.didUseFallback {
                    logDebug(
                        event: "task_icon_fallback_used",
                        message: "Task icon resolver used fallback icon",
                        fields: [
                            "symbol_name": resolution.selectedSymbolName,
                            "fallback": resolution.fallbackReason.rawValue,
                            "confidence": String(format: "%.2f", resolution.confidence)
                        ]
                    )
                } else {
                    logDebug(
                        event: "task_icon_auto_suggested",
                        message: "Task icon resolver suggested semantic icon",
                        fields: [
                            "symbol_name": resolution.selectedSymbolName,
                            "confidence": String(format: "%.2f", resolution.confidence)
                        ]
                    )
                }
            }
        }
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

    /// Executes loadLifeAreas.
    private func loadLifeAreas() {
        manageLifeAreasUseCase?.list { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let areas):
                    guard let self else { return }
                    let activeAreas = areas.filter { !$0.isArchived }
                    let dedupedAreas = self.dedupeLifeAreasByNormalizedName(
                        activeAreas,
                        preferredID: self.selectedLifeAreaID
                    )
                    if dedupedAreas.count != activeAreas.count {
                        logWarning(
                            event: "add_task_life_areas_deduped",
                            message: "Duplicate life-area names detected in AddTaskViewModel; using deduped life-area list",
                            fields: [
                                "before_count": String(activeAreas.count),
                                "after_count": String(dedupedAreas.count)
                            ]
                        )
                    }
                    self.lifeAreas = dedupedAreas
                    if let selectedLifeAreaID = self.selectedLifeAreaID,
                       dedupedAreas.contains(where: { $0.id == selectedLifeAreaID }) {
                        // Keep existing selection when the selected life-area survives dedupe.
                    } else if let selectedLifeAreaID = self.selectedLifeAreaID,
                              let selectedArea = activeAreas.first(where: { $0.id == selectedLifeAreaID }) {
                        let normalizedName = self.normalizedLifeAreaName(selectedArea.name)
                        self.selectedLifeAreaID = dedupedAreas.first(where: {
                            self.normalizedLifeAreaName($0.name) == normalizedName
                        })?.id
                    } else {
                        self.selectedLifeAreaID = nil
                    }
                    self.refreshTaskIcon(using: self.taskName, logEvents: false)
                    self.applyPendingPrefillIfPossible()
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes dedupeLifeAreasByNormalizedName.
    private func dedupeLifeAreasByNormalizedName(
        _ lifeAreas: [LifeArea],
        preferredID: UUID?
    ) -> [LifeArea] {
        var chosenByName: [String: LifeArea] = [:]

        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard let existing = chosenByName[normalizedName] else {
                chosenByName[normalizedName] = lifeArea
                continue
            }

            if existing.id == preferredID {
                continue
            }
            if lifeArea.id == preferredID {
                chosenByName[normalizedName] = lifeArea
            }
        }

        var emitted = Set<String>()
        var deduped: [LifeArea] = []
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard chosenByName[normalizedName]?.id == lifeArea.id else { continue }
            guard emitted.insert(normalizedName).inserted else { continue }
            deduped.append(lifeArea)
        }
        return deduped
    }

    /// Executes normalizedLifeAreaName.
    private func normalizedLifeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "General" : trimmed).lowercased()
    }

    /// Executes applyPendingPrefillIfPossible.
    private func applyPendingPrefillIfPossible() {
        guard let template = pendingPrefillTemplate else { return }

        taskName = template.title
        taskDetails = template.details ?? ""
        selectedPriority = template.priority
        selectedType = template.type
        selectedEnergy = template.energy
        selectedCategory = template.category
        selectedContext = template.context
        estimatedDuration = template.estimatedDuration ?? Self.defaultEstimatedDuration
        applyPrefillDueDate(template.dueDateIntent.resolvedDate(now: nowProvider()))
        isCoreDetailsExpanded = (template.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)

        var resolvedAllSelections = true

        if let lifeAreaID = template.lifeAreaID {
            selectedLifeAreaID = lifeAreaID
            if lifeAreas.contains(where: { $0.id == lifeAreaID }) {
                // Keep the explicit prefill selection.
            } else {
                resolvedAllSelections = false
            }
        }

        if let project = resolveProjectForPrefill(template) {
            selectedProject = project.name
            if let projectLifeAreaID = project.lifeAreaID {
                selectedLifeAreaID = template.lifeAreaID ?? projectLifeAreaID
            }
            loadSections(projectID: project.id)
            loadTaskMetadataOptions(projectID: project.id)
        } else if hasNonEmptyProjectName(template) {
            resolvedAllSelections = false
        } else if template.projectID != nil {
            resolvedAllSelections = false
        }

        validationErrors = []
        errorMessage = nil
        expandedSections = resolvedExpandedSections(for: template)

        if resolvedAllSelections {
            pendingPrefillTemplate = nil
        }
    }

    private func resolvedExpandedSections(for template: AddTaskPrefillTemplate) -> Set<TaskEditorSection> {
        var sections = template.expandedSections ?? []
        if template.showMoreDetails {
            sections.insert(.organize)
        }
        if template.showAdvancedPlanning {
            sections.formUnion([.schedule, .execution, .relationships])
        }
        sections.formUnion(derivedExpandedSections())
        return sections
    }

    private func derivedExpandedSections() -> Set<TaskEditorSection> {
        var sections = Set<TaskEditorSection>()

        if hasReminder || repeatPattern != nil || selectedType != .morning {
            sections.insert(.schedule)
        }

        if selectedProject != ProjectConstants.inboxProjectName
            || selectedLifeAreaID != nil
            || selectedSectionID != nil
            || selectedTagIDs.isEmpty == false {
            sections.insert(.organize)
        }

        if selectedEnergy != .medium
            || selectedCategory != .general
            || selectedContext != .anywhere
            || areDurationsDifferent(estimatedDuration, Self.defaultEstimatedDuration) {
            sections.insert(.execution)
        }

        if selectedParentTaskID != nil || selectedDependencyTaskIDs.isEmpty == false {
            sections.insert(.relationships)
        }

        return sections
    }

    private func applyDefaultScheduleAsPristine(calendar: Calendar = .current) {
        let start = Self.defaultScheduledStart(now: nowProvider(), calendar: calendar)
        scheduledStartAt = start
        dueDate = start
        estimatedDuration = Self.defaultEstimatedDuration
        pristineScheduledStartAt = start
        pristineEstimatedDuration = Self.defaultEstimatedDuration
    }

    private func applyPrefillDueDate(_ date: Date?, calendar: Calendar = .current) {
        guard let date else {
            clearSchedule()
            return
        }
        if TaskScheduleNormalizer.isDateOnly(date, calendar: calendar) {
            setScheduledDate(date, calendar: calendar)
        } else {
            let start = Self.clearingSubminuteComponents(date, calendar: calendar)
            scheduledStartAt = start
            dueDate = start
        }
    }

    public static func defaultScheduledStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.date(byAdding: .minute, value: 20, to: now) ?? now.addingTimeInterval(20 * 60)
        return clearingSubminuteComponents(start, calendar: calendar)
    }

    public static func scheduleRangeLabel(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let end else {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    public static func scheduleDateTimeSummary(start: Date, end: Date?) -> String {
        let dateText = DateUtils.formatDate(start)
        let rangeText = scheduleRangeLabel(start: start, end: end)
        return "\(dateText), \(rangeText)"
    }

    private static func clearingSubminuteComponents(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private func areDatesDifferent(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return false
        case let (.some(lhs), .some(rhs)):
            return abs(lhs.timeIntervalSince(rhs)) >= 1
        default:
            return true
        }
    }

    private func areDurationsDifferent(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return false
        case let (.some(lhs), .some(rhs)):
            return abs(lhs - rhs) >= 1
        default:
            return true
        }
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Executes resolveProjectForPrefill.
    private func resolveProjectForPrefill(_ template: AddTaskPrefillTemplate) -> Project? {
        if let projectID = template.projectID,
           let project = projects.first(where: { $0.id == projectID }) {
            return project
        }

        guard let projectName = template.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
              projectName.isEmpty == false else {
            return nil
        }

        let normalizedProjectName = projectName.lowercased()
        return projects.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedProjectName
        })
    }

    private func hasNonEmptyProjectName(_ template: AddTaskPrefillTemplate) -> Bool {
        guard let projectName = template.projectName else { return false }
        return projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func normalizeProjectSelectionForSelectedLifeArea() {
        guard selectedProject != ProjectConstants.inboxProjectName else { return }
        guard let selectedProjectModel = projects.first(where: { $0.name == selectedProject }) else {
            selectedProject = ProjectConstants.inboxProjectName
            return
        }
        guard let selectedLifeAreaID else { return }
        if selectedProjectModel.lifeAreaID != selectedLifeAreaID {
            selectedProject = ProjectConstants.inboxProjectName
        }
    }

    /// Executes loadSections.
    private func loadSections(projectID: UUID) {
        manageSectionsUseCase?.list(projectID: projectID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let sections):
                    self?.sections = sections.sorted(by: { $0.sortOrder < $1.sortOrder })
                    if let selected = self?.selectedSectionID,
                       sections.contains(where: { $0.id == selected }) == false {
                        self?.selectedSectionID = nil
                    }
                    if self?.selectedSectionID == nil {
                        self?.selectedSectionID = self?.sections.first?.id
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTags.
    private func loadTags() {
        manageTagsUseCase?.list { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tags):
                    self?.tags = tags.sorted(by: { $0.sortOrder < $1.sortOrder })
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTaskMetadataOptions.
    private func loadTaskMetadataOptions(projectID: UUID) {
        guard let taskReadModelRepository else {
            clearDeferredTaskMetadataOptions()
            return
        }

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                projectID: projectID,
                includeCompleted: false,
                sortBy: .dueDateAscending,
                limit: 400,
                offset: 0
            )
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let slice):
                    let activeTasks = slice.tasks
                        .filter { !$0.isComplete }
                        .sorted(by: { (lhs: TaskDefinition, rhs: TaskDefinition) in
                            let lhsDate = lhs.dueDate ?? Date.distantFuture
                            let rhsDate = rhs.dueDate ?? Date.distantFuture
                            if lhsDate == rhsDate {
                                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                            }
                            return lhsDate < rhsDate
                        })
                    self.availableParentTasks = activeTasks
                    self.availableDependencyTasks = activeTasks
                    self.loadedTaskMetadataProjectID = projectID

                    let validIDs = Set(activeTasks.map(\.id))
                    if let selectedParentTaskID = self.selectedParentTaskID, !validIDs.contains(selectedParentTaskID) {
                        self.selectedParentTaskID = nil
                    }
                    self.selectedDependencyTaskIDs = self.selectedDependencyTaskIDs.intersection(validIDs)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.clearDeferredTaskMetadataOptions()
                }
            }
        }
    }

    private func clearDeferredTaskMetadataOptions() {
        loadedTaskMetadataProjectID = nil
        availableParentTasks = []
        availableDependencyTasks = []
        selectedParentTaskID = nil
        selectedDependencyTaskIDs = []
    }

    /// Executes loadCalendarTaskCounts.
    public func loadCalendarTaskCounts(
        windowStart: Date,
        windowEnd: Date,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let taskReadModelRepository else {
            completion([:])
            return
        }

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: windowStart,
                dueDateEnd: windowEnd,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            let tasks = (try? result.get().tasks) ?? []
            let calendar = Calendar.current
            let counts = tasks.reduce(into: [Date: Int]()) { grouped, task in
                guard let dueDate = task.dueDate else { return }
                grouped[calendar.startOfDay(for: dueDate), default: 0] += 1
            }
            DispatchQueue.main.async {
                completion(counts)
            }
        }
    }
}

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case emptyTaskName
    case taskNameTooLong
    case pastDueDate
    case pastReminderTime
    
    public var errorDescription: String? {
        switch self {
        case .emptyTaskName:
            return "Task name cannot be empty"
        case .taskNameTooLong:
            return "Task name is too long (max 200 characters)"
        case .pastDueDate:
            return "Due date cannot be in the past"
        case .pastReminderTime:
            return "Reminder time cannot be in the past"
        }
    }
}

// MARK: - View State

extension AddTaskViewModel {
    
    /// Combined state for the view
    public var viewState: AddTaskViewState {
        return AddTaskViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            isTaskCreated: isTaskCreated,
            validationErrors: validationErrors,
            projects: projects,
            lifeAreas: lifeAreas,
            sections: sections,
            tags: tags,
            canSubmit: validationErrors.isEmpty && !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

/// State structure for the add task view
public struct AddTaskViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let isTaskCreated: Bool
    public let validationErrors: [ValidationError]
    public let projects: [Project]
    public let lifeAreas: [LifeArea]
    public let sections: [TaskerProjectSection]
    public let tags: [TagDefinition]
    public let canSubmit: Bool
}
