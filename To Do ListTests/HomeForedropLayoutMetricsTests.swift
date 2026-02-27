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

    func testAnchorMappingSelectsBottomBarHomeForNonAnalyticsAnchors() {
        XCTAssertEqual(ForedropAnchor.collapsed.selectedBottomBarItem, .home)
        XCTAssertEqual(ForedropAnchor.midReveal.selectedBottomBarItem, .home)
    }

    func testAnchorMappingSelectsBottomBarChartsForAnalyticsAnchor() {
        XCTAssertEqual(ForedropAnchor.fullReveal.selectedBottomBarItem, .charts)
    }

    func testAccessibilityValueContractRemainsStable() {
        XCTAssertEqual(ForedropAnchor.collapsed.accessibilityValue, "collapsed")
        XCTAssertEqual(ForedropAnchor.fullReveal.accessibilityValue, "fullReveal")
    }
}
