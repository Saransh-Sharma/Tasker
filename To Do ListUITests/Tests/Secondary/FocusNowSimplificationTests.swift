import XCTest

final class FocusNowSimplificationTests: BaseUITest {
    private enum SeededFocusTitle {
        static let detail = "Focus Row Opens Detail"
    }

    private var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    private func relaunchWithRescueSeed(compact: Bool = false) {
        app.terminate()
        app.launchArguments.removeAll {
            $0 == XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue
                || $0 == XCUIApplication.LaunchArgumentKey.testSeedCompactRescueWorkspace.rawValue
        }
        app.launchArguments.append(
            compact
                ? XCUIApplication.LaunchArgumentKey.testSeedCompactRescueWorkspace.rawValue
                : XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue
        )
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
    }

    private func relaunchWithFocusSeed() {
        app.terminate()
        if !app.launchArguments.contains(XCUIApplication.LaunchArgumentKey.testSeedFocusWorkspace.rawValue) {
            app.launchArguments.append(XCUIApplication.LaunchArgumentKey.testSeedFocusWorkspace.rawValue)
        }
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
    }

    func testFocusNowTitleTapOpensDetailAndHomeStripStaysCompact() throws {
        relaunchWithFocusSeed()
        XCTAssertTrue(homePage.focusStrip.waitForExistence(timeout: 5), "Focus strip should exist with focus seed")

        XCTAssertFalse(app.buttons["home.focus.why"].exists, "Legacy Why button should be removed")
        XCTAssertFalse(app.buttons["home.focus.plan15"].exists, "Plan next 15m button should be removed")
        XCTAssertFalse(app.staticTexts["home.focus.summary"].exists, "Focus summary subtitle should be removed")
        XCTAssertFalse(homePage.focusShuffleButton.exists, "Home Focus Now should no longer expose shuffle")

        let titleTap = homePage.focusTitleTap
        XCTAssertTrue(titleTap.waitForExistence(timeout: 3), "Focus title tap target should exist")
        XCTAssertEqual(titleTap.label, "Focus Now", "Home Focus Now title should not include a count badge")

        let focusStripText = homePage.focusStrip.staticTexts
        XCTAssertFalse(focusStripText["P1"].exists, "Compact Focus Now should not show priority chips")
        XCTAssertFalse(focusStripText["P2"].exists, "Compact Focus Now should not show priority chips")
        XCTAssertFalse(focusStripText["P3"].exists, "Compact Focus Now should not show priority chips")
        XCTAssertFalse(focusStripText["P0"].exists, "Compact Focus Now should not show priority chips")

        if titleTap.isHittable {
            titleTap.tap()
        } else {
            titleTap.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(
            app.navigationBars.staticTexts["Focus Now"].waitForExistence(timeout: 3),
            "Tapping focus title should open the Focus Now detail sheet"
        )
    }

    func testPrimaryWidgetRailDefaultsToFocusNowAndAllowsPagingToWeeklyOperating() throws {
        relaunchWithFocusSeed()

        XCTAssertTrue(homePage.primaryWidgetRail.waitForExistence(timeout: 5), "Primary widget rail should render on Home")
        XCTAssertTrue(homePage.primaryWidgetIndicator.waitForExistence(timeout: 3), "Primary widget indicator should render")
        XCTAssertTrue(homePage.primaryWidgetIndicatorFocusNow.waitForExistence(timeout: 3), "Focus indicator should be present")
        XCTAssertEqual(homePage.primaryWidgetIndicatorFocusNow.value as? String, "selected", "Focus Now should be the default rail selection")

        homePage.swipePrimaryWidgetRailLeft()

        XCTAssertTrue(
            homePage.primaryWidgetIndicatorWeeklyOperating.waitForExistence(timeout: 3),
            "Weekly Operating indicator should be present after paging"
        )
        XCTAssertEqual(
            homePage.primaryWidgetIndicatorWeeklyOperating.value as? String,
            "selected",
            "Weekly Operating should become active after swiping the rail"
        )
    }

    func testPrimaryWidgetRailKeepsUserSelectionWithinSession() throws {
        relaunchWithFocusSeed()

        XCTAssertTrue(homePage.primaryWidgetRail.waitForExistence(timeout: 5), "Primary widget rail should render on Home")
        homePage.swipePrimaryWidgetRailLeft()
        XCTAssertEqual(homePage.primaryWidgetIndicatorWeeklyOperating.value as? String, "selected")

        XCTAssertTrue(homePage.searchButton.waitForExistence(timeout: 3), "Search entry point should exist")
        homePage.searchButton.tap()
        XCTAssertTrue(homePage.searchView.waitForExistence(timeout: 3), "Search should open")

        XCTAssertTrue(homePage.searchBackChip.waitForExistence(timeout: 3), "Back to tasks should be exposed in search")
        homePage.searchBackChip.tap()

        XCTAssertTrue(homePage.primaryWidgetRail.waitForExistence(timeout: 3), "Primary widget rail should still exist after returning from search")
        XCTAssertEqual(
            homePage.primaryWidgetIndicatorWeeklyOperating.value as? String,
            "selected",
            "The session should preserve the last user-selected primary widget"
        )
    }

    func testFocusTaskRowTapStillOpensTaskDetails() throws {
        relaunchWithFocusSeed()

        let focusCard = homePage.focusTaskCard(containingTitle: SeededFocusTitle.detail)
        XCTAssertTrue(focusCard.waitForExistence(timeout: 5), "Seeded focus task row should be exposed")

        if focusCard.isHittable {
            focusCard.tap()
        } else {
            focusCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(
            app.otherElements[AccessibilityIdentifiers.TaskDetail.view].waitForExistence(timeout: 5),
            "Tapping focus task row should still open Task Detail"
        )
    }

    func testVisibleFocusTaskCanBePinnedAndSurvivesDetailShuffle() throws {
        relaunchWithFocusSeed()

        let focusCard = homePage.focusTaskCard(containingTitle: SeededFocusTitle.detail)
        XCTAssertTrue(focusCard.waitForExistence(timeout: 5), "Focus strip should show the expected seeded task")

        let pinButton = homePage.focusPinButton(containingTitle: SeededFocusTitle.detail)
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "Focus pin button should be exposed")

        pinButton.tap()
        waitForAnimations(duration: 0.5)
        XCTAssertEqual(pinButton.label, "Unpin from Focus Now", "Pin state should update before shuffle")

        let titleTap = homePage.focusTitleTap
        XCTAssertTrue(titleTap.waitForExistence(timeout: 3), "Focus title tap target should exist")
        if titleTap.isHittable {
            titleTap.tap()
        } else {
            titleTap.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        let shuffleButton = homePage.focusDetailShuffleButton
        XCTAssertTrue(shuffleButton.waitForExistence(timeout: 3), "Detail sheet should expose shuffle")
        shuffleButton.tap()

        XCTAssertTrue(
            homePage.focusTaskCard(containingTitle: SeededFocusTitle.detail).waitForExistence(timeout: 3),
            "Pinned focus task should remain visible after shuffle"
        )
    }

    func testExpandedRescueTailShowsPersistentStartActionWithoutChevron() throws {
        relaunchWithRescueSeed()

        XCTAssertTrue(
            homePage.rescueSection.waitForExistence(timeout: 5),
            "Rescue section should appear when 15+ day overdue tasks exist"
        )
        XCTAssertTrue(homePage.rescueHeader.exists, "Rescue header should remain visible")
        XCTAssertTrue(homePage.rescueStartButton.exists, "Start rescue button should remain visible in header")
        XCTAssertFalse(homePage.rescueExpandButton.exists, "Expanded Rescue tail should not expose a chevron")
        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue hidden").exists, "Expanded Rescue tail should render all rescue rows inline")
    }

    func testCompactRescueTailExpandsInlinePreview() throws {
        relaunchWithRescueSeed(compact: true)

        XCTAssertTrue(homePage.rescueSection.waitForExistence(timeout: 5), "Rescue section should exist")
        XCTAssertTrue(homePage.rescueOpenButton.exists, "Compact Rescue should expose a main row button")
        XCTAssertTrue(homePage.rescueExpandButton.exists, "Compact Rescue should expose a chevron")
        XCTAssertFalse(homePage.rescueStartButton.exists, "Compact Rescue should not expose the expanded Start rescue button")
        XCTAssertFalse(homePage.rescueRow(containingTitle: "Rescue oldest").exists, "Collapsed compact Rescue should hide inline preview rows")

        homePage.tapRescueExpand()

        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue oldest").waitForExistence(timeout: 3), "Expanded compact Rescue should reveal the oldest rescue row")
        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue middle").exists, "Expanded compact Rescue should reveal the middle rescue row")
        XCTAssertTrue(
            homePage.rescueRow(containingTitle: "Rescue newest").exists,
            "Expanded compact Rescue should reveal all compact rescue rows"
        )
    }

    func testCompactRescueMainRowOpensSheetAndRendersAtTail() throws {
        relaunchWithRescueSeed(compact: true)

        XCTAssertTrue(homePage.rescueSection.waitForExistence(timeout: 5), "Rescue section should exist")
        let focusRow = homePage.taskRow(containingTitle: "Today focus seed")
        XCTAssertTrue(focusRow.waitForExistence(timeout: 5), "Expected seeded Today task row")
        XCTAssertGreaterThan(homePage.rescueSection.frame.minY, focusRow.frame.maxY, "Rescue tail should render after visible Today rows")

        homePage.tapRescueOpen()

        XCTAssertTrue(
            homePage.rescueSheet.waitForExistence(timeout: 5),
            "Compact Rescue main row should open the Rescue sheet"
        )
    }

    func testZeroRescueStateDoesNotRenderRescueTail() throws {
        app.terminate()
        app.launchArguments.removeAll {
            $0 == XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue
                || $0 == XCUIApplication.LaunchArgumentKey.testSeedCompactRescueWorkspace.rawValue
        }
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)

        XCTAssertFalse(homePage.rescueSection.waitForExistence(timeout: 2), "Rescue tail should not render without rescue items")
    }
}
