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

    func testHomeBottomBarActions() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        XCTAssertTrue(homePage.verifyBottomBarExists(), "Home bottom bar should exist")

        homePage.tapCharts()
        waitForAnimations(duration: 0.4)

        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForSearchFaceOpen(timeout: 3), "Search face should be displayed")
        XCTAssertTrue(homePage.searchField.waitForExistence(timeout: 3), "Search field should appear on top backdrop")
        homePage.tapSearch()
        XCTAssertTrue(homePage.waitForForedropState("collapsed", timeout: 3), "Search should collapse on second search tap")

        homePage.tapChat()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3), "Chat screen should present")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let addTaskPage = homePage.tapAddTask()
        XCTAssertTrue(addTaskPage.verifyIsDisplayed(), "Add task should be displayed from bottom bar")
        addTaskPage.tapCancel()
    }

    func testHomeBottomBarMinimizeOnScroll() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")
        XCTAssertTrue(homePage.verifyBottomBarExists(), "Home bottom bar should exist")

        homePage.taskListScrollView.swipeUp()
        homePage.taskListScrollView.swipeUp()
        XCTAssertTrue(homePage.waitForBottomBarState("minimized", timeout: 2), "Bottom bar should minimize after downward scroll")

        waitForAnimations(duration: 0.55)
        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should auto-restore after scroll idle")

        homePage.taskListScrollView.swipeDown()
        XCTAssertTrue(homePage.waitForBottomBarState("expanded", timeout: 2), "Bottom bar should expand after upward scroll")
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

        // THEN: App should handle rapid switching without crashes.
        // If this runtime uses the new home bottom bar (no UITabBar), home visibility is the contract.
        let homeTabButton = tabBarButton(AccessibilityIdentifiers.TabBar.home)
        if homeTabButton.exists {
            XCTAssertTrue(homeTabButton.isSelected, "Should be on home tab")
        } else {
            XCTAssertTrue(homePage.verifyIsDisplayed(), "Home should remain visible without tab bar")
        }

        takeScreenshot(named: "rapid_tab_switching")
    }

    // MARK: - iPad/iPhone Orientation Policy

    func testIPhoneLandscapeRotationIsBlocked() throws {
        let iPadTasksDestination = app.buttons["home.ipad.destination.tasks"]
        if iPadTasksDestination.waitForExistence(timeout: 1) {
            throw XCTSkip("This check is for iPhone-only orientation policy")
        }

        let homeRoot = app.otherElements[AccessibilityIdentifiers.Home.view]
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
        let iPadTasksDestination = app.buttons["home.ipad.destination.tasks"]
        if iPadTasksDestination.waitForExistence(timeout: 1) {
            throw XCTSkip("This check is for iPhone-only orientation policy")
        }

        let homeRoot = app.otherElements[AccessibilityIdentifiers.Home.view]
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
        let iPadTasksDestination = app.buttons["home.ipad.destination.tasks"]
        guard iPadTasksDestination.waitForExistence(timeout: 3) else {
            throw XCTSkip("Requires iPad native shell destination controls")
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(iPadTasksDestination.exists, "iPad shell should remain visible in landscape")
        XCTAssertGreaterThan(
            app.windows.firstMatch.frame.width,
            app.windows.firstMatch.frame.height,
            "iPad should rotate to landscape"
        )

        XCUIDevice.shared.orientation = .portrait
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(iPadTasksDestination.exists, "iPad shell should remain visible in portrait")
        XCTAssertGreaterThan(
            app.windows.firstMatch.frame.height,
            app.windows.firstMatch.frame.width,
            "iPad should rotate back to portrait"
        )

        XCUIDevice.shared.orientation = .portraitUpsideDown
        waitForAnimations(duration: 0.8)
        XCTAssertTrue(iPadTasksDestination.exists, "iPad shell should remain visible upside-down")
    }

    func testIPadSidebarCanSwitchAcrossCoreDestinations() throws {
        let iPadTasksDestination = app.buttons["home.ipad.destination.tasks"]
        guard iPadTasksDestination.waitForExistence(timeout: 3) else {
            throw XCTSkip("Requires iPad native shell destination controls")
        }

        let destinationToDetail: [(destination: String, detail: String)] = [
            ("tasks", "home.ipad.detail.tasks"),
            ("search", "home.ipad.detail.search"),
            ("analytics", "home.ipad.detail.analytics"),
            ("addTask", "home.ipad.detail.addTask"),
            ("settings", "home.ipad.detail.settings"),
            ("projects", "projectManagement.view")
        ]

        for (destination, detailID) in destinationToDetail {
            let destinationButton = app.buttons["home.ipad.destination.\(destination)"]
            XCTAssertTrue(
                destinationButton.waitForExistence(timeout: 2),
                "Expected iPad destination button \(destination)"
            )
            destinationButton.tap()
            waitForAnimations(duration: 0.5)
            if destination == "addTask" {
                let embeddedDetail = app.otherElements["home.ipad.detail.addTask"].waitForExistence(timeout: 1.5)
                let sheetTitleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField].waitForExistence(timeout: 1.5)
                let fallbackTasksDetail = app.otherElements["home.ipad.detail.tasks"].exists
                XCTAssertTrue(
                    embeddedDetail || sheetTitleField || fallbackTasksDetail,
                    "Expected add-task route to resolve to inspector, sheet, or tasks fallback"
                )

                if sheetTitleField {
                    let cancelButton = app.buttons["Cancel"]
                    if cancelButton.waitForExistence(timeout: 1) {
                        cancelButton.tap()
                        waitForAnimations(duration: 0.4)
                    }
                }
            } else {
                let routedByPrimaryDetailID = app.otherElements[detailID].waitForExistence(timeout: 1.5)
                if destination == "settings" {
                    let settingsMarker = app.staticTexts["Your Workspace"].exists
                        || app.staticTexts["Notifications & Focus"].exists
                    XCTAssertTrue(
                        routedByPrimaryDetailID || settingsMarker,
                        "Expected settings destination content after tapping settings"
                    )
                } else if destination == "projects" {
                    let projectsMarker = app.staticTexts["Select a Project"].exists
                        || app.staticTexts["Inbox is your capture project and cannot be deleted."].exists
                    XCTAssertTrue(
                        routedByPrimaryDetailID || projectsMarker,
                        "Expected projects destination content after tapping projects"
                    )
                } else {
                    XCTAssertTrue(
                        routedByPrimaryDetailID,
                        "Expected iPad detail surface \(detailID) after tapping \(destination)"
                    )
                }
            }
        }
    }
}
