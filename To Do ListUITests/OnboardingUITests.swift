import XCTest

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var additionalLaunchArguments: [String] { ["-TASKER_ENABLE_LIQUID_METAL_CTA"] }
    override var shouldSkipOnboarding: Bool { false }

    func testFreshLaunchShowsWelcomeOnboarding() {
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].exists)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.customize].exists)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
    }

    func testSkipSeedsStarterTaskAndRunsFocusRoomFlow() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].tap()

        let focusRoom = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom]
        XCTAssertTrue(focusRoom.waitForExistence(timeout: 12))

        let startFocus = app.buttons[AccessibilityIdentifiers.Onboarding.focusPrimary]
        XCTAssertTrue(startFocus.waitForExistence(timeout: 12))
        startFocus.tap()

        let markComplete = app.buttons[AccessibilityIdentifiers.Onboarding.markComplete]
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))
        XCTAssertTrue(success.staticTexts["What’s ready"].waitForExistence(timeout: 12))
        XCTAssertTrue(success.staticTexts["Areas"].exists)
        XCTAssertTrue(success.staticTexts["Projects"].exists)
        XCTAssertTrue(success.staticTexts["First win"].exists)
        XCTAssertFalse(success.staticTexts["areas"].exists)
        XCTAssertFalse(success.staticTexts["projects"].exists)

        let goHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        XCTAssertTrue(goHome.waitForExistence(timeout: 12))
        goHome.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }

    func testGuidedFlowCompletesSingleTaskAndRevealsHome() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        let projects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(projects.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        let firstTask = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 12))

        let chooseButton = app.buttons["Choose"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 12))
        chooseButton.tap()

        let finishTask = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(finishTask.waitForExistence(timeout: 12))
        finishTask.tap()

        let focusPrimary = app.buttons[AccessibilityIdentifiers.Onboarding.focusPrimary]
        XCTAssertTrue(focusPrimary.waitForExistence(timeout: 12))
        focusPrimary.tap()

        let markComplete = app.buttons[AccessibilityIdentifiers.Onboarding.markComplete]
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))
        XCTAssertTrue(success.staticTexts["What’s ready"].waitForExistence(timeout: 12))
        XCTAssertTrue(success.staticTexts["Areas"].exists)
        XCTAssertTrue(success.staticTexts["Projects"].exists)
        XCTAssertTrue(success.staticTexts["First win"].exists)
        XCTAssertFalse(success.staticTexts["areas"].exists)
        XCTAssertFalse(success.staticTexts["projects"].exists)

        let goHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        XCTAssertTrue(goHome.waitForExistence(timeout: 12))
        goHome.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }

    func testOnboardingRestoresProjectsStepAfterRelaunch() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        let projects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(projects.waitForExistence(timeout: 12))

        app.terminate()
        app = relaunchAppWithoutReset()

        let resumedProjects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(resumedProjects.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].exists)
    }

    func testCustomPathAllowsManualAreaEditingBeforeContinuing() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.customize].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))

        let homeArea = app.descendants(matching: .any)["onboarding.lifeArea.home"]
        XCTAssertTrue(homeArea.waitForExistence(timeout: 12))
        homeArea.tap()

        let useAreas = app.buttons[AccessibilityIdentifiers.Onboarding.useAreas]
        XCTAssertTrue(useAreas.waitForExistence(timeout: 12))
        useAreas.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
    }

    func testCustomTaskComposerRoundTripReturnsToFirstTaskAndFocusRoom() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        let projects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(projects.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        let firstTask = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 12))

        let customTaskButton = app.buttons["Use my own step"].firstMatch
        XCTAssertTrue(customTaskButton.waitForExistence(timeout: 12))
        customTaskButton.tap()

        let addTaskPage = AddTaskPage(app: app)
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(timeout: 12))
        addTaskPage.enterTitle("Draft a weekly review")
        addTaskPage.tapSave()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 12))

        let goFinishTask = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(goFinishTask.waitForExistence(timeout: 12))
        goFinishTask.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom].waitForExistence(timeout: 12))
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

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))
    }
}

final class OnboardingPromptUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"] }

    func testEstablishedWorkspacePromptCanStartFullOnboarding() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))

        let startButton = app.buttons[AccessibilityIdentifiers.Onboarding.promptStart]
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))
    }

    func testEstablishedWorkspacePromptDismissalSuppressesRelaunch() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))

        let dismissButton = app.buttons[AccessibilityIdentifiers.Onboarding.promptDismiss]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 12))
        dismissButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))

        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"
        ]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
        XCTAssertFalse(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt].waitForExistence(timeout: 3))
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

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))
    }
}

private extension OnboardingFreshLaunchUITests {
    func relaunchAppWithoutReset() -> XCUIApplication {
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS"
        ] + additionalLaunchArguments
        relaunchedApp.launch()
        return relaunchedApp
    }
}
