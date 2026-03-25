//
//  AddTaskPage.swift
//  To Do ListUITests
//
//  Page Object for Add Task Screen
//

import XCTest

class AddTaskPage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.AddTask.view]
    }

    var titleField: XCUIElement {
        // Try accessibility identifier first
        var field = app.textFields[AccessibilityIdentifiers.AddTask.titleField]

        // Fallback: find by placeholder or label
        if !field.exists {
            field = app.textFields.matching(
                NSPredicate(
                    format: "placeholderValue CONTAINS[c] 'title' OR label CONTAINS[c] 'title' OR label CONTAINS[c] 'task name' OR placeholderValue CONTAINS[c] 'what do you need to do'"
                )
            ).firstMatch
        }

        // Last fallback: prefer a non-description text field.
        if !field.exists {
            field = app.textFields.matching(
                NSPredicate(format: "identifier != %@", AccessibilityIdentifiers.AddTask.descriptionField)
            ).firstMatch
        }

        if !field.exists {
            field = app.textFields.firstMatch
        }

        return field
    }

    var modePicker: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.AddTask.modePicker]
    }

    var taskModeButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.AddTask.modeTask]
    }

    var habitModeButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.AddTask.modeHabit]
    }

    var descriptionField: XCUIElement {
        // Try accessibility identifier first
        var field = app.textViews[AccessibilityIdentifiers.AddTask.descriptionField]

        // Fallback: find by placeholder or label
        if !field.exists {
            field = app.textViews.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR label CONTAINS[c] 'description'")).firstMatch
        }

        // Try text fields if text view not found
        if !field.exists {
            field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'description' OR label CONTAINS[c] 'description'")).firstMatch
        }

        return field
    }

    var prioritySegmentedControl: XCUIElement {
        return app.segmentedControls[AccessibilityIdentifiers.AddTask.prioritySegmentedControl]
    }

    var dueDateButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.dueDateButton]
    }

    var dueDatePicker: XCUIElement {
        return app.datePickers[AccessibilityIdentifiers.AddTask.dueDatePicker]
    }

    var taskTypeSelector: XCUIElement {
        return app.segmentedControls[AccessibilityIdentifiers.AddTask.taskTypeSelector]
    }

    var morningButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.morningButton]
    }

    var eveningButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.eveningButton]
    }

    var upcomingButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.upcomingButton]
    }

    var reminderToggle: XCUIElement {
        return app.switches[AccessibilityIdentifiers.AddTask.reminderToggle]
    }

    var reminderTimePicker: XCUIElement {
        return app.datePickers[AccessibilityIdentifiers.AddTask.reminderTimePicker]
    }

    var saveButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.saveButton]
    }

    var cancelButton: XCUIElement {
        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.AddTask.cancelButton]

        // Fallback: find by label
        if !button.exists {
            button = app.buttons["Cancel"]
        }

        // Last fallback: first bar button
        if !button.exists {
            let navBar = app.navigationBars.firstMatch
            if navBar.exists, navBar.buttons.count > 0 {
                button = navBar.buttons.element(boundBy: 0)
            }
        }

        return button
    }

    // Validation error labels
    var titleError: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.AddTask.titleError]
    }

    var descriptionError: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.AddTask.descriptionError]
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Enter task title
    func enterTitle(_ title: String) {
        let primaryTitleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField]
        if primaryTitleField.waitForExistence(timeout: 8) {
            primaryTitleField.tap()
            primaryTitleField.typeText(title)
            return
        }

        let titleContainer = app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.titleField]
        if titleContainer.exists && titleContainer.isHittable {
            titleContainer.tap()
            if let focusedField = focusedTextField(), focusedField.exists {
                focusedField.typeText(title)
                return
            }
        }

        let namedFallbackField = app.textFields.matching(
            NSPredicate(
                format: "identifier != %@ AND (label CONTAINS[c] 'task name' OR placeholderValue CONTAINS[c] 'what do you need to do')",
                AccessibilityIdentifiers.AddTask.descriptionField
            )
        ).firstMatch
        if namedFallbackField.exists {
            namedFallbackField.tap()
            namedFallbackField.typeText(title)
            return
        }

        let descriptionFallbackField = app.textFields[AccessibilityIdentifiers.AddTask.descriptionField]
        if descriptionFallbackField.waitForExistence(timeout: 2) {
            descriptionFallbackField.tap()
            descriptionFallbackField.typeText(title)
            return
        }

        if let focusedField = focusedTextField(), focusedField.exists {
            focusedField.typeText(title)
            return
        }

        XCTFail("Add Task title field should exist")
    }

    func switchToHabitMode() {
        let button = habitModeButton
        if button.waitForExistence(timeout: 3) {
            button.tap()
        }
    }

    /// Clear and enter new title
    func clearAndEnterTitle(_ title: String) {
        titleField.tap()

        // Select all and delete
        if let currentValue = titleField.value as? String, !currentValue.isEmpty {
            titleField.doubleTap()

            // Try to delete existing text
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            titleField.typeText(deleteString)
        }

        titleField.typeText(title)
    }

    /// Enter task description
    func enterDescription(_ description: String) {
        descriptionField.tap()
        descriptionField.typeText(description)
    }

    /// Select priority by name
    func selectPriority(_ priority: TestDataFactory.TaskPriority) {
        // Map priority to actual UI buttons (UI changed from 5 to 4 priorities)
        // Current UI has: "None", "Low", "High", "Max"
        // Map .medium → "Low" since Medium was removed
        var priorityName = priority.displayName
        if priorityName == "Medium" {
            priorityName = "Low"  // Medium no longer exists, map to Low
        }

        let fallbackIndex: Int = {
            switch priority {
            case .none:
                return 0
            case .low, .medium:
                return 1
            case .high:
                return 2
            case .max:
                return 3
            }
        }()

        if prioritySegmentedControl.waitForExistence(timeout: 1.5) {
            let button = prioritySegmentedControl.buttons[priorityName]
            if button.exists {
                button.tap()
                return
            }

            let indexedButton = prioritySegmentedControl.buttons.element(boundBy: fallbackIndex)
            if indexedButton.exists {
                indexedButton.tap()
            } else {
                print("⚠️ Warning: Priority '\(priorityName)' not found in segmented control")
            }
        } else {
            // Fallback: try to find priority buttons directly
            let priorityButton = app.buttons[priorityName]
            if priorityButton.exists {
                priorityButton.tap()
            } else {
                print("⚠️ Warning: Priority '\(priorityName)' button not found")
            }
        }
    }

    /// Select task type
    func selectTaskType(_ taskType: TestDataFactory.TaskType) {
        switch taskType {
        case .morning:
            if morningButton.exists {
                morningButton.tap()
            } else if taskTypeSelector.exists {
                taskTypeSelector.buttons["Morning"].tap()
            }
        case .evening:
            if eveningButton.exists {
                eveningButton.tap()
            } else if taskTypeSelector.exists {
                taskTypeSelector.buttons["Evening"].tap()
            }
        case .upcoming:
            if upcomingButton.exists {
                upcomingButton.tap()
            } else if taskTypeSelector.exists {
                taskTypeSelector.buttons["Upcoming"].tap()
            }
        case .inbox:
            // Inbox is typically default, no specific button
            break
        }
    }

    /// Set due date
    func setDueDate(_ date: Date) {
        // The app uses FSCalendar which is always visible, not a UIDatePicker
        // Wait for calendar to appear
        if dueDatePicker.waitForExistence(timeout: 2) {
            let calendar = Calendar.current
            let dayNumber = calendar.component(.day, from: date)

            // Method 1: Try to find the date number as a button (FSCalendar typically exposes cells as buttons)
            let dateButton = dueDatePicker.buttons["\(dayNumber)"].firstMatch
            if dateButton.exists {
                dateButton.tap()
                print("📅 Tapped date button: \(dayNumber)")
                Thread.sleep(forTimeInterval: 0.5)
                return
            }

            // Method 2: Try to find as static text
            let dateText = dueDatePicker.staticTexts["\(dayNumber)"].firstMatch
            if dateText.exists {
                dateText.tap()
                print("📅 Tapped date text: \(dayNumber)")
                Thread.sleep(forTimeInterval: 0.5)
                return
            }

            // Method 3: Fallback - Find "Today" and tap next cell
            let todayLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'today'")).firstMatch
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

            if todayLabel.exists && calendar.isDate(date, inSameDayAs: tomorrow) {
                let todayFrame = todayLabel.frame
                let dayWidth = dueDatePicker.frame.width / 7.0

                // Tap one cell to the right (tomorrow)
                let tomorrowCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                    .withOffset(CGVector(dx: todayFrame.midX + dayWidth, dy: todayFrame.midY))
                tomorrowCoordinate.tap()

                print("📅 Tapped tomorrow (next to Today cell)")
                Thread.sleep(forTimeInterval: 0.5)
                return
            }

            // Method 4: Last resort - coordinate-based tapping
            let dayOfWeek = calendar.component(.weekday, from: date)
            let calendarFrame = dueDatePicker.frame
            let dayWidth = calendarFrame.width / 7.0
            let xOffset = (CGFloat(dayOfWeek) - 0.5) * dayWidth
            let yOffset = calendarFrame.height * 0.7 // Increased from 0.6 to 0.7 for better accuracy

            let tapCoordinate = dueDatePicker.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: xOffset, dy: yOffset))
            tapCoordinate.tap()

            print("📅 Fallback: Tapped date \(dayNumber) at coordinates x:\(xOffset), y:\(yOffset)")
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Select project
    func selectProject(named projectName: String) {
        // The app uses a pill-style project selector
        // Pills may not be exposed as standard buttons in accessibility hierarchy

        // Method 1: Try direct button access
        let projectButton = app.buttons[projectName]
        if projectButton.exists {
            projectButton.tap()
            return
        }

        // Method 2: Try finding as static text (pills can be exposed as text)
        let projectLabel = app.staticTexts[projectName]
        if projectLabel.exists {
            projectLabel.tap()
            return
        }

        // Method 3: Try within scroll view or collection view
        let projectPills = app.collectionViews.firstMatch
        if projectPills.exists {
            let pillButton = projectPills.buttons[projectName]
            if pillButton.waitForExistence(timeout: 1) {
                pillButton.tap()
                return
            }

            let pillText = projectPills.staticTexts[projectName]
            if pillText.exists {
                pillText.tap()
                return
            }
        }

        // Method 4: Try any element with matching label
        let anyElement = app.descendants(matching: .any)[projectName]
        if anyElement.exists {
            anyElement.tap()
            return
        }

        print("⚠️ Warning: Could not find project named '\(projectName)' - project selection skipped")
    }

    /// Enable reminder
    func enableReminder() {
        if reminderToggle.exists && reminderToggle.value as? String != "1" {
            reminderToggle.tap()
        }
    }

    /// Disable reminder
    func disableReminder() {
        if reminderToggle.exists && reminderToggle.value as? String == "1" {
            reminderToggle.tap()
        }
    }

    /// Set reminder time
    func setReminderTime(_ date: Date) {
        enableReminder()

        if reminderTimePicker.waitForExistence(timeout: 2) {
            reminderTimePicker.adjust(toPickerWheelValue: TestDataFactory.formatDateTimeForDisplay(date))
        }
    }

    /// Tap save button
    @discardableResult
    func tapSave() -> HomePage {
        let addTaskContainer = view
        let navBar = app.navigationBars.firstMatch
        let nonKeyboardDoneButton = navBar.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch
        let nonKeyboardSaveButton = navBar.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch
        let didDismiss: () -> Bool = {
            if self.waitForDismissal(timeout: 2) {
                return true
            }

            let homePage = HomePage(app: self.app)
            return homePage.verifyBottomBarExists(timeout: 1) && homePage.verifyIsDisplayed(timeout: 1)
        }

        let candidates: [XCUIElement] = [
            app.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.buttons["addTask.createButton"],
            addTaskContainer.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.descendants(matching: .button)["addTask.createButton"],
            addTaskContainer.descendants(matching: .any)["addTask.createButton"],
            app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.saveButton],
            navBar.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            navBar.buttons["Done"],
            navBar.buttons["Create"],
            navBar.buttons["Save"],
            nonKeyboardDoneButton,
            nonKeyboardSaveButton,
            app.toolbars.buttons["Done"]
        ]
        waitForSubmitActionToBecomeEnabled(candidates: candidates, timeout: 2.5)
        let deadline = Date().addingTimeInterval(8)
        repeat {
            if navBar.exists {
                let preferredNavButtons: [XCUIElement] = [
                    navBar.buttons[AccessibilityIdentifiers.AddTask.saveButton],
                    navBar.buttons["Done"],
                    navBar.buttons["Save"],
                    navBar.buttons["Create"]
                ]

                for navButton in preferredNavButtons where navButton.exists {
                    tapElementCenter(navButton)
                    if didDismiss() {
                        return HomePage(app: app)
                    }
                }

                let navFrame = navBar.frame
                if navFrame.width > 0 && navFrame.height > 0 {
                    let doneCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                        .withOffset(CGVector(dx: navFrame.maxX - 24, dy: navFrame.midY))
                    doneCoordinate.tap()
                    if didDismiss() {
                        return HomePage(app: app)
                    }
                }
            }

            for candidate in candidates where candidate.exists {
                tapElementCenter(candidate)
                if didDismiss() {
                    return HomePage(app: app)
                }
            }

            if tapComposerCreateCTA(in: addTaskContainer) {
                if didDismiss() {
                    return HomePage(app: app)
                }
            }

            let keyboardDone = app.keyboards.buttons["Done"]
            if keyboardDone.exists {
                keyboardDone.tap()
                if didDismiss() {
                    return HomePage(app: app)
                }
            }

            let keyboardReturn = app.keyboards.buttons["Return"]
            if keyboardReturn.exists {
                keyboardReturn.tap()
                if didDismiss() {
                    return HomePage(app: app)
                }
            }

            Thread.sleep(forTimeInterval: 0.15)
        } while Date() < deadline

        if submitReturnFromFocusedTextField() {
            waitForSubmitActionToBecomeEnabled(candidates: candidates, timeout: 1.0)
            if didDismiss() {
                return HomePage(app: app)
            }
        }

        let primaryTitleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField]
        if focusAndSubmitReturn(primaryTitleField) {
            waitForSubmitActionToBecomeEnabled(candidates: candidates, timeout: 1.0)
            if didDismiss() {
                return HomePage(app: app)
            }
        }

        let fallbackTitleField = app.textFields.firstMatch
        if focusAndSubmitReturn(fallbackTitleField) {
            waitForSubmitActionToBecomeEnabled(candidates: candidates, timeout: 1.0)
            if didDismiss() {
                return HomePage(app: app)
            }
        }

        let homePage = HomePage(app: app)
        if homePage.verifyBottomBarExists(timeout: 1) && homePage.verifyIsDisplayed(timeout: 1) {
            return homePage
        }

        XCTFail("Unable to find save/create action for Add Task screen")
        return HomePage(app: app)
    }

    private func submitReturnFromFocusedTextField() -> Bool {
        let fields = app.descendants(matching: .textField)
        guard fields.count > 0 else { return false }

        for index in 0..<fields.count {
            let field = fields.element(boundBy: index)
            if hasKeyboardFocus(field) {
                field.typeText("\n")
                return true
            }
        }

        return false
    }

    private func focusAndSubmitReturn(_ field: XCUIElement) -> Bool {
        guard field.exists else { return false }

        if !hasKeyboardFocus(field) {
            guard field.isHittable else { return false }
            field.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 0.5)
        }

        guard hasKeyboardFocus(field) else { return false }
        field.typeText("\n")
        return true
    }

    private func focusedTextField() -> XCUIElement? {
        let fields = app.descendants(matching: .textField)
        guard fields.count > 0 else { return nil }

        for index in 0..<fields.count {
            let field = fields.element(boundBy: index)
            if hasKeyboardFocus(field) {
                return field
            }
        }

        return nil
    }

    private func hasKeyboardFocus(_ field: XCUIElement) -> Bool {
        return (field.value(forKey: "hasKeyboardFocus") as? Bool) == true
    }

    private func waitForSubmitActionToBecomeEnabled(candidates: [XCUIElement], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if candidates.contains(where: { $0.exists && $0.isEnabled }) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
    }

    private func tapComposerCreateCTA(in container: XCUIElement) -> Bool {
        guard container.exists else { return false }
        let frame = container.frame
        guard frame.width > 0, frame.height > 0 else { return false }

        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(
            CGVector(
                dx: frame.midX,
                dy: frame.maxY - min(42, max(20, frame.height * 0.08))
            )
        )
        target.tap()
        return true
    }

    private func tapElementCenter(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }

        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else { return }
        let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(
            CGVector(dx: frame.midX, dy: frame.midY)
        )
        coordinate.tap()
    }

    /// Tap cancel button
    @discardableResult
    func tapCancel() -> HomePage {
        cancelButton.tap()
        return HomePage(app: app)
    }

    /// Dismiss keyboard
    func dismissKeyboard() {
        // Try multiple methods to dismiss keyboard as toolbar button approach doesn't work

        // Method 1: Find which field currently has focus and type return there
        let allTextFields = app.textFields
        for i in 0..<allTextFields.count {
            let field = allTextFields.element(boundBy: i)
            if field.value(forKey: "hasKeyboardFocus") as? Bool == true {
                field.typeText("\n")
                // Wait a moment for keyboard to dismiss
                Thread.sleep(forTimeInterval: 0.3)
                break
            }
        }

        // Method 2: If keyboard still visible, swipe down
        if app.keyboards.firstMatch.exists {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Method 3: If still visible, tap outside keyboard area (tap the navigation bar)
        if app.keyboards.firstMatch.exists {
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                navBar.tap()
            }
        }
    }

    /// Submit the add-task form via keyboard Done from title field.
    func submitTitleWithKeyboardDone(times: Int = 1) {
        titleField.tap()
        for _ in 0..<max(1, times) {
            titleField.typeText("\n")
        }
    }

    // MARK: - Complex Actions

    /// Create task with all details (builder-style helper)
    @discardableResult
    func createTask(
        title: String,
        description: String? = nil,
        priority: TestDataFactory.TaskPriority = .medium,
        taskType: TestDataFactory.TaskType = .morning,
        dueDate: Date? = nil,
        project: String? = nil,
        hasReminder: Bool = false
    ) -> HomePage {
        // Enter title
        enterTitle(title)

        // Enter description if provided
        if let description = description {
            enterDescription(description)
        }

        // Select priority
        selectPriority(priority)

        // Select task type
        selectTaskType(taskType)

        // Set due date if provided
        if let dueDate = dueDate {
            setDueDate(dueDate)
        }

        // Select project if provided
        if let project = project {
            selectProject(named: project)
        }

        // Enable reminder if needed
        if hasReminder {
            enableReminder()
        }

        // Dismiss keyboard before saving
        if app.keyboards.firstMatch.exists {
            dismissKeyboard()
        }

        // Save task
        return tapSave()
    }

    /// Create task from TestDataFactory.TaskData
    @discardableResult
    func createTask(from taskData: TestDataFactory.TaskData) -> HomePage {
        return createTask(
            title: taskData.title,
            description: taskData.description,
            priority: taskData.priority,
            taskType: taskData.taskType,
            dueDate: taskData.dueDate,
            project: taskData.project,
            hasReminder: taskData.hasReminder
        )
    }

    // MARK: - Verifications

    /// Verify add task screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        // Require Add Task-specific affordances; a generic navigation bar is not sufficient.
        if titleField.waitForExistence(timeout: timeout) {
            return true
        }

        let addTaskSignals: [XCUIElement] = [
            app.otherElements[AccessibilityIdentifiers.AddTask.view],
            app.otherElements[AccessibilityIdentifiers.AddTask.modePicker],
            app.textFields[AccessibilityIdentifiers.AddTask.descriptionField],
            app.segmentedControls[AccessibilityIdentifiers.AddTask.prioritySegmentedControl],
            app.segmentedControls[AccessibilityIdentifiers.AddTask.taskTypeSelector],
            app.buttons[AccessibilityIdentifiers.AddTask.saveButton]
        ]
        let perSignalTimeout = min(1.0, max(0.25, timeout / Double(max(1, addTaskSignals.count))))
        return addTaskSignals.contains { $0.waitForExistence(timeout: perSignalTimeout) }
    }

    /// Verify validation error is shown
    func verifyValidationError(forField field: String, expectedMessage: String? = nil) -> Bool {
        var errorElement: XCUIElement

        switch field.lowercased() {
        case "title":
            errorElement = titleError
        case "description":
            errorElement = descriptionError
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
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: titleField)

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
