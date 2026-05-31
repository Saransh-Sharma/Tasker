//
//  PerformanceTests.swift
//  LifeBoardUITests
//
//  Performance Tests (10 tests)
//  Tests app performance metrics and benchmarks
//

import XCTest

class PerformanceTests: BaseUITest {

    var homePage: HomePage!
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedFullTimelineWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active",
            XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(), "Performance test app should be ready before measurement starts")
    }

    // MARK: - Test 66: App Launch Performance

    func testAppLaunchPerformance() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
            XCTAssertTrue(ensurePerformanceAppReady(timeout: 14), "App launch performance should reach authenticated Home")
        }

        app.terminate()
        let launchDuration = PerformanceMetrics.measureExecutionTime(
            named: "App Launch Budget",
            testCase: self
        ) {
            app.launch()
            _ = ensurePerformanceAppReady(timeout: 14)
        }
        PerformanceMetrics.assertAppLaunchTime(launchDuration, testCase: self)

        // Verify app launched successfully
        homePage = HomePage(app: app)
        XCTAssertTrue(homePage.verifyIsDisplayed(), "App should launch successfully")

        takeScreenshot(named: "performance_app_launch")
    }

    // MARK: - Test 67: Task List Scrolling Performance

    func testTaskListScrollingPerformance() throws {
        relaunchSeededPerformanceWorkspace()
        let taskListScrollView = homePerformanceScrollSurface()
        XCTAssertTrue(taskListScrollView.waitForExistence(timeout: 8), "Seeded Home scroll surface should exist")

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: homeScrollMetrics(signpostName: "HomeTaskListScrollSession"), options: options) {
            performScrollCycle(on: taskListScrollView, swipeCount: 10)
        }

        takeScreenshot(named: "performance_scroll_end")
    }

    func testHomeAllContentScrollHitches() throws {
        try measureSeededHomeScrollHitches(scopeAccessibilityID: "home.sunrise.filter.all")
    }

    func testHomeTimelineOnlyScrollHitches() throws {
        try measureSeededHomeScrollHitches(scopeAccessibilityID: "home.sunrise.filter.tasks")
    }

    func testHomeHabitsOnlyScrollHitches() throws {
        try measureSeededHomeScrollHitches(scopeAccessibilityID: "home.sunrise.filter.habits")
    }

    func testScheduleScrollPerformance() throws {
        relaunchSeededPerformanceWorkspace()
        try openScheduleForPerformance()

        let scheduleSurface = scheduleScrollSurface()
        XCTAssertTrue(scheduleSurface.waitForExistence(timeout: 8), "Schedule surface should exist for scroll measurement")

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "ScheduleScrollSession")], options: options) {
            for _ in 0..<6 {
                scheduleSurface.swipeUp()
            }
            for _ in 0..<6 {
                scheduleSurface.swipeDown()
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
    }

    func testScheduleEventDetailOpenPerformance() throws {
        relaunchSeededPerformanceWorkspace()
        try openScheduleForPerformance()

        let eventRow = scheduleEventRow(identifier: "schedule.event.test_meeting_1")
        XCTAssertTrue(eventRow.waitForExistence(timeout: 8), "Seeded schedule event should exist for event-open measurement")

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "ScheduleEventDetailOpen")], options: options) {
            tapElement(eventRow)
            XCTAssertTrue(waitForScheduleEventDetailPresented(timeout: 4), "Schedule event detail should open during performance measurement")
            XCTAssertTrue(dismissScheduleEventDetailIfPresented(), "Schedule event detail should dismiss after performance measurement")
        }
    }

    // MARK: - Test 68: Task Creation Performance

    func testTaskCreationPerformance() throws {
        // GIVEN: User is on home screen
        // WHEN: User creates a task
        // THEN: Task creation should be fast

        let metrics: [XCTMetric] = [XCTClockMetric()]

        measure(metrics: metrics) {
            let addTaskPage = homePage.tapAddTask()
            _ = addTaskPage.verifyIsDisplayed()

            addTaskPage.enterTitle("Performance Task")
            addTaskPage.selectPriority(.medium)
            addTaskPage.tapSave()

            _ = homePage.waitForTask(withTitle: "Performance Task", timeout: 5)
        }

        takeScreenshot(named: "performance_task_creation")
    }

    func testAddTaskSheetPresentationPerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [PerformanceMetrics.signpostMetric(named: "AddTaskSheetOpen")], options: options) {
            let addTaskPage = homePage.tapAddTask()
            _ = addTaskPage.verifyIsDisplayed()
            addTaskPage.tapCancel()
        }
    }

    private func measureSeededHomeScrollHitches(scopeAccessibilityID: String) throws {
        guard #available(iOS 19.0, *) else {
            throw XCTSkip("XCTHitchMetric requires iOS 19.0 or later.")
        }

        relaunchSeededPerformanceWorkspace()

        let homeSurface = homePerformanceScrollSurface()
        XCTAssertTrue(homeSurface.waitForExistence(timeout: 8), "Seeded Home scroll surface should exist")

        let scopeButton = app.buttons[scopeAccessibilityID].firstMatch
        if scopeButton.waitForExistence(timeout: 3) {
            scopeButton.tap()
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTHitchMetric(application: app)], options: options) {
            performScrollCycle(on: homeSurface, swipeCount: 8)
        }
    }

    func testSeededMajorFeatureCriticalJourneyPerformance() throws {
        relaunchSeededPerformanceWorkspace()
        XCTAssertTrue(ensurePerformanceAppReady(), "Critical journey should start from ready Home")
        exerciseCriticalJourneyCreationFlow()

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: homeScrollMetrics(signpostName: "SeededMajorFeatureCriticalJourney"), options: options) {
            XCTAssertTrue(ensurePerformanceAppReady(), "Critical journey should start from ready Home")
            cycleBottomTabsForPerformance()
            tapSunriseFilter("all")
            tapSunriseFilter("tasks")
            performScrollCycle(on: homePerformanceScrollSurface(), swipeCount: 3)
            tapFirstHomeTimelineItemIfAvailable()
            dismissTaskOrEventDetailIfPresented()

            tapSunriseFilter("habits")
            performScrollCycle(on: homePerformanceScrollSurface(), swipeCount: 2)
            tapFirstHomeHabitIfAvailable()
            dismissTaskOrEventDetailIfPresented()

            do {
                try openScheduleForPerformance()
            } catch {
                XCTFail("Schedule should open during critical journey: \(error)")
            }
            performScrollCycle(on: scheduleScrollSurface(), swipeCount: 3)
            let eventRow = scheduleEventRow(identifier: "schedule.event.test_meeting_1")
            if eventRow.waitForExistence(timeout: 2) {
                tapElement(eventRow)
                _ = waitForScheduleEventDetailPresented(timeout: 3)
                _ = dismissScheduleEventDetailIfPresented()
            }

            XCTAssertTrue(openInsightsForPerformance(), "Insights should open during critical journey")
            _ = switchInsightsTabForPerformance(.today)
            _ = scrollInsightsTabForPerformance(.week, swipeCount: 2)
            _ = scrollInsightsTabForPerformance(.systems, swipeCount: 2)

            openChatForPerformance()
            returnHomeFromTransientSurface()
        }
    }

    // MARK: - Test 69: Task Completion Performance

    func testTaskCompletionPerformance() throws {
        // GIVEN: Tasks exist
        for i in 1...10 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: "Complete Perf \(i)", priority: .low, taskType: .morning)
            _ = homePage.waitForTask(withTitle: "Complete Perf \(i)", timeout: 5)
        }

        waitForAnimations(duration: 1.0)

        // WHEN: User completes tasks rapidly
        // THEN: Completion should be fast

        PerformanceMetrics.measureAndAssert(
            named: "Task Completion (10 tasks)",
            threshold: PerformanceMetrics.Thresholds.taskCompletionTime * 10, // 3 seconds for 10 tasks
            testCase: self
        ) {
            for i in 0..<10 {
                homePage.completeTask(at: i)
            }
        }

        takeScreenshot(named: "performance_task_completion")
    }

    func testHomeHabitLastCellTapPerformance() throws {
        relaunchForHomeHabitPerformance()

        let tapTarget = homeHabitPerformanceTapTarget()
        XCTAssertTrue(tapTarget.waitForExistence(timeout: 5), "A home habit tap target should exist in the seeded workspace")
        XCTAssertTrue(waitForElementToBeHittable(tapTarget, timeout: 3))

        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [PerformanceMetrics.signpostMetric(named: "HomeHabitLastCellTap")], options: options) {
            let previousValue = (tapTarget.value as? String) ?? ""
            tapTarget.tap()

            let predicate = NSPredicate(format: "value != %@", previousValue)
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: tapTarget)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        }
    }

    // MARK: - Test 70: Chart Rendering Performance

    func testChartRenderPerformance() throws {
        // GIVEN: Data exists for chart
        for i in 1...20 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(
                title: "Chart Task \(i)",
                priority: i % 4 == 0 ? .max : .high,
                taskType: .morning
            )
            _ = homePage.waitForTask(withTitle: "Chart Task \(i)", timeout: 5)

            let taskIndex = findTaskIndex(withTitle: "Chart Task \(i)")
            homePage.completeTask(at: taskIndex)

            if i % 5 == 0 {
                waitForAnimations(duration: 0.5)
            }
        }

        waitForAnimations(duration: 2.0)

        // WHEN: Chart renders with data
        // THEN: Rendering should be performant

        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "HomeInsightsFirstMount")], options: options) {
            homePage.tapCharts()
            XCTAssertTrue(homePage.waitForToolSelection(homePage.chartsButton), "Analytics should open during perf run")
        }

        takeScreenshot(named: "performance_chart_render")
    }

    private func relaunchForHomeHabitPerformance() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-SKIP_ONBOARDING",
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue
        ]
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(), "Habit performance workspace should be ready before measurement starts")
    }

    private func firstHomeHabitRow(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let rowQuery = app.otherElements.matching(NSPredicate(format: "identifier MATCHES %@", #"^home\.habitRow\.[A-Za-z0-9-]+$"#))
        let firstRow = rowQuery.firstMatch

        if firstRow.waitForExistence(timeout: 3) && firstRow.isHittable {
            return firstRow
        }

        for _ in 0..<8 {
            app.swipeUp()
            if firstRow.exists && firstRow.isHittable {
                break
            }
        }

        XCTAssertTrue(firstRow.waitForExistence(timeout: 2), "Expected to find a home habit row after scrolling", file: file, line: line)
        return firstRow
    }

    private func homeHabitPerformanceTapTarget(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let legacyRowQuery = app.otherElements.matching(NSPredicate(format: "identifier MATCHES %@", #"^home\.habitRow\.[A-Za-z0-9-]+$"#))
        let legacyRow = legacyRowQuery.firstMatch

        if legacyRow.waitForExistence(timeout: 3) {
            let rowID = legacyRow.identifier.replacingOccurrences(of: "home.habitRow.", with: "")
            let lastCell = app.buttons[AccessibilityIdentifiers.Home.habitRowLastCell(rowID)]
            if lastCell.waitForExistence(timeout: 3) {
                return lastCell
            }
        }

        let sunriseRowQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier MATCHES %@", #"^home\.habits\.row\.[A-Za-z0-9-]+$"#)
        )
        let sunriseRow = sunriseRowQuery.firstMatch

        if sunriseRow.waitForExistence(timeout: 3) && sunriseRow.isHittable {
            return sunriseRow
        }

        for _ in 0..<8 {
            app.swipeUp()
            if sunriseRow.exists && sunriseRow.isHittable {
                return sunriseRow
            }
        }

        XCTAssertTrue(sunriseRow.waitForExistence(timeout: 2), "Expected to find a Sunrise home habit row after scrolling", file: file, line: line)
        return sunriseRow
    }

    // MARK: - Test 71: Memory Usage with Many Tasks

    @available(iOS 14.0, *)
    func testMemoryUsage_100Tasks() throws {
        // GIVEN: 100 tasks exist
        print("📝 Creating 100 tasks for memory test...")

        for i in 1...100 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Memory Task \(i)")
            addTaskPage.tapSave()

            if i % 25 == 0 {
                waitForAnimations(duration: 1.0)
                print("  Created \(i) tasks...")
            }
        }

        waitForAnimations(duration: 2.0)

        // WHEN: User scrolls and interacts with many tasks
        let taskListScrollView = homePage.taskListScrollView

        // Measure memory
        measure(metrics: [XCTMemoryMetric()]) {
            // Scroll through all tasks
            for _ in 0..<15 {
                taskListScrollView.swipeUp()
            }

            // Complete some tasks
            for i in 0..<10 {
                homePage.completeTask(at: i)
            }

            // Scroll back
            for _ in 0..<15 {
                taskListScrollView.swipeDown()
            }
        }

        takeScreenshot(named: "performance_memory_usage")
    }

    // MARK: - Test 72: Search Performance

    func testSearchPerformance() throws {
        // GIVEN: Many tasks exist
        for i in 1...50 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Search Task \(i)")
            addTaskPage.tapSave()

            if i % 10 == 0 {
                waitForAnimations(duration: 0.5)
            }
        }

        waitForAnimations(duration: 1.0)

        // WHEN: User performs search
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "HomeSearchSurface")], options: options) {
            homePage.tapSearch()
            XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 2), "Search face should open during perf run")
            homePage.typeSearchQuery("Search Task 25")
            homePage.tapSearchBackChip()
        }

        takeScreenshot(named: "performance_search")
    }

    // MARK: - Test 73: Project Filter Performance

    func testProjectFilterPerformance() throws {
        // GIVEN: Multiple projects and tasks exist
        let settingsPage = homePage.tapSettings()
        let projectPage = settingsPage.navigateToProjectManagement()

        // Create 5 projects
        for i in 1...5 {
            let newProjectPage = projectPage.tapAddProject()
            newProjectPage.createProject(name: "Project \(i)")
            _ = projectPage.waitForProject(named: "Project \(i)", timeout: 5)
        }

        projectPage.tapBack()
        settingsPage.tapDone()

        // Create tasks for each project
        for i in 1...25 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Filter Task \(i)")
            addTaskPage.tapSave()
        }

        waitForAnimations(duration: 1.0)

        // WHEN: User applies project filter
        PerformanceMetrics.measureAndAssert(
            named: "Project Filter",
            threshold: 1.0, // 1 second
            testCase: self
        ) {
            homePage.tapProjectFilter()
            waitForAnimations(duration: 1.0)
        }

        takeScreenshot(named: "performance_project_filter")
    }

    // MARK: - Test 74: Animation Performance

    func testAnimationPerformance() throws {
        // GIVEN: Tasks exist with animations
        for i in 1...10 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.createTask(title: "Anim Task \(i)", priority: .medium, taskType: .morning)
            _ = homePage.waitForTask(withTitle: "Anim Task \(i)", timeout: 5)
        }

        // WHEN: User performs animated actions
        measure(metrics: [XCTClockMetric()]) {
            // Complete with animation
            for i in 0..<10 {
                homePage.completeTask(at: i)
                waitForAnimations(duration: 0.1)
            }
        }

        takeScreenshot(named: "performance_animations")
    }

    // MARK: - Test 75: Cold Start Performance

    func testColdStartPerformance() throws {
        // Test cold start (first launch)
        // This simulates user experience on first app open

        let launchOptions = XCTMeasureOptions()
        launchOptions.iterationCount = 5

        measure(metrics: [XCTApplicationLaunchMetric()], options: launchOptions) {
            app.terminate()

            // Simulate cold start delay
            Thread.sleep(forTimeInterval: 1.0)

            app.launch()
        }

        // Verify app is responsive after launch
        homePage = HomePage(app: app)
        XCTAssertTrue(homePage.verifyIsDisplayed(), "App should be responsive after cold start")

        takeScreenshot(named: "performance_cold_start")
    }

    // MARK: - Bonus: Stress Test

    func testStressTest_RapidInteractions() throws {
        // Stress test with rapid interactions
        // GIVEN: App is running
        // WHEN: User performs many rapid actions

        let iterations = 20

        PerformanceMetrics.measureAndAssert(
            named: "Stress Test - Rapid Interactions",
            threshold: 10.0, // 10 seconds
            testCase: self
        ) {
            for i in 0..<iterations {
                // Rapid open/close add task
                let addTaskPage = homePage.tapAddTask()
                addTaskPage.tapCancel()

                if i % 5 == 0 {
                    // Occasionally create a task
                    let page = homePage.tapAddTask()
                    page.enterTitle("Stress Task \(i)")
                    page.tapSave()
                }
            }
        }

        takeScreenshot(named: "performance_stress_test")
    }

    // MARK: - Insights Performance

    func testInsightsTabSwitchingPerformance() throws {
        homePage.tapCharts()
        XCTAssertTrue(
            homePage.insightsContainer.waitForExistence(timeout: 3),
            "Insights container should be visible after opening charts"
        )

        PerformanceMetrics.measureAndAssert(
            named: "Insights Tab Switching",
            threshold: 3.0,
            testCase: self
        ) {
            for _ in 0..<8 {
                _ = homePage.switchInsightsTab(.today)
                _ = homePage.switchInsightsTab(.week)
                _ = homePage.switchInsightsTab(.systems)
            }
        }
    }

    func testInsightsTabScrollPerformance() throws {
        homePage.tapCharts()
        XCTAssertTrue(
            homePage.insightsContainer.waitForExistence(timeout: 3),
            "Insights container should be visible after opening charts"
        )

        PerformanceMetrics.measureAndAssert(
            named: "Insights Tab Scroll",
            threshold: 6.0,
            testCase: self
        ) {
            _ = homePage.scrollInsightsTab(.today, swipeCount: 4)
            _ = homePage.scrollInsightsTab(.week, swipeCount: 4)
            _ = homePage.scrollInsightsTab(.systems, swipeCount: 4)
        }
    }

    func testChatOpenPerformance() throws {
        let composer = app.otherElements["chat.composer.container"]
        let emptyState = app.otherElements["chat.emptyState.container"]

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "ChatOpenToFirstTranscriptRender")], options: options) {
            homePage.tapChat()
            XCTAssertTrue(
                composer.waitForExistence(timeout: 4) || emptyState.waitForExistence(timeout: 4),
                "Chat should present a composer or empty state during perf run"
            )
            if app.navigationBars.buttons.element(boundBy: 0).exists {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }
        }
    }

    // MARK: - Helper

    private func exerciseCriticalJourneyCreationFlow() {
        tapSunriseFilter("tasks")
        let taskTitle = "Critical Journey Setup \(UUID().uuidString.prefix(6))"
        let addTaskPage = homePage.tapAddTask()
        createTaskForPerformance(addTaskPage: addTaskPage, title: taskTitle)
        tapSunriseFilter("tasks")
        XCTAssertTrue(homePage.waitForTask(withTitle: taskTitle, timeout: 5), "Created task should appear during critical journey setup")
        XCTAssertTrue(completeVisibleTaskForPerformance(containingTitle: taskTitle), "Created task should be marked done during critical journey setup")

        tapSunriseFilter("habits")
        let habitTitle = "Critical Habit Setup \(UUID().uuidString.prefix(6))"
        createHabitThroughAddSheet(title: habitTitle)
        markHabitDone(containingTitle: habitTitle)
        tapSunriseFilter("all")
    }

    private func relaunchSeededPerformanceWorkspace() {
        app.terminate()
        app = XCUIApplication()
        app.launchSeededTimelineWorkspace(
            calendarMode: "active",
            skipOnboarding: true,
            evaActivationCompleted: true
        )
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(), "Seeded performance workspace should reach Home before measurement")
        ensureHomeTimelineReady()
    }

    private func homeScrollMetrics(signpostName: String) -> [XCTMetric] {
        var metrics: [XCTMetric] = [PerformanceMetrics.signpostMetric(named: signpostName)]
        if #available(iOS 19.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }
        return metrics
    }

    private func homePerformanceScrollSurface() -> XCUIElement {
        let homeScrollView = app.scrollViews["home.view"].firstMatch
        if homeScrollView.exists {
            return homeScrollView
        }
        let homeSurface = app.otherElements["home.view"].firstMatch
        if homeSurface.exists {
            return homeSurface
        }
        return homePage.taskListScrollView
    }

    private func performScrollCycle(on element: XCUIElement, swipeCount: Int) {
        for _ in 0..<swipeCount {
            element.swipeUp()
        }
        for _ in 0..<swipeCount {
            element.swipeDown()
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
    }

    private func cycleBottomTabsForPerformance() {
        if app.buttons[AccessibilityIdentifiers.Home.bottomBarCalendar].waitForExistence(timeout: 3) {
            tapElement(app.buttons[AccessibilityIdentifiers.Home.bottomBarCalendar])
            _ = app.descendants(matching: .any)["schedule.list"].waitForExistence(timeout: 4)
        }
        if app.buttons[AccessibilityIdentifiers.Home.bottomBarHome].waitForExistence(timeout: 3) {
            tapElement(app.buttons[AccessibilityIdentifiers.Home.bottomBarHome])
            _ = ensurePerformanceAppReady(timeout: 5)
        }

        _ = openInsightsForPerformance()
        if app.buttons[AccessibilityIdentifiers.Home.bottomBarHome].waitForExistence(timeout: 3) {
            tapElement(app.buttons[AccessibilityIdentifiers.Home.bottomBarHome])
            _ = ensurePerformanceAppReady(timeout: 5)
        }

        openChatForPerformance()
        returnHomeFromTransientSurface()
    }

    private func tapSunriseFilter(_ id: String) {
        let button = app.buttons[AccessibilityIdentifiers.Home.sunriseFilter(id)].firstMatch
        if button.waitForExistence(timeout: 3) {
            tapElement(button)
        }
    }

    private func createTaskForPerformance(addTaskPage: AddTaskPage, title: String) {
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(timeout: 5), "Add Task should open during critical journey")
        addTaskPage.enterTitle(title)
        addTaskPage.tapSave()
    }

    private func tapFirstHomeTimelineItemIfAvailable() {
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "home.timeline.task.",
            "home.timeline.event."
        )
        let item = app.descendants(matching: .any).matching(predicate).firstMatch
        if item.waitForExistence(timeout: 3) {
            tapElement(item)
        }
    }

    private func tapFirstHomeHabitIfAvailable() {
        let habit = homeHabitPerformanceTapTarget()
        if habit.waitForExistence(timeout: 3) {
            tapElement(habit)
        }
    }

    private func createHabitThroughAddSheet(title: String) {
        let addPage = AddTaskPage(app: app)
        if openHabitComposerFromHome() == false {
            let taskAddPage = homePage.tapAddTask()
            XCTAssertTrue(taskAddPage.verifyIsDisplayed(timeout: 5), "Add sheet should open before creating a habit")
            taskAddPage.switchToHabitMode()
        }
        XCTAssertTrue(app.otherElements["addHabit.view"].waitForExistence(timeout: 5), "Habit composer should open from the Add sheet")
        enterHabitTitleForPerformance(title)
        let createButton = app.buttons["addHabit.createButton"].exists
            ? app.buttons["addHabit.createButton"]
            : app.descendants(matching: .any)["addHabit.createButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 4), "Habit composer should expose a create button")
        tapElement(createButton)
        _ = app.otherElements["addHabit.view"].waitForExistence(timeout: 0.2)
        let dismissalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.otherElements["addHabit.view"]
        )
        _ = XCTWaiter.wait(for: [dismissalExpectation], timeout: 5)
        _ = ensurePerformanceAppReady(timeout: 8)
        tapSunriseFilter("habits")
        XCTAssertTrue(
            app.staticTexts[title].waitForExistence(timeout: 8)
                || homeHabitRow(containingTitle: title).waitForExistence(timeout: 8),
            "Created habit should appear on Home habits"
        )
    }

    private func openHabitComposerFromHome() -> Bool {
        tapSunriseFilter("habits")
        let addHabitButton = app.buttons[AccessibilityIdentifiers.Home.habitsAddHabit].firstMatch
        for _ in 0..<10 {
            if addHabitButton.exists {
                tapElement(addHabitButton)
                if app.otherElements["addHabit.view"].waitForExistence(timeout: 3) {
                    return true
                }
            }
            homePerformanceScrollSurface().swipeUp()
        }
        return false
    }

    private func enterHabitTitleForPerformance(_ title: String) {
        let titleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 8), "Habit title field should exist")

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.45))
        if app.keyboards.firstMatch.exists {
            app.typeText(title)
            return
        }

        titleField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.typeText(title)
    }

    private func openInsightsForPerformance() -> Bool {
        let chartsButton = app.buttons[AccessibilityIdentifiers.Home.bottomBarCharts].exists
            ? app.buttons[AccessibilityIdentifiers.Home.bottomBarCharts]
            : app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBarCharts]
        guard chartsButton.waitForExistence(timeout: 5) else {
            return false
        }

        tapElement(chartsButton)
        return waitForAnyPerformanceElement(
            [
                homePage.insightsContainer,
                app.descendants(matching: .any)[AccessibilityIdentifiers.Home.insightsContainer],
                app.descendants(matching: .any)[AccessibilityIdentifiers.Home.insightsTabToday],
                app.descendants(matching: .any)[AccessibilityIdentifiers.Home.insightsContentToday],
                app.staticTexts["What needs attention"]
            ],
            timeout: 5
        )
    }

    private func switchInsightsTabForPerformance(_ tab: HomePage.InsightsTab, timeout: TimeInterval = 2) -> Bool {
        let identifier: String
        let label: String
        switch tab {
        case .today:
            identifier = AccessibilityIdentifiers.Home.insightsTabToday
            label = "Today"
        case .week:
            identifier = AccessibilityIdentifiers.Home.insightsTabWeek
            label = "Week"
        case .systems:
            identifier = AccessibilityIdentifiers.Home.insightsTabSystems
            label = "Systems"
        }

        let candidates = [
            app.buttons[identifier],
            app.descendants(matching: .any)[identifier],
            app.buttons[label],
            app.staticTexts[label],
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        ]

        guard let tabElement = candidates.first(where: { $0.waitForExistence(timeout: timeout) }) else {
            XCTFail("Insights \(label) tab should be available for performance interaction")
            return false
        }
        tapElement(tabElement)
        return true
    }

    private func scrollInsightsTabForPerformance(_ tab: HomePage.InsightsTab, swipeCount: Int) -> Bool {
        guard switchInsightsTabForPerformance(tab) else { return false }
        let scrollView = app.scrollViews[AccessibilityIdentifiers.Home.insightsScroll].firstMatch
        let surface = scrollView.exists
            ? scrollView
            : app.descendants(matching: .any)[AccessibilityIdentifiers.Home.insightsScroll]
        guard surface.waitForExistence(timeout: 2) else {
            XCTFail("Insights scroll surface should be available for performance interaction")
            return false
        }

        performScrollCycle(on: surface, swipeCount: swipeCount)
        return true
    }

    private func completeVisibleTaskForPerformance(containingTitle title: String) -> Bool {
        if tapExplicitTaskCheckbox(containingTitle: title), taskCompletionObserved(title: title, timeout: 3) {
            return true
        }

        if completeTaskViaDetailForPerformance(containingTitle: title) {
            return true
        }

        let titleElement = app.staticTexts[title].firstMatch
        guard titleElement.waitForExistence(timeout: 4) else {
            return false
        }

        let frame = titleElement.frame
        let rowY = frame.midY
        let candidateXs = [
            frame.minX - 42,
            frame.minX - 70,
            frame.minX - 98,
            frame.minX - 126,
            54,
            34
        ].map { max(18, min(app.frame.width - 18, $0)) }

        for x in candidateXs {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: x, dy: rowY))
                .tap()
            dismissTaskOrEventDetailIfPresented()
            if taskCompletionObserved(title: title, timeout: 1.2) {
                return true
            }
        }

        titleElement.press(forDuration: 0.8)
        let markComplete = app.buttons["Mark Complete"].firstMatch
        if markComplete.waitForExistence(timeout: 2) {
            tapElement(markComplete)
            return taskCompletionObserved(title: title, timeout: 3)
        }

        return false
    }

    private func completeTaskViaDetailForPerformance(containingTitle title: String) -> Bool {
        let titleElement = app.staticTexts[title].firstMatch
        guard titleElement.waitForExistence(timeout: 3) else {
            return false
        }

        tapElement(titleElement)
        let detailView = app.descendants(matching: .any)[AccessibilityIdentifiers.TaskDetail.view]
        guard detailView.waitForExistence(timeout: 5) else {
            return false
        }

        let completeButton = app.descendants(matching: .any)[AccessibilityIdentifiers.TaskDetail.completeButton].firstMatch
        guard completeButton.waitForExistence(timeout: 4) else {
            dismissTaskOrEventDetailIfPresented()
            return false
        }

        tapElement(completeButton)
        let didComplete = waitForTaskDetailCompletionStateForPerformance(timeout: 5)
        dismissTaskOrEventDetailIfPresented()
        _ = ensurePerformanceAppReady(timeout: 5)
        tapSunriseFilter("tasks")
        return didComplete
    }

    private func waitForTaskDetailCompletionStateForPerformance(timeout: TimeInterval) -> Bool {
        let button = app.descendants(matching: .any)[AccessibilityIdentifiers.TaskDetail.completeButton].firstMatch
        let predicate = NSPredicate { _, _ in
            let label = button.label.lowercased()
            let value = (button.value as? String)?.lowercased() ?? ""
            return label == "completed"
                || label.contains("reopen")
                || value.contains("selected")
                || value == "1"
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapExplicitTaskCheckbox(containingTitle title: String) -> Bool {
        let checkboxPredicate = NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
            "home.taskCheckbox.",
            title
        )
        let checkboxByLabel = app.descendants(matching: .any).matching(checkboxPredicate).firstMatch
        if checkboxByLabel.waitForExistence(timeout: 0.5) {
            tapElement(checkboxByLabel)
            return true
        }

        let titleElement = app.staticTexts[title].firstMatch
        if titleElement.waitForExistence(timeout: 0.5) {
            let titleMidY = titleElement.frame.midY
            let checkboxes = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "home.taskCheckbox.")
            )
            for index in 0..<checkboxes.count {
                let checkbox = checkboxes.element(boundBy: index)
                guard checkbox.exists else { continue }
                if abs(checkbox.frame.midY - titleMidY) <= 28 {
                    tapElement(checkbox)
                    return true
                }
            }
        }

        let row = homePage.taskRow(containingTitle: title)
        guard row.exists, row.identifier.hasPrefix("home.taskRow.") else {
            return false
        }

        let taskID = String(row.identifier.dropFirst("home.taskRow.".count))
        let checkbox = app.descendants(matching: .any)["home.taskCheckbox.\(taskID)"].firstMatch
        if checkbox.waitForExistence(timeout: 0.5) {
            tapElement(checkbox)
            return true
        }

        return false
    }

    private func taskCompletionObserved(title: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if homePage.taskRowStateValue(containingTitle: title)?.localizedCaseInsensitiveContains("done") == true {
                return true
            }

            let doneElement = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@ AND value CONTAINS[c] %@", title, "done")
            ).firstMatch
            if doneElement.exists {
                return true
            }

            if app.staticTexts[title].exists == false && homePage.taskRow(containingTitle: title).exists == false {
                return true
            }

            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        }

        return false
    }

    private func markHabitDone(containingTitle title: String) {
        tapSunriseFilter("habits")
        let row = homeHabitRow(containingTitle: title)
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Created habit row should exist before marking done")
        let previousValue = (row.value as? String) ?? ""
        tapElement(row)

        let predicate = NSPredicate { _, _ in
            let nextValue = (row.value as? String) ?? ""
            return nextValue.localizedCaseInsensitiveContains("done")
                || (previousValue.isEmpty == false && nextValue != previousValue)
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: row)], timeout: 5),
            .completed,
            "Created habit should mark done after tapping its Home row"
        )
    }

    private func homeHabitRow(containingTitle title: String) -> XCUIElement {
        let rowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "home.habits.row.")
        let rows = app.descendants(matching: .any).matching(rowPredicate)
        for _ in 0..<8 {
            for index in 0..<rows.count {
                let row = rows.element(boundBy: index)
                if row.label.localizedCaseInsensitiveContains(title)
                    || row.debugDescription.localizedCaseInsensitiveContains(title) {
                    return row
                }
            }
            homePerformanceScrollSurface().swipeUp()
        }

        let legacyPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "home.habitRow.")
        let legacyRows = app.descendants(matching: .any).matching(legacyPredicate)
        for index in 0..<legacyRows.count {
            let row = legacyRows.element(boundBy: index)
            if row.label.localizedCaseInsensitiveContains(title)
                || row.debugDescription.localizedCaseInsensitiveContains(title) {
                return row
            }
        }

        return app.descendants(matching: .any)["missing.home.habitRow.\(title)"]
    }

    private func dismissTaskOrEventDetailIfPresented() {
        let taskDetail = app.descendants(matching: .any)[AccessibilityIdentifiers.TaskDetail.view]
        if taskDetail.waitForExistence(timeout: 1) {
            let close = app.buttons[AccessibilityIdentifiers.TaskDetail.closeButton]
            if close.exists {
                tapElement(close)
                return
            }
            app.swipeDown()
            return
        }

        if waitForScheduleEventDetailPresented(timeout: 1) {
            _ = dismissScheduleEventDetailIfPresented()
        }
    }

    private func openChatForPerformance() {
        let composer = app.descendants(matching: .any)["chat.composer.container"]
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        homePage.tapChat()
        XCTAssertTrue(
            waitForAnyPerformanceElement([composer, emptyState], timeout: 4),
            "EVA should open to a composer or transcript surface during performance coverage"
        )
    }

    private func waitForAnyPerformanceElement(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        return elements.contains(where: { $0.exists })
    }

    private func returnHomeFromTransientSurface() {
        if app.buttons[AccessibilityIdentifiers.Home.bottomBarHome].waitForExistence(timeout: 1) {
            tapElement(app.buttons[AccessibilityIdentifiers.Home.bottomBarHome])
            _ = ensurePerformanceAppReady(timeout: 5)
            return
        }

        let navButton = app.navigationBars.buttons.element(boundBy: 0)
        if navButton.exists {
            navButton.tap()
        }
        _ = ensurePerformanceAppReady(timeout: 5)
    }

    private func openScheduleForPerformance() throws {
        let calendarButton = app.buttons["home.bottomBar.calendar"].exists
            ? app.buttons["home.bottomBar.calendar"]
            : app.descendants(matching: .any)["home.bottomBar.calendar"]
        XCTAssertTrue(calendarButton.waitForExistence(timeout: 8), "Bottom bar calendar button should exist")
        tapElement(calendarButton)

        let scheduleFilters = app.buttons["schedule.toolbar.filters"]
        let scheduleList = app.descendants(matching: .any)["schedule.list"]
        XCTAssertTrue(
            scheduleFilters.waitForExistence(timeout: 8) || scheduleList.waitForExistence(timeout: 8),
            "Schedule should open from the bottom bar"
        )
    }

    private func scheduleScrollSurface() -> XCUIElement {
        let scrollView = app.scrollViews["schedule.list"].firstMatch
        if scrollView.exists {
            return scrollView
        }

        let identified = app.descendants(matching: .any)["schedule.list"]
        if identified.exists {
            return identified
        }

        return app.scrollViews.firstMatch
    }

    private func scheduleEventRow(identifier: String) -> XCUIElement {
        let directButton = app.buttons[identifier]
        if directButton.exists {
            return directButton
        }

        let descendant = app.descendants(matching: .any)[identifier]
        if descendant.exists {
            return descendant
        }

        let surface = scheduleScrollSurface()
        for _ in 0..<6 {
            surface.swipeUp()
            if directButton.exists {
                return directButton
            }
            if descendant.exists {
                return descendant
            }
        }

        return descendant
    }

    private func dismissScheduleEventDetailIfPresented() -> Bool {
        let identifiedClose = app.buttons["schedule.detail.close"]
        let done = app.navigationBars.buttons["Done"].firstMatch
        let detailSheet = app.descendants(matching: .any)["schedule.detail.sheet"]
        let sheet = app.sheets.firstMatch

        let appeared = waitForScheduleEventDetailPresented(timeout: 2)
        guard appeared else { return false }
        if identifiedClose.exists {
            tapElement(identifiedClose)
        } else if done.exists {
            done.tap()
        } else if sheet.exists {
            sheet.swipeDown()
        } else {
            app.swipeDown()
        }
        return true
    }

    private func waitForScheduleEventDetailPresented(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let probes: [XCUIElement] = [
            app.buttons["schedule.detail.close"],
            app.descendants(matching: .any)["schedule.detail.sheet"],
            app.descendants(matching: .any)["schedule.detail.unavailable"],
            app.navigationBars.buttons["Done"].firstMatch,
            app.sheets.firstMatch
        ]

        while Date() < deadline {
            if probes.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return probes.contains(where: { $0.exists })
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable == false {
            for _ in 0..<4 {
                app.swipeUp()
                if element.isHittable {
                    break
                }
            }
        }

        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
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
