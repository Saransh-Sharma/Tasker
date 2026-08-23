import XCTest

/// The v6 "Life Weave" first run.
///
/// This file previously drove the nine-step flow that was deleted two redesigns
/// ago — it asserted "Step 2 of 9" and tapped `onboarding.primaryGoal.*`
/// identifiers that no longer exist anywhere in the app target, so it could not
/// have passed. It went unnoticed because CI runs `-only-testing:LifeBoardTests`
/// and no UI test is in the gate at all.
///
/// v6 is on by default in Debug, so these need no flag argument. The v5 walk is
/// pinned explicitly where it is still needed (`ChatPlanApplyUndoTests`).
final class LifeWeaveOnboardingUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    private var flow: XCUIElement { app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.flow] }
    private var primary: XCUIElement { app.buttons[AccessibilityIdentifiers.LifeWeave.primaryAction] }
    private var secondary: XCUIElement { app.buttons[AccessibilityIdentifiers.LifeWeave.secondaryAction] }

    private func step(_ suffix: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.step(suffix)]
    }

    /// Six decisions, then Home. The point of the walk is that each step accepts
    /// a real answer and the flow ends — not that any particular pixel appears.
    func testCoreFlowReachesTheRevealInSixSteps() throws {
        guard flow.waitForExistence(timeout: 20) else {
            throw XCTSkip("Onboarding did not present; this test needs a clean install. \(app.debugDescription)")
        }

        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        primary.tap()

        // Intent — the primary stays disabled until something is chosen, which
        // is the contract that stops a blank answer reaching the profile.
        XCTAssertTrue(step("intent").waitForExistence(timeout: 10))
        XCTAssertFalse(primary.isEnabled, "Continue must not be available before an intent is picked")
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch.tap()
        XCTAssertTrue(primary.isEnabled)
        primary.tap()

        // Life areas — two is the stated minimum, so one must not advance.
        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("work-career")].firstMatch.tap()
        XCTAssertFalse(primary.isEnabled, "one area is below the stated 2–5 minimum")
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("health-self")].firstMatch.tap()
        XCTAssertTrue(primary.isEnabled)
        primary.tap()

        XCTAssertTrue(step("dayShape").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.dayShapePreset("typical")].firstMatch.tap()
        primary.tap()

        XCTAssertTrue(step("firstCapture").waitForExistence(timeout: 10))
        secondary.tap() // Skip for now
        primary.tap() // Finish setup

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.revealReceipt].exists,
            "the reveal must show what was actually saved"
        )
        primary.tap()

        XCTAssertTrue(flow.waitForNonExistence(timeout: 15), "Start my day must leave onboarding")
    }

    /// A skipped capture is an honest empty state, never a fabricated task.
    func testSkippingCaptureStillProducesAWorkspace() throws {
        guard flow.waitForExistence(timeout: 20) else {
            throw XCTSkip("Onboarding did not present. \(app.debugDescription)")
        }
        try walkToCapture()
        secondary.tap()
        primary.tap()

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        let receipt = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.revealReceipt]
        XCTAssertTrue(receipt.exists)
        XCTAssertFalse(
            receipt.label.contains("captured"),
            "nothing was captured, so the receipt must not claim anything was"
        )
    }

    /// Back moves the step and leaves the answers alone.
    func testBackDoesNotDestroyAnAnswer() throws {
        guard flow.waitForExistence(timeout: 20) else {
            throw XCTSkip("Onboarding did not present. \(app.debugDescription)")
        }
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        primary.tap()

        XCTAssertTrue(step("intent").waitForExistence(timeout: 10))
        let choice = app.buttons[AccessibilityIdentifiers.LifeWeave.intent("reduceMentalLoad")].firstMatch
        choice.tap()
        primary.tap()

        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.back].tap()

        XCTAssertTrue(step("intent").waitForExistence(timeout: 10))
        XCTAssertTrue(primary.isEnabled, "returning to a step must find the answer still there")
    }

    /// The map is one semantic element, not a pile of decorative paths.
    func testLifeMapIsSummarisedRatherThanExploded() throws {
        guard flow.waitForExistence(timeout: 20) else {
            throw XCTSkip("Onboarding did not present. \(app.debugDescription)")
        }
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        let canvas = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.canvas]
        XCTAssertTrue(canvas.exists)
        XCTAssertTrue(
            canvas.label.contains("Life Map"),
            "the map must publish one summary; VoiceOver cannot see geometry"
        )
    }

    private func walkToCapture() throws {
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        primary.tap()
        XCTAssertTrue(step("intent").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch.tap()
        primary.tap()
        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("work-career")].firstMatch.tap()
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("health-self")].firstMatch.tap()
        primary.tap()
        XCTAssertTrue(step("dayShape").waitForExistence(timeout: 10))
        primary.tap()
        XCTAssertTrue(step("firstCapture").waitForExistence(timeout: 10))
    }
}

/// Restart and the established-workspace invitation are flow-agnostic: they are
/// about *whether* onboarding presents, not which journey it presents.
final class OnboardingPresentationUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { true }

    /// A completed workspace is never interrupted by a launch prompt.
    func testCompletedWorkspaceIsNotInterrupted() {
        let flow = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.flow]
        let legacy = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeMap.flow]
        XCTAssertFalse(flow.waitForExistence(timeout: 4))
        XCTAssertFalse(legacy.exists)
    }
}

/// Guards the exact regression where the shell composer covered EVA's Setup
/// Center action. The route is deterministic and does not depend on a live
/// Cloud EVA backend, so layout coverage stays useful in CI.
final class SetupCenterEvaReachabilityUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testOpenSetupCenter.rawValue,
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
    }

    func testRecommendedActionClearsRootChromeAtAccessibilityXXXL() {
        let privacyAcknowledgement = app.buttons["Got it"]
        if privacyAcknowledgement.waitForExistence(timeout: 3) {
            privacyAcknowledgement.tap()
        }
        XCTAssertTrue(app.navigationBars["Setup Center"].waitForExistence(timeout: 15))
        XCTAssertFalse(
            app.descendants(matching: .any)["home.lifeThread.composer"].exists,
            "utility routes must not mount the global LifeThread composer"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["LifeBoardCompactChrome"].exists,
            "utility routes must not mount the root dock"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["onboarding.tip.home"].exists,
            "a root-only onboarding tip must be cleared when Setup Center is pushed"
        )

        let actionIdentifiers = [
            "setupCenter.calendar.action",
            "setupCenter.health.action",
            "setupCenter.eva.activate",
            "setupCenter.eva.retry",
            "setupCenter.eva.reconnectApple",
            "setupCenter.eva.offline"
        ]
        var recommendedAction: XCUIElement?
        for identifier in actionIdentifiers {
            let candidate = app.buttons[identifier]
            if candidate.waitForExistence(timeout: 2) {
                recommendedAction = candidate
                break
            }
        }
        XCTAssertNotNil(recommendedAction, "Setup Center must expose its recommended action")
        XCTAssertTrue(recommendedAction?.isHittable == true, "the recommended action must be visible without a window-level swipe workaround")
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists == false { return true }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tick")], timeout: 0.25)
        }
        return exists == false
    }
}
