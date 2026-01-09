//
//  NavigationTests.swift
//  To Do ListUITests
//
//  Secondary Tests: Navigation (5 tests)
//  Tests app navigation flows and screen transitions
//

import XCTest

class NavigationTests: BaseUITest {

    var homePage: HomePage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 41: Tab Navigation - Home

    func testTabNavigation_Home() throws {
        // GIVEN: App is launched
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User taps Home tab
        let homeTabButton = tabBarButton(AccessibilityIdentifiers.TabBar.home)

        if homeTabButton.exists {
            homeTabButton.tap()
            waitForAnimations(duration: 0.5)

            // THEN: Home screen should be active
            XCTAssertTrue(homeTabButton.isSelected, "Home tab should be selected")
        }

        takeScreenshot(named: "tab_navigation_home")
    }

    // MARK: - Test 42: Tab Navigation - Inbox

    func testTabNavigation_Inbox() throws {
        // GIVEN: App is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User taps Inbox tab
        let inboxTabButton = tabBarButton(AccessibilityIdentifiers.TabBar.inbox)

        if inboxTabButton.exists {
            inboxTabButton.tap()
            waitForAnimations(duration: 1.0)

            // THEN: Inbox screen should be displayed
            XCTAssertTrue(inboxTabButton.isSelected, "Inbox tab should be selected")

            // Verify inbox elements
            let inboxIndicator = app.otherElements[AccessibilityIdentifiers.Inbox.view]
            if !inboxIndicator.exists {
                // Fallback: check for navigation bar or list
                let navBar = app.navigationBars.firstMatch
                XCTAssertTrue(navBar.exists, "Inbox screen should have navigation elements")
            }
        }

        takeScreenshot(named: "tab_navigation_inbox")
    }

    // MARK: - Test 43: Tab Navigation - Weekly

    func testTabNavigation_Weekly() throws {
        // GIVEN: App is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User taps Weekly tab
        let weeklyTabButton = tabBarButton(AccessibilityIdentifiers.TabBar.weekly)

        if weeklyTabButton.exists {
            weeklyTabButton.tap()
            waitForAnimations(duration: 1.0)

            // THEN: Weekly view should be displayed
            XCTAssertTrue(weeklyTabButton.isSelected, "Weekly tab should be selected")

            // Verify weekly view elements
            let weeklyIndicator = app.otherElements[AccessibilityIdentifiers.Weekly.view]
            if !weeklyIndicator.exists {
                // Fallback: check for table view or navigation elements
                let tableView = app.tables.firstMatch
                XCTAssertTrue(tableView.exists, "Weekly view should have table")
            }
        }

        takeScreenshot(named: "tab_navigation_weekly")
    }

    // MARK: - Test 44: Modal Presentation - Add Task

    func testModalPresentation_AddTask() throws {
        // GIVEN: User is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User taps add task button
        let addTaskPage = homePage.tapAddTask()

        // THEN: Add task modal should be presented
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task screen should be presented")

        // Verify modal elements
        XCTAssertTrue(addTaskPage.titleField.exists, "Title field should exist")
        XCTAssertTrue(addTaskPage.saveButton.exists, "Save button should exist")
        XCTAssertTrue(addTaskPage.cancelButton.exists, "Cancel button should exist")

        takeScreenshot(named: "modal_presentation_add_task")

        // Clean up
        addTaskPage.tapCancel()
    }

    // MARK: - Test 45: Modal Dismissal - Add Task

    func testModalDismissal_AddTask() throws {
        // GIVEN: Add task modal is presented
        let addTaskPage = homePage.tapAddTask()
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task screen should be presented")

        // WHEN: User cancels
        addTaskPage.tapCancel()

        // THEN: Modal should be dismissed and user returns to home
        XCTAssertTrue(addTaskPage.waitForDismissal(timeout: 3), "Add task modal should be dismissed")
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home screen")

        takeScreenshot(named: "modal_dismissal_add_task")
    }

    // MARK: - Bonus: Navigation Stack - Settings → Projects → Back

    func testNavigationStack_SettingsProjectsBack() throws {
        // GIVEN: User is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User navigates through Settings → Projects
        var settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should appear")

        let projectPage = settingsPage.navigateToProjectManagement()
        XCTAssertTrue(projectPage.verifyIsDisplayed(), "Projects should appear")

        // Navigate back
        settingsPage = projectPage.tapBack()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Should return to settings")

        homePage = settingsPage.tapDone()
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home")

        // THEN: Navigation stack should work correctly
        takeScreenshot(named: "navigation_stack_complete")
    }

    // MARK: - Bonus: Rapid Tab Switching

    func testRapidTabSwitching() throws {
        // GIVEN: App is launched
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User rapidly switches between tabs
        let tabs = [
            AccessibilityIdentifiers.TabBar.home,
            AccessibilityIdentifiers.TabBar.inbox,
            AccessibilityIdentifiers.TabBar.weekly,
            AccessibilityIdentifiers.TabBar.home
        ]

        for tabName in tabs {
            let tabButton = tabBarButton(tabName)
            if tabButton.exists {
                tabButton.tap()
                waitForAnimations(duration: 0.3)
            }
        }

        // THEN: App should handle rapid switching without crashes
        // Verify we're back on home
        let homeTabButton = tabBarButton(AccessibilityIdentifiers.TabBar.home)
        XCTAssertTrue(homeTabButton.isSelected, "Should be on home tab")

        takeScreenshot(named: "rapid_tab_switching")
    }
}
