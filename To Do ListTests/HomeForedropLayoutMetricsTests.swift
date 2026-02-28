import XCTest
@testable import To_Do_List

final class HomeForedropLayoutMetricsTests: XCTestCase {

    func testCollapsedOffsetIsZero() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 18,
            analyticsSectionHeight: 300,
            geometryHeight: 844
        )

        XCTAssertEqual(metrics.offset(for: .collapsed), 0)
    }

    func testMidRevealOffsetIsAnchored() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 24,
            analyticsSectionHeight: 280,
            geometryHeight: 844
        )

        XCTAssertEqual(metrics.offset(for: .midReveal), 0, accuracy: 0.001)
    }

    func testFullRevealOffsetIsAnchored() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 12,
            analyticsSectionHeight: 280,
            geometryHeight: 1000
        )

        XCTAssertEqual(metrics.offset(for: .fullReveal), 0, accuracy: 0.001)
    }

    func testFaceMappingSelectsBottomBarHomeForTasksFace() {
        XCTAssertEqual(HomeForedropFace.tasks.selectedBottomBarItem, .home)
    }

    func testFaceMappingSelectsBottomBarChartsForAnalyticsFace() {
        XCTAssertEqual(HomeForedropFace.analytics.selectedBottomBarItem, .charts)
    }

    func testFaceMappingSelectsBottomBarSearchForSearchFace() {
        XCTAssertEqual(HomeForedropFace.search.selectedBottomBarItem, .search)
    }

    func testSurfaceAccessibilityValueContractRemainsStableForAllFaces() {
        XCTAssertEqual(HomeForedropFace.tasks.surfaceAccessibilityValue, "collapsed")
        XCTAssertEqual(HomeForedropFace.analytics.surfaceAccessibilityValue, "fullReveal")
        XCTAssertEqual(HomeForedropFace.search.surfaceAccessibilityValue, "fullReveal")
    }

    func testSearchStateDebouncesQueryUpdates() async throws {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0.05)
        }

        await MainActor.run {
            state.configureIfNeeded { engine }
            state.updateQuery("meet")
            state.updateQuery("meeting")
        }

        try await _Concurrency.Task.sleep(nanoseconds: 10_000_000)
        let queriesBeforeDebounce = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queriesBeforeDebounce, [""], "Debounced query should not fire immediately")

        try await _Concurrency.Task.sleep(nanoseconds: 80_000_000)
        let queriesAfterDebounce = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queriesAfterDebounce, ["", "meeting"], "Debounce should emit only latest query")
    }

    func testSearchStateAppliesStatusPriorityAndProjectFiltersTogether() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded { engine }
            state.setStatus(.today)
            state.togglePriority(.high)
            state.toggleProject("Inbox")
        }

        let appliedStatus = await MainActor.run { engine.currentStatus }
        let appliedPriorities = await MainActor.run { engine.currentPriorities }
        let appliedProjects = await MainActor.run { engine.currentProjects }
        XCTAssertEqual(appliedStatus, .today)
        XCTAssertEqual(appliedPriorities, Set([TaskPriorityConfig.Priority.high.rawValue]))
        XCTAssertEqual(appliedProjects, Set(["Inbox"]))
    }

    func testSearchStateEmptyStateTransitionsBetweenDefaultAndNoResultQuery() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            engine.stubbedResultsByQuery[""] = []
            engine.stubbedResultsByQuery["xyz"] = []
            state.configureIfNeeded { engine }
        }

        let defaultTitle = await MainActor.run { state.emptyStateTitle }
        let defaultVisible = await MainActor.run { state.shouldShowNoResultsMessage }
        XCTAssertTrue(defaultVisible)
        XCTAssertEqual(defaultTitle, "Start searching")

        await MainActor.run {
            state.updateQuery("xyz")
        }

        let queryTitle = await MainActor.run { state.emptyStateTitle }
        let queryVisible = await MainActor.run { state.shouldShowNoResultsMessage }
        XCTAssertTrue(queryVisible)
        XCTAssertEqual(queryTitle, "No tasks found")
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: (([TaskDefinition]) -> Void)?
    var projects: [Project] = [Project.createInbox()]

    var searchQueries: [String] = []
    var currentStatus: HomeSearchStatusFilter = .all
    var currentPriorities: Set<Int32> = []
    var currentProjects: Set<String> = []
    var stubbedResultsByQuery: [String: [TaskDefinition]] = [:]

    func search(query: String) {
        searchQueries.append(query)
        let payload = stubbedResultsByQuery[query] ?? []
        onResultsUpdated?(payload)
    }

    func loadProjects(completion: (() -> Void)?) {
        completion?()
    }

    func clearFilters() {
        currentStatus = .all
        currentPriorities.removeAll()
        currentProjects.removeAll()
    }

    func toggleProjectFilter(_ project: String) {
        if currentProjects.contains(project) {
            currentProjects.remove(project)
        } else {
            currentProjects.insert(project)
        }
    }

    func togglePriorityFilter(_ priority: Int32) {
        if currentPriorities.contains(priority) {
            currentPriorities.remove(priority)
        } else {
            currentPriorities.insert(priority)
        }
    }

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {
        currentStatus = filter
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        let grouped = Dictionary(grouping: tasks) { $0.projectName ?? "Inbox" }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.project < $1.project }
    }
}
