//
//  HomeViewModel.swift
//  Tasker
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine

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
        if focusEngineEnabled {
            applyFocusFilters(trackAnalytics: false)
            return
        }

        isLoading = true
        errorMessage = nil

        useCaseCoordinator.getTasks.getTasksForDate(selectedDate) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let dateResult):
                    self?.morningTasks = dateResult.morningTasks
                    self?.eveningTasks = dateResult.eveningTasks
                    self?.overdueTasks = dateResult.overdueTasks
                    self?.dailyCompletedTasks = dateResult.completedTasks
                    self?.updateCompletionRate(dateResult)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Load tasks for today.
    public func loadTodayTasks() {
        if focusEngineEnabled {
            var state = activeFilterState
            state.quickView = .today
            state.selectedSavedViewID = nil
            activeFilterState = state
            persistLastFilterState()
            applyFocusFilters(trackAnalytics: false)
            loadDailyAnalytics()
            return
        }

        isLoading = true
        errorMessage = nil

        useCaseCoordinator.getTasks.getTodayTasks { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let todayResult):
                    self?.todayTasks = todayResult
                    self?.morningTasks = todayResult.morningTasks
                    self?.eveningTasks = todayResult.eveningTasks
                    self?.overdueTasks = todayResult.overdueTasks
                    self?.dailyCompletedTasks = todayResult.completedTasks
                    self?.updateCompletionRate(todayResult)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        loadDailyAnalytics()
    }

    /// Toggle task completion.
    public func toggleTaskCompletion(_ task: Task) {
        useCaseCoordinator.completeTask.execute(taskId: task.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let completionResult):
                    self?.dailyScore += completionResult.scoreEarned
                    self?.invalidateTaskCaches()
                    self?.reloadCurrentModeTasks()
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
            loadTodayTasks()
            return
        }

        focusEngineEnabled = false
        loadTasksForSelectedDate()
    }

    /// Change selected project filter (legacy path).
    public func selectProject(_ projectName: String) {
        selectedProject = projectName

        if projectName == "All" {
            focusEngineEnabled = true
            applyFocusFilters(trackAnalytics: false)
        } else {
            focusEngineEnabled = false
            loadProjectTasks(projectName)
        }
    }

    /// Focus Engine: set quick view.
    public func setQuickView(_ quickView: HomeQuickView) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.quickView = quickView
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
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
        activeFilterState = saved.asFilterState(pinnedProjectIDs: activeFilterState.pinnedProjectIDs)
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
            activeFilterState = decoded
        } catch {
            activeFilterState = .default
        }
    }

    /// Load all projects.
    public func loadProjects() {
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectsWithStats):
                    let loadedProjects = projectsWithStats.map { $0.project }
                    self?.projects = loadedProjects
                    self?.seedPinnedProjectsIfNeeded(from: loadedProjects)

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears task-related cache entries to force fresh reads.
    public func invalidateTaskCaches() {
        useCaseCoordinator.cacheService?.clearAll()
        print("HOME_CACHE invalidated scope=all")
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
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))
            .sink { [weak self] _ in
                self?.invalidateTaskCaches()
                self?.reloadCurrentModeTasks()
                self?.loadDailyAnalytics()
            }
            .store(in: &cancellables)
    }

    private func loadInitialData() {
        homeOpenedAt = Date()
        didTrackFirstCompletionLatency = false

        restoreLastFilterState()
        loadSavedViews()
        loadProjects()
        applyFocusFilters(trackAnalytics: false)
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
        isLoading = true

        useCaseCoordinator.getTasks.getTasksForProject(projectName) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let projectResult):
                    self?.selectedProjectTasks = projectResult.tasks

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func reloadCurrentModeTasks() {
        loadProjects()

        if focusEngineEnabled {
            applyFocusFilters(trackAnalytics: false)
            return
        }

        if selectedProject != "All" {
            loadProjectTasks(selectedProject)
            return
        }

        if Calendar.current.isDateInToday(selectedDate) {
            loadTodayTasks()
        } else {
            loadTasksForSelectedDate()
        }
    }

    private func applyFocusFilters(trackAnalytics: Bool) {
        isLoading = true
        errorMessage = nil

        homeFilteredTasksUseCase.execute(state: activeFilterState) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let filteredResult):
                    self.quickViewCounts = filteredResult.quickViewCounts
                    self.pointsPotential = filteredResult.pointsPotential
                    self.applyResultToSections(filteredResult)

                    if trackAnalytics {
                        self.trackFeatureUsage(action: "home_filter_applied", metadata: [
                            "quick_view": self.activeFilterState.quickView.analyticsAction,
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
        if activeFilterState.quickView == .done {
            doneTimelineTasks = result.doneTimelineTasks
            dailyCompletedTasks = result.doneTimelineTasks
            completedTasks = result.doneTimelineTasks
            upcomingTasks = []
            morningTasks = []
            eveningTasks = []
            overdueTasks = []
            emptyStateMessage = "No completed tasks in last 30 days"
            emptyStateActionTitle = nil
            updateCompletionRateFromFocusResult(openTasks: result.openTasks, doneTasks: result.doneTimelineTasks)
            return
        }

        doneTimelineTasks = []
        completedTasks = activeFilterState.showCompletedInline ? result.doneTimelineTasks : []

        let overdue = result.openTasks.filter(\.isOverdue)
        let nonOverdue = result.openTasks.filter { !$0.isOverdue }

        let evening = nonOverdue.filter { isEveningTaskHybrid($0) }
        let morning = nonOverdue.filter { !isEveningTaskHybrid($0) }

        morningTasks = morning.sorted(by: sortByPriorityThenDue)
        eveningTasks = evening.sorted(by: sortByPriorityThenDue)
        overdueTasks = overdue.sorted(by: sortByPriorityThenDue)

        switch activeFilterState.quickView {
        case .upcoming:
            upcomingTasks = result.openTasks
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

        updateCompletionRateFromFocusResult(openTasks: result.openTasks, doneTasks: result.doneTimelineTasks)
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

    private func bumpPinnedProject(_ id: UUID) {
        var pinned = activeFilterState.pinnedProjectIDs
        pinned.removeAll { $0 == id }
        pinned.insert(id, at: 0)

        if pinned.count > 5 {
            pinned = Array(pinned.prefix(5))
        }

        activeFilterState.pinnedProjectIDs = pinned
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
    public let selectedProjectIDs: [UUID]
    public let pointsPotential: Int
    public let quickViewCounts: [HomeQuickView: Int]
    public let savedHomeViews: [SavedHomeView]
    public let emptyStateMessage: String?
    public let emptyStateActionTitle: String?
    public let showCompletedInline: Bool
    public let pinnedProjectIDs: [UUID]
}
