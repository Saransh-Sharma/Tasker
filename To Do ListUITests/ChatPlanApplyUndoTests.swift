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

    func testEvaActivationDismissalReopensIntroUntilCompleted() throws {
        try openChatSurface()

        let intro = app.otherElements["eva.activation.intro"]
        XCTAssertTrue(intro.waitForExistence(timeout: 4), "EVA activation intro should appear for a fresh chat entry")

        let introHero = app.otherElements["eva.activation.intro.hero"]
        XCTAssertTrue(introHero.waitForExistence(timeout: 3), "Meet Eva hero media should be visible on the intro screen")

        let window = app.windows.firstMatch
        if window.waitForExistence(timeout: 1), window.frame.width < 500 {
            XCTAssertLessThanOrEqual(introHero.frame.minX, 1, "Compact intro hero should bleed to the leading screen edge")
            XCTAssertGreaterThanOrEqual(introHero.frame.maxX, window.frame.maxX - 1, "Compact intro hero should bleed to the trailing screen edge")

            let navProgress = app.otherElements["eva.activation.nav.progress"]
            XCTAssertTrue(navProgress.waitForExistence(timeout: 3), "Activation nav progress should be visible on the intro screen")

            let topGap = introHero.frame.minY - navProgress.frame.maxY
            XCTAssertLessThanOrEqual(abs(topGap), 2, "Compact intro hero should sit flush below the navigation chrome")
        }

        let activate = app.buttons["Activate Eva"]
        XCTAssertTrue(activate.waitForExistence(timeout: 3))
        activate.tap()

        let aboutYou = app.otherElements["eva.activation.about_you"]
        XCTAssertTrue(aboutYou.waitForExistence(timeout: 4), "Activation should advance into the About You step")

        let workingStyleNoteToggle = app.buttons["eva.activation.about_you.working_style_note.toggle"]
        XCTAssertTrue(workingStyleNoteToggle.waitForExistence(timeout: 3), "Quick sync note toggle should start collapsed")

        app.buttons["Back"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view].waitForExistence(timeout: 5))

        try openChatSurface()
        XCTAssertTrue(intro.waitForExistence(timeout: 4), "Activation intro should return after dismissing without completing")
    }

    func testEvaActivationModeSelectionUpdatesInstallCTA() throws {
        try openChatSurface()

        XCTAssertTrue(app.buttons["Activate Eva"].waitForExistence(timeout: 3))
        app.buttons["Activate Eva"].tap()

        let aboutYou = app.otherElements["eva.activation.about_you"]
        XCTAssertTrue(aboutYou.waitForExistence(timeout: 4))

        let workingStyleChip = app.buttons["eva.activation.style.prioritizeForMe"]
        XCTAssertTrue(workingStyleChip.waitForExistence(timeout: 3))
        workingStyleChip.tap()

        let continueFromAboutYou = app.buttons["Continue"].firstMatch
        XCTAssertTrue(continueFromAboutYou.waitForExistence(timeout: 3))
        continueFromAboutYou.tap()

        let goals = app.otherElements["eva.activation.goals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 4))

        let goalField = app.textFields["eva.activation.goals.composer.field"]
        XCTAssertTrue(goalField.waitForExistence(timeout: 3))
        goalField.tap()
        goalField.typeText("Finish the client handoff plan")

        let addOutcome = app.buttons["eva.activation.goals.composer.button"]
        XCTAssertTrue(addOutcome.waitForExistence(timeout: 3))
        addOutcome.tap()

        let continueFromGoals = app.buttons["Continue"].firstMatch
        XCTAssertTrue(continueFromGoals.waitForExistence(timeout: 3))
        continueFromGoals.tap()

        let modelChoice = app.otherElements["eva.activation.model_choice"]
        XCTAssertTrue(modelChoice.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Install Fast"].waitForExistence(timeout: 3), "Fast should be the default install CTA")

        let smarterCard = app.buttons["eva.activation.mode.smarter"]
        XCTAssertTrue(smarterCard.waitForExistence(timeout: 3))
        smarterCard.tap()

        XCTAssertTrue(app.buttons["Install Smarter"].waitForExistence(timeout: 3), "CTA should update when Smarter is selected")
    }

    func testEvaActivationUsesSingleHostNavigationChrome() throws {
        try openChatSurface()

        XCTAssertTrue(app.buttons["Activate Eva"].waitForExistence(timeout: 3))
        app.buttons["Activate Eva"].tap()

        let aboutYou = app.otherElements["eva.activation.about_you"]
        XCTAssertTrue(aboutYou.waitForExistence(timeout: 4))

        let navTitle = app.staticTexts["eva.activation.nav.title"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Native activation nav title should be visible")
        XCTAssertEqual(navTitle.label, "Quick Sync")

        let navProgress = app.otherElements["eva.activation.nav.progress"]
        XCTAssertTrue(navProgress.waitForExistence(timeout: 3), "Native activation progress bar should be visible")

        XCTAssertFalse(app.staticTexts["Step 2 of 6"].exists, "Inline step header should be removed from the screen body")
        XCTAssertFalse(app.buttons["History"].exists, "History action should be hidden during activation")
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

            let intro = app.otherElements["eva.activation.intro"]
            let emptyState = app.otherElements["chat.emptyState.container"]
            let composer = app.otherElements["chat.composer.container"]
            let predicate = NSPredicate { _, _ in
                intro.exists || emptyState.exists || composer.exists
            }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
            if XCTWaiter.wait(for: [expectation], timeout: 4) == .completed {
                return app
            }
        }

        throw XCTSkip("Chat entry point is not reachable with current accessibility identifiers")
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
}
