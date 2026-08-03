import XCTest

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    /// Walks the rebuilt nine-step flow end to end.
    ///
    /// The previous version of this file asserted "Step 1 of 13" and walked
    /// screens (pain, work style, weekly outcomes, calendar, notifications) that
    /// were only reachable behind a screenshot-only launch argument no test
    /// passed — so it could not have been passing.
    func testGuidedFlowCompletesThroughNineSteps() {
        advanceToSteadyWelcome(in: app)

        let introCTA = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
        XCTAssertTrue(introCTA.waitForExistence(timeout: 12))
        XCTAssertEqual(introCTA.label, "Start")
        introCTA.tap()

        // 2 — Intent
        XCTAssertTrue(app.staticTexts["Step 2 of 9"].waitForExistence(timeout: 12))
        app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.primaryGoal("wholeWeek")]
            .firstMatch.tap()
        tapNext()

        // 3 — Life areas
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
                .waitForExistence(timeout: 12)
        )
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].firstMatch.tap()

        // 4 — Guide
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.evaValue]
                .waitForExistence(timeout: 12)
        )
        tapNext()

        // 5 — Day shape. Accepting the prefilled hours is a single tap.
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.dayShape]
                .waitForExistence(timeout: 12)
        )
        tapNext()

        // 6 — Modules
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.modules]
                .waitForExistence(timeout: 12)
        )
        tapNext()

        // 7 — First win
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habitSetup]
                .waitForExistence(timeout: 12)
        )
        let addTask = app.buttons[AccessibilityIdentifiers.Onboarding.primaryTaskAction].firstMatch
        if addTask.waitForExistence(timeout: 8) { addTask.tap() }
        app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask].firstMatch.tap()

        // 8 — Permissions. Every row is skippable; nothing here may block.
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.permissions]
                .waitForExistence(timeout: 12)
        )
        tapNext()

        // 9 — Success
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
                .waitForExistence(timeout: 12)
        )
        let goHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        XCTAssertTrue(goHome.waitForExistence(timeout: 12))
        goHome.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
                .waitForExistence(timeout: 12)
        )
    }

    func testProgressReportsNineStepsNotThirteen() {
        advanceToSteadyWelcome(in: app)
        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()

        XCTAssertTrue(app.staticTexts["Step 2 of 9"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.staticTexts["Step 2 of 13"].exists)
    }

    func testGlobalSkipStillLeavesAUsableWorkspace() {
        advanceToSteadyWelcome(in: app)
        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()

        let skip = app.buttons[AccessibilityIdentifiers.Onboarding.skipButton]
        XCTAssertTrue(skip.waitForExistence(timeout: 12))
        skip.tap()

        // Skipping seeds the starter workspace and lands on permissions rather
        // than dumping the user on an empty Home.
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.permissions]
                .waitForExistence(timeout: 20)
        )
    }

    func testLifeAreasShowCoreAreasThenRevealOptionalAreas() {
        advanceToSteadyWelcome(in: app)
        app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue].tap()
        app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.primaryGoal("wholeWeek")]
            .firstMatch.tap()
        tapNext()

        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
                .waitForExistence(timeout: 12)
        )
        let moreAreas = app.buttons["More areas"].firstMatch
        if moreAreas.waitForExistence(timeout: 6) {
            moreAreas.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeArea("money")]
                    .waitForExistence(timeout: 8)
            )
        }
    }

    private func tapNext() {
        let next = app.buttons[AccessibilityIdentifiers.Onboarding.nextButton].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 12))
        next.tap()
    }
}


final class OnboardingRestartUITests: BaseUITest {
    override var additionalLaunchArguments: [String] { ["-LIFEBOARD_TEST_OPEN_SETTINGS"] }

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
    override var additionalLaunchArguments: [String] { ["-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE"] }

    func testEstablishedWorkspacePromptCanStartFullOnboarding() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))
        assertCinematicBackdropIsAbsent(in: app)
        assertEstablishedWorkspacePromptContentFits(prompt: prompt)

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
        assertEstablishedWorkspacePromptContentFits(prompt: prompt)

        let dismissButton = app.buttons["Not now"].firstMatch
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 12))
        dismissButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }

    private func assertEstablishedWorkspacePromptContentFits(
        prompt: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.staticTexts["Start from what already fits."].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["What LifeBoard will reuse"].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Already in place: 1 area, 1 project, 3 tasks"].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Keep the areas and projects that already fit."].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Suggest one light habit only if it improves tomorrow."].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Guide you into one small completion without duplicate clutter."].waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Leave your existing setup intact while you review the next layer."].waitForExistence(timeout: 4), file: file, line: line)

        let startButton = app.buttons["Review matched setup"].firstMatch
        let dismissButton = app.buttons["Not now"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(startButton.isHittable, file: file, line: line)
        XCTAssertTrue(dismissButton.isHittable, file: file, line: line)

        assertElementFitsInWindow(prompt, file: file, line: line)
        assertElementFitsInWindow(startButton, file: file, line: line)
        assertElementFitsInWindow(dismissButton, file: file, line: line)
    }

    private func assertElementFitsInWindow(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let window = app.windows.firstMatch
        let windowFrame = window.exists ? window.frame : app.frame
        let frame = element.frame
        let tolerance: CGFloat = 1

        XCTAssertGreaterThanOrEqual(frame.minX, windowFrame.minX - tolerance, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, windowFrame.minY - tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, windowFrame.maxX + tolerance, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, windowFrame.maxY + tolerance, file: file, line: line)
    }
}

final class OnboardingLaunchQueueUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-LIFEBOARD_TEST_ROUTE:daily_summary:morning"] }

    func testFreshLaunchShowsOnboardingAfterBlockingModalDismisses() {
        let dailySummary = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.dailySummaryModal]
        XCTAssertTrue(dailySummary.waitForExistence(timeout: 12))

        let dismissCTA = app.buttons["Start Today"]
        XCTAssertTrue(dismissCTA.waitForExistence(timeout: 12))
        dismissCTA.tap()

        advanceToSteadyWelcome(in: app)
    }
}

@MainActor
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
    XCTAssertTrue(app.staticTexts["Change this later"].exists)
}

@MainActor
private func waitForGoalReady(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let goal = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.goal]
    XCTAssertTrue(goal.waitForExistence(timeout: 12), "Expected goal step to exist", file: file, line: line)
}

@MainActor
private func assertCinematicBackdrop(in app: XCUIApplication, grain expectedValue: String, file: StaticString = #filePath, line: UInt = #line) {
    let video = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropVideo]
    XCTAssertTrue(video.waitForExistence(timeout: 8), "Expected cinematic backdrop video marker to exist", file: file, line: line)

    let grain = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropGrain]
    XCTAssertTrue(grain.waitForExistence(timeout: 8), "Expected cinematic backdrop grain marker to exist", file: file, line: line)
    XCTAssertEqual(grain.value as? String, expectedValue, "Unexpected onboarding video grain amount", file: file, line: line)
}

@MainActor
private func assertCinematicBackdropIsAbsent(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    let video = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropVideo]
    XCTAssertFalse(video.exists, "Expected cinematic backdrop video marker to be absent", file: file, line: line)

    let grain = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.backdropGrain]
    XCTAssertFalse(grain.exists, "Expected cinematic backdrop grain marker to be absent", file: file, line: line)
}
