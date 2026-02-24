//
//  HomeViewModel.swift
//  Tasker
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine

public enum HomeTaskMutationEvent: String, Codable, CaseIterable {
    case created
    case updated
    case deleted
    case completed
    case reopened
    case rescheduled
    case projectChanged
    case priorityChanged
    case typeChanged
    case dueDateChanged
    case bulkChanged
}

public enum FocusPinResult: Equatable {
    case pinned
    case alreadyPinned
    case capacityReached(limit: Int)
    case taskIneligible
}

public extension Notification.Name {
    static let homeTaskMutation = Notification.Name("HomeTaskMutationEvent")
}

/// ViewModel for the Home screen
/// Manages all business logic and state for the home view
public final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties (Observable State)

    @Published public private(set) var todayTasks: TodayTasksResult?
    @Published public private(set) var selectedDate: Date = Date()
    @Published public private(set) var selectedProject: String = "All"
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var dailyScore: Int = 0
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var completionRate: Double = 0.0

    // TaskDefinition lists by category
    @Published public private(set) var morningTasks: [TaskDefinition] = []
    @Published public private(set) var eveningTasks: [TaskDefinition] = []
    @Published public private(set) var overdueTasks: [TaskDefinition] = []
    @Published public private(set) var dailyCompletedTasks: [TaskDefinition] = []
    @Published public private(set) var upcomingTasks: [TaskDefinition] = []
    @Published public private(set) var completedTasks: [TaskDefinition] = []
    @Published public private(set) var doneTimelineTasks: [TaskDefinition] = []

    // Focus Engine
    @Published public private(set) var activeFilterState: HomeFilterState = .default
    @Published public private(set) var savedHomeViews: [SavedHomeView] = []
    @Published public private(set) var quickViewCounts: [HomeQuickView: Int] = [:]
    @Published public private(set) var pointsPotential: Int = 0
    @Published public private(set) var progressState: HomeProgressState = .empty
    @Published public private(set) var focusTasks: [TaskDefinition] = []
    @Published public private(set) var pinnedFocusTaskIDs: [UUID] = []
    @Published public private(set) var emptyStateMessage: String?
    @Published public private(set) var emptyStateActionTitle: String?
    @Published public private(set) var focusEngineEnabled: Bool = true
    @Published public private(set) var activeScope: HomeListScope = .today
    @Published public private(set) var evaHomeInsights: EvaHomeInsights?
    @Published public private(set) var evaFocusWhySheetPresented: Bool = false
    @Published public private(set) var evaTriageSheetPresented: Bool = false
    @Published public private(set) var evaRescueSheetPresented: Bool = false
    @Published public private(set) var evaTriageScope: EvaTriageScope = .visible
    @Published public private(set) var evaTriageQueueLoading: Bool = false
    @Published public private(set) var evaTriageQueueErrorMessage: String?
    @Published public private(set) var evaTriageQueue: [EvaTriageQueueItem] = []
    @Published public private(set) var evaRescuePlan: EvaRescuePlan?
    @Published public private(set) var evaLastBatchRunID: UUID?

    // Next Action Module: total open tasks for today
    public var todayOpenTaskCount: Int {
        (morningTasks + eveningTasks).filter { !$0.isComplete }.count
    }

    // Projects
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var selectedProjectTasks: [TaskDefinition] = []

    // MARK: - Dependencies

    private let useCaseCoordinator: UseCaseCoordinator
    private let homeFilteredTasksUseCase: GetHomeFilteredTasksUseCase
    private let computeEvaHomeInsightsUseCase: ComputeEvaHomeInsightsUseCase
    private let getInboxTriageQueueUseCase: GetInboxTriageQueueUseCase
    private let getOverdueRescuePlanUseCase: GetOverdueRescuePlanUseCase
    private let buildEvaBatchProposalUseCase: BuildEvaBatchProposalUseCase
    private let savedHomeViewRepository: SavedHomeViewRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol?
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Persistence Keys

    private static let lastFilterStateKey = "home.focus.lastFilterState.v2"
    private static let pinnedFocusTaskIDsKey = "home.focus.pinnedTaskIDs.v2"
    private static let recentShuffleTaskIDsKey = "home.eva.recentShuffleTaskIDs.v1"
    private static let maxPinnedFocusTasks = 3
    private static let maxShuffleHistorySize = 10
    private static let defaultShuffleExclusionWindow = 3

    // MARK: - Session State

    private var homeOpenedAt: Date = Date()
    private var didTrackFirstCompletionLatency = false
    private var completionOverrides: [UUID: Bool] = [:]
    private var reloadGeneration: Int = 0
    private var suppressCompletionReloadUntil: Date?
    private var lastRecurringTopUpAt: Date?
    private var recentShuffledFocusTaskIDs: [UUID] = []

    private let completionNotificationDebounceMS = 120
    private let completionReloadSuppressionSeconds: TimeInterval = 0.35
    private let mutationNotificationDebounceMS = 90
    private let recurringTopUpThrottleSeconds: TimeInterval = 90
    private static let mutationNotificationSource = "homeViewModel"

    // MARK: - Initialization

    /// Initializes a new instance.
    public init(
        useCaseCoordinator: UseCaseCoordinator,
        savedHomeViewRepository: SavedHomeViewRepositoryProtocol = UserDefaultsSavedHomeViewRepository(),
        analyticsService: AnalyticsServiceProtocol? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.homeFilteredTasksUseCase = useCaseCoordinator.getHomeFilteredTasks
        self.computeEvaHomeInsightsUseCase = useCaseCoordinator.computeEvaHomeInsights
        self.getInboxTriageQueueUseCase = useCaseCoordinator.getInboxTriageQueue
        self.getOverdueRescuePlanUseCase = useCaseCoordinator.getOverdueRescuePlan
        self.buildEvaBatchProposalUseCase = useCaseCoordinator.buildEvaBatchProposal
        self.savedHomeViewRepository = savedHomeViewRepository
        self.analyticsService = analyticsService
        self.userDefaults = userDefaults

        setupBindings()
        loadInitialData()
    }

    // MARK: - Public Methods

    /// Load tasks for the selected date.
    public func loadTasksForSelectedDate() {
        focusEngineEnabled = true
        activeScope = .customDate(selectedDate)
        var state = activeFilterState
        state.quickView = .today
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false, generation: nextReloadGeneration())
    }

    /// Executes loadTasksForSelectedDate.
    private func loadTasksForSelectedDate(generation: Int) {
        triggerRecurringTopUpIfNeeded()
        focusEngineEnabled = true
        activeScope = .customDate(selectedDate)
        applyFocusFilters(trackAnalytics: false, generation: generation)
    }

    /// Load tasks for today.
    public func loadTodayTasks() {
        loadTodayTasks(generation: nextReloadGeneration())
    }

    /// Executes loadTodayTasks.
    private func loadTodayTasks(generation: Int) {
        triggerRecurringTopUpIfNeeded()
        focusEngineEnabled = true
        activeScope = .today
        selectedDate = Date()
        var state = activeFilterState
        state.quickView = .today
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false, generation: generation)
        loadDailyAnalytics()
    }

    /// Executes triggerRecurringTopUpIfNeeded.
    private func triggerRecurringTopUpIfNeeded() {
        let now = Date()
        if let lastRecurringTopUpAt,
           now.timeIntervalSince(lastRecurringTopUpAt) < recurringTopUpThrottleSeconds {
            return
        }
        lastRecurringTopUpAt = now
        useCaseCoordinator.createTaskDefinition.maintainRecurringSeries(daysAhead: 45) { _ in }
    }

    /// Toggle task completion.
    public func toggleTaskCompletion(_ task: TaskDefinition) {
        setTaskCompletion(
            taskID: task.id,
            to: !task.isComplete,
            taskSnapshot: task
        ) { _ in }
    }

    /// Deterministically sets completion to a desired value.
    public func setTaskCompletion(
        taskID: UUID,
        to desiredCompletion: Bool,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        setTaskCompletion(
            taskID: taskID,
            to: desiredCompletion,
            taskSnapshot: currentTaskSnapshot(for: taskID),
            completion: completion
        )
    }

    /// Create a new task.
    public func createTask(request: CreateTaskDefinitionRequest) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .created)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Delete a task.
    public func deleteTask(_ task: TaskDefinition) {
        deleteTask(taskID: task.id) { _ in }
    }

    /// Executes deleteTask.
    public func deleteTask(
        taskID: UUID,
        scope: TaskDeleteScope = .single,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.removePinnedFocusTaskID(taskID)
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .deleted)
                    completion(.success(()))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Reschedule a task.
    public func rescheduleTask(_ task: TaskDefinition, to newDate: Date?) {
        rescheduleTask(taskID: task.id, to: newDate) { _ in }
    }

    /// Executes rescheduleTask.
    public func rescheduleTask(
        taskID: UUID,
        to newDate: Date?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let task):
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .rescheduled)
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes updateTask.
    public func updateTask(
        taskID: UUID,
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        var normalizedRequest = request
        normalizedRequest.updatedAt = Date()
        useCaseCoordinator.updateTaskDefinition.execute(request: normalizedRequest) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let task):
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: self?.mutationReason(for: request) ?? .updated)
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes loadTaskDetailMetadata.
    public func loadTaskDetailMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        var loadedProjects: [Project] = projects
        var loadedLifeAreas: [LifeArea] = []
        var loadedSections: [TaskerProjectSection] = []
        var loadedTags: [TagDefinition] = []
        var availableTasks: [TaskDefinition] = []

        /// Executes record.
        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        useCaseCoordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                loadedProjects = projectsWithStats.map(\.project)
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                loadedLifeAreas = lifeAreas
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                loadedSections = sections
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                loadedTags = tags
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let slice):
                availableTasks = slice.tasks
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(TaskDetailMetadataPayload(
                projects: loadedProjects,
                lifeAreas: loadedLifeAreas,
                sections: loadedSections,
                tags: loadedTags,
                availableTasks: availableTasks
            )))
        }
    }

    /// Executes loadTaskChildren.
    public func loadTaskChildren(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        useCaseCoordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Executes createTaskDefinition.
    public func createTaskDefinition(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdTask):
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .created)
                    completion(.success(createdTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes createTagForTaskDetail.
    public func createTagForTaskDetail(
        name: String,
        completion: @escaping (Result<TagDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.manageTags.create(name: name, color: nil, icon: nil) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Executes createProjectForTaskDetail.
    public func createProjectForTaskDetail(
        name: String,
        completion: @escaping (Result<Project, Error>) -> Void
    ) {
        useCaseCoordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let project):
                    self?.loadProjects()
                    completion(.success(project))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Track Home interactions from view-layer events (animations, collapse toggles, etc.).
    public func trackHomeInteraction(action: String, metadata: [String: Any] = [:]) {
        trackFeatureUsage(action: action, metadata: metadata)
    }

    public var canUseManualFocusDrag: Bool {
        activeScope == .today
    }

    /// Executes pinTaskToFocus.
    @discardableResult
    public func pinTaskToFocus(_ taskID: UUID) -> FocusPinResult {
        guard canUseManualFocusDrag else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
            return .capacityReached(limit: Self.maxPinnedFocusTasks)
        }

        pinnedFocusTaskIDs.append(taskID)
        persistPinnedFocusTaskIDs()
        focusTasks = composedFocusTasks(from: openTasks)
        refreshEvaInsights(openTasks: openTasks)
        return .pinned
    }

    /// Executes unpinTaskFromFocus.
    public func unpinTaskFromFocus(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        focusTasks = composedFocusTasks(from: openTasks)
        refreshEvaInsights(openTasks: openTasks)
    }

    /// Change selected date.
    public func selectDate(_ date: Date) {
        selectedDate = date

        if Calendar.current.isDateInToday(date) {
            focusEngineEnabled = true
            activeScope = .today
            loadTodayTasks()
            return
        }

        focusEngineEnabled = true
        activeScope = .customDate(date)
        loadTasksForSelectedDate()
    }

    /// Change selected project filter (legacy path).
    public func selectProject(_ projectName: String) {
        selectedProject = projectName

        if projectName == "All" {
            focusEngineEnabled = true
            applyFocusFilters(trackAnalytics: false)
        } else {
            focusEngineEnabled = true
            if let project = projects.first(where: { $0.name.caseInsensitiveCompare(projectName) == .orderedSame }) {
                setProjectFilters([project.id])
            } else {
                applyFocusFilters(trackAnalytics: false)
            }
        }
    }

    /// Focus Engine: set quick view.
    public func setQuickView(_ quickView: HomeQuickView) {
        focusEngineEnabled = true
        activeScope = .fromQuickView(quickView)
        if quickView == .today {
            selectedDate = Date()
        }
        var state = activeFilterState
        state.quickView = quickView
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set Today grouping mode.
    public func setProjectGroupingMode(_ mode: HomeProjectGroupingMode) {
        focusEngineEnabled = true
        var state = activeFilterState
        guard state.projectGroupingMode != mode else { return }
        state.projectGroupingMode = mode
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: set explicit custom project section order (Inbox excluded).
    public func setCustomProjectOrder(_ orderedProjectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        let normalizedOrder = normalizedCustomProjectOrder(
            from: orderedProjectIDs,
            currentOrder: state.customProjectOrderIDs,
            availableProjects: projects
        )
        guard state.customProjectOrderIDs != normalizedOrder else { return }
        state.customProjectOrderIDs = normalizedOrder
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: toggle a project facet chip (OR across selected IDs).
    public func toggleProjectFilter(_ projectID: UUID) {
        focusEngineEnabled = true
        var ids = activeFilterState.selectedProjectIDs

        if let index = ids.firstIndex(of: projectID) {
            ids.remove(at: index)
        } else {
            ids.append(projectID)
        }

        var state = activeFilterState
        state.selectedProjectIDs = ids
        state.selectedSavedViewID = nil
        activeFilterState = state

        bumpPinnedProject(projectID)
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set explicit selected project IDs.
    public func setProjectFilters(_ projectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = Array(Set(projectIDs))
        state.selectedSavedViewID = nil
        activeFilterState = state

        for id in projectIDs {
            bumpPinnedProject(id)
        }

        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: clear project filter facets.
    public func clearProjectFilters() {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = []
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_cleared", metadata: ["scope": "projects"])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: apply advanced composable filter.
    public func applyAdvancedFilter(_ filter: HomeAdvancedFilter?, showCompletedInline: Bool? = nil) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.advancedFilter = filter?.isEmpty == false ? filter : nil
        if let showCompletedInline {
            state.showCompletedInline = showCompletedInline
        }
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set show completed inline flag.
    public func setShowCompletedInline(_ value: Bool) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.showCompletedInline = value
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: save current filter state as a reusable view.
    public func saveCurrentFilterAsView(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Saved view name cannot be empty"
            return
        }

        if savedHomeViews.count >= 20 {
            errorMessage = "You can save up to 20 Home views"
            return
        }

        let now = Date()
        let saved = SavedHomeView(
            name: trimmedName,
            quickView: activeFilterState.quickView,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            advancedFilter: activeFilterState.advancedFilter,
            showCompletedInline: activeFilterState.showCompletedInline,
            createdAt: now,
            updatedAt: now
        )

        savedHomeViewRepository.save(saved) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    self?.trackFeatureUsage(action: "home_filter_saved_view_created", metadata: ["name": trimmedName])
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: apply a previously saved filter state.
    public func applySavedView(id: UUID) {
        guard let saved = savedHomeViews.first(where: { $0.id == id }) else {
            return
        }

        focusEngineEnabled = true
        activeScope = .fromQuickView(saved.quickView)
        var restoredState = saved.asFilterState(pinnedProjectIDs: activeFilterState.pinnedProjectIDs)
        restoredState.projectGroupingMode = activeFilterState.projectGroupingMode
        restoredState.customProjectOrderIDs = activeFilterState.customProjectOrderIDs
        activeFilterState = restoredState
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_saved_view_used", metadata: ["id": id.uuidString])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: delete a saved filter view.
    public func deleteSavedView(id: UUID) {
        savedHomeViewRepository.delete(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    if self?.activeFilterState.selectedSavedViewID == id {
                        self?.activeFilterState.selectedSavedViewID = nil
                        self?.persistLastFilterState()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: reset all filters to default state.
    public func resetAllFilters() {
        focusEngineEnabled = true
        activeScope = .today
        selectedDate = Date()
        activeFilterState = .default
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_reset", metadata: [:])
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: load saved views from persistence.
    public func loadSavedViews() {
        savedHomeViewRepository.fetchAll { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: restore last persisted filter state.
    public func restoreLastFilterState() {
        guard let data = userDefaults.data(forKey: Self.lastFilterStateKey) else {
            activeFilterState = .default
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode(HomeFilterState.self, from: data)
            guard decoded.version == HomeFilterState.schemaVersion else {
                activeFilterState = .default
                return
            }
            activeFilterState = sanitizeFilterState(decoded, availableProjects: projects)
        } catch {
            activeFilterState = .default
        }
    }

    /// Load all projects.
    public func loadProjects() {
        loadProjects(generation: nextReloadGeneration())
    }

    /// Executes loadProjects.
    private func loadProjects(generation: Int) {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=projects generation=\(generation)")
                    return
                }
                switch result {
                case .success(let projectsWithStats):
                    let loadedProjects = projectsWithStats.map { $0.project }
                    self.projects = loadedProjects
                    self.seedPinnedProjectsIfNeeded(from: loadedProjects)
                    self.normalizeCustomProjectOrderIfNeeded(from: loadedProjects)

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears task-related cache entries to force fresh reads.
    public func invalidateTaskCaches() {
        useCaseCoordinator.cacheService?.clearAll()
        logDebug("HOME_CACHE invalidated scope=all")
    }

    /// Executes completionOverride.
    func completionOverride(for taskID: UUID) -> Bool? {
        completionOverrides[taskID]
    }

    /// Load upcoming tasks for legacy upcoming mode.
    public func loadUpcomingTasks() {
        focusEngineEnabled = true
        setQuickView(.upcoming)
    }

    /// Load completed tasks for legacy history mode.
    public func loadCompletedTasks() {
        focusEngineEnabled = true
        setQuickView(.done)
    }

    /// Complete morning routine.
    public func completeMorningRoutine() {
        useCaseCoordinator.completeMorningRoutine { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let routineResult):
                    self?.dailyScore += routineResult.totalScore
                    self?.refreshProgressState()
                    self?.loadTodayTasks()

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Reschedule all overdue tasks.
    public func rescheduleOverdueTasks() {
        useCaseCoordinator.rescheduleAllOverdueTasks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadTodayTasks()

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func evaFocusInsight(for taskID: UUID) -> EvaFocusTaskInsight? {
        evaHomeInsights?.focus.taskInsights.first(where: { $0.taskID == taskID })
    }

    public func setEvaFocusWhyPresented(_ value: Bool) {
        evaFocusWhySheetPresented = value
    }

    public func setEvaTriagePresented(_ value: Bool) {
        evaTriageSheetPresented = value
    }

    public func setEvaRescuePresented(_ value: Bool) {
        evaRescueSheetPresented = value
    }

    public func openFocusWhy() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        evaFocusWhySheetPresented = true
        trackHomeInteraction(action: "focus_now_why_open", metadata: [:])
    }

    public func shuffleFocusNow() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        guard canUseManualFocusDrag else { return }
        guard activeScope.quickView != .done else { return }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.count > 1 else { return }
        let pinnedSet = Set(pinnedFocusTaskIDs)
        let candidates = openTasks.filter { !pinnedSet.contains($0.id) }
        guard candidates.isEmpty == false else { return }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        let autoFill = Array(ranked.prefix(max(0, Self.maxPinnedFocusTasks - pinnedFocusTaskIDs.count)))
        let pinned = pinnedFocusTaskIDs.compactMap { id in openTasks.first(where: { $0.id == id }) }
        let newSelection = Array((pinned + autoFill).prefix(Self.maxPinnedFocusTasks))
        guard newSelection.isEmpty == false else { return }

        focusTasks = newSelection
        for task in newSelection {
            recentShuffledFocusTaskIDs.append(task.id)
        }
        recentShuffledFocusTaskIDs = Array(recentShuffledFocusTaskIDs.suffix(Self.maxShuffleHistorySize))
        persistRecentShuffleTaskIDs()
        refreshEvaInsights()
        trackHomeInteraction(action: "focus_now_shuffle_tap", metadata: [
            "result_count": newSelection.count
        ])
    }

    public func startTriage() {
        startTriage(scope: .visible)
    }

    public func startTriage(scope: EvaTriageScope) {
        guard V2FeatureFlags.evaTriageEnabled else { return }
        evaTriageSheetPresented = true
        trackHomeInteraction(action: "triage_open", metadata: [
            "scope": scope.rawValue
        ])
        refreshTriageQueue(scope: scope)
    }

    public func refreshTriageQueue(scope: EvaTriageScope) {
        refreshTriageQueue(scope: scope, completion: nil)
    }

    public func refreshTriageQueue(
        scope: EvaTriageScope,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        guard V2FeatureFlags.evaTriageEnabled else {
            completion?(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Eva triage disabled"]
            )))
            return
        }

        evaTriageScope = scope
        evaTriageQueueLoading = true
        evaTriageQueueErrorMessage = nil

        let visibleOpenTasks = focusOpenTasksForCurrentState()
        let visibleInbox = visibleOpenTasks.filter {
            !$0.isComplete && $0.projectID == ProjectConstants.inboxProjectID
        }

        switch scope {
        case .visible:
            evaTriageQueue = getInboxTriageQueueUseCase.execute(
                inboxTasks: visibleInbox,
                allTasks: visibleOpenTasks,
                projects: projects,
                maxItems: 20
            )
            evaTriageQueueLoading = false
            trackHomeInteraction(action: "triage_scope_changed", metadata: [
                "scope": scope.rawValue,
                "queue_count": evaTriageQueue.count
            ])
            completion?(.success(()))

        case .allInbox:
            useCaseCoordinator.getTasks.getTasksForProject(ProjectConstants.inboxProjectID, includeCompleted: false) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let inboxResult):
                        let inboxOpen = inboxResult.tasks.filter { !$0.isComplete }
                        let allTasks = self.uniqueTasks(visibleOpenTasks + inboxOpen)
                        self.evaTriageQueue = self.getInboxTriageQueueUseCase.execute(
                            inboxTasks: inboxOpen,
                            allTasks: allTasks,
                            projects: self.projects,
                            maxItems: 20
                        )
                        self.evaTriageQueueErrorMessage = nil
                        self.evaTriageQueueLoading = false
                        self.trackHomeInteraction(action: "triage_scope_changed", metadata: [
                            "scope": scope.rawValue,
                            "queue_count": self.evaTriageQueue.count
                        ])
                        completion?(.success(()))
                    case .failure(let error):
                        self.evaTriageQueue = self.getInboxTriageQueueUseCase.execute(
                            inboxTasks: visibleInbox,
                            allTasks: visibleOpenTasks,
                            projects: self.projects,
                            maxItems: 20
                        )
                        self.evaTriageQueueErrorMessage = "Couldn’t load backlog inbox. Showing visible tasks only."
                        self.evaTriageQueueLoading = false
                        self.trackHomeInteraction(action: "triage_error", metadata: [
                            "scope": scope.rawValue,
                            "error": error.localizedDescription
                        ])
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    public func openRescue() {
        guard V2FeatureFlags.evaRescueEnabled else { return }
        evaRescueSheetPresented = true
        useCaseCoordinator.getTasks.getOverdueTasks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                let tasks: [TaskDefinition]
                switch result {
                case .success(let overdue):
                    tasks = overdue
                case .failure:
                    tasks = self.overdueTasks
                }
                let openOverdue = tasks.filter { !$0.isComplete }
                self.evaRescuePlan = self.getOverdueRescuePlanUseCase.execute(
                    overdueTasks: openOverdue,
                    now: Date()
                )
                self.trackHomeInteraction(action: "rescue_open", metadata: [
                    "scope": "all_overdue",
                    "overdue_count": openOverdue.count
                ])
            }
        }
    }

    public func removeTriageQueueItem(taskID: UUID) {
        evaTriageQueue.removeAll { $0.task.id == taskID }
    }

    public func applyTriageDecision(
        for item: EvaTriageQueueItem,
        decision: EvaTriageDecision,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let suggestionThreshold = 0.45
        var request = UpdateTaskDefinitionRequest(id: item.task.id)
        var mutated = false

        if decision.useSuggestedProject,
           item.suggestions.projectConfidence >= suggestionThreshold,
           let projectID = item.suggestions.projectID,
           projectID != item.task.projectID {
            request.projectID = projectID
            mutated = true
        } else if !decision.useSuggestedProject,
                  let selectedProjectID = decision.selectedProjectID,
                  selectedProjectID != item.task.projectID {
            request.projectID = selectedProjectID
            mutated = true
        }

        if let deferPreset = decision.deferPreset {
            let deferDate = deferPreset.resolveDueDate()
            if item.task.dueDate != deferDate {
                request.dueDate = deferDate
                request.clearDueDate = false
                mutated = true
            }
        } else if decision.useSuggestedDue,
                  item.suggestions.dueConfidence >= suggestionThreshold {
            let dueDate = dueDate(for: item.suggestions.dueBucket)
            switch item.suggestions.dueBucket {
            case .someday:
                if item.task.dueDate != nil {
                    request.clearDueDate = true
                    mutated = true
                }
            case .none:
                break
            default:
                if item.task.dueDate != dueDate {
                    request.dueDate = dueDate
                    mutated = true
                }
            }
        } else if !decision.useSuggestedDue {
            if decision.clearDueDate {
                if item.task.dueDate != nil {
                    request.clearDueDate = true
                    mutated = true
                }
            } else if let selectedDueDate = decision.selectedDueDate,
                      item.task.dueDate != selectedDueDate {
                request.dueDate = selectedDueDate
                mutated = true
            }
        }

        if decision.useSuggestedDuration,
           item.suggestions.durationConfidence >= suggestionThreshold,
           let suggestedDuration = item.suggestions.durationSeconds,
           item.task.estimatedDuration != suggestedDuration {
            request.estimatedDuration = suggestedDuration
            mutated = true
        } else if !decision.useSuggestedDuration {
            if decision.clearDuration {
                if item.task.estimatedDuration != nil {
                    request.clearEstimatedDuration = true
                    mutated = true
                }
            } else if let selectedDuration = decision.selectedDurationSeconds,
                      item.task.estimatedDuration != selectedDuration {
                request.estimatedDuration = selectedDuration
                mutated = true
            }
        }

        guard mutated else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Select at least one change or defer option to continue."]
            )))
            return
        }

        updateTask(taskID: item.task.id, request: request) { [weak self] result in
            guard let self else {
                completion(result)
                return
            }
            switch result {
            case .success(let updatedTask):
                self.removeTriageQueueItem(taskID: updatedTask.id)
                self.trackHomeInteraction(action: "triage_apply_next", metadata: [
                    "task_id": updatedTask.id.uuidString,
                    "defer_preset": decision.deferPreset?.rawValue ?? "none",
                    "used_suggested_project": decision.useSuggestedProject,
                    "used_suggested_due": decision.useSuggestedDue,
                    "used_suggested_duration": decision.useSuggestedDuration
                ])
                completion(.success(updatedTask))
            case .failure(let error):
                self.trackHomeInteraction(action: "triage_error", metadata: [
                    "task_id": item.task.id.uuidString,
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func applyTriageSuggestion(
        for item: EvaTriageQueueItem,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let decision = EvaTriageDecision(
            selectedProjectID: nil,
            useSuggestedProject: item.suggestions.projectID != nil,
            selectedDueDate: nil,
            clearDueDate: false,
            useSuggestedDue: item.suggestions.dueBucket != nil,
            selectedDurationSeconds: nil,
            clearDuration: false,
            useSuggestedDuration: item.suggestions.durationSeconds != nil,
            stateHint: item.suggestions.stateHint,
            useSuggestedState: item.suggestions.stateHint != nil,
            deferPreset: nil
        )
        applyTriageDecision(for: item, decision: decision, completion: completion)
    }

    public func applyEvaBatchPlan(
        source: EvaBatchSource,
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard mutations.isEmpty == false else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No Eva mutations to apply"]
            )))
            return
        }
        let openTasks = focusOpenTasksForCurrentState() + completedTasks + doneTimelineTasks + evaTriageQueue.map(\.task)
        let tasksByID = openTasks.reduce(into: [UUID: TaskDefinition]()) { partialResult, task in
            partialResult[task.id] = task
        }
        let proposal = buildEvaBatchProposalUseCase.execute(
            source: source,
            tasksByID: tasksByID,
            mutations: mutations
        )

        useCaseCoordinator.assistantActionPipeline.propose(threadID: proposal.threadID, envelope: proposal.envelope) { [weak self] proposeResult in
            switch proposeResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .success(let proposedRun):
                self?.useCaseCoordinator.assistantActionPipeline.confirm(runID: proposedRun.id) { confirmResult in
                    switch confirmResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    case .success:
                        self?.useCaseCoordinator.assistantActionPipeline.applyConfirmedRun(id: proposedRun.id) { applyResult in
                            DispatchQueue.main.async {
                                switch applyResult {
                                case .success(let run):
                                    self?.evaLastBatchRunID = run.id
                                    self?.reloadCurrentModeTasks()
                                    self?.trackHomeInteraction(action: source == .triage ? "triage_bulk_apply" : "rescue_apply_confirmed", metadata: [
                                        "mutation_count": mutations.count
                                    ])
                                    completion(.success(run))
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func applyAllTriageSuggestions(
        confidenceThreshold: Double = 0.75,
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        let mutations = evaTriageQueue.compactMap { item -> EvaBatchMutationInstruction? in
            var mutation = EvaBatchMutationInstruction(taskID: item.task.id)
            var hasChange = false

            if item.suggestions.projectConfidence >= confidenceThreshold,
               let projectID = item.suggestions.projectID,
               projectID != item.task.projectID {
                mutation.projectID = projectID
                hasChange = true
            }
            if item.suggestions.dueConfidence >= confidenceThreshold {
                switch item.suggestions.dueBucket {
                case .someday:
                    if item.task.dueDate != nil {
                        mutation.clearDueDate = true
                        hasChange = true
                    }
                case .none:
                    break
                default:
                    let suggestedDate = dueDate(for: item.suggestions.dueBucket)
                    if item.task.dueDate != suggestedDate {
                        mutation.dueDate = suggestedDate
                        hasChange = true
                    }
                }
            }
            if item.suggestions.durationConfidence >= confidenceThreshold,
               let duration = item.suggestions.durationSeconds,
               item.task.estimatedDuration != duration {
                mutation.estimatedDuration = duration
                hasChange = true
            }
            return hasChange ? mutation : nil
        }

        applyEvaBatchPlan(source: .triage, mutations: mutations) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.evaTriageQueue.removeAll()
                }
                completion(result)
            }
        }
    }

    public func applyRescuePlan(
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_apply_tap", metadata: [
            "mutation_count": mutations.count
        ])
        applyEvaBatchPlan(source: .rescue, mutations: mutations) { [weak self] result in
            switch result {
            case .success(let run):
                self?.trackHomeInteraction(action: "rescue_apply_success", metadata: [
                    "run_id": run.id.uuidString,
                    "mutation_count": mutations.count
                ])
                completion(.success(run))
            case .failure(let error):
                self?.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func undoEvaBatchPlan(
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard let runID = evaLastBatchRunID else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No Eva batch run available to undo"]
            )))
            return
        }
        useCaseCoordinator.assistantActionPipeline.undoAppliedRun(id: runID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let run):
                    self?.reloadCurrentModeTasks()
                    self?.trackHomeInteraction(action: "rescue_undo", metadata: [
                        "run_id": run.id.uuidString
                    ])
                    completion(.success(run))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func undoRescueRun(
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_undo_tap", metadata: [:])
        undoEvaBatchPlan { [weak self] result in
            switch result {
            case .success(let run):
                self?.trackHomeInteraction(action: "rescue_undo_success", metadata: [
                    "run_id": run.id.uuidString
                ])
                completion(.success(run))
            case .failure(let error):
                self?.trackHomeInteraction(action: "rescue_undo_error", metadata: [
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func createSplitChildren(
        parentTaskID: UUID,
        draft: EvaSplitDraft,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        guard let parent = currentTaskSnapshot(for: parentTaskID) ?? focusOpenTasksForCurrentState().first(where: { $0.id == parentTaskID }) ?? overdueTasks.first(where: { $0.id == parentTaskID }) else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Parent task no longer exists."]
            )))
            return
        }

        let childTitles = draft.children
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard childTitles.count >= 2 else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Add at least two subtasks to split."]
            )))
            return
        }

        let dueDate = draft.childDuePreset?.resolveDueDate()
        let group = DispatchGroup()
        let lock = NSLock()
        var created: [TaskDefinition] = []
        var firstError: Error?

        trackHomeInteraction(action: "rescue_split_open", metadata: [
            "parent_task_id": parentTaskID.uuidString
        ])

        for title in childTitles {
            group.enter()
            let request = CreateTaskDefinitionRequest(
                title: title,
                details: nil,
                projectID: parent.projectID,
                projectName: parent.projectName,
                dueDate: dueDate,
                parentTaskID: parent.id,
                priority: parent.priority,
                type: parent.type,
                energy: parent.energy,
                category: parent.category,
                context: parent.context,
                isEveningTask: parent.isEveningTask,
                estimatedDuration: nil
            )

            useCaseCoordinator.createTaskDefinition.execute(request: request) { result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case .success(let task):
                    created.append(task)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let firstError {
                self.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "split_parent_task_id": parentTaskID.uuidString,
                    "error": firstError.localizedDescription
                ])
                completion(.failure(firstError))
                return
            }
            self.reloadCurrentModeTasks()
            self.trackHomeInteraction(action: "rescue_split_created", metadata: [
                "parent_task_id": parentTaskID.uuidString,
                "child_count": created.count
            ])
            completion(.success(created))
        }
    }

    public func undoCreatedSplitChildren(
        childTaskIDs: [UUID],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard childTaskIDs.isEmpty == false else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for taskID in childTaskIDs {
            group.enter()
            useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: .single) { result in
                lock.lock()
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let firstError {
                completion(.failure(firstError))
                return
            }
            self.reloadCurrentModeTasks()
            self.trackHomeInteraction(action: "rescue_split_undo", metadata: [
                "child_count": childTaskIDs.count
            ])
            completion(.success(()))
        }
    }

    // MARK: - Private Methods

    /// Executes setupBindings.
    private func setupBindings() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.requestChartRefresh(reason: .created)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.requestChartRefresh(reason: .updated)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.requestChartRefresh(reason: .deleted)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(completionNotificationDebounceMS), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let suppressUntil = self.suppressCompletionReloadUntil, Date() <= suppressUntil {
                    logDebug("HOME_ROW_STATE vm.notification_suppressed source=TaskCompletionChanged")
                    return
                }
                self.invalidateTaskCaches()
                self.reloadCurrentModeTasks()
                self.loadDailyAnalytics()
                self.requestChartRefresh(reason: .bulkChanged)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .homeTaskMutation)
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(mutationNotificationDebounceMS), scheduler: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }

                let source = notification.userInfo?["source"] as? String
                guard source != Self.mutationNotificationSource else { return }

                let reasonRaw = notification.userInfo?["reason"] as? String
                let reason = reasonRaw.flatMap(HomeTaskMutationEvent.init(rawValue:)) ?? .updated
                self.handleExternalMutation(reason: reason, repostEvent: false)
            }
            .store(in: &cancellables)
    }

    /// Executes setTaskCompletion.
    private func setTaskCompletion(
        taskID: UUID,
        to requestedCompletion: Bool,
        taskSnapshot: TaskDefinition?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        logDebug(
            "HOME_ROW_STATE vm.toggle_input id=\(taskID.uuidString) " +
            "isComplete=\(String(describing: taskSnapshot?.isComplete)) requested=\(requestedCompletion)"
        )
        useCaseCoordinator.completeTaskDefinition.setCompletion(
            taskID: taskID,
            to: requestedCompletion
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTask):
                    self?.completionOverrides[updatedTask.id] = updatedTask.isComplete
                    self?.suppressCompletionReloadUntil = Date().addingTimeInterval(self?.completionReloadSuppressionSeconds ?? 0.35)
                    self?.applyCompletionResultLocally(updatedTask)
                    let stateMatchesRequest = updatedTask.isComplete == requestedCompletion
                    if stateMatchesRequest {
                        if updatedTask.isComplete {
                            self?.dailyScore += updatedTask.priority.scorePoints
                        } else {
                            self?.dailyScore = max(0, (self?.dailyScore ?? 0) - updatedTask.priority.scorePoints)
                        }
                        self?.refreshProgressState()
                    } else {
                        logDebug(
                            "HOME_ROW_STATE vm.toggle_mismatch id=\(updatedTask.id.uuidString) " +
                            "requested=\(requestedCompletion) result=\(updatedTask.isComplete) " +
                            "forcing_analytics_reload=true"
                        )
                    }
                    self?.loadDailyAnalytics()
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(
                        reason: updatedTask.isComplete ? .completed : .reopened
                    )
                    self?.trackFirstCompletionLatencyIfNeeded()
                    completion(.success(updatedTask))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes currentTaskSnapshot.
    private func currentTaskSnapshot(for id: UUID) -> TaskDefinition? {
        let candidates = morningTasks + eveningTasks + overdueTasks + dailyCompletedTasks + upcomingTasks + completedTasks + doneTimelineTasks
        return candidates.first(where: { $0.id == id })
    }

    /// Executes mutationReason.
    private func mutationReason(for request: UpdateTaskDefinitionRequest) -> HomeTaskMutationEvent {
        if request.projectID != nil {
            return .projectChanged
        }
        if request.priority != nil {
            return .priorityChanged
        }
        if request.type != nil {
            return .typeChanged
        }
        if request.dueDate != nil || request.clearDueDate {
            return .dueDateChanged
        }
        return .updated
    }

    /// Executes loadInitialData.
    private func loadInitialData() {
        homeOpenedAt = Date()
        didTrackFirstCompletionLatency = false

        restoreLastFilterState()
        restorePinnedFocusTaskIDs()
        restoreRecentShuffleTaskIDs()
        activeScope = .fromQuickView(activeFilterState.quickView)
        if case .today = activeScope {
            selectedDate = Date()
        }
        loadSavedViews()
        let generation = nextReloadGeneration()
        loadProjects(generation: generation)
        applyFocusFilters(trackAnalytics: false, generation: generation)
        loadDailyAnalytics()
    }

    /// Executes loadDailyAnalytics.
    private func loadDailyAnalytics() {
        refreshDailyScoreFromCompletedTasksToday()

        useCaseCoordinator.calculateAnalytics.calculateTodayAnalytics { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let analytics) = result {
                    self?.completionRate = analytics.completionRate
                }
            }
        }

        useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let streakInfo) = result {
                    self?.streak = streakInfo.currentStreak
                    self?.refreshProgressState()
                }
            }
        }
    }

    /// Executes refreshDailyScoreFromCompletedTasksToday.
    private func refreshDailyScoreFromCompletedTasksToday(referenceDate: Date = Date()) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        useCaseCoordinator.getTasks.searchTasks(query: "", in: .all) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let tasks):
                    let completedTasks = tasks.filter(\.isComplete)
                    let totalScore = completedTasks.reduce(0) { partial, task in
                        let countsForToday: Bool
                        if let completionDate = task.dateCompleted {
                            countsForToday = completionDate >= startOfDay && completionDate < endOfDay
                        } else if let dueDate = task.dueDate {
                            // Legacy fallback for records missing dateCompleted.
                            countsForToday = dueDate >= startOfDay && dueDate < endOfDay
                        } else {
                            countsForToday = false
                        }

                        guard countsForToday else { return partial }
                        return partial + task.priority.scorePoints
                    }

                    self.dailyScore = totalScore
                    self.refreshProgressState()

                case .failure(let error):
                    logWarning(
                        event: "home_daily_score_refresh_failed",
                        message: "Failed to refresh completion-date XP score",
                        fields: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    /// Executes loadProjectTasks.
    private func loadProjectTasks(_ projectID: UUID) {
        loadProjectTasks(projectID, generation: nextReloadGeneration())
    }

    /// Executes loadProjectTasks.
    private func loadProjectTasks(_ projectID: UUID, generation: Int) {
        isLoading = true

        useCaseCoordinator.getTasks.getTasksForProject(projectID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=project generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let projectResult):
                    let projectTasks = projectResult.tasks
                    let overridden = self.applyCompletionOverrides(
                        openTasks: projectTasks.filter { !$0.isComplete },
                        doneTasks: projectTasks.filter(\.isComplete)
                    )
                    self.selectedProjectTasks = overridden.openTasks + overridden.doneTasks

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes reloadCurrentModeTasks.
    private func reloadCurrentModeTasks() {
        let generation = nextReloadGeneration()
        loadProjects(generation: generation)
        applyFocusFilters(trackAnalytics: false, generation: generation)
    }

    /// Executes applyFocusFilters.
    private func applyFocusFilters(trackAnalytics: Bool) {
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: nextReloadGeneration())
    }

    /// Executes applyFocusFilters.
    private func applyFocusFilters(trackAnalytics: Bool, generation: Int) {
        isLoading = true
        errorMessage = nil

        homeFilteredTasksUseCase.execute(state: activeFilterState, scope: activeScope) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=focus generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let filteredResult):
                    self.quickViewCounts = filteredResult.quickViewCounts
                    self.pointsPotential = filteredResult.pointsPotential
                    self.applyResultToSections(filteredResult)
                    self.refreshProgressState()

                    if trackAnalytics {
                        self.trackFeatureUsage(action: "home_filter_applied", metadata: [
                            "quick_view": self.activeScope.quickView.analyticsAction,
                            "scope": self.scopeAnalyticsAction(self.activeScope),
                            "project_count": self.activeFilterState.selectedProjectIDs.count,
                            "saved_view": self.activeFilterState.selectedSavedViewID?.uuidString ?? "",
                            "advanced_filter": self.activeFilterState.advancedFilter != nil
                        ])
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes applyResultToSections.
    private func applyResultToSections(_ result: HomeFilteredTasksResult) {
        let overriddenResult = applyCompletionOverrides(
            openTasks: result.openTasks,
            doneTasks: result.doneTimelineTasks
        )
        let openTasks = overriddenResult.openTasks
        let incomingDoneTasks = overriddenResult.doneTasks
        let shouldKeepCompletedInline = shouldKeepCompletedInline(for: activeScope)
        let doneTasks = mergedInlineDoneTasks(
            incomingDoneTasks: incomingDoneTasks,
            openTasks: openTasks,
            shouldKeepCompletedInline: shouldKeepCompletedInline
        )
        let visibleTasks = shouldKeepCompletedInline ? (openTasks + doneTasks) : openTasks

        logDebug(
            "HOME_ROW_STATE vm.apply_result quick=\(activeScope.quickView.rawValue) " +
            "open=\(summarizeRowState(openTasks)) done=\(summarizeRowState(doneTasks))"
        )

        if canUseManualFocusDrag {
            prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set(openTasks.map(\.id)))
        }
        focusTasks = composedFocusTasks(from: openTasks)
        refreshEvaInsights(openTasks: openTasks)

        if activeScope == .done {
            doneTimelineTasks = doneTasks
            dailyCompletedTasks = doneTasks
            completedTasks = doneTasks
            focusTasks = []
            refreshEvaInsights(openTasks: [])
            upcomingTasks = []
            morningTasks = []
            eveningTasks = []
            overdueTasks = []
            emptyStateMessage = "No completed tasks in last 30 days"
            emptyStateActionTitle = nil
            updateCompletionRateFromFocusResult(openTasks: openTasks, doneTasks: doneTasks)
            return
        }

        doneTimelineTasks = []
        completedTasks = doneTasks
        dailyCompletedTasks = doneTasks

        let overdue = visibleTasks.filter { isTaskOverdue($0, relativeTo: activeScope) }
        let nonOverdue = visibleTasks.filter { !isTaskOverdue($0, relativeTo: activeScope) }

        let computedEvening = nonOverdue.filter { isEveningTaskHybrid($0) }.sorted(by: sortByPriorityThenDue)
        let computedMorning = nonOverdue.filter { !isEveningTaskHybrid($0) }.sorted(by: sortByPriorityThenDue)
        let computedOverdue = overdue.sorted(by: sortByPriorityThenDue)

        if shouldKeepCompletedInline {
            let retained = retainingInlineCompletedRows(
                computedMorning: computedMorning,
                computedEvening: computedEvening,
                computedOverdue: computedOverdue,
                doneTasks: doneTasks
            )
            morningTasks = retained.morning
            eveningTasks = retained.evening
            overdueTasks = retained.overdue
        } else {
            morningTasks = computedMorning
            eveningTasks = computedEvening
            overdueTasks = computedOverdue
        }

        switch activeScope.quickView {
        case .upcoming:
            upcomingTasks = openTasks
            emptyStateMessage = "No upcoming tasks in 14 days"
            emptyStateActionTitle = nil
        case .morning:
            upcomingTasks = []
            emptyStateMessage = "No morning tasks. Add one to start strong."
            emptyStateActionTitle = "Add Morning TaskDefinition"
        case .evening:
            upcomingTasks = []
            emptyStateMessage = "No evening tasks. Plan your wind-down."
            emptyStateActionTitle = "Add Evening TaskDefinition"
        case .today:
            upcomingTasks = []
            emptyStateMessage = nil
            emptyStateActionTitle = nil
        case .done:
            // handled above
            break
        }

        updateCompletionRateFromFocusResult(openTasks: openTasks, doneTasks: doneTasks)
    }

    /// Executes updateCompletionRateFromFocusResult.
    private func updateCompletionRateFromFocusResult(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let total = openTasks.count + doneTasks.count
        completionRate = total > 0 ? Double(doneTasks.count) / Double(total) : 0
    }

    /// Executes refreshProgressState.
    private func refreshProgressState() {
        let earnedXP = max(0, dailyScore)
        let remainingPotentialXP = max(0, pointsPotential)
        let targetXP = earnedXP + remainingPotentialXP
        let streakDays = max(0, streak)

        progressState = HomeProgressState(
            earnedXP: earnedXP,
            remainingPotentialXP: remainingPotentialXP,
            todayTargetXP: targetXP,
            streakDays: streakDays,
            isStreakSafeToday: earnedXP > 0
        )
    }

    /// Executes persistLastFilterState.
    private func persistLastFilterState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(activeFilterState) {
            userDefaults.set(data, forKey: Self.lastFilterStateKey)
        }
    }

    /// Executes restorePinnedFocusTaskIDs.
    private func restorePinnedFocusTaskIDs() {
        let persistedIDs = userDefaults
            .stringArray(forKey: Self.pinnedFocusTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(persistedIDs)
    }

    /// Executes persistPinnedFocusTaskIDs.
    private func persistPinnedFocusTaskIDs() {
        let normalized = normalizedPinnedFocusTaskIDs(pinnedFocusTaskIDs)
        if normalized != pinnedFocusTaskIDs {
            pinnedFocusTaskIDs = normalized
        }
        userDefaults.set(normalized.map(\.uuidString), forKey: Self.pinnedFocusTaskIDsKey)
    }

    /// Executes restoreRecentShuffleTaskIDs.
    private func restoreRecentShuffleTaskIDs() {
        recentShuffledFocusTaskIDs = userDefaults
            .stringArray(forKey: Self.recentShuffleTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
    }

    /// Executes persistRecentShuffleTaskIDs.
    private func persistRecentShuffleTaskIDs() {
        userDefaults.set(recentShuffledFocusTaskIDs.map(\.uuidString), forKey: Self.recentShuffleTaskIDsKey)
    }

    private var shuffleExclusionWindow: Int {
        #if DEBUG
        if userDefaults.object(forKey: "debug.eva.focus.shuffleExclusionWindow") != nil {
            let configured = userDefaults.integer(forKey: "debug.eva.focus.shuffleExclusionWindow")
            return max(1, min(8, configured))
        }
        #endif
        return Self.defaultShuffleExclusionWindow
    }

    /// Executes seedPinnedProjectsIfNeeded.
    private func seedPinnedProjectsIfNeeded(from projects: [Project]) {
        guard activeFilterState.pinnedProjectIDs.isEmpty else { return }
        let seeded = Array(projects.prefix(5).map(\.id))
        guard !seeded.isEmpty else { return }
        activeFilterState.pinnedProjectIDs = seeded
        persistLastFilterState()
    }

    /// Executes normalizeCustomProjectOrderIfNeeded.
    private func normalizeCustomProjectOrderIfNeeded(from projects: [Project]) {
        let normalized = normalizedCustomProjectOrder(
            from: activeFilterState.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: projects
        )
        guard activeFilterState.customProjectOrderIDs != normalized else { return }
        activeFilterState.customProjectOrderIDs = normalized
        persistLastFilterState()
    }

    /// Executes bumpPinnedProject.
    private func bumpPinnedProject(_ id: UUID) {
        var pinned = activeFilterState.pinnedProjectIDs
        pinned.removeAll { $0 == id }
        pinned.insert(id, at: 0)

        if pinned.count > 5 {
            pinned = Array(pinned.prefix(5))
        }

        activeFilterState.pinnedProjectIDs = pinned
    }

    /// Executes refreshEvaInsights.
    private func refreshEvaInsights(openTasks: [TaskDefinition]? = nil) {
        guard V2FeatureFlags.evaFocusEnabled || V2FeatureFlags.evaTriageEnabled || V2FeatureFlags.evaRescueEnabled else {
            evaHomeInsights = nil
            return
        }
        let sourceOpenTasks = openTasks ?? focusOpenTasksForCurrentState()
        evaHomeInsights = computeEvaHomeInsightsUseCase.execute(
            openTasks: sourceOpenTasks,
            focusTasks: focusTasks,
            anchorDate: activeScope.referenceDate
        )
    }

    /// Executes dueDate.
    private func dueDate(for bucket: EvaDueBucket?) -> Date? {
        guard let bucket else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch bucket {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            let daysUntilEndOfWeek = 7 - calendar.component(.weekday, from: today)
            return calendar.date(byAdding: .day, value: max(daysUntilEndOfWeek, 2), to: today)
        case .someday:
            return nil
        }
    }

    private func uniqueTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        var seen = Set<UUID>()
        var unique: [TaskDefinition] = []
        unique.reserveCapacity(tasks.count)
        for task in tasks where !seen.contains(task.id) {
            seen.insert(task.id)
            unique.append(task)
        }
        return unique
    }

    /// Executes sanitizeFilterState.
    private func sanitizeFilterState(_ state: HomeFilterState, availableProjects: [Project]) -> HomeFilterState {
        var sanitized = state
        sanitized.customProjectOrderIDs = normalizedCustomProjectOrder(
            from: state.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: availableProjects
        )
        return sanitized
    }

    /// Executes normalizedCustomProjectOrder.
    private func normalizedCustomProjectOrder(
        from requestedOrder: [UUID],
        currentOrder: [UUID],
        availableProjects: [Project]
    ) -> [UUID] {
        let customProjects = availableProjects
            .filter { !$0.isInbox && $0.id != ProjectConstants.inboxProjectID }

        let dedupedRequested = Array(NSOrderedSet(array: requestedOrder).compactMap { $0 as? UUID })
            .filter { $0 != ProjectConstants.inboxProjectID }

        let dedupedCurrent = Array(NSOrderedSet(array: currentOrder).compactMap { $0 as? UUID })
            .filter { $0 != ProjectConstants.inboxProjectID }

        guard !customProjects.isEmpty else {
            var merged = dedupedRequested
            for id in dedupedCurrent where !merged.contains(id) {
                merged.append(id)
            }
            return merged
        }

        let customByID = Dictionary(uniqueKeysWithValues: customProjects.map { ($0.id, $0) })
        let requestedPresent = dedupedRequested.filter { customByID[$0] != nil }
        let currentPresent = dedupedCurrent.filter { customByID[$0] != nil }

        var merged = requestedPresent
        for id in currentPresent where !merged.contains(id) {
            merged.append(id)
        }

        let missing = customProjects
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(\.id)
            .filter { !merged.contains($0) }

        return merged + missing
    }

    /// Executes sortByPriorityThenDue.
    private func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    /// Executes isEveningTaskHybrid.
    private func isEveningTaskHybrid(_ task: TaskDefinition) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    /// Executes rankedFocusTasks.
    private func rankedFocusTasks(from tasks: [TaskDefinition], relativeTo scope: HomeListScope) -> [TaskDefinition] {
        guard !tasks.isEmpty else { return [] }

        let calendar = Calendar.current
        let anchorStart = calendar.startOfDay(for: scope.referenceDate)
        let anchorEnd = calendar.date(byAdding: .day, value: 1, to: anchorStart) ?? anchorStart

        /// Executes isOverdue.
        func isOverdue(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate < anchorStart
        }

        /// Executes isDueToday.
        func isDueToday(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= anchorStart && dueDate < anchorEnd
        }

        if V2FeatureFlags.evaFocusEnabled {
            let scored = tasks.map { task in
                let overdueDays = task.dueDate.map { max(0, calendar.dateComponents([.day], from: $0, to: anchorStart).day ?? 0) } ?? 0
                let urgency = Double(overdueDays) * 1.4 + (isDueToday(task) ? 2.0 : 0)
                let quickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800 ? 1.0 : 0
                let unblocked = task.dependencies.isEmpty ? 1.0 : -1.2
                let importance = Double(task.priority.scorePoints) * 0.6
                let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: Date()).day ?? 0)
                let freshness = staleDays >= 14 ? -0.8 : 0.3
                let score = urgency + quickWin + unblocked + importance + freshness
                return (task: task, score: score)
            }
            let sortedScored = scored.sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                let lhsDue = lhs.task.dueDate ?? Date.distantFuture
                let rhsDue = rhs.task.dueDate ?? Date.distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.task.id.uuidString < rhs.task.id.uuidString
            }
            return Array(sortedScored.map(\.task).prefix(Self.maxPinnedFocusTasks))
        }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsOverdue = isOverdue(lhs)
            let rhsOverdue = isOverdue(rhs)
            if lhsOverdue != rhsOverdue {
                return lhsOverdue
            }

            let lhsDueToday = isDueToday(lhs)
            let rhsDueToday = isDueToday(rhs)
            if lhsDueToday != rhsDueToday {
                return lhsDueToday
            }

            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }

            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        return Array(sorted.prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes composedFocusTasks.
    private func composedFocusTasks(from openTasks: [TaskDefinition]) -> [TaskDefinition] {
        guard !openTasks.isEmpty else { return [] }

        guard canUseManualFocusDrag else {
            return rankedFocusTasks(from: openTasks, relativeTo: activeScope)
        }

        let openByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        let pinnedOpen = pinnedFocusTaskIDs.compactMap { openByID[$0] }
        let pinnedSet = Set(pinnedOpen.map(\.id))
        let rankedAutoFill = rankedFocusTasks(
            from: openTasks.filter { !pinnedSet.contains($0.id) },
            relativeTo: activeScope
        )

        return Array((pinnedOpen + rankedAutoFill).prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes prunePinnedFocusTaskIDs.
    private func prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set<UUID>) {
        let filtered = pinnedFocusTaskIDs.filter { keepingOpenTaskIDs.contains($0) }
        guard filtered != pinnedFocusTaskIDs else { return }
        pinnedFocusTaskIDs = filtered
        persistPinnedFocusTaskIDs()
    }

    /// Executes removePinnedFocusTaskID.
    private func removePinnedFocusTaskID(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        focusTasks = composedFocusTasks(from: openTasks)
        refreshEvaInsights(openTasks: openTasks)
    }

    /// Executes normalizedPinnedFocusTaskIDs.
    private func normalizedPinnedFocusTaskIDs(_ ids: [UUID]) -> [UUID] {
        var deduped: [UUID] = []
        deduped.reserveCapacity(min(ids.count, Self.maxPinnedFocusTasks))

        for id in ids where !deduped.contains(id) {
            deduped.append(id)
            if deduped.count == Self.maxPinnedFocusTasks {
                break
            }
        }

        return deduped
    }

    /// Executes focusOpenTasksForCurrentState.
    private func focusOpenTasksForCurrentState() -> [TaskDefinition] {
        switch activeScope.quickView {
        case .done:
            return []
        case .upcoming:
            return upcomingTasks.filter { !$0.isComplete }
        case .today, .morning, .evening:
            return (morningTasks + eveningTasks + overdueTasks).filter { !$0.isComplete }
        }
    }

    /// Executes refreshFocusTasksFromCurrentState.
    private func refreshFocusTasksFromCurrentState() {
        if activeScope.quickView == .done {
            focusTasks = []
            refreshEvaInsights(openTasks: [])
            return
        }

        let openTasks = focusOpenTasksForCurrentState()
        if canUseManualFocusDrag {
            prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set(openTasks.map(\.id)))
        }
        focusTasks = composedFocusTasks(from: openTasks)
        refreshEvaInsights(openTasks: openTasks)
    }

    /// Executes trackFeatureUsage.
    private func trackFeatureUsage(action: String, metadata: [String: Any]? = nil) {
        analyticsService?.trackFeatureUsage(feature: "home_filter", action: action, metadata: metadata)
    }

    /// Executes handleExternalMutation.
    public func handleExternalMutation(reason: HomeTaskMutationEvent, repostEvent: Bool = true) {
        invalidateTaskCaches()
        reloadCurrentModeTasks()
        loadDailyAnalytics()
        if repostEvent {
            requestChartRefresh(reason: reason)
        }
    }

    /// Executes requestChartRefresh.
    public func requestChartRefresh(reason: HomeTaskMutationEvent) {
        NotificationCenter.default.post(
            name: .homeTaskMutation,
            object: nil,
            userInfo: [
                "reason": reason.rawValue,
                "source": Self.mutationNotificationSource
            ]
        )
    }

    /// Executes scopeAnalyticsAction.
    private func scopeAnalyticsAction(_ scope: HomeListScope) -> String {
        switch scope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    /// Executes trackFirstCompletionLatencyIfNeeded.
    private func trackFirstCompletionLatencyIfNeeded() {
        guard !didTrackFirstCompletionLatency else { return }
        didTrackFirstCompletionLatency = true

        let latency = Date().timeIntervalSince(homeOpenedAt)
        trackFeatureUsage(action: "home_filter_time_to_first_completion_sec", metadata: ["seconds": latency])
    }

    /// Executes updateCompletionRate.
    private func updateCompletionRate(_ result: TodayTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes updateCompletionRate.
    private func updateCompletionRate(_ result: DateTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes applyCompletionResultLocally.
    private func applyCompletionResultLocally(_ updatedTask: TaskDefinition) {
        let keepsCompletedInline = shouldKeepCompletedInline(for: activeScope)

        if keepsCompletedInline {
            upsertTaskInOpenProjectionPreservingPosition(updatedTask)
        } else {
            removeTaskFromOpenProjections(id: updatedTask.id)
        }
        selectedProjectTasks = replacingTask(in: selectedProjectTasks, with: updatedTask)

        if updatedTask.isComplete {
            completedTasks = upsertingTaskInPlace(in: completedTasks, with: updatedTask)
            dailyCompletedTasks = upsertingTaskInPlace(in: dailyCompletedTasks, with: updatedTask)
            doneTimelineTasks = upsertingTaskInPlace(in: doneTimelineTasks, with: updatedTask)
        } else {
            if !keepsCompletedInline {
                insertTaskIntoOpenProjection(updatedTask)
                if activeFilterState.quickView == .upcoming {
                    upcomingTasks = upsertingTaskInPlace(in: upcomingTasks, with: updatedTask)
                }
            }
            completedTasks = removingTask(id: updatedTask.id, from: completedTasks)
            dailyCompletedTasks = removingTask(id: updatedTask.id, from: dailyCompletedTasks)
            doneTimelineTasks = removingTask(id: updatedTask.id, from: doneTimelineTasks)
        }

        if let snapshot = todayTasks {
            var snapshotMorning = snapshot.morningTasks
            var snapshotEvening = snapshot.eveningTasks
            var snapshotOverdue = snapshot.overdueTasks
            let snapshotCompletedSeed = snapshot.completedTasks
            var snapshotCompleted = removingTask(id: updatedTask.id, from: snapshotCompletedSeed)

            let snapshotWasInMorning = snapshotMorning.contains(where: { $0.id == updatedTask.id })
            let snapshotWasInEvening = snapshotEvening.contains(where: { $0.id == updatedTask.id })
            let snapshotWasInOverdue = snapshotOverdue.contains(where: { $0.id == updatedTask.id })

            if updatedTask.isComplete {
                snapshotCompleted = upsertingTaskInPlace(in: snapshotCompleted, with: updatedTask)
                if keepsCompletedInline {
                    if snapshotWasInMorning {
                        snapshotMorning = replacingTaskIfPresent(in: snapshotMorning, with: updatedTask)
                    } else if snapshotWasInEvening {
                        snapshotEvening = replacingTaskIfPresent(in: snapshotEvening, with: updatedTask)
                    } else if snapshotWasInOverdue {
                        snapshotOverdue = replacingTaskIfPresent(in: snapshotOverdue, with: updatedTask)
                    } else if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                } else {
                    snapshotMorning = removingTask(id: updatedTask.id, from: snapshotMorning)
                    snapshotEvening = removingTask(id: updatedTask.id, from: snapshotEvening)
                    snapshotOverdue = removingTask(id: updatedTask.id, from: snapshotOverdue)
                }
            } else {
                if keepsCompletedInline {
                    if snapshotWasInMorning {
                        snapshotMorning = replacingTaskIfPresent(in: snapshotMorning, with: updatedTask)
                    } else if snapshotWasInEvening {
                        snapshotEvening = replacingTaskIfPresent(in: snapshotEvening, with: updatedTask)
                    } else if snapshotWasInOverdue {
                        snapshotOverdue = replacingTaskIfPresent(in: snapshotOverdue, with: updatedTask)
                    } else if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                } else {
                    snapshotMorning = removingTask(id: updatedTask.id, from: snapshotMorning)
                    snapshotEvening = removingTask(id: updatedTask.id, from: snapshotEvening)
                    snapshotOverdue = removingTask(id: updatedTask.id, from: snapshotOverdue)
                    if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                }
            }

            let updatedSnapshot = TodayTasksResult(
                morningTasks: sortTasksByPriorityThenDue(snapshotMorning),
                eveningTasks: sortTasksByPriorityThenDue(snapshotEvening),
                overdueTasks: sortTasksByPriorityThenDue(snapshotOverdue),
                completedTasks: snapshotCompleted,
                totalCount: snapshot.totalCount
            )
            todayTasks = updatedSnapshot
        }

        logDebug(
            "HOME_ROW_STATE vm.local_apply id=\(updatedTask.id.uuidString) isComplete=\(updatedTask.isComplete) " +
            "morning=\(morningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "evening=\(eveningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "overdue=\(overdueTasks.contains(where: { $0.id == updatedTask.id })) " +
            "completed=\(completedTasks.contains(where: { $0.id == updatedTask.id })) " +
            "doneTimeline=\(doneTimelineTasks.contains(where: { $0.id == updatedTask.id }))"
        )

        if updatedTask.isComplete {
            removePinnedFocusTaskID(updatedTask.id)
        }
        refreshFocusTasksFromCurrentState()
        refreshProgressState()
    }

    /// Executes replacingTask.
    private func replacingTask(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        tasks.map { task in
            task.id == updatedTask.id ? updatedTask : task
        }
    }

    /// Executes upsertingTaskInPlace.
    private func upsertingTaskInPlace(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks + [updatedTask]
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    /// Executes replacingTaskIfPresent.
    private func replacingTaskIfPresent(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    /// Executes removingTask.
    private func removingTask(id: UUID, from tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.filter { $0.id != id }
    }

    /// Executes removeTaskFromOpenProjections.
    private func removeTaskFromOpenProjections(id: UUID) {
        morningTasks = removingTask(id: id, from: morningTasks)
        eveningTasks = removingTask(id: id, from: eveningTasks)
        overdueTasks = removingTask(id: id, from: overdueTasks)
        upcomingTasks = removingTask(id: id, from: upcomingTasks)
    }

    /// Executes upsertTaskInOpenProjectionPreservingPosition.
    private func upsertTaskInOpenProjectionPreservingPosition(_ task: TaskDefinition) {
        if morningTasks.contains(where: { $0.id == task.id }) {
            morningTasks = replacingTaskIfPresent(in: morningTasks, with: task)
            return
        }
        if eveningTasks.contains(where: { $0.id == task.id }) {
            eveningTasks = replacingTaskIfPresent(in: eveningTasks, with: task)
            return
        }
        if overdueTasks.contains(where: { $0.id == task.id }) {
            overdueTasks = replacingTaskIfPresent(in: overdueTasks, with: task)
            return
        }
        if upcomingTasks.contains(where: { $0.id == task.id }) {
            upcomingTasks = replacingTaskIfPresent(in: upcomingTasks, with: task)
            return
        }

        insertTaskIntoOpenProjection(task)
    }

    /// Executes insertTaskIntoOpenProjection.
    private func insertTaskIntoOpenProjection(_ task: TaskDefinition) {
        if task.isOverdue {
            overdueTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: overdueTasks, with: task))
            return
        }

        if isEveningTaskHybrid(task) {
            eveningTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: eveningTasks, with: task))
        } else {
            morningTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: morningTasks, with: task))
        }
    }

    /// Executes sortTasksByPriorityThenDue.
    private func sortTasksByPriorityThenDue(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted(by: sortByPriorityThenDue)
    }

    private enum InlineSection {
        case morning
        case evening
        case overdue
    }

    /// Executes retainingInlineCompletedRows.
    private func retainingInlineCompletedRows(
        computedMorning: [TaskDefinition],
        computedEvening: [TaskDefinition],
        computedOverdue: [TaskDefinition],
        doneTasks: [TaskDefinition]
    ) -> (morning: [TaskDefinition], evening: [TaskDefinition], overdue: [TaskDefinition]) {
        var morning = computedMorning
        var evening = computedEvening
        var overdue = computedOverdue

        var visibleIDs = Set((morning + evening + overdue).map(\.id))
        let doneByID = Dictionary(uniqueKeysWithValues: doneTasks.map { ($0.id, $0) })

        let priorCompleted: [(InlineSection, Int, TaskDefinition)] = {
            let morningRows = morningTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.morning, index, task) : nil
            }
            let eveningRows = eveningTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.evening, index, task) : nil
            }
            let overdueRows = overdueTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.overdue, index, task) : nil
            }
            return morningRows + eveningRows + overdueRows
        }()

        for (section, previousIndex, previousTask) in priorCompleted {
            if visibleIDs.contains(previousTask.id) {
                continue
            }

            let completionOverride = completionOverrides[previousTask.id]
            guard doneByID[previousTask.id] != nil || completionOverride == true else {
                continue
            }
            if completionOverride == false {
                continue
            }

            var restoredTask = doneByID[previousTask.id] ?? previousTask
            if completionOverride == true {
                restoredTask.isComplete = true
                restoredTask.dateCompleted = restoredTask.dateCompleted ?? Date()
            }
            guard isTaskCompletedOnActiveScopeDay(restoredTask) else {
                continue
            }

            switch section {
            case .morning:
                insertTaskIfMissing(&morning, task: restoredTask, preferredIndex: previousIndex)
            case .evening:
                insertTaskIfMissing(&evening, task: restoredTask, preferredIndex: previousIndex)
            case .overdue:
                insertTaskIfMissing(&overdue, task: restoredTask, preferredIndex: previousIndex)
            }
            visibleIDs.insert(restoredTask.id)
        }

        return (morning: morning, evening: evening, overdue: overdue)
    }

    /// Executes insertTaskIfMissing.
    private func insertTaskIfMissing(_ tasks: inout [TaskDefinition], task: TaskDefinition, preferredIndex: Int) {
        if let existingIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[existingIndex] = task
            return
        }

        let targetIndex = max(0, min(preferredIndex, tasks.count))
        tasks.insert(task, at: targetIndex)
    }

    /// Executes isTaskOverdue.
    private func isTaskOverdue(_ task: TaskDefinition, relativeTo scope: HomeListScope) -> Bool {
        guard let dueDate = task.dueDate else { return false }

        switch scope {
        case .today:
            return dueDate < Calendar.current.startOfDay(for: Date())
        case .customDate(let anchorDate):
            return dueDate < Calendar.current.startOfDay(for: anchorDate)
        case .upcoming, .done, .morning, .evening:
            return task.isOverdue
        }
    }

    /// Executes shouldKeepCompletedInline.
    private func shouldKeepCompletedInline(for scope: HomeListScope) -> Bool {
        switch scope {
        case .today, .customDate:
            return true
        case .upcoming, .done, .morning, .evening:
            return false
        }
    }

    /// Executes isTaskCompletedOnScopeDay.
    private func isTaskCompletedOnScopeDay(_ task: TaskDefinition, scope: HomeListScope) -> Bool {
        guard task.isComplete, let completionDate = task.dateCompleted else { return false }
        let calendar = Calendar.current
        let startOfScopeDay = calendar.startOfDay(for: scope.referenceDate)
        guard let startOfNextScopeDay = calendar.date(byAdding: .day, value: 1, to: startOfScopeDay) else {
            return false
        }
        return completionDate >= startOfScopeDay && completionDate < startOfNextScopeDay
    }

    /// Executes isTaskCompletedOnActiveScopeDay.
    private func isTaskCompletedOnActiveScopeDay(_ task: TaskDefinition) -> Bool {
        isTaskCompletedOnScopeDay(task, scope: activeScope)
    }

    /// Executes mergedInlineDoneTasks.
    private func mergedInlineDoneTasks(
        incomingDoneTasks: [TaskDefinition],
        openTasks: [TaskDefinition],
        shouldKeepCompletedInline: Bool
    ) -> [TaskDefinition] {
        guard shouldKeepCompletedInline else {
            return incomingDoneTasks
        }

        let openIDs = Set(openTasks.map(\.id))
        let retainedPriorDone = completedTasks.filter { task in
            !openIDs.contains(task.id) && isTaskCompletedOnActiveScopeDay(task)
        }

        var merged: [TaskDefinition] = []
        var seen = Set<UUID>()
        for task in incomingDoneTasks + retainedPriorDone where task.isComplete && isTaskCompletedOnActiveScopeDay(task) {
            if seen.insert(task.id).inserted {
                merged.append(task)
            }
        }
        return merged
    }

    /// Executes normalizedSections.
    private func normalizedSections(
        morning: [TaskDefinition],
        evening: [TaskDefinition],
        overdue: [TaskDefinition],
        completed: [TaskDefinition]
    ) -> (morning: [TaskDefinition], evening: [TaskDefinition], overdue: [TaskDefinition], completed: [TaskDefinition]) {
        let overridden = applyCompletionOverrides(
            openTasks: morning + evening + overdue,
            doneTasks: completed
        )

        let openTasks = overridden.openTasks
        let normalizedOverdue = sortTasksByPriorityThenDue(openTasks.filter(\.isOverdue))
        let nonOverdue = openTasks.filter { !$0.isOverdue }
        let normalizedEvening = sortTasksByPriorityThenDue(nonOverdue.filter { isEveningTaskHybrid($0) })
        let normalizedMorning = sortTasksByPriorityThenDue(nonOverdue.filter { !isEveningTaskHybrid($0) })

        return (
            morning: normalizedMorning,
            evening: normalizedEvening,
            overdue: normalizedOverdue,
            completed: overridden.doneTasks
        )
    }

    /// Executes nextReloadGeneration.
    @discardableResult
    private func nextReloadGeneration() -> Int {
        reloadGeneration += 1
        return reloadGeneration
    }

    /// Executes isCurrentReloadGeneration.
    private func isCurrentReloadGeneration(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }

    /// Executes applyCompletionOverrides.
    private func applyCompletionOverrides(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) -> (openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let normalizedOpen = openTasks.map(applyingCompletionOverrideIfNeeded)
        let normalizedDone = doneTasks.map(applyingCompletionOverrideIfNeeded)

        var mergedOpen: [TaskDefinition] = []
        var openIDs = Set<UUID>()
        for task in normalizedOpen where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }
        for task in normalizedDone where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }

        var mergedDone: [TaskDefinition] = []
        var doneIDs = Set<UUID>()
        for task in normalizedDone where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }
        for task in normalizedOpen where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }

        reconcileCompletionOverrides(persistedTasks: openTasks + doneTasks)
        return (openTasks: mergedOpen, doneTasks: mergedDone)
    }

    /// Executes applyingCompletionOverrideIfNeeded.
    private func applyingCompletionOverrideIfNeeded(_ task: TaskDefinition) -> TaskDefinition {
        guard let expectedCompletion = completionOverrides[task.id],
              expectedCompletion != task.isComplete else {
            return task
        }

        var updated = task
        updated.isComplete = expectedCompletion
        updated.dateCompleted = expectedCompletion ? (updated.dateCompleted ?? Date()) : nil
        return updated
    }

    /// Executes reconcileCompletionOverrides.
    private func reconcileCompletionOverrides(persistedTasks: [TaskDefinition]) {
        guard !completionOverrides.isEmpty else { return }

        var resolvedIDs: [UUID] = []
        for (id, expectedCompletion) in completionOverrides {
            guard let persistedTask = persistedTasks.first(where: { $0.id == id }) else { continue }
            if persistedTask.isComplete == expectedCompletion {
                resolvedIDs.append(id)
            }
        }

        guard !resolvedIDs.isEmpty else { return }
        for id in resolvedIDs {
            completionOverrides.removeValue(forKey: id)
        }

        let resolvedSummary = resolvedIDs.map { $0.uuidString.prefix(8) }.joined(separator: ",")
        logDebug("HOME_ROW_STATE vm.override_cleared ids=[\(resolvedSummary)]")
    }

    /// Executes summarizeRowState.
    private func summarizeRowState(_ tasks: [TaskDefinition], limit: Int = 4) -> String {
        let summary = tasks.prefix(limit).map { task in
            let state = task.isComplete ? "done" : "open"
            return "\(task.id.uuidString.prefix(8)):\(state):\(task.title)"
        }.joined(separator: "|")
        return "[\(summary)] total=\(tasks.count)"
    }
}

// MARK: - View State

extension HomeViewModel {

    /// Combined state for the view.
    public var viewState: HomeViewState {
        HomeViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedDate: selectedDate,
            selectedProject: selectedProject,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            upcomingTasks: upcomingTasks,
            completedTasks: completedTasks,
            doneTimelineTasks: doneTimelineTasks,
            projects: projects,
            dailyScore: dailyScore,
            streak: streak,
            completionRate: completionRate,
            activeQuickView: activeFilterState.quickView,
            activeScope: activeScope,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            pointsPotential: pointsPotential,
            progressState: progressState,
            focusTasks: focusTasks,
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            quickViewCounts: quickViewCounts,
            savedHomeViews: savedHomeViews,
            emptyStateMessage: emptyStateMessage,
            emptyStateActionTitle: emptyStateActionTitle,
            showCompletedInline: activeFilterState.showCompletedInline,
            pinnedProjectIDs: activeFilterState.pinnedProjectIDs
        )
    }
}

/// State structure for the home view.
public struct HomeViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedDate: Date
    public let selectedProject: String
    public let morningTasks: [TaskDefinition]
    public let eveningTasks: [TaskDefinition]
    public let overdueTasks: [TaskDefinition]
    public let upcomingTasks: [TaskDefinition]
    public let completedTasks: [TaskDefinition]
    public let doneTimelineTasks: [TaskDefinition]
    public let projects: [Project]
    public let dailyScore: Int
    public let streak: Int
    public let completionRate: Double
    public let activeQuickView: HomeQuickView
    public let activeScope: HomeListScope
    public let selectedProjectIDs: [UUID]
    public let pointsPotential: Int
    public let progressState: HomeProgressState
    public let focusTasks: [TaskDefinition]
    public let pinnedFocusTaskIDs: [UUID]
    public let quickViewCounts: [HomeQuickView: Int]
    public let savedHomeViews: [SavedHomeView]
    public let emptyStateMessage: String?
    public let emptyStateActionTitle: String?
    public let showCompletedInline: Bool
    public let pinnedProjectIDs: [UUID]
}

public struct HomeProgressState: Equatable {
    public let earnedXP: Int
    public let remainingPotentialXP: Int
    public let todayTargetXP: Int
    public let streakDays: Int
    public let isStreakSafeToday: Bool

    public static let empty = HomeProgressState(
        earnedXP: 0,
        remainingPotentialXP: 0,
        todayTargetXP: 0,
        streakDays: 0,
        isStreakSafeToday: false
    )

    public var progressFraction: Double {
        guard todayTargetXP > 0 else { return 0 }
        return min(1, Double(earnedXP) / Double(todayTargetXP))
    }
}
