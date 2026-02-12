//
//  HomePage.swift
//  To Do ListUITests
//
//  Page Object for Home Screen
//

import XCTest

class HomePage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Elements

    var view: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.view]
    }

    var addTaskButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
    }

    var settingsButton: XCUIElement {
        // Fallback to finding by predicate if accessibility identifier not set
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'")
        let settingsButtons = app.buttons.containing(predicate)

        if settingsButtons.count > 0 {
            return settingsButtons.firstMatch
        }

        // Fallback to toolbar buttons
        if app.toolbars.firstMatch.exists {
            let toolbarButtons = app.toolbars.firstMatch.buttons
            if toolbarButtons.count > 2 {
                return toolbarButtons.element(boundBy: 2) // Settings is typically 3rd button
            }
        }

        return app.buttons[AccessibilityIdentifiers.Home.settingsButton]
    }

    var searchButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.searchButton]
    }

    var inboxButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.inboxButton]
    }

    var projectFilterButton: XCUIElement {
        let quickMenu = app.buttons[AccessibilityIdentifiers.Home.quickFilterMenuButton]
        if quickMenu.exists {
            return quickMenu
        }

        let legacyProjectFilter = app.buttons["home.projectFilterButton"]
        if legacyProjectFilter.exists {
            return legacyProjectFilter
        }

        let navMenuButton = app.buttons["home.focus.menu.button.nav"]
        if navMenuButton.exists {
            return navMenuButton
        }

        return app.buttons["home.focus.filterButton.nav"]
    }

    var quickFilterMenuContainer: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.quickFilterMenuContainer]
    }

    var quickFilterAdvancedButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.quickFilterMenuAdvancedButton]
    }

    var morningTasksList: XCUIElement {
        return app.tables[AccessibilityIdentifiers.Home.morningTasksList]
    }

    var eveningTasksList: XCUIElement {
        return app.tables[AccessibilityIdentifiers.Home.eveningTasksList]
    }

    var dailyScoreLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.dailyScoreLabel]
    }

    var streakLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.streakLabel]
    }

    var completionRateLabel: XCUIElement {
        return app.staticTexts[AccessibilityIdentifiers.Home.completionRateLabel]
    }

    var chartView: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.chartView]
    }

    var taskListScrollView: XCUIElement {
        let identifiedScrollView = app.scrollViews[AccessibilityIdentifiers.Home.taskListScrollView]
        if identifiedScrollView.exists {
            return identifiedScrollView
        }

        let fallbackOtherElement = app.otherElements[AccessibilityIdentifiers.Home.taskListScrollView]
        if fallbackOtherElement.exists {
            return fallbackOtherElement
        }

        let firstScrollView = app.scrollViews.firstMatch
        if firstScrollView.exists {
            return firstScrollView
        }

        return app.tables.firstMatch
    }

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Actions

    /// Tap the add task button to open task creation screen
    @discardableResult
    func tapAddTask() -> AddTaskPage {
        addTaskButton.tap()
        return AddTaskPage(app: app)
    }

    /// Tap settings button to open settings
    @discardableResult
    func tapSettings() -> SettingsPage {
        settingsButton.tap()
        return SettingsPage(app: app)
    }

    /// Tap search button
    func tapSearch() {
        searchButton.tap()
    }

    /// Tap inbox button
    func tapInbox() {
        inboxButton.tap()
    }

    /// Tap project filter button
    func tapProjectFilter() {
        projectFilterButton.tap()
    }

    /// Navigate home screen to a specific date using the date picker
    func navigateToDate(_ date: Date) {
        // Find the home date picker element
        let datePicker = app.otherElements[AccessibilityIdentifiers.Home.datePicker]

        if datePicker.waitForExistence(timeout: 2) {
            // FSCalendar in week mode - use coordinate-based tapping
            let calendar = Calendar.current
            let dayOfWeek = calendar.component(.weekday, from: date) // 1=Sunday, 7=Saturday

            let calendarFrame = datePicker.frame
            let dayWidth = calendarFrame.width / 7.0

            // Calculate X position: center of the day's column
            let xOffset = (CGFloat(dayOfWeek) - 0.5) * dayWidth

            // Calculate Y position: tap in the date number area
            let yOffset = calendarFrame.height * 0.6

            // Tap the date
            let tapCoordinate = datePicker.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: xOffset, dy: yOffset))
            tapCoordinate.tap()

            // Wait for view to update
            Thread.sleep(forTimeInterval: 0.5)

            print("📅 Navigated home view to: \(date)")
        } else {
            print("⚠️ Warning: Home date picker not found - navigation skipped")
        }
    }

    /// Get task cell at index
    func taskCell(at index: Int) -> XCUIElement {
        return app.tables.cells.element(boundBy: index)
    }

    /// Get task checkbox at index
    func taskCheckbox(at index: Int) -> XCUIElement {
        let identifier = AccessibilityIdentifiers.Home.taskCheckbox(index: index)
        return app.buttons[identifier]
    }

    /// Complete task at index by tapping checkbox
    func completeTask(at index: Int) {
        let checkbox = taskCheckbox(at: index)

        // Fallback: if accessibility identifier not set, tap the first button in the cell
        if !checkbox.exists {
            let cell = taskCell(at: index)
            if let firstButton = cell.buttons.allElementsBoundByIndex.first {
                firstButton.tap()
                return
            }
        }

        checkbox.tap()
    }

    /// Uncomplete task at index
    func uncompleteTask(at index: Int) {
        completeTask(at: index) // Same action - toggle
    }

    /// Tap task cell to open detail view
    func tapTask(at index: Int) {
        taskCell(at: index).tap()
    }

    /// Swipe to delete task at index
    func deleteTask(at index: Int) {
        let cell = taskCell(at: index)
        cell.swipeLeft()

        // Tap delete button
        let deleteButton = cell.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }
    }

    // MARK: - Verifications

    /// Verify home screen is displayed
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        // Check for navigation bar or tab bar
        let navBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch

        return navBar.waitForExistence(timeout: timeout) || tabBar.waitForExistence(timeout: timeout)
    }

    /// Verify task exists with title
    func verifyTaskExists(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        return taskText.exists
    }

    /// Verify task does not exist
    func verifyTaskDoesNotExist(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        return !taskText.exists
    }

    /// Get task count in table
    func getTaskCount() -> Int {
        return app.tables.cells.count
    }

    /// Verify task count
    func verifyTaskCount(_ expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        let actualCount = getTaskCount()
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) tasks, found \(actualCount)",
            file: file,
            line: line
        )
    }

    /// Verify daily score
    func verifyDailyScore(_ expectedScore: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let scoreText = dailyScoreLabel.label

        // Score might be displayed as "Score: 10" or just "10"
        let containsScore = scoreText.contains("\(expectedScore)")

        if !containsScore {
            XCTFail(
                "Expected daily score \(expectedScore), found '\(scoreText)'",
                file: file,
                line: line
            )
        }

        return containsScore
    }

    /// Verify streak
    func verifyStreak(_ expectedStreak: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let streakText = streakLabel.label

        // Streak might be displayed as "Streak: 5" or "5 days"
        let containsStreak = streakText.contains("\(expectedStreak)")

        if !containsStreak {
            XCTFail(
                "Expected streak \(expectedStreak), found '\(streakText)'",
                file: file,
                line: line
            )
        }

        return containsStreak
    }

    /// Verify completion rate
    func verifyCompletionRate(_ expectedRate: Int, file: StaticString = #file, line: UInt = #line) -> Bool {
        let rateText = completionRateLabel.label

        // Rate might be displayed as "60%" or "Completion: 60%"
        let containsRate = rateText.contains("\(expectedRate)")

        if !containsRate {
            XCTFail(
                "Expected completion rate \(expectedRate)%, found '\(rateText)'",
                file: file,
                line: line
            )
        }

        return containsRate
    }

    /// Verify chart is visible
    func verifyChartIsVisible() -> Bool {
        return chartView.exists
    }

    /// Verify empty state (no tasks)
    func verifyEmptyState() -> Bool {
        return getTaskCount() == 0
    }

    // MARK: - Wait Helpers

    /// Wait for task to appear
    @discardableResult
    func waitForTask(withTitle title: String, timeout: TimeInterval = 5) -> Bool {
        let taskText = app.staticTexts[title]
        return taskText.waitForExistence(timeout: timeout)
    }

    /// Wait for task count to match expected
    @discardableResult
    func waitForTaskCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            return self.getTaskCount() == expectedCount
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }

    /// Wait for daily score to update
    @discardableResult
    func waitForDailyScoreUpdate(to expectedScore: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            let scoreText = self.dailyScoreLabel.label
            return scoreText.contains("\(expectedScore)")
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        return result == .completed
    }
}
