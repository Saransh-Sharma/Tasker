import XCTest

@MainActor
final class FocusNowSeededUITests: BaseUITest {
    private enum Seed {
        static let focusRowID = "10000000-0000-0000-0000-000000000001"
        static let focusAID = "10000000-0000-0000-0000-000000000002"
        static let focusBID = "10000000-0000-0000-0000-000000000003"
        static let candidateID = "10000000-0000-0000-0000-000000000005"
    }

    private var homePage: HomePage!
    private var focusPage: FocusNowPage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.testSeedFocusWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedFocusNowSuite.rawValue
        ]
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        homePage = HomePage(app: app)
        focusPage = FocusNowPage(app: app, homePage: homePage)
    }

    func testHomeFocusStripIsCompactAndDetailOpensSeededSet() throws {
        XCTAssertTrue(focusPage.waitForHomeStrip(timeout: 8), "Seeded Focus Now strip should render on Home.")
        XCTAssertFalse(app.buttons["home.focus.why"].exists, "Home Focus Now should not expose the removed Why button.")
        XCTAssertFalse(homePage.focusShuffleButton.exists, "Home Focus Now should not expose the removed shuffle button.")
        XCTAssertFalse(homePage.focusStrip.staticTexts["P1"].exists, "Compact strip should hide priority chips.")

        XCTAssertTrue(focusPage.openDetail(), "Tapping Focus Now title should open the detail sheet.")
        XCTAssertTrue(focusPage.deck.waitForExistence(timeout: 5), "Focus Now deck should render.")
        XCTAssertTrue(focusPage.card(index: 0).waitForExistence(timeout: 4), "Current focus card should render.")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.focusRowID)].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.focusAID)].exists)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.focusBID)].exists)
    }

    func testCardFlipTimerSheetAndCancelPathAreReachable() throws {
        XCTAssertTrue(focusPage.openDetail(), "Focus detail should open.")
        let firstCard = focusPage.card(index: 0)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        focusPage.tap(firstCard)

        XCTAssertTrue(app.buttons["focusNow.card.startTimer"].waitForExistence(timeout: 4), "Flipped card should expose Start timer.")
        focusPage.tap(app.buttons["focusNow.card.startTimer"])

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.timerSheet].waitForExistence(timeout: 5), "Timer sheet should open.")
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.FocusNow.timerPreset(minutes: 25)].waitForExistence(timeout: 3), "Timer sheet should expose preset durations.")
    }

    func testCandidateSwapAndToastUndoRestoreCurrentSet() throws {
        XCTAssertTrue(focusPage.openDetail(), "Focus detail should open.")
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.focusRowID)].waitForExistence(timeout: 5))

        let candidateSwap = focusPage.candidateSwap(id: Seed.candidateID)
        XCTAssertTrue(candidateSwap.waitForExistence(timeout: 6), "Seeded replacement candidate should expose a stable swap control.")
        focusPage.tap(candidateSwap)

        XCTAssertTrue(app.buttons[Seed.focusRowID].waitForExistence(timeout: 4) || app.buttons["Focus Row Opens Detail"].waitForExistence(timeout: 4), "Replacement dialog should ask which current task to replace.")
        let replaceTarget = app.buttons["Focus Row Opens Detail"].exists ? app.buttons["Focus Row Opens Detail"] : app.buttons[Seed.focusRowID]
        focusPage.tap(replaceTarget)

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.candidateID)].waitForExistence(timeout: 5), "Candidate should appear in the current Focus Now set.")
        XCTAssertTrue(focusPage.toast.waitForExistence(timeout: 5), "Swap should expose undo toast.")
        focusPage.tap(focusPage.toast)

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.focusRowID)].waitForExistence(timeout: 5), "Undo should restore the original focus task.")
    }

    func testRefineSheetCanAdjustAndApplyCurrentSet() throws {
        XCTAssertTrue(focusPage.openDetail(), "Focus detail should open.")
        focusPage.tap(app.buttons[AccessibilityIdentifiers.FocusNow.refineOpen])

        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.refineSheet].waitForExistence(timeout: 5), "Refine sheet should open.")
        let candidateRow = focusPage.refineRow(id: Seed.candidateID)
        XCTAssertTrue(candidateRow.waitForExistence(timeout: 5), "Refine sheet should include seeded replacement candidates.")
        focusPage.tap(candidateRow)

        let selectedTarget = app.buttons["Focus Row Opens Detail"].exists ? app.buttons["Focus Row Opens Detail"] : app.buttons[AccessibilityIdentifiers.FocusNow.refineRow(Seed.focusRowID)]
        XCTAssertTrue(selectedTarget.waitForExistence(timeout: 4), "Full set replacement dialog should ask which task to replace.")
        focusPage.tap(selectedTarget)

        focusPage.tap(app.buttons[AccessibilityIdentifiers.FocusNow.refineDone])
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.FocusNow.cardTitle(Seed.candidateID)].waitForExistence(timeout: 5), "Refined set should apply selected replacement.")
    }
}
