import XCTest
@testable import To_Do_List

@MainActor
final class HomeBottomBarStateTests: XCTestCase {
    func testSelectUpdatesSelectedItem() {
        let state = HomeBottomBarState()

        state.select(.home)
        XCTAssertEqual(state.selectedItem, .home)

        state.select(.calendar)
        XCTAssertEqual(state.selectedItem, .calendar)

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

    func testCalendarBottomBarSymbolBuildsDaySpecificCalendarSFImageNames() {
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 1), "1.calendar")
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 31), "31.calendar")
    }

    func testCalendarBottomBarSymbolFallsBackForInvalidDay() {
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 0), "calendar")
        XCTAssertEqual(HomeCalendarBottomBarSymbol.symbolName(day: 32), "calendar")
    }

    func testCollapsedChromeStateMinimizesBottomBar() {
        let state = HomeBottomBarState()

        state.handleChromeStateChange(.collapsed)

        XCTAssertTrue(state.isMinimized)
    }

    func testExpandedChromeStateRestoresBottomBar() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.expanded)

        XCTAssertFalse(state.isMinimized)
    }

    func testNearTopChromeStateRestoresBottomBar() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.nearTop)

        XCTAssertFalse(state.isMinimized)
    }

    func testIdleChromeStateRestoresBottomBar() {
        let state = HomeBottomBarState()
        state.isMinimized = true

        state.handleChromeStateChange(.idle)

        XCTAssertFalse(state.isMinimized)
    }

    func testScrollTrackerEmitsOnlyThresholdedChromeTransitions() {
        var tracker = HomeScrollChromeStateTracker()

        XCTAssertNil(tracker.consume(offset: 0))
        XCTAssertEqual(tracker.consume(offset: 52), .expanded)
        XCTAssertNil(tracker.consume(offset: 56))
        XCTAssertNil(tracker.consume(offset: 72))
        XCTAssertEqual(tracker.consume(offset: 80), .collapsed)
        XCTAssertNil(tracker.consume(offset: 83))
        XCTAssertNil(tracker.consume(offset: 74))
        XCTAssertEqual(tracker.consume(offset: 64), .expanded)
    }

    func testScrollTrackerOnlyEmitsIdleOncePerIdlePeriod() {
        var tracker = HomeScrollChromeStateTracker()

        XCTAssertEqual(tracker.consume(offset: 50), .expanded)
        XCTAssertEqual(tracker.emitIdleIfNeeded(), .idle)
        XCTAssertNil(tracker.emitIdleIfNeeded())
        XCTAssertEqual(tracker.consume(offset: 78), .collapsed)
        XCTAssertEqual(tracker.emitIdleIfNeeded(), .idle)
    }

    func testScrollTrackerReturningNearTopResetsChromeState() {
        var tracker = HomeScrollChromeStateTracker()

        XCTAssertEqual(tracker.consume(offset: 50), .expanded)
        XCTAssertEqual(tracker.consume(offset: 80), .collapsed)
        XCTAssertEqual(tracker.consume(offset: 18), .nearTop)
        XCTAssertNil(tracker.consume(offset: 22))
    }
}
