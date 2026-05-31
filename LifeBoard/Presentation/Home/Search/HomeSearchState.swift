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
    @Published var selectedStatus: HomeSearchStatusFilter = .all
    @Published var selectedPriorities: Set<Int32> = []
    @Published var selectedProjects: Set<String> = []
    @Published private(set) var sections: [HomeSearchSection] = []
    @Published private(set) var availableProjects: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

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

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldShowNoResultsMessage: Bool {
        hasLoaded && !isLoading && sections.isEmpty
    }

    var emptyStateTitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Start with what you remember"
        }
        return "No matching tasks"
    }

    var emptyStateSubtitle: String {
        if trimmedQuery.isEmpty && !hasActiveFilters {
            return "Search tasks, notes, habits, or refine the quick chips."
        }
        return "Try a different query or clear one of the quick chips."
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
    }

    func updateQuery(_ newValue: String) {
        guard query != newValue else { return }
        query = newValue
        refresh(immediate: false)
    }

    func clearQuery() {
        guard !query.isEmpty else { return }
        query = ""
        refresh(immediate: true)
    }

    func setStatus(_ status: HomeSearchStatusFilter) {
        guard selectedStatus != status else { return }
        selectedStatus = status
        refresh(immediate: true)
    }

    func togglePriority(_ priority: TaskPriorityConfig.Priority) {
        let raw = priority.rawValue
        if selectedPriorities.contains(raw) {
            selectedPriorities.remove(raw)
        } else {
            selectedPriorities.insert(raw)
        }
        refresh(immediate: true)
    }

    func toggleProject(_ project: String) {
        if selectedProjects.contains(project) {
            selectedProjects.remove(project)
        } else {
            selectedProjects.insert(project)
        }
        refresh(immediate: true)
    }

    func markDataMutated() {
        needsRefreshOnNextActivation = true
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
}
