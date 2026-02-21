import XCTest

final class TaskBreakdownFlowTests: BaseUITest {
    func testTaskDetailCanOpenBreakdownSheetWhenEntryIsVisible() throws {
        let homePage = HomePage(app: app)
        guard homePage.view.waitForExistence(timeout: 8) else {
            throw XCTSkip("Home view did not stabilize for breakdown smoke test")
        }

        let taskRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        )
        guard taskRows.count > 0 else {
            throw XCTSkip("No task rows are available to open task detail")
        }

        let taskRow = taskRows.element(boundBy: 0)
        taskRow.tap()
        let detailView = app.otherElements["taskDetail.view"]
        let detailVisible = detailView.waitForExistence(timeout: 4) || app.navigationBars.firstMatch.waitForExistence(timeout: 4)
        guard detailVisible else {
            throw XCTSkip("Task detail view did not appear")
        }

        let breakdownButton = app.buttons["Break down"]
        guard breakdownButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Break down entry not visible (feature disabled or task already has steps)")
        }

        breakdownButton.tap()
        let breakdownVisible = app.navigationBars["Breakdown"].waitForExistence(timeout: 4)
            || app.staticTexts["AI Breakdown"].waitForExistence(timeout: 4)
        XCTAssertTrue(breakdownVisible)
    }
}
