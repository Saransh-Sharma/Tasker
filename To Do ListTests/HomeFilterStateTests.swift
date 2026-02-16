import XCTest
@testable import To_Do_List

final class HomeFilterStateTests: XCTestCase {

    func testDecodingLegacyPayloadUsesDefaultsForGroupingFields() throws {
        let json = """
        {
          "version": 1,
          "quickView": "today",
          "selectedProjectIDs": [],
          "pinnedProjectIDs": [],
          "advancedFilter": null,
          "showCompletedInline": false,
          "selectedSavedViewID": null
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(HomeFilterState.self, from: data)

        XCTAssertEqual(decoded.quickView, .today)
        XCTAssertEqual(decoded.projectGroupingMode, .prioritizeOverdue)
        XCTAssertEqual(decoded.customProjectOrderIDs, [])
    }

    func testEncodingRoundTripPreservesGroupingFields() throws {
        let first = UUID()
        let second = UUID()
        let initial = HomeFilterState(
            quickView: .today,
            projectGroupingMode: .groupByProjects,
            selectedProjectIDs: [first],
            customProjectOrderIDs: [second, first]
        )

        let data = try JSONEncoder().encode(initial)
        let decoded = try JSONDecoder().decode(HomeFilterState.self, from: data)

        XCTAssertEqual(decoded.projectGroupingMode, .groupByProjects)
        XCTAssertEqual(decoded.customProjectOrderIDs, [second, first])
        XCTAssertEqual(decoded.selectedProjectIDs, [first])
    }
}
