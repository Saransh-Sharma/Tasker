import XCTest
@testable import To_Do_List

@MainActor
final class HomeSearchStateTests: XCTestCase {
    func testActivateSkipsRefreshWhenRequestSignatureIsUnchanged() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { HomeDataRevision(rawValue: 1) }
        )

        state.activate()
        state.activate()

        XCTAssertEqual(engine.searchInvocations.count, 1)
        XCTAssertEqual(engine.invalidatedRevisions, [1])
    }

    func testMarkDataMutatedForcesRefreshOnNextActivation() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()
        var revision = HomeDataRevision(rawValue: 1)

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { revision }
        )

        state.activate()
        revision = HomeDataRevision(rawValue: 2)
        state.markDataMutated()
        state.activate()

        XCTAssertEqual(engine.invalidatedRevisions, [1, 2])
        XCTAssertEqual(engine.searchInvocations.count, 2)
        XCTAssertEqual(engine.searchInvocations.map(\.revision), [1, 2])
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)?
    var projects: [Project] = []
    var searchInvocations: [(query: String, revision: Int)] = []
    var invalidatedRevisions: [Int] = []

    func search(query: String, revision: Int) {
        searchInvocations.append((query, revision))
        onResultsUpdated?(revision, [])
    }

    func loadProjects(completion: (() -> Void)?) {
        completion?()
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {}

    func clearFilters() {}

    func toggleProjectFilter(_ project: String) {}

    func togglePriorityFilter(_ priority: Int32) {}

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {}

    func invalidateSearchCache(revision: Int) {
        invalidatedRevisions.append(revision)
    }

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        []
    }
}
