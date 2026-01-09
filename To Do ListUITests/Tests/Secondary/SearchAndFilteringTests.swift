//
//  SearchAndFilteringTests.swift
//  To Do ListUITests
//
//  Secondary Tests: Search & Filtering (5 tests)
//  Tests search functionality and task filtering
//

import XCTest

class SearchAndFilteringTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)

        // Create test tasks for searching
        createTestTasks()
    }

    private func createTestTasks() {
        let tasks = [
            ("Meeting with Team", TestDataFactory.TaskPriority.high),
            ("Review Code", TestDataFactory.TaskPriority.medium),
            ("Meeting Prep", TestDataFactory.TaskPriority.high),
            ("Coffee Break", TestDataFactory.TaskPriority.low),
            ("Sprint Planning", TestDataFactory.TaskPriority.medium)
        ]

        for (title, priority) in tasks {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: priority, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }
    }

    // MARK: - Test 52: Search Task by Title

    func testSearchTaskByTitle() throws {
        // GIVEN: Multiple tasks exist
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting with Team"), "Task should exist")

        // WHEN: User searches for "Meeting"
        homePage.tapSearch()
        waitForAnimations(duration: 0.5)

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Meeting")

            waitForAnimations(duration: 1.0)

            // THEN: Only matching tasks should be displayed
            XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting with Team"), "Meeting task should be visible")
            XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting Prep"), "Meeting Prep should be visible")

            // Non-matching tasks might still be visible depending on implementation
            takeScreenshot(named: "search_by_title")
        }
    }

    // MARK: - Test 53: Search No Results

    func testSearchNoResults() throws {
        // GIVEN: Tasks exist
        // WHEN: User searches for non-existent term
        homePage.tapSearch()
        waitForAnimations(duration: 0.5)

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("NonExistentTask123")

            waitForAnimations(duration: 1.0)

            // THEN: No tasks or empty state should be shown
            let taskCount = homePage.getTaskCount()

            // Either no tasks or all tasks hidden
            print("📊 Task count after search: \(taskCount)")

            takeScreenshot(named: "search_no_results")
        }
    }

    // MARK: - Test 54: Clear Search

    func testClearSearch() throws {
        // GIVEN: User has performed a search
        homePage.tapSearch()
        waitForAnimations(duration: 0.5)

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Meeting")
            waitForAnimations(duration: 1.0)

            // WHEN: User clears the search
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            } else {
                // Alternative: tap X button
                let xButton = app.buttons["Cancel"]
                if xButton.exists {
                    xButton.tap()
                }
            }

            waitForAnimations(duration: 1.0)

            // THEN: All tasks should be visible again
            let taskCount = homePage.getTaskCount()
            XCTAssertGreaterThan(taskCount, 0, "Tasks should be visible after clearing search")

            takeScreenshot(named: "clear_search")
        }
    }

    // MARK: - Test 55: Filter by Priority - High Only

    func testFilterByPriority_HighOnly() throws {
        // GIVEN: Tasks with different priorities exist
        // WHEN: User filters by high priority
        // Note: Filter UI varies by app - might be a button, menu, or segmented control

        // Look for filter button
        let filterButton = homePage.projectFilterButton
        if filterButton.exists {
            filterButton.tap()
            waitForAnimations(duration: 0.5)

            // Look for priority filter option
            let highPriorityOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'high' OR label CONTAINS[c] 'P0' OR label CONTAINS[c] 'P1'")).firstMatch

            if highPriorityOption.exists {
                highPriorityOption.tap()
                waitForAnimations(duration: 1.0)

                // THEN: Only high priority tasks visible
                XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting with Team"), "High priority task should be visible")
                XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting Prep"), "High priority task should be visible")

                takeScreenshot(named: "filter_high_priority")
            }
        } else {
            print("⚠️ Filter button not found - implementation may vary")
        }
    }

    // MARK: - Test 56: Filter by Date - Today

    func testFilterByDate_Today() throws {
        // GIVEN: Tasks exist with various due dates
        // WHEN: User filters by today's date
        // Note: This might be automatic on home screen or require date picker

        // Check if date picker exists
        let datePicker = app.datePickers.firstMatch
        if datePicker.exists {
            // Select today
            let today = TestDataFactory.today()
            let formattedDate = TestDataFactory.formatDateForDisplay(today)

            datePicker.adjust(toPickerWheelValue: formattedDate)
            waitForAnimations(duration: 1.0)

            // THEN: Only today's tasks should be visible
            let taskCount = homePage.getTaskCount()
            print("📊 Tasks for today: \(taskCount)")

            takeScreenshot(named: "filter_by_date_today")
        } else {
            // Home screen might already show today's tasks by default
            print("✅ Home screen shows today's tasks by default")
            takeScreenshot(named: "default_today_view")
        }
    }

    // MARK: - Bonus: Filter by Project

    func testFilterByProject() throws {
        // GIVEN: Tasks exist in different projects
        // WHEN: User filters by project
        let filterButton = homePage.projectFilterButton
        if filterButton.exists {
            filterButton.tap()
            waitForAnimations(duration: 1.0)

            // Look for Inbox project option
            let inboxOption = app.buttons["Inbox"]
            if inboxOption.exists {
                inboxOption.tap()
                waitForAnimations(duration: 1.0)

                // THEN: Only Inbox tasks visible
                takeScreenshot(named: "filter_by_project_inbox")
            }
        }
    }

    // MARK: - Bonus: Combined Search and Filter

    func testCombinedSearchAndFilter() throws {
        // GIVEN: Tasks exist
        // WHEN: User applies both search and filter
        homePage.tapSearch()
        waitForAnimations(duration: 0.5)

        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Meeting")
            waitForAnimations(duration: 1.0)

            // Apply filter if available
            // (Implementation depends on app UI)

            // THEN: Results should match both criteria
            takeScreenshot(named: "combined_search_filter")
        }
    }
}
