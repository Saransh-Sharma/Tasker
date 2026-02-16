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

    func testMidRevealOffsetIncludesCalendarExpansion() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 24,
            analyticsSectionHeight: 280,
            geometryHeight: 844
        )

        XCTAssertEqual(
            metrics.offset(for: .midReveal),
            HomeForedropLayoutMetrics.midRevealBaseOffset + 24,
            accuracy: 0.001
        )
    }

    func testFullRevealOffsetEnforcesMinimumAnalyticsPeekFloorWhenSectionIsSmall() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 12,
            analyticsSectionHeight: 280,
            geometryHeight: 1000
        )

        let expectedMid = HomeForedropLayoutMetrics.midRevealBaseOffset + 12
        let expectedFull = expectedMid + HomeForedropLayoutMetrics.minimumAnalyticsPeekAtFullReveal

        XCTAssertEqual(metrics.offset(for: .fullReveal), expectedFull, accuracy: 0.001)
    }

    func testFullRevealOffsetIsCappedByMinimumVisibleForedropHeight() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 12,
            analyticsSectionHeight: 900,
            geometryHeight: 500
        )

        let expectedCapped = 500 - HomeForedropLayoutMetrics.minimumVisibleForedropHeight
        XCTAssertEqual(metrics.offset(for: .fullReveal), expectedCapped, accuracy: 0.001)
    }

    func testFullRevealOffsetIsMateriallyDeeperThanLegacyOnStandardHeightDevice() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 0,
            analyticsSectionHeight: 300,
            geometryHeight: 844
        )

        let legacyFull: CGFloat = 380
        XCTAssertGreaterThan(metrics.offset(for: .fullReveal), legacyFull + 220)
    }

    func testFullRevealNeverFallsAboveMidRevealWhenScreenIsVeryShort() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 20,
            analyticsSectionHeight: 420,
            geometryHeight: 300
        )

        XCTAssertEqual(
            metrics.offset(for: .fullReveal),
            metrics.offset(for: .midReveal),
            accuracy: 0.001
        )
    }
}
