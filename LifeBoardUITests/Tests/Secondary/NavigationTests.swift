//
//  NavigationTests.swift
//  LifeBoardUITests
//
//  Secondary Tests: Navigation
//  Tests app navigation flows and screen transitions
//

import XCTest

class NavigationTests: BaseUITest {

    var homePage: HomePage!

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
    }

    // MARK: - Root Navigation
    //
    // The Foundation shell has five roots (Home, Plan, Track, Insights, Eva),
    // reached from the dock on iPhone and the root switcher on iPad and Mac.
    // Inbox and Week are Plan lenses, not tabs.

    func testTabNavigation_Home() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        XCTAssertTrue(homePage.openRoot("plan"), "Plan should open from the root chrome")
        XCTAssertTrue(homePage.openRoot("home"), "Home should open from the root chrome")
        XCTAssertTrue(homePage.waitForRootSelection(homePage.homeButton), "Home should read as the selected root")

        takeScreenshot(named: "tab_navigation_home")
    }

    func testTabNavigation_Inbox() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        XCTAssertTrue(homePage.openRoot("plan"), "Plan should open from the root chrome")
        let inboxLens = app.buttons[AccessibilityIdentifiers.Plan.lens("Inbox")]
        XCTAssertTrue(inboxLens.waitForExistence(timeout: 8), "Plan should offer its Inbox lens")
        inboxLens.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Plan.inbox].waitForExistence(timeout: 10),
            "The Inbox lens should show the inbox"
        )

        takeScreenshot(named: "tab_navigation_inbox")
    }

    func testTabNavigation_Weekly() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        XCTAssertTrue(homePage.openRoot("plan"), "Plan should open from the root chrome")
        let weekLens = app.buttons[AccessibilityIdentifiers.Plan.lens("Week")]
        XCTAssertTrue(weekLens.waitForExistence(timeout: 8), "Plan should offer its Week lens")
        weekLens.tap()

        let compactWeek = app.descendants(matching: .any)[AccessibilityIdentifiers.Plan.weekCompactList]
        let boardWeek = app.descendants(matching: .any)[AccessibilityIdentifiers.Plan.weekSevenDayBoard]
        let weekShown = NSPredicate { _, _ in compactWeek.exists || boardWeek.exists }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: weekShown, object: nil)], timeout: 10),
            .completed,
            "The Week lens should show the week list or the seven-day board"
        )

        takeScreenshot(named: "tab_navigation_weekly")
    }

    // MARK: - Modal Presentation - Add Task

    func testModalPresentation_AddTask() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        let addTaskPage = homePage.tapAddTask()

        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task screen should be presented")
        XCTAssertTrue(addTaskPage.titleField.exists, "Title field should exist")
        XCTAssertTrue(addTaskPage.createButton.exists, "Create button should exist")
        XCTAssertTrue(addTaskPage.cancelButton.exists, "Cancel button should exist")

        takeScreenshot(named: "modal_presentation_add_task")

        addTaskPage.tapCancel()
    }

    // MARK: - Modal Dismissal - Add Task

    func testModalDismissal_AddTask() throws {
        let addTaskPage = homePage.tapAddTask()
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task screen should be presented")

        addTaskPage.tapCancel()

        XCTAssertTrue(addTaskPage.waitForDismissal(timeout: 3), "Add task modal should be dismissed")
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home screen")

        takeScreenshot(named: "modal_dismissal_add_task")
    }

    func testHomeBottomBarInsightsAction() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        XCTAssertTrue(homePage.verifyBottomBarExists(), "Root chrome should exist")

        XCTAssertTrue(homePage.openInsights(), "Insights should open from the root chrome")
        XCTAssertTrue(homePage.insightsRoot.exists, "Insights root should be displayed")
    }

    func testHomeAddTaskActionPresentsModal() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        let addTaskPage = homePage.tapAddTask()
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task should be displayed from Home's tasks card")
        addTaskPage.tapCancel()
    }

    // MARK: - Bonus: Navigation Stack - Settings → Life Management → Back

    func testNavigationStack_SettingsProjectsBack() throws {
        // GIVEN: User is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User navigates through Settings → Life Management
        var settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should appear")

        let projectPage = settingsPage.navigateToProjectManagement()
        XCTAssertTrue(projectPage.verifyIsDisplayed(), "Life Management should appear")

        // Navigate back
        settingsPage = projectPage.tapBack()
        XCTAssertTrue(settingsPage.returnToHub(), "Should return to settings")

        homePage = settingsPage.tapDone()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home")

        // THEN: Navigation stack should work correctly
        takeScreenshot(named: "navigation_stack_complete")
    }

    // MARK: - Rapid Root Switching

    func testRapidTabSwitching() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        for root in ["plan", "track", "insights", "eva", "home"] {
            let button = homePage.rootButton(root)
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Expected a root button for \(root)")
            button.tap()
            waitForAnimations(duration: 0.3)
        }

        XCTAssertTrue(homePage.verifyIsDisplayed(), "Rapid switching should land back on Home")
        XCTAssertTrue(homePage.waitForRootSelection(homePage.homeButton), "Home should read as selected")

        takeScreenshot(named: "rapid_tab_switching")
    }

    // MARK: - iPad/iPhone Orientation Policy
    //
    // These waited on `home.ipad.destination.*`, identifiers only the never-used
    // `SunriseiPadSplitShellView` emitted, so on iPad the iPad tests always
    // skipped and the iPhone-only tests ran against an iPad. The live
    // regular-width chrome is the top root switcher.

    private var rootSwitcher: XCUIElement {
        app.descendants(matching: .any)["foundation.expanded.rootSwitcher"]
    }

    func testIPhoneLandscapeRotationIsBlocked() throws {
        if rootSwitcher.waitForExistence(timeout: 1) {
            throw XCTSkip("This check is for iPhone-only orientation policy")
        }

        let homeRoot = homePage.view
        XCTAssertTrue(homeRoot.waitForExistence(timeout: 5), "Home should be visible")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForAnimations(duration: 0.8)

        let frame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            frame.height,
            frame.width,
            "iPhone should stay portrait-oriented when landscape is requested"
        )
        XCTAssertTrue(homeRoot.exists, "Home should remain visible after blocked rotation")

        XCUIDevice.shared.orientation = .portrait
    }

    func testIPhoneUpsideDownPortraitIsSupported() throws {
        if rootSwitcher.waitForExistence(timeout: 1) {
            throw XCTSkip("This check is for iPhone-only orientation policy")
        }

        let homeRoot = homePage.view
        XCTAssertTrue(homeRoot.waitForExistence(timeout: 5), "Home should be visible")

        XCUIDevice.shared.orientation = .portraitUpsideDown
        waitForAnimations(duration: 0.8)

        let frame = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            frame.height,
            frame.width,
            "iPhone should remain in portrait family in upside-down mode"
        )
        XCTAssertTrue(homeRoot.exists, "Home should remain visible in upside-down portrait")

        XCUIDevice.shared.orientation = .portrait
    }

    func testIPadSupportsAllOrientations() throws {
        guard app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Requires iPad window class")
        }
        XCTAssertTrue(rootSwitcher.waitForExistence(timeout: 5), "iPad should show the root switcher")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(rootSwitcher.exists, "Root switcher should remain visible in landscape")
        XCTAssertGreaterThan(
            app.windows.firstMatch.frame.width,
            app.windows.firstMatch.frame.height,
            "iPad should rotate to landscape"
        )

        XCUIDevice.shared.orientation = .portrait
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(rootSwitcher.exists, "Root switcher should remain visible in portrait")
        XCTAssertGreaterThan(
            app.windows.firstMatch.frame.height,
            app.windows.firstMatch.frame.width,
            "iPad should rotate back to portrait"
        )

        XCUIDevice.shared.orientation = .portraitUpsideDown
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(rootSwitcher.exists, "Root switcher should remain visible upside-down")
        XCUIDevice.shared.orientation = .portrait
    }

    func testIPadRootSwitcherReachesEveryRoot() throws {
        guard app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Requires iPad window class")
        }
        XCTAssertTrue(rootSwitcher.waitForExistence(timeout: 5), "iPad should show the root switcher")

        for root in ["plan", "track", "insights", "eva", "home"] {
            let button = app.buttons["foundation.expanded.destination.\(root)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Expected switcher button for \(root)")
            button.tap()
            waitForAnimations(duration: 0.5)
            XCTAssertTrue(
                app.descendants(matching: .any)["\(root).header"].waitForExistence(timeout: 5),
                "Expected the \(root) root after choosing it in the switcher"
            )
            XCTAssertTrue(button.isSelected, "The chosen root should read as selected")
        }
    }
}
