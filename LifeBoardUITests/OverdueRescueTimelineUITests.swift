import XCTest

/// Keeping overdue work for today from the Overdue Rescue deck.
///
/// The deck opens from Plan's day (`plan.day.openRescue`), and kept work lands
/// in Plan's day. Home no longer has its own timeline or rescue section.
@MainActor
final class OverdueRescueTimelineUITests: BaseUITest {
    private enum Seed {
        static let rescuedTaskID = "20000000-0000-0000-0000-000000000101"
        static let rescuedTaskTitle = "Rescue timeline quick win"
    }

    private var homePage: HomePage!
    private var rescuePage: OverdueRescuePage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.enableDebugLogging.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedRescueTimelineWorkspace.rawValue
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
        rescuePage = OverdueRescuePage(app: app, homePage: homePage)
    }

    func testKeepTodayFromRescueShowsTaskOnTodayTimeline() throws {
        XCTAssertTrue(
            rescuePage.open(cardID: Seed.rescuedTaskID),
            "Plan's Rescue entry should open the deck on the seeded overdue task."
        )

        let keepToday = rescuePage.keepTodayButton
        XCTAssertTrue(keepToday.waitForExistence(timeout: 5), "Rescue card should expose a stable Keep Today action.")
        rescuePage.tap(keepToday)

        let viewToday = app.buttons[AccessibilityIdentifiers.Home.rescueCompletionViewToday]
        let close = app.buttons[AccessibilityIdentifiers.Home.rescueClose]
        if viewToday.waitForExistence(timeout: 5) {
            rescuePage.tap(viewToday)
        } else if close.waitForExistence(timeout: 3) {
            rescuePage.tap(close)
        }
        XCTAssertTrue(
            rescuePage.sheet.waitForNonExistence(timeout: 8),
            "Closing Rescue should return to Plan."
        )

        // Kept work with or without a time can render as a row or as an
        // Anytime chip, so match the title on any element.
        let keptTask = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", Seed.rescuedTaskTitle)
        ).firstMatch
        for _ in 0..<12 where keptTask.exists == false {
            app.swipeUp()
        }
        XCTAssertTrue(keptTask.waitForExistence(timeout: 12), "Keep Today should put the task in today's plan.")

        let rescueEntry = rescuePage.planRescueEntry
        if rescueEntry.exists {
            rescuePage.tap(rescueEntry)
            XCTAssertTrue(rescuePage.sheet.waitForExistence(timeout: 8), "Rescue should reopen while other work is overdue.")
            XCTAssertFalse(
                rescuePage.card(id: Seed.rescuedTaskID).waitForExistence(timeout: 3),
                "Rescued task should leave the overdue rescue deck."
            )
        }
    }
}
