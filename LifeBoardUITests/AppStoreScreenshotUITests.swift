import XCTest

@MainActor
final class AppStoreScreenshotUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testExpandedAppStoreOnboarding.rawValue]
    }

    func testCaptureExpandedAppStoreScreenshotSet() throws {
        captureOnboardingScreens()
        captureSeededHomeScreens()
        captureEvaActivationScreen()
        captureEvaChatScreen()
        captureHabitScreens()
        captureOverdueRescueScreens()
        captureReflectionScreens()
    }

    override func waitForAppLaunch() {
        let homeIndicator = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
        if homeIndicator.waitForExistence(timeout: 6) {
            return
        }

        if app.launchArguments.contains(XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue) {
            let navBar = app.navigationBars.firstMatch
            let tabBar = app.tabBars.firstMatch
            let seededContent = app.staticTexts["Finalize partner launch brief"]
            XCTAssert(
                navBar.waitForExistence(timeout: 5) || tabBar.waitForExistence(timeout: 2) || seededContent.exists,
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

        let navBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        XCTAssert(
            navBar.waitForExistence(timeout: 5) || tabBar.waitForExistence(timeout: 5),
            "App did not launch successfully within timeout"
        )
    }

    private func captureOnboardingScreens() {
        waitForSteadyWelcome()
        saveScreenshot("01_onboarding_welcome")

        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.goal].waitForExistence(timeout: 12))
        saveScreenshot("02_onboarding_goal")

        tapButton(labelPrefix: "Starting each day")
        app.buttons["Choose goal"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        saveScreenshot("05_onboarding_life_areas")

        let useAreas = app.buttons[AccessibilityIdentifiers.Onboarding.useAreas]
        XCTAssertTrue(useAreas.waitForExistence(timeout: 8))
        if waitUntilEnabled(useAreas, timeout: 2) == false {
            selectLifeAreaIfNeeded("work-career")
            selectLifeAreaIfNeeded("life-admin")
            selectLifeAreaIfNeeded("health-self")
        }
        XCTAssertTrue(waitUntilEnabled(useAreas, timeout: 8))
        tap(useAreas)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaValue].waitForExistence(timeout: 12))
        saveScreenshot("04_onboarding_choose_eva")

        app.buttons["Choose guide"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habitSetup].waitForExistence(timeout: 12))
        saveScreenshot("06_onboarding_habit_setup")

        app.buttons["Set habit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaStyle].waitForExistence(timeout: 12))
        app.buttons["Be concise"].firstMatch.tap()
        app.buttons["Save style"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.workBlockers].waitForExistence(timeout: 12))
        saveScreenshot("03_onboarding_blockers")

        app.buttons["Context switching"].firstMatch.tap()
        app.buttons["Save blockers"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.weeklyOutcomes].waitForExistence(timeout: 12))
        saveScreenshot("07_onboarding_weekly_outcomes")

        let outcomeField = app.textFields[AccessibilityIdentifiers.Onboarding.weeklyOutcomeField(0)]
        XCTAssertTrue(outcomeField.waitForExistence(timeout: 12))
        outcomeField.tap()
        outcomeField.typeText("Ship the partner launch calmly")
        dismissKeyboardIfNeeded()
        app.buttons["Save outcomes"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 18))
        let chooseTaskButton = app.buttons["Choose"].firstMatch
        XCTAssertTrue(chooseTaskButton.waitForExistence(timeout: 8))
        tap(chooseTaskButton)
        let finishTaskButton = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(waitUntilEnabled(finishTaskButton, timeout: 12))
        scrollToTop()
        saveScreenshot("08_onboarding_first_task")

        tap(finishTaskButton)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemo].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemoTimeline].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.homeDemoHabits].waitForExistence(timeout: 8))
        saveScreenshot("09_onboarding_home_demo")

        app.buttons[AccessibilityIdentifiers.Onboarding.nextButton].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.calendarPermission].waitForExistence(timeout: 12))
        saveScreenshot("10_onboarding_permissions")
    }

    private func captureSeededHomeScreens() {
        relaunchSeededWorkspace(evaCompleted: true)
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
        _ = waitForLabelContaining("Walk before first coffee", timeout: 5)
        saveScreenshot("14_home_habits")

        tapSunriseFilter("all")
        let focusStrip = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.focusStrip]
        scrollUntilVisible(focusStrip, maxSwipes: 3)
        if focusStrip.waitForExistence(timeout: 3) == false {
            _ = waitForLabelContaining("Finalize partner launch brief", timeout: 4)
        }
        saveScreenshot("15_home_focus_strip")
    }

    private func captureEvaActivationScreen() {
        relaunchSeededWorkspace(evaCompleted: false)
        openChatSurface()
        let activationIntro = app.otherElements["eva.activation.intro"]
        if activationIntro.waitForExistence(timeout: 6) == false {
            _ = waitForEvaChat(timeout: 4)
        }
        saveScreenshot("16_eva_activation")
    }

    private func captureEvaChatScreen() {
        relaunchSeededWorkspace(evaCompleted: true)
        openChatSurface()
        if waitForEvaChat(timeout: 10) == false {
            _ = waitForLabelContaining("Eva", timeout: 2)
        }
        saveScreenshot("17_eva_chat")
    }

    private func captureHabitScreens() {
        relaunchSeededWorkspace(evaCompleted: true, presentHabitBoard: true)
        let board = app.descendants(matching: .any)[AccessibilityIdentifiers.HabitBoard.view]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        _ = waitForLabelContaining("Walk before first coffee", timeout: 5)
        saveScreenshot("18_habit_board_history")

        let firstRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "habitBoard.row.")
        ).firstMatch
        guard firstRow.waitForExistence(timeout: 6) else {
            saveScreenshot("19_habit_detail_history")
            saveScreenshot("20_habit_grid_reflection")
            return
        }
        tap(firstRow)

        guard app.descendants(matching: .any)[AccessibilityIdentifiers.HabitDetail.view].waitForExistence(timeout: 10) else {
            saveScreenshot("19_habit_detail_history")
            saveScreenshot("20_habit_grid_reflection")
            return
        }
        saveScreenshot("19_habit_detail_history")
        scrollUntilVisible(app.descendants(matching: .any)[AccessibilityIdentifiers.HabitDetail.grid], maxSwipes: 4)
        saveScreenshot("20_habit_grid_reflection")
    }

    private func captureOverdueRescueScreens() {
        relaunchSeededWorkspace(evaCompleted: true)
        let rescueSection = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSection]
        let rescueStart = app.buttons[AccessibilityIdentifiers.Home.rescueStart]
        let rescueOpen = app.buttons[AccessibilityIdentifiers.Home.rescueOpen]
        scrollUntilVisible(rescueSection, maxSwipes: 7)
        let hasRescueEntry = rescueSection.waitForExistence(timeout: 4) || rescueStart.exists || rescueOpen.exists
        if hasRescueEntry == false {
            _ = waitForLabelContaining("Renew passport photos", timeout: 4)
        }
        saveScreenshot("21_overdue_rescue_entry")
        guard hasRescueEntry else {
            saveScreenshot("22_overdue_rescue_deck")
            saveScreenshot("23_overdue_rescue_completion")
            return
        }

        if rescueStart.exists {
            tap(rescueStart)
        } else if rescueOpen.exists {
            tap(rescueOpen)
        } else {
            tap(rescueSection)
        }

        let rescueSheet = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueSheet]
        guard rescueSheet.waitForExistence(timeout: 8) else {
            saveScreenshot("22_overdue_rescue_deck")
            saveScreenshot("23_overdue_rescue_completion")
            return
        }
        _ = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueCard("A5000000-0000-0000-0000-000000000101")].waitForExistence(timeout: 4)
        saveScreenshot("22_overdue_rescue_deck")

        let keepToday = app.buttons[AccessibilityIdentifiers.Home.rescueActionKeepToday]
        if keepToday.waitForExistence(timeout: 6) {
            tap(keepToday)
        }

        let viewToday = app.buttons[AccessibilityIdentifiers.Home.rescueCompletionViewToday]
        _ = viewToday.waitForExistence(timeout: 8)
        saveScreenshot("23_overdue_rescue_completion")
    }

    private func captureReflectionScreens() {
        relaunchSeededWorkspace(evaCompleted: true, postSeedRoute: "daily_summary:nightly")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.screen].waitForExistence(timeout: 18))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.yesterdayCard].waitForExistence(timeout: 8))
        saveScreenshot("24_daily_reflection_summary")

        scrollUntilVisible(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.todayCard], maxSwipes: 4)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.todayCard].waitForExistence(timeout: 8))
        saveScreenshot("25_daily_reflection_plan")

        let contextToggle = app.buttons[AccessibilityIdentifiers.ReflectPlan.contextToggle]
        scrollUntilVisible(contextToggle, maxSwipes: 5)
        if contextToggle.waitForExistence(timeout: 4) {
            tap(contextToggle)
            _ = app.textFields[AccessibilityIdentifiers.ReflectPlan.noteField].waitForExistence(timeout: 4)
        }
        saveScreenshot("26_daily_reflection_context")
    }

    private func relaunchSeededWorkspace(
        evaCompleted: Bool,
        presentHabitBoard: Bool = false,
        postSeedRoute: String? = nil
    ) {
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
        if presentHabitBoard {
            relaunched.launchArguments.append(XCUIApplication.LaunchArgumentKey.testPresentHabitBoard.rawValue)
        }
        if let postSeedRoute {
            relaunched.launchArguments.append("-LIFEBOARD_TEST_POST_SEED_ROUTE:\(postSeedRoute)")
        }
        relaunched.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app = relaunched
        app.launch()
        waitForAppLaunch()
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

    private func openChatSurface() {
        let homePage = HomePage(app: app)
        let candidates = [
            homePage.chatButton,
            app.buttons["Chat"],
            app.descendants(matching: .any)["home.bottomBar"]
        ]
        for candidate in candidates where candidate.waitForExistence(timeout: 2) {
            if candidate.identifier == "home.bottomBar" {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
            } else {
                tap(candidate)
            }
            if waitForEvaChat(timeout: 4) || app.otherElements["eva.activation.intro"].exists {
                return
            }
        }
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.92)).tap()
    }

    private func waitForEvaChat(timeout: TimeInterval) -> Bool {
        let transcriptText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "cleanest plan")
        ).firstMatch
        let emptyGreeting = app.staticTexts["Hi there!"]
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        let standardComposer = app.descendants(matching: .any)["chat.composer.container"]
        let composer = app.descendants(matching: .any)["eva.structured.composer"]
        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if transcriptText.exists || emptyGreeting.exists || emptyState.exists || standardComposer.exists || composer.exists || navTitle.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return transcriptText.exists || emptyGreeting.exists || emptyState.exists || standardComposer.exists || composer.exists || navTitle.exists
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
        if id == "habits" {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.535))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.535))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        let filter = app.buttons[AccessibilityIdentifiers.Home.sunriseFilter(id)]
        XCTAssertTrue(filter.waitForExistence(timeout: 8))
        if id == "habits" {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.74, dy: 0.535)).tap()
        } else {
            tap(filter)
        }
    }

    private func selectLifeAreaIfNeeded(_ id: String) {
        let area = app.descendants(matching: .any)["onboarding.lifeArea.\(id)"]
        if area.waitForExistence(timeout: 3) {
            tap(area)
        }
    }

    private func tapButton(labelPrefix: String) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", labelPrefix)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 12))
        tap(button)
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

    private func waitForLabelContaining(_ text: String, timeout: TimeInterval) -> Bool {
        let element = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", text)
        ).firstMatch
        if element.waitForExistence(timeout: min(2, timeout)) {
            return true
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            app.swipeUp()
            if element.waitForExistence(timeout: 0.8) {
                return true
            }
        }
        return element.exists
    }

    private func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int) {
        if element.waitForExistence(timeout: 1) { return }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return
            }
        }
    }

    private func scrollToTop() {
        for _ in 0..<4 {
            app.swipeDown()
        }
    }

    private func dismissKeyboardIfNeeded() {
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else if app.keyboards.firstMatch.exists {
            app.typeText("\n")
        }
    }

    private func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func assertNoFixtureCopyIsVisible() {
        let forbidden = ["UI test", "seed", "Timeline Launch", "Rescue suite", "Rescue timeline quick win"]
        for text in forbidden {
            let element = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@", text)
            ).firstMatch
            XCTAssertFalse(element.exists, "Fixture copy should not be visible in App Store screenshots: \(text)")
        }
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let defaultOutputRoot = repositoryRoot
            .appendingPathComponent("screenshots/app-store-raw-2026-07-06", isDirectory: true)
            .path
        let outputConfiguration = screenshotOutputConfiguration(repositoryRoot: repositoryRoot)
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
    }

    private func screenshotOutputConfiguration(repositoryRoot: URL) -> ScreenshotOutputConfiguration? {
        let configURL = repositoryRoot.appendingPathComponent(".app-store-screenshot-config.json")
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? JSONDecoder().decode(ScreenshotOutputConfiguration.self, from: data)
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
