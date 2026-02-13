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

    // Task lists by category
    @Published public private(set) var morningTasks: [Task] = []
    @Published public private(set) var eveningTasks: [Task] = []
    @Published public private(set) var overdueTasks: [Task] = []
    @Published public private(set) var dailyCompletedTasks: [Task] = []
    @Published public private(set) var upcomingTasks: [Task] = []
    @Published public private(set) var completedTasks: [Task] = []
    @Published public private(set) var doneTimelineTasks: [Task] = []

    // Focus Engine
    @Published public private(set) var activeFilterState: HomeFilterState = .default
    @Published public private(set) var savedHomeViews: [SavedHomeView] = []
    @Published public private(set) var quickViewCounts: [HomeQuickView: Int] = [:]
    @Published public private(set) var pointsPotential: Int = 0
    @Published public private(set) var emptyStateMessage: String?
    @Published public private(set) var emptyStateActionTitle: String?
    @Published public private(set) var focusEngineEnabled: Bool = true
    @Published public private(set) var activeScope: HomeListScope = .today

    // Projects
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var selectedProjectTasks: [Task] = []

    // MARK: - Dependencies

    private let useCaseCoordinator: UseCaseCoordinator
    private let homeFilteredTasksUseCase: GetHomeFilteredTasksUseCase
    private let savedHomeViewRepository: SavedHomeViewRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol?
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Persistence Keys

    private static let lastFilterStateKey = "home.focus.lastFilterState.v1"

    // MARK: - Session State

    private var homeOpenedAt: Date = Date()
    private var didTrackFirstCompletionLatency = false
    private var completionOverrides: [UUID: Bool] = [:]
    private var reloadGeneration: Int = 0
    private var suppressCompletionReloadUntil: Date?

    private let completionNotificationDebounceMS = 120
    private let completionReloadSuppressionSeconds: TimeInterval = 0.35
    private let mutationNotificationDebounceMS = 90
    private static let mutationNotificationSource = "homeViewModel"

    // MARK: - Initialization

    public init(
        useCaseCoordinator: UseCaseCoordinator,
        savedHomeViewRepository: SavedHomeViewRepositoryProtocol = UserDefaultsSavedHomeViewRepository(),
        analyticsService: AnalyticsServiceProtocol? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.homeFilteredTasksUseCase = useCaseCoordinator.getHomeFilteredTasks
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

    private func loadTasksForSelectedDate(generation: Int) {
        focusEngineEnabled = true
        activeScope = .customDate(selectedDate)
        applyFocusFilters(trackAnalytics: false, generation: generation)
    }

    /// Load tasks for today.
    public func loadTodayTasks() {
        loadTodayTasks(generation: nextReloadGeneration())
    }

    private func loadTodayTasks(generation: Int) {
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

    /// Toggle task completion.
    public func toggleTaskCompletion(_ task: Task) {
        let requestedCompletion = !task.isComplete
        print(
            "HOME_ROW_STATE vm.toggle_input id=\(task.id.uuidString) name=\(task.name) " +
            "isComplete=\(task.isComplete) requested=\(requestedCompletion)"
        )
        useCaseCoordinator.completeTask.setCompletion(
            taskId: task.id,
            to: requestedCompletion,
            taskSnapshot: task
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let completionResult):
                    self?.completionOverrides[completionResult.task.id] = completionResult.task.isComplete
                    self?.suppressCompletionReloadUntil = Date().addingTimeInterval(self?.completionReloadSuppressionSeconds ?? 0.35)
                    print(
                        "HOME_ROW_STATE vm.toggle_result id=\(completionResult.task.id.uuidString) " +
                        "requested=\(requestedCompletion) input=\(task.isComplete) " +
                        "result=\(completionResult.task.isComplete) override_set=true"
                    )
                    self?.applyCompletionResultLocally(completionResult.task)
                    let stateMatchesRequest = completionResult.task.isComplete == requestedCompletion
                    if stateMatchesRequest {
                        self?.dailyScore += completionResult.scoreEarned
                    } else {
                        print(
                            "HOME_ROW_STATE vm.toggle_mismatch id=\(completionResult.task.id.uuidString) " +
                            "requested=\(requestedCompletion) result=\(completionResult.task.isComplete) " +
                            "forcing_analytics_reload=true"
                        )
                    }
                    self?.loadDailyAnalytics()
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(
                        reason: completionResult.task.isComplete ? .completed : .reopened
                    )
                    self?.trackFirstCompletionLatencyIfNeeded()

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Create a new task.
    public func createTask(request: CreateTaskRequest) {
        useCaseCoordinator.createTask.execute(request: request) { [weak self] result in
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
    public func deleteTask(_ task: Task) {
        useCaseCoordinator.deleteTask.execute(taskId: task.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .deleted)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Reschedule a task.
    public func rescheduleTask(_ task: Task, to newDate: Date) {
        useCaseCoordinator.rescheduleTask.execute(taskId: task.id, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
                    self?.requestChartRefresh(reason: .rescheduled)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
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

    private func loadProjects(generation: Int) {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    print("HOME_ROW_STATE vm.drop_stale_reload source=projects generation=\(generation)")
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
        print("HOME_CACHE invalidated scope=all")
    }

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

    // MARK: - Private Methods

    private func setupBindings() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.requestChartRefresh(reason: .created)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.requestChartRefresh(reason: .updated)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
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
                    print("HOME_ROW_STATE vm.notification_suppressed source=TaskCompletionChanged")
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

    private func loadInitialData() {
        homeOpenedAt = Date()
        didTrackFirstCompletionLatency = false

        restoreLastFilterState()
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

    private func loadDailyAnalytics() {
        useCaseCoordinator.calculateAnalytics.calculateTodayAnalytics { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let analytics) = result {
                    self?.dailyScore = analytics.totalScore
                    self?.completionRate = analytics.completionRate
                }
            }
        }

        useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let streakInfo) = result {
                    self?.streak = streakInfo.currentStreak
                }
            }
        }
    }

    private func loadProjectTasks(_ projectName: String) {
        loadProjectTasks(projectName, generation: nextReloadGeneration())
    }

    private func loadProjectTasks(_ projectName: String, generation: Int) {
        isLoading = true

        useCaseCoordinator.getTasks.getTasksForProject(projectName) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    print("HOME_ROW_STATE vm.drop_stale_reload source=project generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let projectResult):
                    let overridden = self.applyCompletionOverrides(
                        openTasks: projectResult.tasks.filter { !$0.isComplete },
                        doneTasks: projectResult.tasks.filter(\.isComplete)
                    )
                    self.selectedProjectTasks = overridden.openTasks + overridden.doneTasks

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func reloadCurrentModeTasks() {
        let generation = nextReloadGeneration()
        loadProjects(generation: generation)
        applyFocusFilters(trackAnalytics: false, generation: generation)
    }

    private func applyFocusFilters(trackAnalytics: Bool) {
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: nextReloadGeneration())
    }

    private func applyFocusFilters(trackAnalytics: Bool, generation: Int) {
        isLoading = true
        errorMessage = nil

        homeFilteredTasksUseCase.execute(state: activeFilterState, scope: activeScope) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    print("HOME_ROW_STATE vm.drop_stale_reload source=focus generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let filteredResult):
                    self.quickViewCounts = filteredResult.quickViewCounts
                    self.pointsPotential = filteredResult.pointsPotential
                    self.applyResultToSections(filteredResult)

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

        print(
            "HOME_ROW_STATE vm.apply_result quick=\(activeScope.quickView.rawValue) " +
            "open=\(summarizeRowState(openTasks)) done=\(summarizeRowState(doneTasks))"
        )

        if activeScope == .done {
            doneTimelineTasks = doneTasks
            dailyCompletedTasks = doneTasks
            completedTasks = doneTasks
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
            emptyStateActionTitle = "Add Morning Task"
        case .evening:
            upcomingTasks = []
            emptyStateMessage = "No evening tasks. Plan your wind-down."
            emptyStateActionTitle = "Add Evening Task"
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

    private func updateCompletionRateFromFocusResult(openTasks: [Task], doneTasks: [Task]) {
        let total = openTasks.count + doneTasks.count
        completionRate = total > 0 ? Double(doneTasks.count) / Double(total) : 0
    }

    private func persistLastFilterState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(activeFilterState) {
            userDefaults.set(data, forKey: Self.lastFilterStateKey)
        }
    }

    private func seedPinnedProjectsIfNeeded(from projects: [Project]) {
        guard activeFilterState.pinnedProjectIDs.isEmpty else { return }
        let seeded = Array(projects.prefix(5).map(\.id))
        guard !seeded.isEmpty else { return }
        activeFilterState.pinnedProjectIDs = seeded
        persistLastFilterState()
    }

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

    private func bumpPinnedProject(_ id: UUID) {
        var pinned = activeFilterState.pinnedProjectIDs
        pinned.removeAll { $0 == id }
        pinned.insert(id, at: 0)

        if pinned.count > 5 {
            pinned = Array(pinned.prefix(5))
        }

        activeFilterState.pinnedProjectIDs = pinned
    }

    private func sanitizeFilterState(_ state: HomeFilterState, availableProjects: [Project]) -> HomeFilterState {
        var sanitized = state
        sanitized.customProjectOrderIDs = normalizedCustomProjectOrder(
            from: state.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: availableProjects
        )
        return sanitized
    }

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

    private func sortByPriorityThenDue(lhs: Task, rhs: Task) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    private func isEveningTaskHybrid(_ task: Task) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    private func trackFeatureUsage(action: String, metadata: [String: Any]? = nil) {
        analyticsService?.trackFeatureUsage(feature: "home_filter", action: action, metadata: metadata)
    }

    public func handleExternalMutation(reason: HomeTaskMutationEvent, repostEvent: Bool = true) {
        invalidateTaskCaches()
        reloadCurrentModeTasks()
        if repostEvent {
            requestChartRefresh(reason: reason)
        }
    }

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

    private func trackFirstCompletionLatencyIfNeeded() {
        guard !didTrackFirstCompletionLatency else { return }
        didTrackFirstCompletionLatency = true

        let latency = Date().timeIntervalSince(homeOpenedAt)
        trackFeatureUsage(action: "home_filter_time_to_first_completion_sec", metadata: ["seconds": latency])
    }

    private func updateCompletionRate(_ result: TodayTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    private func updateCompletionRate(_ result: DateTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    private func applyCompletionResultLocally(_ updatedTask: Task) {
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
            var snapshotCompleted = removingTask(id: updatedTask.id, from: snapshot.completedTasks)

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

        print(
            "HOME_ROW_STATE vm.local_apply id=\(updatedTask.id.uuidString) isComplete=\(updatedTask.isComplete) " +
            "morning=\(morningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "evening=\(eveningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "overdue=\(overdueTasks.contains(where: { $0.id == updatedTask.id })) " +
            "completed=\(completedTasks.contains(where: { $0.id == updatedTask.id })) " +
            "doneTimeline=\(doneTimelineTasks.contains(where: { $0.id == updatedTask.id }))"
        )
    }

    private func replacingTask(in tasks: [Task], with updatedTask: Task) -> [Task] {
        tasks.map { task in
            task.id == updatedTask.id ? updatedTask : task
        }
    }

    private func upsertingTaskInPlace(in tasks: [Task], with updatedTask: Task) -> [Task] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks + [updatedTask]
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    private func replacingTaskIfPresent(in tasks: [Task], with updatedTask: Task) -> [Task] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    private func removingTask(id: UUID, from tasks: [Task]) -> [Task] {
        tasks.filter { $0.id != id }
    }

    private func removeTaskFromOpenProjections(id: UUID) {
        morningTasks = removingTask(id: id, from: morningTasks)
        eveningTasks = removingTask(id: id, from: eveningTasks)
        overdueTasks = removingTask(id: id, from: overdueTasks)
        upcomingTasks = removingTask(id: id, from: upcomingTasks)
    }

    private func upsertTaskInOpenProjectionPreservingPosition(_ task: Task) {
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

    private func insertTaskIntoOpenProjection(_ task: Task) {
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

    private func sortTasksByPriorityThenDue(_ tasks: [Task]) -> [Task] {
        tasks.sorted(by: sortByPriorityThenDue)
    }

    private enum InlineSection {
        case morning
        case evening
        case overdue
    }

    private func retainingInlineCompletedRows(
        computedMorning: [Task],
        computedEvening: [Task],
        computedOverdue: [Task],
        doneTasks: [Task]
    ) -> (morning: [Task], evening: [Task], overdue: [Task]) {
        var morning = computedMorning
        var evening = computedEvening
        var overdue = computedOverdue

        var visibleIDs = Set((morning + evening + overdue).map(\.id))
        let doneByID = Dictionary(uniqueKeysWithValues: doneTasks.map { ($0.id, $0) })

        let priorCompleted: [(InlineSection, Int, Task)] = {
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

    private func insertTaskIfMissing(_ tasks: inout [Task], task: Task, preferredIndex: Int) {
        if let existingIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[existingIndex] = task
            return
        }

        let targetIndex = max(0, min(preferredIndex, tasks.count))
        tasks.insert(task, at: targetIndex)
    }

    private func isTaskOverdue(_ task: Task, relativeTo scope: HomeListScope) -> Bool {
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

    private func shouldKeepCompletedInline(for scope: HomeListScope) -> Bool {
        switch scope {
        case .today, .customDate:
            return true
        case .upcoming, .done, .morning, .evening:
            return false
        }
    }

    private func mergedInlineDoneTasks(
        incomingDoneTasks: [Task],
        openTasks: [Task],
        shouldKeepCompletedInline: Bool
    ) -> [Task] {
        guard shouldKeepCompletedInline else {
            return incomingDoneTasks
        }

        let openIDs = Set(openTasks.map(\.id))
        let retainedPriorDone = completedTasks.filter { task in
            !openIDs.contains(task.id)
        }

        var merged: [Task] = []
        var seen = Set<UUID>()
        for task in incomingDoneTasks + retainedPriorDone where task.isComplete {
            if seen.insert(task.id).inserted {
                merged.append(task)
            }
        }
        return merged
    }

    private func normalizedSections(
        morning: [Task],
        evening: [Task],
        overdue: [Task],
        completed: [Task]
    ) -> (morning: [Task], evening: [Task], overdue: [Task], completed: [Task]) {
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

    @discardableResult
    private func nextReloadGeneration() -> Int {
        reloadGeneration += 1
        return reloadGeneration
    }

    private func isCurrentReloadGeneration(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }

    private func applyCompletionOverrides(openTasks: [Task], doneTasks: [Task]) -> (openTasks: [Task], doneTasks: [Task]) {
        let normalizedOpen = openTasks.map(applyingCompletionOverrideIfNeeded)
        let normalizedDone = doneTasks.map(applyingCompletionOverrideIfNeeded)

        var mergedOpen: [Task] = []
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

        var mergedDone: [Task] = []
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

    private func applyingCompletionOverrideIfNeeded(_ task: Task) -> Task {
        guard let expectedCompletion = completionOverrides[task.id],
              expectedCompletion != task.isComplete else {
            return task
        }

        var updated = task
        updated.isComplete = expectedCompletion
        updated.dateCompleted = expectedCompletion ? (updated.dateCompleted ?? Date()) : nil
        return updated
    }

    private func reconcileCompletionOverrides(persistedTasks: [Task]) {
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
        print("HOME_ROW_STATE vm.override_cleared ids=[\(resolvedSummary)]")
    }

    private func summarizeRowState(_ tasks: [Task], limit: Int = 4) -> String {
        let summary = tasks.prefix(limit).map { task in
            let state = task.isComplete ? "done" : "open"
            return "\(task.id.uuidString.prefix(8)):\(state):\(task.name)"
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
    public let morningTasks: [Task]
    public let eveningTasks: [Task]
    public let overdueTasks: [Task]
    public let upcomingTasks: [Task]
    public let completedTasks: [Task]
    public let doneTimelineTasks: [Task]
    public let projects: [Project]
    public let dailyScore: Int
    public let streak: Int
    public let completionRate: Double
    public let activeQuickView: HomeQuickView
    public let activeScope: HomeListScope
    public let selectedProjectIDs: [UUID]
    public let pointsPotential: Int
    public let quickViewCounts: [HomeQuickView: Int]
    public let savedHomeViews: [SavedHomeView]
    public let emptyStateMessage: String?
    public let emptyStateActionTitle: String?
    public let showCompletedInline: Bool
    public let pinnedProjectIDs: [UUID]
}
