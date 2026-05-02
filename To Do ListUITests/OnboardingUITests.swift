import XCTest

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    func testFreshLaunchShowsWelcomeThenCurrentProgressModel() {
        advanceToSteadyWelcome(in: app)

        let introCTA = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
        XCTAssertEqual(introCTA.label, "Start setup")
        introCTA.tap()

        waitForGoalReady(in: app)
        XCTAssertTrue(app.staticTexts["Step 1 of 14"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["Step 1 of 6"].exists)
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testGuidedFlowCompletesThroughCurrentFourteenStepPath() {
        advanceToFocusRoom()

        let startFocus = waitForFocusPrimary()
        startFocus.tap()

        let markComplete = app.buttons[AccessibilityIdentifiers.Onboarding.markComplete].firstMatch
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habitCheckIn].waitForExistence(timeout: 12))
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.calendarPermission].waitForExistence(timeout: 12))
        app.buttons["Skip for now"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.notificationPermission].waitForExistence(timeout: 12))
        app.buttons["Skip for now"].firstMatch.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))

        let goHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        XCTAssertTrue(goHome.waitForExistence(timeout: 12))
        goHome.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }

    func testGlobalSkipSeedsStarterTaskAndRunsFocusRoomFlow() {
        startGuidedOnboarding()

        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
        app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].tap()

        let focusRoom = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom]
        XCTAssertTrue(focusRoom.waitForExistence(timeout: 12))
        XCTAssertTrue(waitForFocusPrimary().exists)
    }

    func testLifeAreasShowCoreAreasThenRevealOptionalAreas() {
        advanceToLifeAreas()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.work-career"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.life-admin"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.health-self"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["onboarding.lifeArea.relationships"].exists)

        let showMoreAreas = app.buttons["Show more areas"]
        XCTAssertTrue(showMoreAreas.waitForExistence(timeout: 12))
        showMoreAreas.tap()

        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.relationships"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.learning-growth"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.creativity-fun"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.lifeArea.money"].exists)
    }

    func testEvaStyleStepCanSelectChiefOfStaffPersona() {
        advanceToEvaStyle()

        let personaButton = app.buttons[AccessibilityIdentifiers.Onboarding.mascotPersona("sato")]
        XCTAssertTrue(personaButton.waitForExistence(timeout: 12), "Sato persona should be available on the assistant preferences step")
        personaButton.tap()

        XCTAssertTrue(app.staticTexts["Sato"].waitForExistence(timeout: 3), "Selected persona name should remain visible")

        let assistantGoalField = app.textFields.firstMatch
        XCTAssertTrue(assistantGoalField.waitForExistence(timeout: 12))
        assistantGoalField.tap()
        assistantGoalField.typeText("Finish one concrete task")
        app.buttons["Save preferences"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 18))
        XCTAssertTrue(app.buttons["Ask Sato"].waitForExistence(timeout: 6), "Later onboarding assistant copy should use the selected persona")
    }

    func testOnboardingRestoresGoalStepAfterRelaunch() {
        startGuidedOnboarding()

        app.terminate()
        app = relaunchAppWithoutReset()

        waitForGoalReady(in: app)
        XCTAssertTrue(app.buttons["Choose goal"].exists)
    }

    private func startGuidedOnboarding() {
        advanceToSteadyWelcome(in: app)
        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()
        waitForGoalReady(in: app)
    }

    private func advanceToLifeAreas() {
        startGuidedOnboarding()

        tapButton(labelPrefix: "Starting each day")
        app.buttons["Choose goal"].tap()

        let pain = button(labelPrefix: "Several priorities compete and I stall")
        XCTAssertTrue(pain.waitForExistence(timeout: 12))
        pain.tap()
        app.buttons["Choose blockers"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaValue].waitForExistence(timeout: 12))
        app.buttons["Build setup"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
    }

    private func advanceToFocusRoom() {
        advanceToEvaStyle()
        let evaGoalField = app.textFields.firstMatch
        XCTAssertTrue(evaGoalField.waitForExistence(timeout: 12))
        evaGoalField.tap()
        evaGoalField.typeText("Finish one concrete task")
        app.buttons["Save preferences"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 18))
        app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom].waitForExistence(timeout: 12))
    }

    private func advanceToEvaStyle() {
        advanceToLifeAreas()
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habitSetup].waitForExistence(timeout: 12))
        app.buttons["Set habit"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.streakPreview].waitForExistence(timeout: 12))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaStyle].waitForExistence(timeout: 12))
    }

    private func relaunchAppWithoutReset() -> XCUIApplication {
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS"
        ] + additionalLaunchArguments
        relaunchedApp.launch()
        return relaunchedApp
    }

    private func button(labelPrefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", labelPrefix)).firstMatch
    }

    private func tapButton(labelPrefix: String) {
        let button = button(labelPrefix: labelPrefix)
        XCTAssertTrue(button.waitForExistence(timeout: 12))
        button.tap()
    }

    private func waitForFocusPrimary() -> XCUIElement {
        let button = app.buttons[AccessibilityIdentifiers.Onboarding.focusPrimary].firstMatch
        if button.waitForExistence(timeout: 6) == false {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 12))
        return button
    }
}

final class OnboardingRestartUITests: BaseUITest {
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_OPEN_SETTINGS"] }

    func testRestartOnboardingFromSettings() {
        let restartButton = app.buttons[AccessibilityIdentifiers.Settings.onboardingRestartButton]
        for _ in 0..<6 where restartButton.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(restartButton.waitForExistence(timeout: 12))
        restartButton.tap()

        advanceToSteadyWelcome(in: app)
    }
}

final class OnboardingPromptUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"] }

    func testEstablishedWorkspacePromptCanStartFullOnboarding() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))
        assertCinematicBackdropIsAbsent(in: app)

        let startButton = app.buttons["Review matched setup"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        waitForGoalReady(in: app)
        XCTAssertTrue(app.staticTexts["What needs attention first?"].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testEstablishedWorkspacePromptDismissalSuppressesRelaunch() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))
        assertCinematicBackdropIsAbsent(in: app)

        let dismissButton = app.buttons["Not now"].firstMatch
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 12))
        dismissButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }
}

final class OnboardingLaunchQueueUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_ROUTE:daily_summary:morning"] }

    func testFreshLaunchShowsOnboardingAfterBlockingModalDismisses() {
        let dailySummary = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.dailySummaryModal]
        XCTAssertTrue(dailySummary.waitForExistence(timeout: 12))

        let dismissCTA = app.buttons["Start Today"]
        XCTAssertTrue(dismissCTA.waitForExistence(timeout: 12))
        dismissCTA.tap()

        advanceToSteadyWelcome(in: app)
    }
}

private func advanceToSteadyWelcome(in app: XCUIApplication) {
    let introOverlay = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroOverlay]
    XCTAssertTrue(introOverlay.waitForExistence(timeout: 4))

    assertCinematicBackdrop(in: app, grain: "25%")

    let introCTA = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
    if introCTA.waitForExistence(timeout: 8) == false {
        introOverlay.tap()
    }
    XCTAssertTrue(introCTA.waitForExistence(timeout: 12))
    XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
    XCTAssertTrue(app.staticTexts["Guided setup"].exists)
    XCTAssertTrue(app.staticTexts["~2 min"].exists)
    XCTAssertTrue(app.staticTexts["Easy to edit"].exists)
}

private func waitForGoalReady(in app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
    let goal = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.goal]
    XCTAssertTrue(goal.waitForExistence(timeout: 12), "Expected goal step to exist", file: file, line: line)
}

private func assertCinematicBackdrop(in app: XCUIApplication, grain expectedValue: String, file: StaticString = #file, line: UInt = #line) {
    let video = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropVideo]
    XCTAssertTrue(video.waitForExistence(timeout: 8), "Expected cinematic backdrop video marker to exist", file: file, line: line)

    let grain = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropGrain]
    XCTAssertTrue(grain.waitForExistence(timeout: 8), "Expected cinematic backdrop grain marker to exist", file: file, line: line)
    XCTAssertEqual(grain.value as? String, expectedValue, "Unexpected onboarding video grain amount", file: file, line: line)
}

private func assertCinematicBackdropIsAbsent(in app: XCUIApplication, file: StaticString = #file, line: UInt = #line) {
    let video = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropVideo]
    XCTAssertFalse(video.exists, "Expected cinematic backdrop video marker to be absent", file: file, line: line)

    let grain = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropGrain]
    XCTAssertFalse(grain.exists, "Expected cinematic backdrop grain marker to be absent", file: file, line: line)
}
