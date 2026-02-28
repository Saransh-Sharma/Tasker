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

    func testSearchFocusPolicyAutofocusesPhoneOnly() {
        let originalValue = V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled
        defer { V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled = originalValue }
        V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled = true

        XCTAssertTrue(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .phone))
        XCTAssertFalse(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .padRegular))
        XCTAssertFalse(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .padExpanded))
    }

    func testSearchStateActivationSkipsRedundantRefreshWhenSignatureIsUnchanged() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded { engine }
        }

        let initialCount = await MainActor.run { engine.searchQueries.count }

        await MainActor.run {
            state.activate()
        }

        let finalCount = await MainActor.run { engine.searchQueries.count }
        XCTAssertEqual(initialCount, 1)
        XCTAssertEqual(finalCount, initialCount, "Unchanged search activation should not issue a duplicate search")
    }

    func testSearchStateDataMutationForcesRefreshOnNextActivation() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded { engine }
            state.markDataMutated()
            state.activate()
        }

        let queries = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queries.count, 2, "A data mutation should force one additional refresh")
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)?
    var projects: [Project] = [Project.createInbox()]

    var searchQueries: [String] = []
    var searchRevisions: [Int] = []
    var currentStatus: HomeSearchStatusFilter = .all
    var currentPriorities: Set<Int32> = []
    var currentProjects: Set<String> = []
    var stubbedResultsByQuery: [String: [TaskDefinition]] = [:]

    func search(query: String, revision: Int) {
        searchQueries.append(query)
        searchRevisions.append(revision)
        let payload = stubbedResultsByQuery[query] ?? []
        onResultsUpdated?(revision, payload)
    }

    func loadProjects(completion: (() -> Void)?) {
        completion?()
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {
        currentStatus = status
        currentProjects = Set(projects)
        currentPriorities = Set(priorities)
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

    func invalidateSearchCache(revision: Int) {
        _ = revision
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        let grouped = Dictionary(grouping: tasks) { $0.projectName ?? "Inbox" }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.project < $1.project }
    }
}
