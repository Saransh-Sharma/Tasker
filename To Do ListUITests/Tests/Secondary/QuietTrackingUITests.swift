import XCTest

final class QuietTrackingUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedQuietTrackingWorkspace.rawValue
        ]
    }

    func testQuietTrackingSheetSupportsScrollSelectionAndSave() {
        let homePage = HomePage(app: app)

        XCTAssertTrue(homePage.passiveTrackingRail.waitForExistence(timeout: 8), "Passive tracking rail should appear in the seeded workspace")

        let passiveTrackingCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityIdentifiers.Home.passiveTrackingCard(""))
        )
        XCTAssertGreaterThanOrEqual(passiveTrackingCards.count, 2, "Seeded quiet tracking workspace should expose at least two passive tracking cards")

        let secondPassiveTrackingCard = passiveTrackingCards.element(boundBy: 1)
        XCTAssertTrue(secondPassiveTrackingCard.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForElementToBeHittable(secondPassiveTrackingCard, timeout: 3))
        secondPassiveTrackingCard.tap()

        XCTAssertTrue(homePage.quietTrackingSheet.waitForExistence(timeout: 5), "Quiet tracking sheet should open from Home")
        XCTAssertTrue(homePage.quietTrackingSheetScroll.waitForExistence(timeout: 3), "Quiet tracking sheet should expose a scroll container")

        let habitButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.quietTracking.sheet.habit."))
        XCTAssertGreaterThanOrEqual(habitButtons.count, 2, "Seeded quiet tracking workspace should expose at least two habits")

        let secondHabitButton = habitButtons.element(boundBy: 1)
        XCTAssertTrue(secondHabitButton.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForElementToBeHittable(secondHabitButton, timeout: 3))
        secondHabitButton.tap()

        let scrollView = homePage.quietTrackingSheetScroll
        scrollView.swipeUp()
        scrollView.swipeDown()

        XCTAssertEqual(
            homePage.quietTrackingSheetTodayButton.value as? String,
            "Selected",
            "Quiet tracking should default to today"
        )

        XCTAssertTrue(
            scrollToElement(homePage.quietTrackingSheetYesterdayButton, in: scrollView, maxSwipes: 4),
            "The quiet tracking sheet should scroll until the day shortcuts are reachable"
        )
        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSheetYesterdayButton, timeout: 3))

        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSheetOutcomeLapseButton, timeout: 3))
        homePage.quietTrackingSheetOutcomeLapseButton.tap()

        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSheetSaveButton, timeout: 3))
        homePage.quietTrackingSheetSaveButton.tap()

        XCTAssertTrue(waitForElementToDisappear(homePage.quietTrackingSheet, timeout: 5), "Saving should dismiss the quiet tracking sheet")
    }
}
