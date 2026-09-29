//
//  TaskDeletionTests.swift
//  LifeBoardUITests
//
//  Critical Tests: Task Deletion
//  Home rows have no swipe actions; a task is deleted from its detail route
//  (`TaskRouteView`): Task actions → Delete → "Delete task" confirmation.
//

import XCTest

class TaskDeletionTests: BaseUITest {

    /// New tasks are due today, so they appear in Home's Tasks card, which is
    /// where this suite completes, undoes and deletes them.
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testNewTasksDueToday.rawValue]
    }

    var homePage: HomePage!

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
    }

    // MARK: - Delete Task

    func testDeleteTask() throws {
        let taskTitle = "Task to Delete"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .low, taskType: .morning)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let initialCount = homePage.getTaskCount()

        homePage.deleteTask(containingTitle: taskTitle)

        XCTAssertTrue(homePage.waitForTaskToDisappear(withTitle: taskTitle, timeout: 5), "Deleted task should not exist")
        XCTAssertEqual(homePage.getTaskCount(), initialCount - 1, "Task count should decrease by 1")

        takeScreenshot(named: "delete_task")
    }

    // MARK: - Delete Task Confirmation

    func testDeleteTaskConfirmation() throws {
        let taskTitle = "Task with Delete Confirmation"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .medium, taskType: .evening)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        XCTAssertTrue(
            homePage.requestDeletion(containingTitle: taskTitle),
            "Delete should ask for confirmation before removing the task"
        )
        takeScreenshot(named: "delete_confirmation_shown")

        homePage.taskDeleteConfirmButton.tap()

        XCTAssertTrue(homePage.verifyIsDisplayed(timeout: 5), "Deleting should return to Home")
        XCTAssertTrue(homePage.waitForTaskToDisappear(withTitle: taskTitle, timeout: 5), "Task should be deleted after confirmation")

        takeScreenshot(named: "delete_confirmed")
    }

    // MARK: - Cancel Delete Task

    func testCancelDeleteTask() throws {
        let taskTitle = "Task with Cancelled Delete"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .high, taskType: .morning)

        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let initialCount = homePage.getTaskCount()

        XCTAssertTrue(homePage.requestDeletion(containingTitle: taskTitle), "Delete should ask for confirmation")
        takeScreenshot(named: "delete_before_cancel")

        homePage.cancelDeletion()
        XCTAssertTrue(
            homePage.taskRouteNavigationBar.waitForExistence(timeout: 3),
            "Cancelling should keep the task route open"
        )

        homePage.returnFromTaskRoute()
        XCTAssertTrue(homePage.verifyIsDisplayed(timeout: 5), "Home should be reachable after cancelling")
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should still exist after canceling delete")
        XCTAssertEqual(homePage.getTaskCount(), initialCount, "Task count should remain the same")

        takeScreenshot(named: "delete_cancelled")
    }

    // MARK: - Delete Multiple Tasks

    func testDeleteMultipleTasks() throws {
        let taskTitles = ["Task 1 to Delete", "Task 2 to Delete", "Task 3 to Delete"]

        for title in taskTitles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        let initialCount = homePage.getTaskCount()
        XCTAssertGreaterThanOrEqual(initialCount, 3, "At least 3 tasks should exist")

        for title in taskTitles {
            homePage.deleteTask(containingTitle: title)
            XCTAssertTrue(homePage.waitForTaskToDisappear(withTitle: title, timeout: 5), "Task '\(title)' should be deleted")
        }

        XCTAssertEqual(homePage.getTaskCount(), initialCount - 3, "Task count should decrease by 3")

        takeScreenshot(named: "delete_multiple_tasks")
    }
}
