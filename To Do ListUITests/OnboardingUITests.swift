import XCTest

final class OnboardingFreshLaunchUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    func testFreshLaunchShowsWelcomeOnboarding() {
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 10))
    }

    func testSkippingOnboardingFromWelcomeSuppressesRelaunch() {
        let welcome = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome]
        XCTAssertTrue(welcome.waitForExistence(timeout: 10))

        let skipButton = app.buttons["Skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 10))
        skipButton.tap()

        let home = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
        XCTAssertTrue(home.waitForExistence(timeout: 10))

        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS"
        ]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.flow].waitForExistence(timeout: 2))
    }

    func testFullGuidedFlowCompletingSecondTaskStillShowsFinish() {
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 10))

        let continueWelcome = app.buttons["Start guided setup"]
        XCTAssertTrue(continueWelcome.waitForExistence(timeout: 10))
        continueWelcome.tap()

        let continueLifeAreas = app.buttons["Use these life areas"]
        XCTAssertTrue(continueLifeAreas.waitForExistence(timeout: 10))
        continueLifeAreas.tap()

        let continueProjects = app.buttons["Use these projects"]
        XCTAssertTrue(continueProjects.waitForExistence(timeout: 10))
        continueProjects.tap()

        let firstTemplate = app.buttons["onboarding.taskTemplate.task-health-move-1"]
        XCTAssertTrue(firstTemplate.waitForExistence(timeout: 10))
        firstTemplate.tap()
        XCTAssertTrue(app.buttons["addTask.createButton"].waitForExistence(timeout: 10))
        app.buttons["addTask.createButton"].tap()

        let secondTemplate = app.buttons["onboarding.taskTemplate.task-health-move-2"]
        XCTAssertTrue(secondTemplate.waitForExistence(timeout: 10))
        secondTemplate.tap()
        XCTAssertTrue(app.buttons["addTask.createButton"].waitForExistence(timeout: 10))
        app.buttons["addTask.createButton"].tap()

        let continueTasks = app.buttons["Go to Home and complete either one"]
        XCTAssertTrue(continueTasks.waitForExistence(timeout: 10))
        continueTasks.tap()

        let homePage = HomePage(app: app)
        XCTAssertTrue(homePage.view.waitForExistence(timeout: 10))
        homePage.completeTask(containingTitle: "Lay out workout clothes")

        let finish = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.finish]
        XCTAssertTrue(finish.waitForExistence(timeout: 20))
    }
}

final class OnboardingRestartUITests: BaseUITest {
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_OPEN_SETTINGS"] }

    func testRestartOnboardingFromSettings() {
        let restartButton = app.buttons["Restart onboarding"]
        for _ in 0..<8 where restartButton.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(restartButton.waitForExistence(timeout: 10))
        restartButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 10))
    }
}

final class OnboardingPromptUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"] }

    func testEstablishedWorkspaceShowsPromptAndNotNowSuppressesRelaunch() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        XCTAssertTrue(prompt.waitForExistence(timeout: 12))

        app.buttons["Not now"].tap()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 10))

        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments = [
            "-UI_TESTING",
            "-DISABLE_ANIMATIONS",
            "-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"
        ]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunchedApp.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt].waitForExistence(timeout: 3))
    }

    func testEstablishedWorkspacePromptCanStartFullOnboarding() {
        let startButton = app.buttons["Start guided setup"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 12))
        startButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 10))
    }
}

final class OnboardingLaunchQueueUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] { ["-TASKER_TEST_ROUTE:daily_summary:morning"] }

    func testFreshLaunchShowsOnboardingAfterBlockingModalDismisses() {
        let dailySummary = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.dailySummaryModal]
        XCTAssertTrue(dailySummary.waitForExistence(timeout: 10))

        let dismissCTA = app.buttons["Start Today"]
        XCTAssertTrue(dismissCTA.waitForExistence(timeout: 10))
        dismissCTA.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.welcome].waitForExistence(timeout: 12))
    }
}
