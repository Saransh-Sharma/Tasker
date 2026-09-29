import XCTest

/// The four-screen first run: welcome and intent, life areas, one real thing,
/// Ready. Connections open as sheets over Ready and return there.
final class LifeWeaveOnboardingUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    private var flow: XCUIElement { app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.flow] }
    private var primary: XCUIElement { app.buttons[AccessibilityIdentifiers.LifeWeave.primaryAction] }
    private var secondary: XCUIElement { app.buttons[AccessibilityIdentifiers.LifeWeave.secondaryAction] }

    private func step(_ suffix: String) -> XCUIElement {
        app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.step(suffix)]
    }

    private func requireFlow() throws {
        guard flow.waitForExistence(timeout: 20) else {
            throw XCTSkip("Onboarding did not present; this test needs a clean install. \(app.debugDescription)")
        }
    }

    /// Four screens, then Home. Each screen accepts a real answer, and the
    /// primary says what is missing until it can act.
    func testCoreFlowReachesReadyInFourScreens() throws {
        try requireFlow()

        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        XCTAssertFalse(primary.isEnabled, "the primary must not act before an intent is picked")
        XCTAssertEqual(primary.label, "Pick one")
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch.tap()
        XCTAssertEqual(primary.label, "Continue")
        primary.tap()

        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        XCTAssertEqual(primary.label, "Pick 2 more")
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("work-career")].firstMatch.tap()
        XCTAssertFalse(primary.isEnabled, "one area is below the minimum of two")
        XCTAssertEqual(primary.label, "Pick 1 more")
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("health-self")].firstMatch.tap()
        XCTAssertTrue(primary.isEnabled)
        primary.tap()

        XCTAssertTrue(step("firstCapture").waitForExistence(timeout: 10))
        secondary.tap() // Skip

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.revealReceipt].exists,
            "Ready must show what was actually saved"
        )
        XCTAssertEqual(primary.label, "Start my day")
        primary.tap()

        XCTAssertTrue(flow.waitForNonExistence(timeout: 15), "Start my day must leave onboarding")
        XCTAssertFalse(
            app.descendants(matching: .any)["onboarding.tip.home"].waitForExistence(timeout: 3),
            "arriving at Home from Ready must not meet a tip about Home"
        )
    }

    /// Usual hours are never asked, so Ready does not list them (or offer to
    /// edit a choice the person never made).
    func testHoursAreEditedFromReadyNotAsked() throws {
        try requireFlow()
        try walkToCapture()
        secondary.tap()

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        let edit = app.buttons[AccessibilityIdentifiers.LifeWeave.hoursEdit]
        XCTAssertFalse(edit.waitForExistence(timeout: 2), "Ready must not show hours the flow never asked for")
    }

    /// The Cloud EVA disclosure is one line on Ready with the full detail a tap away.
    func testEvaDataUseIsOneTapFromReady() throws {
        try requireFlow()
        try walkToCapture()
        secondary.tap()

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        let notice = app.buttons["onboarding.eva.automaticDisclosure"]
        if notice.waitForExistence(timeout: 5) == false || notice.isHittable == false { app.swipeUp() }
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        notice.tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.eva.dataUse.sheet"].waitForExistence(timeout: 5))
    }

    /// A skipped capture is an honest empty state, never a fabricated task.
    func testSkippingCaptureStillProducesAWorkspace() throws {
        try requireFlow()
        try walkToCapture()
        secondary.tap()

        XCTAssertTrue(step("reveal").waitForExistence(timeout: 25))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.revealReceipt].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["onboarding.savedCapture"].exists,
            "nothing was captured, so Ready must not claim anything was"
        )
    }

    /// Back moves the step and leaves the answers alone.
    func testBackDoesNotDestroyAnAnswer() throws {
        try requireFlow()
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("reduceMentalLoad")].firstMatch.tap()
        primary.tap()

        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.back].tap()

        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        XCTAssertTrue(primary.isEnabled, "returning to a step must find the answer still there")
    }

    /// The map is one semantic element, not a pile of decorative paths.
    func testLifeMapIsSummarisedRatherThanExploded() throws {
        try requireFlow()
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch.tap()
        primary.tap()
        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        let canvas = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.canvas]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertTrue(
            canvas.label.contains("life areas"),
            "the map must publish one summary; VoiceOver cannot see geometry"
        )
    }

    private func walkToCapture() throws {
        XCTAssertTrue(step("arrival").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch.tap()
        primary.tap()
        XCTAssertTrue(step("lifeAreas").waitForExistence(timeout: 10))
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("work-career")].firstMatch.tap()
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("health-self")].firstMatch.tap()
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
        XCTAssertFalse(flow.waitForExistence(timeout: 4))
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
        XCTAssertTrue(app.navigationBars["Connections"].waitForExistence(timeout: 15))
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


final class SeamlessOnboardingUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }

    private var primary: XCUIElement { app.buttons[AccessibilityIdentifiers.LifeWeave.primaryAction] }

    func testFourScreenSkipCaptureAndIndependentConnections() {
        let intent = app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch
        XCTAssertTrue(intent.waitForExistence(timeout: 20))
        intent.tap()
        primary.tap()
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("work-career")].firstMatch.tap()
        app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea("health-self")].firstMatch.tap()
        primary.tap()
        let skip = app.buttons[AccessibilityIdentifiers.LifeWeave.secondaryAction]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertEqual(skip.label, "Skip")
        skip.tap()
        let health = app.buttons["onboarding.connection.health"]
        XCTAssertTrue(health.waitForExistence(timeout: 15))
        if !health.isHittable { app.swipeUp() }
        health.tap()
        XCTAssertTrue(app.buttons["health.connection.continue"].waitForExistence(timeout: 5))
        app.buttons["health.connection.continue"].tap()
        XCTAssertTrue(app.buttons["health.connection.continue"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        XCTAssertEqual(primary.label, "Start my day")
        primary.tap()
        let reachedHome = app.buttons["home.onboarding.firstAction"].firstMatch.waitForExistence(timeout: 10)
        if !reachedHome {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(reachedHome)
    }
}

final class SeamlessOnboardingLargeTextUITests: BaseUITest {
    override var shouldSkipOnboarding: Bool { false }
    override var additionalLaunchArguments: [String] {
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testSaveRealTaskWithLargeText() {
        let primary = app.buttons[AccessibilityIdentifiers.LifeWeave.primaryAction]
        let intent = app.buttons[AccessibilityIdentifiers.LifeWeave.intent("clarityToday")].firstMatch
        XCTAssertTrue(intent.waitForExistence(timeout: 20))
        intent.tap()
        primary.tap()
        for area in ["work-career", "health-self"] {
            let button = app.buttons[AccessibilityIdentifiers.LifeWeave.lifeArea(area)].firstMatch
            if !button.isHittable { app.swipeUp() }
            button.tap()
        }
        primary.tap()
        let field = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.captureField].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Prepare the project outline")
        // Save is available from the first character; interpretation happens
        // on a pause or, if there was none, as part of Save itself.
        XCTAssertEqual(primary.label, "Save")
        primary.tap()
        XCTAssertTrue(app.buttons["Start my day"].waitForExistence(timeout: 15))
        primary.tap()
        XCTAssertTrue(app.buttons["foundation.destination.home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Prepare the project outline"].firstMatch.waitForExistence(timeout: 10))
    }
}
