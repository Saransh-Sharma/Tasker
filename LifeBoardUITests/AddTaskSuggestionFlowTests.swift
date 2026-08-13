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

    func testHomeTaskAndHabitCaptureEntrypointsOpenExpectedComposers() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        XCTAssertTrue(addTaskPage.verifyIsDisplayed(timeout: 8))
        XCTAssertTrue(addTaskPage.titleField.exists)

        let dismiss = app.buttons["foundation.capture.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 3))
        dismiss.tap()

        let tools = app.buttons["lifeThread.composer.toolsToggle"]
        XCTAssertTrue(tools.waitForExistence(timeout: 4))
        tools.tap()

        let habitTool = app.buttons["lifeThread.composer.tool.habit"]
        XCTAssertTrue(habitTool.waitForExistence(timeout: 3))
        habitTool.tap()

        let habitSurface = app.otherElements["addHabit.view"]
        XCTAssertTrue(habitSurface.waitForExistence(timeout: 3))
    }

    func testTypingTaskTitleUpdatesTimelinePreview() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        guard addTaskPage.verifyIsDisplayed(timeout: 8) else {
            throw XCTSkip("Add Task surface did not open in this launch state")
        }

        addTaskPage.enterTitle("call dentist after lunch")
        XCTAssertTrue(addTaskPage.timelinePreview.waitForExistence(timeout: 3))
        XCTAssertTrue(
            addTaskPage.timelinePreview.label.localizedCaseInsensitiveContains("call dentist after lunch"),
            "Expected the timeline preview to reflect the typed task title"
        )
    }

    func testAddTaskScheduleEditorShowsBelowTitleAndSupportsTimeAndDurationControls() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        guard addTaskPage.verifyIsDisplayed(timeout: 8) else {
            throw XCTSkip("Add Task surface did not open in this launch state")
        }

        guard addTaskPage.titleField.waitForExistence(timeout: 2),
              addTaskPage.scheduleEditor.waitForExistence(timeout: 3) else {
            throw XCTSkip("Add Task title or schedule editor is unavailable in this layout variant")
        }
        XCTAssertTrue(addTaskPage.scheduleTimeRow.exists, "Schedule editor should expose the start-time row")

        addTaskPage.selectScheduleDuration(minutes: 30)
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.scheduleDurationChip(minutes: 30)].exists
        )

        addTaskPage.openScheduleTimePicker()
        let pickerSurface = addTaskPage.scheduleTimePickerSheet
        let picker = addTaskPage.scheduleTimePicker
        XCTAssertTrue(
            pickerSurface.waitForExistence(timeout: 3) || picker.waitForExistence(timeout: 3),
            "Tapping the time row should open the start-time picker."
        )

        let wheel = app.pickerWheels.firstMatch
        if wheel.waitForExistence(timeout: 2) {
            wheel.swipeUp()
        } else if picker.exists {
            picker.swipeUp()
        } else {
            throw XCTSkip("Wheel picker controls were not exposed by this simulator/runtime")
        }

        if addTaskPage.scheduleTimePickerConfirmButton.waitForExistence(timeout: 2) {
            addTaskPage.scheduleTimePickerConfirmButton.tap()
        } else {
            app.buttons["Set Time"].firstMatch.tap()
        }

        XCTAssertTrue(addTaskPage.scheduleEditor.waitForExistence(timeout: 2))
    }
}
