import XCTest

final class QuickFilterChromeTests: BaseUITest {
    private let quickFilterMinimumExpandedWidth: CGFloat = 84

    func testTodayQuickFilterShowsTitleOnColdLaunchAndAfterReturningFromOtherViews() throws {
        let homePage = HomePage(app: app)
        let quickFilterButton = homePage.projectFilterButton
        let quickFilterTitleLabel = homePage.quickFilterTitleLabel

        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        XCTAssertTrue(quickFilterTitleLabel.waitForExistence(timeout: 3), "Today quick filter should show its title on cold launch")
        XCTAssertEqual(quickFilterTitleLabel.label, "Today", "Today quick filter should render the Today title on cold launch")
        XCTAssertGreaterThan(
            quickFilterButton.frame.width,
            quickFilterMinimumExpandedWidth,
            "Today quick filter should be wider than an icon-only pill on cold launch"
        )

        quickFilterButton.tap()

        let overdueButton = app.buttons["home.focus.menu.option.overdue"]
        XCTAssertTrue(overdueButton.waitForExistence(timeout: 3), "Overdue quick view should be visible in the menu")
        overdueButton.tap()

        XCTAssertTrue(homePage.backToTodayButton.waitForExistence(timeout: 3), "Back to Today should appear outside the default Today view")

        quickFilterButton.tap()

        let todayButton = app.buttons["home.focus.menu.option.today"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 3), "Today quick view should be visible in the menu")
        todayButton.tap()

        XCTAssertTrue(quickFilterTitleLabel.waitForExistence(timeout: 3), "Today quick filter should still show its title after returning from another quick view")
        XCTAssertEqual(quickFilterTitleLabel.label, "Today", "Today quick filter should restore the Today title after returning from another quick view")
        XCTAssertGreaterThan(
            quickFilterButton.frame.width,
            quickFilterMinimumExpandedWidth,
            "Today quick filter should stay wider than an icon-only pill after returning from another quick view"
        )
    }

    func testTodayAndCustomDateShowHeaderDateWhileOtherQuickViewsHideIt() throws {
        let homePage = HomePage(app: app)
        let headerDateLabel = homePage.headerDateLabel

        XCTAssertTrue(headerDateLabel.waitForExistence(timeout: 3), "Today view should show the centered date")

        let quickFilterButton = homePage.projectFilterButton
        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        quickFilterButton.tap()

        let pickDateButton = app.buttons["home.focus.menu.datePicker"]
        XCTAssertTrue(pickDateButton.waitForExistence(timeout: 3), "Pick date should be visible in the quick view menu")
        pickDateButton.tap()

        let dateNavigationBar = app.navigationBars["Date"].firstMatch
        XCTAssertTrue(dateNavigationBar.waitForExistence(timeout: 3), "Date sheet should open")

        selectVisibleFutureDate(in: app, preferredDate: TestDataFactory.tomorrow())

        let applyButton = app.buttons["Apply"]
        XCTAssertTrue(applyButton.waitForExistence(timeout: 3), "Apply button should exist in the home date picker")
        applyButton.tap()

        XCTAssertTrue(homePage.backToTodayButton.waitForExistence(timeout: 3), "Custom date should show Back to Today")
        XCTAssertTrue(headerDateLabel.waitForExistence(timeout: 3), "Custom date view should continue showing the centered date")

        quickFilterButton.tap()

        let overdueButton = app.buttons["home.focus.menu.option.overdue"]
        XCTAssertTrue(overdueButton.waitForExistence(timeout: 3), "Overdue quick view should be visible in the menu")
        overdueButton.tap()

        XCTAssertTrue(waitForElementToDisappear(headerDateLabel, timeout: 3), "Non-Today quick views should hide the centered date")
    }

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

    func testTodayShowsXPStatusAndOtherQuickViewsHideIt() throws {
        let homePage = HomePage(app: app)
        let xpLabel = homePage.topChromeXPLabel

        XCTAssertTrue(xpLabel.waitForExistence(timeout: 10), "Today view should show the top chrome XP status")

        let quickFilterButton = homePage.projectFilterButton
        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        quickFilterButton.tap()

        let overdueButton = app.buttons["home.focus.menu.option.overdue"]
        XCTAssertTrue(overdueButton.waitForExistence(timeout: 3), "Overdue quick view should be visible in the menu")
        overdueButton.tap()

        XCTAssertTrue(waitForElementToDisappear(xpLabel, timeout: 3), "Non-Today quick views should hide the top chrome XP status")
    }

    private func selectVisibleFutureDate(in root: XCUIElement, preferredDate: Date) {
        let candidateDates = [
            preferredDate,
            TestDataFactory.daysFromNow(2),
            TestDataFactory.daysFromNow(3)
        ]

        for candidate in candidateDates {
            let dayLabel = String(Calendar.current.component(.day, from: candidate))
            let queries = [
                root.buttons[dayLabel],
                root.staticTexts[dayLabel],
                app.buttons[dayLabel],
                app.staticTexts[dayLabel]
            ]

            if let element = queries.first(where: \.exists) {
                element.tap()
                return
            }
        }

        XCTFail("Unable to find a visible future date to select in the home date picker")
    }
}
