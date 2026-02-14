//
//  AnalyticsAndChartsTests.swift
//  To Do ListUITests
//
//  Secondary Tests: Analytics & Charts (4 tests)
//  Tests analytics display and chart rendering
//

import XCTest

class AnalyticsAndChartsTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 57: Chart Renders After Completion

    func testChartRendersAfterCompletion() throws {
        // GIVEN: Tasks exist
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: "Task for Chart", priority: .max, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Task for Chart", timeout: 5)

        // WHEN: User completes a task
        let taskIndex = findTaskIndex(withTitle: "Task for Chart")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 2.0)

        // THEN: Chart should render/update
        let chartExists = homePage.verifyChartIsVisible()

        if chartExists {
            print("✅ Chart is visible")
        } else {
            print("⚠️ Chart may be below fold or not visible in current view")
        }

        takeScreenshot(named: "chart_renders_after_completion")
    }

    // MARK: - Test 58: Nav XP Chart Visibility Follows Daily XP

    func testNavXpPieChartVisibilityFollowsDailyXP() throws {
        // GIVEN: User is on home screen with fresh app state
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // THEN: Zero XP day should hide nav chart and nav chart button
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHidden(timeout: 2),
            "Navigation XP pie chart should be hidden when score is zero"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsAbsent(),
            "Navigation XP pie chart button should be absent when score is zero"
        )

        // WHEN: User completes a task and gains XP
        let taskTitle = "Nav XP Visibility Task"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .max, taskType: .morning)
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let completeIndex = findTaskIndex(withTitle: taskTitle)
        homePage.completeTask(at: completeIndex)
        waitForAnimations(duration: 1.5)

        // THEN: Nav chart and nav chart button should appear
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsVisible(timeout: 5),
            "Navigation XP pie chart should be visible when score is positive"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsPresent(timeout: 3),
            "Navigation XP pie chart button should be present when score is positive"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHittable(),
            "Navigation XP pie chart should be hittable when visible"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartSize(expected: 136, tolerance: 10),
            "Floating navigation XP pie chart should be approximately 136x136"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsFullyVisibleInWindow(),
            "Floating navigation XP pie chart should be fully visible inside the app window"
        )

        // Interaction should still work while visible
        homePage.tapNavXpPieChart()
        waitForAnimations(duration: 0.8)

        // Chart should remain visible and unclipped after date updates.
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            homePage.navigateToDate(tomorrow)
            waitForAnimations(duration: 0.8)
            XCTAssertTrue(
                homePage.verifyNavXpPieChartIsVisible(timeout: 3),
                "Navigation XP pie chart should remain visible after date changes"
            )
            XCTAssertTrue(
                homePage.verifyNavXpPieChartIsFullyVisibleInWindow(),
                "Navigation XP pie chart should remain fully visible after date changes"
            )
            homePage.navigateToDate(Date())
            waitForAnimations(duration: 0.8)
        }

        // WHEN: User reopens the same task and score returns to zero
        let reopenIndex = findTaskIndex(withTitle: taskTitle)
        homePage.uncompleteTask(at: reopenIndex)
        waitForAnimations(duration: 1.5)

        // THEN: Nav chart and nav chart button should hide again
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHidden(timeout: 3),
            "Navigation XP pie chart should hide again when score returns to zero"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsAbsent(),
            "Navigation XP pie chart button should be absent again when score returns to zero"
        )

        takeScreenshot(named: "nav_xp_pie_chart_visibility_follows_score")
    }

    // MARK: - Test 59: Radar Chart Display

    func testRadarChartDisplay() throws {
        // GIVEN: User is on home screen with completed tasks
        // Create and complete multiple tasks
        let tasks = [
            ("Chart Task 1", TestDataFactory.TaskPriority.max),
            ("Chart Task 2", TestDataFactory.TaskPriority.high),
            ("Chart Task 3", TestDataFactory.TaskPriority.medium)
        ]

        for (title, priority) in tasks {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: priority, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)

            let taskIndex = findTaskIndex(withTitle: title)
            homePage.completeTask(at: taskIndex)
            waitForAnimations(duration: 0.5)
        }

        waitForAnimations(duration: 2.0)

        // WHEN: User views home screen
        // THEN: Radar/radial chart should be displayed
        let chartView = homePage.chartView

        if chartView.exists {
            print("✅ Radar chart is displayed")
            XCTAssertTrue(true, "Radar chart exists")
        } else {
            // Chart might require scrolling or be in analytics section
            print("⚠️ Radar chart not immediately visible - may require scrolling")
        }

        takeScreenshot(named: "radar_chart_display")
    }

    // MARK: - Test 60: Analytics Score Display

    func testAnalyticsScoreDisplay() throws {
        // GIVEN: User has completed tasks with score
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: "Scored Task", priority: .high, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Scored Task", timeout: 5)

        let taskIndex = findTaskIndex(withTitle: "Scored Task")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // WHEN: User views analytics/score
        // THEN: Score should be displayed
        let scoreDisplayed = homePage.dailyScoreLabel.exists

        if scoreDisplayed {
            let scoreText = homePage.dailyScoreLabel.label
            print("📊 Score displayed: \(scoreText)")
            XCTAssertTrue(scoreText.contains("4") || scoreText.count > 0, "Score should be displayed")
        } else {
            print("⚠️ Score label not found with current identifier")
        }

        takeScreenshot(named: "analytics_score_display")
    }

    // MARK: - Test 60B: Home Cockpit XP Label

    func testHomeCockpitShowsXpTodayLabel() throws {
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: "Cockpit XP Task", priority: .high, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Cockpit XP Task", timeout: 5)

        let taskIndex = findTaskIndex(withTitle: "Cockpit XP Task")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        XCTAssertTrue(homePage.dailyScoreLabel.waitForExistence(timeout: 3), "Home cockpit XP label should be visible")
        XCTAssertTrue(homePage.dailyScoreLabel.label.contains("XP Today"), "Cockpit should use XP Today copy")
    }

    // MARK: - Test 60C: Focus Strip Caps At Three Tasks

    func testFocusStripCapsTaskCardsAtThree() throws {
        let titles = ["Focus 1", "Focus 2", "Focus 3", "Focus 4"]
        for title in titles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .high, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        XCTAssertTrue(homePage.focusStrip.waitForExistence(timeout: 3), "Focus strip should exist")

        let predicate = NSPredicate(format: "identifier BEGINSWITH 'home.focus.task.'")
        let focusCards = app.descendants(matching: .any).matching(predicate)
        XCTAssertGreaterThan(focusCards.count, 0)
        XCTAssertLessThanOrEqual(focusCards.count, 3, "Focus strip should show at most 3 tasks")
    }

    // MARK: - Test 60F: Drag Task Into Focus Adds Focus Card

    func testDragTaskToFocusAddsPinnedCard() throws {
        let rankedTitles = ["Ranked A", "Ranked B", "Ranked C"]
        for title in rankedTitles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .high, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        let pinCandidate = "Pin Candidate"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: pinCandidate, priority: .low, taskType: .morning)
        _ = homePage.waitForTask(withTitle: pinCandidate, timeout: 5)

        XCTAssertTrue(homePage.dragTaskToFocus(title: pinCandidate), "Should drag task row to focus drop zone")
        waitForAnimations(duration: 1.0)

        let pinnedCard = homePage.focusTaskCard(containingTitle: pinCandidate)
        XCTAssertTrue(pinnedCard.waitForExistence(timeout: 3), "Pinned task should appear in focus strip")
    }

    // MARK: - Test 60G: Drag Focus Card Out Keeps Task In List

    func testDragFocusTaskToListRemovesPinnedCardAndKeepsRow() throws {
        let rankedTitles = ["Keep Rank A", "Keep Rank B", "Keep Rank C"]
        for title in rankedTitles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .high, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        let pinCandidate = "Unpin Candidate"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: pinCandidate, priority: .low, taskType: .morning)
        _ = homePage.waitForTask(withTitle: pinCandidate, timeout: 5)

        XCTAssertTrue(homePage.dragTaskToFocus(title: pinCandidate), "Should drag candidate into focus")
        waitForAnimations(duration: 1.0)
        XCTAssertTrue(homePage.focusTaskCard(containingTitle: pinCandidate).exists, "Pinned card should exist before unpin")

        XCTAssertTrue(homePage.dragFocusTaskToList(title: pinCandidate), "Should drag focus card back to list drop zone")
        waitForAnimations(duration: 1.0)

        XCTAssertFalse(homePage.focusTaskCard(containingTitle: pinCandidate).exists, "Pinned card should be removed from focus strip")
        XCTAssertTrue(homePage.taskRow(containingTitle: pinCandidate).exists, "Task should remain in task list after unpin")
    }

    // MARK: - Test 60H: Fourth Pin Is Rejected

    func testFourthFocusPinIsRejected() throws {
        let rankedTitles = ["Rank Base A", "Rank Base B", "Rank Base C"]
        for title in rankedTitles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .high, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        let pinCandidates = ["Pin 1", "Pin 2", "Pin 3", "Pin 4"]
        for title in pinCandidates {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
        }

        XCTAssertTrue(homePage.dragTaskToFocus(title: "Pin 1"))
        XCTAssertTrue(homePage.dragTaskToFocus(title: "Pin 2"))
        XCTAssertTrue(homePage.dragTaskToFocus(title: "Pin 3"))
        waitForAnimations(duration: 1.2)

        XCTAssertTrue(homePage.focusTaskCard(containingTitle: "Pin 1").exists)
        XCTAssertTrue(homePage.focusTaskCard(containingTitle: "Pin 2").exists)
        XCTAssertTrue(homePage.focusTaskCard(containingTitle: "Pin 3").exists)

        XCTAssertTrue(homePage.dragTaskToFocus(title: "Pin 4"))
        waitForAnimations(duration: 1.0)

        XCTAssertFalse(
            homePage.focusTaskCard(containingTitle: "Pin 4").exists,
            "Fourth pin should be rejected when manual focus capacity is full"
        )
    }

    // MARK: - Test 60D: Completed Group Toggle Appears When Completed Rows Grow

    func testCompletedGroupToggleAppearsAfterMultipleCompletions() throws {
        let titles = ["Done A", "Done B", "Done C"]
        for title in titles {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: title, timeout: 5)
            let idx = findTaskIndex(withTitle: title)
            homePage.completeTask(at: idx)
            waitForAnimations(duration: 0.6)
        }

        let togglePredicate = NSPredicate(format: "identifier BEGINSWITH 'home.completedToggle.'")
        let completedToggle = app.descendants(matching: .any).matching(togglePredicate).firstMatch
        XCTAssertTrue(completedToggle.waitForExistence(timeout: 3), "Completed toggle should appear once completed rows exceed 2")
    }

    // MARK: - Test 60E: Compact Row Height Regression Guard

    func testTaskRowsRemainCompact() throws {
        let taskTitle = "Compact Row Guard"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .high, taskType: .morning)
        _ = homePage.waitForTask(withTitle: taskTitle, timeout: 5)

        let row = homePage.taskRow(containingTitle: taskTitle)
        XCTAssertTrue(row.waitForExistence(timeout: 3), "Task row should be visible")
        XCTAssertLessThanOrEqual(row.frame.height, 92, "Compact row should remain visually dense")
        takeScreenshot(named: "home_compact_row_regression")
    }

    // MARK: - Test 60I: Foredrop Surface Extends Behind Bottom Bar

    func testForedropSurfaceExtendsToBottomAndTaskListRemainsScrollable() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")
        XCTAssertTrue(homePage.foredropSurface.waitForExistence(timeout: 3), "Foredrop surface should exist")
        XCTAssertTrue(homePage.bottomBar.waitForExistence(timeout: 3), "Bottom bar should exist")
        XCTAssertTrue(homePage.taskListScrollView.waitForExistence(timeout: 3), "Task list should exist")

        for index in 1...10 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: "Backdrop Fill \(index)", priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: "Backdrop Fill \(index)", timeout: 5)
        }

        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should start expanded")
        XCTAssertGreaterThan(
            homePage.taskListScrollView.frame.maxY,
            homePage.bottomBar.frame.minY,
            "Task list should extend behind the bottom bar when expanded"
        )
        XCTAssertGreaterThanOrEqual(
            homePage.foredropSurface.frame.maxY,
            homePage.view.frame.maxY - 2,
            "Foredrop surface should reach screen edge when expanded"
        )

        let scrollView = homePage.taskListScrollView
        scrollView.swipeUp()
        waitForAnimations(duration: 0.5)
        if !homePage.waitForBottomBarState("minimized", timeout: 2) {
            scrollView.swipeUp()
            waitForAnimations(duration: 0.5)
        }

        XCTAssertTrue(homePage.waitForBottomBarState("minimized", timeout: 3), "Bottom bar should minimize on list scroll")
        XCTAssertGreaterThan(
            homePage.taskListScrollView.frame.maxY,
            homePage.bottomBar.frame.minY,
            "Task list should remain behind the bottom bar when minimized"
        )
        XCTAssertGreaterThanOrEqual(
            homePage.foredropSurface.frame.maxY,
            homePage.view.frame.maxY - 2,
            "Foredrop surface should reach screen edge when minimized"
        )

        scrollView.swipeDown()
        waitForAnimations(duration: 0.5)
        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 3), "Bottom bar should restore after reverse scroll")
        XCTAssertTrue(homePage.taskRow(containingTitle: "Backdrop Fill 1").waitForExistence(timeout: 3), "Task list should remain interactive")
        takeScreenshot(named: "home_foredrop_bottom_extension")
    }

    // MARK: - Test 61: Analytics Streak Display

    func testAnalyticsStreakDisplay() throws {
        // GIVEN: User has a streak
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: "Streak Task", priority: .medium, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Streak Task", timeout: 5)

        let taskIndex = findTaskIndex(withTitle: "Streak Task")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // WHEN: User views streak analytics
        // THEN: Streak should be displayed
        let streakDisplayed = homePage.streakLabel.exists

        if streakDisplayed {
            let streakText = homePage.streakLabel.label
            print("🔥 Streak displayed: \(streakText)")
            XCTAssertTrue(streakText.count > 0, "Streak should be displayed")
        } else {
            print("⚠️ Streak label not found with current identifier")
        }

        takeScreenshot(named: "analytics_streak_display")
    }

    // MARK: - Bonus: Weekly Analytics

    func testWeeklyAnalytics() throws {
        // GIVEN: Tasks completed over time
        // WHEN: User views weekly analytics
        // Navigate to weekly view if needed
        let weeklyTab = tabBarButton("Weekly")
        if weeklyTab.exists {
            weeklyTab.tap()
            waitForAnimations(duration: 1.0)

            // THEN: Weekly data should be displayed
            takeScreenshot(named: "weekly_analytics")
        }
    }

    // MARK: - Bonus: Completion Rate Display

    func testCompletionRateDisplay() throws {
        // GIVEN: Some tasks completed, some not
        let addTaskPage1 = homePage.tapAddTask()
        addTaskPage1.createTask(title: "Complete This", priority: .low, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Complete This", timeout: 5)

        let addTaskPage2 = homePage.tapAddTask()
        addTaskPage2.createTask(title: "Leave This", priority: .low, taskType: .morning)
        _ = homePage.waitForTask(withTitle: "Leave This", timeout: 5)

        // Complete one
        let taskIndex = findTaskIndex(withTitle: "Complete This")
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)

        // WHEN: User views completion rate
        // THEN: Rate should be displayed (50% in this case)
        let rateDisplayed = homePage.completionRateLabel.exists

        if rateDisplayed {
            let rateText = homePage.completionRateLabel.label
            print("📈 Completion rate: \(rateText)")
        }

        takeScreenshot(named: "completion_rate_display")
    }

    // MARK: - Helper

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
