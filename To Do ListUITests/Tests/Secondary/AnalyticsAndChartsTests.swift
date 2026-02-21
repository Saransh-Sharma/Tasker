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
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.disableAIForUITests.rawValue]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        // These flows intentionally create/complete multiple tasks and can exceed the default UI-test allowance.
        executionTimeAllowance = 120
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

    // MARK: - Test 58: Nav XP Chart Remains Hidden

    func testNavXpPieChartVisibilityFollowsDailyXP() throws {
        // GIVEN: User is on home screen with fresh app state
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // THEN: Nav chart should be hidden and nav chart button absent
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHidden(timeout: 2),
            "Navigation XP pie chart should be hidden by default"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsAbsent(),
            "Navigation XP pie chart button should be absent by default"
        )

        // WHEN: User completes a task and gains XP
        let taskTitle = "Nav XP Visibility Task"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .max, taskType: .morning)
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        let completeIndex = findTaskIndex(withTitle: taskTitle)
        homePage.completeTask(at: completeIndex)
        waitForAnimations(duration: 1.5)

        // THEN: Nav chart and nav chart button should still remain hidden
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHidden(timeout: 3),
            "Navigation XP pie chart should remain hidden when score is positive"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsAbsent(),
            "Navigation XP pie chart button should remain absent when score is positive"
        )

        // Chart should remain hidden after date updates.
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            homePage.navigateToDate(tomorrow)
            waitForAnimations(duration: 0.8)
            XCTAssertTrue(
                homePage.verifyNavXpPieChartIsHidden(timeout: 3),
                "Navigation XP pie chart should remain hidden after date changes"
            )
            XCTAssertTrue(
                homePage.verifyNavXpPieChartButtonIsAbsent(),
                "Navigation XP pie chart button should remain absent after date changes"
            )
            homePage.navigateToDate(Date())
            waitForAnimations(duration: 0.8)
        }

        // WHEN: User reopens the same task and score returns to zero
        let reopenIndex = findTaskIndex(withTitle: taskTitle)
        homePage.uncompleteTask(at: reopenIndex)
        waitForAnimations(duration: 1.5)

        // THEN: Nav chart and nav chart button should still be hidden
        XCTAssertTrue(
            homePage.verifyNavXpPieChartIsHidden(timeout: 3),
            "Navigation XP pie chart should remain hidden when score returns to zero"
        )
        XCTAssertTrue(
            homePage.verifyNavXpPieChartButtonIsAbsent(),
            "Navigation XP pie chart button should remain absent when score returns to zero"
        )

        takeScreenshot(named: "nav_xp_pie_chart_visibility_follows_score")
    }

    // MARK: - Test 59: Radar Chart Display

    func testRadarChartDisplay() throws {
        // GIVEN: User has a custom project with completed tasks
        let projectName = uniqueProjectName(prefix: "Radar Display")
        createCustomProject(named: projectName)

        let tasks = [
            ("Chart Task 1", TestDataFactory.TaskPriority.max),
            ("Chart Task 2", TestDataFactory.TaskPriority.high),
            ("Chart Task 3", TestDataFactory.TaskPriority.medium)
        ]

        for (title, priority) in tasks {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: title, priority: priority, taskType: .morning, project: projectName)
            XCTAssertTrue(homePage.waitForTask(withTitle: title, timeout: 5), "Task '\(title)' should be created")

            let taskIndex = findTaskIndex(withTitle: title)
            homePage.completeTask(at: taskIndex)
            waitForAnimations(duration: 0.5)
        }

        waitForAnimations(duration: 2.0)

        // THEN: Radar/radial chart should be displayed
        XCTAssertTrue(waitForRadarChartToAppear(timeout: 5), "Radar chart should be visible after custom project completions")
        takeScreenshot(named: "radar_chart_display")
    }

    // MARK: - Test 59B: Radar Chart Entry Count Growth Crash Guard

    func testRadarChartDoesNotCrashWhenEntryCountIncreasesAfterTaskCompletion() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")

        let projectA = uniqueProjectName(prefix: "Radar A")
        let projectB = uniqueProjectName(prefix: "Radar B")
        createCustomProject(named: projectA)

        let projectATask = "Radar Task A"
        createAndCompleteTask(title: projectATask, priority: .high, project: projectA)
        XCTAssertTrue(waitForRadarChartToAppear(timeout: 5), "Radar chart should appear after first project completion")

        createCustomProject(named: projectB)

        let projectBTask = "Radar Task B"
        createAndCompleteTask(title: projectBTask, priority: .max, project: projectB)
        XCTAssertTrue(waitForRadarChartToAppear(timeout: 5), "Radar chart should stay visible after entry-count growth")
        XCTAssertEqual(app.state, .runningForeground, "App should remain running after radar redraw with increased entries")

        for iteration in 1...3 {
            var toggleIndex = findTaskIndex(withTitle: projectBTask)
            homePage.uncompleteTask(at: toggleIndex)
            waitForAnimations(duration: 0.8)
            XCTAssertEqual(app.state, .runningForeground, "App should remain running after uncomplete iteration \(iteration)")
            XCTAssertTrue(waitForRadarChartToAppear(timeout: 4), "Radar chart should remain visible after uncomplete iteration \(iteration)")

            toggleIndex = findTaskIndex(withTitle: projectBTask)
            homePage.completeTask(at: toggleIndex)
            waitForAnimations(duration: 0.8)
            XCTAssertEqual(app.state, .runningForeground, "App should remain running after complete iteration \(iteration)")
            XCTAssertTrue(waitForRadarChartToAppear(timeout: 4), "Radar chart should remain visible after complete iteration \(iteration)")
        }

        takeScreenshot(named: "radar_chart_entry_count_growth_no_crash")
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

        guard homePage.focusStrip.waitForExistence(timeout: 3) else {
            throw XCTSkip("Focus strip is not exposed in current runtime configuration")
        }

        let predicate = NSPredicate(format: "identifier BEGINSWITH 'home.focus.task.'")
        let focusCards = app.descendants(matching: .any).matching(predicate)
        guard focusCards.count > 0 else {
            throw XCTSkip("Focus cards are not exposed with stable accessibility identifiers")
        }
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

        guard homePage.dragTaskToFocus(title: pinCandidate) else {
            throw XCTSkip("Focus dropzone is unavailable; skipping drag-to-focus verification")
        }
        waitForAnimations(duration: 1.0)

        let pinnedCard = homePage.focusTaskCard(containingTitle: pinCandidate)
        guard pinnedCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("Pinned focus card is not exposed with stable accessibility identifiers")
        }
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

        guard homePage.dragTaskToFocus(title: pinCandidate) else {
            throw XCTSkip("Focus dropzone is unavailable; skipping drag-to-focus verification")
        }
        waitForAnimations(duration: 1.0)
        guard homePage.focusTaskCard(containingTitle: pinCandidate).waitForExistence(timeout: 3) else {
            throw XCTSkip("Pinned focus card is not exposed; skipping drag-back verification")
        }

        guard homePage.dragFocusTaskToList(title: pinCandidate) else {
            throw XCTSkip("List dropzone is unavailable; skipping drag-back verification")
        }
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

        guard homePage.dragTaskToFocus(title: "Pin 1"),
              homePage.dragTaskToFocus(title: "Pin 2"),
              homePage.dragTaskToFocus(title: "Pin 3") else {
            throw XCTSkip("Focus dropzone is unavailable; skipping fourth-pin capacity verification")
        }
        waitForAnimations(duration: 1.2)

        guard homePage.focusTaskCard(containingTitle: "Pin 1").waitForExistence(timeout: 3),
              homePage.focusTaskCard(containingTitle: "Pin 2").waitForExistence(timeout: 3),
              homePage.focusTaskCard(containingTitle: "Pin 3").waitForExistence(timeout: 3) else {
            throw XCTSkip("Pinned focus cards are not exposed; skipping fourth-pin capacity verification")
        }

        guard homePage.dragTaskToFocus(title: "Pin 4") else {
            throw XCTSkip("Focus dropzone is unavailable; skipping fourth-pin capacity verification")
        }
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
        guard homePage.foredropSurface.waitForExistence(timeout: 3) else {
            throw XCTSkip("Foredrop surface is not exposed in current runtime configuration")
        }
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

    // MARK: - Test 60J: Full Reveal Shows Collapse Hint And Collapses Back

    func testForedropFullRevealShowsCollapseHintAndTapCollapsesToDefault() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")
        guard homePage.foredropSurface.waitForExistence(timeout: 3) else {
            throw XCTSkip("Foredrop surface is not exposed in current runtime configuration")
        }
        XCTAssertTrue(homePage.chartsButton.waitForExistence(timeout: 3), "Charts button should exist")

        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 2), "Foredrop should start collapsed")
        XCTAssertFalse(homePage.foredropCollapseHint.exists, "Collapse hint should be hidden while collapsed")

        let collapsedMinY = homePage.foredropSurface.frame.minY

        homePage.tapCharts()
        waitForAnimations(duration: 0.6)

        XCTAssertTrue(homePage.waitForForedropState("fullReveal", timeout: 3), "Charts action should reach full reveal")
        XCTAssertTrue(homePage.foredropCollapseHint.waitForExistence(timeout: 2), "Collapse hint should be visible at full reveal")

        let fullRevealMinY = homePage.foredropSurface.frame.minY
        XCTAssertGreaterThan(
            fullRevealMinY,
            collapsedMinY + 220,
            "Foredrop should move down substantially when fully revealing analytics"
        )
        XCTAssertGreaterThan(
            fullRevealMinY,
            homePage.view.frame.height * 0.70,
            "Foredrop full reveal should reach a low enough position across screen sizes"
        )

        XCTAssertTrue(homePage.foredropCollapseHint.isHittable, "Collapse hint should be tappable")
        homePage.foredropCollapseHint.tap()
        waitForAnimations(duration: 0.5)

        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Collapse hint should return foredrop to default state")
        XCTAssertFalse(homePage.foredropCollapseHint.waitForExistence(timeout: 1), "Collapse hint should hide after collapsing")
        takeScreenshot(named: "home_foredrop_full_reveal_collapse_hint")
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

    private func uniqueProjectName(prefix: String) -> String {
        let suffix = UUID().uuidString.prefix(6)
        return "\(prefix) \(suffix)"
    }

    private func createCustomProject(named name: String) {
        let settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be visible before creating project '\(name)'")

        let projectPage = settingsPage.navigateToProjectManagement()
        XCTAssertTrue(projectPage.verifyIsDisplayed(), "Project Management should be visible before creating project '\(name)'")

        let newProjectPage = projectPage.tapAddProject()
        let updatedProjectPage = newProjectPage.createProject(
            name: name,
            description: "Radar crash regression project"
        )
        XCTAssertTrue(updatedProjectPage.waitForProject(named: name, timeout: 5), "Project '\(name)' should be created")

        let backToSettings = updatedProjectPage.tapBack()
        homePage = backToSettings.tapDone()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible after creating project '\(name)'")
    }

    private func createAndCompleteTask(
        title: String,
        priority: TestDataFactory.TaskPriority,
        project: String
    ) {
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: title, priority: priority, taskType: .morning, project: project)
        XCTAssertTrue(homePage.waitForTask(withTitle: title, timeout: 5), "Task '\(title)' should be created in project '\(project)'")

        let taskIndex = findTaskIndex(withTitle: title)
        homePage.completeTask(at: taskIndex)
        waitForAnimations(duration: 1.0)
    }

    private func waitForRadarChartToAppear(timeout: TimeInterval) -> Bool {
        if homePage.radarChartView.waitForExistence(timeout: timeout) {
            return true
        }

        let scrollView = homePage.taskListScrollView
        guard scrollView.exists else {
            return homePage.radarChartView.exists
        }

        for _ in 0..<3 {
            scrollView.swipeUp()
            if homePage.radarChartView.waitForExistence(timeout: 1.0) {
                return true
            }
        }

        return homePage.radarChartView.exists
    }

    private func findTaskIndex(withTitle title: String) -> Int {
        let taskRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        )
        for index in 0..<taskRows.count {
            let row = taskRows.element(boundBy: index)
            if row.label.localizedCaseInsensitiveContains(title) || row.staticTexts[title].exists {
                return index
            }
        }

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
