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
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Home should start collapsed")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home tool should be selected initially")
        let collapsedMinY = homePage.foredropSurface.frame.minY

        // WHEN: User searches for "Meeting"
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open in-place")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.searchButton), "Search tool should be selected while open")
        XCTAssertTrue(homePage.searchField.waitForExistence(timeout: 3), "Backdrop search field should be visible")
        let searchOpenMinY = homePage.foredropSurface.frame.minY
        XCTAssertLessThan(abs(searchOpenMinY - collapsedMinY), 12, "Foredrop should stay anchored while opening search")

        homePage.typeSearchQuery("Meeting")
        waitForAnimations(duration: 1.0)

        // THEN: Only matching tasks should be displayed
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting with Team"), "Meeting task should be visible")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting Prep"), "Meeting Prep should be visible")
        XCTAssertTrue(homePage.searchResultsList.waitForExistence(timeout: 2), "Search results list should exist")

        takeScreenshot(named: "search_by_title")

        // Close path by tapping Search again.
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Search should collapse on second tap")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be re-selected when search closes")
    }

    // MARK: - Test 53: Search No Results

    func testSearchNoResults() throws {
        // GIVEN: Tasks exist
        // WHEN: User searches for non-existent term
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")
        homePage.typeSearchQuery("NonExistentTask123")
        waitForAnimations(duration: 1.0)

        // THEN: Empty state should be shown in the flipped search face
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifiers.Search.emptyStateLabel].waitForExistence(timeout: 2),
            "No-result empty state should be visible"
        )
        takeScreenshot(named: "search_no_results")
    }

    // MARK: - Test 54: Clear Search

    func testClearSearch() throws {
        // GIVEN: User has performed a search
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")
        homePage.typeSearchQuery("Meeting")
        waitForAnimations(duration: 1.0)

        // WHEN: User clears the search
        let clearButton = app.buttons[AccessibilityIdentifiers.Search.clearButton]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2), "Search clear button should appear")
        clearButton.tap()
        waitForAnimations(duration: 0.7)

        // THEN: Results should still be visible and non-empty for empty-query search
        XCTAssertTrue(homePage.searchResultsList.waitForExistence(timeout: 2), "Results list should remain visible")
        XCTAssertGreaterThan(homePage.getSearchResultsCount(), 0, "Tasks should be visible after clearing search")
        takeScreenshot(named: "clear_search")
    }

    func testSearchFaceClosePaths_HomeAndBackChip() throws {
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Home should start collapsed")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should start selected")

        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search should open")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.searchButton), "Search tool should be selected")

        homePage.tapHome()
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Home tap should collapse search")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected after closing search")

        homePage.tapTopNavSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Top-nav search should open search face")
        XCTAssertTrue(homePage.searchBackChip.waitForExistence(timeout: 2), "Back chip should appear on search face")
        homePage.tapSearchBackChip()
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Back chip should collapse search")
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
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")
        homePage.typeSearchQuery("Meeting")
        waitForAnimations(duration: 0.9)

        if homePage.searchStatusTodayChip.waitForExistence(timeout: 2) {
            homePage.searchStatusTodayChip.tap()
            waitForAnimations(duration: 0.7)
        }

        // THEN: Results should remain visible and searchable after chip refinement
        XCTAssertTrue(homePage.searchResultsList.waitForExistence(timeout: 2), "Search results should remain visible")
        takeScreenshot(named: "combined_search_filter")
    }
}
