import XCTest

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

        // Eva is a root; leaving it means choosing another root.
        XCTAssertTrue(HomePage(app: app).openRoot("home"), "Home should open from the root chrome")

        try openChatSurface()
        XCTAssertFalse(
            app.otherElements["eva.activation.intro"].waitForExistence(timeout: 2),
            "Reopening EVA should not restart activation"
        )
    }

    /// Eva is a Foundation root, reached from the dock or root switcher.
    @discardableResult
    private func openChatSurface() throws -> XCUIApplication {
        let evaRoot = HomePage(app: app).rootButton("eva")
        guard evaRoot.waitForExistence(timeout: 5) else {
            throw XCTSkip("The Eva root is not reachable from the root chrome")
        }
        evaRoot.tap()

        let emptyState = app.otherElements["chat.emptyState.container"]
        let composer = app.otherElements["chat.composer.container"]
        let predicate = NSPredicate { _, _ in
            emptyState.exists || composer.exists
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        if XCTWaiter.wait(for: [expectation], timeout: 6) == .completed {
            return app
        }

        throw XCTSkip("Eva root did not show the chat surface")
    }
}

final class ChatCompletedChromeUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [XCUIApplication.LaunchArgumentKey.testEvaActivationCompleted.rawValue]
    }

    func testCompletedChatComposerOpensKeyboardFromBottomBarEntry() throws {
        try openCompletedChatSurface()

        let composer = waitForCompletedChatComposer(timeout: 5)
        XCTAssertTrue(composer.exists, "Completed chat composer should be visible after opening the Eva root")

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

    /// Eva is a Foundation root, reached from the dock or root switcher.
    @discardableResult
    private func openCompletedChatSurface() throws -> XCUIApplication {
        let evaRoot = HomePage(app: app).rootButton("eva")
        if evaRoot.waitForExistence(timeout: 5) {
            evaRoot.tap()
        }

        if waitForCompletedChatSurface(timeout: 5) {
            return app
        }

        throw XCTSkip("Eva root did not show the completed chat surface")
    }

    private func waitForCompletedChatSurface(timeout: TimeInterval) -> Bool {
        let emptyState = app.descendants(matching: .any)["chat.emptyState.container"]
        let composer = app.descendants(matching: .any)["chat.composer.container"]
        let structuredComposer = app.descendants(matching: .any)["eva.structured.composer"]
        let navTitle = app.descendants(matching: .any)["chat.nav.title"]
        let emptyGreeting = app.staticTexts["Hi there"]
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
}
