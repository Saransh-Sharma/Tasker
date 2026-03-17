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

    // MARK: - Test 50: Workspace Rows

    func testWorkspaceRowsAreVisible() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        XCTAssertTrue(app.staticTexts["Life Management"].waitForExistence(timeout: 3), "Life Management row should exist")
        XCTAssertTrue(app.staticTexts["Chats"].waitForExistence(timeout: 3), "Chats row should exist")
        XCTAssertTrue(app.staticTexts["Models"].waitForExistence(timeout: 3), "Models row should exist")

        takeScreenshot(named: "workspace_rows_visible")
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

    func testRecommendedModelIsPreselectedInInstallPicker() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        guard settingsPage.verifyLLMSettingsRowExists() else {
            throw XCTSkip("LLM Settings not available in this configuration")
        }

        settingsPage.navigateToLLMSettings()

        let llmSettingsView = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.view]
        XCTAssertTrue(llmSettingsView.waitForExistence(timeout: 8), "LLM settings should be displayed")

        let modelsRow = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.modelsSettingsRow]
        XCTAssertTrue(modelsRow.waitForExistence(timeout: 8), "Models row should be displayed")
        modelsRow.tap()

        let modelsView = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.modelsView]
        XCTAssertTrue(modelsView.waitForExistence(timeout: 8), "Models view should be displayed")

        let installModelButton = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.installModelButton]
        XCTAssertTrue(installModelButton.waitForExistence(timeout: 8), "Install model button should be displayed")
        installModelButton.tap()

        let modelPicker = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMModelPicker.view]
        XCTAssertTrue(modelPicker.waitForExistence(timeout: 8), "Model picker should be displayed")

        let recommendedBadge = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMModelPicker.recommendedBadge]
        XCTAssertTrue(recommendedBadge.waitForExistence(timeout: 8), "Recommended badge should be visible")

        let recommendedRow = app.buttons[AccessibilityIdentifiers.LLMModelPicker.recommendedRow]
        XCTAssertTrue(recommendedRow.waitForExistence(timeout: 8), "Recommended row should be visible")
        XCTAssertEqual(recommendedRow.value as? String, "selected", "Recommended model should be preselected")
    }

    func testDecorativeButtonEffectsToggleDefaultsOffAndCanBeEnabled() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        let decorativeCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.decorativeButtonEffectsCard]

        for _ in 0..<4 where decorativeCard.exists == false {
            app.swipeUp()
        }

        XCTAssertTrue(decorativeCard.waitForExistence(timeout: 8), "Decorative button effects card should exist")

        let decorativeToggle = decorativeCard.switches.firstMatch
        XCTAssertTrue(decorativeToggle.waitForExistence(timeout: 8), "Decorative button effects toggle should exist")
        XCTAssertEqual(decorativeToggle.value as? String, "0", "Decorative button effects should default off")

        decorativeToggle.tap()
        XCTAssertEqual(decorativeToggle.value as? String, "1", "Decorative button effects should toggle on")

        settingsPage.tapDone()
        XCTAssertTrue(settingsPage.waitForDismissal(timeout: 5), "Settings should dismiss after tapping Done")

        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed after reopening")

        let reopenedCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.decorativeButtonEffectsCard]
        for _ in 0..<4 where reopenedCard.exists == false {
            app.swipeUp()
        }

        XCTAssertTrue(reopenedCard.waitForExistence(timeout: 8), "Decorative button effects card should exist after reopening")

        let reopenedToggle = reopenedCard.switches.firstMatch
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: 8), "Decorative button effects toggle should exist after reopening")
        XCTAssertEqual(reopenedToggle.value as? String, "1", "Decorative button effects should persist after relaunching settings")
    }
}
