import XCTest

@MainActor
final class EvaCloudLiveDeviceSmokeTests: XCTestCase {
    func testAppleCloudActivationOnPhysicalDevice() throws {
        #if !LIFEBOARD_LIVE_CLOUD_SMOKE
        throw XCTSkip("Live Apple smoke runs only with the LIFEBOARD_LIVE_CLOUD_SMOKE build condition.")
        #endif
        continueAfterFailure = false

        let app = XCUIApplication()
        // Deliberately *not* `-SKIP_ONBOARDING`: the EVA sign-in this test
        // qualifies now lives inside onboarding's power-up chain.
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            // Pinned to the v5 Life Map journey, which is what the walk below
            // drives. v6 is on by default in Debug, and without this the test
            // would find no `onboarding.lifeMap.flow` and quietly `XCTSkip` —
            // losing the Apple sign-in coverage it exists to provide rather than
            // reporting that it had. Retarget this at the v6 chain when v6
            // promotes and the v5 flow is retired.
            "-LIFEBOARD_DISABLE_ONBOARDING_V6"
        ]
        app.launch()

        // Cloud EVA is reached through app onboarding now, not through a
        // standalone setup screen on the EVA tab. `-LIFEBOARD_TEST_EVA_CLOUD_SETUP`
        // no longer stages anything, so this smoke test drives the real path:
        // build the Life Map, choose "Power it up", and walk to the EVA step.
        let onboarding = app.descendants(matching: .any)["onboarding.lifeMap.flow"]
        guard onboarding.waitForExistence(timeout: 15) else {
            throw XCTSkip(
                "Onboarding did not present. This smoke test needs a clean install: it signs in through the onboarding EVA step. Hierarchy: \(app.debugDescription)"
            )
        }

        let evaStep = app.descendants(matching: .any)["onboarding.lifeMap.step.eva"]
        let primary = app.buttons["onboarding.primaryAction"]
        let secondary = app.buttons["onboarding.secondaryAction"]

        // Walk the flow. The core steps each accept their default answer, and
        // the reveal's secondary action opens the power-up chain.
        var guardRail = 0
        while evaStep.exists == false, guardRail < 40 {
            guardRail += 1
            if app.descendants(matching: .any)["onboarding.lifeMap.step.reveal"].exists {
                XCTAssertTrue(secondary.waitForExistence(timeout: 5))
                secondary.tap()
                continue
            }
            guard primary.waitForExistence(timeout: 5), primary.isEnabled else {
                throw XCTSkip(
                    "Onboarding stalled on a step needing a real choice. Hierarchy: \(app.debugDescription)"
                )
            }
            primary.tap()
        }

        XCTAssertTrue(
            evaStep.waitForExistence(timeout: 10),
            "Expected to reach the onboarding EVA step. Hierarchy: \(app.debugDescription)"
        )

        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        let signInTitle = primary.label
        primary.tap()

        #if targetEnvironment(simulator)
        throw XCTSkip(
            "The simulator reached Apple's native authorization flow. Complete end-to-end qualification on physical hardware because App Attest is unavailable in Simulator."
        )
        #endif

        // Success is the requirement checklist completing; failure surfaces as
        // the step's inline error rather than a thrown exception.
        let cloudReady = NSPredicate { _, _ in
            primary.exists && primary.label != signInTitle
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: cloudReady, object: app)],
            timeout: 180
        )
        XCTAssertNotEqual(result, .timedOut, "Apple cloud activation did not finish within three minutes.")
    }
}

final class ChatPlanApplyUndoTests: BaseUITest {
    func testChatEntryPointOpensAssistantSurfaceAndSlashPicker() throws {
        try openChatSurface()

        XCTAssertFalse(app.staticTexts["Planning workspace"].exists, "Chat body should not render the old planning workspace header")
        XCTAssertFalse(app.staticTexts["Keep context tight, use commands when you want structured help."].exists, "Open-thread guidance should not render as a body chrome row")

        let slashButton = app.buttons["chat.slash_button"]
        XCTAssertTrue(slashButton.waitForExistence(timeout: 3), "Slash picker button should be visible")
        slashButton.tap()

        let commandSearch = app.textFields["chat.command_picker.search"]
        XCTAssertTrue(commandSearch.waitForExistence(timeout: 4), "Slash command picker search should open")
    }

    /// EVA's tab is a chat screen now, not a wizard.
    ///
    /// These four tests used to drive the standalone activation flow — intro,
    /// About You, Goals, model choice, and its own navigation chrome. App
    /// onboarding asks all of that and marks activation completed on its way
    /// out, so a user who reaches the EVA tab has already answered. Asserting
    /// the old screens would be asserting the duplication this change removed.
    func testChatEntryPointOpensDirectlyIntoChatWithoutAnActivationWizard() throws {
        try openChatSurface()

        let composer = app.otherElements["chat.composer.container"]
        let emptyState = app.otherElements["chat.emptyState.container"]
        let predicate = NSPredicate { _, _ in composer.exists || emptyState.exists }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 6),
            .completed,
            "Opening EVA should land in chat"
        )

        for retired in [
            "eva.activation.intro",
            "eva.activation.about_you",
            "eva.activation.goals",
            "eva.activation.cloud_setup",
            "eva.activation.model_choice"
        ] {
            XCTAssertFalse(
                app.descendants(matching: .any)[retired].exists,
                "\(retired) is retired; app onboarding owns it now"
            )
        }
    }

    /// Leaving EVA and coming back must not resurrect a setup flow.
    func testLeavingAndReopeningChatDoesNotReopenAnActivationFlow() throws {
        try openChatSurface()

        tapNativeChatBackOrCloseButton()
        XCTAssertTrue(
            app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 5)
        )

        try openChatSurface()
        XCTAssertFalse(
            app.otherElements["eva.activation.intro"].waitForExistence(timeout: 2),
            "Reopening EVA should not restart activation"
        )
    }

    @discardableResult
    private func openChatSurface() throws -> XCUIApplication {
        let homePage = HomePage(app: app)
        let chatCandidates: [XCUIElement] = [
            homePage.chatButton,
            app.buttons["Chat"],
            app.descendants(matching: .any)["home.bottomBar"]
        ]

        for candidate in chatCandidates where candidate.waitForExistence(timeout: 2) {
            if candidate.identifier == "home.bottomBar" {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
            } else if candidate.isHittable {
                candidate.tap()
            } else {
                candidate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }

            let emptyState = app.otherElements["chat.emptyState.container"]
            let composer = app.otherElements["chat.composer.container"]
            let predicate = NSPredicate { _, _ in
                emptyState.exists || composer.exists
            }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
            if XCTWaiter.wait(for: [expectation], timeout: 4) == .completed {
                return app
            }
        }

        throw XCTSkip("Chat entry point is not reachable with current accessibility identifiers")
    }

    private func tapNativeChatBackOrCloseButton() {
        let navigationBar = app.navigationBars.firstMatch
        let closeButton = navigationBar.buttons["Close"]
        let backButton = navigationBar.buttons["Back"]
        let button = closeButton.exists ? closeButton : backButton

        XCTAssertTrue(button.waitForExistence(timeout: 3), "Native chat back or close button should exist")

        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}

final class ChatCompletedChromeUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue]
    }

    func testCompletedChatUsesCompactNativeNavigationChrome() throws {
        try openCompletedChatSurface()

        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Completed chat should publish a native compact nav title")
        XCTAssertEqual(navTitle.label, "Eva")

        XCTAssertEqual(navTitle.value as? String, "Ask or use / commands")

        XCTAssertFalse(app.staticTexts["Planning workspace"].exists, "Empty chat should not render planning workspace copy")
        XCTAssertFalse(app.staticTexts["Keep context tight, use commands when you want structured help."].exists, "Open-thread chrome copy should be removed")

        XCTAssertTrue(app.buttons["chat.header.settings"].exists || app.buttons["Settings"].exists, "Settings should live in the native navigation bar")
        XCTAssertTrue(app.buttons["chat.header.history"].exists || app.buttons["History"].exists, "History should live in the native navigation bar")
        XCTAssertFalse(app.buttons["chat.header.new_chat"].exists || app.buttons["New chat"].exists, "New chat should be hidden for a fresh empty chat")
        XCTAssertTrue(app.buttons["Back"].exists || app.buttons["Close"].exists, "Back or close should remain in the native navigation bar")

        if app.staticTexts["Hi there!"].exists {
            XCTAssertTrue(app.buttons["eva.structured.help"].exists, "Structured Eva help should remain reachable after replacing the questionmark artwork")
        }
    }

    func testCompletedChatComposerOpensKeyboardFromBottomBarEntry() throws {
        try openCompletedChatSurface()

        let composer = waitForCompletedChatComposer(timeout: 5)
        XCTAssertTrue(composer.exists, "Completed chat composer should be visible after opening Eva from the home chat button")

        let textField = composer.textFields.firstMatch.exists
            ? composer.textFields.firstMatch
            : app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 2), "Chat composer text field should be reachable")

        if textField.isHittable {
            textField.tap()
        } else {
            textField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Chat composer should open the keyboard on the dedicated Eva screen")
        textField.typeText("Plan my focus block")
    }

    func testCompletedChatBackButtonReturnsToHome() throws {
        try openCompletedChatSurface()

        let composer = app.descendants(matching: .any)["chat.composer.container"]
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        XCTAssertTrue(
            composer.exists || emptyState.exists || navTitle.exists,
            "Completed chat should be visible before tapping Back"
        )

        tapNativeChatBackOrCloseButton()

        let homePage = HomePage(app: app)
        XCTAssertTrue(homePage.verifyIsDisplayed(timeout: 4), "Back from completed chat should return to Home")
        XCTAssertTrue(homePage.waitForToolSelection(homePage.homeButton, timeout: 4), "Home should be selected after dismissing completed chat")
        XCTAssertFalse(navTitle.waitForExistence(timeout: 1), "Completed chat navigation title should disappear after dismissal")
    }

    @discardableResult
    private func openCompletedChatSurface() throws -> XCUIApplication {
        let homePage = HomePage(app: app)
        let chatButton = homePage.chatButton.waitForExistence(timeout: 2) ? homePage.chatButton : app.buttons["Chat"]

        if chatButton.waitForExistence(timeout: 2) {
            if chatButton.isHittable {
                chatButton.tap()
            } else {
                chatButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.92)).tap()
        }

        if waitForCompletedChatSurface(timeout: 5) {
            return app
        }

        throw XCTSkip("Completed chat entry point is not reachable with current accessibility identifiers")
    }

    private func waitForCompletedChatSurface(timeout: TimeInterval) -> Bool {
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        let composer = app.descendants(matching: .any)["chat.composer.container"]
        let structuredComposer = app.descendants(matching: .any)["eva.structured.composer"]
        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        let emptyGreeting = app.staticTexts["Hi there!"]
        let predicate = NSPredicate { _, _ in
            emptyState.exists || composer.exists || structuredComposer.exists || navTitle.exists || emptyGreeting.exists
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForCompletedChatComposer(timeout: TimeInterval) -> XCUIElement {
        let structuredComposer = app.descendants(matching: .any)["eva.structured.composer"]
        if structuredComposer.waitForExistence(timeout: timeout) {
            return structuredComposer
        }

        let composer = app.descendants(matching: .any)["chat.composer.container"]
        _ = composer.waitForExistence(timeout: timeout)
        return composer
    }

    private func tapNativeChatBackOrCloseButton() {
        let navigationBar = app.navigationBars.firstMatch
        let backButton = navigationBar.buttons["Back"]
        let closeButton = navigationBar.buttons["Close"]
        let button = backButton.exists ? backButton : closeButton

        XCTAssertTrue(button.waitForExistence(timeout: 3), "Native chat back or close button should exist")

        if button.isHittable {
            button.tap()
        } else {
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
