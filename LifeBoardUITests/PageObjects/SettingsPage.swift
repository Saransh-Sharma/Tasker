//
//  SettingsPage.swift
//  LifeBoardUITests
//
//  Page Object for Settings Screen
//

import XCTest

@MainActor
class SettingsPage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var navigationBar: XCUIElement {
        return app.navigationBars[AccessibilityIdentifiers.Settings.navigationBar]
    }

    var doneButton: XCUIElement {
        return navigationBar.buttons[AccessibilityIdentifiers.Settings.doneButton]
    }

    var lifeManagementRow: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Settings.lifeManagementRow]
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

    /// Leave Settings. It is pushed onto the root's stack, so it has a back
    /// button rather than a Done button; Done is kept for sheet presentations.
    @discardableResult
    func tapDone() -> HomePage {
        if doneButton.exists {
            doneButton.tap()
        } else if navigationBar.exists {
            navigationBar.buttons.element(boundBy: 0).tap()
        }
        return HomePage(app: app)
    }

    /// Open a Settings category from the hub (`settings.category.<route>`):
    /// the hub lists categories, and rows such as the calendar controls live
    /// inside "Calendar & Health".
    @discardableResult
    func openCategory(_ route: String, timeout: TimeInterval = 5) -> Bool {
        let category = app.descendants(matching: .any)["settings.category.\(route)"]
        guard category.exists || category.waitForExistence(timeout: timeout) else { return false }
        category.tap()
        return true
    }

    /// Back out of a Settings category to the hub. Rows such as Life
    /// Management sit inside a category, so Back from them lands on the
    /// category page first.
    @discardableResult
    func returnToHub(timeout: TimeInterval = 5) -> Bool {
        for _ in 0..<3 {
            if navigationBar.waitForExistence(timeout: 1) {
                return true
            }
            let back = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
            guard back.exists else { break }
            back.tap()
        }
        return navigationBar.waitForExistence(timeout: timeout)
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
        // Life Management lives in the Workspace section of the "Plan &
        // Organize" category; the hub lists categories, not the rows in them.
        if lifeManagementRow.waitForExistence(timeout: 1) == false {
            openCategory("planAndOrganize", timeout: 3)
        }
        if lifeManagementRow.waitForExistence(timeout: 3) {
            lifeManagementRow.tap()
        }
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
        return lifeManagementRow.exists
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
        let lifeManagementView = app.descendants(matching: .any)["settings.lifeManagement.view"]
        return lifeManagementView.waitForExistence(timeout: timeout)
    }
}
