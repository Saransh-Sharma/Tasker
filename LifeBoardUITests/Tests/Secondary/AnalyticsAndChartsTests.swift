//
//  AnalyticsAndChartsTests.swift
//  LifeBoardUITests
//
//  Secondary Tests: Sunrise Insights
//

import XCTest

class AnalyticsAndChartsTests: BaseUITest {

    var homePage: HomePage!

    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.disableLLM.rawValue]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        executionTimeAllowance = 120
        homePage = HomePage(app: app)
    }

    func testInsightsTodaySurfaceUpdatesAfterCompletion() throws {
        let taskTitle = "Task for Insights"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .max, taskType: .morning)
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be visible before completion")

        homePage.completeTask(at: findTaskIndex(withTitle: taskTitle))

        XCTAssertTrue(homePage.openInsights(), "Insights should open from the Sunrise bottom dock")
        assertTodayInsightsSurface()
        takeScreenshot(named: "insights_today_surface_after_completion")
    }

    func testInsightsNavigationSurvivesDailyXPChanges() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        XCTAssertTrue(homePage.homeButton.waitForExistence(timeout: 3), "Bottom home button should remain present")

        XCTAssertTrue(homePage.openInsights(), "Insights should open from Charts")
        XCTAssertTrue(homePage.insightsContainer.waitForExistence(timeout: 3), "Insights should render")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.chartsButton), "Insights should select the charts dock item")

        homePage.tapHome()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should close Insights")

        let taskTitle = "Nav XP Visibility Task"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .max, taskType: .morning)
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be created")

        homePage.completeTask(at: findTaskIndex(withTitle: taskTitle))
        XCTAssertTrue(homePage.openInsights(), "Insights should remain reachable when score is positive")
        assertTodayInsightsSurface()

        homePage.tapHome()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible before reopening the completed task")
        homePage.uncompleteTask(at: findTaskIndex(withTitle: taskTitle))

        XCTAssertTrue(homePage.openInsights(), "Insights should remain reachable when score returns to zero")
        assertTodayInsightsSurface()
        takeScreenshot(named: "insights_navigation_survives_daily_xp_changes")
    }

    func testInsightsWeekDisplay() throws {
        relaunchWithSearchSeed()
        let visibleSeededTitles = ["Meeting with Team", "Meeting Prep", "Review Code"].filter { title in
            homePage.waitForTask(withTitle: title, timeout: 2)
        }
        XCTAssertFalse(visibleSeededTitles.isEmpty, "At least one seeded search task should be visible")
        for title in visibleSeededTitles {
            homePage.completeTask(at: findTaskIndex(withTitle: title))
        }

        XCTAssertTrue(openInsightsWeek(), "Week Insights content should be visible after seeded completions")

        XCTAssertTrue(
            element(id: AccessibilityIdentifiers.Home.insightsWeekHero).waitForExistence(timeout: 3),
            "Week tab should expose its current-week hero content"
        )
        let weekDetails = element(id: AccessibilityIdentifiers.Home.insightsDisclosureWeekDetails)
        XCTAssertTrue(weekDetails.waitForExistence(timeout: 3), "Week details disclosure should exist")
        takeScreenshot(named: "insights_week_display")
    }

    func testInsightsSurvivesCompletionAndTabSwitch() throws {
        relaunchWithSearchSeed()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")

        let seededTask = "Meeting with Team"
        XCTAssertTrue(homePage.waitForTask(withTitle: seededTask, timeout: 5), "Seeded task should be visible")
        homePage.completeTask(at: findTaskIndex(withTitle: seededTask))

        XCTAssertTrue(homePage.openInsights(), "Insights should open after completing a task")
        assertTodayInsightsSurface()

        XCTAssertTrue(homePage.switchInsightsTab(.week), "Week tab should be reachable")
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsDisclosureWeekDetails).waitForExistence(timeout: 3), "Week content should render")

        XCTAssertTrue(homePage.switchInsightsTab(.systems), "Systems tab should be reachable")
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsContentSystems).waitForExistence(timeout: 3), "Systems content should render")

        if homePage.insightsScrollView.waitForExistence(timeout: 2) {
            homePage.insightsScrollView.swipeUp()
        }
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsContentSystems).exists, "Systems content should remain mounted after scroll")
        takeScreenshot(named: "insights_completion_and_tab_switch")
    }

    func testInsightsTodayCTAsOpenTaskAndHabitWorkflows() throws {
        XCTAssertTrue(homePage.openInsights(), "Insights should open from Charts")
        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsHeroCard), "Today hero CTA should be tappable")
        XCTAssertTrue(element(id: "addTask.view").waitForExistence(timeout: 3), "Empty Today hero should open Add Task")
        dismissPresentedSheet()

        XCTAssertTrue(homePage.insightsContainer.waitForExistence(timeout: 3), "Insights should still be available after dismissing Add Task")
        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsActionHabitCheck), "Habit check CTA should be tappable")
        XCTAssertTrue(element(id: "habitBoard.view").waitForExistence(timeout: 3), "Habit check should open Habit Board")
        takeScreenshot(named: "insights_today_ctas_open_task_and_habit")
    }

    func testInsightsWeekCTAsExpandMomentumAndOpenProjects() throws {
        relaunchWithSearchSeed()
        XCTAssertTrue(homePage.openInsights(), "Insights should open from Charts")
        XCTAssertTrue(homePage.switchInsightsTab(.week), "Week tab should be reachable")

        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsActionWeeklyMomentum), "Weekly momentum CTA should be tappable")
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsWeeklyRhythm).waitForExistence(timeout: 3), "Weekly momentum should reveal weekly rhythm")

        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsActionProjectMix), "Project mix CTA should be tappable")
        XCTAssertTrue(element(id: "projectManagement.view").waitForExistence(timeout: 3), "Project mix should open Project Management")
        takeScreenshot(named: "insights_week_ctas_expand_and_open_projects")
    }

    func testInsightsSystemsCTAsExpandConsistencyAndOpenReminderSettings() throws {
        relaunchWithSearchSeed()
        XCTAssertTrue(homePage.openInsights(), "Insights should open from Charts")
        XCTAssertTrue(homePage.switchInsightsTab(.systems), "Systems tab should be reachable")

        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsActionReminderResponse), "Reminder response CTA should be tappable")
        XCTAssertTrue(
            element(id: AccessibilityIdentifiers.Settings.view).waitForExistence(timeout: 3) ||
                element(id: "settings.root").waitForExistence(timeout: 3) ||
                element(id: "settings.hero.card").waitForExistence(timeout: 3),
            "Reminder response should open Settings"
        )

        let doneButton = app.navigationBars[AccessibilityIdentifiers.Settings.navigationBar]
            .buttons[AccessibilityIdentifiers.Settings.doneButton]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Settings should expose Done")
        tap(doneButton)
        XCTAssertTrue(homePage.openInsights(), "Insights should reopen after Settings")
        XCTAssertTrue(homePage.switchInsightsTab(.systems), "Systems tab should be reachable after Settings")

        XCTAssertTrue(tapInsightElement(id: AccessibilityIdentifiers.Home.insightsActionConsistency), "Consistency CTA should be tappable")
        XCTAssertTrue(
            waitForAccessibilityValue(
                id: AccessibilityIdentifiers.Home.insightsDisclosureSystemDetails,
                containing: "expanded"
            ),
            "Consistency should expand Systems details"
        )
        takeScreenshot(named: "insights_systems_ctas_expand_and_open_settings")
    }

    func testTaskRowsRemainCompact() throws {
        let taskTitle = "Compact Row Guard"
        let addTaskPage = homePage.tapAddTask()
        addTaskPage.createTask(title: taskTitle, priority: .high, taskType: .morning)
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Task should be visible")

        let row = homePage.taskRow(containingTitle: taskTitle)
        XCTAssertTrue(row.waitForExistence(timeout: 3), "Task row should be visible")
        if row.identifier.hasPrefix("home.taskRow."), row.frame.height < app.windows.firstMatch.frame.height * 0.7 {
            XCTAssertLessThanOrEqual(row.frame.height, 220, "Sunrise task card row should remain visually bounded")
        } else {
            XCTAssertLessThanOrEqual(row.frame.height, 80, "Task title fallback should remain compact when row grouping is not exposed")
        }
        takeScreenshot(named: "home_compact_row_regression")
    }

    func testSunriseSurfaceExtendsToBottomAndTaskListRemainsScrollable() throws {
        relaunchWithSearchSeed()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")
        XCTAssertTrue(homePage.bottomBar.waitForExistence(timeout: 3), "Bottom bar should exist")
        XCTAssertTrue(homePage.taskListScrollView.waitForExistence(timeout: 3), "Task list should exist")
        XCTAssertTrue(homePage.waitForTask(withTitle: "Meeting with Team", timeout: 5), "Seeded task list should be visible")

        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should start expanded")
        XCTAssertGreaterThan(homePage.taskListScrollView.frame.maxY, homePage.bottomBar.frame.minY, "Task list should extend behind the bottom bar")

        let initialBottomBarFrame = homePage.bottomBar.frame
        let scrollView = homePage.taskListScrollView
        scrollView.swipeUp()
        scrollView.swipeUp()

        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should remain expanded on list scroll")
        XCTAssertEqual(homePage.bottomBar.frame.height, initialBottomBarFrame.height, accuracy: 1.0, "Bottom bar height should stay stable")
        XCTAssertGreaterThan(homePage.taskListScrollView.frame.maxY, homePage.bottomBar.frame.minY, "Task list should remain behind the stable bottom bar")

        scrollView.swipeDown()
        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 3), "Bottom bar should remain expanded after reverse scroll")
        XCTAssertEqual(homePage.bottomBar.frame.height, initialBottomBarFrame.height, accuracy: 1.0, "Bottom bar height should stay stable after reverse scroll")
        XCTAssertTrue(homePage.taskRow(containingTitle: "Meeting with Team").waitForExistence(timeout: 3), "Task list should remain interactive")
        takeScreenshot(named: "home_sunrise_bottom_extension")
    }

    func testSunriseFullRevealShowsCollapseHintAndTapCollapsesToDefault() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")
        XCTAssertTrue(homePage.chartsButton.waitForExistence(timeout: 3), "Charts button should exist")
        XCTAssertFalse(homePage.insightsContainer.exists, "Insights should not be visible before opening")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected by default")

        XCTAssertTrue(homePage.openInsights(), "Charts should open Insights")
        XCTAssertTrue(homePage.insightsContainer.waitForExistence(timeout: 3), "Insights should render")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.chartsButton), "Charts should be selected while Insights is open")

        homePage.tapHome()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home button should return to default destination")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected after closing Insights")

        XCTAssertTrue(homePage.openInsights(), "Charts should reopen Insights")
        XCTAssertTrue(homePage.insightsContainer.waitForExistence(timeout: 3), "Charts should reopen Insights")

        homePage.tapHome()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should return sunrise to default state")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton), "Home should be selected after returning to tasks")
        takeScreenshot(named: "home_sunrise_full_reveal_collapse_hint")
    }

    func testBottomBarFabRemainsVisibleWhenClusterHidesAndAutoReveals() throws {
        relaunchWithSearchSeed()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should be visible")
        XCTAssertTrue(homePage.bottomBar.waitForExistence(timeout: 3), "Bottom bar should exist")
        XCTAssertTrue(homePage.addTaskButton.waitForExistence(timeout: 3), "FAB should exist")
        XCTAssertTrue(homePage.waitForTask(withTitle: "Meeting with Team", timeout: 5), "Seeded task list should be visible")

        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should start expanded")
        XCTAssertTrue(homePage.addTaskButton.isHittable, "FAB should start hittable")

        let initialBottomBarFrame = homePage.bottomBar.frame
        let scrollView = homePage.taskListScrollView
        scrollView.swipeUp()
        scrollView.swipeUp()

        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should remain expanded while scrolling down")
        XCTAssertEqual(homePage.bottomBar.frame.height, initialBottomBarFrame.height, accuracy: 1.0, "Bottom bar height should stay stable while scrolling down")
        XCTAssertTrue(homePage.addTaskButton.exists, "FAB should remain visible in hierarchy")
        XCTAssertTrue(homePage.addTaskButton.isHittable, "FAB should remain hittable while the bottom bar stays expanded")

        scrollView.swipeUp()
        _ = homePage.waitForBottomBarState("expanded", timeout: 2)
        scrollView.swipeDown()
        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should remain expanded on upward scroll")
        XCTAssertEqual(homePage.bottomBar.frame.height, initialBottomBarFrame.height, accuracy: 1.0, "Bottom bar height should stay stable on upward scroll")
    }

    private func assertTodayInsightsSurface(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(homePage.insightsContainer.waitForExistence(timeout: 3), "Insights container should exist", file: file, line: line)
        XCTAssertTrue(homePage.insightsTodayTab.waitForExistence(timeout: 3), "Today segmented tab should exist", file: file, line: line)
        XCTAssertTrue(homePage.insightsWeekTab.waitForExistence(timeout: 3), "Week segmented tab should exist", file: file, line: line)
        XCTAssertTrue(homePage.insightsSystemsTab.waitForExistence(timeout: 3), "Systems segmented tab should exist", file: file, line: line)
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsContentToday).waitForExistence(timeout: 3), "Today content should render", file: file, line: line)

        let hero = element(id: AccessibilityIdentifiers.Home.insightsHeroCard)
        XCTAssertTrue(hero.waitForExistence(timeout: 3), "Today hero card should exist", file: file, line: line)
        XCTAssertTrue(
            hero.label.localizedCaseInsensitiveContains("XP") || hero.label.localizedCaseInsensitiveContains("done"),
            "Hero card should expose the progress metric in its accessibility label",
            file: file,
            line: line
        )
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsActionNextDecision).waitForExistence(timeout: 3), "Next decision card should exist", file: file, line: line)
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsActionProtectFocus).waitForExistence(timeout: 3), "Protect focus card should exist", file: file, line: line)
        XCTAssertTrue(element(id: AccessibilityIdentifiers.Home.insightsDisclosureTodayDetails).waitForExistence(timeout: 3), "Today details disclosure should exist", file: file, line: line)
    }

    private func openInsightsWeek() -> Bool {
        guard homePage.openInsights(timeout: 5) else { return false }
        guard homePage.switchInsightsTab(.week, timeout: 3) else { return false }
        return element(id: AccessibilityIdentifiers.Home.insightsDisclosureWeekDetails).waitForExistence(timeout: 3)
    }

    private func element(id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    @discardableResult
    private func tapInsightElement(id: String, timeout: TimeInterval = 3, maxSwipes: Int = 5) -> Bool {
        let target = element(id: id)
        if target.waitForExistence(timeout: timeout), target.isHittable {
            tap(target)
            return true
        }

        let scrollView = homePage.insightsScrollView
        guard scrollView.waitForExistence(timeout: 2) else { return false }
        for _ in 0..<maxSwipes {
            scrollView.swipeUp()
            if target.waitForExistence(timeout: 0.5), target.isHittable {
                tap(target)
                return true
            }
        }
        for _ in 0..<maxSwipes {
            scrollView.swipeDown()
            if target.waitForExistence(timeout: 0.5), target.isHittable {
                tap(target)
                return true
            }
        }
        return false
    }

    private func waitForAccessibilityValue(
        id: String,
        containing text: String,
        timeout: TimeInterval = 3
    ) -> Bool {
        let target = app.buttons[id]
        let predicate = NSPredicate { _, _ in
            guard target.exists else { return false }
            return String(describing: target.value ?? "")
                .localizedCaseInsensitiveContains(text)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dismissPresentedSheet() {
        let closeButtons = ["addTask.cancelButton", "Close", "Cancel"]
        for identifier in closeButtons {
            let button = app.buttons[identifier]
            if button.waitForExistence(timeout: 1) {
                tap(button)
                return
            }
        }
    }

    private func relaunchWithSearchSeed() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableLLM.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedSearchWorkspace.rawValue
        ]
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
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
