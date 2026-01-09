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
            field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'title' OR label CONTAINS[c] 'title'")).firstMatch
        }

        // Last fallback: first text field
        if !field.exists {
            field = app.textFields.firstMatch
        }

        return field
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
        // Try accessibility identifier first
        var button = app.buttons[AccessibilityIdentifiers.AddTask.saveButton]

        // Fallback: find by label "Save" or "Done"
        if !button.exists {
            button = app.buttons["Save"]
        }

        if !button.exists {
            button = app.buttons["Done"]
        }

        // Last fallback: right bar button (typically Done button in navigation bar)
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
        var button = app.buttons[AccessibilityIdentifiers.AddTask.cancelButton]

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
        titleField.tap()
        titleField.typeText(title)
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

        if prioritySegmentedControl.exists {
            let button = prioritySegmentedControl.buttons[priorityName]
            if button.exists {
                button.tap()
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
        // The app uses FluentUI PillButtonBar for project selection
        // Pills may not be exposed as standard buttons in accessibility hierarchy

        // Method 1: Try direct button access
        let projectButton = app.buttons[projectName]
        if projectButton.exists {
            projectButton.tap()
            return
        }

        // Method 2: Try finding as static text (FluentUI pills sometimes exposed as text)
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
        saveButton.tap()
        return HomePage(app: app)
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

    // MARK: - Complex Actions (Fluent API)

    /// Create task with all details (fluent interface)
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
        // Check for title field or navigation bar
        let navBar = app.navigationBars.firstMatch
        let titleFieldExists = titleField.waitForExistence(timeout: timeout)
        let navBarExists = navBar.waitForExistence(timeout: timeout)

        return titleFieldExists || navBarExists
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
