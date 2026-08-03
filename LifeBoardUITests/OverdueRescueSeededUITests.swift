import XCTest

@MainActor
final class OverdueRescueSeededUITests: BaseUITest {
    private enum Seed {
        static let keepID = "21000000-0000-0000-0000-000000000001"
        static let moveID = "21000000-0000-0000-0000-000000000002"
        static let editID = "21000000-0000-0000-0000-000000000003"
        static let deleteID = "21000000-0000-0000-0000-000000000004"
    }

    private var homePage: HomePage!
    private var rescuePage: OverdueRescuePage!

    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.enableDebugLogging.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedOverdueRescueSuite.rawValue
        ]
    }

    override func setUp() async throws {
        try await super.setUp()
        homePage = HomePage(app: app)
        rescuePage = OverdueRescuePage(app: app, homePage: homePage)
    }

    func testSeededRescueDeckOpensWithStableActionsAndCardOrder() throws {
        XCTAssertTrue(rescuePage.open(cardID: Seed.keepID), "Seeded Overdue Rescue suite should open on the first deterministic card.")

        XCTAssertTrue(rescuePage.card(id: Seed.keepID).waitForExistence(timeout: 5), "Oldest high-priority rescue task should be first.")
        XCTAssertTrue(rescuePage.keepTodayButton.waitForExistence(timeout: 3), "Deck should expose Keep Today by identifier.")
        XCTAssertTrue(rescuePage.moveLaterButton.waitForExistence(timeout: 3), "Deck should expose Move Later by identifier.")
        XCTAssertTrue(rescuePage.editButton.waitForExistence(timeout: 3), "Deck should expose Edit by identifier.")
        XCTAssertTrue(rescuePage.deleteButton.waitForExistence(timeout: 3), "Deck should expose Delete by identifier.")
    }

    func testMoveLaterCanBeUndoneAndRestoresCard() throws {
        XCTAssertTrue(rescuePage.open(cardID: Seed.keepID), "Rescue should open before making decisions.")
        rescuePage.tap(rescuePage.keepTodayButton)

        XCTAssertTrue(rescuePage.card(id: Seed.moveID).waitForExistence(timeout: 6), "Move-later seed card should become active after first decision.")
        rescuePage.tap(rescuePage.moveLaterButton)

        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Snackbar.action("undo")].waitForExistence(timeout: 5), "Move Later should expose snackbar Undo.")
        rescuePage.tap(rescuePage.snackbarUndoButton)

        XCTAssertTrue(rescuePage.card(id: Seed.moveID).waitForExistence(timeout: 6), "Undo should restore the moved rescue card.")
    }

    func testEditAndDeleteConfirmationFlowsAreReachableAndUndoable() throws {
        XCTAssertTrue(rescuePage.open(cardID: Seed.keepID), "Rescue should open before making decisions.")
        rescuePage.tap(rescuePage.keepTodayButton)
        XCTAssertTrue(rescuePage.card(id: Seed.moveID).waitForExistence(timeout: 6))
        rescuePage.tap(rescuePage.moveLaterButton)

        XCTAssertTrue(rescuePage.card(id: Seed.editID).waitForExistence(timeout: 6), "Edit card should become active.")
        rescuePage.tap(rescuePage.editButton)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueEditSheet].waitForExistence(timeout: 5), "Edit sheet should open.")
        rescuePage.tap(app.buttons[AccessibilityIdentifiers.Home.rescueEditSave])

        XCTAssertTrue(rescuePage.card(id: Seed.deleteID).waitForExistence(timeout: 6), "Delete card should become active after editing.")
        rescuePage.tap(rescuePage.deleteButton)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityIdentifiers.Home.rescueDeleteOverlay].waitForExistence(timeout: 4), "Guarded delete should show confirmation.")
        rescuePage.tap(app.buttons[AccessibilityIdentifiers.Home.rescueDeleteCancel])
        XCTAssertTrue(rescuePage.card(id: Seed.deleteID).waitForExistence(timeout: 3), "Cancel should keep the delete candidate active.")

        rescuePage.tap(rescuePage.deleteButton)
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.rescueDeleteConfirm].waitForExistence(timeout: 4))
        rescuePage.tap(app.buttons[AccessibilityIdentifiers.Home.rescueDeleteConfirm])
        XCTAssertTrue(rescuePage.snackbarUndoButton.waitForExistence(timeout: 5), "Delete should expose snackbar Undo.")
        rescuePage.tap(rescuePage.snackbarUndoButton)

        XCTAssertTrue(rescuePage.card(id: Seed.deleteID).waitForExistence(timeout: 6), "Undo should restore the deleted rescue card.")
    }
}
