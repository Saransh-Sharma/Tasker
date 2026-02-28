import XCTest
@testable import To_Do_List

@MainActor
final class HomeBottomBarStateTests: XCTestCase {
    private var originalSchedulerFlag: Bool = true

    override func setUp() {
        super.setUp()
        originalSchedulerFlag = V2FeatureFlags.iPadPerfBottomBarSchedulerV2Enabled
        V2FeatureFlags.iPadPerfBottomBarSchedulerV2Enabled = true
    }

    override func tearDown() {
        V2FeatureFlags.iPadPerfBottomBarSchedulerV2Enabled = originalSchedulerFlag
        super.tearDown()
    }

    func testSelectUpdatesSelectedItem() {
        let state = HomeBottomBarState()

        state.select(.home)
        XCTAssertEqual(state.selectedItem, .home)

        state.select(.charts)
        XCTAssertEqual(state.selectedItem, .charts)

        state.select(.search)
        XCTAssertEqual(state.selectedItem, .search)

        state.select(.chat)
        XCTAssertEqual(state.selectedItem, .chat)

        state.select(.create)
        XCTAssertEqual(state.selectedItem, .create)
    }

    func testSelectedItemDefaultsToHome() {
        let state = HomeBottomBarState()
        XCTAssertEqual(state.selectedItem, .home)
    }

    func testCumulativeDownwardScrollMinimizesBottomBar() {
        let state = HomeBottomBarState()
        XCTAssertFalse(state.isMinimized)

        state.handleScrollOffsetChange(120)
        state.handleScrollOffsetChange(132)
        XCTAssertFalse(state.isMinimized)

        state.handleScrollOffsetChange(145)
        XCTAssertTrue(state.isMinimized)
    }

    func testCumulativeUpwardScrollRestoresBottomBar() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleScrollOffsetChange(200)
        state.handleScrollOffsetChange(194)
        XCTAssertTrue(state.isMinimized)

        state.handleScrollOffsetChange(188)
        XCTAssertFalse(state.isMinimized)
    }

    func testSmallJitterDoesNotToggleState() {
        let state = HomeBottomBarState()
        XCTAssertFalse(state.isMinimized)

        state.handleScrollOffsetChange(120)
        state.handleScrollOffsetChange(123)
        XCTAssertFalse(state.isMinimized)

        state.isMinimized = true
        state.handleScrollOffsetChange(200)
        state.handleScrollOffsetChange(196)
        XCTAssertTrue(state.isMinimized)
    }

    func testNearTopAlwaysShowsCluster() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleScrollOffsetChange(120)
        state.handleScrollOffsetChange(30)

        XCTAssertFalse(state.isMinimized)
    }

    func testIdleRevealRestoresBottomBarAfterDelay() async {
        let state = HomeBottomBarState()
        state.handleScrollOffsetChange(120)
        state.handleScrollOffsetChange(152)
        XCTAssertTrue(state.isMinimized)

        try? await _Concurrency.Task.sleep(nanoseconds: 550_000_000)

        XCTAssertFalse(state.isMinimized)
    }

    func testRapidDownwardScrollUsesSingleIdleRevealWorker() {
        let state = HomeBottomBarState()

        state.handleScrollOffsetChange(100)
        for step in 1...48 {
            state.handleScrollOffsetChange(100 + CGFloat(step * 4))
        }

        XCTAssertLessThanOrEqual(state.idleRevealSchedulerWorkerStartsForTesting, 1)
    }
}
