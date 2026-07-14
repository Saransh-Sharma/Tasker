import XCTest

@MainActor
final class AppStoreScreenshotUITests: BaseUITest {
    private struct ScreenshotLaunchConfiguration {
        let fixedNow: String

        var launchArguments: [String] {
            ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        }

        var launchEnvironment: [String: String] {
            [
                "LIFEBOARD_SCREENSHOT_FIXED_NOW": fixedNow,
                "TZ": "UTC"
            ]
        }
    }

    private var screenshotLaunchConfiguration: ScreenshotLaunchConfiguration {
        let configuration = screenshotOutputConfiguration(repositoryRoot: repositoryRoot)
        return ScreenshotLaunchConfiguration(
            fixedNow: configuration?.fixedNow ?? "2026-07-13T10:00:00Z"
        )
    }

    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testExpandedAppStoreOnboarding.rawValue]
            + screenshotLaunchConfiguration.launchArguments
    }
    override var additionalLaunchEnvironment: [String: String] {
        screenshotLaunchConfiguration.launchEnvironment
    }

    func testCaptureExpandedAppStoreScreenshotSet() throws {
        try captureOnboardingScreens()
        try captureSeededHomeScreens()
        try captureEvaActivationScreen()
        try captureEvaChatScreen()
        try captureHabitScreens()
        try captureOverdueRescueScreens()
        try captureReflectionScreens()
    }

    func testScreenshotSeedCompletesWithoutTerminatingTheApp() throws {
        try relaunchSeededWorkspace(evaCompleted: true)
        XCTAssertTrue(waitForRealisticHomeContent(timeout: 18))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSeededScreenshotDestinationsAreReachable() throws {
        try captureSeededHomeScreens()
        try captureEvaActivationScreen()
        try captureEvaChatScreen()
        try captureHabitScreens()
        try captureOverdueRescueScreens()
        try captureReflectionScreens()
    }

    func testSecondaryScreenshotDestinationsAreReachable() throws {
        try captureEvaActivationScreen()
        try captureEvaChatScreen()
        try captureHabitScreens()
        try captureOverdueRescueScreens()
        try captureReflectionScreens()
    }

    func testRescueScreenshotDestinationsAreReachable() throws {
        try captureOverdueRescueScreens()
    }

    func testOnboardingGoalUsesStableSelectableCardIdentifiers() throws {
        waitForSteadyWelcome()
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue])
        try require(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.goal],
            timeout: 12,
            message: "Onboarding goal destination did not appear"
        )
        let goal = try require(
            app.buttons[AccessibilityIdentifiers.Onboarding.primaryGoal("dailyExecution")],
            timeout: 8,
            message: "Daily execution goal did not expose its stable identifier"
        )
        try tap(goal)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton].isEnabled)
    }

    func testMissingSeededContentFailsClosed() throws {
        app.terminate()
        let unseededApp = XCUIApplication()
        unseededApp.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue
        ]
        app = unseededApp
        app.launch()
        waitForAppLaunch()

        let seededTask = app.descendants(matching: .any)[
            AccessibilityIdentifiers.Home.timelineTask("A5000000-0000-0000-0000-000000000001")
        ]
        XCTAssertThrowsError(
            try require(seededTask, timeout: 1, message: "Expected seeded task was missing")
        )
    }

    override func waitForAppLaunch() {
        let homeIndicator = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
        if homeIndicator.waitForExistence(timeout: 6) {
            return
        }

        if app.launchArguments.contains(XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue) {
            let seededContent = app.staticTexts["Finalize partner launch brief"]
            XCTAssert(
                waitForAny(app.navigationBars, timeout: 5)
                    || waitForAny(app.tabBars, timeout: 2)
                    || seededContent.exists,
                "Seeded screenshot app did not launch successfully within timeout"
            )
            return
        }

        let onboardingFlow = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.flow]
        let onboardingPrompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        let onboardingFinish = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.finish]
        let onboardingExists =
            onboardingFlow.waitForExistence(timeout: 20)
            || onboardingPrompt.waitForExistence(timeout: 4)
            || onboardingFinish.waitForExistence(timeout: 4)
        if onboardingExists {
            return
        }

        XCTAssert(
            waitForAny(app.navigationBars, timeout: 5) || waitForAny(app.tabBars, timeout: 5),
            "App did not launch successfully within timeout"
        )
    }

    private func captureOnboardingScreens() throws {
        waitForSteadyWelcome()
        saveScreenshot("01_onboarding_welcome")

        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.goal].waitForExistence(timeout: 12))
        saveScreenshot("02_onboarding_goal")

        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.primaryGoal("dailyExecution")])
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        saveScreenshot("05_onboarding_life_areas")

        let useAreas = app.buttons[AccessibilityIdentifiers.Onboarding.useAreas]
        XCTAssertTrue(useAreas.waitForExistence(timeout: 8))
        if waitUntilEnabled(useAreas, timeout: 2) == false {
            try selectLifeAreaIfNeeded("work-career")
            try selectLifeAreaIfNeeded("life-admin")
            try selectLifeAreaIfNeeded("health-self")
        }
        XCTAssertTrue(waitUntilEnabled(useAreas, timeout: 8))
        try tap(useAreas)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaValue].waitForExistence(timeout: 12))
        saveScreenshot("04_onboarding_choose_eva")

        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habitSetup].waitForExistence(timeout: 12))
        saveScreenshot("06_onboarding_habit_setup")

        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaStyle].waitForExistence(timeout: 12))
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.workingStyle("concise")])
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.workBlockers].waitForExistence(timeout: 12))
        saveScreenshot("03_onboarding_blockers")

        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.momentumBlocker("contextSwitching")])
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.weeklyOutcomes].waitForExistence(timeout: 12))
        saveScreenshot("07_onboarding_weekly_outcomes")

        let outcomeField = app.textFields[AccessibilityIdentifiers.Onboarding.weeklyOutcomeField(0)]
        XCTAssertTrue(outcomeField.waitForExistence(timeout: 12))
        outcomeField.tap()
        outcomeField.typeText("Ship the partner launch calmly")
        dismissKeyboardIfNeeded()
        try tap(app.buttons[AccessibilityIdentifiers.Onboarding.nextButton])

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 18))
        let chooseTaskButton = app.buttons[AccessibilityIdentifiers.Onboarding.primaryTaskAction]
        try require(chooseTaskButton, timeout: 8, message: "Primary onboarding task action did not appear")
        try tap(chooseTaskButton)
        let finishTaskButton = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(waitUntilEnabled(finishTaskButton, timeout: 12))
        scrollToTop()
        saveScreenshot("08_onboarding_first_task")

        try tap(finishTaskButton)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemo].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemoTimeline].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemoHabits].waitForExistence(timeout: 8))
        saveScreenshot("09_onboarding_home_demo")

        app.buttons[AccessibilityIdentifiers.Onboarding.nextButton].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.calendarPermission].waitForExistence(timeout: 12))
        saveScreenshot("10_onboarding_permissions")
    }

    private func captureSeededHomeScreens() throws {
        try relaunchSeededWorkspace(evaCompleted: true)
        XCTAssertTrue(waitForRealisticHomeContent(timeout: 18))
        assertNoFixtureCopyIsVisible()
        saveScreenshot("11_home_seeded_day")

        tapSunriseFilter("tasks")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineTask("A5000000-0000-0000-0000-000000000001")].waitForExistence(timeout: 8))
        saveScreenshot("12_home_tasks")

        tapSunriseFilter("meetings")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineEvent("test_meeting_1")].waitForExistence(timeout: 8))
        saveScreenshot("13_home_meetings")

        tapSunriseFilter("habits")
        try require(
            app.descendants(matching: .any)["home.habits.row.A6000000-0000-0000-0000-000000000002"],
            timeout: 8,
            message: "Expected the seeded Protein with breakfast habit"
        )
        saveScreenshot("14_home_habits")

        tapSunriseFilter("all")
        let focusStrip = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.focusStrip]
        scrollUntilVisible(focusStrip, maxSwipes: 3, in: homeScrollElement())
        try requireVisible(focusStrip, timeout: 3, message: "Expected the seeded focus strip before capture")
        saveScreenshot("15_home_focus_strip")
    }

    private func captureEvaActivationScreen() throws {
        try relaunchSeededWorkspace(evaCompleted: false)
        try openChatSurface()
        try require(
            app.descendants(matching: .any)["eva.activation.intro"],
            timeout: 10,
            message: "Eva activation intro did not appear"
        )
        saveScreenshot("16_eva_activation")
    }

    private func captureEvaChatScreen() throws {
        try relaunchSeededWorkspace(evaCompleted: true)
        try openChatSurface()
        guard waitForEvaChat(timeout: 10) else {
            throw captureFailure("Eva chat did not reach a transcript or composer state")
        }
        saveScreenshot("17_eva_chat")
    }

    private func captureHabitScreens() throws {
        try relaunchSeededWorkspace(evaCompleted: true)
        let openBoard = app.buttons[AccessibilityIdentifiers.Home.habitsOpenBoard]
        scrollUntilVisible(openBoard, maxSwipes: 5, in: homeScrollElement())
        try requireVisible(openBoard, timeout: 8, message: "Seeded habit board action did not appear")
        try tap(openBoard)
        let board = app.descendants(matching: .any)[AccessibilityIdentifiers.HabitBoard.view]
        XCTAssertTrue(board.waitForExistence(timeout: 15))

        let seededHabitID = "A6000000-0000-0000-0000-000000000002"
        let seededRow = app.descendants(matching: .any)["habitBoard.row.\(seededHabitID)"]
        try require(seededRow, timeout: 8, message: "Seeded screenshot habit row did not appear")
        XCTAssertEqual(seededRow.label, "Protein with breakfast")
        saveScreenshot("18_habit_board_history")
        try tap(seededRow)

        try require(
            app.descendants(matching: .any)[AccessibilityIdentifiers.HabitDetail.view],
            timeout: 12,
            message: "Seeded habit detail did not open"
        )
        saveScreenshot("19_habit_detail_history")
        scrollUntilVisible(app.descendants(matching: .any)[AccessibilityIdentifiers.HabitDetail.grid], maxSwipes: 4)
        saveScreenshot("20_habit_grid_reflection")
    }

    private func captureOverdueRescueScreens() throws {
        try relaunchSeededWorkspace(evaCompleted: true, seedRescue: true)
        let rescueSection = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSection]
        let rescueStart = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueStart]
        let rescueOpen = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueOpen]
        scrollDownUntilVisible(rescueOpen, maxSwipes: 14, in: homeScrollElement())
        let hasRescueEntry = isVisible(rescueSection) || isVisible(rescueStart) || isVisible(rescueOpen)
        guard hasRescueEntry else {
            let counts = app.descendants(matching: .any)["home.debug.counts"]
            let countsValue = counts.exists ? String(describing: counts.value ?? "unknown") : "unavailable"
            throw captureFailure("Seeded overdue-rescue entry did not appear; Home counts: \(countsValue)")
        }
        saveScreenshot("21_overdue_rescue_entry")

        if rescueStart.exists {
            try tap(rescueStart)
        } else if rescueOpen.exists {
            try tap(rescueOpen)
        } else {
            try tap(rescueSection)
        }

        let rescueSheet = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSheet]
        guard rescueSheet.waitForExistence(timeout: 10) else {
            let loading = app.descendants(matching: .any)["home.rescue.launcher.loading"]
            let failed = app.descendants(matching: .any)["home.rescue.launcher.failed"]
            let state = loading.exists
                ? "launcher remained loading"
                : (failed.exists ? "launcher failed: \(failed.value)" : "launcher state was not rendered")
            throw captureFailure("Overdue-rescue sheet did not open (\(state))")
        }
        try require(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueCard("A5000000-0000-0000-0000-000000000101")],
            timeout: 6,
            message: "Seeded rescue card did not appear"
        )
        saveScreenshot("22_overdue_rescue_deck")

        let keepToday = app.buttons[AccessibilityIdentifiers.Home.rescueActionKeepToday]
        try require(keepToday, timeout: 8, message: "Keep Today rescue action did not appear")
        try tap(keepToday)

        let viewToday = app.buttons[AccessibilityIdentifiers.Home.rescueCompletionViewToday]
        try require(viewToday, timeout: 10, message: "Rescue completion state did not appear")
        saveScreenshot("23_overdue_rescue_completion")
    }

    private func captureReflectionScreens() throws {
        try relaunchSeededWorkspace(evaCompleted: true, postSeedRoute: "daily_summary:nightly")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.screen].waitForExistence(timeout: 18))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.yesterdayCard].waitForExistence(timeout: 8))
        saveScreenshot("24_daily_reflection_summary")

        scrollUntilVisible(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.todayCard], maxSwipes: 4)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.todayCard].waitForExistence(timeout: 8))
        saveScreenshot("25_daily_reflection_plan")

        let contextToggle = app.buttons[AccessibilityIdentifiers.ReflectPlan.contextToggle]
        scrollUntilVisible(contextToggle, maxSwipes: 5)
        try require(contextToggle, timeout: 8, message: "Reflection context control did not appear")
        try tap(contextToggle)
        try require(
            app.textFields[AccessibilityIdentifiers.ReflectPlan.noteField],
            timeout: 6,
            message: "Reflection context note field did not appear"
        )
        saveScreenshot("26_daily_reflection_context")
    }

    private func relaunchSeededWorkspace(
        evaCompleted: Bool,
        seedRescue: Bool = false,
        postSeedRoute: String? = nil
    ) throws {
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedAppStoreScreenshots.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active"
        ]
        if evaCompleted {
            relaunched.launchArguments.append(XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue)
        }
        if seedRescue {
            relaunched.launchArguments.append(XCUIApplication.LaunchArgumentKey.testSeedOverdueRescueSuite.rawValue)
            relaunched.launchArguments.append(XCUIApplication.LaunchArgumentKey.enableDebugLogging.rawValue)
        }
        if let postSeedRoute {
            relaunched.launchArguments.append("-LIFEBOARD_TEST_POST_SEED_ROUTE:\(postSeedRoute)")
        }
        relaunched.launchArguments.append(contentsOf: screenshotLaunchConfiguration.launchArguments)
        relaunched.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        for (key, value) in screenshotLaunchConfiguration.launchEnvironment {
            relaunched.launchEnvironment[key] = value
        }
        app = relaunched
        app.launch()
        waitForAppLaunch()
        let ready = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.screenshotSeedReady]
        let failed = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.screenshotSeedFailed]
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline, ready.exists == false, failed.exists == false {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if failed.exists {
            throw captureFailure("App Store screenshot seed failed: \(failed.value as? String ?? "unknown error")")
        }
        try require(ready, timeout: 1, message: "App Store screenshot seed did not complete")
    }

    private func waitForSteadyWelcome() {
        let overlay = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroOverlay]
        XCTAssertTrue(overlay.waitForExistence(timeout: 8))
        let start = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
        if start.waitForExistence(timeout: 8) == false {
            overlay.tap()
        }
        XCTAssertTrue(start.waitForExistence(timeout: 12))
    }

    private func openChatSurface() throws {
        let homePage = HomePage(app: app)
        try require(homePage.chatButton, timeout: 8, message: "Eva dock button did not appear")
        try tap(homePage.chatButton)
        let activationIntro = app.descendants(matching: .any)["eva.activation.intro"]
        guard waitForEvaChat(timeout: 6) || activationIntro.waitForExistence(timeout: 2) else {
            throw captureFailure("Eva surface did not open from the dock button")
        }
    }

    private func waitForEvaChat(timeout: TimeInterval) -> Bool {
        let transcriptText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "cleanest plan")
        )
        let emptyGreeting = app.staticTexts["Hi there!"]
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        let standardComposer = app.descendants(matching: .any)["chat.composer.container"]
        let composer = app.descendants(matching: .any)["eva.structured.composer"]
        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if transcriptText.count > 0 || emptyGreeting.exists || emptyState.exists || standardComposer.exists || composer.exists || navTitle.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return transcriptText.count > 0 || emptyGreeting.exists || emptyState.exists || standardComposer.exists || composer.exists || navTitle.exists
    }

    private func waitForRealisticHomeContent(timeout: TimeInterval) -> Bool {
        let expected = [
            "Finalize partner launch brief",
            "Launch Readiness Review",
            "Walk before first coffee"
        ]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if expected.contains(where: { app.staticTexts[$0].exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return expected.contains(where: { app.staticTexts[$0].exists })
    }

    private func tapSunriseFilter(_ id: String) {
        scrollToTop()
        let chipRail = app.scrollViews["home.sunrise.chipRail"]
        XCTAssertTrue(chipRail.waitForExistence(timeout: 8))
        if id == "habits" {
            chipRail.swipeLeft()
        } else if id == "all" {
            chipRail.swipeRight()
        }
        let filter = app.buttons[AccessibilityIdentifiers.Home.sunriseFilter(id)]
        XCTAssertTrue(filter.waitForExistence(timeout: 8))
        filter.tap()
    }

    private func selectLifeAreaIfNeeded(_ id: String) throws {
        let area = app.descendants(matching: .any)["onboarding.lifeArea.\(id)"]
        if area.waitForExistence(timeout: 3) {
            try tap(area)
        }
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return element.exists && element.isEnabled
    }

    @discardableResult
    private func require(_ element: XCUIElement, timeout: TimeInterval, message: String) throws -> XCUIElement {
        guard element.waitForExistence(timeout: timeout) else {
            throw captureFailure(message)
        }
        return element
    }

    @discardableResult
    private func requireVisible(_ element: XCUIElement, timeout: TimeInterval, message: String) throws -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isVisible(element) { return element }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        guard isVisible(element) else { throw captureFailure(message) }
        return element
    }

    private func captureFailure(_ message: String) -> Error {
        return NSError(domain: "AppStoreScreenshotUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func scrollUntilVisible(
        _ element: XCUIElement,
        maxSwipes: Int,
        in scrollElement: XCUIElement? = nil
    ) {
        if element.waitForExistence(timeout: 1), isVisible(element) { return }
        for _ in 0..<maxSwipes {
            if let scrollElement {
                scrollElement.swipeUp()
            } else {
                app.swipeUp()
            }
            if element.waitForExistence(timeout: 1), isVisible(element) {
                return
            }
        }
    }

    private func homeScrollElement() -> XCUIElement {
        let taskList = app.scrollViews[AccessibilityIdentifiers.Home.taskListScrollView]
        return taskList.exists ? taskList : app
    }

    private func scrollDownUntilVisible(
        _ element: XCUIElement,
        maxSwipes: Int,
        in scrollElement: XCUIElement? = nil
    ) {
        if element.waitForExistence(timeout: 1), isVisible(element) { return }
        for _ in 0..<maxSwipes {
            if let scrollElement {
                scrollElement.swipeDown()
            } else {
                app.swipeDown()
            }
            if element.waitForExistence(timeout: 1), isVisible(element) {
                return
            }
        }
    }

    private func isVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, element.frame.isEmpty == false else { return false }
        return app.frame.intersects(element.frame)
    }

    private func scrollToTop() {
        for _ in 0..<4 {
            app.swipeDown()
        }
    }

    private func dismissKeyboardIfNeeded() {
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else if app.keyboards.count > 0 {
            app.typeText("\n")
        }
    }

    private func tap(_ element: XCUIElement) throws {
        guard element.isHittable else {
            throw captureFailure("Required element is not hittable: \(element.identifier)")
        }
        element.tap()
    }

    private func assertNoFixtureCopyIsVisible() {
        let forbidden = ["UI test", "seed", "Timeline Launch", "Rescue suite", "Rescue timeline quick win"]
        for text in forbidden {
            let matches = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@", text)
            )
            XCTAssertEqual(matches.count, 0, "Fixture copy should not be visible in App Store screenshots: \(text)")
        }
    }

    private func waitForAny(_ query: XCUIElementQuery, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if query.count > 0 { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return query.count > 0
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let repositoryRootURL = repositoryRoot
        let outputDate = String(screenshotLaunchConfiguration.fixedNow.prefix(10))
        let defaultOutputRoot = repositoryRootURL
            .appendingPathComponent("screenshots/app-store-raw-\(outputDate)", isDirectory: true)
            .path
        let outputConfiguration = screenshotOutputConfiguration(repositoryRoot: repositoryRootURL)
        let outputRoot = ProcessInfo.processInfo.environment["LIFEBOARD_SCREENSHOT_OUTPUT_DIR"]
            ?? outputConfiguration?.outputRoot
            ?? defaultOutputRoot
        let deviceSlug = ProcessInfo.processInfo.environment["LIFEBOARD_SCREENSHOT_DEVICE_SLUG"]
            ?? outputConfiguration?.deviceSlug
            ?? slug(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "simulator")
        let directory = URL(fileURLWithPath: outputRoot, isDirectory: true)
            .appendingPathComponent(deviceSlug, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: fileURL, options: .atomic)
        } catch {
            XCTFail("Failed to write screenshot \(name): \(error.localizedDescription)")
        }
    }

    private struct ScreenshotOutputConfiguration: Decodable {
        let outputRoot: String?
        let deviceSlug: String?
        let fixedNow: String?
    }

    private func screenshotOutputConfiguration(repositoryRoot: URL) -> ScreenshotOutputConfiguration? {
        let candidates = [
            URL(fileURLWithPath: "/tmp/lifeboard-app-store-screenshot-config.json"),
            repositoryRoot.appendingPathComponent(".app-store-screenshot-config.json")
        ]
        for configURL in candidates {
            guard let data = try? Data(contentsOf: configURL),
                  let configuration = try? JSONDecoder().decode(ScreenshotOutputConfiguration.self, from: data) else { continue }
            return configuration
        }
        return nil
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
