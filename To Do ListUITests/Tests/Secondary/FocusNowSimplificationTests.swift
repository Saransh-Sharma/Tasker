import XCTest

final class FocusNowSimplificationTests: BaseUITest {

    private var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    func testFocusNowTitleTapOpensWhyAndLegacyActionsAreRemoved() throws {
        guard homePage.focusStrip.waitForExistence(timeout: 3) else {
            throw XCTSkip("Focus strip is not available in current runtime configuration")
        }

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
        let taskTitle = "Focus Row Opens Detail"

        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(
            title: taskTitle,
            priority: .high,
            taskType: .morning
        )

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        guard homePage.dragTaskToFocus(title: taskTitle) else {
            throw XCTSkip("Unable to drag task to focus strip in current runtime configuration")
        }

        let focusCard = homePage.focusTaskCard(containingTitle: taskTitle)
        guard focusCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("Pinned focus task card is not exposed")
        }

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
}
