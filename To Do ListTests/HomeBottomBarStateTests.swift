import XCTest
@testable import To_Do_List

@MainActor
final class HomeBottomBarStateTests: XCTestCase {

    func testSelectUpdatesSelectedItem() {
        let state = HomeBottomBarState()

        state.select(.charts)
        XCTAssertEqual(state.selectedItem, .charts)

        state.select(.search)
        XCTAssertEqual(state.selectedItem, .search)

        state.select(.chat)
        XCTAssertEqual(state.selectedItem, .chat)

        state.select(.create)
        XCTAssertEqual(state.selectedItem, .create)
    }

    func testLargePositiveDeltaMinimizesBottomBar() {
        let state = HomeBottomBarState()
        XCTAssertFalse(state.isMinimized)

        state.updateMinimizeState(fromScrollDelta: 24)
        XCTAssertTrue(state.isMinimized)
    }

    func testLargeNegativeDeltaRestoresBottomBar() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.updateMinimizeState(fromScrollDelta: -20)
        XCTAssertFalse(state.isMinimized)
    }

    func testSmallJitterDoesNotToggleState() {
        let state = HomeBottomBarState()
        XCTAssertFalse(state.isMinimized)

        state.updateMinimizeState(fromScrollDelta: 3)
        XCTAssertFalse(state.isMinimized)

        state.isMinimized = true
        state.updateMinimizeState(fromScrollDelta: -3)
        XCTAssertTrue(state.isMinimized)
    }
}
