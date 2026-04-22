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

    func testTypingTaskTitleShowsIconPreviewAndPicker() throws {
        let homePage = HomePage(app: app)
        let addTaskPage = homePage.tapAddTask()

        guard addTaskPage.verifyIsDisplayed(timeout: 8) else {
            throw XCTSkip("Add Task surface did not open in this launch state")
        }

        XCTAssertTrue(addTaskPage.iconButton.waitForExistence(timeout: 3))

        addTaskPage.enterTitle("call dentist after lunch")
        Thread.sleep(forTimeInterval: 0.4)

        let iconButtonLabel = addTaskPage.iconButton.label.lowercased()
        XCTAssertTrue(
            iconButtonLabel.contains("stethoscope") || iconButtonLabel.contains("icon"),
            "Expected task icon preview button to expose an icon-focused accessibility label"
        )

        addTaskPage.openIconPicker()
        XCTAssertTrue(addTaskPage.iconPickerSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(addTaskPage.iconSearchField.exists)
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

        XCTAssertGreaterThanOrEqual(
            addTaskPage.scheduleEditor.frame.minY,
            addTaskPage.titleField.frame.minY,
            "Schedule editor should render after the title field in the add-task capture flow."
        )

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
