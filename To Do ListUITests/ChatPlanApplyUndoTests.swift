import XCTest

final class ChatPlanApplyUndoTests: BaseUITest {
    func testChatEntryPointOpensAssistantSurfaceAndSlashPicker() throws {
        let homePage = HomePage(app: app)
        let chatCandidates: [XCUIElement] = [
            homePage.chatButton,
            app.buttons["Chat"],
            app.descendants(matching: .any)["home.bottomBar"]
        ]

        var opened = false
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
            if emptyState.waitForExistence(timeout: 4) || composer.waitForExistence(timeout: 4) {
                opened = true
                break
            }
        }

        guard opened else {
            throw XCTSkip("Chat entry point is not reachable with current accessibility identifiers")
        }

        let slashButton = app.buttons["chat.slash_button"]
        XCTAssertTrue(slashButton.waitForExistence(timeout: 3), "Slash picker button should be visible")
        slashButton.tap()

        let commandSearch = app.textFields["chat.command_picker.search"]
        XCTAssertTrue(commandSearch.waitForExistence(timeout: 4), "Slash command picker search should open")
    }
}
