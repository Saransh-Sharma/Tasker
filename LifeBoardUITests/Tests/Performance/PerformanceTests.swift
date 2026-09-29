//
//  PerformanceTests.swift
//  LifeBoardUITests
//
//  Performance Tests
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

    override func setUp() async throws {
        try await super.setUp()
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
        try measureSeededHomeScrollHitches()
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

    func testGoalComposerInteractionPerformance() throws {
        relaunchGoalComposerPerformanceWorkspace()

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: composerInteractionMetrics(), options: options) {
            let addGoal = app.buttons["goals.add"]
            XCTAssertTrue(addGoal.waitForExistence(timeout: 2), "Goals should expose the add action")
            tapElement(addGoal)

            let composer = app.descendants(matching: .any)["track.goal.composer"]
            XCTAssertTrue(composer.waitForExistence(timeout: 2), "Goal composer should present promptly")

            let title = app.textFields["track.goal.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 2), "Goal title should be available")
            let focusStarted = Date()
            tapElement(title)
            XCTAssertTrue(
                app.keyboards.firstMatch.waitForExistence(timeout: 2),
                "Goal title should become interactive without entering a layout loop"
            )
            XCTAssertLessThanOrEqual(
                Date().timeIntervalSince(focusStarted),
                2,
                "Goal title focus and keyboard presentation should settle within two seconds"
            )

            title.typeText("Composer performance")
            XCTAssertEqual(title.value as? String, "Composer performance")

            let countType = app.buttons["track.goal.type.count"]
            XCTAssertTrue(countType.waitForExistence(timeout: 2))
            tapElement(countType)
            composer.swipeUp()
            let target = app.textFields["track.goal.target"]
            XCTAssertTrue(
                target.waitForExistence(timeout: 2),
                "Changing goal type should lazily reveal the target controls"
            )
            tapElement(target)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
            let keyboardDone = app.buttons["Done"].firstMatch
            XCTAssertTrue(keyboardDone.waitForExistence(timeout: 2))
            tapElement(keyboardDone)
            XCTAssertTrue(
                waitForElementToDisappear(app.keyboards.firstMatch, timeout: 2),
                "The numeric keyboard should dismiss from its native toolbar"
            )

            dismissComposer(identifier: "track.goal.composer")
        }
    }

    func testHydrationComposerInteractionPerformance() throws {
        relaunchHydrationComposerPerformanceWorkspace()

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: composerInteractionMetrics(), options: options) {
            let hydration = app.buttons["home.signal.hydration"]
            XCTAssertTrue(hydration.waitForExistence(timeout: 2), "Home should expose hydration logging")
            tapElement(hydration)

            let composer = app.descendants(matching: .any)["track.hydration.composer"]
            XCTAssertTrue(composer.waitForExistence(timeout: 2), "Hydration composer should present promptly")

            let bottle = app.buttons["Bottle, 500 mL"]
            XCTAssertTrue(bottle.waitForExistence(timeout: 2))
            tapElement(bottle)
            XCTAssertTrue(app.buttons["Add 500 mL"].waitForExistence(timeout: 2))
            composer.swipeUp()

            dismissComposer(identifier: "track.hydration.composer")
        }
    }

    func testGoalComposerComfortAndDynamicTypeMatrix() throws {
        let configurations: [(name: String, appearance: String?, contentSize: String)] = [
            ("High Contrast", "high-contrast-light", "UICTContentSizeCategoryL"),
            ("Reduce Transparency", "reduced-transparency", "UICTContentSizeCategoryL"),
            ("Reduce Motion", "reduced-motion", "UICTContentSizeCategoryL"),
            ("Accessibility XXXL", nil, "UICTContentSizeCategoryAccessibilityXXXL")
        ]

        for configuration in configurations {
            XCTContext.runActivity(named: configuration.name) { _ in
                relaunchGoalComposerPerformanceWorkspace(
                    appearance: configuration.appearance,
                    contentSize: configuration.contentSize
                )

                let addGoal = app.buttons["goals.add"]
                XCTAssertTrue(addGoal.waitForExistence(timeout: 2))
                tapElement(addGoal)

                let composer = app.descendants(matching: .any)["track.goal.composer"]
                XCTAssertTrue(composer.waitForExistence(timeout: 2))

                let title = app.textFields["track.goal.title"]
                XCTAssertTrue(title.waitForExistence(timeout: 2))
                tapElement(title)
                XCTAssertTrue(
                    app.keyboards.firstMatch.waitForExistence(timeout: 2),
                    "\(configuration.name) should preserve native field focus"
                )
                title.typeText("Accessible goal")
                XCTAssertEqual(title.value as? String, "Accessible goal")

                let countType = app.buttons["track.goal.type.count"]
                XCTAssertTrue(countType.waitForExistence(timeout: 2))
                tapElement(countType)
                composer.swipeUp()
                XCTAssertTrue(
                    app.descendants(matching: .any)["track.goal.target"].waitForExistence(timeout: 2),
                    "\(configuration.name) should keep offscreen target controls reachable"
                )

                dismissComposer(identifier: "track.goal.composer")
            }
        }
    }

    func testSharedTrackComposerPrimitiveCoverage() throws {
        relaunchTrackComposerPerformanceWorkspace()

        let mood = app.buttons["track.quick.mood"]
        XCTAssertTrue(mood.waitForExistence(timeout: 8))
        tapElement(mood)
        let moodComposer = app.descendants(matching: .any)["track.mood.composer"]
        XCTAssertTrue(moodComposer.waitForExistence(timeout: 2))
        let happy = app.buttons["track.mood.choice.happy"]
        XCTAssertTrue(happy.waitForExistence(timeout: 2))
        tapElement(happy)
        XCTAssertTrue(happy.isSelected, "Mood selection should retain its native selected trait")
        moodComposer.swipeUp()
        XCTAssertTrue(app.buttons["track.mood.commit"].exists)
        dismissComposer(identifier: "track.mood.composer")

        let areas = app.buttons["track.lens.areas"]
        XCTAssertTrue(areas.waitForExistence(timeout: 2))
        tapElement(areas)
        let resilience = app.buttons["track.habits.resilience"]
        tapElement(resilience)
        XCTAssertTrue(app.navigationBars["Habit settings"].waitForExistence(timeout: 8))
        let createGroup = app.buttons["Create group"]
        XCTAssertTrue(createGroup.waitForExistence(timeout: 8))
        tapElement(createGroup)

        let groupComposer = app.descendants(matching: .any)["track.habitGroup.composer"]
        XCTAssertTrue(groupComposer.waitForExistence(timeout: 2))
        let groupName = app.textFields["track.habitGroup.name"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 2))
        tapElement(groupName)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        groupName.typeText("Morning focus")
        XCTAssertEqual(groupName.value as? String, "Morning focus")
        dismissComposer(identifier: "track.habitGroup.composer")
    }

    private func measureSeededHomeScrollHitches() throws {
        guard #available(iOS 19.0, *) else {
            throw XCTSkip("XCTHitchMetric requires iOS 19.0 or later.")
        }

        relaunchSeededPerformanceWorkspace()

        let homeSurface = homePerformanceScrollSurface()
        XCTAssertTrue(homeSurface.waitForExistence(timeout: 8), "Seeded Home scroll surface should exist")

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTHitchMetric(application: app)], options: options) {
            performScrollCycle(on: homeSurface, swipeCount: 8)
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
            for _ in 0..<10 {
                homePage.completeTask(at: 0)
            }
        }

        takeScreenshot(named: "performance_task_completion")
    }

    private func relaunchGoalComposerPerformanceWorkspace(
        appearance: String? = nil,
        contentSize: String = "UICTContentSizeCategoryL"
    ) {
        app.terminate()
        app = composerPerformanceApplication(
            deepLink: "lifeboard://goals",
            appearance: appearance,
            contentSize: contentSize
        )
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
        XCTAssertTrue(
            app.buttons["goals.add"].waitForExistence(timeout: 12),
            "Goals should be ready before composer measurement starts"
        )
    }

    private func relaunchHydrationComposerPerformanceWorkspace() {
        app.terminate()
        app = composerPerformanceApplication()
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(), "Home should be ready before hydration measurement starts")
        XCTAssertTrue(
            app.buttons["home.signal.hydration"].waitForExistence(timeout: 8),
            "Hydration signal should be ready before composer measurement starts"
        )
    }

    private func relaunchTrackComposerPerformanceWorkspace() {
        app.terminate()
        app = composerPerformanceApplication()
        app.launchArguments.append(XCUIApplication.LaunchArgumentKey.testSeedHabitBoardWorkspace.rawValue)
        app.launch()
        waitForAppLaunch()
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady())

        let track = app.buttons["foundation.destination.track"]
        XCTAssertTrue(track.waitForExistence(timeout: 8))
        tapElement(track)
        XCTAssertTrue(app.descendants(matching: .any)["track.header"].waitForExistence(timeout: 8))
    }

    private func composerPerformanceApplication(
        deepLink: String? = nil,
        appearance: String? = nil,
        contentSize: String = "UICTContentSizeCategoryL"
    ) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.enableSignatureShaders.rawValue,
            "-LIFEBOARD_UI_TEST_ANIMATIONS_ENABLED",
            XCUIApplication.LaunchArgumentKey.testSeedFullTimelineWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue,
            "-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION",
            "-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2",
            "-LIFEBOARD_ENABLE_PREMIUM_IA_V5",
            "-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2"
        ]
        application.launchArguments.append(contentsOf: [
            "-UIPreferredContentSizeCategoryName",
            contentSize
        ])
        if let appearance {
            application.launchArguments.append("-LIFEBOARD_VISUAL_APPEARANCE=\(appearance)")
        }
        if let deepLink {
            application.launchArguments.append(
                "\(XCUIApplication.LaunchArgumentKey.testDeepLink.rawValue):\(deepLink)"
            )
        }
        application.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        return application
    }

    private func composerInteractionMetrics() -> [XCTMetric] {
        var metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(application: app),
            XCTMemoryMetric(application: app)
        ]
        if #available(iOS 19.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }
        return metrics
    }

    private func dismissComposer(identifier: String) {
        let composer = app.descendants(matching: .any)[identifier]
        if composer.exists {
            let cancel = app.navigationBars.buttons["Cancel"].firstMatch
            let close = app.navigationBars.buttons["Close"].firstMatch
            if cancel.exists {
                tapElement(cancel)
            } else if close.exists {
                tapElement(close)
            } else {
                let dragHandle = composer.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)
                )
                let screenBottom = app.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)
                )
                dragHandle.press(forDuration: 0.1, thenDragTo: screenBottom)
            }
        }
        XCTAssertTrue(
            waitForElementToDisappear(composer, timeout: 2),
            "Composer should dismiss promptly"
        )
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
            for _ in 0..<10 {
                homePage.completeTask(at: 0)
            }

            // Scroll back
            for _ in 0..<15 {
                taskListScrollView.swipeDown()
            }
        }

        takeScreenshot(named: "performance_memory_usage")
    }

    // MARK: - Test 74: LifeBoardAnimation Performance

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
            for _ in 0..<10 {
                homePage.completeTask(at: 0)
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
            let terminated = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in self.app.state == .notRunning },
                object: NSObject()
            )
            _ = XCTWaiter.wait(for: [terminated], timeout: 2)

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
        XCTAssertTrue(homePage.openInsights(), "Insights root should open from the root chrome")

        // 32 switches at no more than 0.5s each. An XCUITest tap alone is
        // ~0.35s (event round trip and idle wait); the old 3s total allowed
        // under 0.1s per switch, which no tap can meet.
        PerformanceMetrics.measureAndAssert(
            named: "Insights Lens Switching",
            threshold: 32 * 0.5,
            testCase: self
        ) {
            for _ in 0..<8 {
                for lens in ["overview", "trends", "review", "experience"] {
                    _ = switchInsightsLens(lens)
                }
            }
        }
    }

    func testInsightsTabScrollPerformance() throws {
        XCTAssertTrue(homePage.openInsights(), "Insights root should open from the root chrome")

        PerformanceMetrics.measureAndAssert(
            named: "Insights Lens Scroll",
            threshold: 6.0,
            testCase: self
        ) {
            for lens in ["overview", "trends", "review"] {
                guard switchInsightsLens(lens) else { continue }
                performScrollCycle(on: insightsScrollSurface(), swipeCount: 4)
            }
        }
    }

    func testChatOpenPerformance() throws {
        let composer = app.otherElements["chat.composer.container"]
        let emptyState = app.otherElements["chat.emptyState.container"]

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [PerformanceMetrics.signpostMetric(named: "ChatOpenToFirstTranscriptRender")], options: options) {
            tapElement(homePage.rootButton("eva"))
            XCTAssertTrue(
                composer.waitForExistence(timeout: 4) || emptyState.waitForExistence(timeout: 4),
                "Chat should present a composer or empty state during perf run"
            )
            tapElement(homePage.homeButton)
            _ = homePage.verifyIsDisplayed(timeout: 5)
        }
    }

    func testFoundationEstablishedEvaDashboardCyclePerformance() throws {
        try measureFoundationEvaDashboardCycles(evaActivationCompleted: true)
    }

    func testFoundationOnboardingEvaDashboardCyclePerformance() throws {
        try measureFoundationEvaDashboardCycles(evaActivationCompleted: false)
    }

    func testFoundationShellLaunchPerformance() throws {
        app.terminate()
        app = foundationPerformanceApplication(evaActivationCompleted: true)

        let options = XCTMeasureOptions()
        options.iterationCount = 10
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            app.terminate()
            app.launch()
        }

        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(timeout: 14))
        XCTAssertTrue(app.buttons["foundation.destination.home"].waitForExistence(timeout: 8))
    }

    func testFoundationMotionEnabledReadinessSmoke() throws {
        relaunchFoundationPerformanceWorkspace(evaActivationCompleted: true)
        for destination in ["home", "plan", "track", "insights", "home", "track"] {
            let button = app.otherElements["LifeBoardCompactChrome"].buttons["foundation.destination.\(destination)"].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            let ready = app.descendants(matching: .any)["foundation.performance.interactive.\(destination)"].firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 8), "Selected root must report its own laid-out control: \(destination)")
            XCTAssertFalse(app.tabBars.firstMatch.exists, "The custom dock must be the sole visible and accessible root switcher")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Motion-enabled \(destination)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testFoundationHydrationCaptureUpdatesHome() throws {
        relaunchFoundationPerformanceWorkspace(evaActivationCompleted: true)
        let hydration = app.buttons["home.signal.hydration"].firstMatch
        XCTAssertTrue(hydration.waitForExistence(timeout: 8))
        hydration.tap()
        let composer = app.descendants(matching: .any)["track.hydration.composer"].firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        let commit = app.descendants(matching: .any)["track.hydration.commit"].firstMatch
        XCTAssertTrue(commit.waitForExistence(timeout: 5))
        let save = commit.elementType == .button ? commit : commit.buttons.firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: composer)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed)
        let updated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] %@", "250 ml"), object: hydration)
        XCTAssertEqual(XCTWaiter().wait(for: [updated], timeout: 8), .completed,
                       "Home must display shared capture's committed local water total")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Home after shared hydration capture"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFoundationHomeAnimationOnScrollPerformance() throws {
        relaunchFoundationPerformanceWorkspace(evaActivationCompleted: true)
        let scroll = app.descendants(matching: .any)["foundation.home.scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))

        var metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTCPUMetric(application: app),
            XCTMemoryMetric(application: app)
        ]
        if #available(iOS 19.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: metrics, options: options) {
            performScrollCycle(on: scroll, swipeCount: 4)
        }
    }

    // MARK: - Helper

    private func measureFoundationEvaDashboardCycles(evaActivationCompleted: Bool) throws {
        relaunchFoundationPerformanceWorkspace(evaActivationCompleted: evaActivationCompleted)

        let options = XCTMeasureOptions()
        options.iterationCount = 1
        var metrics: [XCTMetric] = [
            PerformanceMetrics.signpostMetric(named: "EvaTabOpenToInteractive"),
            // RootSwitchAttempt includes cancellations; completed latency is exported
            // separately by RootSwitchCompletedMilliseconds events.
            XCTMemoryMetric(application: app)
        ]
        if #available(iOS 19.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }

        measure(metrics: metrics, options: options) {
            for _ in 0..<10 {
                openFoundationDestination("plan", readyIdentifier: "plan.header")
                openFoundationDestination("track", readyIdentifier: "track.header")
                openFoundationDestination("insights", readyIdentifier: "foundation.insights")

                let evaButton = app.buttons["foundation.destination.eva"]
                XCTAssertTrue(evaButton.waitForExistence(timeout: 2))
                tapElement(evaButton)
                let evaIsInteractive = waitForEvaInteractive(
                    activationCompleted: evaActivationCompleted,
                    timeout: 4
                )
                if evaIsInteractive == false {
                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "Eva readiness failure"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                XCTAssertTrue(evaIsInteractive, "Eva should become interactive without a user-visible hang")

                openFoundationDestination("home", readyIdentifier: "home.header")
                XCTAssertFalse(
                    app.descendants(matching: .any)["foundation.eva"].exists,
                    "Eva should leave the accessibility hierarchy after eviction"
                )
            }
        }
    }

    private func relaunchFoundationPerformanceWorkspace(evaActivationCompleted: Bool) {
        app.terminate()
        app = foundationPerformanceApplication(evaActivationCompleted: evaActivationCompleted)
        app.launch()
        homePage = HomePage(app: app)
        XCTAssertTrue(ensurePerformanceAppReady(timeout: 14))
        XCTAssertTrue(app.buttons["foundation.destination.home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["foundation.performance.ready"].firstMatch.waitForExistence(timeout: 15),
            "Motion, signature shaders, normal ambience and device policy must be active before measurement")
    }

    private func foundationPerformanceApplication(evaActivationCompleted: Bool) -> XCUIApplication {
        let application = XCUIApplication()
        application.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.enableSignatureShaders.rawValue,
            "-LIFEBOARD_UI_TEST_ANIMATIONS_ENABLED",
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedFullTimelineWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active",
            "-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION",
            "-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2",
            "-LIFEBOARD_ENABLE_PREMIUM_IA_V5",
            "-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2"
        ]
        if evaActivationCompleted {
            application.launchArguments.append(XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue)
        }
        application.launchEnvironment["PERFORMANCE_TEST"] = "1"
        return application
    }

    private func openFoundationDestination(_ destination: String, readyIdentifier: String) {
        let button = app.buttons["foundation.destination.\(destination)"]
        XCTAssertTrue(button.waitForExistence(timeout: 2), "\(destination) destination should exist")
        tapElement(button)
        XCTAssertTrue(
            app.descendants(matching: .any)[readyIdentifier].waitForExistence(timeout: 2),
            "\(destination) should expose \(readyIdentifier)"
        )
    }

    private func waitForEvaInteractive(activationCompleted: Bool, timeout: TimeInterval) -> Bool {
        let expectedElements: [XCUIElement]
        if activationCompleted {
            expectedElements = [
                app.descendants(matching: .any)["chat.composer.container"],
                app.descendants(matching: .any)["chat.emptyState.container"],
                app.descendants(matching: .any)["eva.store.loading"],
                app.descendants(matching: .any)["foundation.eva"]
            ]
        } else {
            expectedElements = [
                app.descendants(matching: .any)["eva.activation.intro"],
                app.descendants(matching: .any)["eva.store.loading"],
                app.descendants(matching: .any)["foundation.eva"]
            ]
        }
        let predicate = NSPredicate { _, _ in
            expectedElements.contains(where: \.exists)
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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
    }

    private func homeScrollMetrics(signpostName: String) -> [XCTMetric] {
        var metrics: [XCTMetric] = [PerformanceMetrics.signpostMetric(named: signpostName)]
        if #available(iOS 19.0, *) {
            metrics.append(XCTHitchMetric(application: app))
        }
        return metrics
    }

    private func homePerformanceScrollSurface() -> XCUIElement {
        homePage.taskListScrollView
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

    @discardableResult
    private func switchInsightsLens(_ lens: String, timeout: TimeInterval = 2) -> Bool {
        let button = app.buttons[AccessibilityIdentifiers.Insights.lens(lens)]
        // `exists` first: waitForExistence checks on a one-second poll.
        guard button.exists || button.waitForExistence(timeout: timeout) else {
            XCTFail("Insights \(lens) lens should be available for performance interaction")
            return false
        }
        tapElement(button)
        return true
    }

    /// The Overview lens carries `foundation.insights.scroll`; Trends and
    /// Review scroll in their own views, so fall back to whatever scrolls.
    private func insightsScrollSurface() -> XCUIElement {
        let tagged = app.descendants(matching: .any)[AccessibilityIdentifiers.Insights.scroll]
        if tagged.exists { return tagged }
        let anyScroll = app.scrollViews.firstMatch
        return anyScroll.exists ? anyScroll : app
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
}
