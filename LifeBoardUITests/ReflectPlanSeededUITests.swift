import XCTest

@MainActor
final class ReflectPlanSeededUITests: BaseUITest {
    private enum Seed {
        static let swapCandidateID = "22000000-0000-0000-0000-000000000007"
        static let postSeedRoute = "-LIFEBOARD_TEST_POST_SEED_ROUTE:daily_summary:nightly"
    }

    private var reflectPage: ReflectPlanPage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedReflectPlanSuite.rawValue,
            Seed.postSeedRoute
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        reflectPage = ReflectPlanPage(app: app)
        XCTAssertTrue(reflectPage.screen.waitForExistence(timeout: 12), "Post-seed nightly route should open Reflect & Plan.")
    }

    func testRouteOpensSeededReflectionAndPlanContext() throws {
        XCTAssertTrue(reflectPage.yesterdayCard.waitForExistence(timeout: 8), "Yesterday summary should render from seeded completed/open tasks.")
        XCTAssertTrue(reflectPage.todayCard.waitForExistence(timeout: 8), "Today plan should render from seeded planning candidates.")
        XCTAssertTrue(app.staticTexts["Reflect shipped proposal"].waitForExistence(timeout: 5), "Completed task should appear in the reflection summary.")
        XCTAssertTrue(app.staticTexts["Reflect carryover contract"].waitForExistence(timeout: 5), "Carryover task should appear in the plan.")
        XCTAssertTrue(app.staticTexts["Protect shutdown ritual"].waitForExistence(timeout: 5), "Seeded at-risk habit should appear in the plan context.")
    }

    func testContextEntryAndSavePersistCompletionAcrossRelaunch() throws {
        XCTAssertTrue(reflectPage.contextToggle.waitForExistence(timeout: 6), "Context toggle should be reachable.")
        reflectPage.tap(reflectPage.contextToggle)

        XCTAssertTrue(reflectPage.noteField.waitForExistence(timeout: 4), "Expanded context should expose a note field.")
        reflectPage.noteField.tap()
        reflectPage.noteField.typeText("Closed the loop and kept today narrow")

        reflectPage.tap(app.buttons[AccessibilityIdentifiers.ReflectPlan.mood("good")])
        reflectPage.tap(app.buttons[AccessibilityIdentifiers.ReflectPlan.energy("okay")])
        reflectPage.tap(app.buttons[AccessibilityIdentifiers.ReflectPlan.friction("too_much_planned")])

        XCTAssertTrue(reflectPage.saveButton.waitForExistence(timeout: 4), "Save button should remain sticky and reachable.")
        reflectPage.tap(reflectPage.saveButton)
        XCTAssertTrue(waitForElementToDisappear(reflectPage.screen, timeout: 10), "Saving should dismiss Reflect & Plan.")

        app.terminate()
        app.launchArguments.removeAll {
            $0 == XCUIApplication.LaunchArgumentKey.resetAppState.rawValue
                || $0 == XCUIApplication.LaunchArgumentKey.testSeedReflectPlanSuite.rawValue
        }
        app.launch()

        reflectPage = ReflectPlanPage(app: app)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.complete].waitForExistence(timeout: 12), "Saved reflection should persist as complete after relaunch.")
    }

    func testSwapSearchReplacesTopTaskBeforeSave() throws {
        let firstSwap = reflectPage.todayTaskSwap(index: 0)
        XCTAssertTrue(firstSwap.waitForExistence(timeout: 6), "Top plan row should expose a stable Swap control.")
        reflectPage.tap(firstSwap)

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.swapSheet].waitForExistence(timeout: 6), "Swap sheet should open.")
        XCTAssertTrue(reflectPage.swapSearchField.waitForExistence(timeout: 4), "Swap sheet should expose search.")
        reflectPage.swapSearchField.tap()
        reflectPage.swapSearchField.typeText("Plan swap")

        let useCandidate = reflectPage.swapOptionUse(id: Seed.swapCandidateID)
        XCTAssertTrue(useCandidate.waitForExistence(timeout: 5), "Seeded swap candidate should be filterable by title.")
        reflectPage.tap(useCandidate)

        XCTAssertTrue(app.staticTexts["Plan swap candidate"].waitForExistence(timeout: 5), "Selected candidate should replace a visible plan row before save.")
    }
}

@MainActor
final class ReflectPlanCompletedSeededUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedReflectPlanSuite.rawValue,
            XCUIApplication.LaunchArgumentKey.testReflectPlanCompleted.rawValue,
            "-LIFEBOARD_TEST_POST_SEED_ROUTE:daily_summary:nightly"
        ]
    }

    func testAlreadyCompletedReflectionShowsCompleteState() throws {
        let complete = app.descendants(matching: .any)[AccessibilityIdentifiers.ReflectPlan.complete]
        XCTAssertTrue(complete.waitForExistence(timeout: 12), "Pre-completed reflection seed should render the closed-out state.")
        XCTAssertTrue(app.staticTexts["You're already closed out."].waitForExistence(timeout: 4))
    }
}
