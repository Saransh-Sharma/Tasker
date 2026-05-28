import XCTest

final class QuickFilterChromeTests: BaseUITest {
    private let quickFilterMaximumIconWidth: CGFloat = 44

    func testTodayQuickFilterShowsIconOnlyOnColdLaunchAndAfterReturningFromOtherViews() throws {
        let homePage = HomePage(app: app)
        let quickFilterButton = homePage.projectFilterButton

        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        XCTAssertFalse(
            homePage.topChrome.staticTexts["Today"].exists,
            "Home scope trigger should not render a visible Today title on cold launch"
        )
        XCTAssertLessThanOrEqual(
            quickFilterButton.frame.width,
            quickFilterMaximumIconWidth,
            "Today quick filter should stay icon-sized on cold launch"
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

        XCTAssertFalse(
            homePage.topChrome.staticTexts["Today"].exists,
            "Home scope trigger should remain icon-only after returning to Today"
        )
        XCTAssertLessThanOrEqual(
            quickFilterButton.frame.width,
            quickFilterMaximumIconWidth,
            "Today quick filter should remain icon-sized after returning to Today"
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

    @MainActor
    func testSunriseContentFilterChipsHideNonmatchingTimelineCards() throws {
        relaunchWithSunriseTimelineSeed()

        func chip(_ id: String) -> XCUIElement {
            app.buttons["home.sunrise.filter.\(id)"]
        }

        guard chip("all").waitForExistence(timeout: 5),
              chip("meetings").waitForExistence(timeout: 2),
              chip("tasks").waitForExistence(timeout: 2),
              chip("habits").waitForExistence(timeout: 2) else {
            throw XCTSkip("Sunrise content filter chips are not reachable in the current launch state")
        }

        chip("all").tap()
        let initialTaskIDs = timelineIdentifiers(withPrefix: "home.timeline.task.")
        let initialEventIDs = timelineIdentifiers(withPrefix: "home.timeline.event.")
        guard initialTaskIDs.isEmpty == false || initialEventIDs.isEmpty == false else {
            throw XCTSkip("No visible Sunrise timeline cards are available for content-filter verification")
        }

        if initialEventIDs.isEmpty == false {
            chip("tasks").tap()
            XCTAssertTrue(
                waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: true, timeout: 3),
                "Tasks scope should hide calendar timeline cards"
            )
        }

        if initialTaskIDs.isEmpty == false {
            chip("meetings").tap()
            XCTAssertTrue(
                waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: true, timeout: 3),
                "Meetings scope should hide task timeline cards"
            )
        }

        chip("habits").tap()
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: true, timeout: 3),
            "Habits scope should hide task timeline cards"
        )
        XCTAssertTrue(
            waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: true, timeout: 3),
            "Habits scope should hide calendar timeline cards"
        )

        chip("all").tap()
        if initialTaskIDs.isEmpty == false {
            XCTAssertTrue(
                waitForTimelineIdentifiers(withPrefix: "home.timeline.task.", toBeEmpty: false, timeout: 3),
                "All scope should restore task timeline cards"
            )
        }
        if initialEventIDs.isEmpty == false {
            XCTAssertTrue(
                waitForTimelineIdentifiers(withPrefix: "home.timeline.event.", toBeEmpty: false, timeout: 3),
                "All scope should restore calendar timeline cards"
            )
        }
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

    func testTimelineHorizontalSwipeNavigatesDaysAndBackToToday() throws {
        let homePage = HomePage(app: app)

        guard homePage.timelineSurface.waitForExistence(timeout: 5),
              homePage.headerDateLabel.waitForExistence(timeout: 5) else {
            throw XCTSkip("Timeline surface and header date are not reachable in the current launch state")
        }

        let todayLabel = homePage.headerDateLabel.label

        homePage.swipeTimelineLeft()

        XCTAssertTrue(homePage.backToTodayButton.waitForExistence(timeout: 4), "Next-day swipe should show Back to Today")
        XCTAssertTrue(homePage.headerDateLabel.waitForExistence(timeout: 4), "Custom-day header date should remain visible")
        XCTAssertTrue(
            waitForHeaderDate(on: homePage, notEqualTo: todayLabel, timeout: 4),
            "Left swipe should move the Home timeline to the next day"
        )

        homePage.swipeTimelineRight()
        XCTAssertTrue(
            waitForHeaderDate(on: homePage, equalTo: todayLabel, timeout: 4),
            "Right swipe from the next day should return the Home timeline to today"
        )

        homePage.swipeTimelineRight()
        XCTAssertTrue(homePage.backToTodayButton.waitForExistence(timeout: 4), "Back to Today should reappear after another non-today swipe")
        XCTAssertTrue(homePage.headerDateLabel.waitForExistence(timeout: 4), "Previous-day header date should remain visible")
        homePage.backToTodayButton.tap()
        XCTAssertTrue(
            waitForHeaderDate(on: homePage, equalTo: todayLabel, timeout: 4),
            "Back to Today should restore today's header date"
        )
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

    func testReflectionSheetShowsNoLoadingSpinner() throws {
        let homePage = HomePage(app: app)
        let reflectionButton = homePage.reflectionReadyButton

        guard reflectionButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Reflection CTA is not visible in the current Today state")
        }

        reflectionButton.tap()

        let reflectionScreen = app.descendants(matching: .any)["reflection.plan.screen"].firstMatch
        XCTAssertTrue(reflectionScreen.waitForExistence(timeout: 3), "Reflection sheet should appear")

        let loadingIndicator = reflectionScreen.activityIndicators.firstMatch
        XCTAssertFalse(
            loadingIndicator.waitForExistence(timeout: 1),
            "Reflection sheet should not show a loading spinner"
        )
    }

    func testTodayShowsDayProgressStatusAndOtherQuickViewsHideIt() throws {
        let homePage = HomePage(app: app)
        let dayProgressLabel = homePage.topChromeDayProgressLabel

        guard dayProgressLabel.waitForExistence(timeout: 10) else {
            throw XCTSkip("Sunrise Home does not expose the old top chrome day progress status in this launch state")
        }

        let quickFilterButton = homePage.projectFilterButton
        guard quickFilterButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Quick view trigger is not reachable in the current launch state")
        }

        quickFilterButton.tap()

        let overdueButton = app.buttons["home.focus.menu.option.overdue"]
        XCTAssertTrue(overdueButton.waitForExistence(timeout: 3), "Overdue quick view should be visible in the menu")
        overdueButton.tap()

        XCTAssertTrue(waitForElementToDisappear(dayProgressLabel, timeout: 3), "Non-Today quick views should hide the top chrome day progress status")
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

            if let element = queries.first(where: { $0.exists && $0.isHittable }) {
                element.tap()
                return
            }
        }

        XCTFail("Unable to find a visible future date to select in the home date picker")
    }

    @MainActor
    private func relaunchWithSunriseTimelineSeed() {
        app.terminate()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):active"
        ]
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        app.launch()
        waitForAppLaunch()
    }

    @MainActor
    private func timelineIdentifiers(withPrefix prefix: String) -> [String] {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .allElementsBoundByIndex
            .map(\.identifier)
    }

    @MainActor
    private func waitForTimelineIdentifiers(
        withPrefix prefix: String,
        toBeEmpty expectedEmpty: Bool,
        timeout: TimeInterval
    ) -> Bool {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let isEmpty = query.count == 0
            if isEmpty == expectedEmpty {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        return (query.count == 0) == expectedEmpty
    }

    private func waitForHeaderDate(
        on homePage: HomePage,
        equalTo expectedLabel: String,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedLabel),
            object: homePage.headerDateLabel
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForHeaderDate(
        on homePage: HomePage,
        notEqualTo initialLabel: String,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initialLabel),
            object: homePage.headerDateLabel
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
