//
//  TaskDeletionTests.swift
//  To Do ListUITests
//
//  Critical Tests: Task Deletion (3 tests)
//  Tests the functionality of deleting tasks
//

import XCTest

class TaskDeletionTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 22: Delete Task

    func testDeleteTask() throws {
        // GIVEN: A task exists
        let taskTitle = "Task to Delete"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .low, taskType: .morning)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let initialCount = homePage.getTaskCount()

        // WHEN: User deletes the task
        let taskIndex = findTaskIndex(withTitle: taskTitle)
        homePage.deleteTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // THEN: Task should be removed from the list
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: taskTitle), "Deleted task should not exist")

        // Verify task count decreased
        let newCount = homePage.getTaskCount()
        XCTAssertEqual(newCount, initialCount - 1, "Task count should decrease by 1")

        takeScreenshot(named: "delete_task")
    }

    // MARK: - Test 23: Delete Task Confirmation

    func testDeleteTaskConfirmation() throws {
        // GIVEN: A task exists
        let taskTitle = "Task with Delete Confirmation"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .medium, taskType: .evening)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        // WHEN: User swipes to delete
        let taskIndex = findTaskIndex(withTitle: taskTitle)
        let cell = homePage.taskCell(at: taskIndex)
        cell.swipeLeft()

        waitForAnimations(duration: 0.5)

        // THEN: Delete button should appear
        let deleteButton = cell.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear after swipe")

        takeScreenshot(named: "delete_confirmation_shown")

        // Confirm deletion
        deleteButton.tap()
        waitForAnimations(duration: 1.0)

        // Verify task is deleted
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: taskTitle), "Task should be deleted after confirmation")

        takeScreenshot(named: "delete_confirmed")
    }

    // MARK: - Test 24: Cancel Delete Task

    func testCancelDeleteTask() throws {
        // GIVEN: A task exists
        let taskTitle = "Task with Cancelled Delete"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .high, taskType: .morning)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let initialCount = homePage.getTaskCount()

        // WHEN: User swipes to delete but doesn't confirm
        let taskIndex = findTaskIndex(withTitle: taskTitle)
        let cell = homePage.taskCell(at: taskIndex)
        cell.swipeLeft()

        waitForAnimations(duration: 0.5)

        // Delete button appears
        let deleteButton = cell.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear")

        takeScreenshot(named: "delete_before_cancel")

        // Swipe back (cancel delete) - swipe right to close delete button
        cell.swipeRight()

        waitForAnimations(duration: 1.0)

        // THEN: Task should still exist
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: taskTitle), "Task should still exist after canceling delete")

        // Verify task count unchanged
        let currentCount = homePage.getTaskCount()
        XCTAssertEqual(currentCount, initialCount, "Task count should remain the same")

        takeScreenshot(named: "delete_cancelled")
    }

    // MARK: - Bonus: Delete Multiple Tasks

    func testDeleteMultipleTasks() throws {
        // GIVEN: Multiple tasks exist
        let taskTitles = ["Task 1 to Delete", "Task 2 to Delete", "Task 3 to Delete"]

        for title in taskTitles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        let initialCount = homePage.getTaskCount()
        XCTAssertGreaterThanOrEqual(initialCount, 3, "At least 3 tasks should exist")

        // WHEN: User deletes all 3 tasks
        for title in taskTitles {
            let taskIndex = findTaskIndex(withTitle: title)
            homePage.deleteTask(at: taskIndex)
            waitForAnimations(duration: 0.5)
        }

        waitForAnimations(duration: 1.0)

        // THEN: All tasks should be deleted
        for title in taskTitles {
            XCTAssertFalse(homePage.verifyTaskExists(withTitle: title), "Task '\(title)' should be deleted")
        }

        // Verify task count decreased by 3
        let finalCount = homePage.getTaskCount()
        XCTAssertEqual(finalCount, initialCount - 3, "Task count should decrease by 3")

        takeScreenshot(named: "delete_multiple_tasks")
    }

    // MARK: - Bonus: Delete Completed Task

    func testDeleteCompletedTask() throws {
        // GIVEN: A completed task exists
        let taskTitle = "Completed Task to Delete"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .max, taskType: .morning)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        // Complete the task
        let taskIndex = findTaskIndex(withTitle: taskTitle)
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // Verify score updated (P0 = 7 points)
        XCTAssertTrue(homePage.verifyDailyScore(7), "Score should be 7 after completion")

        // WHEN: User deletes the completed task
        let completedTaskIndex = findTaskIndex(withTitle: taskTitle)
        homePage.deleteTask(at: completedTaskIndex)
        waitForAnimations(duration: 1.0)

        // THEN: Task should be deleted
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: taskTitle), "Completed task should be deleted")

        // Score might remain or be recalculated depending on app logic
        // Document the behavior
        takeScreenshot(named: "delete_completed_task")
    }

    // MARK: - Helper Methods

    private func findTaskIndex(withTitle title: String) -> Int {
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
