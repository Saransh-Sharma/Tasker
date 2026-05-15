import XCTest
@testable import LifeBoard

final class HomeTaskMutationPayloadTests: XCTestCase {

    func testProgressInsightsIgnoresNonInsightsTaskUpdate() {
        let payload = HomeTaskMutationPayload(
            reason: .updated,
            source: "test",
            taskID: UUID()
        )

        XCTAssertFalse(InsightsInvalidationPolicy.shouldRefreshProgressInsights(for: payload, referenceDate: Date()))
        XCTAssertFalse(InsightsInvalidationPolicy.shouldRefreshProjectInsights(for: payload, referenceDate: Date()))
    }

    func testProgressInsightsRefreshesForCompletedTaskInsideDisplayedWeek() {
        let referenceDate = Date()
        let payload = HomeTaskMutationPayload(
            reason: .completed,
            source: "test",
            taskID: UUID(),
            previousIsComplete: false,
            newIsComplete: true,
            previousDueDate: nil,
            newDueDate: referenceDate,
            previousCompletionDate: nil,
            newCompletionDate: referenceDate
        )

        XCTAssertTrue(InsightsInvalidationPolicy.shouldRefreshProgressInsights(for: payload, referenceDate: referenceDate))
        XCTAssertTrue(InsightsInvalidationPolicy.shouldRefreshProjectInsights(for: payload, referenceDate: referenceDate))
    }

    func testProjectInsightsRefreshesForProjectMutationWithoutTaskPayload() {
        let payload = HomeTaskMutationPayload(
            reason: .projectChanged,
            source: "test",
            affectedProjectID: UUID()
        )

        XCTAssertFalse(InsightsInvalidationPolicy.shouldRefreshProgressInsights(for: payload, referenceDate: Date()))
        XCTAssertTrue(InsightsInvalidationPolicy.shouldRefreshProjectInsights(for: payload, referenceDate: Date()))
    }

    func testSearchRefreshTriggersForTaskScopedMutation() {
        let payload = HomeTaskMutationPayload(
            reason: .updated,
            source: "test",
            taskID: UUID()
        )

        XCTAssertTrue(HomeSearchInvalidationPolicy.shouldRefreshSearch(for: payload))
    }

    func testSearchRefreshSkipsProjectMutationWithoutIdentity() {
        let payload = HomeTaskMutationPayload(
            reason: .projectChanged,
            source: "test"
        )

        XCTAssertFalse(HomeSearchInvalidationPolicy.shouldRefreshSearch(for: payload))
    }
}
