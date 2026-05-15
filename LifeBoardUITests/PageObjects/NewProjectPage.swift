//
//  NewProjectPage.swift
//  LifeBoardUITests
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

    // MARK: - Elements

    var view: XCUIElement {
        unifiedComposer
    }

    var nameField: XCUIElement {
        var field = view.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'name' OR label CONTAINS[c] 'name'")).firstMatch

        if !field.exists {
            field = view.textFields.firstMatch
        }

        if !field.exists {
            field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'name' OR label CONTAINS[c] 'name'")).firstMatch
        }

        return field
    }

    var descriptionField: XCUIElement {
        var field = view.textViews.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR label CONTAINS[c] 'description' OR placeholderValue CONTAINS[c] 'project for'")
        ).firstMatch

        if !field.exists {
            field = view.textFields.matching(
                NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR placeholderValue CONTAINS[c] 'project for'")
            ).firstMatch
        }

        if !field.exists {
            let textFields = view.textFields.allElementsBoundByIndex
            if textFields.count > 1 {
                field = textFields[1]
            }
        }

        return field
    }

    var colorPicker: XCUIElement {
        return view.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Color'")).firstMatch
    }

    var iconPicker: XCUIElement {
        return view.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Icon'")).firstMatch
    }

    var saveButton: XCUIElement {
        let saveLabelPredicate = NSPredicate(
            format: "label ==[c] 'Create' OR label ==[c] 'Save' OR label ==[c] 'Add Project' OR label ==[c] 'Save Project'"
        )

        let composerButton = view.buttons.matching(saveLabelPredicate).firstMatch
        if composerButton.exists {
            return composerButton
        }

        if app.buttons["Add Project"].exists {
            return app.buttons["Add Project"]
        }

        if app.buttons["Save Project"].exists {
            return app.buttons["Save Project"]
        }

        if app.buttons["Create"].exists {
            return app.buttons["Create"]
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
        var button = view.buttons["Cancel"]
        if !button.exists {
            button = app.buttons["Cancel"]
        }

        if !button.exists {
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                button = navBar.buttons.element(boundBy: 0)
            }
        }

        return button
    }

    var nameError: XCUIElement {
        return view.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'name' AND (label CONTAINS[c] 'required' OR label CONTAINS[c] 'enter')")
        ).firstMatch
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
                && self.nameField.exists == false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    private func resolveSaveButton(timeout: TimeInterval) -> XCUIElement? {
        let saveCandidates: [XCUIElement] = [
            view.buttons["Add Project"],
            view.buttons["Save Project"],
            view.buttons["Create"],
            view.buttons["Save"],
            app.buttons["Add Project"],
            app.buttons["Save Project"],
            app.buttons["Create"],
            app.buttons["Save"]
        ]
        if let existing = saveCandidates.first(where: \.exists) {
            return existing
        }
        for candidate in saveCandidates where candidate.waitForExistence(timeout: timeout) {
            return candidate
        }
        let navButtons = app.navigationBars.firstMatch.buttons
        guard navButtons.count > 0 else { return nil }
        let trailingNavButton = navButtons.element(boundBy: navButtons.count - 1)
        guard trailingNavButton.waitForExistence(timeout: timeout) else { return nil }
        return trailingNavButton
    }
}
