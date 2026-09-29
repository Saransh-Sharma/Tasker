//
//  TaskCompletionTests.swift
//  LifeBoardUITests
//
//  Critical Tests: Task Completion
//  Completing a task from Home's tasks card removes it from the card and
//  leaves a receipt whose Undo reopens it. Home has no score or streak label;
//  the completion receipt is what a completion shows.
//

import XCTest

class TaskCompletionTests: BaseUITest {

    /// New tasks are due today, so they appear in Home's Tasks card, which is
    /// where this suite completes, undoes and deletes them.
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testNewTasksDueToday.rawValue]
    }

    var homePage: HomePage!

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)

        // Create initial tasks for completion testing
        createTestTasks()
    }

    // MARK: - Setup Helper

    /// Create test tasks with various priorities
    private func createTestTasks() {
        let addTaskPage1 = homePage.tapAddTask()
        addTaskPage1.createTask(title: "P0 Task", priority: .max, taskType: .morning)

        let addTaskPage2 = homePage.tapAddTask()
        addTaskPage2.createTask(title: "P1 Task", priority: .high, taskType: .morning)

        let addTaskPage3 = homePage.tapAddTask()
        addTaskPage3.createTask(title: "P2 Task", priority: .medium, taskType: .morning)

        let addTaskPage4 = homePage.tapAddTask()
        addTaskPage4.createTask(title: "P3 Task", priority: .low, taskType: .evening)

        // Wait for all tasks to appear
        XCTAssertTrue(homePage.waitForTaskCount(4, timeout: 10), "All 4 test tasks should be created")
    }

    /// A Home completion takes the row out of the card and offers Undo.
    private func assertCompleted(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            homePage.waitForTaskToDisappear(withTitle: title, timeout: 5),
            "Completed task '\(title)' should leave Home's open tasks",
            file: file,
            line: line
        )
        XCTAssertTrue(
            homePage.undoCompletionButton.waitForExistence(timeout: 5),
            "Completing a task should leave a receipt with Undo",
            file: file,
            line: line
        )
    }

    // MARK: - Complete Task

    func testCompleteTaskShowsUndoReceipt_P0() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P0 Task"), "P0 task should exist")

        homePage.completeTask(containingTitle: "P0 Task")

        assertCompleted("P0 Task")
        takeScreenshot(named: "complete_p0_task_receipt")
    }

    func testCompleteTaskShowsUndoReceipt_P1() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P1 Task"), "P1 task should exist")

        homePage.completeTask(containingTitle: "P1 Task")

        assertCompleted("P1 Task")
        takeScreenshot(named: "complete_p1_task_receipt")
    }

    func testCompleteMultipleTasksRemovesEachFromHome() throws {
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P0 Task"), "P0 task exists")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P1 Task"), "P1 task exists")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P2 Task"), "P2 task exists")

        homePage.completeTask(containingTitle: "P0 Task")
        assertCompleted("P0 Task")

        homePage.completeTask(containingTitle: "P1 Task")
        assertCompleted("P1 Task")

        homePage.completeTask(containingTitle: "P2 Task")
        assertCompleted("P2 Task")

        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P3 Task"), "The untouched task should stay on Home")
        takeScreenshot(named: "complete_multiple_tasks")
    }

    // MARK: - Reopen

    func testUndoReopensCompletedTask() throws {
        homePage.completeTask(containingTitle: "P0 Task")
        assertCompleted("P0 Task")

        homePage.uncompleteLastCompletedTask()

        XCTAssertTrue(homePage.waitForTask(withTitle: "P0 Task", timeout: 5), "Undo should put the task back on Home")
        takeScreenshot(named: "undo_reopens_task")
    }

    func testTaskOpenDoneOpenUpdatesInlineRowStateWithoutRelaunch() throws {
        let taskTitle = "P0 Task"
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: taskTitle), "Task should exist in Today view")

        let initialRow = homePage.taskRow(containingTitle: taskTitle)
        XCTAssertTrue(initialRow.waitForExistence(timeout: 5), "Task row should be visible")
        let completeCheckbox = homePage.taskCheckbox(containingTitle: taskTitle)
        XCTAssertTrue(completeCheckbox.waitForExistence(timeout: 5), "Task completion control should exist")
        XCTAssertEqual(completeCheckbox.value as? String, "Not complete", "An open task's control should read Not complete")
        completeCheckbox.tap()

        assertCompleted(taskTitle)

        homePage.undoCompletionButton.tap()

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should return after Undo without a relaunch")
        XCTAssertTrue(
            homePage.taskCheckbox(containingTitle: taskTitle).waitForExistence(timeout: 5),
            "The reopened task should offer completion again"
        )

        takeScreenshot(named: "task_open_done_open_state_transition")
    }

    // MARK: - Performance

    func testTaskCompletionPerformance() throws {
        // Find the control first: the measured block is the completion itself,
        // not XCUITest locating and scrolling to the row.
        let checkbox = homePage.taskCheckbox(containingTitle: "P0 Task")
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5), "Task completion control should exist")
        PerformanceMetrics.measureAndAssert(
            named: "Task Completion",
            threshold: PerformanceMetrics.Thresholds.taskCompletionTime,
            testCase: self
        ) {
            checkbox.tap()
        }
        assertCompleted("P0 Task")
    }
}
