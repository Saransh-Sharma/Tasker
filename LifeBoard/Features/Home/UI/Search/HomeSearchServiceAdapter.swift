import Combine
import Foundation

@MainActor
protocol HomeSearchService: AnyObject {
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
final class HomeSearchEngineAdapter: HomeSearchService {
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
