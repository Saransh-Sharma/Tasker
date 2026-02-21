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

    var foredropSurface: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.foredropSurface,
            "home.foredropSurface",
            "homeForedropSurface"
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var foredropHandle: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.foredropHandle]
    }

    var foredropCollapseHint: XCUIElement {
        let byIdentifier = app.buttons[AccessibilityIdentifiers.Home.foredropCollapseHint]
        if byIdentifier.exists {
            return byIdentifier
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.foredropCollapseHint]
    }

    var addTaskButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
    }

    var bottomBar: XCUIElement {
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBar]
    }

    var chartsButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.bottomBarCharts]
    }

    var settingsButton: XCUIElement {
        let byIdentifier = app.buttons[AccessibilityIdentifiers.Home.settingsButton]
        if byIdentifier.exists {
            return byIdentifier
        }

        let byAnyIdentifier = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.settingsButton]
        if byAnyIdentifier.exists {
            return byAnyIdentifier
        }

        return app.buttons.matching(
            NSPredicate(
                format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'"
            )
        ).firstMatch
    }

    var searchButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.searchButton]
    }

    var chatButton: XCUIElement {
        return app.buttons[AccessibilityIdentifiers.Home.chatButton]
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

    var focusStrip: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.focusStrip,
            "home.focusZone",
            AccessibilityIdentifiers.Home.focusDropZone
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var focusDropZone: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.focusDropZone,
            "home.focusZone",
            AccessibilityIdentifiers.Home.focusStrip
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var listDropZone: XCUIElement {
        let predicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@",
            AccessibilityIdentifiers.Home.listDropZone,
            AccessibilityIdentifiers.Home.taskListScrollView
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
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

    var radarChartView: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.radarChartView]
    }

    var navXpPieChart: XCUIElement {
        return app.otherElements[AccessibilityIdentifiers.Home.navXpPieChart]
    }

    var navXpPieChartButton: XCUIElement {
        let byButtonQuery = app.buttons["home.navXpPieChart.button"]
        if byButtonQuery.exists {
            return byButtonQuery
        }
        let byOtherElementsQuery = app.otherElements["home.navXpPieChart.button"]
        if byOtherElementsQuery.exists {
            return byOtherElementsQuery
        }
        return app.otherElements["home.navXpPieChart.container"]
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

    private var taskRowQuery: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        )
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func firstHittableElement(in query: XCUIElementQuery) -> XCUIElement? {
        for index in 0..<query.count {
            let candidate = query.element(boundBy: index)
            if candidate.exists && candidate.isHittable {
                return candidate
            }
        }
        return nil
    }

    private func rowMatchesTitle(_ row: XCUIElement, title: String) -> Bool {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalizedTitle.isEmpty == false else {
            return false
        }

        if row.label.lowercased().contains(normalizedTitle) {
            return true
        }

        // When accessibility grouping changes, debugDescription still includes
        // descendant text and remains stable enough for UI test matching.
        return row.debugDescription.lowercased().contains(normalizedTitle)
    }

    // MARK: - Actions

    /// Tap the add task button to open task creation screen
    @discardableResult
    func tapAddTask() -> AddTaskPage {
        let addTaskPage = AddTaskPage(app: app)
        for _ in 0..<3 {
            let byButtonID = app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
            if byButtonID.waitForExistence(timeout: 1) {
                if byButtonID.isHittable {
                    byButtonID.tap()
                } else {
                    byButtonID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            let byAnyID = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.addTaskButton]
            if byAnyID.waitForExistence(timeout: 1) {
                byAnyID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            let addTaskByLabel = app.buttons["Add Task"]
            if addTaskByLabel.exists {
                addTaskByLabel.tap()
                if addTaskPage.verifyIsDisplayed(timeout: 2) {
                    return addTaskPage
                }
            }

            // Avoid tapping an ambiguous "home.bottomBar" query because multiple
            // bottom-bar buttons can share that identifier in UI test snapshots.
            // The explicit Add Task button paths above are the only safe fallbacks.
        }

        XCTFail("Add Task button should exist before tapping")
        return addTaskPage
    }

    /// Tap settings button to open settings
    @discardableResult
    func tapSettings() -> SettingsPage {
        let settingsPage = SettingsPage(app: app)
        let candidates: [XCUIElement] = [
            app.buttons[AccessibilityIdentifiers.Home.settingsButton],
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.settingsButton],
            app.buttons.matching(
                NSPredicate(
                    format: "label CONTAINS[c] 'Settings' OR label CONTAINS[c] 'gear' OR identifier CONTAINS[c] 'settings'"
                )
            ).firstMatch
        ]

        for candidate in candidates {
            guard candidate.waitForExistence(timeout: 2) else { continue }
            if candidate.isHittable {
                candidate.tap()
            } else {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }

            if settingsPage.verifyIsDisplayed(timeout: 2) {
                return settingsPage
            }
        }

        XCTFail("Failed to tap \(AccessibilityIdentifiers.Home.settingsButton)")
        return settingsPage
    }

    /// Tap search button
    func tapSearch() {
        searchButton.tap()
    }

    /// Tap charts button
    func tapCharts() {
        chartsButton.tap()
    }

    /// Tap chat button
    func tapChat() {
        chatButton.tap()
    }

    /// Tap inbox button
    func tapInbox() {
        inboxButton.tap()
    }

    /// Tap floating nav XP pie chart.
    func tapNavXpPieChart() {
        let chart = navXpPieChart
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "Navigation XP pie chart should exist before tapping")
        chart.tap()
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
        let taskRow = taskRowQuery.element(boundBy: index)
        if taskRow.exists {
            return taskRow
        }

        return app.tables.cells.element(boundBy: index)
    }

    /// Get task checkbox at index
    func taskCheckbox(at index: Int) -> XCUIElement {
        let identifier = AccessibilityIdentifiers.Home.taskCheckbox(index: index)
        let legacyCheckbox = app.buttons[identifier]
        if legacyCheckbox.exists {
            return legacyCheckbox
        }

        let row = taskCell(at: index)
        let rowCheckbox = row.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).firstMatch
        if rowCheckbox.exists {
            return rowCheckbox
        }

        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).element(boundBy: index)
    }

    /// Get SwiftUI task row by title using stable row accessibility identifiers.
    func taskRow(containingTitle title: String) -> XCUIElement {
        let rowsContainingTitle = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        ).containing(.staticText, identifier: title)
        if let hittableRow = firstHittableElement(in: rowsContainingTitle) {
            return hittableRow
        }

        let rowContainingTitle = rowsContainingTitle.firstMatch
        if rowContainingTitle.exists {
            return rowContainingTitle
        }

        let rowsByLabel = taskRowQuery.matching(
            NSPredicate(format: "label CONTAINS[c] %@", title)
        )
        if let hittableRowByLabel = firstHittableElement(in: rowsByLabel) {
            return hittableRowByLabel
        }

        let rowByLabel = rowsByLabel.firstMatch
        if rowByLabel.exists {
            return rowByLabel
        }

        let rows = taskRowQuery
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if rowMatchesTitle(row, title: title) {
                return row
            }
        }

        let fallbackByLabel = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.' AND label CONTAINS[c] %@", title)
        ).firstMatch
        if fallbackByLabel.exists {
            return fallbackByLabel
        }

        return app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskRow.'")
        ).firstMatch
    }

    func focusTaskCard(containingTitle title: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH 'home.focus.task.' AND label CONTAINS[c] %@",
            title
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @discardableResult
    func dragTaskToFocus(title: String, duration: TimeInterval = 0.8) -> Bool {
        let row = taskRow(containingTitle: title)
        guard row.waitForExistence(timeout: 4), focusDropZone.waitForExistence(timeout: 4) else {
            return false
        }
        row.press(forDuration: duration, thenDragTo: focusDropZone)
        return true
    }

    @discardableResult
    func dragFocusTaskToList(title: String, duration: TimeInterval = 0.8) -> Bool {
        let card = focusTaskCard(containingTitle: title)
        guard card.waitForExistence(timeout: 4), listDropZone.waitForExistence(timeout: 4) else {
            return false
        }
        card.press(forDuration: duration, thenDragTo: listDropZone)
        return true
    }

    /// Get SwiftUI task checkbox by title using stable checkbox accessibility identifiers.
    func taskCheckbox(containingTitle title: String) -> XCUIElement {
        let row = taskRow(containingTitle: title)
        if row.exists, row.identifier.hasPrefix("home.taskRow.") {
            let taskID = String(row.identifier.dropFirst("home.taskRow.".count))
            let rowScopedCheckboxIdentifier = "home.taskCheckbox.\(taskID)"

            let rowScopedMatches = row.buttons.matching(
                NSPredicate(format: "identifier == %@", rowScopedCheckboxIdentifier)
            )
            if let hittableRowScopedCheckbox = firstHittableElement(in: rowScopedMatches) {
                return hittableRowScopedCheckbox
            }

            let rowScopedCheckbox = rowScopedMatches.firstMatch
            if rowScopedCheckbox.exists {
                return rowScopedCheckbox
            }

            let directMatches = app.buttons.matching(
                NSPredicate(format: "identifier == %@", rowScopedCheckboxIdentifier)
            )
            if let hittableDirectCheckbox = firstHittableElement(in: directMatches) {
                return hittableDirectCheckbox
            }

            let directCheckbox = directMatches.firstMatch
            if directCheckbox.exists {
                return directCheckbox
            }
        }

        let checkboxesByLabel = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.' AND label CONTAINS[c] %@", title)
        )
        if let hittableCheckboxByLabel = firstHittableElement(in: checkboxesByLabel) {
            return hittableCheckboxByLabel
        }

        let checkboxByLabel = checkboxesByLabel.firstMatch
        if checkboxByLabel.exists {
            return checkboxByLabel
        }
        let checkboxPredicate = NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        let checkboxesInRow = row.buttons.matching(checkboxPredicate)
        if let hittableCheckboxInRow = firstHittableElement(in: checkboxesInRow) {
            return hittableCheckboxInRow
        }

        let checkboxInRow = checkboxesInRow.firstMatch
        if checkboxInRow.exists {
            return checkboxInRow
        }

        let rows = taskRowQuery
        for index in 0..<rows.count {
            let candidateRow = rows.element(boundBy: index)
            guard rowMatchesTitle(candidateRow, title: title) else { continue }
            let candidateCheckbox = candidateRow.buttons.matching(checkboxPredicate).firstMatch
            if candidateCheckbox.exists {
                return candidateCheckbox
            }
        }

        return app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'home.taskCheckbox.'")
        ).firstMatch
    }

    /// Read row state accessibility value ("open" / "done") for a task title.
    func taskRowStateValue(containingTitle title: String) -> String? {
        taskRow(containingTitle: title).value as? String
    }

    /// Wait for a task row state value ("open" / "done") for a given title.
    func waitForTaskRowState(_ expectedState: String, title: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            guard let value = self.taskRowStateValue(containingTitle: title) else {
                return false
            }
            return value.caseInsensitiveCompare(expectedState) == .orderedSame
        }

        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Complete task at index by tapping checkbox
    func completeTask(at index: Int) {
        let checkbox = taskCheckbox(at: index)
        if checkbox.exists {
            tapElement(checkbox)
            return
        }

        // Last-resort fallback for runtimes where checkbox IDs are not projected.
        if !checkbox.exists {
            let cell = taskCell(at: index)
            let fallbackCheckbox = cell.buttons.matching(
                NSPredicate(format: "identifier CONTAINS[c] 'checkbox' OR label CONTAINS[c] 'complete'")
            ).firstMatch
            if fallbackCheckbox.exists {
                tapElement(fallbackCheckbox)
                return
            }
        }
    }

    /// Complete task by title by tapping checkbox inside the matching row.
    func completeTask(containingTitle title: String) {
        let checkbox = taskCheckbox(containingTitle: title)
        if checkbox.waitForExistence(timeout: 2) {
            tapElement(checkbox)
            return
        }

        let titleElement = app.staticTexts.matching(
            NSPredicate(format: "label == %@", title)
        ).firstMatch
        if titleElement.waitForExistence(timeout: 1.5) {
            let titleFrame = titleElement.frame
            let targetX = max(8, titleFrame.minX - 30)
            let targetY = titleFrame.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: targetX, dy: targetY))
                .tap()
            return
        }

        let row = taskRow(containingTitle: title)
        let fallbackCheckbox = row.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH 'home.taskCheckbox.' OR label CONTAINS[c] 'complete' OR label CONTAINS[c] %@",
                title
            )
        ).firstMatch
        if fallbackCheckbox.exists {
            tapElement(fallbackCheckbox)
            return
        }

        if row.exists {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        }
    }

    /// Uncomplete task at index
    func uncompleteTask(at index: Int) {
        completeTask(at: index) // Same action - toggle
    }

    /// Uncomplete task by title.
    func uncompleteTask(containingTitle title: String) {
        completeTask(containingTitle: title) // Same action - toggle
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

    @discardableResult
    func verifyBottomBarExists(timeout: TimeInterval = 5) -> Bool {
        if bottomBar.waitForExistence(timeout: timeout) {
            return true
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBar]
            .waitForExistence(timeout: timeout)
    }

    @discardableResult
    func waitForBottomBarState(_ expectedState: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedState)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: bottomBar)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    @discardableResult
    func waitForForedropState(_ expectedState: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedState)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: foredropSurface)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Verify task exists with title
    func verifyTaskExists(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        if taskText.exists {
            return true
        }
        return taskRow(containingTitle: title).exists
    }

    /// Verify task does not exist
    func verifyTaskDoesNotExist(withTitle title: String) -> Bool {
        let taskText = app.staticTexts[title]
        return !taskText.exists && !taskRow(containingTitle: title).exists
    }

    /// Get task count in table
    func getTaskCount() -> Int {
        let rowCount = taskRowQuery.count
        if rowCount > 0 {
            return rowCount
        }
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

    /// Verify floating nav XP pie chart is visible.
    func verifyNavXpPieChartIsVisible(timeout: TimeInterval = 5) -> Bool {
        navXpPieChart.waitForExistence(timeout: timeout)
    }

    /// Verify floating nav XP pie chart is hidden.
    func verifyNavXpPieChartIsHidden(timeout: TimeInterval = 2) -> Bool {
        !navXpPieChart.waitForExistence(timeout: timeout)
    }

    /// Verify floating nav XP pie chart can be interacted with.
    @discardableResult
    func verifyNavXpPieChartIsHittable(file: StaticString = #file, line: UInt = #line) -> Bool {
        let isHittable = navXpPieChart.isHittable
        if !isHittable {
            XCTFail("Navigation XP pie chart should be hittable", file: file, line: line)
        }
        return isHittable
    }

    /// Verify floating nav XP pie chart size is approximately expected.
    @discardableResult
    func verifyNavXpPieChartSize(
        expected: CGFloat = 136,
        tolerance: CGFloat = 10,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let frame = navXpPieChart.frame
        let widthMatches = abs(frame.width - expected) <= tolerance
        let heightMatches = abs(frame.height - expected) <= tolerance
        let matches = widthMatches && heightMatches

        if !matches {
            XCTFail(
                "Expected nav XP pie chart size near \(expected)x\(expected), got \(frame.width)x\(frame.height)",
                file: file,
                line: line
            )
        }

        return matches
    }

    /// Verify floating nav XP pie chart frame is fully within the visible app window.
    @discardableResult
    func verifyNavXpPieChartIsFullyVisibleInWindow(file: StaticString = #file, line: UInt = #line) -> Bool {
        let chartFrame = navXpPieChart.frame
        let window = app.windows.firstMatch
        let windowFrame = window.frame

        let isFullyVisible = windowFrame.contains(chartFrame)
        if !isFullyVisible {
            XCTFail(
                "Expected nav XP pie chart frame \(chartFrame) to be fully inside window frame \(windowFrame)",
                file: file,
                line: line
            )
        }
        return isFullyVisible
    }

    /// Verify nav pie chart is horizontally aligned with settings button and positioned above it.
    @discardableResult
    func verifyNavXpPieChartAlignedWithSettingsButton(
        horizontalTolerance: CGFloat = 16,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let chartExists = navXpPieChart.waitForExistence(timeout: 5)
        let settingsExists = settingsButton.waitForExistence(timeout: 5)
        guard chartExists, settingsExists else {
            XCTFail("Expected nav pie chart and settings button to exist for alignment check", file: file, line: line)
            return false
        }

        let chartFrame = navXpPieChart.frame
        let settingsFrame = settingsButton.frame
        let isHorizontallyAligned = abs(chartFrame.midX - settingsFrame.midX) <= horizontalTolerance
        let isAboveSettings = chartFrame.midY < settingsFrame.midY
        let isAligned = isHorizontallyAligned && isAboveSettings

        if !isAligned {
            XCTFail(
                "Expected nav pie chart aligned above settings. chart=\(chartFrame), settings=\(settingsFrame), tolerance=\(horizontalTolerance)",
                file: file,
                line: line
            )
        }
        return isAligned
    }

    /// Verify nav XP pie chart button/container is absent.
    @discardableResult
    func verifyNavXpPieChartButtonIsAbsent(file: StaticString = #file, line: UInt = #line) -> Bool {
        let isAbsent = !navXpPieChartButton.exists
        if !isAbsent {
            XCTFail("Navigation XP pie chart button should be absent", file: file, line: line)
        }
        return isAbsent
    }

    /// Verify nav XP pie chart button/container is present.
    @discardableResult
    func verifyNavXpPieChartButtonIsPresent(timeout: TimeInterval = 3, file: StaticString = #file, line: UInt = #line) -> Bool {
        let isPresent = navXpPieChartButton.waitForExistence(timeout: timeout)
        if !isPresent {
            XCTFail("Navigation XP pie chart button should be present", file: file, line: line)
        }
        return isPresent
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
        if taskText.waitForExistence(timeout: timeout) {
            return true
        }
        return taskRow(containingTitle: title).waitForExistence(timeout: timeout)
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
