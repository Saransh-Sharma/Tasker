//
//  AddTaskViewModel.swift
//  LifeBoard
//
//  ViewModel for Add Task screen - manages task creation workflow
//

import Foundation
import Combine

public enum AddTaskCreationError: Error, Equatable {
    case invalidInput
}

/// ViewModel for the Add Task screen
/// Manages task creation state and validation
@MainActor
public final class AddTaskViewModel: ObservableObject {
    public static let defaultEstimatedDuration: TimeInterval = 15 * 60

    private struct TaskIconSearchCacheKey: Equatable {
        let query: String
        let preferredSymbols: [String]
    }

    // MARK: - Published Properties (Observable State)

    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var sections: [ProjectSectionDefinition] = []
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
    @Published public var selectedProjectID: UUID = ProjectConstants.inboxProjectID
    @Published public var plannedDate: Date?
    private var creationRequestID = UUID()
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
        || selectedProjectID != ProjectConstants.inboxProjectID
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
        } else if let plannedDate {
            parts.append(DateUtils.formatDate(plannedDate))
        } else {
            parts.append(String(localized: "No schedule"))
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
            parts.append(selectedTagIDs.count == 1 ? String(localized: "1 tag") : String(localized: "\(selectedTagIDs.count) tags"))
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
            parts.append(Self.planningBucketTitle(selectedPlanningBucket))
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
        projects.first(where: { $0.id == selectedProjectID })
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

    public func selectProject(id: UUID?) {
        guard let id else {
            selectedProjectID = ProjectConstants.inboxProjectID
            selectedProject = ProjectConstants.inboxProjectName
            return
        }

        selectedProjectID = id
        selectedProject = projects.first(where: { $0.id == id })?.name ?? ProjectConstants.inboxProjectName
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
    private let gamificationEngine: GamificationService?
    private let aiSuggestionService: AISuggestionService?
    private let taskIconResolver: TaskIconResolver
    private let isAISuggestionRefinementReady: @MainActor () -> Bool
    let nowProvider: () -> Date
    private let taskIconResolutionQueue = DispatchQueue(label: "lifeboard.add-task-icon-resolution", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var suggestionTask: Task<Void, Never>?
    private var suggestionRequestToken = UUID()
    private var pendingPrefillTemplate: AddTaskPrefillTemplate?
    /// Capture tokens that name a project or tags, held until those lists load.
    private var pendingCaptureProjectName: String?
    private var pendingCaptureTagNames: [String] = []
    private var hasLoadedTags = false
    private var hasLoadedProjects = false
    private var inFlightCaptureTagCreations = 0
    /// True once the schedule was set on purpose (a capture seed or "Anytime"),
    /// so the sheet's default slot must not overwrite it, whichever runs first.
    public private(set) var hasExplicitSchedule = false
    private let suggestionDebounceMilliseconds = 650
    private let taskIconDebounceMilliseconds = 140
    private var loadedTaskMetadataProjectID: UUID?
    var pristineScheduledStartAt: Date?
    var pristineEstimatedDuration: TimeInterval?
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
        gamificationEngine: GamificationService? = nil,
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
        plannedDate = scheduledStartAt
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
        plannedDate = scheduledStartAt
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
        plannedDate = nil
    }

    /// "Anytime" — the task has no start time. With a day it is planned for that
    /// day (all-day); without one it is unscheduled.
    public func setAnytime(on day: Date?, calendar: Calendar = .current) {
        hasExplicitSchedule = true
        scheduledStartAt = nil
        plannedDate = day.map { calendar.startOfDay(for: $0) }
    }

    /// Seeds the form from a Quick Capture parse. Every recognized token lands in
    /// a field: a date without a time stays "anytime" on that day rather than
    /// borrowing a default slot, and `+project` / `#tag` resolve once their lists
    /// load (missing tags are created, since the person typed them on purpose).
    public func applyCaptureSeed(_ parsed: ParsedCapture, rawText: String, calendar: Calendar = .current) {
        taskName = parsed.cleanTitle.isEmpty ? rawText : parsed.cleanTitle
        if let priority = parsed.priority { selectedPriority = priority }
        if let duration = parsed.duration { setEstimatedDuration(duration) }
        if let repeatPattern = parsed.repeatPattern { self.repeatPattern = repeatPattern }
        if let context = parsed.context {
            if let resolved = Self.taskContext(matching: context) {
                selectedContext = resolved
            } else {
                // An unknown place is still the person's words; keep it in the title.
                taskName += " @\(context)"
            }
        }
        if let date = parsed.dueDate {
            if parsed.isAllDay {
                setAnytime(on: date, calendar: calendar)
            } else {
                let start = Self.clearingSubminuteComponents(date, calendar: calendar)
                hasExplicitSchedule = true
                scheduledStartAt = start
                plannedDate = start
            }
        }
        let projectName = parsed.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if parsed.dueDate == nil {
            setAnytime(on: nil)
        }
        pendingCaptureProjectName = projectName.isEmpty ? nil : projectName
        pendingCaptureTagNames = parsed.tags
        resolvePendingCaptureSelections()
    }

    /// What the title field would mean if saved now ("Call mom tomorrow 3pm
    /// #family"), or nil when it is plain words. Live, for the "Understood" line.
    public var typedTitleParse: ParsedCapture? {
        let parsed = TaskCaptureParser.parse(taskName, now: nowProvider())
        guard parsed.hasProposals, parsed.cleanTitle.isEmpty == false else { return nil }
        return parsed
    }

    /// Applies what the parser understood in a typed title before saving.
    ///
    /// Add Task never ran the parser on its own title, so "Call mom tomorrow
    /// 3pm #family" was saved word for word while the composer and the Inbox
    /// understood the same text. Unlike a capture seed, a title that names no
    /// date leaves the schedule the person chose alone. Waits for `#tag`
    /// creation and `+project` lookup; a project that does not exist goes back
    /// into the title rather than being dropped.
    public func applyTypedTitleParse(calendar: Calendar = .current) async {
        guard let parsed = typedTitleParse else { return }
        let raw = taskName
        let schedule = (hasExplicitSchedule, scheduledStartAt, plannedDate)
        applyCaptureSeed(parsed, rawText: raw, calendar: calendar)
        if parsed.dueDate == nil {
            hasExplicitSchedule = schedule.0
            scheduledStartAt = schedule.1
            plannedDate = schedule.2
        }
        _ = await awaitCaptureSelectionsResolved()
        if let unresolved = pendingCaptureProjectName {
            pendingCaptureProjectName = nil
            taskName += " +\(unresolved)"
        }
    }

    static func taskContext(matching token: String) -> TaskContext? {
        let key = token.lowercased()
        if let exact = TaskContext(rawValue: key) { return exact }
        switch key {
        case "work", "desk": return .office
        case "laptop", "pc", "mac": return .computer
        case "call", "calls", "mobile": return .phone
        case "errand", "shopping", "out", "town": return .errands
        case "outside": return .outdoor
        case "commuting", "train", "car": return .commute
        case "meetings": return .meeting
        default: return nil
        }
    }

    private func resolvePendingCaptureSelections() {
        if let name = pendingCaptureProjectName,
           // Hyphens stand for spaces, so "+side-project" finds "Side Project".
           let project = projects.first(where: {
               CaptureTokenCompletion.normalized($0.name) == CaptureTokenCompletion.normalized(name)
           }) {
            pendingCaptureProjectName = nil
            selectProject(id: project.id)
            if selectedLifeAreaID == nil, let lifeAreaID = project.lifeAreaID {
                selectedLifeAreaID = lifeAreaID
            }
            loadSections(projectID: project.id)
            loadTaskMetadataOptions(projectID: project.id)
        }
        guard hasLoadedTags, pendingCaptureTagNames.isEmpty == false else { return }
        let names = pendingCaptureTagNames
        pendingCaptureTagNames = []
        for name in names {
            if let tag = tags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                selectedTagIDs.insert(tag.id)
            } else {
                inFlightCaptureTagCreations += 1
                createTag(name: name) { [weak self] _ in
                    Task { @MainActor in self?.inFlightCaptureTagCreations -= 1 }
                }
            }
        }
    }

    /// For a save without the sheet: waits until the lists a capture seed needs
    /// have loaded (and any `#tag` it creates has landed), then reports whether
    /// the `+project` resolved. `false` means the person should see the editor.
    public func awaitCaptureSelectionsResolved(timeout: Duration = .seconds(2)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        func listsReady() -> Bool {
            hasLoadedProjects && (hasLoadedTags || manageTagsUseCase == nil)
        }
        while listsReady() == false {
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        resolvePendingCaptureSelections()
        while inFlightCaptureTagCreations > 0 {
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return pendingCaptureProjectName == nil
    }

    public func restoreDefaultSchedule() {
        let start = Self.defaultScheduledStart(now: nowProvider())
        scheduledStartAt = start
        plannedDate = start
        estimatedDuration = Self.defaultEstimatedDuration
    }

    /// Create a new task
    public func createTask(onCompletion: (@MainActor (Result<UUID, Error>) -> Void)? = nil) {
        guard !isLoading else { return }
        guard validateInput() else {
            onCompletion?(.failure(AddTaskCreationError.invalidInput))
            return
        }

        lastCreatedTaskID = nil
        isTaskCreated = false
        isLoading = true
        errorMessage = nil

        let selectedProjectObject = selectedProjectObject
        let projectID = selectedProjectObject?.id ?? selectedProjectID
        let projectName = selectedProjectObject?.name
            ?? (projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : nil)

        let resolvedTagIDs = selectedTagIDs.isEmpty ? parseImplicitTagIDs(from: taskName) : selectedTagIDs
        let requestID = creationRequestID
        let resolvedScheduledStartAt = scheduledStartAt
        let resolvedScheduledEndAt = scheduledEndAt
        let definitionRequest = CreateTaskDefinitionRequest(
            id: requestID,
            title: taskName,
            details: taskDetails.isEmpty ? nil : taskDetails,
            projectID: projectID,
            projectName: projectName,
            iconSymbolName: V2FeatureFlags.autoTaskIconsEnabled ? displayedTaskIconSymbolName : nil,
            lifeAreaID: selectedLifeAreaID,
            sectionID: selectedSectionID,
            plannedDate: plannedDate ?? resolvedScheduledStartAt,
            dueDate: dueDate,
            scheduledStartAt: resolvedScheduledStartAt,
            scheduledEndAt: resolvedScheduledEndAt,
            isAllDay: resolvedScheduledStartAt == nil && plannedDate != nil,
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
            request: definitionRequest,
            scheduleIsIndependent: true
        ) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false

                switch result {
                case .success:
                    self?.lastCreatedTaskID = requestID
                    self?.isTaskCreated = true
                    onCompletion?(.success(requestID))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    onCompletion?(.failure(error))
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
            Task { @MainActor in
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
                    self?.hasLoadedProjects = true
                    if let strongSelf = self {
                        strongSelf.reconcileSelectedProjectAfterProjectsLoad()
                    }
                    if let strongSelf = self,
                       strongSelf.projects.contains(where: { $0.id == strongSelf.selectedProjectID }) || strongSelf.selectedProjectID == ProjectConstants.inboxProjectID {
                        strongSelf.loadSections(projectID: strongSelf.selectedProjectID)
                    } else {
                        self?.clearDeferredTaskMetadataOptions()
                    }
                    self?.refreshTaskIcon(using: self?.taskName ?? "", logEvents: false)
                    self?.applyPendingPrefillIfPossible()
                    self?.resolvePendingCaptureSelections()

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
            Task { @MainActor in
                switch result {
                case .success(let project):
                    self?.selectProject(id: project.id)
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
    public func createTag(name: String, completion: @escaping @Sendable (Bool) -> Void) {
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
            Task { @MainActor in
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

    /// Sentence-case bucket name. `displayName` in the domain package is
    /// Title Case, and the raw value is a storage key.
    static func planningBucketTitle(_ bucket: TaskPlanningBucket) -> String {
        switch bucket {
        case .today: String(localized: "Today")
        case .thisWeek: String(localized: "This week")
        case .nextWeek: String(localized: "Next week")
        case .later: String(localized: "Later")
        case .someday: String(localized: "Someday")
        }
    }

    /// Reschedule task (for editing existing tasks)
    public func rescheduleTask(_ taskId: UUID, to newDate: Date) {
        guard let rescheduleTaskDefinitionUseCase else {
            errorMessage = String(localized: "Couldn’t reschedule task.")
            return
        }

        isLoading = true

        rescheduleTaskDefinitionUseCase.execute(taskID: taskId, newDate: newDate) { [weak self] result in
            Task { @MainActor in
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
        selectProject(id: nil)
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
        pendingCaptureProjectName = nil
        pendingCaptureTagNames = []
        hasExplicitSchedule = false
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
            Task { @MainActor in
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
        guard selectedProjectID != ProjectConstants.inboxProjectID || projects.contains(where: { $0.id == selectedProjectID }) else {
            clearDeferredTaskMetadataOptions()
            return
        }
        guard loadedTaskMetadataProjectID != selectedProjectID else { return }
        loadTaskMetadataOptions(projectID: selectedProjectID)
    }

    /// Validate input and update validation errors
    @discardableResult
    public func validateInput() -> Bool {
        validationErrors = validationErrorsForCurrentInput(now: nowProvider())
        return validationErrors.isEmpty
    }

    func validationErrorsForCurrentInput(now: Date) -> [ValidationError] {
        var errors: [ValidationError] = []

        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTaskName)
        } else if taskName.count > 200 {
            errors.append(.taskNameTooLong)
        }

        // Validate due date/schedule (nil is valid — "Someday")
        if let scheduledStartAt, scheduledStartAt < now {
            errors.append(.pastDueDate)
        } else if let dueDate, dueDate < Calendar.current.startOfDay(for: now) {
            errors.append(.pastDueDate)
        }

        if hasReminder && reminderTime < now {
            errors.append(.pastReminderTime)
        }

        return errors
    }
}

extension AddTaskViewModel {
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
                self.reconcileSelectedProjectFromLegacyName(projectName)
                if let project = self.selectedProjectObject,
                   project.id != ProjectConstants.inboxProjectID,
                   let projectLifeAreaID = project.lifeAreaID,
                   self.selectedLifeAreaID != projectLifeAreaID {
                    self.selectedLifeAreaID = projectLifeAreaID
                }
                guard self.selectedProjectID == ProjectConstants.inboxProjectID || self.selectedProjectObject != nil else {
                    self.sections = []
                    self.selectedSectionID = nil
                    self.clearDeferredTaskMetadataOptions()
                    return
                }
                self.loadSections(projectID: self.selectedProjectID)
                if self.loadedTaskMetadataProjectID != self.selectedProjectID {
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
            .receive(on: RunLoop.main)
            .compactMap { $0.gamificationLedgerMutation?.dailyXPSoFar }
            .sink { [weak self] dailyXP in
                self?.todayXPSoFar = max(0, dailyXP)
            }
            .store(in: &cancellables)

        guard let gamificationEngine else { return }
        gamificationEngine.fetchTodayXP { [weak self] result in
            Task { @MainActor in
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
        let refineInterval = PerformanceTrace.begin("AddTaskSuggestionRefine")
        suggestionTask = Task { @MainActor [weak self] in
            guard let self else {
                PerformanceTrace.end(refineInterval)
                return
            }
            let suggestion = await aiSuggestionService.refineFieldSuggestion(
                for: titleAtRequestStart,
                projectName: self.selectedProject
            )
            guard Task.isCancelled == false else {
                PerformanceTrace.end(refineInterval)
                return
            }

            await MainActor.run {
                defer { PerformanceTrace.end(refineInterval) }
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
        let taskIconResolver = self.taskIconResolver
        taskIconResolutionToken += 1
        let token = taskIconResolutionToken

        taskIconResolutionQueue.async { [taskIconResolver] in
            let interval = PerformanceTrace.begin("AddTaskIconResolve")
            let resolution = taskIconResolver.resolve(
                title: taskName,
                projectName: projectName,
                projectIconSymbolName: projectIconSymbolName,
                lifeAreaName: lifeAreaName,
                category: category,
                currentSymbolName: currentSymbolName,
                selectionSource: selectionSource
            )
            PerformanceTrace.end(interval)

            Task { @MainActor [weak self] in
                guard let self else { return }
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
            Task { @MainActor in
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
            selectProject(id: project.id)
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

    private func normalizeProjectSelectionForSelectedLifeArea() {
        guard selectedProjectID != ProjectConstants.inboxProjectID else { return }
        guard let selectedProjectModel = selectedProjectObject else {
            selectProject(id: nil)
            return
        }
        guard let selectedLifeAreaID else { return }
        if selectedProjectModel.lifeAreaID != selectedLifeAreaID {
            selectProject(id: nil)
        }
    }

    private func reconcileSelectedProjectAfterProjectsLoad() {
        if let project = projects.first(where: { $0.id == selectedProjectID }) {
            selectedProject = project.name
            return
        }

        reconcileSelectedProjectFromLegacyName(selectedProject)
        if selectedProjectID == ProjectConstants.inboxProjectID,
           let inbox = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
            selectedProject = inbox.name
        }
    }

    private func reconcileSelectedProjectFromLegacyName(_ projectName: String) {
        if projects.contains(where: { $0.id == selectedProjectID && $0.name == projectName }) {
            return
        }

        if projectName == ProjectConstants.inboxProjectName {
            selectedProjectID = ProjectConstants.inboxProjectID
            return
        }

        if let project = projects.first(where: { $0.name == projectName }) {
            selectedProjectID = project.id
        }
    }

    /// Executes loadSections.
    private func loadSections(projectID: UUID) {
        manageSectionsUseCase?.list(projectID: projectID) { [weak self] result in
            Task { @MainActor in
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
            Task { @MainActor in
                switch result {
                case .success(let tags):
                    self?.tags = tags.sorted(by: { $0.sortOrder < $1.sortOrder })
                    self?.hasLoadedTags = true
                    self?.resolvePendingCaptureSelections()
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
            Task { @MainActor in
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
        completion: @escaping @Sendable ([Date: Int]) -> Void
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
            Task { @MainActor in
                completion(counts)
            }
        }
    }
}
