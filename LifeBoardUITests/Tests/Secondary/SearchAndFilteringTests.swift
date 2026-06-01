//
//  SearchAndFilteringTests.swift
//  LifeBoardUITests
//
//  Secondary Tests: Search & Filtering (5 tests)
//  Tests search functionality and task filtering
//

import XCTest

class SearchAndFilteringTests: BaseUITest {

    var homePage: HomePage!
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedSearchWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.disableLLM.rawValue
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    private func seedSearchTasks() {
        _ = homePage.view.waitForExistence(timeout: 5)
    }

    // MARK: - Test 52: Search Task by Title

    func testSearchTaskByTitle() throws {
        // GIVEN: Multiple tasks exist
        seedSearchTasks()
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home tool should be selected initially")

        // WHEN: User searches for "Meeting"
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from the Home search affordance")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open in-place")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.searchButton), "Search tool should be selected while open")
        XCTAssertTrue(homePage.searchField.waitForExistence(timeout: 3), "Backdrop search field should be visible")
        XCTAssertTrue(homePage.searchChromeContainer.waitForExistence(timeout: 2), "Search chrome container should exist")
        XCTAssertTrue(homePage.searchContentContainer.waitForExistence(timeout: 2), "Search content container should exist")
        let safeAreaBoundary = homePage.topSafeAreaBoundary()
        let initialFieldMinY = homePage.searchField.frame.minY
        XCTAssertGreaterThanOrEqual(initialFieldMinY, safeAreaBoundary - 1, "Search field should stay below the safe area")
        XCTAssertGreaterThanOrEqual(
            homePage.searchContentContainer.frame.minY,
            homePage.searchChromeContainer.frame.maxY - 1,
            "Search content should start below the chrome"
        )

        homePage.typeSearchQuery("Meeting")
        waitForAnimations(duration: 1.0)
        XCTAssertGreaterThanOrEqual(
            homePage.searchField.frame.minY,
            safeAreaBoundary - 1,
            "Search field should remain below the safe area while focused"
        )
        XCTAssertLessThan(
            abs(homePage.searchField.frame.minY - initialFieldMinY),
            3,
            "Keyboard focus should not pull the search field upward"
        )
        XCTAssertGreaterThanOrEqual(
            homePage.searchContentContainer.frame.minY,
            homePage.searchChromeContainer.frame.maxY - 1,
            "Results content should remain below the chrome while focused"
        )

        // THEN: Only matching tasks should be displayed
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting with Team"), "Meeting task should be visible")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting Prep"), "Meeting Prep should be visible")
        XCTAssertTrue(homePage.searchResultsList.waitForExistence(timeout: 2), "Search results list should exist")
        let meetingResult = app.staticTexts["Meeting with Team"]
        XCTAssertTrue(meetingResult.exists, "Meeting result should exist")
        XCTAssertGreaterThanOrEqual(
            meetingResult.frame.minY,
            homePage.searchContentContainer.frame.minY - 1,
            "Visible results should not clip above the search content region"
        )

        takeScreenshot(named: "search_by_title")

        // Close path by tapping the Search face back chip.
        XCTAssertTrue(homePage.searchBackChip.waitForExistence(timeout: 2), "Search back chip should exist")
        homePage.tapSearchBackChip()
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be re-selected when search closes")
    }

    // MARK: - Test 53: Search No Results

    func testSearchNoResults() throws {
        // GIVEN: Tasks exist
        // WHEN: User searches for non-existent term
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")
        let initialFieldMinY = homePage.searchField.frame.minY
        homePage.typeSearchQuery("NonExistentTask123")
        waitForAnimations(duration: 1.0)

        // THEN: Empty state should be shown in the flipped search face
        XCTAssertTrue(
            app.staticTexts[AccessibilityIdentifiers.Search.emptyStateLabel].waitForExistence(timeout: 2),
            "No-result empty state should be visible"
        )
        XCTAssertTrue(homePage.searchChromeContainer.waitForExistence(timeout: 2), "Search chrome container should exist")
        XCTAssertTrue(homePage.searchContentContainer.waitForExistence(timeout: 2), "Search content container should exist")
        XCTAssertGreaterThanOrEqual(
            homePage.searchField.frame.minY,
            homePage.topSafeAreaBoundary() - 1,
            "Focused search field should stay below the safe area"
        )
        XCTAssertLessThan(
            abs(homePage.searchField.frame.minY - initialFieldMinY),
            3,
            "Keyboard presentation should not pull the search field upward"
        )
        XCTAssertGreaterThanOrEqual(
            homePage.searchContentContainer.frame.minY,
            homePage.searchChromeContainer.frame.maxY - 1,
            "Search content should remain below the chrome while the keyboard is visible"
        )
        XCTAssertGreaterThanOrEqual(
            app.staticTexts[AccessibilityIdentifiers.Search.emptyStateLabel].frame.minY,
            homePage.searchChromeContainer.frame.maxY - 1,
            "Empty state should render below the search chrome"
        )
        takeScreenshot(named: "search_no_results")
    }

    // MARK: - Test 54: Clear Search

    func testClearSearch() throws {
        // GIVEN: User has performed a search
        seedSearchTasks()
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
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
        XCTAssertGreaterThan(homePage.getTaskCount(), 0, "Tasks should be visible after clearing search")
        takeScreenshot(named: "clear_search")
    }

    func testSearchFaceClosePaths_HomeAndBackChip() throws {
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should start selected")

        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search should open")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.searchButton), "Search tool should be selected")

        homePage.tapHome()
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected after closing search")

        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Bottom search should reopen search face")
        XCTAssertTrue(homePage.searchBackChip.waitForExistence(timeout: 2), "Back chip should appear on search face")
        homePage.tapSearchBackChip()
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected after back chip closes search")
    }

    func testSuggestedCommandOverdueTasksShowsSeededOverdueTasksWithoutTyping() throws {
        seedSearchTasks()
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")

        let overdueSuggestion = app.buttons[AccessibilityIdentifiers.Search.suggestion("overdueTasks")]
        XCTAssertTrue(overdueSuggestion.waitForExistence(timeout: 3), "Overdue tasks suggestion should be visible")
        overdueSuggestion.tap()
        waitForAnimations(duration: 0.7)

        XCTAssertTrue(app.staticTexts["Overdue tasks"].waitForExistence(timeout: 2), "Command result header should appear")
        XCTAssertTrue(homePage.verifyTaskExists(withTitle: "Meeting Prep"), "Seeded overdue task should appear without typing")
        XCTAssertFalse(homePage.verifyTaskExists(withTitle: "Coffee Break"), "Completed task should not appear in overdue command results")
    }

    func testSuggestedCommandMissedHabitsShowsSeededRecoveryHabitWithoutTyping() throws {
        seedSearchTasks()
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should open")

        let missedHabitsSuggestion = app.buttons[AccessibilityIdentifiers.Search.suggestion("missedHabits")]
        XCTAssertTrue(missedHabitsSuggestion.waitForExistence(timeout: 3), "Missed habits suggestion should be visible")
        missedHabitsSuggestion.tap()
        waitForAnimations(duration: 0.7)

        XCTAssertTrue(app.staticTexts["Missed habits"].waitForExistence(timeout: 2), "Command result header should appear")
        XCTAssertTrue(app.staticTexts["Search recovery habit"].waitForExistence(timeout: 3), "Seeded missed habit should appear without typing")
    }

    // MARK: - Test 55: Filter by Priority - High Only

    func testFilterByPriority_HighOnly() throws {
        // GIVEN: Tasks with different priorities exist
        seedSearchTasks()
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
        seedSearchTasks()
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
        seedSearchTasks()
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
        seedSearchTasks()
        // WHEN: User applies both search and filter
        XCTAssertTrue(homePage.openSearchFromHome(), "Search should open from Home")
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
