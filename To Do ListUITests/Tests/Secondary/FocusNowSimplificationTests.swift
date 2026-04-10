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

    func testFocusNowTitleTapOpensWhyAndLegacyActionsAreRemoved() throws {
        relaunchWithFocusSeed()
        XCTAssertTrue(homePage.focusStrip.waitForExistence(timeout: 5), "Focus strip should exist with focus seed")

        XCTAssertFalse(app.buttons["home.focus.why"].exists, "Legacy Why button should be removed")
        XCTAssertFalse(app.buttons["home.focus.plan15"].exists, "Plan next 15m button should be removed")
        XCTAssertFalse(app.staticTexts["home.focus.summary"].exists, "Focus summary subtitle should be removed")

        let titleTap = homePage.focusTitleTap
        XCTAssertTrue(titleTap.waitForExistence(timeout: 3), "Focus title tap target should exist")

        if titleTap.isHittable {
            titleTap.tap()
        } else {
            titleTap.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(
            app.navigationBars.staticTexts["Why Eva Picked These"].waitForExistence(timeout: 3),
            "Tapping focus title should open Why sheet"
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

    func testVisibleFocusTaskCanBePinnedAndSurvivesShuffle() throws {
        relaunchWithFocusSeed()

        let focusCard = homePage.focusTaskCard(containingTitle: SeededFocusTitle.detail)
        XCTAssertTrue(focusCard.waitForExistence(timeout: 5), "Focus strip should show the expected seeded task")

        let pinButton = homePage.focusPinButton(containingTitle: SeededFocusTitle.detail)
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "Focus pin button should be exposed")

        pinButton.tap()
        waitForAnimations(duration: 0.5)
        XCTAssertEqual(pinButton.label, "Unpin from Focus Now", "Pin state should update before shuffle")

        let shuffleButton = homePage.focusShuffleButton
        XCTAssertTrue(shuffleButton.waitForExistence(timeout: 3), "Shuffle button should be exposed")
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
