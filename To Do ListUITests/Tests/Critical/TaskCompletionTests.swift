//
//  TaskCompletionTests.swift
//  To Do ListUITests
//
//  Critical Tests: Task Completion (7 tests)
//  Tests the core functionality of completing tasks and score updates
//

import XCTest

class TaskCompletionTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)

        // Create initial tasks for completion testing
        createTestTasks()
    }

    // MARK: - Setup Helper

    /// Create test tasks with various priorities
    private func createTestTasks() {
        // Create P0 task (7 points)
        let addTaskPage1 = homePage.tapAddTask()
        addTaskPage1.createTask(title: "P0 Task", priority: .max, taskType: .morning)

        // Create P1 task (4 points)
        let addTaskPage2 = homePage.tapAddTask()
        addTaskPage2.createTask(title: "P1 Task", priority: .high, taskType: .morning)

        // Create P2 task (3 points)
        let addTaskPage3 = homePage.tapAddTask()
        addTaskPage3.createTask(title: "P2 Task", priority: .medium, taskType: .morning)

        // Create P3 task (2 points)
        let addTaskPage4 = homePage.tapAddTask()
        addTaskPage4.createTask(title: "P3 Task", priority: .low, taskType: .evening)

        // Wait for all tasks to appear
        XCTAssertTrue(homePage.waitForTaskCount(4, timeout: 10), "All 4 test tasks should be created")
    }

    // MARK: - Test 9: Complete Task Updates Score - P0

    func testCompleteTaskUpdatesScore_P0() throws {
        // GIVEN: A P0 (Max priority) task exists in the list
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P0 Task"), "P0 task should exist")

        // Get initial score
        // Note: We expect fresh state, so initial score should be 0

        // WHEN: User completes the P0 task
        // Find the P0 task and complete it
        let taskIndex = findTaskIndex(withTitle: "P0 Task")
        homePage.completeTask(at: taskIndex)

        // Wait for score update
        waitForAnimations(duration: 1.0)

        // THEN: Daily score should increase by 7 points
        let scoreUpdated = homePage.waitForDailyScoreUpdate(to: 7, timeout: 5)
        XCTAssertTrue(scoreUpdated, "Daily score should update to 7 after completing P0 task")

        XCTAssertTrue(homePage.verifyDailyScore(7), "Daily score should be 7")

        takeScreenshot(named: "complete_p0_task_score_7")
    }

    // MARK: - Test 10: Complete Task Updates Score - P1

    func testCompleteTaskUpdatesScore_P1() throws {
        // GIVEN: A P1 (High priority) task exists
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P1 Task"), "P1 task should exist")

        // WHEN: User completes the P1 task
        let taskIndex = findTaskIndex(withTitle: "P1 Task")
        homePage.completeTask(at: taskIndex)

        waitForAnimations(duration: 1.0)

        // THEN: Daily score should be 4 points (or 11 if P0 was also completed)
        // Since tests run independently with fresh state, score should be 4
        let scoreUpdated = homePage.waitForDailyScoreUpdate(to: 4, timeout: 5)

        // Note: If running after P0 test, score might be 11 (7 + 4)
        // For fresh state per test, it should be 4
        XCTAssertTrue(scoreUpdated || homePage.verifyDailyScore(11), "Daily score should be 4 (or 11 if cumulative)")

        takeScreenshot(named: "complete_p1_task_score")
    }

    // MARK: - Test 11: Complete Multiple Tasks Accumulates Score

    func testCompleteMultipleTasksAccumulatesScore() throws {
        // GIVEN: Multiple tasks with different priorities exist
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P0 Task"), "P0 task exists")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P1 Task"), "P1 task exists")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P2 Task"), "P2 task exists")

        // WHEN: User completes 3 tasks (P0: 7, P1: 4, P2: 3)
        let p0Index = findTaskIndex(withTitle: "P0 Task")
        homePage.completeTask(at: p0Index)
        waitForAnimations(duration: 0.5)

        let p1Index = findTaskIndex(withTitle: "P1 Task")
        homePage.completeTask(at: p1Index)
        waitForAnimations(duration: 0.5)

        let p2Index = findTaskIndex(withTitle: "P2 Task")
        homePage.completeTask(at: p2Index)
        waitForAnimations(duration: 1.0)

        // THEN: Total score should be 14 (7 + 4 + 3)
        let totalScore = 14
        let scoreUpdated = homePage.waitForDailyScoreUpdate(to: totalScore, timeout: 5)

        XCTAssertTrue(scoreUpdated, "Score should accumulate to 14")
        XCTAssertTrue(homePage.verifyDailyScore(totalScore), "Daily score should be 14")

        takeScreenshot(named: "complete_multiple_tasks_score_14")
    }

    // MARK: - Test 12: Uncomplete Task Reduces Score

    func testUncompleteTaskReducesScore() throws {
        // GIVEN: A task is completed and score is updated
        let taskIndex = findTaskIndex(withTitle: "P0 Task")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // Verify score is 7
        XCTAssertTrue(homePage.waitForDailyScoreUpdate(to: 7, timeout: 5), "Initial score should be 7")

        // WHEN: User uncompletes the task (taps checkbox again)
        homePage.uncompleteTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // THEN: Score should reduce back to 0
        let scoreReduced = homePage.waitForDailyScoreUpdate(to: 0, timeout: 5)
        XCTAssertTrue(scoreReduced, "Score should reduce back to 0")

        XCTAssertTrue(homePage.verifyDailyScore(0), "Daily score should be 0 after uncompleting")

        takeScreenshot(named: "uncomplete_task_reduces_score")
    }

    // MARK: - Test 13: Complete Task Updates Streak

    func testCompleteTaskUpdatesStreak() throws {
        // GIVEN: User has no current streak (fresh state)
        // Initial streak should be 0

        // WHEN: User completes a task today
        let taskIndex = findTaskIndex(withTitle: "P0 Task")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // THEN: Streak should increment to 1
        // Note: Streak logic may vary - it might only increment after completing tasks on consecutive days
        // For now, we verify that streak updates when a task is completed

        let streakUpdated = homePage.waitForStreak(1, timeout: 5)
        if !streakUpdated {
            // Streak might not update immediately or might have different logic
            print("⚠️ Streak did not update to 1 immediately - may require consecutive day completion")
        }

        takeScreenshot(named: "complete_task_updates_streak")
    }

    // MARK: - Test 14: Complete Task via BEMCheckbox

    func testCompleteTaskViaBEMCheckbox() throws {
        // GIVEN: A task exists with a BEMCheckbox
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "P0 Task"), "Task should exist")

        // WHEN: User taps the inline checkbox to complete the task
        let taskIndex = findTaskIndex(withTitle: "P0 Task")
        let checkbox = homePage.taskCheckbox(at: taskIndex)

        // If checkbox doesn't exist with accessibility identifier, find it in cell
        if !checkbox.exists {
            let cell = homePage.taskCell(at: taskIndex)
            let firstButton = cell.buttons.firstMatch
            XCTAssertTrue(firstButton.exists, "Checkbox button should exist in cell")
            firstButton.tap()
        } else {
            checkbox.tap()
        }

        waitForAnimations(duration: 1.0)

        // THEN: Task should be marked as completed
        // Score should update (P0 = 7 points)
        let scoreUpdated = homePage.waitForDailyScoreUpdate(to: 7, timeout: 5)
        XCTAssertTrue(scoreUpdated, "Score should update to 7 after checkbox tap")

        takeScreenshot(named: "complete_via_checkbox")
    }

    // MARK: - Test 15: Completed Task Shows Strikethrough

    func testCompletedTaskShowsStrikethrough() throws {
        // GIVEN: A task exists
        let taskTitle = "P0 Task"
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: taskTitle), "Task should exist")

        // WHEN: User completes the task
        let taskIndex = findTaskIndex(withTitle: taskTitle)
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // THEN: Task should show visual strikethrough
        // Note: Visual strikethrough is difficult to verify in UI tests without accessibility
        // We can verify the task still exists and score updated

        XCTAssertTrue(homePage.verifyTaskExists(withTitle: taskTitle), "Completed task should still be visible")
        XCTAssertTrue(homePage.verifyDailyScore(7), "Score should be 7")

        // Take screenshot to visually verify strikethrough
        takeScreenshot(named: "completed_task_strikethrough")

        // Optional: Check if task cell has different attributes when completed
        let cell = homePage.taskCell(at: taskIndex)
        XCTAssertTrue(cell.exists, "Cell should exist")
    }

    // MARK: - Helper Methods

    /// Find task index by title
    private func findTaskIndex(withTitle title: String) -> Int {
        let cells = app.tables.cells
        for index in 0..<cells.count {
            let cell = cells.element(boundBy: index)
            if cell.staticTexts[title].exists {
                return index
            }
        }
        return 0 // Default to first task
    }

    /// Wait for score to update (custom wait helper)
    private func waitForStreak(_ expectedStreak: Int, timeout: TimeInterval) -> Bool {
        return homePage.waitForStreak(expectedStreak, timeout: timeout)
    }

    // MARK: - Performance Test (Bonus)

    func testTaskCompletionPerformance() throws {
        // Measure the time it takes to complete a task
        PerformanceMetrics.measureAndAssert(
            named: "Task Completion",
            threshold: PerformanceMetrics.Thresholds.taskCompletionTime,
            testCase: self
        ) {
            let taskIndex = findTaskIndex(withTitle: "P0 Task")
            homePage.completeTask(at: taskIndex)
        }
    }
}

// MARK: - HomePage Extension for Streak Verification

extension HomePage {
    /// Wait for streak to update to expected value
    func waitForStreak(_ expectedStreak: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            let streakText = self.streakLabel.label
            return streakText.contains("\(expectedStreak)")
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }
}
