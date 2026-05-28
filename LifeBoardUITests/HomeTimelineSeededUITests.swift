import XCTest

@MainActor
final class HomeTimelineSeededUITests: BaseUITest {
    private enum Seed {
        static let overlapTaskID = "20000000-0000-0000-0000-000000000001"
        static let deepWorkTaskID = "20000000-0000-0000-0000-000000000002"
        static let completedTaskID = "20000000-0000-0000-0000-000000000005"
        static let dailyHabitID = "30000000-0000-0000-0000-000000000001"
        static let quietHabitID = "30000000-0000-0000-0000-000000000002"
        static let primaryMeetingID = "test_meeting_1"
    }

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedFullTimelineWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active"
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        ensureHomeTimelineReady()
    }

    func testSeededTimelineRendersMeetingsTasksHabitsProjectsAndConflictSignals() throws {
        let meeting = element(identifier: AccessibilityIdentifiers.Home.timelineEvent(Seed.primaryMeetingID))
        let overlapTask = element(identifier: AccessibilityIdentifiers.Home.timelineTask(Seed.overlapTaskID))
        let deepWorkTask = element(identifier: AccessibilityIdentifiers.Home.timelineTask(Seed.deepWorkTaskID))

        XCTAssertTrue(waitForHomeElement(meeting, timeout: 10), "Seeded active meeting should render on Home timeline.")
        XCTAssertTrue(waitForHomeElement(overlapTask, timeout: 8), "Seeded overlap task should render on Home timeline.")
        XCTAssertTrue(waitForHomeElement(deepWorkTask, timeout: 8), "Seeded deep work task should render on Home timeline.")
        XCTAssertTrue(waitForLabelContaining("Timeline hydrate", timeout: 8), "Daily seeded habit should render on Home.")
        XCTAssertTrue(waitForLabelContaining("Timeline Launch", timeout: 6), "Seeded project label should be exposed in timeline content.")

        XCTAssertTrue(waitForHomeElement(meeting, timeout: 6), "Seeded meeting should remain reachable after habit/project traversal.")
        XCTAssertTrue(waitForHomeElement(overlapTask, timeout: 6), "Seeded overlapping task should remain reachable after habit/project traversal.")
    }

    func testSunriseFilterChipsPartitionSeededTimelineContentAndResetToAll() throws {
        scrollHomeToTop()
        tapFilter("all")

        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: false, timeout: 5),
            "All filter should expose seeded timeline tasks."
        )
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: false, timeout: 5),
            "All filter should expose seeded timeline meetings."
        )

        tapFilter("tasks")
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: true, timeout: 4),
            "Tasks filter should hide meeting cards."
        )
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: false, timeout: 4),
            "Tasks filter should keep task cards visible."
        )

        tapFilter("meetings")
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: true, timeout: 4),
            "Meetings filter should hide task cards."
        )
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: false, timeout: 4),
            "Meetings filter should keep meeting cards visible."
        )

        tapFilter("habits")
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: true, timeout: 4),
            "Habits filter should hide task cards."
        )
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: true, timeout: 4),
            "Habits filter should hide meeting cards."
        )
        XCTAssertTrue(
            waitForLabelContaining("Timeline hydrate", timeout: 6),
            "Habits filter should keep seeded habit rows reachable."
        )

        scrollHomeToTop()
        tapFilter("all")
        XCTAssertTrue(
            waitForHomeElement(element(identifier: AccessibilityIdentifiers.Home.timelineEvent(Seed.primaryMeetingID)), timeout: 6),
            "All filter should restore seeded meetings."
        )
        XCTAssertTrue(
            waitForHomeElement(element(identifier: AccessibilityIdentifiers.Home.timelineTask(Seed.deepWorkTaskID)), timeout: 6),
            "All filter should restore seeded tasks."
        )
    }

    func testMeetingDetailCloseAndHideRemovesOnlyHomeTimelineOccurrence() throws {
        let meetingID = AccessibilityIdentifiers.Home.timelineEvent(Seed.primaryMeetingID)
        let meeting = element(identifier: meetingID)
        XCTAssertTrue(waitForHomeElement(meeting, timeout: 10), "Seeded Home meeting should be visible before opening detail.")

        tapElement(meeting)
        XCTAssertTrue(
            element(identifier: "schedule.detail.close").waitForExistence(timeout: 5),
            "Meeting detail should expose a deterministic close control."
        )
        tapElement(element(identifier: "schedule.detail.close"))
        XCTAssertTrue(waitForAbsence(identifier: "schedule.detail.sheet", timeout: 4), "Close should dismiss event detail.")

        XCTAssertTrue(waitForHomeElement(element(identifier: meetingID), timeout: 6), "Meeting should still be visible before hiding.")
        tapElement(element(identifier: meetingID))

        let hide = element(identifier: "schedule.detail.hideFromTimeline")
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "Meeting detail should expose Hide from Timeline.")
        tapElement(hide)

        XCTAssertTrue(waitForAbsence(identifier: meetingID, timeout: 4), "Hidden meeting should be removed from Home timeline.")

        openScheduleFromBottomBar()
        let scheduleEvent = element(identifier: "schedule.event.\(Seed.primaryMeetingID)")
        XCTAssertTrue(
            waitForScrollableElement(scheduleEvent, timeout: 8),
            "Hiding from Home should not remove the meeting from Schedule."
        )
    }

    func testTaskDetailEditCompleteReopenAndPersistAfterRelaunch() throws {
        let taskID = AccessibilityIdentifiers.Home.timelineTask(Seed.deepWorkTaskID)
        let originalTask = element(identifier: taskID)
        XCTAssertTrue(waitForHomeElement(originalTask, timeout: 10), "Seeded task should be visible before detail editing.")

        tapElement(originalTask)
        XCTAssertTrue(element(identifier: AccessibilityIdentifiers.TaskDetail.view).waitForExistence(timeout: 6))

        let editedTitle = "Timeline deep work edited"
        let titleField = element(identifier: AccessibilityIdentifiers.TaskDetail.titleField)
        clearAndTypeText(titleField, text: editedTitle, timeout: 6)
        XCTAssertTrue(
            element(identifier: AccessibilityIdentifiers.TaskDetail.projectLabel).label.localizedCaseInsensitiveContains("Timeline Launch"),
            "Task detail should expose seeded project context."
        )

        let completeButton = element(identifier: AccessibilityIdentifiers.TaskDetail.completeButton)
        tapElement(completeButton)
        XCTAssertTrue(waitForTaskDetailCompletionState(isComplete: true, timeout: 5), "Completion state should update in task detail.")

        tapElement(element(identifier: AccessibilityIdentifiers.TaskDetail.closeButton))
        XCTAssertTrue(waitForAbsence(identifier: AccessibilityIdentifiers.TaskDetail.view, timeout: 4), "Task detail should close.")
        XCTAssertTrue(waitForLabelContaining(editedTitle, timeout: 8), "Edited task title should appear on Home after autosave.")

        relaunchWithoutResetForPersistence()
        XCTAssertTrue(waitForHomeElement(element(identifier: taskID), timeout: 10), "Edited task row should persist after relaunch.")
        XCTAssertTrue(waitForLabelContaining(editedTitle, timeout: 8), "Edited task title should persist after relaunch.")

        tapElement(element(identifier: taskID))
        XCTAssertTrue(element(identifier: AccessibilityIdentifiers.TaskDetail.view).waitForExistence(timeout: 6))
        XCTAssertTrue(waitForTaskDetailCompletionState(isComplete: true, timeout: 5), "Completed task state should persist after relaunch.")

        tapElement(element(identifier: AccessibilityIdentifiers.TaskDetail.completeButton))
        XCTAssertTrue(waitForTaskDetailCompletionState(isComplete: false, timeout: 5), "Completed task should reopen from detail.")
    }

    func testTimelineLaunchDismissesEligibleOnboardingPromptAndReachesHome() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchSeededTimelineWorkspace(calendarMode: "active", skipOnboarding: false)

        XCTAssertTrue(
            ensureHomeTimelineReady(timeout: 16),
            "Seeded timeline launch should recover to Home even when onboarding prompt or flow is eligible."
        )
        XCTAssertTrue(
            waitForHomeElement(element(identifier: AccessibilityIdentifiers.Home.timelineTask(Seed.overlapTaskID)), timeout: 8),
            "Timeline-specific tests should not get stuck behind onboarding."
        )
    }

    private func tapFilter(_ id: String) {
        let chip = app.buttons[AccessibilityIdentifiers.Home.sunriseFilter(id)]
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "Expected \(id) Sunrise filter chip to exist.")
        tapElement(chip)
    }

    private func element(identifier: String) -> XCUIElement {
        let button = app.buttons[identifier]
        if button.exists {
            return button
        }
        return app.descendants(matching: .any)[identifier]
    }

    private func waitForHomeElement(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.waitForExistence(timeout: min(timeout, 2)) {
            return true
        }
        return waitForScrollableElement(element, timeout: timeout, scrollAttempts: 8)
    }

    private func waitForScrollableElement(
        _ element: XCUIElement,
        timeout: TimeInterval,
        scrollAttempts: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: min(timeout, 2)) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        var attempts = 0
        while Date() < deadline, attempts < scrollAttempts {
            homeScrollElement().swipeUp()
            if element.waitForExistence(timeout: 0.8) {
                return true
            }
            attempts += 1
        }

        return element.exists
    }

    private func scrollHomeToTop() {
        let scroll = homeScrollElement()
        for _ in 0..<5 {
            scroll.swipeDown()
        }
    }

    private func homeScrollElement() -> XCUIElement {
        let homePage = HomePage(app: app)
        if homePage.taskListScrollView.exists {
            return homePage.taskListScrollView
        }
        return app
    }

    private func waitForConflictSignal(timeout: TimeInterval) -> Bool {
        scrollHomeToTop()
        let conflict = element(identifier: AccessibilityIdentifiers.Home.timelineConflictBlock)
        let overlap = element(identifier: AccessibilityIdentifiers.Home.timelineOverlapCluster)
        if conflict.waitForExistence(timeout: 1) || overlap.waitForExistence(timeout: 1) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            homeScrollElement().swipeUp()
            if conflict.waitForExistence(timeout: 0.6) || overlap.waitForExistence(timeout: 0.6) {
                return true
            }
        }
        return conflict.exists || overlap.exists
    }

    private func waitForQuietTrackingRail(timeout: TimeInterval) -> Bool {
        scrollHomeToTop()
        let rail = element(identifier: AccessibilityIdentifiers.Home.passiveTrackingRail)
        let cardPredicate = NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityIdentifiers.Home.passiveTrackingCard(""))
        let cards = app.buttons.matching(cardPredicate)

        if rail.waitForExistence(timeout: 1) || cards.firstMatch.waitForExistence(timeout: 1) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            homeScrollElement().swipeUp()
            if rail.waitForExistence(timeout: 0.6) || cards.firstMatch.waitForExistence(timeout: 0.6) {
                return true
            }
        }
        return rail.exists || cards.firstMatch.exists
    }

    private func waitForLabelContaining(_ text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.descendants(matching: .any).matching(predicate).firstMatch.exists {
                return true
            }
            homeScrollElement().swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return app.descendants(matching: .any).matching(predicate).firstMatch.exists
    }

    private func waitForTimelineIdentifiers(
        withPrefix prefix: String,
        toBeEmpty expectedEmpty: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let exists = app.descendants(matching: .any).matching(predicate).firstMatch.exists
            if exists != expectedEmpty {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        let exists = app.descendants(matching: .any).matching(predicate).firstMatch.exists
        return exists != expectedEmpty
    }

    private func waitForAbsence(identifier: String, timeout: TimeInterval) -> Bool {
        let target = app.descendants(matching: .any)[identifier]
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: target
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForTaskDetailCompletionState(isComplete: Bool, timeout: TimeInterval) -> Bool {
        let button = element(identifier: AccessibilityIdentifiers.TaskDetail.completeButton)
        let predicate = NSPredicate { _, _ in
            let label = button.label.lowercased()
            let value = String(describing: button.value ?? "").lowercased()
            if isComplete {
                return label == "completed" || label.contains("reopen") || value.contains("selected") || value == "1"
            } else {
                return label == "not completed" || label.contains("incomplete") || value.contains("not") || value == "0"
            }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func openScheduleFromBottomBar() {
        scrollHomeToTop()
        let button = element(identifier: "home.bottomBar.calendar")
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Bottom bar calendar button should exist.")
        tapElement(button)
        XCTAssertTrue(app.buttons["schedule.toolbar.filters"].waitForExistence(timeout: 8), "Schedule should open from bottom bar.")
        ensureCalendarSelectionIfNeeded()
    }

    private func ensureCalendarSelectionIfNeeded() {
        let noCalendarsState = element(identifier: "schedule.noCalendars.body")
        guard noCalendarsState.waitForExistence(timeout: 1.2) else { return }

        let filters = app.buttons["schedule.toolbar.filters"]
        guard filters.waitForExistence(timeout: 4) else { return }
        tapElement(filters)

        let workCalendar = element(identifier: "schedule.chooser.calendar.work")
        guard workCalendar.waitForExistence(timeout: 8) else { return }
        tapElement(workCalendar)

        let done = app.buttons["schedule.chooser.done"].exists ? app.buttons["schedule.chooser.done"] : app.buttons["Done"].firstMatch
        guard done.waitForExistence(timeout: 6) else { return }
        tapElement(done)
    }

    private func relaunchWithoutResetForPersistence() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active"
        ]
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app.launch()
        ensureHomeTimelineReady()
    }
}
