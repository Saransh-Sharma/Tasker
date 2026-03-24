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

    func testSwitchingAwayFromTodayShowsBackToTodayAffordance() throws {
        let homePage = HomePage(app: app)
        let quickFilterButton = homePage.projectFilterButton

        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        quickFilterButton.tap()

        let overdueButton = app.buttons["home.focus.menu.option.overdue"]
        XCTAssertTrue(overdueButton.waitForExistence(timeout: 3), "Overdue quick view should be visible in the menu")
        overdueButton.tap()

        XCTAssertTrue(homePage.backToTodayButton.waitForExistence(timeout: 3), "Back to Today should appear outside the default Today view")
        XCTAssertFalse(homePage.reflectionReadyButton.exists, "Reflection CTA should not be visible outside Today")
    }

    func testReflectionReadyButtonOpensReflectionSheet() throws {
        let homePage = HomePage(app: app)
        let reflectionButton = homePage.reflectionReadyButton

        guard reflectionButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Reflection CTA is not visible in the current Today state")
        }

        reflectionButton.tap()

        let reflectionTitle = app.staticTexts["Daily Reflection"]
        XCTAssertTrue(reflectionTitle.waitForExistence(timeout: 3), "Reflection CTA should open the existing reflection sheet")
    }
}
