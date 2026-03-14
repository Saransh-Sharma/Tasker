import XCTest
@testable import To_Do_List

final class HomeTaskMutationPayloadTests: XCTestCase {

    func testLineChartIgnoresNonChartTaskUpdate() {
        let payload = HomeTaskMutationPayload(
            reason: .updated,
            source: "test",
            taskID: UUID()
        )

        XCTAssertFalse(ChartInvalidationPolicy.shouldRefreshLineChart(for: payload, referenceDate: Date()))
        XCTAssertFalse(ChartInvalidationPolicy.shouldRefreshRadarChart(for: payload, referenceDate: Date()))
    }

    func testLineChartRefreshesForCompletedTaskInsideDisplayedWeek() {
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

        XCTAssertTrue(ChartInvalidationPolicy.shouldRefreshLineChart(for: payload, referenceDate: referenceDate))
        XCTAssertTrue(ChartInvalidationPolicy.shouldRefreshRadarChart(for: payload, referenceDate: referenceDate))
    }

    func testRadarChartRefreshesForProjectMutationWithoutTaskPayload() {
        let payload = HomeTaskMutationPayload(
            reason: .projectChanged,
            source: "test",
            affectedProjectID: UUID()
        )

        XCTAssertFalse(ChartInvalidationPolicy.shouldRefreshLineChart(for: payload, referenceDate: Date()))
        XCTAssertTrue(ChartInvalidationPolicy.shouldRefreshRadarChart(for: payload, referenceDate: Date()))
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
