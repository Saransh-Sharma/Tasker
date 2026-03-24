import XCTest
@testable import To_Do_List

final class HomeBandLayoutPlannerTests: XCTestCase {
    func testVisibleBandsStayInEditorialOrder() {
        let bands = HomeBandLayoutPlanner.visibleBands(
            hasQuickFilters: true,
            hasDueTodayAgenda: true,
            hasPressureTools: true,
            hasSecondaryContent: true
        )

        XCTAssertEqual(bands, [.context, .activeWork, .pressure, .secondary])
    }

    func testVisibleBandsSkipEmptyBandsWithoutReorderingRemainingBands() {
        let bands = HomeBandLayoutPlanner.visibleBands(
            hasQuickFilters: false,
            hasDueTodayAgenda: true,
            hasPressureTools: true,
            hasSecondaryContent: false
        )

        XCTAssertEqual(bands, [.activeWork, .pressure])
    }
}
