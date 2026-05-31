//
//  HomeSearchState.swift
//  LifeBoard
//
//  Search state and engine adapter for the Home shell.
//

import Combine
import Foundation

enum HomeSearchStatusFilter: String, CaseIterable, Equatable, Identifiable {
    case all
    case today
    case overdue
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .today:
            return "Today"
        case .overdue:
            return "Overdue"
        case .completed:
            return "Completed"
        }
    }

    var analyticsName: String { rawValue }

    var accessibilityIdentifier: String {
        "search.status.\(rawValue)"
    }
}

enum CommandSearchMode: String, CaseIterable, Equatable, Identifiable {
    case search
    case askEva

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:
            return "Search"
        case .askEva:
            return "Ask Eva"
        }
    }
}

enum CommandSearchEmptyState: Equatable {
    case `default`
    case partial
    case noResults
    case rich
}

private extension HomeSearchStatusFilter {
    var searchValue: HomeSearchViewModel.StatusFilterType {
        switch self {
        case .all:
            return .all
        case .today:
            return .today
        case .overdue:
            return .overdue
        case .completed:
            return .completed
        }
    }
}

struct HomeSearchSection: Identifiable, Equatable {
    let projectName: String
    let tasks: [TaskDefinition]

    var id: String { projectName }
}

enum HomeSearchSuggestedCommand: String, CaseIterable, Equatable, Identifiable {
    case whatNext
    case overdueTasks
    case missedHabits
    case nextTwoHours
    case beforeMeeting
    case quickWins

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whatNext:
            return "What next?"
        case .overdueTasks:
            return "Overdue tasks"
        case .missedHabits:
            return "Missed habits"
        case .nextTwoHours:
            return "Next 2 hours"
        case .beforeMeeting:
            return "Before meeting"
        case .quickWins:
            return "Quick wins"
        }
    }

    var symbol: String {
        switch self {
        case .whatNext:
            return "sparkles"
        case .overdueTasks:
            return "exclamationmark.triangle"
        case .missedHabits:
            return "repeat.circle"
        case .nextTwoHours:
            return "timer"
        case .beforeMeeting:
            return "calendar"
        case .quickWins:
            return "bolt"
        }
    }

    var context: String {
        switch self {
        case .whatNext:
            return "Find the next best move."
        case .overdueTasks:
            return "List stale work that needs a decision."
        case .missedHabits:
            return "Recover routine drift."
        case .nextTwoHours:
            return "Fit work into the next useful block."
        case .beforeMeeting:
            return "Match tasks to calendar space."
        case .quickWins:
            return "Find small tasks with useful payoff."
        }
    }

    static func contextualDefaults(calendar: Calendar = .current, now: Date = Date()) -> [HomeSearchSuggestedCommand] {
        let hour = calendar.component(.hour, from: now)
        let contextual: [HomeSearchSuggestedCommand]
        if hour < 12 {
            contextual = [.whatNext, .quickWins, .nextTwoHours]
        } else if hour < 18 {
            contextual = [.nextTwoHours, .beforeMeeting, .quickWins]
        } else {
            contextual = [.whatNext, .quickWins, .overdueTasks]
        }

        var commands: [HomeSearchSuggestedCommand] = [.whatNext, .overdueTasks, .missedHabits]
        for command in contextual where commands.contains(command) == false {
            commands.append(command)
        }
        return Array(commands.prefix(6))
    }
}

struct HomeSearchCommandResult: Equatable {
    let command: HomeSearchSuggestedCommand
    let title: String
    let subtitle: String
    let taskSections: [HomeSearchSection]
    let habitRows: [HomeHabitRow]
    let emptyTitle: String
    let emptySubtitle: String
    let emptyPrimaryTitle: String?
    let fallbackCommand: HomeSearchSuggestedCommand?

    var resultCount: Int {
        taskSections.reduce(0) { $0 + $1.tasks.count } + habitRows.count
    }

    var isEmpty: Bool {
        resultCount == 0
    }
}

enum HomeSearchCommandResultBuilder {
    private static let quickWinLimit: TimeInterval = 15 * 60
    private static let nextTwoHours: TimeInterval = 2 * 60 * 60
    private static let beforeMeetingBuffer: TimeInterval = 10 * 60
    private static let commandResultLimit = 8

    static func build(
        command: HomeSearchSuggestedCommand,
        tasksSnapshot: HomeTasksSnapshot,
        habitsSnapshot: HomeHabitsSnapshot,
        calendarSnapshot: HomeCalendarSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeSearchCommandResult {
        let openTasks = uniqueTasks(openTasks(from: tasksSnapshot))
        let recoveryHabits = missedHabitRows(from: habitsSnapshot)

        switch command {
        case .whatNext:
            let tasks = Array(rankFocusTasks(openTasks, now: now, calendar: calendar).prefix(5))
            let habits = tasks.isEmpty ? Array(recoveryHabits.prefix(5)) : []
            return result(
                command: command,
                title: "What next?",
                subtitle: tasks.isEmpty ? "\(habits.count) habit\(habits.count == 1 ? "" : "s") need recovery" : "\(tasks.count) recommended move\(tasks.count == 1 ? "" : "s")",
                tasks: tasks,
                habits: habits,
                emptyTitle: "Nothing needs attention",
                emptySubtitle: "No open task or missed habit is ready in the current Home snapshot."
            )
        case .overdueTasks:
            let tasks = tasksSnapshot.overdueTasks.filter { $0.isComplete == false }
            return result(
                command: command,
                title: "Overdue tasks",
                subtitle: "\(tasks.count) task\(tasks.count == 1 ? "" : "s") overdue",
                tasks: tasks,
                emptyTitle: "No overdue tasks",
                emptySubtitle: "There is no stale open work in the current task list."
            )
        case .missedHabits:
            return result(
                command: command,
                title: "Missed habits",
                subtitle: "\(recoveryHabits.count) habit\(recoveryHabits.count == 1 ? "" : "s") need recovery",
                habits: recoveryHabits,
                emptyTitle: "No missed habits",
                emptySubtitle: "Your active habits do not show missed or recovery states right now."
            )
        case .nextTwoHours:
            let windowEnd = now.addingTimeInterval(nextTwoHours)
            let tasks = openTasks.filter { task in
                if let scheduledStart = task.scheduledStartAt {
                    return scheduledStart >= now && scheduledStart <= windowEnd
                }
                guard let estimatedDuration = task.estimatedDuration else { return false }
                return estimatedDuration > 0 && estimatedDuration <= nextTwoHours
            }
            return result(
                command: command,
                title: "Next 2 hours",
                subtitle: "\(tasks.count) task\(tasks.count == 1 ? "" : "s") fit the next block",
                tasks: Array(sortTasksByPriorityThenDue(tasks).prefix(commandResultLimit)),
                emptyTitle: "No tasks fit the next 2 hours",
                emptySubtitle: "Add estimates to tasks or ask Eva to help break down larger work."
            )
        case .beforeMeeting:
            guard let meeting = calendarSnapshot.nextMeeting,
                  meeting.event.startDate > now else {
                return result(
                    command: command,
                    title: "Before meeting",
                    subtitle: "No upcoming meeting found",
                    tasks: [],
                    emptyTitle: "No meeting ahead",
                    emptySubtitle: "There is no upcoming calendar meeting in the current Home context.",
                    emptyPrimaryTitle: HomeSearchSuggestedCommand.quickWins.title,
                    fallbackCommand: .quickWins
                )
            }
            let available = max(0, meeting.event.startDate.timeIntervalSince(now) - beforeMeetingBuffer)
            let tasks = openTasks.filter { task in
                if let scheduledStart = task.scheduledStartAt {
                    return scheduledStart >= now && scheduledStart < meeting.event.startDate
                }
                guard let estimatedDuration = task.estimatedDuration else { return false }
                return estimatedDuration > 0 && estimatedDuration <= available
            }
            let minutes = max(0, Int(available / 60))
            return result(
                command: command,
                title: "Before meeting",
                subtitle: "\(minutes) min before \(meeting.event.title)",
                tasks: Array(sortTasksByPriorityThenDue(tasks).prefix(commandResultLimit)),
                emptyTitle: "Nothing fits before \(meeting.event.title)",
                emptySubtitle: "The available window is too small for estimated tasks.",
                emptyPrimaryTitle: HomeSearchSuggestedCommand.quickWins.title,
                fallbackCommand: .quickWins
            )
        case .quickWins:
            let tasks = openTasks.filter { task in
                guard let estimatedDuration = task.estimatedDuration else { return false }
                return estimatedDuration > 0 && estimatedDuration <= quickWinLimit
            }
            return result(
                command: command,
                title: "Quick wins",
                subtitle: "\(tasks.count) task\(tasks.count == 1 ? "" : "s") at 15 min or less",
                tasks: Array(sortTasksByPriorityThenDue(tasks).prefix(commandResultLimit)),
                emptyTitle: "No quick wins",
                emptySubtitle: "No open task currently has an estimate of 15 minutes or less."
            )
        }
    }

    private static func result(
        command: HomeSearchSuggestedCommand,
        title: String,
        subtitle: String,
        tasks: [TaskDefinition] = [],
        habits: [HomeHabitRow] = [],
        emptyTitle: String,
        emptySubtitle: String,
        emptyPrimaryTitle: String? = nil,
        fallbackCommand: HomeSearchSuggestedCommand? = nil
    ) -> HomeSearchCommandResult {
        HomeSearchCommandResult(
            command: command,
            title: title,
            subtitle: subtitle,
            taskSections: groupTasksByProject(tasks),
            habitRows: habits,
            emptyTitle: emptyTitle,
            emptySubtitle: emptySubtitle,
            emptyPrimaryTitle: emptyPrimaryTitle,
            fallbackCommand: fallbackCommand
        )
    }

    private static func openTasks(from snapshot: HomeTasksSnapshot) -> [TaskDefinition] {
        snapshot.morningTasks
            + snapshot.eveningTasks
            + snapshot.overdueTasks
            + snapshot.focusTasks
            + snapshot.focusRows.compactMap(task(from:))
            + (snapshot.dueTodaySection?.rows.compactMap(task(from:)) ?? [])
            + snapshot.todaySections.flatMap { $0.rows.compactMap(task(from:)) }
            + snapshot.todayAgendaSectionState.sections.flatMap { $0.rows.compactMap(task(from:)) }
    }

    private static func task(from row: HomeTodayRow) -> TaskDefinition? {
        if case .task(let task) = row {
            return task
        }
        return nil
    }

    private static func missedHabitRows(from snapshot: HomeHabitsSnapshot) -> [HomeHabitRow] {
        (snapshot.habitHomeSectionState.recoveryRows + snapshot.habitHomeSectionState.primaryRows)
            .filter { row in
                row.state == .overdue
                    || row.state == .lapsedToday
                    || row.last14Days.contains { $0.state == .failure }
            }
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return habitStateRank(lhs.state) < habitStateRank(rhs.state)
                }
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak < rhs.currentStreak
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private static func habitStateRank(_ state: HomeHabitRowState) -> Int {
        switch state {
        case .overdue:
            return 0
        case .lapsedToday:
            return 1
        case .due:
            return 2
        case .tracking:
            return 3
        case .completedToday, .skippedToday:
            return 4
        }
    }

    private static func rankFocusTasks(
        _ tasks: [TaskDefinition],
        now: Date,
        calendar: Calendar
    ) -> [TaskDefinition] {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        return sortTasksByPriorityThenDue(tasks)
            .map { task -> (TaskDefinition, Double) in
                let overdueDays = task.dueDate.map { max(0, calendar.dateComponents([.day], from: $0, to: startOfToday).day ?? 0) } ?? 0
                let dueToday = task.dueDate.map { $0 >= startOfToday && $0 < endOfToday } ?? false
                let quickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= quickWinLimit ? 1.0 : 0
                let unblocked = task.dependencies.isEmpty ? 1.0 : -1.2
                let importance = Double(task.priority.scorePoints) * 0.6
                let urgency = Double(overdueDays) * 1.4 + (dueToday ? 2.0 : 0)
                return (task, urgency + quickWin + unblocked + importance)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return compareByDueThenTitle(lhs.0, rhs.0)
            }
            .map(\.0)
    }

    private static func sortTasksByPriorityThenDue(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            return compareByDueThenTitle(lhs, rhs)
        }
    }

    private static func compareByDueThenTitle(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func groupTasksByProject(_ tasks: [TaskDefinition]) -> [HomeSearchSection] {
        Dictionary(grouping: tasks) { $0.projectName ?? ProjectConstants.inboxProjectName }
            .map { HomeSearchSection(projectName: $0.key, tasks: $0.value) }
            .sorted { $0.projectName.localizedStandardCompare($1.projectName) == .orderedAscending }
    }

    private static func uniqueTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        var seen = Set<UUID>()
        var unique: [TaskDefinition] = []
        for task in tasks where task.isComplete == false {
            guard seen.insert(task.id).inserted else { continue }
            unique.append(task)
        }
        return unique
    }
}

struct HomeSearchRequestSignature: Equatable {
    let dataRevision: UInt64
    let query: String
    let status: HomeSearchStatusFilter
    let priorities: [Int32]
    let projects: [String]
}

enum HomeSearchFocusPolicyResolver {
    static func shouldAutoFocusOnSearchEntry(layoutClass: LifeBoardLayoutClass) -> Bool {
        guard V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled else {
            return false
        }
        return false
    }
}

@MainActor
protocol HomeSearchEngine: AnyObject {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? { get set }
    var projects: [Project] { get }

    func search(query: String, revision: Int)
    func loadProjects(completion: (@MainActor @Sendable () -> Void)?)
    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32])
    func clearFilters()
    func toggleProjectFilter(_ project: String)
    func togglePriorityFilter(_ priority: Int32)
    func setStatusFilter(_ filter: HomeSearchStatusFilter)
    func invalidateSearchCache(revision: Int)
    func releaseResources()
    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])]
}

@MainActor
final class HomeSearchEngineAdapter: HomeSearchEngine {
    private let viewModel: HomeSearchViewModel

    init(viewModel: HomeSearchViewModel) {
        self.viewModel = viewModel
    }

    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)? {
        get { viewModel.onResultsUpdatedWithRevision }
        set { viewModel.onResultsUpdatedWithRevision = newValue }
    }

    var projects: [Project] {
        viewModel.projects
    }

    func search(query: String, revision: Int) {
        viewModel.search(query: query, revision: revision)
    }

    func loadProjects(completion: (@MainActor @Sendable () -> Void)?) {
        viewModel.loadProjects(completion: completion)
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {
        viewModel.replaceFilters(
            status: status.searchValue,
            projects: projects,
            priorities: priorities
        )
    }

    func clearFilters() {
        viewModel.clearFilters()
    }

    func toggleProjectFilter(_ project: String) {
        viewModel.toggleProjectFilter(project)
    }

    func togglePriorityFilter(_ priority: Int32) {
        viewModel.togglePriorityFilter(priority)
    }

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {
        viewModel.setStatusFilter(filter.searchValue)
    }

    func invalidateSearchCache(revision: Int) {
        viewModel.invalidateSearchCache(revision: revision)
    }

    func releaseResources() {
        viewModel.purgeCaches()
        viewModel.onResultsUpdatedWithRevision = nil
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        viewModel.groupTasksByProject(tasks)
    }
}

@MainActor
final class SearchRefreshCoordinator {
    private let debounceNanoseconds: UInt64
    private var debounceTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(debounceDelay: TimeInterval = 0.18) {
        debounceNanoseconds = UInt64(max(0, debounceDelay) * 1_000_000_000)
    }

    @discardableResult
    func request(
        immediate: Bool,
        perform: @escaping @MainActor (UInt64) -> Void
    ) -> UInt64 {
        generation &+= 1
        let requestGeneration = generation
        debounceTask?.cancel()

        if immediate || debounceNanoseconds == 0 {
            perform(requestGeneration)
            return requestGeneration
        }

        let wait = debounceNanoseconds
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: wait)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                perform(requestGeneration)
            }
        }
        return requestGeneration
    }

    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}

@MainActor
final class HomeSearchState: ObservableObject {
    @Published var query: String = ""
    @Published var commandMode: CommandSearchMode = .search
    @Published var selectedStatus: HomeSearchStatusFilter = .all
    @Published var selectedPriorities: Set<Int32> = []
    @Published var selectedProjects: Set<String> = []
    @Published var isCompletedExpanded = false
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var sections: [HomeSearchSection] = []
    @Published private(set) var availableProjects: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var activeSuggestedCommandResult: HomeSearchCommandResult?

    private var engine: HomeSearchEngine?
    private let refreshCoordinator: SearchRefreshCoordinator
    private var sharedDataRevisionProvider: (() -> HomeDataRevision)?
    private var latestIssuedSearchRevision: Int = 0
    private var needsRefreshOnNextActivation = false
    private var lastExecutedSignature: HomeSearchRequestSignature?

    init(debounceDelay: TimeInterval = 0.18) {
        refreshCoordinator = SearchRefreshCoordinator(debounceDelay: debounceDelay)
    }

    var hasActiveFilters: Bool {
        selectedStatus != .all || !selectedPriorities.isEmpty || !selectedProjects.isEmpty
    }

    var hasActiveSuggestedCommand: Bool {
        activeSuggestedCommandResult != nil
    }

    var activeFilterCount: Int {
        (selectedStatus == .all ? 0 : 1) + selectedPriorities.count + selectedProjects.count
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowNoResultsMessage: Bool {
        if let activeSuggestedCommandResult {
            return activeSuggestedCommandResult.isEmpty
        }
        hasLoaded && !isLoading && sections.isEmpty
    }

    var emptyStateTitle: String {
        if let activeSuggestedCommandResult {
            return activeSuggestedCommandResult.emptyTitle
        }
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Find anything in LifeBoard"
        }
        return "Nothing matched \"\(trimmedQuery)\""
    }

    var emptyStateSubtitle: String {
        if let activeSuggestedCommandResult {
            return activeSuggestedCommandResult.emptySubtitle
        }
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Try asking what to do next, showing overdue tasks, or planning the next block."
        }
        return "Widen your search, clear filters, or ask Eva to reason over your day."
    }

    var emptyPrimaryTitle: String? {
        activeSuggestedCommandResult?.emptyPrimaryTitle
    }

    var emptyFallbackCommand: HomeSearchSuggestedCommand? {
        activeSuggestedCommandResult?.fallbackCommand
    }

    func configureIfNeeded(
        makeEngine: () -> HomeSearchEngine,
        dataRevisionProvider: @escaping () -> HomeDataRevision
    ) {
        guard engine == nil else { return }
        sharedDataRevisionProvider = dataRevisionProvider
        let resolvedEngine = makeEngine()
        engine = resolvedEngine
        resolvedEngine.invalidateSearchCache(revision: currentSearchCacheRevision)
        resolvedEngine.onResultsUpdated = { [weak self] revision, tasks in
            guard let self else { return }
            Task { @MainActor in
                self.handleResults(tasks, revision: revision)
            }
        }
        resolvedEngine.loadProjects { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.refreshAvailableProjects()
            }
        }
    }

    func activate() {
        guard engine != nil else { return }
        let nextSignature = requestSignature
        if needsRefreshOnNextActivation == false,
           lastExecutedSignature == nextSignature {
            return
        }
        refresh(immediate: true)
    }

    func deactivate() {
        refreshCoordinator.cancel()
        isLoading = false
    }

    func releaseResources() {
        refreshCoordinator.cancel()
        engine?.releaseResources()
        engine = nil
        sharedDataRevisionProvider = nil
        latestIssuedSearchRevision = 0
        needsRefreshOnNextActivation = false
        lastExecutedSignature = nil
        isLoading = false
        hasLoaded = false
        sections = []
        availableProjects = []
        recentSearches = []
        commandMode = .search
        isCompletedExpanded = false
        activeSuggestedCommandResult = nil
    }

    func setCommandMode(_ mode: CommandSearchMode) {
        guard commandMode != mode else { return }
        commandMode = mode
        LifeBoardFeedback.selection()
    }

    func updateQuery(_ newValue: String) {
        guard query != newValue else { return }
        clearSuggestedCommandResult()
        query = newValue
        refresh(immediate: false)
    }

    func clearQuery() {
        clearSuggestedCommandResult()
        guard !query.isEmpty else { return }
        query = ""
        refresh(immediate: true)
    }

    func submitCurrentQuery() {
        let text = trimmedQuery
        guard text.isEmpty == false else { return }
        recordRecentSearch(text)
    }

    func recordRecentSearch(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        recentSearches.insert(normalized, at: 0)
        if recentSearches.count > 5 {
            recentSearches.removeLast(recentSearches.count - 5)
        }
    }

    func setStatus(_ status: HomeSearchStatusFilter) {
        guard selectedStatus != status else { return }
        clearSuggestedCommandResult()
        selectedStatus = status
        refresh(immediate: true)
    }

    func togglePriority(_ priority: TaskPriorityConfig.Priority) {
        clearSuggestedCommandResult()
        let raw = priority.rawValue
        if selectedPriorities.contains(raw) {
            selectedPriorities.remove(raw)
        } else {
            selectedPriorities.insert(raw)
        }
        refresh(immediate: true)
    }

    func toggleProject(_ project: String) {
        clearSuggestedCommandResult()
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
        refresh(immediate: true)
    }

    func clearFilters() {
        clearSuggestedCommandResult()
        guard hasActiveFilters else { return }
        selectedStatus = .all
        selectedPriorities.removeAll()
        selectedProjects.removeAll()
        engine?.clearFilters()
        refresh(immediate: true)
    }

    func runSuggestedCommand(_ result: HomeSearchCommandResult) {
        refreshCoordinator.cancel()
        activeSuggestedCommandResult = result
        commandMode = .search
        query = ""
        isLoading = false
        hasLoaded = true
        sections = []
        selectedPriorities.removeAll()
        selectedProjects.removeAll()
        if result.command == .overdueTasks {
            selectedStatus = .overdue
        } else {
            selectedStatus = .all
        }
        recordRecentSearch(result.command.title)
        LifeBoardFeedback.selection()
    }

    func toggleCompletedExpansion() {
        isCompletedExpanded.toggle()
        LifeBoardFeedback.selection()
    }

    func markDataMutated() {
        needsRefreshOnNextActivation = true
        activeSuggestedCommandResult = nil
        engine?.invalidateSearchCache(revision: currentSearchCacheRevision)
    }

    func refresh(immediate: Bool) {
        guard engine != nil else { return }
        let nextSignature = requestSignature
        if hasLoaded,
           needsRefreshOnNextActivation == false,
           lastExecutedSignature == nextSignature {
            isLoading = false
            return
        }
        guard V2FeatureFlags.iPadPerfSearchCoalescingV2Enabled else {
            let nextRevision = max(1, latestIssuedSearchRevision &+ 1)
            performSearch(refreshGeneration: UInt64(nextRevision))
            return
        }
        logDebug(
            event: "searchRefresh",
            message: "Home search refresh requested",
            fields: [
                "immediate": immediate ? "true" : "false",
                "data_revision": String(currentDataRevision.rawValue),
                "query_length": String(trimmedQuery.count)
            ]
        )
        _ = refreshCoordinator.request(immediate: immediate) { [weak self] refreshGeneration in
            self?.performSearch(refreshGeneration: refreshGeneration)
        }
    }

    private func performSearch(refreshGeneration: UInt64) {
        guard let engine else { return }
        activeSuggestedCommandResult = nil
        let cappedRevision = Int(refreshGeneration % UInt64(Int.max))
        latestIssuedSearchRevision = cappedRevision
        isLoading = true
        let signature = requestSignature
        let projects = signature.projects
        let priorities = signature.priorities
        engine.setFilters(
            status: selectedStatus,
            projects: projects,
            priorities: priorities
        )
        lastExecutedSignature = signature
        needsRefreshOnNextActivation = false
        logDebug(
            event: "searchPerform",
            message: "Home search execution started",
            fields: [
                "search_revision": String(cappedRevision),
                "data_revision": String(currentDataRevision.rawValue),
                "status": selectedStatus.analyticsName,
                "query_length": String(trimmedQuery.count),
                "project_filter_count": String(projects.count),
                "priority_filter_count": String(priorities.count)
            ]
        )
        engine.search(query: trimmedQuery, revision: cappedRevision)
    }

    private func handleResults(_ tasks: [TaskDefinition], revision: Int) {
        guard let engine else { return }
        guard revision >= latestIssuedSearchRevision else { return }
        let nextSections = engine
            .groupTasksByProject(tasks)
            .map { HomeSearchSection(projectName: $0.project, tasks: $0.tasks) }
        if sections != nextSections {
            sections = nextSections
        }
        hasLoaded = true
        isLoading = false
        refreshAvailableProjects()
        LifeBoardPerformanceTrace.event("HomeSearchResultsApplied")
    }

    private func refreshAvailableProjects() {
        let remoteProjectNames = Set((engine?.projects ?? []).map(\.name))
        let visibleProjectNames = Set(sections.map(\.projectName))
        let allProjects = remoteProjectNames
            .union(visibleProjectNames)
            .union([ProjectConstants.inboxProjectName])
        let nextAvailableProjects = allProjects.sorted()
        let nextSelectedProjects = selectedProjects.intersection(allProjects)
        if availableProjects != nextAvailableProjects {
            availableProjects = nextAvailableProjects
        }
        if selectedProjects != nextSelectedProjects {
            selectedProjects = nextSelectedProjects
        }
    }

    private var requestSignature: HomeSearchRequestSignature {
        HomeSearchRequestSignature(
            dataRevision: currentDataRevision.rawValue,
            query: trimmedQuery,
            status: selectedStatus,
            priorities: selectedPriorities.sorted(),
            projects: selectedProjects.sorted()
        )
    }

    private var currentDataRevision: HomeDataRevision {
        sharedDataRevisionProvider?() ?? .zero
    }

    private var currentSearchCacheRevision: Int {
        Int(truncatingIfNeeded: currentDataRevision.rawValue)
    }

    private func clearSuggestedCommandResult() {
        activeSuggestedCommandResult = nil
    }
}
