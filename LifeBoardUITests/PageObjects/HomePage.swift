//
//  HomePage.swift
//  LifeBoardUITests
//
//  Page Object for the live Home root.
//
//  Home is `AdaptiveHome` (LifeBoard/Features/Home/Adaptive) inside the
//  Foundation shell. Every root carries `<root>.header`; the roots are reached
//  from the dock on iPhone (`foundation.destination.<root>`) or the top root
//  switcher on iPad and Mac (`foundation.expanded.destination.<root>`).
//  Tasks live in the Home tasks card (`HomeTasksCardContent`): each open task is
//  a `home.task.<uuid>` button with a sibling completion control
//  `home.taskCheckbox.<uuid>`. Completing a task removes it from the card and
//  shows a receipt whose Undo (`home.tasks.undoCompletion`) reopens it.
//

import XCTest

@MainActor
class HomePage {

    // MARK: - Properties

    private let app: XCUIApplication

    // MARK: - Initialization

    init(app: XCUIApplication) {
        self.app = app
    }

    private func missingElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)["missing.\(identifier)"]
    }

    // MARK: - Shell

    /// Home's root header. Every Foundation root stamps `<root>.header`.
    var view: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Home.header]
    }

    /// The root chrome: the dock on iPhone, the root switcher on iPad and Mac.
    var bottomBar: XCUIElement {
        let dock = app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.compactChrome]
        if dock.exists {
            return dock
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.rootSwitcher]
    }

    /// The button that selects a root (`home`, `plan`, `track`, `insights`, `eva`).
    func rootButton(_ destination: String) -> XCUIElement {
        let dockButton = app.buttons[AccessibilityIdentifiers.Shell.destination(destination)]
        if dockButton.exists {
            return dockButton
        }
        let switcherButton = app.buttons[AccessibilityIdentifiers.Shell.expandedDestination(destination)]
        if switcherButton.exists {
            return switcherButton
        }
        return dockButton
    }

    var homeButton: XCUIElement {
        rootButton("home")
    }

    var insightsButton: XCUIElement {
        rootButton("insights")
    }

    /// The Insights root's header.
    var insightsRoot: XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.header("insights")]
    }

    /// Home's scroll view.
    var taskListScrollView: XCUIElement {
        let scrollView = app.scrollViews[AccessibilityIdentifiers.Home.scroll]
        if scrollView.exists {
            return scrollView
        }
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Home.scroll]
    }

    /// Home's "…" menu, which holds Settings.
    var settingsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Shell.more("home")]
    }

    // MARK: - Tasks Card

    /// "Add a task" in the Home tasks card; it opens the Add Task sheet.
    var addTaskButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.addTaskButton]
    }

    /// The Undo on the receipt a Home completion leaves behind.
    var undoCompletionButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.Home.undoCompletion]
    }

    private var taskRowQuery: XCUIElementQuery {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityIdentifiers.Home.taskRowPrefix)
        )
    }

    // MARK: - Actions

    /// Select a root from the dock or the root switcher and wait for its header.
    @discardableResult
    func openRoot(_ destination: String, timeout: TimeInterval = 8) -> Bool {
        let button = rootButton(destination)
        guard button.waitForExistence(timeout: timeout) else { return false }
        tapElement(button)
        return app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.header(destination)]
            .waitForExistence(timeout: timeout)
    }

    /// Tap Home's "Add a task" to open the Add Task sheet.
    @discardableResult
    func tapAddTask() -> AddTaskPage {
        let addTaskPage = AddTaskPage(app: app)
        if view.exists == false {
            openRoot("home")
        }
        for _ in 0..<3 {
            let addTask = addTaskButton
            revealOnHome(addTask)
            // `exists` first: `waitForExistence` checks on a one-second poll,
            // so it costs a second even for a control already on screen.
            if addTask.exists || addTask.waitForExistence(timeout: 2) {
                tapElement(addTask)
                if addTaskPage.verifyIsDisplayed(timeout: 3) {
                    return addTaskPage
                }
            }
        }

        XCTFail("Home's Add a task button (\(AccessibilityIdentifiers.Home.addTaskButton)) should open the Add Task sheet")
        return addTaskPage
    }

    /// Open Settings from Home's "…" menu.
    @discardableResult
    func tapSettings() -> SettingsPage {
        let settingsPage = SettingsPage(app: app)
        if view.exists == false {
            openRoot("home")
        }
        let more = settingsButton
        if more.waitForExistence(timeout: 5) {
            tapElement(more)
            let settings = app.buttons["Settings"]
            if settings.waitForExistence(timeout: 3) {
                settings.tap()
            }
        }

        if settingsPage.verifyIsDisplayed(timeout: 5) == false {
            XCTFail("Settings should open from \(AccessibilityIdentifiers.Shell.more("home"))")
        }
        return settingsPage
    }

    @discardableResult
    func openInsights(timeout: TimeInterval = 8) -> Bool {
        openRoot("insights", timeout: timeout)
    }

    /// Tap the Insights root.
    func tapInsights() {
        tapElement(insightsButton)
    }

    /// Tap the Home root.
    func tapHome() {
        tapElement(homeButton)
    }

    /// Whether a root button reads as selected.
    @discardableResult
    func waitForRootSelection(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Task Rows

    /// The Home task row whose label contains `title`.
    func taskRow(containingTitle title: String) -> XCUIElement {
        let rows = taskRowQuery.matching(NSPredicate(format: "label CONTAINS[c] %@", title))
        if let hittable = firstHittableElement(in: rows) {
            return hittable
        }
        let row = rows.firstMatch
        if row.exists {
            return row
        }
        return missingElement("\(AccessibilityIdentifiers.Home.taskRowPrefix)\(title)")
    }

    /// How many Tasks-card rows carry this title. One row per task, unlike
    /// counting text: a task that is scheduled and due also shows its title in
    /// the today story.
    func taskRowCount(containingTitle title: String) -> Int {
        taskRowQuery.matching(NSPredicate(format: "label CONTAINS[c] %@", title)).count
    }

    /// The Home task row at `index`, in card order.
    func taskCell(at index: Int) -> XCUIElement {
        taskRowQuery.element(boundBy: index)
    }

    /// Index of the first Home task row whose label contains `title`, or 0.
    func taskIndex(withTitle title: String) -> Int {
        let rows = taskRowQuery
        for index in 0..<rows.count where rows.element(boundBy: index).label.localizedCaseInsensitiveContains(title) {
            return index
        }
        return 0
    }

    /// The completion control that sits beside a Home task row.
    func taskCheckbox(containingTitle title: String) -> XCUIElement {
        let row = taskRow(containingTitle: title)
        if row.exists {
            return app.buttons[checkboxIdentifier(forRowIdentifier: row.identifier)]
        }
        return missingElement("\(AccessibilityIdentifiers.Home.taskCheckboxPrefix)\(title)")
    }

    func taskCheckbox(at index: Int) -> XCUIElement {
        let row = taskCell(at: index)
        guard row.exists else {
            return missingElement("\(AccessibilityIdentifiers.Home.taskCheckboxPrefix)\(index)")
        }
        return app.buttons[checkboxIdentifier(forRowIdentifier: row.identifier)]
    }

    private func checkboxIdentifier(forRowIdentifier identifier: String) -> String {
        let taskID = String(identifier.dropFirst(AccessibilityIdentifiers.Home.taskRowPrefix.count))
        return AccessibilityIdentifiers.Home.taskCheckbox(taskID)
    }

    /// Complete a Home task. The row leaves the card and a receipt with Undo appears.
    func completeTask(containingTitle title: String) {
        let checkbox = taskCheckbox(containingTitle: title)
        revealOnHome(checkbox)
        if checkbox.waitForExistence(timeout: 3) {
            tapElement(checkbox)
        }
    }

    func completeTask(at index: Int) {
        let checkbox = taskCheckbox(at: index)
        revealOnHome(checkbox)
        if checkbox.waitForExistence(timeout: 3) {
            tapElement(checkbox)
        }
    }

    /// Reopen the most recently completed Home task through the receipt's Undo.
    ///
    /// Home lists open tasks only, so a completed task is reopened from the
    /// receipt rather than from its row.
    func uncompleteLastCompletedTask() {
        let undo = undoCompletionButton
        revealOnHome(undo)
        if undo.waitForExistence(timeout: 3) {
            tapElement(undo)
        }
    }

    /// Open a Home task's detail route.
    func tapTask(containingTitle title: String) {
        let row = taskRow(containingTitle: title)
        revealOnHome(row)
        if row.waitForExistence(timeout: 3) {
            tapElement(row)
        }
    }

    func tapTask(at index: Int) {
        let row = taskCell(at: index)
        revealOnHome(row)
        if row.waitForExistence(timeout: 3) {
            tapElement(row)
        }
    }

    /// The pushed task route (`TaskRouteView`) titles itself "Task".
    var taskRouteNavigationBar: XCUIElement {
        app.navigationBars["Task"]
    }

    /// Leave the task route with its back button and wait for Home.
    func returnFromTaskRoute() {
        let bar = taskRouteNavigationBar
        if bar.waitForExistence(timeout: 3) {
            bar.buttons.element(boundBy: 0).tap()
        }
        _ = view.waitForExistence(timeout: 5)
    }

    /// The task route's actions menu (Open in Plan, Archive, Delete).
    // Menu items and confirmation-dialog buttons are UIKit actions under the
    // hood, and SwiftUI does not always carry their identifiers across, so each
    // of these also matches the control's visible label.
    var taskActionsMenu: XCUIElement {
        button(identifier: AccessibilityIdentifiers.TaskEditor.actions, orLabel: "Task actions")
    }

    var taskDeleteAction: XCUIElement {
        button(identifier: AccessibilityIdentifiers.TaskEditor.delete, orLabel: "Delete")
    }

    var taskDeleteConfirmButton: XCUIElement {
        button(identifier: AccessibilityIdentifiers.TaskEditor.deleteConfirm, orLabel: "Delete task")
    }

    private func button(identifier: String, orLabel label: String) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", identifier, label))
            .firstMatch
    }

    /// Open the task route's actions menu. On iPhone the secondary toolbar
    /// item folds into the navigation bar's overflow ("More") button, which
    /// lists the menu's items (Open in Plan, Archive, Delete) directly.
    private func openTaskActions() -> Bool {
        if taskActionsMenu.exists || taskActionsMenu.waitForExistence(timeout: 2) {
            taskActionsMenu.tap()
            return true
        }
        let overflow = taskRouteNavigationBar.buttons["More"]
        guard overflow.exists || overflow.waitForExistence(timeout: 2) else { return false }
        overflow.tap()
        if taskDeleteAction.waitForExistence(timeout: 2) {
            return true
        }
        // Some layouts keep the menu as one nested entry inside the overflow.
        guard taskActionsMenu.waitForExistence(timeout: 2) else { return false }
        taskActionsMenu.tap()
        return true
    }

    /// Open a task and ask to delete it; stops at the confirmation dialog.
    @discardableResult
    func requestDeletion(containingTitle title: String) -> Bool {
        tapTask(containingTitle: title)
        guard taskRouteNavigationBar.waitForExistence(timeout: 5), openTaskActions() else { return false }
        guard taskDeleteAction.waitForExistence(timeout: 3) else { return false }
        taskDeleteAction.tap()
        return taskDeleteConfirmButton.waitForExistence(timeout: 3)
    }

    /// Back out of the "Delete this task?" confirmation. On iOS 26 it is a
    /// popover-style menu with no Cancel button; dismissing it means tapping
    /// outside, as a person would.
    func cancelDeletion() {
        let cancel = app.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        if cancel.exists {
            cancel.tap()
            return
        }
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.exists {
            dismissRegion.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        _ = taskDeleteConfirmButton.waitForNonExistence(timeout: 2)
    }

    /// Delete a Home task from its detail route; the route pops back to Home.
    func deleteTask(containingTitle title: String) {
        guard requestDeletion(containingTitle: title) else {
            XCTFail("Task '\(title)' should offer Delete from its task actions")
            return
        }
        taskDeleteConfirmButton.tap()
        _ = view.waitForExistence(timeout: 5)
    }

    func deleteTask(at index: Int) {
        let row = taskCell(at: index)
        revealOnHome(row)
        guard row.waitForExistence(timeout: 3) else {
            XCTFail("Home task row \(index) should exist before deleting it")
            return
        }
        tapElement(row)
        guard taskRouteNavigationBar.waitForExistence(timeout: 5), openTaskActions() else {
            XCTFail("Task route should expose its actions menu")
            return
        }
        guard taskDeleteAction.waitForExistence(timeout: 3) else {
            XCTFail("Task actions should offer Delete")
            return
        }
        taskDeleteAction.tap()
        guard taskDeleteConfirmButton.waitForExistence(timeout: 3) else {
            XCTFail("Delete should ask for confirmation")
            return
        }
        taskDeleteConfirmButton.tap()
        _ = view.waitForExistence(timeout: 5)
    }

    // MARK: - Verifications

    /// Verify the Home root is displayed.
    @discardableResult
    func verifyIsDisplayed(timeout: TimeInterval = 5) -> Bool {
        view.waitForExistence(timeout: timeout)
    }

    @discardableResult
    func verifyBottomBarExists(timeout: TimeInterval = 5) -> Bool {
        let dock = app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.compactChrome]
        let switcher = app.descendants(matching: .any)[AccessibilityIdentifiers.Shell.rootSwitcher]
        let predicate = NSPredicate { _, _ in dock.exists || switcher.exists }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Verify a task with this title is listed on Home.
    func verifyTaskExists(withTitle title: String) -> Bool {
        let row = taskRow(containingTitle: title)
        if row.exists {
            return true
        }
        revealOnHome(row)
        return taskRow(containingTitle: title).exists
    }

    /// Verify no task with this title is listed on Home.
    func verifyTaskDoesNotExist(withTitle title: String) -> Bool {
        !taskRow(containingTitle: title).exists
    }

    /// Number of task rows the Home tasks card currently shows.
    /// Open tasks on Home's Tasks card. The card shows a short preview until
    /// "Show more", so expand it first or the count stops at the preview.
    func getTaskCount() -> Int {
        let showMore = app.buttons[AccessibilityIdentifiers.Home.taskCardShowMore]
        if showMore.exists {
            revealOnHome(showMore)
            tapElement(showMore)
            _ = app.buttons[AccessibilityIdentifiers.Home.taskCardShowLess].waitForExistence(timeout: 2)
        }
        return taskRowQuery.count
    }

    func verifyTaskCount(_ expectedCount: Int, file: StaticString = #filePath, line: UInt = #line) {
        let actualCount = getTaskCount()
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) tasks, found \(actualCount)",
            file: file,
            line: line
        )
    }

    func verifyEmptyState() -> Bool {
        getTaskCount() == 0
    }

    // MARK: - Wait Helpers

    /// Wait for a task row with this title to appear on Home.
    @discardableResult
    func waitForTask(withTitle title: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if taskRow(containingTitle: title).exists {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        } while Date() < deadline
        revealOnHome(taskRow(containingTitle: title))
        return taskRow(containingTitle: title).exists
    }

    /// Wait for a task row with this title to leave Home.
    @discardableResult
    func waitForTaskToDisappear(withTitle title: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            self.taskRow(containingTitle: title).exists == false
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @discardableResult
    func waitForTaskCount(_ expectedCount: Int, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate { _, _ in
            self.getTaskCount() == expectedCount
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: - Private

    /// Scroll Home until `element` exists and is hittable, in small steps.
    private func revealOnHome(_ element: XCUIElement, maximumSteps: Int = 16) {
        guard view.exists else { return }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
        // Stop at the first check that finds it visible. A `for … where` form
        // re-evaluated both queries on every one of the steps even when the
        // element was already on screen, about a second per call.
        //
        // "Visible" means clear of the floating composer and dock at the bottom
        // (the lowest ~22% of the window): a control just under them still
        // reports hittable, then the tap lands on the chrome.
        let chromeTop = app.frame.height * 0.78
        func isClear() -> Bool {
            element.exists && element.isHittable && element.frame.maxY < chromeTop
        }
        var steps = 0
        while steps < maximumSteps, isClear() == false {
            start.press(forDuration: 0.05, thenDragTo: end)
            steps += 1
        }
        if steps > 0 {
            // Let the scroll view finish decelerating before anything taps.
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
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
}
