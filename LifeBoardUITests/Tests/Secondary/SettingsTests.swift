import XCTest

class SettingsTests: BaseUITest {

    var homePage: HomePage!
    var settingsPage: SettingsPage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
    }

    func testNavigateToSettings() throws {
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Home screen should be displayed")

        settingsPage = homePage.tapSettings()

        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")
        XCTAssertTrue(settingsPage.navigationBar.exists, "Settings navigation bar should exist")
        XCTAssertTrue(settingsPage.doneButton.exists, "Done button should exist")
        XCTAssertTrue(settingsPage.heroCard.waitForExistence(timeout: 3), "Hero card should exist")

        takeScreenshot(named: "navigate_to_settings")
    }

    func testDismissSettings() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        homePage = settingsPage.tapDone()

        XCTAssertTrue(settingsPage.waitForDismissal(timeout: 3), "Settings should be dismissed")
        XCTAssertTrue(homePage.verifyIsDisplayed(), "Should return to home screen")

        takeScreenshot(named: "dismiss_settings")
    }

    func testPrimarySettingsRowsAreVisible() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        XCTAssertTrue(settingsPage.verifyLifeManagementRowExists(), "Life Management row should exist")
        XCTAssertFalse(settingsPage.verifyProjectManagementRowExists(), "Separate Projects row should not exist")
        XCTAssertTrue(settingsPage.verifyAIAssistantRowExists(), "AI Assistant row should exist")
        XCTAssertTrue(app.staticTexts["Notifications & Focus"].waitForExistence(timeout: 3), "Notifications section should exist")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Settings.onboardingRestartButton].waitForExistence(timeout: 3), "Guided Setup row should exist")

        takeScreenshot(named: "settings_primary_rows_visible")
    }

    func testChiefOfStaffPersonaCanBeChangedFromSettings() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        let personaButton = app.buttons[AccessibilityIdentifiers.Settings.chiefOfStaffPersona("sato")]
        XCTAssertTrue(scrollUntilExists(personaButton, direction: .up, maxSwipes: 8), "Sato persona should be available in Settings")
        personaButton.tap()

        let card = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.chiefOfStaffCard]
        XCTAssertTrue(scrollUntilExists(card, direction: .down, maxSwipes: 8), "Chief of Staff card should be visible")
        XCTAssertTrue(card.label.contains("Sato"), "Selected Chief of Staff card should reflect Sato. Actual label: \(card.label)")

        takeScreenshot(named: "settings_chief_of_staff_sato")
    }

    private enum ScrollDirection {
        case up
        case down
    }

    private func scrollUntilExists(
        _ element: XCUIElement,
        direction: ScrollDirection,
        maxSwipes: Int,
        timeout: TimeInterval = 1
    ) -> Bool {
        for _ in 0...maxSwipes {
            if element.waitForExistence(timeout: timeout) {
                return true
            }
            switch direction {
            case .up:
                app.swipeUp()
            case .down:
                app.swipeDown()
            }
        }
        return false
    }

    func testNavigateToLifeManagementFromSettings() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        settingsPage.navigateToLifeManagement()

        let lifeManagementView = app.descendants(matching: .any)["settings.lifeManagement.view"]
        XCTAssertTrue(lifeManagementView.waitForExistence(timeout: 5), "Life Management screen should be displayed")

        takeScreenshot(named: "navigate_to_life_management_from_settings")
    }

    func testNavigateToAIAssistantSettings() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")
        XCTAssertTrue(settingsPage.verifyAIAssistantRowExists(), "AI Assistant row should exist")

        settingsPage.navigateToAIAssistant()

        let llmSettingsView = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.view]
        XCTAssertTrue(llmSettingsView.waitForExistence(timeout: 8), "AI Assistant settings should be displayed")

        let chatsRow = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.chatsSettingsRow]
        let modelsRow = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.modelsSettingsRow]
        let memoryRow = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.memorySettingsRow]
        let privacyRow = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.privacySettingsRow]

        XCTAssertTrue(chatsRow.waitForExistence(timeout: 8), "Chat Behavior row should exist")
        XCTAssertTrue(modelsRow.exists, "Models row should exist")
        XCTAssertTrue(memoryRow.exists, "Personal Memory row should exist")
        XCTAssertTrue(privacyRow.exists, "Data & Privacy row should exist")

        takeScreenshot(named: "navigate_to_ai_assistant_settings")
    }

    func testSettingsDoesNotShowSeparateProjectsRow() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")
        XCTAssertFalse(settingsPage.verifyProjectManagementRowExists(), "Projects should no longer be exposed as a separate settings row")
    }

    func testRecommendedModelIsPreselectedInInstallPicker() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")
        XCTAssertTrue(settingsPage.verifyAIAssistantRowExists(), "AI Assistant row should exist")

        settingsPage.navigateToAIAssistant()

        let llmSettingsView = app.descendants(matching: .any)[AccessibilityIdentifiers.LLMSettings.view]
        XCTAssertTrue(llmSettingsView.waitForExistence(timeout: 8), "AI settings should be displayed")

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
        XCTAssertEqual(reopenedToggle.value as? String, "1", "Decorative button effects should persist after reopening settings")
    }

    func testHomeBackgroundNoiseSliderDefaultsAndPersists() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        let noiseCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.homeBackgroundNoiseCard]

        for _ in 0..<4 where noiseCard.exists == false {
            app.swipeUp()
        }

        XCTAssertTrue(noiseCard.waitForExistence(timeout: 8), "Home background noise card should exist")

        let noiseValue = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.homeBackgroundNoiseValue]
        XCTAssertTrue(noiseValue.waitForExistence(timeout: 8), "Home background noise value should exist")
        XCTAssertEqual(noiseValue.label, "20%", "Home background noise should default to 20%")

        let noiseSlider = app.sliders[AccessibilityIdentifiers.Settings.homeBackgroundNoiseSlider]
        XCTAssertTrue(noiseSlider.waitForExistence(timeout: 8), "Home background noise slider should exist")

        noiseSlider.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertEqual(noiseValue.label, "50%", "Home background noise value should update after moving the slider")

        settingsPage.tapDone()
        XCTAssertTrue(settingsPage.waitForDismissal(timeout: 5), "Settings should dismiss after tapping Done")

        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed after reopening")

        let reopenedNoiseCard = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.homeBackgroundNoiseCard]
        for _ in 0..<4 where reopenedNoiseCard.exists == false {
            app.swipeUp()
        }

        XCTAssertTrue(reopenedNoiseCard.waitForExistence(timeout: 8), "Home background noise card should exist after reopening")

        let reopenedNoiseValue = app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.homeBackgroundNoiseValue]
        XCTAssertTrue(reopenedNoiseValue.waitForExistence(timeout: 8), "Home background noise value should exist after reopening")
        XCTAssertEqual(reopenedNoiseValue.label, "50%", "Home background noise value should persist after reopening settings")
    }

    func testAppVersionDisplay() throws {
        settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(), "Settings should be displayed")

        for _ in 0..<5 where settingsPage.verifyAppVersionDisplayed() == false {
            app.swipeUp()
        }

        XCTAssertTrue(settingsPage.verifyAppVersionDisplayed(), "App version row should exist")

        let versionText = settingsPage.getAppVersionText()
        let containsVersion = versionText.range(of: "\\d+\\.\\d+", options: .regularExpression) != nil
        XCTAssertTrue(containsVersion, "Version text should contain version number")
        XCTAssertTrue(app.staticTexts["Made with care by Saransh"].exists, "Footer should show the single-line author credit")

        takeScreenshot(named: "app_version_display")
    }
}
