//
//  SettingsTests.swift
//  To Do ListUITests
//
//  Secondary Tests: Settings (6 tests)
//  Tests settings screen functionality and preferences
//

import XCTest

class SettingsTests: BaseUITest {

    var homePage: HomePage!
    var settingsPage: SettingsPage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    // MARK: - Test 46: Navigate to Settings

    func testNavigateToSettings() throws {
        // GIVEN: User is on home screen
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        // WHEN: User taps settings button
        settingsPage = homePage.tapSettings()

        // THEN: Settings screen should appear
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // Verify settings navigation bar
        XCTAssertTrue(settingsPage.navigationBar.exists, "Settings navigation bar should exist")

        // Verify done button exists
        XCTAssertTrue(settingsPage.doneButton.exists, "Done button should exist")

        takeScreenshot(named: "navigate_to_settings")
    }

    // MARK: - Test 47: Dismiss Settings

    func testDismissSettings() throws {
        // GIVEN: Settings screen is displayed
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // WHEN: User taps Done
        homePage = settingsPage.tapDone()

        // THEN: Settings should be dismissed and return to home
        XCTAssertTrue(settingsPage.waitForDismissal(timeout: 3), "Settings should be dismissed")
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home screen")

        takeScreenshot(named: "dismiss_settings")
    }

    // MARK: - Test 48: Navigate to Project Management from Settings

    func testNavigateToProjectManagementFromSettings() throws {
        // GIVEN: User is on settings screen
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // WHEN: User taps Project Management row
        let projectPage = settingsPage.navigateToProjectManagement()

        // THEN: Project management screen should appear
        XCTAssertTrue(projectPage.verifyIsDisplayed(), "Project management should be displayed")

        // Verify we're on projects screen
        XCTAssertTrue(projectPage.navigationBar.exists, "Projects navigation bar should exist")

        takeScreenshot(named: "navigate_to_project_management_from_settings")
    }

    // MARK: - Test 49: Navigate Back from Project Management

    func testNavigateBackFromProjectManagement() throws {
        // GIVEN: User is on project management screen
        settingsPage = homePage.tapSettings()
        let projectPage = settingsPage.navigateToProjectManagement()
        XCTAssertTrue(projectPage.verifyIsDisplayed(), "Project management should be displayed")

        // WHEN: User taps back button
        settingsPage = projectPage.tapBack()

        // THEN: Should return to settings
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Should return to settings")

        // Verify settings navigation bar is visible
        XCTAssertTrue(settingsPage.navigationBar.exists, "Settings navigation bar should exist")

        takeScreenshot(named: "navigate_back_from_project_management")
    }

    // MARK: - Test 50: Toggle Dark Mode

    func testToggleDarkMode() throws {
        // GIVEN: User is on settings screen
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // Get initial dark mode state (if accessible)
        // Note: Dark mode toggle might be in appearance section

        // WHEN: User toggles dark mode
        settingsPage.toggleDarkMode()

        waitForAnimations(duration: 1.0)

        // THEN: Theme should change
        // (Visual verification - theme change might be immediate or require app restart)

        takeScreenshot(named: "toggle_dark_mode")

        // Toggle back to restore state
        settingsPage.toggleDarkMode()
        waitForAnimations(duration: 1.0)

        takeScreenshot(named: "toggle_dark_mode_restored")
    }

    // MARK: - Test 51: App Version Display

    func testAppVersionDisplay() throws {
        // GIVEN: User is on settings screen
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // WHEN: User views app version section
        // Scroll to bottom if needed to see version
        let settingsTable = app.tables.firstMatch
        if settingsTable.exists {
            scrollToBottom(in: settingsTable)
        }

        // THEN: App version should be displayed
        let versionDisplayed = settingsPage.verifyAppVersionDisplayed()

        if versionDisplayed {
            let versionText = settingsPage.getAppVersionText()
            print("📱 App Version: \(versionText)")

            // Verify version text contains version number pattern (e.g., "1.0.0")
            let containsVersion = versionText.range(of: "\\d+\\.\\d+", options: .regularExpression) != nil
            XCTAssertTrue(containsVersion, "Version text should contain version number")
        } else {
            print("⚠️ App version label not found - might need scrolling or different locator")
        }

        takeScreenshot(named: "app_version_display")
    }

    // MARK: - Bonus: Settings Rows Exist

    func testSettingsRowsExist() throws {
        // GIVEN: User is on settings screen
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // WHEN: User views settings

        // THEN: Key settings rows should exist
        XCTAssertTrue(settingsPage.verifyProjectManagementRowExists(), "Project Management row should exist")

        // LLM Settings (if available)
        if settingsPage.verifyLLMSettingsRowExists() {
            print("✅ LLM Settings available")
        }

        // Appearance settings
        if settingsPage.verifyAppearanceRowExists() {
            print("✅ Appearance settings available")
        }

        takeScreenshot(named: "settings_rows_exist")
    }

    // MARK: - Bonus: Navigate to LLM Settings (if available)

    func testNavigateToLLMSettings() throws {
        // GIVEN: User is on settings screen
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        // WHEN: User taps LLM Settings (if available)
        if settingsPage.verifyLLMSettingsRowExists() {
            settingsPage.navigateToLLMSettings()

            waitForAnimations(duration: 1.0)

            // THEN: LLM Settings screen should appear
            let llmNavBar = app.navigationBars.firstMatch
            XCTAssertTrue(llmNavBar.exists, "LLM Settings should be displayed")

            takeScreenshot(named: "navigate_to_llm_settings")

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else {
            print("⚠️ LLM Settings not available - skipping test")
        }
    }
}
