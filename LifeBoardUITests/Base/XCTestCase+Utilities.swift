//
//  XCTestCase+Utilities.swift
//  To Do ListUITests
//
//  Utility extensions for XCTestCase to enhance test readability and functionality
//

import XCTest

extension XCTestCase {

    // MARK: - Element Query Helpers

    /// Find button by accessibility identifier
    func button(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.buttons[identifier]
    }

    /// Find text field by accessibility identifier
    func textField(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.textFields[identifier]
    }

    /// Find text view by accessibility identifier
    func textView(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.textViews[identifier]
    }

    /// Find static text by accessibility identifier
    func staticText(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.staticTexts[identifier]
    }

    /// Find table by accessibility identifier
    func table(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.tables[identifier]
    }

    /// Find collection view by accessibility identifier
    func collectionView(_ identifier: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.collectionViews[identifier]
    }

    /// Find navigation bar by title
    func navigationBar(_ title: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.navigationBars[title]
    }

    /// Find tab bar button by label
    func tabBarButton(_ label: String, in element: XCUIElement? = nil) -> XCUIElement {
        let context = element ?? XCUIApplication()
        return context.tabBars.buttons[label]
    }

    // MARK: - Table View Helpers

    /// Get table cell at index
    func tableCell(at index: Int, in table: XCUIElement) -> XCUIElement {
        return table.cells.element(boundBy: index)
    }

    /// Get table cell count
    func tableCellCount(in table: XCUIElement) -> Int {
        return table.cells.count
    }

    /// Find table cell containing text
    func tableCell(containing text: String, in table: XCUIElement) -> XCUIElement? {
        let cells = table.cells.allElementsBoundByIndex
        return cells.first { $0.staticTexts[text].exists }
    }

    /// Verify table has exact number of cells
    func verifyTableCellCount(
        _ expectedCount: Int,
        in table: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let actualCount = table.cells.count
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) cells, found \(actualCount)",
            file: file,
            line: line
        )
    }

    // MARK: - Date Helpers

    /// Format date for UI display (e.g., "Jan 15, 2025")
    func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Format date with time for UI display (e.g., "Jan 15, 2025 at 3:30 PM")
    func formatDateTimeForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Create date from string (format: "yyyy-MM-dd")
    func createDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// Get today's date at start of day
    func today() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }

    /// Get tomorrow's date
    func tomorrow() -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: today())!
    }

    /// Get yesterday's date
    func yesterday() -> Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: today())!
    }

    /// Get date n days from now
    func daysFromNow(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: today())!
    }

    // MARK: - Keyboard Helpers

    /// Dismiss keyboard
    func dismissKeyboard(in app: XCUIApplication) {
        app.toolbars.buttons["Done"].tap()
    }

    /// Tap return key on keyboard
    func tapReturnKey(in app: XCUIApplication) {
        app.keyboards.buttons["Return"].tap()
    }

    /// Check if keyboard is visible
    func isKeyboardVisible(in app: XCUIApplication) -> Bool {
        return app.keyboards.firstMatch.exists
    }

    // MARK: - Alert Helpers

    /// Verify alert is shown with title
    func verifyAlertIsShown(
        withTitle title: String,
        in app: XCUIApplication,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let alert = app.alerts[title]
        XCTAssertTrue(
            alert.waitForExistence(timeout: 3),
            "Alert with title '\(title)' not found",
            file: file,
            line: line
        )
    }

    /// Tap alert button
    func tapAlertButton(
        _ buttonTitle: String,
        in app: XCUIApplication,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let button = app.alerts.buttons[buttonTitle]
        XCTAssertTrue(
            button.waitForExistence(timeout: 3),
            "Alert button '\(buttonTitle)' not found",
            file: file,
            line: line
        )
        button.tap()
    }

    // MARK: - Scroll Helpers

    /// Scroll element to visible
    func scrollToElement(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        maxSwipes: Int = 10
    ) -> Bool {
        var swipeCount = 0

        while !element.isHittable && swipeCount < maxSwipes {
            scrollView.swipeUp()
            swipeCount += 1

            if element.isHittable {
                return true
            }
        }

        return element.isHittable
    }

    /// Scroll to top of scroll view
    func scrollToTop(in scrollView: XCUIElement) {
        scrollView.swipeDown(velocity: .fast)
    }

    /// Scroll to bottom of scroll view
    func scrollToBottom(in scrollView: XCUIElement) {
        scrollView.swipeUp(velocity: .fast)
    }

    // MARK: - Wait Helpers

    /// Wait for network request to complete (useful for CloudKit sync)
    func waitForNetworkIdle(timeout: TimeInterval = 5) {
        // Wait for network activity indicator to disappear
        Thread.sleep(forTimeInterval: timeout)
    }

    /// Wait for animation to complete
    func waitForAnimations(duration: TimeInterval = 0.5) {
        Thread.sleep(forTimeInterval: duration)
    }

    // MARK: - Conditional Helpers

    /// Execute closure if element exists
    func ifExists(
        _ element: XCUIElement,
        timeout: TimeInterval = 1,
        execute: (XCUIElement) -> Void
    ) {
        if element.waitForExistence(timeout: timeout) {
            execute(element)
        }
    }

    /// Execute closure if element does not exist
    func ifNotExists(
        _ element: XCUIElement,
        timeout: TimeInterval = 1,
        execute: () -> Void
    ) {
        if !element.waitForExistence(timeout: timeout) {
            execute()
        }
    }

    // MARK: - Performance Helpers

    /// Measure time of block execution
    func measureExecutionTime(
        named name: String,
        block: () -> Void
    ) -> TimeInterval {
        let start = Date()
        block()
        let end = Date()
        let duration = end.timeIntervalSince(start)

        print("⏱ \(name) took \(String(format: "%.3f", duration)) seconds")
        return duration
    }

    /// Assert execution time is under limit
    func assertExecutionTime(
        _ timeLimit: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line,
        block: () -> Void
    ) {
        let start = Date()
        block()
        let end = Date()
        let duration = end.timeIntervalSince(start)

        XCTAssertLessThanOrEqual(
            duration,
            timeLimit,
            "Execution took \(String(format: "%.3f", duration))s, expected < \(timeLimit)s",
            file: file,
            line: line
        )
    }
}
