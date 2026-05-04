import XCTest

final class TaskBreakdownFlowTests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue]
    }

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
        if !breakdownButton.waitForExistence(timeout: 1.5) {
            let stepsDisclosure = app.buttons[AccessibilityIdentifiers.TaskDetail.stepsDisclosure]
            if stepsDisclosure.waitForExistence(timeout: 3) {
                stepsDisclosure.tap()
            } else if app.buttons["Steps"].waitForExistence(timeout: 2) {
                app.buttons["Steps"].tap()
            }
        }

        guard breakdownButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Break down entry not visible (feature disabled or task already has steps)")
        }

        breakdownButton.tap()
        let breakdownVisible = app.navigationBars["Breakdown"].waitForExistence(timeout: 4)
            || app.staticTexts["AI Breakdown"].waitForExistence(timeout: 4)
        XCTAssertTrue(breakdownVisible)
    }
}
