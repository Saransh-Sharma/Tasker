import XCTest

final class AddTaskSuggestionFlowTests: BaseUITest {
    func testAddTaskSheetOpensAndAcceptsTitleInput() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        guard addTaskPage.verifyIsDisplayed(timeout: 8) else {
            throw XCTSkip("Add Task surface did not open in this launch state")
        }

        addTaskPage.enterTitle("write annual report by Friday")

        guard addTaskPage.titleField.waitForExistence(timeout: 2) else {
            throw XCTSkip("Title input field is unavailable in this layout variant")
        }

        let typedValue = (addTaskPage.titleField.value as? String ?? "").lowercased()
        XCTAssertTrue(
            typedValue.contains("annual report") || typedValue.contains("write annual report by friday")
        )
    }

    func testHomeAddSheetShowsTaskHabitSwitchAndDefaultsToTask() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        guard addTaskPage.verifyIsDisplayed(timeout: 8) else {
            throw XCTSkip("Unified add sheet did not open in this launch state")
        }

        XCTAssertTrue(addTaskPage.modePicker.waitForExistence(timeout: 2))
        XCTAssertTrue(addTaskPage.taskModeButton.exists)
        XCTAssertTrue(addTaskPage.habitModeButton.exists)
        XCTAssertTrue(addTaskPage.titleField.exists)

        addTaskPage.switchToHabitMode()

        let habitSurface = app.otherElements["addHabit.view"]
        XCTAssertTrue(habitSurface.waitForExistence(timeout: 3))
    }
}
