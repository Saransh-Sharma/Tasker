import XCTest

final class HomeCalendarModuleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCalendarCardStateTransitionsAcrossStubModes() throws {
        assertCalendarMode("permission", expectedStateID: "home.calendar.state.permission", expectsRetry: false)
        assertCalendarMode("noCalendars", expectedStateID: "home.calendar.state.noCalendars", expectsRetry: false)
        assertCalendarMode("empty", expectedStateID: "home.calendar.state.empty", expectsRetry: false)
        assertCalendarMode("active", expectedStateID: "home.calendar.state.active", expectsRetry: false)
        assertCalendarMode("error", expectedStateID: "home.calendar.state.error", expectsRetry: true)
    }

    func testSettingsCalendarControlsSmokePath() throws {
        let app = launchApp(calendarMode: "active")
        let homePage = HomePage(app: app)
        let settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(timeout: 8))

        let accessRow = findInScrollableView(app: app, identifier: "settings.calendar.access.row", elementType: .any)
        let selectionRow = findInScrollableView(app: app, identifier: "settings.calendar.selection.row", elementType: .any)
        let includeDeclined = findInScrollableView(app: app, identifier: "settings.calendar.includeDeclined.toggle", elementType: .switch)
        let includeAllDayAgenda = findInScrollableView(app: app, identifier: "settings.calendar.includeAllDayAgenda.toggle", elementType: .switch)
        let includeAllDayBusy = findInScrollableView(app: app, identifier: "settings.calendar.includeAllDayBusy.toggle", elementType: .switch)

        XCTAssertTrue(accessRow.exists)
        XCTAssertTrue(selectionRow.exists)
        XCTAssertTrue(includeDeclined.exists)
        XCTAssertTrue(includeAllDayAgenda.exists)
        XCTAssertTrue(includeAllDayBusy.exists)

        XCTAssertTrue(accessRow.isHittable || accessRow.isEnabled)
        XCTAssertTrue(selectionRow.isHittable || selectionRow.isEnabled)
        XCTAssertTrue(includeDeclined.isHittable || includeDeclined.isEnabled)
        XCTAssertTrue(includeAllDayAgenda.isHittable || includeAllDayAgenda.isEnabled)
        XCTAssertTrue(includeAllDayBusy.isHittable || includeAllDayBusy.isEnabled)
    }

    func testCalendarTimelinePreviewOpensSchedule() throws {
        let app = launchApp(calendarMode: "active")

        openSchedule(from: app)

        let segmentedControl = app.descendants(matching: .any)["schedule.segmented"]
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["schedule.list"].exists)
    }

    func testScheduleSwitchesBetweenTodayAndWeekTabs() throws {
        let app = launchApp(calendarMode: "active")

        openSchedule(from: app)

        let weekTab = scheduleWeekTab(in: app)
        XCTAssertTrue(weekTab.waitForExistence(timeout: 8))
        weekTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule.week.content"].waitForExistence(timeout: 8))
    }

    func testScheduleFiltersOpenCustomChooserAndCommitSelection() throws {
        let app = launchApp(calendarMode: "active")

        openSchedule(from: app)

        let filters = app.descendants(matching: .any)["schedule.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8))
        filters.tap()

        let personalCalendar = app.descendants(matching: .any)["schedule.chooser.calendar.personal"]
        XCTAssertTrue(personalCalendar.waitForExistence(timeout: 8))
        personalCalendar.tap()

        let done = scheduleChooserDoneButton(in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        done.tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule.segmented"].waitForExistence(timeout: 8))
    }

    func testScheduleTimelineExpandsInlineAndCollapsesBack() throws {
        let app = launchApp(calendarMode: "active")

        openSchedule(from: app)

        let compactTimeline = app.descendants(matching: .any)["schedule.timeline.compact"]
        XCTAssertTrue(compactTimeline.waitForExistence(timeout: 8))
        compactTimeline.tap()

        let expandedTimeline = app.descendants(matching: .any)["schedule.timeline.expanded"]
        XCTAssertTrue(expandedTimeline.waitForExistence(timeout: 8))

        let toggle = app.buttons["schedule.timeline.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        toggle.tap()

        XCTAssertTrue(compactTimeline.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["schedule.event.test_meeting_1"].exists)
    }

    func testScheduleEventRowOpensNativeEventDetail() throws {
        let app = launchApp(calendarMode: "active")

        openSchedule(from: app)

        let eventRow = scheduleEventRow(in: app, identifier: "schedule.event.test_meeting_1", fallbackTitle: "Design Review")
        XCTAssertTrue(eventRow.waitForExistence(timeout: 8))
        eventRow.tap()

        let closeButton = scheduleDetailCloseButton(in: app)
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8))
        closeButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule.segmented"].waitForExistence(timeout: 8))
    }

    private func assertCalendarMode(_ mode: String, expectedStateID: String, expectsRetry: Bool) {
        let app = launchApp(calendarMode: mode)
        let card = app.descendants(matching: .any)["home.calendar.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Calendar card should render for mode \(mode)")

        let state = app.descendants(matching: .any)[expectedStateID]
        let knownStateIDs = [
            "home.calendar.state.permission",
            "home.calendar.state.permission.notDetermined",
            "home.calendar.state.permission.denied",
            "home.calendar.state.permission.restricted",
            "home.calendar.state.permission.writeOnly",
            "home.calendar.state.noCalendars",
            "home.calendar.state.empty",
            "home.calendar.state.active",
            "home.calendar.state.error"
        ]
        let visibleStates = knownStateIDs.filter { app.descendants(matching: .any)[$0].exists }
        let diagnostics = [
            "home.calendar.connect",
            "home.calendar.nextMeeting",
            "home.calendar.freeUntil",
            "home.calendar.busyStrip",
            "home.calendar.timelinePreview",
            "home.calendar.retry",
            "home.calendar.filters",
            "home.calendar.openSchedule"
        ]
        let visibleDiagnostics = diagnostics.filter { app.descendants(matching: .any)[$0].exists }
        XCTAssertTrue(
            state.waitForExistence(timeout: 8),
            "Expected calendar state \(expectedStateID) for mode \(mode). Visible states: \(visibleStates); Visible diagnostics: \(visibleDiagnostics)"
        )

        let filters = app.descendants(matching: .any)["home.calendar.filters"]
        let openSchedule = app.descendants(matching: .any)["home.calendar.openSchedule"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8))
        XCTAssertTrue(openSchedule.waitForExistence(timeout: 8))

        let retry = app.descendants(matching: .any)["home.calendar.retry"]
        if expectsRetry {
            XCTAssertTrue(retry.waitForExistence(timeout: 8))
        } else {
            XCTAssertFalse(retry.exists)
        }
    }

    private func launchApp(calendarMode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):\(calendarMode)"
        ]
        app.launch()
        return app
    }

    private func findInScrollableView(app: XCUIApplication, identifier: String, elementType: XCUIElement.ElementType) -> XCUIElement {
        let query = app.descendants(matching: elementType).matching(identifier: identifier)
        let element = query.firstMatch
        if element.exists {
            return element
        }

        for _ in 0..<6 {
            app.swipeUp()
            if element.exists {
                break
            }
        }
        return element
    }

    private func openSchedule(from app: XCUIApplication) {
        let timelinePreview = app.descendants(matching: .any)["home.calendar.timelinePreview"]
        if timelinePreview.waitForExistence(timeout: 4) {
            timelinePreview.tap()
            return
        }

        let openSchedule = app.descendants(matching: .any)["home.calendar.openSchedule"]
        XCTAssertTrue(openSchedule.waitForExistence(timeout: 8))
        openSchedule.tap()
    }

    private func scheduleWeekTab(in app: XCUIApplication) -> XCUIElement {
        let identified = app.descendants(matching: .any)["schedule.segment.week"]
        if identified.exists {
            return identified
        }
        return app.buttons["Week"].firstMatch
    }

    private func scheduleChooserDoneButton(in app: XCUIApplication) -> XCUIElement {
        let identified = app.buttons.matching(identifier: "schedule.chooser.done").firstMatch
        if identified.exists {
            return identified
        }
        return app.buttons["Done"].firstMatch
    }

    private func scheduleEventRow(in app: XCUIApplication, identifier: String, fallbackTitle: String) -> XCUIElement {
        let identified = app.buttons.matching(identifier: identifier).firstMatch
        if identified.exists {
            return identified
        }

        let buttonMatch = app.buttons[fallbackTitle].firstMatch
        if buttonMatch.exists {
            return buttonMatch
        }

        let containerMatch = app.otherElements.containing(.staticText, identifier: fallbackTitle).firstMatch
        if containerMatch.exists {
            return containerMatch
        }

        return app.staticTexts[fallbackTitle].firstMatch
    }

    private func scheduleDetailCloseButton(in app: XCUIApplication) -> XCUIElement {
        let identified = app.descendants(matching: .any)["schedule.detail.close"]
        if identified.exists {
            return identified
        }

        return app.navigationBars.buttons["Close"].firstMatch
    }
}
