//
//  TaskEditingTests.swift
//  LifeBoardUITests
//
//  Critical Tests: Task Editing
//  A Home task row opens the task route (`TaskRouteView`), which autosaves.
//

import XCTest

class TaskEditingTests: BaseUITest {

    var homePage: HomePage!
    private let seededTaskTitle = "Draft update"
    private let seededProjectTitle = "Ship one thing"

    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue]
    }

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
        XCTAssertTrue(homePage.waitForTask(withTitle: seededTaskTitle, timeout: 8), "Seeded task should be visible")
    }

    /// The task route (`TaskRouteView`) opened from a Home task row.
    private func taskEditorTitleInput() -> XCUIElement {
        let textField = app.textFields[AccessibilityIdentifiers.TaskEditor.title]
        if textField.exists {
            return textField
        }
        let textView = app.textViews[AccessibilityIdentifiers.TaskEditor.title]
        if textView.exists {
            return textView
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.TaskEditor.title]
    }

    /// The editor autosaves when a field loses focus; tapping the title bar
    /// ends editing and the route shows a "Task updated" receipt.
    private func flushEditorAndWaitForReceipt(file: StaticString = #filePath, line: UInt = #line) {
        homePage.taskRouteNavigationBar.tap()
        XCTAssertTrue(
            app.staticTexts["Task updated"].waitForExistence(timeout: 10),
            "The task editor should confirm the autosave",
            file: file,
            line: line
        )
    }

    private func chip(_ field: String) -> XCUIElement {
        app.buttons[AccessibilityIdentifiers.TaskEditor.chip(field)]
    }

    // MARK: - Edit Task Title

    func testEditTaskTitle() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let titleField = taskEditorTitleInput()
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Task title field should exist")
        clearAndTypeText(titleField, text: "Edited Task Title")
        flushEditorAndWaitForReceipt()

        homePage.returnFromTaskRoute()

        XCTAssertTrue(homePage.waitForTask(withTitle: "Edited Task Title", timeout: 5), "Task title should be updated on Home")
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Old title should not exist")

        takeScreenshot(named: "edit_task_title")
    }

    func testLongTaskTitleWrapsInTaskDetail() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let longTitle = "Edited task title that is intentionally long enough to wrap across multiple lines so the full wording stays visible in task detail."
        let titleField = taskEditorTitleInput()
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Task title field should exist")

        clearAndTypeText(titleField, text: longTitle)
        waitForAnimations(duration: 0.5)

        XCTAssertEqual(titleField.value as? String, longTitle, "Long title should remain editable without truncating the value")
        XCTAssertGreaterThan(titleField.frame.height, 44, "Long title field should grow taller than a single-line field")

        takeScreenshot(named: "edit_task_long_title_wrap")
    }

    // MARK: - Edit Task Priority

    func testEditTaskPriority() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let priorityChip = chip("priority")
        XCTAssertTrue(priorityChip.waitForExistence(timeout: 5), "The editor should offer a Priority chip")
        if priorityChip.label.localizedCaseInsensitiveContains("High") == false {
            priorityChip.tap()
            // The Priority picker is a menu; its current value opens it.
            let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] 'Priority'"))
                .matching(NSPredicate(format: "identifier != %@", AccessibilityIdentifiers.TaskEditor.chip("priority")))
                .firstMatch
            XCTAssertTrue(picker.waitForExistence(timeout: 3), "The Priority picker should appear under the chips")
            picker.tap()
            let high = app.buttons["High"]
            XCTAssertTrue(high.waitForExistence(timeout: 3), "High priority option should be visible")
            high.tap()
        }

        let highPredicate = NSPredicate(format: "label CONTAINS[c] 'High'")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: highPredicate, object: priorityChip)], timeout: 5),
            .completed,
            "The Priority chip should read High after choosing it"
        )

        takeScreenshot(named: "edit_task_priority")
    }

    // MARK: - Edit Task Deadline

    func testEditTaskDueDate() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let deadlineChip = chip("deadline")
        XCTAssertTrue(deadlineChip.waitForExistence(timeout: 5), "The editor should offer a Deadline chip")
        let originalLabel = deadlineChip.label

        if originalLabel.localizedCaseInsensitiveContains("Due") == false {
            deadlineChip.tap()
            let deadlineToggle = app.switches["Deadline"]
            XCTAssertTrue(deadlineToggle.waitForExistence(timeout: 3), "Choosing Deadline should show its toggle")
            deadlineToggle.tap()
        }

        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 3), "A deadline should expose its date picker")
        let duePredicate = NSPredicate(format: "label CONTAINS[c] 'Due'")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: duePredicate, object: deadlineChip)], timeout: 5),
            .completed,
            "The Deadline chip should show a concrete due date"
        )

        takeScreenshot(named: "edit_task_due_date")
    }

    // MARK: - Edit Task Project

    func testEditTaskProject() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let projectChip = chip("project")
        XCTAssertTrue(projectChip.waitForExistence(timeout: 5), "The editor should offer a Project chip")
        if projectChip.label.localizedCaseInsensitiveContains(seededProjectTitle) == false {
            projectChip.tap()
        }

        let projectControl = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Project' AND identifier != %@", AccessibilityIdentifiers.TaskEditor.chip("project"))
        ).firstMatch
        XCTAssertTrue(
            projectControl.waitForExistence(timeout: 3) || app.staticTexts[seededProjectTitle].exists,
            "Project controls should appear in the task editor"
        )

        homePage.returnFromTaskRoute()
        XCTAssertTrue(homePage.waitForTask(withTitle: seededTaskTitle, timeout: 5), "Task should still exist")

        takeScreenshot(named: "edit_task_project")
    }

    // MARK: - Edit Task Notes

    func testEditTaskDescription() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: seededTaskTitle), "Task should exist")

        homePage.tapTask(containingTitle: seededTaskTitle)
        XCTAssertTrue(homePage.taskRouteNavigationBar.waitForExistence(timeout: 8), "Task route should open")

        let notesField = app.textFields[AccessibilityIdentifiers.TaskEditor.notes].exists
            ? app.textFields[AccessibilityIdentifiers.TaskEditor.notes]
            : app.descendants(matching: .any)[AccessibilityIdentifiers.TaskEditor.notes]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5), "Task notes field should exist")
        notesField.tap()
        notesField.typeText("Edited description content")
        flushEditorAndWaitForReceipt()

        homePage.returnFromTaskRoute()
        XCTAssertTrue(homePage.waitForTask(withTitle: seededTaskTitle, timeout: 5), "Task should still exist with updated notes")

        takeScreenshot(named: "edit_task_description")
    }
}
