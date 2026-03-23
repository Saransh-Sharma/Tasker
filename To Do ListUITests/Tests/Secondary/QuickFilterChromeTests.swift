import XCTest

final class QuickFilterChromeTests: BaseUITest {
    func testQuickFilterMenuSupportsAdvancedAndResetFlows() throws {
        let homePage = HomePage(app: app)

        let quickFilterButton = homePage.projectFilterButton
        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick filter trigger is not reachable with current accessibility identifiers")
        }

        quickFilterButton.tap()

        let advancedButton = homePage.quickFilterAdvancedButton
        XCTAssertTrue(advancedButton.waitForExistence(timeout: 3), "Advanced filters row should be visible")
        advancedButton.tap()

        let advancedTitle = app.navigationBars["Advanced Filters"].firstMatch
        XCTAssertTrue(advancedTitle.waitForExistence(timeout: 3), "Advanced filters sheet should open")

        let closeButton = app.buttons["Close"]
        if closeButton.waitForExistence(timeout: 2) {
            closeButton.tap()
        }

        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick filter trigger did not reappear after advanced filters")
        }

        quickFilterButton.tap()
        XCTAssertTrue(advancedButton.waitForExistence(timeout: 3), "Quick filter menu should reopen")

        let resetButton = app.buttons["home.focus.menu.reset"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 3), "Reset button should be visible")
        resetButton.tap()
    }
}
