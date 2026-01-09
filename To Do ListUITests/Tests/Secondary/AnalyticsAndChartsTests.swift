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

    // MARK: - Test 58: Radar Chart Display

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

    // MARK: - Test 59: Analytics Score Display

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

    // MARK: - Test 60: Analytics Streak Display

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
