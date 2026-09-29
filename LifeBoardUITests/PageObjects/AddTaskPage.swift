//
//  AddTaskPage.swift
//  LifeBoardUITests
//
//  Page Object for Add Task Screen
//

import XCTest

@MainActor
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

        // The remaining fallbacks match any text field, so they only run while
        // the sheet is up. Once it closes they would find Home's composer and
        // report the sheet as still open (or type Return into the composer).
        guard isPresented else { return field }

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

    var detailsDisclosure: XCUIElement {
        app.buttons[AccessibilityIdentifiers.AddTask.detailsDisclosure]
    }

    var timelinePreview: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.timelinePreview]
    }

    var lifeAreaSelector: XCUIElement {
        app.otherElements[AccessibilityIdentifiers.AddTask.lifeAreaSelector]
    }

    var scheduleEditor: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.scheduleEditor]
    }

    var scheduleTimeRow: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.scheduleTimeRow]
    }

    var scheduleTimePickerSheet: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.scheduleTimePickerSheet]
    }

    var scheduleTimePicker: XCUIElement {
        app.datePickers[AccessibilityIdentifiers.AddTask.scheduleTimePicker]
    }

    var scheduleTimePickerConfirmButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.AddTask.scheduleTimePickerConfirm]
    }

    var customDateChip: XCUIElement {
        let byButton = app.buttons[AccessibilityIdentifiers.DatePickerSheet.customDateChip]
        if byButton.exists {
            return byButton
        }

        let byAny = app.descendants(matching: .any)[AccessibilityIdentifiers.DatePickerSheet.customDateChip]
        if byAny.exists {
            return byAny
        }

        let pickDateButton = app.buttons["Pick date"]
        if pickDateButton.exists {
            return pickDateButton
        }

        return app.staticTexts["Pick date"]
    }

    var customDateSheet: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.DatePickerSheet.sheet]
    }

    var customDateCalendar: XCUIElement {
        return app.datePickers[AccessibilityIdentifiers.DatePickerSheet.calendar]
    }

    var customDateConfirmButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.DatePickerSheet.confirmButton]
    }

    var saveButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.AddTask.saveButton]
    }

    var createButton: XCUIElement {
        let directButton = app.buttons[AccessibilityIdentifiers.AddTask.createButton]
        if directButton.exists {
            return directButton
        }

        let descendantButton = app.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.createButton]
        if descendantButton.exists {
            return descendantButton
        }

        let legacySaveButton = app.buttons[AccessibilityIdentifiers.AddTask.saveButton]
        if legacySaveButton.exists {
            return legacySaveButton
        }

        let labeledPrimaryAction = app.buttons.matching(
            NSPredicate(
                format: "label == 'Create' OR label == 'Save' OR label == 'Add Task' OR label == 'Add'"
            )
        ).firstMatch
        if labeledPrimaryAction.exists {
            return labeledPrimaryAction
        }

        return app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.createButton]
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
    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Enter task title
    func enterTitle(_ title: String) {
        let primaryTitleField = app.textFields[AccessibilityIdentifiers.AddTask.titleField]
        if primaryTitleField.exists || primaryTitleField.waitForExistence(timeout: 8) {
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

    func openScheduleTimePicker() {
        let row = scheduleTimeRow
        if row.waitForExistence(timeout: 3) {
            tapElementCenter(row)
        }
    }

    func selectScheduleDuration(minutes: Int) {
        let identifier = AccessibilityIdentifiers.AddTask.scheduleDurationChip(minutes: minutes)
        let chip = app.descendants(matching: .any)[identifier]
        if chip.waitForExistence(timeout: 3) {
            tapElementCenter(chip)
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
        expandDetailsIfNeeded()
        descriptionField.tap()
        descriptionField.typeText(description)
    }

    func expandDetailsIfNeeded() {
        if descriptionField.waitForExistence(timeout: 0.5) {
            return
        }

        let candidates: [XCUIElement] = [
            detailsDisclosure,
            app.buttons["Add details"],
            app.buttons["Details"]
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: 1) {
            candidate.tap()
            if descriptionField.waitForExistence(timeout: 1.5) {
                return
            }
            let refreshedDisclosure = candidate.identifier.isEmpty
                ? detailsDisclosure
                : app.buttons[candidate.identifier]
            if refreshedDisclosure.waitForExistence(timeout: 1) {
                refreshedDisclosure.tap()
                _ = descriptionField.waitForExistence(timeout: 1.5)
            }
            return
        }
    }

    /// Select priority by name
    func selectPriority(_ priority: TestDataFactory.TaskPriority) {
        expandDetailsIfNeeded()
        // Map priority to actual UI buttons (UI changed from 5 to 4 priorities)
        // Current UI has: "None", "Low", "High", "Max"
        // Map .medium → "Low" since Medium was removed
        var priorityName = priority.displayName
        if priorityName == "Medium" {
            priorityName = "Low"  // Medium no longer exists, map to Low
        }

        // The Add Task sheet shows priority as labelled pills, not a segmented control.
        let priorityButton = app.buttons[priorityName]
        if priorityButton.waitForExistence(timeout: 1.5) {
            priorityButton.tap()
        } else {
            print("⚠️ Warning: Priority '\(priorityName)' button not found")
        }
    }

    /// Set due date
    func setDueDate(_ date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        if calendar.isDate(targetDay, inSameDayAs: today) {
            tapDatePreset(label: "Today")
            return
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(targetDay, inSameDayAs: tomorrow) {
            tapDatePreset(label: "Tomorrow")
            return
        }

        guard openCustomDatePicker() else { return }

        guard customDateSheet.waitForExistence(timeout: 2) || customDateCalendar.waitForExistence(timeout: 2) else {
            return
        }

        let dayNumber = calendar.component(.day, from: targetDay)
        let calendarRoot = customDateCalendar.waitForExistence(timeout: 1) ? customDateCalendar : customDateSheet

        let dateButton = calendarRoot.buttons["\(dayNumber)"].firstMatch
        if dateButton.exists {
            tapElementCenter(dateButton)
        } else {
            let dateText = calendarRoot.staticTexts["\(dayNumber)"].firstMatch
            if dateText.exists {
                tapElementCenter(dateText)
            }
        }

        if customDateConfirmButton.waitForExistence(timeout: 1) {
            tapElementCenter(customDateConfirmButton)
        }

        _ = customDateSheet.waitForNonExistence(timeout: 2)
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

    func selectLifeArea(named lifeAreaName: String) {
        let scopedCandidates: [XCUIElement] = [
            lifeAreaSelector.buttons[lifeAreaName],
            lifeAreaSelector.staticTexts[lifeAreaName],
            app.buttons[lifeAreaName],
            app.staticTexts[lifeAreaName]
        ]

        for candidate in scopedCandidates where candidate.waitForExistence(timeout: 1) {
            candidate.tap()
            return
        }

        print("⚠️ Warning: Could not find life area named '\(lifeAreaName)' - life area selection skipped")
    }

    /// Tap save button
    @discardableResult
    func tapSave() -> HomePage {
        // Fast path: the sheet's own Done. The fallbacks below each spend a
        // fixed dismissal wait, which made a plain save take several seconds.
        if saveButton.exists || saveButton.waitForExistence(timeout: 2), saveButton.isEnabled {
            saveButton.tap()
            if waitForDismissal(timeout: 5) {
                return HomePage(app: app)
            }
        }

        let addTaskContainer = view
        let navBar = app.navigationBars.firstMatch
        let toolbar = app.toolbars.firstMatch
        let didDismiss: () -> Bool = {
            if self.waitForDismissal(timeout: 2) {
                return true
            }

            return false
        }

        let candidates: [XCUIElement] = [
            app.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.buttons[AccessibilityIdentifiers.AddTask.createButton],
            addTaskContainer.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.saveButton],
            addTaskContainer.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.createButton],
            addTaskContainer.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.createButton],
            app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.saveButton],
            navBar.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            toolbar.buttons[AccessibilityIdentifiers.AddTask.saveButton],
            navBar.buttons["Done"],
            navBar.buttons["Create"],
            navBar.buttons["Save"],
            toolbar.buttons["Done"],
            toolbar.buttons["Create"],
            toolbar.buttons["Save"]
        ]
        waitForSubmitActionToBecomeEnabled(candidates: candidates, timeout: 2.5)
        let deadline = Date().addingTimeInterval(8)
        repeat {
            if didDismiss() {
                return HomePage(app: app)
            }

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
            }

            if toolbar.exists {
                let preferredToolbarButtons: [XCUIElement] = [
                    toolbar.buttons[AccessibilityIdentifiers.AddTask.saveButton],
                    toolbar.buttons["Done"],
                    toolbar.buttons["Save"],
                    toolbar.buttons["Create"]
                ]

                for toolbarButton in preferredToolbarButtons where toolbarButton.exists {
                    tapElementCenter(toolbarButton)
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

            _ = waitUntil(timeout: 0.4) { didDismiss() }
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
        if isPresented, focusAndSubmitReturn(fallbackTitleField) {
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
        let candidates: [XCUIElement] = [
            container.buttons[AccessibilityIdentifiers.AddTask.createButton],
            container.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.createButton],
            container.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.createButton],
            app.buttons[AccessibilityIdentifiers.AddTask.createButton],
            app.descendants(matching: .button)[AccessibilityIdentifiers.AddTask.createButton],
            app.descendants(matching: .any)[AccessibilityIdentifiers.AddTask.createButton]
        ]

        for candidate in candidates where candidate.exists {
            tapElementCenter(candidate)
            return true
        }

        return false
    }

    private func tapDatePreset(label: String) {
        let candidates: [XCUIElement] = [
            app.buttons[label],
            view.buttons[label],
            view.descendants(matching: .button)[label]
        ]

        for candidate in candidates where candidate.exists {
            tapElementCenter(candidate)
            _ = waitUntil(timeout: 1) { candidate.isSelected || self.customDateSheet.exists }
            return
        }
    }

    @discardableResult
    private func openCustomDatePicker() -> Bool {
        for _ in 0..<3 {
            let candidate = customDateChip
            if candidate.waitForExistence(timeout: 1) {
                let frame = candidate.frame
                if frame.width > 0, frame.height > 0 {
                    if candidate.debugDescription.contains("offscreen: true") {
                        view.swipeLeft()
                        _ = waitUntil(timeout: 1) { candidate.exists && candidate.isHittable }
                        continue
                    }
                    tapElementCenter(candidate)
                    return true
                }
            }

            // The chips scroll horizontally inside the sheet; without the
            // sheet container there is nothing to swipe.
            guard view.exists else { return false }
            view.swipeLeft()
            _ = waitUntil(timeout: 1) { candidate.exists && candidate.isHittable }
        }

        return false
    }

    private func tapElementCenter(_ element: XCUIElement) {
        let frame = element.frame
        guard frame.width > 0, frame.height > 0 else {
            return
        }

        let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(
            CGVector(dx: frame.midX, dy: frame.midY)
        )
        coordinate.tap()
    }

    /// Tap cancel button
    @discardableResult
    /// Tap Done without expecting the sheet to close — for tests that check
    /// saving is blocked (an empty title leaves Done disabled). `tapSave()`
    /// fails the test when nothing saves, which is the point here.
    func attemptSave() {
        if saveButton.waitForExistence(timeout: 2) {
            saveButton.tap()
        }
    }

    /// Cancel the sheet. With anything typed, the sheet first asks
    /// "Discard changes?"; this confirms Discard, as a person meaning to
    /// cancel would.
    @discardableResult
    func tapCancel() -> HomePage {
        cancelButton.tap()
        // Only an edited sheet asks; a clean one just closes. Poll briefly for
        // either rather than always waiting on a prompt that may never come.
        let discard = app.buttons["Discard"]
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if discard.exists {
                discard.tap()
                break
            }
            if isPresented == false { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
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
                _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 1)
                break
            }
        }

        // Method 2: If keyboard still visible, swipe down
        if app.keyboards.firstMatch.exists {
            app.swipeDown()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 1)
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
    /// Press Return `times` times in one burst. One `typeText` call, because
    /// the first Return submits and closes the sheet: separate calls would find
    /// no title field for the rest, which is not the double-submit being tested.
    func submitTitleWithKeyboardDone(times: Int = 1) {
        let field = titleField
        field.tap()
        field.typeText(String(repeating: "\n", count: max(1, times)))
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval, _ condition: @escaping () -> Bool) -> XCTWaiter.Result {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in condition() },
            object: NSObject()
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout)
    }

    // MARK: - Complex Actions

    /// Create task with all details (builder-style helper).
    ///
    /// `taskType` and `hasReminder` are accepted for `TestDataFactory`
    /// compatibility but no longer act: the Add Task sheet has no
    /// morning/evening type and no inline reminder toggle.
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

        // Set due date if provided
        if let dueDate = dueDate {
            setDueDate(dueDate)
        }

        // Select project if provided
        if let project = project {
            selectProject(named: project)
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
        let field = titleField
        if field.exists || field.waitForExistence(timeout: timeout) {
            return true
        }

        let addTaskSignals: [XCUIElement] = [
            app.otherElements[AccessibilityIdentifiers.AddTask.view],
            app.otherElements[AccessibilityIdentifiers.AddTask.lifeAreaSelector],
            app.buttons[AccessibilityIdentifiers.AddTask.detailsDisclosure],
            app.buttons[AccessibilityIdentifiers.AddTask.saveButton]
        ]
        let perSignalTimeout = min(1.0, max(0.25, timeout / Double(max(1, addTaskSignals.count))))
        return addTaskSignals.contains { $0.waitForExistence(timeout: perSignalTimeout) }
    }

    /// Verify validation error is shown
    func verifyValidationError(forField field: String, expectedMessage: String? = nil) -> Bool {
        // The sheet has no per-field error labels; a named field falls back to
        // any error-like copy on screen.
        let errorElement = app.staticTexts[field]
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
        if createButton.exists {
            return createButton.isEnabled
        }
        return saveButton.isEnabled
    }

    /// Verify save button is disabled
    func verifySaveButtonDisabled() -> Bool {
        if createButton.exists {
            return !createButton.isEnabled
        }
        return !saveButton.isEnabled
    }

    // MARK: - Wait Helpers

    /// Wait for screen to be dismissed
    @discardableResult
    func waitForDismissal(timeout: TimeInterval = 5) -> Bool {
        // The sheet's own controls, not "a text field": Home has a composer
        // field of its own, which kept this waiting after the sheet had closed.
        // A short manual poll: an XCTNSPredicateExpectation checks on a
        // one-second poll, so a sheet that closes in 0.3s still cost a second.
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if isPresented == false { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return isPresented == false
    }

    /// Whether the Add Task sheet is on screen, judged by its own controls.
    var isPresented: Bool {
        app.buttons[AccessibilityIdentifiers.AddTask.cancelButton].exists
            || app.buttons[AccessibilityIdentifiers.AddTask.saveButton].exists
            || view.exists
    }
}
