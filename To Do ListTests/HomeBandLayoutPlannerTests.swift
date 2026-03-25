import XCTest
@testable import To_Do_List

final class HomeBandLayoutPlannerTests: XCTestCase {
    func testVisibleBandsStayInEditorialOrder() {
        let bands = HomeBandLayoutPlanner.visibleBands(
            hasPassiveTracking: true,
            hasFocusHero: true,
            hasTodayAgenda: true,
            hasRescue: true,
            hasQuietTracking: true
        )

        XCTAssertEqual(bands, [.context, .activeWork, .pressure, .secondary])
    }

    func testVisibleBandsSkipEmptyBandsWithoutReorderingRemainingBands() {
        let bands = HomeBandLayoutPlanner.visibleBands(
            hasPassiveTracking: false,
            hasFocusHero: false,
            hasTodayAgenda: true,
            hasRescue: true,
            hasQuietTracking: false
        )

        XCTAssertEqual(bands, [.activeWork, .pressure])
    }
}
