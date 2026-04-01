import XCTest

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    func testFreshLaunchShowsWelcomeOnboarding() {
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].exists)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.customize].exists)
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].label, "Start recommended setup")
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Onboarding.customize].label, "Customize setup")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
        XCTAssertTrue(app.buttons["Getting started"].exists)
        XCTAssertTrue(app.buttons["Too many options"].exists)
        XCTAssertTrue(app.buttons["Keeping track"].exists)
        XCTAssertTrue(app.buttons["Following through"].exists)
        XCTAssertTrue(app.buttons["Too much at once"].exists)
    }

    func testWelcomeFrictionSelectionUpdatesSharedHelperText() {
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 12))

        let keepingTrack = app.buttons["Keeping track"]
        XCTAssertTrue(keepingTrack.waitForExistence(timeout: 12))
        keepingTrack.tap()

        XCTAssertTrue(app.staticTexts["Tasker will bring the next step back when it matters."].waitForExistence(timeout: 12))
    }

    func testSkipSeedsStarterTaskAndRunsFocusRoomFlow() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].tap()

        let focusRoom = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom]
        XCTAssertTrue(focusRoom.waitForExistence(timeout: 12))

        let startFocus = app.buttons["Start focus"].firstMatch
        XCTAssertTrue(startFocus.waitForExistence(timeout: 12))
        startFocus.tap()

        let markComplete = app.buttons["Mark complete"].firstMatch
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))

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

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useHabits].tap()

        let firstTask = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 12))

        let chooseButton = app.buttons["Choose"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 12))
        chooseButton.tap()

        let finishTask = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(finishTask.waitForExistence(timeout: 12))
        finishTask.tap()

        let focusPrimary = app.buttons["Start focus"].firstMatch
        XCTAssertTrue(focusPrimary.waitForExistence(timeout: 12))
        focusPrimary.tap()

        let markComplete = app.buttons["Mark complete"].firstMatch
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))

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

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useHabits].tap()

        let firstTask = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 12))

        let customTaskButton = app.staticTexts["Create my own first task"].firstMatch
        let firstTaskScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(firstTaskScrollView.waitForExistence(timeout: 12))
        XCTAssertTrue(scrollToElement(customTaskButton, in: firstTaskScrollView, maxSwipes: 6))
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

    func testHabitStepAllowsSuggestedHabitThenContinuesToFirstTask() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        let projects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(projects.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))

        let addHabitButton = app.buttons["Add"].firstMatch
        XCTAssertTrue(addHabitButton.waitForExistence(timeout: 12))
        addHabitButton.tap()
        XCTAssertTrue(app.staticTexts["1 added"].waitForExistence(timeout: 12))

        let continueButton = app.buttons[AccessibilityIdentifiers.Onboarding.useHabits]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 12))
        continueButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 12))
    }

    func testCustomHabitComposerRoundTripReturnsToHabitStep() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        let projects = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects]
        XCTAssertTrue(projects.waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))

        let customHabitButton = app.staticTexts["Create my own habit"].firstMatch
        let habitsScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(habitsScrollView.waitForExistence(timeout: 12))
        XCTAssertTrue(scrollToElement(customHabitButton, in: habitsScrollView, maxSwipes: 6))
        customHabitButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["addHabit.view"].waitForExistence(timeout: 12))

        let titleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField]
        XCTAssertTrue(titleField.waitForExistence(timeout: 12))
        titleField.tap()
        titleField.typeText("Stretch for one minute")

        app.buttons["Add Habit"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["1 added"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.useHabits].exists)
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

        let startButton = app.buttons["Review matched setup"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        XCTAssertEqual(startButton.label, "Review matched setup")
        startButton.tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Your matched setup is ready for its first rhythm."].waitForExistence(timeout: 12))
    }

    func testEstablishedWorkspacePromptResumeRestoresHabitsContinuityCopy() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))

        let startButton = app.buttons["Review matched setup"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Your matched setup is ready for its first rhythm."].exists)

        app.terminate()
        app = relaunchPromptAppWithoutReset()

        let resumedHabits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(resumedHabits.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Your matched setup is ready for its first rhythm."].waitForExistence(timeout: 12))
    }

    func testEstablishedWorkspacePromptDismissalSuppressesRelaunch() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))

        let dismissButton = app.buttons["Not now"].firstMatch
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

private extension OnboardingPromptUITests {
    func relaunchPromptAppWithoutReset() -> XCUIApplication {
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"
        ]
        relaunchedApp.launch()
        return relaunchedApp
    }
}
