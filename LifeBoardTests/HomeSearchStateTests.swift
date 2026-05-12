import XCTest
@testable import LifeBoard

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

    func testOlderSearchResultsDoNotOverrideNewerRevision() {
        let state = HomeSearchState(debounceDelay: 0)
        let engine = MockHomeSearchEngine()
        engine.autoEmitResults = false

        state.configureIfNeeded(
            makeEngine: { engine },
            dataRevisionProvider: { HomeDataRevision(rawValue: 1) }
        )

        state.activate()
        state.query = "fresh"
        state.refresh(immediate: true)

        XCTAssertEqual(engine.searchInvocations.map(\.revision), [1, 2])

        engine.onResultsUpdated?(1, [makeTask(title: "Stale")])
        XCTAssertTrue(state.sections.isEmpty)

        engine.onResultsUpdated?(2, [makeTask(title: "Fresh")])
        XCTAssertEqual(state.sections.map(\.projectName), [ProjectConstants.inboxProjectName])
        XCTAssertEqual(state.sections.first?.tasks.map(\.title), ["Fresh"])
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)?
    var projects: [Project] = []
    var searchInvocations: [(query: String, revision: Int)] = []
    var invalidatedRevisions: [Int] = []
    var autoEmitResults = true

    func search(query: String, revision: Int) {
        searchInvocations.append((query, revision))
        if autoEmitResults {
            onResultsUpdated?(revision, [])
        }
    }

    func loadProjects(completion: (@MainActor @Sendable () -> Void)?) {
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
        Dictionary(grouping: tasks) { $0.projectName ?? ProjectConstants.inboxProjectName }
            .map { (project: $0.key, tasks: $0.value) }
            .sorted { $0.project < $1.project }
    }
}

private func makeTask(title: String) -> TaskDefinition {
    Task(
        id: UUID(),
        projectID: ProjectConstants.inboxProjectID,
        name: title,
        priority: .medium,
        dueDate: Date(),
        project: ProjectConstants.inboxProjectName,
        isComplete: false,
        dateCompleted: nil
    )
}
