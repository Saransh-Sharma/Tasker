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

    private var unifiedView: XCUIElement {
        app.otherElements["settings.lifeManagement.view"]
    }

    private var legacyView: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.ProjectManagement.view]
    }

    private var unifiedNavigationBar: XCUIElement {
        app.navigationBars["Life Management"]
    }

    private var legacyNavigationBar: XCUIElement {
        app.navigationBars[AccessibilityIdentifiers.ProjectManagement.navigationBar]
    }

    // MARK: - Elements

    var view: XCUIElement {
        if unifiedView.exists {
            return unifiedView
        }
        return legacyView
    }

    var navigationBar: XCUIElement {
        if unifiedNavigationBar.exists {
            return unifiedNavigationBar
        }
        return legacyNavigationBar
    }

    var backButton: XCUIElement {
        return navigationBar.buttons.element(boundBy: 0)
    }

    var addProjectButton: XCUIElement {
        let unifiedAddMenu = app.buttons["settings.lifeManagement.addMenu"]
        if unifiedAddMenu.exists {
            return unifiedAddMenu
        }

        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.ProjectManagement.addProjectButton]

        // Fallback: top-right navigation button
        if !button.exists {
            let navButtons = navigationBar.buttons
            if navButtons.count > 0 {
                button = navButtons.element(boundBy: navButtons.count - 1)
            }
        }

        // Fallback: find by label
        if !button.exists {
            button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'add' OR label CONTAINS[c] '+'")).firstMatch
        }

        return button
    }

    var addAreaButton: XCUIElement {
        let unifiedButton = app.buttons["settings.lifeManagement.addAreaButton"]
        if unifiedButton.exists {
            return unifiedButton
        }
        let cardScopedButton = app.otherElements["settings.lifeManagement.addAreaCard"]
            .buttons
            .matching(NSPredicate(format: "label ==[c] 'Add Area'"))
            .firstMatch
        if cardScopedButton.exists {
            return cardScopedButton
        }
        return app.buttons["Add Area"]
    }

    var areaComposer: XCUIElement {
        app.descendants(matching: .any)["settings.lifeManagement.areaComposer"]
    }

    var projectsList: XCUIElement {
        let identifiedTable = app.tables[AccessibilityIdentifiers.ProjectManagement.projectsList]
        if identifiedTable.exists {
            return identifiedTable
        }
        let unifiedScrollView = view.scrollViews.firstMatch
        if unifiedScrollView.exists {
            return unifiedScrollView
        }
        return app.tables.firstMatch
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
        let addProjectAction = app.buttons["Add Project"]
        let unifiedAddMenu = app.buttons["settings.lifeManagement.addMenu"]
        if unifiedAddMenu.waitForExistence(timeout: 2) {
            unifiedAddMenu.tap()
            if addProjectAction.waitForExistence(timeout: 2) {
                addProjectAction.tap()
            }
            return NewProjectPage(app: app)
        }

        let button = addProjectButton
        if button.waitForExistence(timeout: 2) {
            button.tap()
        }

        if addProjectAction.exists {
            addProjectAction.tap()
        }
        return NewProjectPage(app: app)
    }

    /// Tap in-content add area button
    @discardableResult
    func tapAddArea() -> Bool {
        let button = addAreaButton
        if button.waitForExistence(timeout: 5) == false {
            return false
        }
        button.tap()
        return areaComposer.waitForExistence(timeout: 5)
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
        let namedProject = view.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
        if namedProject.exists {
            namedProject.tap()
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
        if unifiedView.waitForExistence(timeout: timeout) {
            return true
        }
        if legacyView.waitForExistence(timeout: timeout) {
            return true
        }
        if unifiedNavigationBar.waitForExistence(timeout: timeout) {
            return true
        }
        return legacyNavigationBar.waitForExistence(timeout: timeout)
    }

    /// Verify project exists with name
    func verifyProjectExists(named name: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)

        if view.descendants(matching: .any).matching(predicate).firstMatch.exists {
            return true
        }

        if projectsList.staticTexts[name].exists {
            return true
        }

        if projectsList.descendants(matching: .staticText).matching(predicate).firstMatch.exists {
            return true
        }

        return app.staticTexts.matching(predicate).firstMatch.exists
    }

    /// Verify project does not exist
    func verifyProjectDoesNotExist(named name: String) -> Bool {
        return !verifyProjectExists(named: name)
    }

    /// Get project count
    func getProjectCount() -> Int {
        let unifiedProjectNodes = view.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "settings.lifeManagement.node.project.")
        )
        if unifiedProjectNodes.count > 0 {
            return unifiedProjectNodes.count
        }

        if projectsList.exists {
            return projectsList.cells.count
        }
        return app.tables.firstMatch.cells.count
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

    /// Verify in-content add area button is visible
    func verifyAddAreaButtonVisible() -> Bool {
        return addAreaButton.exists
    }

    // MARK: - Wait Helpers

    /// Wait for project to appear
    @discardableResult
    func waitForProject(named name: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)

        let unifiedMatch = view.descendants(matching: .any).matching(predicate).firstMatch
        if unifiedMatch.waitForExistence(timeout: timeout) {
            return true
        }

        if projectsList.staticTexts[name].waitForExistence(timeout: timeout) {
            return true
        }

        let listMatch = projectsList.descendants(matching: .staticText).matching(predicate).firstMatch
        if listMatch.waitForExistence(timeout: timeout) {
            return true
        }

        let globalMatch = app.staticTexts.matching(predicate).firstMatch
        return globalMatch.waitForExistence(timeout: timeout)
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
