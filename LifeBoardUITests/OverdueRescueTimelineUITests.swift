import XCTest

@MainActor
final class OverdueRescueTimelineUITests: BaseUITest {
    private enum Seed {
        static let rescuedTaskID = "20000000-0000-0000-0000-000000000101"
        static let rescuedTaskTitle = "Rescue timeline quick win"
    }

    private var homePage: HomePage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.enableDebugLogging.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedRescueTimelineWorkspace.rawValue
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
    }

    func testKeepTodayFromRescueShowsTaskOnTodayTimeline() throws {
        let timelineTaskID = AccessibilityIdentifiers.Home.timelineTask(Seed.rescuedTaskID)
        let rescueCardID = AccessibilityIdentifiers.Home.rescueCard(Seed.rescuedTaskID)

        XCTAssertFalse(app.descendants(matching: .any)[timelineTaskID].exists, "Seeded overdue task should not appear on Today timeline before rescue.")

        openRescueSheet(rescueCardID: rescueCardID)

        XCTAssertTrue(
            app.descendants(matching: .any)[rescueCardID].waitForExistence(timeout: 8),
            "Rescue sheet should show the seeded overdue task card."
        )

        let keepToday = app.buttons[AccessibilityIdentifiers.Home.rescueActionKeepToday]
        XCTAssertTrue(keepToday.waitForExistence(timeout: 5), "Rescue card should expose a stable Keep Today action.")
        tapElement(keepToday)

        let viewToday = app.buttons[AccessibilityIdentifiers.Home.rescueCompletionViewToday]
        if viewToday.waitForExistence(timeout: 5) {
            tapElement(viewToday)
        } else {
            let close = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Close' OR identifier == %@", "home.rescue.close")
            ).firstMatch
            if close.exists {
                tapElement(close)
            }
        }

        XCTAssertTrue(
            waitForTimelineTask(identifier: timelineTaskID, timeout: 12),
            "Keep Today should move the overdue task into Today timeline."
        )
        let rescuedTimelineTask = app.descendants(matching: .any)[timelineTaskID]
        XCTAssertNotEqual(
            String(describing: rescuedTimelineTask.value ?? ""),
            "All-day item",
            "Timed rescue tasks should keep their original time and render as scheduled timeline rows."
        )
        let allDayStrip = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineAllDayStrip]
        if allDayStrip.exists {
            XCTAssertFalse(
                allDayStrip.descendants(matching: .any)[timelineTaskID].exists,
                "Timed rescue tasks should not render inside the all-day strip."
            )
        }
        XCTAssertTrue(
            waitForRescueSectionToClear(timeout: 8),
            "Rescued task should leave the overdue rescue section after reload."
        )
    }

    private func openRescueSheet(rescueCardID: String) {
        if app.descendants(matching: .any)[rescueCardID].waitForExistence(timeout: 2) {
            return
        }
        let deadline = Date().addingTimeInterval(35)
        while Date() < deadline {
            if homePage.rescueStartButton.exists {
                tapElement(homePage.rescueStartButton)
                XCTAssertTrue(homePage.rescueSheet.waitForExistence(timeout: 8), "Rescue sheet should open.")
                return
            }
            if homePage.rescueOpenButton.exists {
                tapElement(homePage.rescueOpenButton)
                XCTAssertTrue(homePage.rescueSheet.waitForExistence(timeout: 8), "Rescue sheet should open.")
                return
            }
            homeScrollElement().swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let debugCounts = app.descendants(matching: .any)["home.debug.counts"]
        let countsValue = debugCounts.exists ? String(describing: debugCounts.value ?? "nil") : "missing"
        XCTFail("Home should expose the overdue rescue launcher for the seeded task. counts=\(countsValue)")
    }

    private func waitForTimelineTask(identifier: String, timeout: TimeInterval) -> Bool {
        let task = app.descendants(matching: .any)[identifier]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if task.exists {
                return true
            }
            homeScrollElement().swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return task.exists
    }

    private func waitForRescueSectionToClear(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let rescueSectionExists = homePage.rescueSection.exists
            let rescueRowExists = homePage.rescueRow(containingTitle: Seed.rescuedTaskTitle).exists
            if rescueSectionExists == false || rescueRowExists == false {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return homePage.rescueSection.exists == false || homePage.rescueRow(containingTitle: Seed.rescuedTaskTitle).exists == false
    }

    private func homeScrollElement() -> XCUIElement {
        let taskList = app.scrollViews[AccessibilityIdentifiers.Home.taskListScrollView]
        if taskList.exists {
            return taskList
        }
        let timeline = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineContent]
        if timeline.exists {
            return timeline
        }
        return app.scrollViews.firstMatch
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
