//
//  ProjectManagementPage.swift
//  To Do ListUITests
//
//  Page Object for Project Management Screen
//

import XCTest

class ProjectManagementPage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.ProjectManagement.view]
    }

    var navigationBar: XCUIElement {
        return app.navigationBars[AccessibilityIdentifiers.ProjectManagement.navigationBar]
    }

    var backButton: XCUIElement {
        return navigationBar.buttons.element(boundBy: 0)
    }

    var addProjectButton: XCUIElement {
        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.ProjectManagement.addProjectButton]

        // Fallback: top-right navigation button
        if !button.exists {
            button = navigationBar.buttons.element(boundBy: navigationBar.buttons.count - 1)
        }

        // Fallback: find by label
        if !button.exists {
            button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] '+'")).firstMatch
        }

        return button
    }

    var projectsList: XCUIElement {
        return app.tables[AccessibilityIdentifiers.ProjectManagement.projectsList]
    }

    var emptyStateLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.ProjectManagement.emptyStateLabel]
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Tap back button
    @discardableResult
    func tapBack() -> SettingsPage {
        backButton.tap()
        return SettingsPage(app: app)
    }

    /// Tap add project button
    @discardableResult
    func tapAddProject() -> NewProjectPage {
        addProjectButton.tap()
        return NewProjectPage(app: app)
    }

    /// Get project cell at index
    func projectCell(at index: Int) -> XCUIElement {
        return projectsList.cells.element(boundBy: index)
    }

    /// Get project name at index
    func projectName(at index: Int) -> String {
        let identifier = AccessibilityIdentifiers.ProjectManagement.projectName(index: index)
        let nameElement = app.staticTexts[identifier]

        if nameElement.exists {
            return nameElement.label
        }

        // Fallback: get first static text in cell
        let cell = projectCell(at: index)
        return cell.staticTexts.element(boundBy: 0).label
    }

    /// Tap project at index
    func tapProject(at index: Int) {
        projectCell(at: index).tap()
    }

    /// Tap project with name
    func tapProject(named name: String) {
        let projectCell = projectsList.cells.staticTexts[name]
        if projectCell.exists {
            projectCell.tap()
        }
    }

    /// Swipe to delete project at index
    func deleteProject(at index: Int) {
        let cell = projectCell(at: index)
        cell.swipeLeft()

        // Tap delete button
        let deleteButton = cell.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }
    }

    /// Delete project by name
    func deleteProject(named name: String) {
        let cell = projectsList.cells.staticTexts[name].firstMatch
        if cell.exists {
            cell.swipeLeft()

            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
            }
        }
    }

    // MARK: - Verifications

    /// Verify project management screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        return navigationBar.waitForExistence(timeout: timeout)
    }

    /// Verify project exists with name
    func verifyProjectExists(named name: String) -> Bool {
        let projectText = projectsList.staticTexts[name]
        return projectText.exists
    }

    /// Verify project does not exist
    func verifyProjectDoesNotExist(named name: String) -> Bool {
        let projectText = projectsList.staticTexts[name]
        return !projectText.exists
    }

    /// Get project count
    func getProjectCount() -> Int {
        return projectsList.cells.count
    }

    /// Verify project count
    func verifyProjectCount(_ expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        let actualCount = getProjectCount()
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) projects, found \(actualCount)",
            file: file,
            line: line
        )
    }

    /// Verify Inbox project exists
    func verifyInboxExists() -> Bool {
        return verifyProjectExists(named: AccessibilityIdentifiers.ProjectConstants.inboxProjectName)
    }

    /// Verify empty state is shown
    func verifyEmptyState() -> Bool {
        // Check if empty state label exists OR if project count is 0
        return emptyStateLabel.exists || getProjectCount() == 0
    }

    /// Verify add project button is visible
    func verifyAddProjectButtonVisible() -> Bool {
        return addProjectButton.exists
    }

    // MARK: - Wait Helpers

    /// Wait for project to appear
    @discardableResult
    func waitForProject(named name: String, timeout: TimeInterval = 5) -> Bool {
        let projectText = projectsList.staticTexts[name]
        return projectText.waitForExistence(timeout: timeout)
    }

    /// Wait for project count to match expected
    @discardableResult
    func waitForProjectCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            return self.getProjectCount() == expectedCount
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }

    /// Wait for empty state
    @discardableResult
    func waitForEmptyState(timeout: TimeInterval = 5) -> Bool {
        if emptyStateLabel.exists {
            return true
        }

        return waitForProjectCount(0, timeout: timeout)
    }
}
