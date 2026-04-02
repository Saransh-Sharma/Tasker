import XCTest
import CoreGraphics

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    func testFreshLaunchShowsOutcomeFirstWelcome() {
        let introOverlay = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroOverlay]
        XCTAssertTrue(introOverlay.waitForExistence(timeout: 4))

        let introCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroTitleCard]
        XCTAssertTrue(introCard.waitForExistence(timeout: 6))
        XCTAssertLessThan(introCard.frame.midY, app.windows.firstMatch.frame.height * 0.35)

        assertCinematicBackdrop(in: app, grain: "25%")

        let introCTA = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
        XCTAssertTrue(introCTA.waitForExistence(timeout: 12))
        XCTAssertEqual(introCTA.label, "Get your days back under control")

        let setupDuringIntro = app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended]
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeReady].exists)
        XCTAssertFalse(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
        XCTAssertFalse(setupDuringIntro.exists && setupDuringIntro.isHittable)

        introCTA.tap()

        let welcomeReady = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeReady]
        XCTAssertTrue(welcomeReady.waitForExistence(timeout: 8))
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 12))
        XCTAssertFalse(introOverlay.exists)

        let heroVideo = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeHeroVideo]
        XCTAssertTrue(heroVideo.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        let title = app.staticTexts["Get your day back under control."]
        XCTAssertTrue(title.exists)
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].label, "Set up Tasker")
        XCTAssertEqual(app.buttons[AccessibilityIdentifiers.Onboarding.customize].label, "Customize it")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.skipButton].exists)
        XCTAssertFalse(app.buttons["Getting started"].exists)
    }

    func testWelcomeIntroDoesNotReplayWhenNavigatingBackToWelcome() {
        let introOverlay = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroOverlay]
        XCTAssertTrue(introOverlay.waitForExistence(timeout: 4))
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))

        let back = app.buttons["Back"]
        XCTAssertTrue(back.waitForExistence(timeout: 12))
        back.tap()

        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 4))
        XCTAssertFalse(introOverlay.exists)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].exists)
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testWelcomePrimaryCTARespondsToEdgeTap() {
        advanceThroughWelcomeIntro()

        let setup = app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended]
        XCTAssertTrue(setup.waitForExistence(timeout: 12))
        tapInsideEdge(of: setup, normalizedX: 0.92)

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))
    }

    func testBlockerSelectionShowsInlineHelperOnly() {
        advanceThroughWelcomeIntro()
        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        let keepingTrack = app.buttons["Keeping track"]
        XCTAssertTrue(keepingTrack.waitForExistence(timeout: 12))
        keepingTrack.tap()

        XCTAssertTrue(app.staticTexts["We’ll bring the next step back when it matters."].waitForExistence(timeout: 12))
        XCTAssertEqual(keepingTrack.value as? String, "Selected")
    }

    func testBlockerSkipForNowContinuesToAreas() {
        advanceThroughWelcomeIntro()
        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))

        app.buttons[AccessibilityIdentifiers.Onboarding.skipBlocker].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testBlockerPrimaryCTARespondsToEdgeTap() {
        advanceThroughWelcomeIntro()
        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))

        let continueButton = app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 12))
        tapInsideEdge(of: continueButton, normalizedX: 0.08)

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testLifeAreasShowCoreAreasFirstThenRevealOptionalAreas() {
        advanceThroughWelcomeIntro()
        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))

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

    func testSkipSeedsStarterTaskAndRunsFocusRoomFlow() {
        advanceThroughWelcomeIntro()

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
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        let firstTask = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask]
        XCTAssertTrue(firstTask.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        let chooseButton = app.buttons["Choose"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 12))
        chooseButton.tap()

        let continueButton = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 12))
        continueButton.tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
        app.buttons[AccessibilityIdentifiers.Onboarding.useHabits].tap()

        let focusRoom = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom]
        XCTAssertTrue(focusRoom.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        let focusPrimary = app.buttons["Start focus"].firstMatch
        XCTAssertTrue(focusPrimary.waitForExistence(timeout: 12))
        focusPrimary.tap()

        let markComplete = app.buttons["Mark complete"].firstMatch
        XCTAssertTrue(markComplete.waitForExistence(timeout: 12))
        markComplete.tap()

        let success = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.success]
        XCTAssertTrue(success.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        let goHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        XCTAssertTrue(goHome.waitForExistence(timeout: 12))
        goHome.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 12))
    }

    func testOnboardingRestoresBlockerStepAfterRelaunch() {
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker].waitForExistence(timeout: 12))

        app.terminate()
        app = relaunchAppWithoutReset()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].exists)
    }

    func testOnboardingRestoresProjectsStepAfterRelaunch() {
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

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
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.customize].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.skipBlocker].tap()

        let lifeAreas = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas]
        XCTAssertTrue(lifeAreas.waitForExistence(timeout: 12))

        let lifeAdminArea = app.descendants(matching: .any)["onboarding.lifeArea.life-admin"]
        XCTAssertTrue(lifeAdminArea.waitForExistence(timeout: 12))
        lifeAdminArea.tap()

        let useAreas = app.buttons[AccessibilityIdentifiers.Onboarding.useAreas]
        XCTAssertTrue(useAreas.waitForExistence(timeout: 12))
        useAreas.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
    }

    func testCustomTaskComposerRoundTripReturnsToFirstTaskThenHabitsAndFocusRoom() {
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

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

        let continueButton = app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 12))
        continueButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useHabits].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom].waitForExistence(timeout: 12))
    }

    func testHabitStepAllowsSuggestedHabitThenContinuesToFocusRoom() {
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 12))
        app.buttons["Choose"].firstMatch.tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask].tap()

        let habits = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.habits]
        XCTAssertTrue(habits.waitForExistence(timeout: 12))

        let addHabitButton = app.buttons["Add"].firstMatch
        XCTAssertTrue(addHabitButton.waitForExistence(timeout: 12))
        addHabitButton.tap()
        XCTAssertTrue(app.staticTexts["1 added"].waitForExistence(timeout: 12))

        let finishButton = app.buttons[AccessibilityIdentifiers.Onboarding.useHabits]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 12))
        finishButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.focusRoom].waitForExistence(timeout: 12))
    }

    func testCustomHabitComposerRoundTripReturnsToHabitStep() {
        advanceThroughWelcomeIntro()

        app.buttons[AccessibilityIdentifiers.Onboarding.startRecommended].tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.continueFromBlocker].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.lifeAreas].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useAreas].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.projects].waitForExistence(timeout: 12))
        app.buttons[AccessibilityIdentifiers.Onboarding.useProjects].tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.firstTask].waitForExistence(timeout: 12))
        app.buttons["Choose"].firstMatch.tap()
        app.buttons[AccessibilityIdentifiers.Onboarding.goFinishTask].tap()

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

        advanceToSteadyWelcome(in: app)
    }
}

private extension OnboardingFreshLaunchUITests {
    func tapInsideEdge(of element: XCUIElement, normalizedX: CGFloat) {
        XCTAssertTrue(waitForElementToBeHittable(element, timeout: 12))
        element.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: 0.5)).tap()
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
        XCTAssertEqual(startButton.label, "Review matched setup")
        startButton.tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["What usually gets in your way?"].waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")
    }

    func testEstablishedWorkspacePromptResumeRestoresBlockerContinuity() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))
        assertCinematicBackdropIsAbsent(in: app)

        let startButton = app.buttons["Review matched setup"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        let blocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(blocker.waitForExistence(timeout: 12))
        assertCinematicBackdrop(in: app, grain: "100%")

        app.terminate()
        app = relaunchPromptAppWithoutReset()

        let resumedBlocker = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.blocker]
        XCTAssertTrue(resumedBlocker.waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["What usually gets in your way?"].waitForExistence(timeout: 12))
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

        advanceToSteadyWelcome(in: app)
    }
}

private extension OnboardingFreshLaunchUITests {
    func advanceThroughWelcomeIntro() {
        advanceToSteadyWelcome(in: app)
    }

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

private func advanceToSteadyWelcome(in app: XCUIApplication) {
    let introOverlay = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroOverlay]
    XCTAssertTrue(introOverlay.waitForExistence(timeout: 4))

    let introCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeIntroTitleCard]
    XCTAssertTrue(introCard.waitForExistence(timeout: 8))
    assertCinematicBackdrop(in: app, grain: "25%")

    let introCTA = app.buttons[AccessibilityIdentifiers.Onboarding.welcomeIntroContinue]
    XCTAssertTrue(introCTA.waitForExistence(timeout: 12))
    XCTAssertFalse(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeReady].exists)

    introCTA.tap()

    let welcomeReady = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcomeReady]
    XCTAssertTrue(welcomeReady.waitForExistence(timeout: 8))

    let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
    XCTAssertTrue(welcome.waitForExistence(timeout: 12))
    XCTAssertFalse(introOverlay.exists)
    assertCinematicBackdrop(in: app, grain: "100%")
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
