import XCTest
@testable import To_Do_List

@MainActor
final class HomeBottomBarStateTests: XCTestCase {

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
}
