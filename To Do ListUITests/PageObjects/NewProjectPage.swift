//
//  NewProjectPage.swift
//  To Do ListUITests
//
//  Page Object for New Project Screen
//

import XCTest

class NewProjectPage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.NewProject.view]
    }

    var nameField: XCUIElement {
        // Try accessibility identifier first
        var field = app.textFields[AccessibilityIdentifiers.NewProject.nameField]

        // Fallback: find by placeholder
        if !field.exists {
            field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'name' OR label CONTAINS[c] 'name'")).firstMatch
        }

        // Last fallback: first text field
        if !field.exists {
            field = app.textFields.firstMatch
        }

        return field
    }

    var descriptionField: XCUIElement {
        // Try accessibility identifier first
        var field = app.textViews[AccessibilityIdentifiers.NewProject.descriptionField]

        // Fallback: find by placeholder
        if !field.exists {
            field = app.textViews.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR label CONTAINS[c] 'description'")).firstMatch
        }

        // Try text fields if text view not found
        if !field.exists {
            field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'description'")).firstMatch
        }

        return field
    }

    var colorPicker: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.NewProject.colorPicker]
    }

    var iconPicker: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.NewProject.iconPicker]
    }

    var saveButton: XCUIElement {
        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.NewProject.saveButton]

        // Fallback: find by label
        if !button.exists {
            button = app.buttons["Save"]
        }

        // Last fallback: right bar button
        if !button.exists {
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                button = navBar.buttons.element(boundBy: navBar.buttons.count - 1)
            }
        }

        return button
    }

    var cancelButton: XCUIElement {
        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.NewProject.cancelButton]

        // Fallback: find by label
        if !button.exists {
            button = app.buttons["Cancel"]
        }

        // Last fallback: first bar button
        if !button.exists {
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                button = navBar.buttons.element(boundBy: 0)
            }
        }

        return button
    }

    var nameError: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.NewProject.nameError]
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Enter project name
    func enterName(_ name: String) {
        nameField.tap()
        nameField.typeText(name)
    }

    /// Clear and enter new name
    func clearAndEnterName(_ name: String) {
        nameField.tap()

        // Select all and delete
        if let currentValue = nameField.value as? String, !currentValue.isEmpty {
            nameField.doubleTap()

            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            nameField.typeText(deleteString)
        }

        nameField.typeText(name)
    }

    /// Enter project description
    func enterDescription(_ description: String) {
        descriptionField.tap()
        descriptionField.typeText(description)
    }

    /// Select color
    func selectColor(_ color: String) {
        if colorPicker.exists {
            // Try to find color button
            let colorButton = app.buttons[color]
            if colorButton.exists {
                colorButton.tap()
            }
        }
    }

    /// Select icon
    func selectIcon(_ icon: String) {
        if iconPicker.exists {
            // Try to find icon button
            let iconButton = app.buttons[icon]
            if iconButton.exists {
                iconButton.tap()
            }
        }
    }

    /// Tap save button
    @discardableResult
    func tapSave() -> ProjectManagementPage {
        saveButton.tap()
        return ProjectManagementPage(app: app)
    }

    /// Tap cancel button
    @discardableResult
    func tapCancel() -> ProjectManagementPage {
        cancelButton.tap()
        return ProjectManagementPage(app: app)
    }

    /// Dismiss keyboard
    func dismissKeyboard() {
        app.toolbars.buttons["Done"].tap()
    }

    // MARK: - Complex Actions (Fluent API)

    /// Create project with all details
    @discardableResult
    func createProject(
        name: String,
        description: String? = nil,
        color: String? = nil,
        icon: String? = nil
    ) -> ProjectManagementPage {
        // Enter name
        enterName(name)

        // Enter description if provided
        if let description = description {
            enterDescription(description)
        }

        // Select color if provided
        if let color = color {
            selectColor(color)
        }

        // Select icon if provided
        if let icon = icon {
            selectIcon(icon)
        }

        // Dismiss keyboard before saving
        if app.keyboards.firstMatch.exists {
            dismissKeyboard()
        }

        // Save project
        return tapSave()
    }

    /// Create project from TestDataFactory.ProjectData
    @discardableResult
    func createProject(from projectData: TestDataFactory.ProjectData) -> ProjectManagementPage {
        return createProject(
            name: projectData.name,
            description: projectData.description,
            color: projectData.color,
            icon: projectData.icon
        )
    }

    // MARK: - Verifications

    /// Verify new project screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        // Check for name field or navigation bar
        let navBar = app.navigationBars.firstMatch
        let nameFieldExists = nameField.waitForExistence(timeout: timeout)
        let navBarExists = navBar.waitForExistence(timeout: timeout)

        return nameFieldExists || navBarExists
    }

    /// Verify validation error is shown
    func verifyValidationError(forField field: String, expectedMessage: String? = nil) -> Bool {
        var errorElement: XCUIElement

        switch field.lowercased() {
        case "name":
            errorElement = nameError
        default:
            errorElement = app.staticTexts[field]
        }

        // Check if error exists
        if !errorElement.exists {
            // Try to find any error message
            let errorPredicate = NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'required' OR label CONTAINS[c] 'invalid'")
            let errors = app.staticTexts.matching(errorPredicate)
            if errors.count > 0 {
                return true
            }
            return false
        }

        // If expected message provided, verify it matches
        if let expectedMessage = expectedMessage {
            return errorElement.label.contains(expectedMessage)
        }

        return true
    }

    /// Verify save button is enabled
    func verifySaveButtonEnabled() -> Bool {
        return saveButton.isEnabled
    }

    /// Verify save button is disabled
    func verifySaveButtonDisabled() -> Bool {
        return !saveButton.isEnabled
    }

    // MARK: - Wait Helpers

    /// Wait for screen to be dismissed
    @discardableResult
    func waitForDismissal(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nameField)

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
