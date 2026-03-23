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

    var lifeManagementRow: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.lifeManagementRow]
    }

    var projectsRow: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.projectsRow]
    }

    var aiAssistantRow: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.aiAssistantRow]
    }

    var heroCard: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.heroCard]
    }

    var appVersionRow: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.appVersionRow]
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

    /// Navigate to Life Management
    func navigateToLifeManagement() {
        lifeManagementRow.tap()
    }

    /// Navigate to AI Assistant settings
    func navigateToAIAssistant() {
        aiAssistantRow.tap()
    }

    /// Backward-compatible alias for older tests.
    @discardableResult
    func navigateToProjectManagement() -> ProjectManagementPage {
        projectsRow.tap()
        return ProjectManagementPage(app: app)
    }

    /// Backward-compatible alias for older tests.
    func navigateToLLMSettings() {
        navigateToAIAssistant()
    }

    /// Tap app version to show version info
    func tapAppVersion() {
        appVersionRow.tap()
    }

    // MARK: - Verifications

    /// Verify settings screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        return navigationBar.waitForExistence(timeout: timeout)
    }

    /// Verify life management row exists
    func verifyLifeManagementRowExists() -> Bool {
        return lifeManagementRow.exists
    }

    /// Verify AI assistant row exists
    func verifyAIAssistantRowExists() -> Bool {
        return aiAssistantRow.exists
    }

    /// Backward-compatible alias for older tests.
    func verifyProjectManagementRowExists() -> Bool {
        return projectsRow.exists
    }

    /// Backward-compatible alias for older tests.
    func verifyLLMSettingsRowExists() -> Bool {
        return verifyAIAssistantRowExists()
    }

    /// Verify app version is displayed
    func verifyAppVersionDisplayed() -> Bool {
        return appVersionRow.exists
    }

    /// Get app version text
    func getAppVersionText() -> String {
        return appVersionRow.label
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

    /// Wait for life management screen to appear
    @discardableResult
    func waitForLifeManagement(timeout: TimeInterval = 5) -> Bool {
        let lifeManagementView = app.descendants(matching: .any)["settings.lifeManagement.view"]
        return lifeManagementView.waitForExistence(timeout: timeout)
    }

    /// Backward-compatible alias for older tests.
    @discardableResult
    func waitForProjectManagement(timeout: TimeInterval = 5) -> Bool {
        let projectManagementView = app.descendants(matching: .any)[AccessibilityIdentifiers.ProjectManagement.view]
        return projectManagementView.waitForExistence(timeout: timeout)
    }
}
