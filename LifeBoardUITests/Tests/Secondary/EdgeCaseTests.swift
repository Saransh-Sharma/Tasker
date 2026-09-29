//
//  EdgeCaseTests.swift
//  LifeBoardUITests
//
//  Secondary Tests: Edge Cases (2 tests)
//  Tests edge cases and unusual scenarios
//

import XCTest

class EdgeCaseTests: BaseUITest {

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

    // Test 64 (overdue indicator) was removed: it set a past deadline in Add
    // Task, which the live sheet cannot do (it schedules; deadlines are set on
    // the task screen), and its overdue check only printed. Overdue tasks are
    // covered by the seeded Overdue Rescue suites.

    // MARK: - Test 65: Empty State Display

    func testEmptyStateDisplay() throws {
        // GIVEN: No tasks exist (fresh app state)
        // WHEN: User views task list
        let taskCount = homePage.getTaskCount()

        // THEN: Empty state should be displayed or task count is 0
        if taskCount == 0 {
            print("✅ No tasks exist - empty state")

            // Look for empty state message
            let emptyStateLabels = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no tasks' OR label CONTAINS[c] 'empty' OR label CONTAINS[c] 'add a task'"))

            if emptyStateLabels.count > 0 {
                print("✅ Empty state message found")
            } else {
                print("⚠️ No explicit empty state message - list is just empty")
            }

            XCTAssertTrue(homePage.verifyEmptyState(), "Empty state should be true")
        } else {
            print("⚠️ Tasks exist - deleting all to test empty state")

            // Delete all tasks to reach empty state
            while homePage.getTaskCount() > 0 {
                homePage.deleteTask(at: 0)
                waitForAnimations(duration: 0.5)
            }

            waitForAnimations(duration: 1.0)

            // Now verify empty state
            XCTAssertTrue(homePage.verifyEmptyState(), "Empty state should be displayed after deleting all tasks")
        }

        takeScreenshot(named: "empty_state_display")
    }

    // MARK: - Bonus: Maximum Tasks

    func testMaximumTasksDisplay() throws {
        // GIVEN: Many tasks exist
        // WHEN: User creates 50 tasks
        print("📝 Creating 50 tasks to test performance and display...")

        for i in 1...50 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Task \(i)")
            addTaskPage.tapSave()

            // Don't wait for each one to appear to speed up test
            if i % 10 == 0 {
                waitForAnimations(duration: 0.5)
            }
        }

        waitForAnimations(duration: 2.0)

        // THEN: All tasks should be displayed and scrollable
        let taskCount = homePage.getTaskCount()
        print("📊 Total tasks created: \(taskCount)")

        XCTAssertGreaterThanOrEqual(taskCount, 40, "Most tasks should be created (allowing for some failures)")

        // Test scrolling with many tasks
        let taskListScrollView = homePage.taskListScrollView
        if taskListScrollView.exists {
            taskListScrollView.swipeUp()
            waitForAnimations(duration: 0.3)
            taskListScrollView.swipeUp()
            waitForAnimations(duration: 0.3)

            print("✅ Scrolling works with many tasks")
        }

        takeScreenshot(named: "maximum_tasks_display")
    }

    // MARK: - Bonus: Task with Very Long Title

    func testTaskWithVeryLongTitle() throws {
        // GIVEN: User creates task with very long title
        let longTitle = String(repeating: "A", count: 150) // 150 characters

        let addTaskPage = homePage.tapAddTask()
        addTaskPage.enterTitle(longTitle)

        // Dismiss keyboard
        if app.keyboards.firstMatch.exists {
            addTaskPage.dismissKeyboard()
        }

        addTaskPage.tapSave()

        waitForAnimations(duration: 1.0)

        // WHEN: Task is displayed
        // THEN: Title should be truncated or wrapped properly
        let taskCell = homePage.taskCell(at: 0)
        XCTAssertTrue(taskCell.exists, "Task with long title should be created")

        // Visual verification of truncation
        takeScreenshot(named: "task_long_title")
    }

    // MARK: - Bonus: Rapid Task Creation

    func testRapidTaskCreation() throws {
        // GIVEN: User rapidly creates multiple tasks
        // WHEN: Creating 5 tasks in quick succession
        for i in 1...5 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Rapid Task \(i)")
            addTaskPage.tapSave()
            // Minimal wait between creations
        }

        waitForAnimations(duration: 2.0)

        // THEN: All tasks should be created without issues
        let taskCount = homePage.getTaskCount()
        XCTAssertGreaterThanOrEqual(taskCount, 5, "All rapid tasks should be created")

        takeScreenshot(named: "rapid_task_creation")
    }

    // MARK: - Bonus: Duplicate Task Titles

    func testDuplicateTaskTitles() throws {
        // GIVEN: User creates tasks with same title
        let duplicateTitle = "Duplicate Task"

        for _ in 1...3 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle(duplicateTitle)
            addTaskPage.tapSave()
            _ = homePage.waitForTask(withTitle: duplicateTitle, timeout: 3)
        }

        waitForAnimations(duration: 1.0)

        // WHEN: Multiple tasks with same title exist
        // THEN: All should be displayed (tasks distinguished by UUID internally)
        let taskCount = homePage.getTaskCount()
        XCTAssertGreaterThanOrEqual(taskCount, 3, "All duplicate title tasks should exist")

        takeScreenshot(named: "duplicate_task_titles")
    }
}
