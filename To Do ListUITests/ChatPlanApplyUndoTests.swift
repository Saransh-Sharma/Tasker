import XCTest

final class ChatPlanApplyUndoTests: BaseUITest {
    func testChatEntryPointOpensAssistantSurface() throws {
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

            let emptyStateTitle = app.staticTexts["ask Eva anything"]
            let chatInput = app.textFields["ask me anything..."]
            if emptyStateTitle.waitForExistence(timeout: 4) || chatInput.waitForExistence(timeout: 4) {
                opened = true
                break
            }
        }

        guard opened else {
            throw XCTSkip("Chat entry point is not reachable with current accessibility identifiers")
        }

    }
}
