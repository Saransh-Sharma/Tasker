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

        XCTAssertTrue(homePage.quietTrackingSummary.waitForExistence(timeout: 8), "Quiet tracking summary should appear in the seeded workspace")
        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSummary, timeout: 3))
        homePage.quietTrackingSummary.tap()

        XCTAssertTrue(homePage.quietTrackingSheet.waitForExistence(timeout: 5), "Quiet tracking sheet should open from Home")
        XCTAssertTrue(homePage.quietTrackingSheetScroll.waitForExistence(timeout: 3), "Quiet tracking sheet should expose a scroll container")

        let habitButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.quietTracking.sheet.habit."))
        XCTAssertGreaterThanOrEqual(habitButtons.count, 2, "Seeded quiet tracking workspace should expose at least two habits")

        let secondHabitButton = habitButtons.element(boundBy: 1)
        XCTAssertTrue(secondHabitButton.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForElementToBeHittable(secondHabitButton, timeout: 3))
        secondHabitButton.tap()

        let selectedDateLabel = app.staticTexts[AccessibilityIdentifiers.Home.quietTrackingSheetSelectedDate]
        XCTAssertTrue(selectedDateLabel.waitForExistence(timeout: 3))
        let initialDateLabel = selectedDateLabel.label
        let formatStyle = Date.FormatStyle.dateTime.weekday(.wide).month(.abbreviated).day()
        let yesterdayLabel = (Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()).formatted(formatStyle)
        let todayLabel = Date().formatted(formatStyle)

        let scrollView = homePage.quietTrackingSheetScroll
        scrollView.swipeUp()
        scrollView.swipeDown()

        let targetLabel: String
        let targetButton: XCUIElement
        if initialDateLabel == yesterdayLabel {
            targetLabel = todayLabel
            targetButton = homePage.quietTrackingSheetTodayButton
        } else {
            targetLabel = yesterdayLabel
            targetButton = homePage.quietTrackingSheetYesterdayButton
        }

        XCTAssertTrue(waitForElementToBeHittable(targetButton, timeout: 3))
        targetButton.tap()
        let changedPredicate = NSPredicate(format: "label == %@", targetLabel)
        let changedExpectation = XCTNSPredicateExpectation(predicate: changedPredicate, object: selectedDateLabel)
        XCTAssertEqual(
            XCTWaiter.wait(for: [changedExpectation], timeout: 3),
            .completed,
            "Changing the selected day should update the visible day label"
        )

        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSheetOutcomeLapseButton, timeout: 3))
        homePage.quietTrackingSheetOutcomeLapseButton.tap()

        XCTAssertTrue(waitForElementToBeHittable(homePage.quietTrackingSheetSaveButton, timeout: 3))
        homePage.quietTrackingSheetSaveButton.tap()

        XCTAssertTrue(waitForElementToDisappear(homePage.quietTrackingSheet, timeout: 5), "Saving should dismiss the quiet tracking sheet")
    }
}
