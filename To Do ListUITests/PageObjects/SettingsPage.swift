//
//  SettingsPage.swift
//  To Do ListUITests
//
//  Page Object for Settings Screen
//

import XCTest

class SettingsPage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Settings.view]
    }

    var navigationBar: XCUIElement {
        return app.navigationBars[AccessibilityIdentifiers.Settings.navigationBar]
    }

    var doneButton: XCUIElement {
        return navigationBar.buttons[AccessibilityIdentifiers.Settings.doneButton]
    }

    var projectManagementRow: XCUIElement {
        return app.tables.cells.staticTexts[AccessibilityIdentifiers.Settings.projectManagementRow]
    }

    var llmSettingsRow: XCUIElement {
        return app.tables.cells.staticTexts[AccessibilityIdentifiers.Settings.llmSettingsRow]
    }

    var appearanceRow: XCUIElement {
        return app.tables.cells.staticTexts[AccessibilityIdentifiers.Settings.appearanceRow]
    }

    var darkModeToggle: XCUIElement {
        return app.switches[AccessibilityIdentifiers.Settings.darkModeToggle]
    }

    var appVersionLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Settings.appVersionLabel]
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Tap done button to dismiss settings
    @discardableResult
    func tapDone() -> HomePage {
        doneButton.tap()
        return HomePage(app: app)
    }

    /// Navigate to Project Management
    @discardableResult
    func navigateToProjectManagement() -> ProjectManagementPage {
        projectManagementRow.tap()
        return ProjectManagementPage(app: app)
    }

    /// Navigate to LLM Settings
    func navigateToLLMSettings() {
        llmSettingsRow.tap()
    }

    /// Navigate to Appearance settings
    func navigateToAppearance() {
        appearanceRow.tap()
    }

    /// Toggle dark mode
    func toggleDarkMode() {
        if darkModeToggle.exists {
            darkModeToggle.tap()
        } else {
            // Fallback: find dark mode in appearance row
            appearanceRow.tap()

            // Look for dark mode toggle in the appearance screen
            let darkModeSwitch = app.switches.matching(NSPredicate(format: "label CONTAINS[c] 'dark' OR label CONTAINS[c] 'theme'")).firstMatch
            if darkModeSwitch.exists {
                darkModeSwitch.tap()
            }

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// Enable dark mode
    func enableDarkMode() {
        if darkModeToggle.exists {
            let isOn = darkModeToggle.value as? String == "1"
            if !isOn {
                darkModeToggle.tap()
            }
        }
    }

    /// Disable dark mode
    func disableDarkMode() {
        if darkModeToggle.exists {
            let isOn = darkModeToggle.value as? String == "1"
            if isOn {
                darkModeToggle.tap()
            }
        }
    }

    /// Tap app version to show version info
    func tapAppVersion() {
        appVersionLabel.tap()
    }

    // MARK: - Verifications

    /// Verify settings screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        return navigationBar.waitForExistence(timeout: timeout)
    }

    /// Verify project management row exists
    func verifyProjectManagementRowExists() -> Bool {
        return projectManagementRow.exists
    }

    /// Verify LLM settings row exists
    func verifyLLMSettingsRowExists() -> Bool {
        return llmSettingsRow.exists
    }

    /// Verify appearance row exists
    func verifyAppearanceRowExists() -> Bool {
        return appearanceRow.exists
    }

    /// Verify dark mode is enabled
    func verifyDarkModeEnabled() -> Bool {
        if darkModeToggle.exists {
            return darkModeToggle.value as? String == "1"
        }
        return false
    }

    /// Verify dark mode is disabled
    func verifyDarkModeDisabled() -> Bool {
        if darkModeToggle.exists {
            return darkModeToggle.value as? String != "1"
        }
        return false
    }

    /// Verify app version is displayed
    func verifyAppVersionDisplayed() -> Bool {
        return appVersionLabel.exists
    }

    /// Get app version text
    func getAppVersionText() -> String {
        return appVersionLabel.label
    }

    // MARK: - Wait Helpers

    /// Wait for settings to be dismissed
    @discardableResult
    func waitForDismissal(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: navigationBar)

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for project management screen to appear
    @discardableResult
    func waitForProjectManagement(timeout: TimeInterval = 5) -> Bool {
        let projectsNavBar = app.navigationBars[AccessibilityIdentifiers.ProjectManagement.navigationBar]
        return projectsNavBar.waitForExistence(timeout: timeout)
    }
}
