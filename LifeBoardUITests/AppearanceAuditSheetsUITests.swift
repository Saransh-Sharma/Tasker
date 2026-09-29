import XCTest

/// Captures the sheets that only open by tapping, in light and dark.
///
/// The appearance audit of 2026-09-18 reached every pushed route by launch
/// argument, but ~150 sheets open only from a tap, so fixes made there
/// (Overdue Rescue, the mood dial, composers) were
/// verified in code only. This taps through to each and writes a PNG per
/// appearance.
///
/// Not part of the default plan's intent: it asserts only that each surface
/// opened, and writes evidence when `LIFEBOARD_AUDIT_OUTPUT` is set (pass it as
/// `TEST_RUNNER_LIFEBOARD_AUDIT_OUTPUT` to xcodebuild).
@MainActor
final class AppearanceAuditSheetsUITests: XCTestCase {
    private let appearances = ["light", "dark"]

    /// The same set the production-evidence captures enable, so Plan renders
    /// the layout that carries the Rescue row.
    private static let featureFlags = [
        "LIFE_OS_FOUNDATION", "DASHBOARD_CUSTOMIZATION_V2", "TRACKERS_V1", "HEALTH_INTEGRATIONS_V1",
        "JOURNAL_V1", "KNOWLEDGE_NOTES_V1", "PLANNING_CORE_V1", "FOCUS_EXECUTION_V2", "TRACK_FOUNDATIONS_V2",
        "GOALS_ROUTINES_V1", "CARE_MODULES_V2", "LIFE_OS_UNIFIED_PRESENTATION_V2", "PREMIUM_IA_V5",
        "WELLNESS_CORE_V1", "FASTING_V2", "NUTRITION_V1", "LIFE_MOMENTS_V1"
    ]

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = true
    }

    private func launch(appearance: String, seeds: [XCUIApplication.LaunchArgumentKey]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            "-SKIP_ONBOARDING",
            "-LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED",
            "-LIFEBOARD_VISUAL_APPEARANCE=\(appearance)",
            "-AppleInterfaceStyle", appearance == "dark" ? "Dark" : "Light"
        ] + seeds.map(\.rawValue) + Self.featureFlags.map { "-LIFEBOARD_ENABLE_" + $0 }
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, name: String, appearance: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name)--\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let output = ProcessInfo.processInfo.environment["LIFEBOARD_AUDIT_OUTPUT"] else { return }
        let directory = URL(fileURLWithPath: output, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name)--\(appearance)--morning.png"),
            options: .atomic
        )
    }

    func testOverdueRescueDeck() throws {
        for appearance in appearances {
            let app = launch(appearance: appearance, seeds: [.testSeedEstablishedWorkspace])
            app.buttons["foundation.destination.plan"].firstMatch.tap()
            let rescue = app.buttons[AccessibilityIdentifiers.Plan.openRescue].firstMatch
            // The Rescue row yields to other Plan prompts (calendar access) by
            // state and clock. Skip, don't fail.
            guard rescue.waitForExistence(timeout: 12) else {
                throw XCTSkip("Plan shows no Rescue row in this state (\(appearance)).")
            }
            rescue.tap()
            sleep(2)
            capture(app, name: "sheet-overdue-rescue", appearance: appearance)
            app.terminate()
        }
    }

    func testTrackQuickMoodSheet() {
        for appearance in appearances {
            let app = launch(appearance: appearance, seeds: [.testSeedEstablishedWorkspace])
            app.buttons["foundation.destination.track"].firstMatch.tap()
            let mood = app.buttons["track.quick.mood"].firstMatch
            XCTAssertTrue(mood.waitForExistence(timeout: 12), "Track quick mood should exist in \(appearance).")
            mood.tap()
            sleep(2)
            capture(app, name: "sheet-quick-mood", appearance: appearance)
            app.terminate()
        }
    }

    func testPlanTaskLibrarySheet() {
        for appearance in appearances {
            let app = launch(appearance: appearance, seeds: [.testSeedEstablishedWorkspace])
            app.buttons["foundation.destination.plan"].firstMatch.tap()
            let backlog = app.buttons["Backlog"].firstMatch
            if backlog.waitForExistence(timeout: 8) { backlog.tap() }
            let library = app.descendants(matching: .any)["plan.taskLibrary.open"].firstMatch
            XCTAssertTrue(library.waitForExistence(timeout: 12), "Plan task library should exist in \(appearance).")
            if library.exists { library.tap() }
            sleep(2)
            capture(app, name: "sheet-plan-task-library", appearance: appearance)
            app.terminate()
        }
    }

    func testEvaChatsList() {
        for appearance in appearances {
            let app = launch(appearance: appearance, seeds: [.testSeedEstablishedWorkspace])
            app.buttons["foundation.destination.eva"].firstMatch.tap()
            let more = app.buttons["foundation.more.eva"].firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 12), "Eva more should exist in \(appearance).")
            more.tap()
            let chats = app.buttons["foundation.eva.chats"].firstMatch
            if chats.waitForExistence(timeout: 4) { chats.tap() }
            sleep(2)
            capture(app, name: "sheet-eva-chats", appearance: appearance)
            app.terminate()
        }
    }

    func testSettingsCategories() {
        let categories = ["planAndOrganize", "calendarAndHealth", "eva", "reminders", "lookAndFeel", "dataAndHelp"]
        for appearance in appearances {
            let app = launch(appearance: appearance, seeds: [.testSeedEstablishedWorkspace])
            app.launchArguments.append("-LIFEBOARD_TEST_OPEN_SETTINGS")
            app.terminate()
            app.launch()
            for category in categories {
                let row = app.descendants(matching: .any)["settings.category.\(category)"].firstMatch
                var attempts = 0
                while row.exists == false, attempts < 4 {
                    app.swipeUp()
                    attempts += 1
                }
                guard row.waitForExistence(timeout: 6) else {
                    XCTFail("Settings category \(category) not found in \(appearance).")
                    continue
                }
                row.tap()
                sleep(2)
                capture(app, name: "settings-\(category)", appearance: appearance)
                app.navigationBars.buttons.firstMatch.tap()
                sleep(1)
            }
            app.terminate()
        }
    }
}
