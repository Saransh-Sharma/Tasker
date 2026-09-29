import XCTest

/// Overdue work on Home and its route into Overdue Rescue.
///
/// The old Home "Needs Replan" tray and launcher are gone. Home now lists
/// slipped work as one "Needs you" row (`home.upNext.rescue`, which opens
/// Plan's overdue week), and the Rescue deck opens from Plan's day
/// (`plan.day.openRescue`).
final class HomeReplanDayUITests: BaseUITest {
    private var homePage: HomePage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedRescueWorkspace.rawValue
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
    }

    func testRescueSeedShowsPastDayBacklogOnHome() {
        let rescueRow = app.buttons[AccessibilityIdentifiers.Home.upNextRescue]
        for _ in 0..<8 where rescueRow.exists == false || rescueRow.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(rescueRow.waitForExistence(timeout: 8), "Home should list slipped work for the rescue seed")
        XCTAssertTrue(
            rescueRow.label.localizedCaseInsensitiveContains("4 tasks from earlier"),
            "Home's Needs you row should count the seeded overdue tasks. Label: \(rescueRow.label)"
        )
    }

    func testStartReplanOpensOverdueRescueDeck() {
        XCTAssertTrue(homePage.openRoot("plan"), "Plan should open from the root chrome")

        let openRescue = app.buttons[AccessibilityIdentifiers.Plan.openRescue]
        for _ in 0..<12 where openRescue.exists == false || openRescue.isHittable == false {
            app.swipeUp()
        }
        XCTAssertTrue(openRescue.waitForExistence(timeout: 8), "Plan should offer Rescue for the seeded overdue work")
        openRescue.tap()

        let rescueSheet = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSheet]
        XCTAssertTrue(rescueSheet.waitForExistence(timeout: 10), "Rescue should open the Overdue Rescue deck")
        XCTAssertTrue(app.staticTexts["Rescue oldest"].waitForExistence(timeout: 5), "Rescue deck should show the seeded oldest rescue task")
    }
}
