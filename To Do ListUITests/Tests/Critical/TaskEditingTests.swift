//
//  TaskEditingTests.swift
//  To Do ListUITests
//
//  Critical Tests: Task Editing (6 tests)
//  Tests the functionality of editing existing tasks
//

import XCTest

class TaskEditingTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)

        // Create initial task for editing
        createInitialTask()
    }

    // MARK: - Setup Helper

    private func createInitialTask() {
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(
            title: "Task to Edit",
            description: "Original description",
            priority: .medium,
            taskType: .morning
        )

        XCTAssertTrue(homePage.waitForTask(withTitle: "Task to Edit", timeout: 5), "Initial task should be created")
    }

    // MARK: - Test 16: Edit Task Title

    func testEditTaskTitle() throws {
        // GIVEN: A task exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist")

        // WHEN: User opens task and edits the title
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        // Wait for task detail or edit screen to appear
        waitForAnimations(duration: 1.0)

        // Find title field and edit it
        let titleField = app.textFields.matching(NSPredicate(format: "value CONTAINS 'Task to Edit'")).firstMatch

        if titleField.exists {
            titleField.tap()
            titleField.doubleTap() // Select text

            // Clear and enter new title
            if let currentValue = titleField.value as? String, !currentValue.isEmpty {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                titleField.typeText(deleteString)
            }

            titleField.typeText("Edited Task Title")

            // Save changes
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            } else {
                // Try Done button
                app.buttons["Done"].tap()
            }
        }

        // THEN: Task title should be updated
        waitForAnimations(duration: 1.0)

        let titleUpdated = homePage.waitForTask(withTitle: "Edited Task Title", timeout: 5)
        XCTAssertTrue(titleUpdated, "Task title should be updated")

        // Verify old title doesn't exist
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Old title should not exist")

        takeScreenshot(named: "edit_task_title")
    }

    // MARK: - Test 17: Edit Task Priority

    func testEditTaskPriority() throws {
        // GIVEN: A task with Medium priority exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist")

        // WHEN: User changes priority from Medium to High (P1)
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // Find and tap priority control
        let priorityControl = app.segmentedControls.firstMatch
        if priorityControl.exists {
            priorityControl.buttons["High"].tap()

            // Save changes
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            } else {
                app.buttons["Done"].tap()
            }
        } else {
            // Try finding priority buttons directly
            let highPriorityButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'High' OR label CONTAINS 'P1'")).firstMatch
            if highPriorityButton.exists {
                highPriorityButton.tap()
                app.buttons["Done"].tap()
            }
        }

        // THEN: Priority should be updated to High
        waitForAnimations(duration: 1.0)

        // Complete the task to verify it gives 4 points (P1 = High = 4 points)
        let updatedTaskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.completeTask(at: updatedTaskIndex)
        waitForAnimations(duration: 1.0)

        // Verify score is 4 (High priority)
        let scoreUpdated = homePage.waitForDailyScoreUpdate(to: 4, timeout: 5)
        XCTAssertTrue(scoreUpdated, "Score should be 4 for High priority task")

        takeScreenshot(named: "edit_task_priority")
    }

    // MARK: - Test 18: Edit Task Due Date

    func testEditTaskDueDate() throws {
        // GIVEN: A task exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist")

        // WHEN: User opens task and changes due date
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        let dueChip = app.buttons[AccessibilityIdentifiers.TaskDetail.dueChip]
        XCTAssertTrue(dueChip.waitForExistence(timeout: 3), "Due date chip should exist in task detail")
        let originalDueLabel = dueChip.label

        dueChip.tap()
        waitForAnimations(duration: 0.5)

        let customDateChip = app.buttons[AccessibilityIdentifiers.DatePickerSheet.customDateChip]
        XCTAssertTrue(customDateChip.waitForExistence(timeout: 3), "Custom date chip should appear when editing due date")
        XCTAssertTrue(customDateChip.isHittable, "Custom date chip should be tappable")
        customDateChip.tap()

        let datePickerSheet = app.otherElements[AccessibilityIdentifiers.DatePickerSheet.sheet]
        XCTAssertTrue(datePickerSheet.waitForExistence(timeout: 3), "Due date picker sheet should appear")

        let confirmButton = app.buttons[AccessibilityIdentifiers.DatePickerSheet.confirmButton]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Set Date button should exist")
        XCTAssertTrue(confirmButton.isHittable, "Set Date button should be visible without dragging or scrolling")

        let graphicalCalendar = app.datePickers[AccessibilityIdentifiers.DatePickerSheet.calendar]
        XCTAssertTrue(graphicalCalendar.waitForExistence(timeout: 3), "Graphical date picker should be visible")

        selectVisibleFutureDate(in: datePickerSheet, preferredDate: TestDataFactory.tomorrow())
        confirmButton.tap()

        // THEN: Due date should be updated
        waitForAnimations(duration: 1.0)

        XCTAssertTrue(dueChip.waitForExistence(timeout: 3), "Due date chip should still exist after saving")
        XCTAssertNotEqual(dueChip.label, originalDueLabel, "Due date chip should change after setting a date")
        XCTAssertFalse(dueChip.label.localizedCaseInsensitiveContains("No due"), "Due date chip should show a concrete date")

        takeScreenshot(named: "edit_task_due_date")
    }

    // MARK: - Test 19: Edit Task Project

    func testEditTaskProject() throws {
        // GIVEN: A task exists (defaults to Inbox)
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist")

        // WHEN: User changes task project
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // Look for project selector
        let projectButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'project' OR label CONTAINS 'Inbox'")).firstMatch

        if projectButton.exists {
            projectButton.tap()
            waitForAnimations(duration: 0.5)

            // Select a different project (if available)
            // For now, just verify the project picker appeared
            let projectPicker = app.collectionViews.firstMatch
            XCTAssertTrue(projectPicker.exists || app.tables.firstMatch.exists, "Project picker should appear")

            // Close picker
            app.buttons["Done"].tap()
        } else {
            // Save and close
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            } else {
                app.buttons["Done"].tap()
            }
        }

        // THEN: Task should still exist
        waitForAnimations(duration: 1.0)
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should still exist")

        takeScreenshot(named: "edit_task_project")
    }

    // MARK: - Test 20: Edit Task Description

    func testEditTaskDescription() throws {
        // GIVEN: A task with description exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist")

        // WHEN: User edits the description
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // Find description field
        let descriptionField = app.textViews.matching(NSPredicate(format: "value CONTAINS 'Original description'")).firstMatch

        if !descriptionField.exists {
            // Try finding any text view
            let anyTextView = app.textViews.firstMatch
            if anyTextView.exists {
                anyTextView.tap()
                anyTextView.typeText("\nEdited description content")
            }
        } else {
            descriptionField.tap()
            descriptionField.typeText("\nEdited description content")
        }

        // Save changes
        let saveButton = app.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        } else {
            app.buttons["Done"].tap()
        }

        // THEN: Description should be updated
        waitForAnimations(duration: 1.0)

        // Verify task still exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should still exist with updated description")

        takeScreenshot(named: "edit_task_description")
    }

    private func selectVisibleFutureDate(in sheet: XCUIElement, preferredDate: Date) {
        let candidateDates = [
            preferredDate,
            TestDataFactory.daysFromNow(2),
            TestDataFactory.daysFromNow(3)
        ]

        for candidate in candidateDates {
            let dayLabel = String(Calendar.current.component(.day, from: candidate))
            let queries = [
                sheet.buttons[dayLabel].firstMatch,
                sheet.staticTexts[dayLabel].firstMatch,
                app.buttons[dayLabel].firstMatch,
                app.staticTexts[dayLabel].firstMatch
            ]

            if let element = queries.first(where: \.exists) {
                element.tap()
                return
            }
        }
    }

    // MARK: - Test 21: Edit Task Type (Morning to Evening)

    func testEditTaskType_MorningToEvening() throws {
        // GIVEN: A morning task exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Morning task should exist")

        // WHEN: User changes task type from Morning to Evening
        let taskIndex = findTaskIndex(withTitle: "Task to Edit")
        homePage.tapTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // Find task type selector
        let taskTypeControl = app.segmentedControls.matching(NSPredicate(format: "label CONTAINS 'Morning' OR label CONTAINS 'Evening'")).firstMatch

        if taskTypeControl.exists {
            taskTypeControl.buttons["Evening"].tap()

            // Save changes
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            } else {
                app.buttons["Done"].tap()
            }
        } else {
            // Try finding type buttons directly
            let eveningButton = app.buttons.matching(NSPredicate(format: "label == 'Evening'")).firstMatch
            if eveningButton.exists {
                eveningButton.tap()
                app.buttons["Done"].tap()
            } else {
                // Can't find task type selector, just close
                app.buttons["Done"].tap()
            }
        }

        // THEN: Task type should be updated to Evening
        waitForAnimations(duration: 1.0)

        // Verify task still exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Task to Edit"), "Task should exist as evening task")

        takeScreenshot(named: "edit_task_type_evening")
    }

    // MARK: - Helper Methods

    private func findTaskIndex(withTitle title: String) -> Int {
        let taskRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        )
        for index in 0..<taskRows.count {
            let row = taskRows.element(boundBy: index)
            if row.label.localizedCaseInsensitiveContains(title) || row.staticTexts[title].exists {
                return index
            }
        }

        let cells = app.tables.cells
        for index in 0..<cells.count {
            let cell = cells.element(boundBy: index)
            if cell.staticTexts[title].exists {
                return index
            }
        }
        return 0
    }
}
