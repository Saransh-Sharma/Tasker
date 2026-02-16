//
//  PerformanceTests.swift
//  To Do ListUITests
//
//  Performance Tests (10 tests)
//  Tests app performance metrics and benchmarks
//

import XCTest

class PerformanceTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 66: App Launch Performance

    func testAppLaunchPerformance() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
        }

        // Verify app launched successfully
        homePage = HomePage(app: app)
        XCTAssertTrue(homePage.verifyIsDisplayed(), "App should launch successfully")

        takeScreenshot(named: "performance_app_launch")
    }

    // MARK: - Test 67: Task List Scrolling Performance

    func testTaskListScrollingPerformance() throws {
        // GIVEN: Many tasks exist for scrolling
        print("📝 Creating 100 tasks for scroll performance test...")

        for i in 1...100 {
            let addTaskPage = homePage.tapAddTask()
            addTaskPage.enterTitle("Scroll Task \(i)")
            addTaskPage.selectPriority(i % 4 == 0 ? .max : (i % 3 == 0 ? .high : .medium))
            addTaskPage.tapSave()

            // Batch wait for performance
            if i % 20 == 0 {
                waitForAnimations(duration: 1.0)
                print("  Created \(i) tasks...")
            }
        }

        waitForAnimations(duration: 2.0)

        let taskCount = homePage.getTaskCount()
        print("📊 Total tasks for scroll test: \(taskCount)")

        // WHEN: User scrolls through the list
        let taskListScrollView = homePage.taskListScrollView
        XCTAssertTrue(taskListScrollView.exists, "Task list scroll view should exist")

        // Measure scrolling performance
        PerformanceMetrics.measureAndAssert(
            named: "Task List Scrolling (100 tasks)",
            threshold: 2.0, // 2 seconds to scroll through list
            testCase: self
        ) {
            // Scroll through entire list
            for _ in 0..<10 {
                taskListScrollView.swipeUp()
            }

            // Scroll back up
            for _ in 0..<10 {
                taskListScrollView.swipeDown()
            }
        }

        takeScreenshot(named: "performance_scroll_end")
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

        PerformanceMetrics.measureAndAssert(
            named: "Chart Rendering",
            threshold: PerformanceMetrics.Thresholds.chartRenderTime,
            testCase: self
        ) {
            // Force chart refresh by navigating away and back
            let settingsPage = homePage.tapSettings()
            _ = settingsPage.verifyIsDisplayed()
            homePage = settingsPage.tapDone()
            _ = homePage.verifyIsDisplayed()

            // Wait for chart to render
            waitForAnimations(duration: 1.0)
        }

        takeScreenshot(named: "performance_chart_render")
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
        PerformanceMetrics.measureAndAssert(
            named: "Search Performance",
            threshold: PerformanceMetrics.Thresholds.searchResponseTime,
            testCase: self
        ) {
            homePage.tapSearch()

            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 2) {
                searchField.tap()
                searchField.typeText("Search Task 25")
            }

            waitForAnimations(duration: 1.0)
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
