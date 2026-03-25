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

    private func relaunchWithRescueSeed() {
        app.terminate()
        if !app.launchArguments.contains(XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue) {
            app.launchArguments.append(XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue)
        }
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

    func testRescueHeaderShowsPersistentStartActionWhenRescueItemsExist() throws {
        relaunchWithRescueSeed()

        XCTAssertTrue(
            homePage.rescueSection.waitForExistence(timeout: 5),
            "Rescue section should appear when 15+ day overdue tasks exist"
        )
        XCTAssertTrue(homePage.rescueHeader.exists, "Rescue header should remain visible")
        XCTAssertTrue(homePage.rescueStartButton.exists, "Start rescue button should remain visible in header")
    }

    func testCollapsedRescueShowsPreviewRowsAndExpandKeepsStartActionVisible() throws {
        relaunchWithRescueSeed()

        XCTAssertTrue(homePage.rescueSection.waitForExistence(timeout: 5), "Rescue section should exist")
        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue oldest").exists, "Collapsed Rescue should show oldest preview row")
        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue middle").exists, "Collapsed Rescue should show second preview row")
        XCTAssertTrue(homePage.rescueRow(containingTitle: "Rescue newest").exists, "Collapsed Rescue should show third preview row")
        XCTAssertFalse(homePage.rescueRow(containingTitle: "Rescue hidden").exists, "Collapsed Rescue should hide rows beyond preview limit")

        homePage.tapRescueExpand()

        XCTAssertTrue(
            homePage.rescueRow(containingTitle: "Rescue hidden").waitForExistence(timeout: 3),
            "Expanded Rescue should reveal rows beyond preview limit"
        )
        XCTAssertTrue(homePage.rescueStartButton.exists, "Start rescue should remain visible after expanding")
    }

    func testStartRescueOpensRescueSheet() throws {
        relaunchWithRescueSeed()

        XCTAssertTrue(homePage.rescueSection.waitForExistence(timeout: 5), "Rescue section should exist")
        homePage.tapStartRescue()

        XCTAssertTrue(
            homePage.rescueSheet.waitForExistence(timeout: 5),
            "Start rescue should open the Rescue sheet"
        )
    }
}
