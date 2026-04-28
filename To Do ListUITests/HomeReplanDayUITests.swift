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
        XCTAssertTrue(scrolledIntoView || persistentEntry.exists, "Replan Day should remain reachable at the bottom of Home")
        guard persistentEntry.exists else {
            return XCTFail("Replan Day entry should exist before tapping")
        }

        if persistentEntry.isHittable {
            persistentEntry.tap()
        } else {
            persistentEntry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(launcher.waitForExistence(timeout: 5), "Replan Day entry should reopen the launcher")
    }

    func testRescueSeedShowsPastDayBacklogInLauncher() {
        let tray = app.buttons["home.needsReplan.tray"]
        XCTAssertTrue(tray.waitForExistence(timeout: 8), "Needs Replan tray should be visible for the rescue seed")

        tray.tap()

        let launcher = app.otherElements["home.needsReplan.launcher"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), "Replan launcher should open")
        XCTAssertTrue(app.staticTexts["3 tasks need a decision"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Spanning 3 past days"].waitForExistence(timeout: 3))
    }
}
