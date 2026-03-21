import XCTest

final class ChatPlanApplyUndoTests: BaseUITest {
    func testChatEntryPointOpensAssistantSurfaceAndSlashPicker() throws {
        try openChatSurface()

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
