import XCTest

/// The hardware-keyboard contract on iPad (and Mac Catalyst, which runs the
/// same main menu): ⌘1–5 switch roots, ⌘N opens a capture, Esc closes it.
///
/// Before the menu bar existed these shortcuts were hidden SwiftUI buttons that
/// only lived in the expanded shell, Esc did nothing anywhere, and ⌘N was bound
/// twice. Nothing tested any of it.
final class HardwareKeyboardUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
        // XCUITest's `typeKey(_:modifierFlags:)` on the iOS simulator never
        // reaches UIKit's main-menu key commands: `buildMenu` runs (File, View
        // and Window present) but `canPerformAction` is never asked, so the
        // shell cannot tell a missing shortcut from an undelivered key. Verified
        // by hand on Mac Catalyst instead (⌘2 → Plan, ⌘N → New Task sheet,
        // 2026-09-25). Run this suite against the Mac Catalyst destination.
        throw XCTSkip("Main-menu key commands are not delivered by XCUITest on the iOS simulator")
        #endif
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-RESET_APP_STATE",
            "-UI_TESTING",
            "-SKIP_ONBOARDING",
            "-DISABLE_CLOUD_SYNC",
            "-LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED",
            "-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE",
            "-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION",
            "-LIFEBOARD_ENABLE_PLANNING_CORE_V1",
            "-LIFEBOARD_ENABLE_JOURNAL_V1",
            "-LIFEBOARD_ENABLE_KNOWLEDGE_NOTES_V1",
            "-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2",
            "-LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2"
        ]
        app.launch()
        // The first launch after a fresh install can land on onboarding despite
        // `-SKIP_ONBOARDING`; one relaunch with the same arguments lands on the shell.
        if app.descendants(matching: .any)["onboarding.lifeweave.flow"].waitForExistence(timeout: 2) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["home.header"].waitForExistence(timeout: 15),
            "Home should be the first root"
        )
    }

    override func tearDownWithError() throws {
        app?.terminate()
    }

    func testCommandNumberSwitchesRoots() throws {
        for (key, root) in [("2", "plan"), ("3", "track"), ("4", "insights"), ("5", "eva"), ("1", "home")] {
            app.typeKey(key, modifierFlags: .command)
            XCTAssertTrue(
                app.descendants(matching: .any)["\(root).header"].waitForExistence(timeout: 5),
                "⌘\(key) should open \(root)"
            )
        }
    }

    func testCommandNOpensCaptureAndEscapeClosesIt() throws {
        app.typeKey("n", modifierFlags: .command)
        let cancel = app.buttons["addTask.cancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "⌘N should open the task capture")

        // The title field is focused. One Esc closes the sheet anyway: the app's
        // Esc command outranks the field (`SheetEscapeRouter`).
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(
            waitForDisappearance(of: cancel, timeout: 5),
            "One Esc should close the capture sheet even with the title field focused"
        )
    }

    func testCommandNOnEvaStartsAChatInsteadOfATask() throws {
        app.typeKey("5", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["eva.header"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertFalse(
            app.buttons["addTask.cancelButton"].waitForExistence(timeout: 2),
            "⌘N on Eva starts a new chat, not a task capture"
        )
    }

    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
