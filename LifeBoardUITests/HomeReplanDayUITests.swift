import XCTest

final class HomeReplanDayUITests: BaseUITest {
    private var homePage: HomePage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    func testLaterHidesTopPromptButKeepsReplanDayAvailable() {
        let tray = app.buttons["home.needsReplan.tray"]
        XCTAssertTrue(tray.waitForExistence(timeout: 8), "Needs Replan tray should be visible on Today")

        tray.tap()

        let launcher = app.otherElements["home.needsReplan.launcher"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), "Replan launcher should open from the top prompt")

        let laterButton = app.buttons["Later"]
        XCTAssertTrue(laterButton.waitForExistence(timeout: 2), "Later action should be present in the launcher")
        laterButton.tap()

        XCTAssertFalse(tray.waitForExistence(timeout: 2), "Needs Replan prompt should stay dismissed for today")

        let persistentEntry = app.buttons["home.replanDay.entry"]
        let scrolledIntoView = scrollToElement(persistentEntry, in: homePage.taskListScrollView, maxSwipes: 8)
        XCTAssertTrue(scrolledIntoView, "Replan Day should scroll fully into the visible Home viewport")
        XCTAssertTrue(persistentEntry.exists, "Replan Day entry should exist before tapping")
        XCTAssertTrue(persistentEntry.isHittable, "Replan Day entry should be directly tappable above the bottom chrome")

        XCTAssertTrue(
            homePage.waitForBottomBarState("expanded", timeout: 3),
            "Bottom bar should restore before checking Replan Day clearance"
        )
        XCTAssertTrue(homePage.foredropSurface.waitForExistence(timeout: 3), "Foredrop surface should exist for edge-to-edge regression")
        XCTAssertGreaterThanOrEqual(
            homePage.foredropSurface.frame.maxY,
            homePage.view.frame.maxY - 2,
            "Foredrop surface should remain edge-to-edge behind the bottom chrome"
        )
        XCTAssertTrue(persistentEntry.isHittable, "Replan Day entry should remain tappable after the bottom bar restores")
        let bottomChromeTop = bottomChromeTopEdge()
        XCTAssertLessThanOrEqual(
            persistentEntry.frame.maxY + 8,
            bottomChromeTop,
            "Replan Day entry should rest above the bottom app bar and FAB"
        )

        persistentEntry.tap()

        XCTAssertTrue(launcher.waitForExistence(timeout: 5), "Replan Day entry should reopen the launcher")
    }

    func testRescueSeedShowsPastDayBacklogInLauncher() {
        let tray = app.buttons["home.needsReplan.tray"]
        XCTAssertTrue(tray.waitForExistence(timeout: 8), "Needs Replan tray should be visible for the rescue seed")

        tray.tap()

        let launcher = app.otherElements["home.needsReplan.launcher"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), "Replan launcher should open")
        XCTAssertTrue(app.staticTexts["4 tasks need a decision"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Spanning 4 past days"].waitForExistence(timeout: 3))
    }

    func testReplanCardExposesLifeBoardActionsAndHotZones() {
        let tray = app.buttons["home.needsReplan.tray"]
        XCTAssertTrue(tray.waitForExistence(timeout: 8), "Needs Replan tray should be visible")
        tray.tap()

        let startButton = app.buttons["home.needsReplan.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Start Replan should be available")
        startButton.tap()

        let card = app.descendants(matching: .any)["home.needsReplan.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Replan card should be visible")
        XCTAssertTrue(app.descendants(matching: .any)["home.needsReplan.dragSource"].waitForExistence(timeout: 3), "Replan task should expose a drag source")

        XCTAssertTrue(app.buttons["home.needsReplan.action.inbox"].exists, "Move to Inbox fallback action should be accessible")
        XCTAssertTrue(app.buttons["home.needsReplan.action.planToday"].exists, "Plan Today fallback action should be accessible")
        XCTAssertTrue(app.buttons["home.needsReplan.action.complete"].exists, "Complete fallback action should be accessible")
        XCTAssertTrue(app.buttons["home.needsReplan.action.delete"].exists, "Delete fallback action should be accessible")

        XCTAssertTrue(app.descendants(matching: .any)["home.needsReplan.hotZone.planToday"].exists, "Plan Today hot zone should be present for drag targeting")
        XCTAssertTrue(app.descendants(matching: .any)["home.needsReplan.hotZone.moveToInbox"].exists, "Inbox hot zone should be present for drag targeting")
        XCTAssertTrue(app.descendants(matching: .any)["home.needsReplan.hotZone.complete"].exists, "Complete hot zone should be present for drag targeting")
        XCTAssertTrue(app.descendants(matching: .any)["home.needsReplan.hotZone.delete"].exists, "Delete hot zone should be present for drag targeting")
    }

    private func bottomChromeTopEdge() -> CGFloat {
        var topEdges: [CGFloat] = []
        if homePage.bottomBar.exists {
            topEdges.append(homePage.bottomBar.frame.minY)
        }
        if homePage.addTaskButton.exists {
            topEdges.append(homePage.addTaskButton.frame.minY)
        }
        return topEdges.min() ?? app.frame.maxY
    }
}
