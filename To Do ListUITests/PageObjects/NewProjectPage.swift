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

    private var unifiedComposer: XCUIElement {
        app.otherElements["settings.lifeManagement.projectComposer"]
    }

    private var legacyComposer: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.NewProject.view]
    }

    // MARK: - Elements

    var view: XCUIElement {
        if unifiedComposer.exists {
            return unifiedComposer
        }
        return legacyComposer
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
            field = app.textViews.matching(
                NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR label CONTAINS[c] 'description' OR placeholderValue CONTAINS[c] 'project for'")
            ).firstMatch
        }

        // Try text fields if text view not found
        if !field.exists {
            field = app.textFields.matching(
                NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR placeholderValue CONTAINS[c] 'project for'")
            ).firstMatch
        }

        if !field.exists {
            let textFields = app.textFields.allElementsBoundByIndex
            if textFields.count > 1 {
                field = textFields[1]
            }
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
        let saveLabelPredicate = NSPredicate(
            format: "label ==[c] 'Create' OR label ==[c] 'Save' OR label ==[c] 'Add Project' OR label ==[c] 'Save Project' OR identifier == %@",
            AccessibilityIdentifiers.NewProject.saveButton
        )

        let newProjectAlert = app.alerts["New Project"]
        if newProjectAlert.exists {
            let alertButtons = newProjectAlert.buttons.matching(saveLabelPredicate)
            if alertButtons.count > 0 {
                return alertButtons.firstMatch
            }
        }

        let newProjectSheet = app.sheets["New Project"]
        if newProjectSheet.exists {
            let sheetButtons = newProjectSheet.buttons.matching(saveLabelPredicate)
            if sheetButtons.count > 0 {
                return sheetButtons.firstMatch
            }
        }

        let identifiedButton = app.buttons[AccessibilityIdentifiers.NewProject.saveButton]
        if identifiedButton.exists {
            return identifiedButton
        }

        if app.buttons["Create"].exists {
            return app.buttons["Create"]
        }

        if app.buttons["Save"].exists {
            return app.buttons["Save"]
        }

        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let navButtons = navBar.buttons
            if navButtons.count > 0 {
                return navButtons.element(boundBy: navButtons.count - 1)
            }
        }

        return app.buttons.firstMatch
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
        if let button = resolveSaveButton(timeout: 2) {
            if button.isHittable {
                button.tap()
            } else {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            XCTFail("Save button should exist before tapping")
        }
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
        guard app.keyboards.firstMatch.exists else { return }

        // Prefer explicit toolbar done buttons when present.
        let doneCandidates: [XCUIElement] = [
            app.toolbars.buttons["Done"],
            app.keyboards.buttons["Done"],
            app.navigationBars.buttons["Done"]
        ]
        for candidate in doneCandidates where candidate.exists {
            candidate.tap()
            if app.keyboards.firstMatch.exists == false {
                return
            }
        }

        // Final fallback: submit newline only from the currently focused control.
        let focusedElement = app.descendants(matching: .any).matching(
            NSPredicate(format: "hasKeyboardFocus == true")
        ).firstMatch
        if focusedElement.exists {
            focusedElement.typeText("\n")
        }
    }

    // MARK: - Complex Actions

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

        // Only dismiss keyboard when save button is not hittable.
        if app.keyboards.firstMatch.exists && saveButton.isHittable == false {
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
        if unifiedComposer.waitForExistence(timeout: timeout) {
            return true
        }
        if legacyComposer.waitForExistence(timeout: timeout) {
            return true
        }
        return nameField.waitForExistence(timeout: timeout)
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
        let predicate = NSPredicate { _, _ in
            self.unifiedComposer.exists == false
                && self.legacyComposer.exists == false
                && self.nameField.exists == false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func resolveSaveButton(timeout: TimeInterval) -> XCUIElement? {
        var saveCandidates: [XCUIElement] = [
            app.buttons[AccessibilityIdentifiers.NewProject.saveButton],
            app.buttons["Add Project"],
            app.buttons["Save Project"],
            app.buttons["Create"],
            app.buttons["Save"]
        ]
        let navButtons = app.navigationBars.firstMatch.buttons
        if navButtons.count > 0 {
            saveCandidates.append(navButtons.element(boundBy: navButtons.count - 1))
        }
        if let existing = saveCandidates.first(where: \.exists) {
            return existing
        }
        for candidate in saveCandidates where candidate.waitForExistence(timeout: timeout) {
            return candidate
        }
        return nil
    }
}
