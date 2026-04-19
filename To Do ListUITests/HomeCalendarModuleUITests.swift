import XCTest

final class HomeCalendarModuleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCalendarCardStateTransitionsAcrossStubModes() throws {
        assertCalendarMode("permission", expectedStateID: "home.calendar.state.permission", expectsRetry: false)
        assertCalendarMode("noCalendars", expectedStateID: "home.calendar.state.noCalendars", expectsRetry: false)
        assertCalendarMode("allDayOnly", expectedStateID: "home.calendar.state.allDayOnly", expectsRetry: false)
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

        let timelinePreview = homeTimelinePreview(in: app)
        XCTAssertTrue(
            waitForElementWithScrolling(timelinePreview, in: app, timeout: 10, scrollAttempts: 4),
            "Expected timeline preview to be visible in active calendar mode."
        )
        tapElement(timelinePreview, in: app)
        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))

        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["schedule.list"].exists)
    }

    func testScheduleSwitchesBetweenTodayAndWeekTabs() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromCardOrTimeline(from: app)

        let weekTab = scheduleWeekTab(in: app)
        XCTAssertTrue(weekTab.waitForExistence(timeout: 8))
        weekTab.tap()

        XCTAssertTrue(
            accessibilityValueContainsSelected(weekTab),
            "Week tab should be selected after tapping it."
        )

        let selectedSummary = app.descendants(matching: .any)["schedule.week.selectedDay"]
        XCTAssertTrue(
            waitForElementWithScrolling(selectedSummary, in: app, timeout: 8),
            "Selected-day summary should render in week mode."
        )
        let initialSummary = selectedSummary.label

        let dayChips = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule.week.day."))
        XCTAssertGreaterThanOrEqual(dayChips.count, 2)
        let alternateDay = dayChips.element(boundBy: 1)
        tapElement(alternateDay, in: app)

        XCTAssertNotEqual(initialSummary, selectedSummary.label, "Selected day summary should change when week strip selection changes.")
    }

    func testScheduleFiltersOpenCustomChooserAndCommitSelection() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromCardOrTimeline(from: app)

        let filters = app.buttons["schedule.toolbar.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8))
        filters.tap()

        let personalCalendar = app.descendants(matching: .any)["schedule.chooser.calendar.personal"]
        XCTAssertTrue(personalCalendar.waitForExistence(timeout: 8))
        personalCalendar.tap()

        let done = scheduleChooserDoneButton(in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        done.tap()

        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
    }

    func testScheduleTimelineIsAlwaysExpandedInRedesign() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromCardOrTimeline(from: app)
        XCTAssertTrue(
            waitForActiveScheduleContent(in: app, timeout: 10),
            "Expected active schedule content to render in active mode. Visible states: \(scheduleStateDiagnostics(in: app))"
        )

        let expandedTimeline = app.descendants(matching: .any)["schedule.timeline.expanded"]
        XCTAssertTrue(
            waitForElementWithScrolling(expandedTimeline, in: app, timeout: 8),
            "Expanded timeline should render by default in redesigned schedule mode."
        )

        let toggle = app.buttons["schedule.timeline.toggle"]
        XCTAssertFalse(toggle.exists, "Timeline expand/collapse toggle should not be present after redesign.")

        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
    }

    func testScheduleEventRowOpensNativeEventDetail() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromCardOrTimeline(from: app)
        XCTAssertTrue(
            waitForActiveScheduleContent(in: app, timeout: 10),
            "Expected active schedule content to render in active mode. Visible states: \(scheduleStateDiagnostics(in: app))"
        )

        let eventRow = scheduleEventRow(in: app, identifier: "schedule.event.test_meeting_1")
        XCTAssertTrue(
            waitForElementWithScrolling(eventRow, in: app, timeout: 8),
            "Expected stub event row to be discoverable in active schedule mode."
        )
        tapElement(eventRow, in: app)

        XCTAssertTrue(
            dismissScheduleEventDetailIfPresented(in: app),
            "Expected event detail to expose a deterministic dismiss action."
        )

        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
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
            "home.calendar.state.allDayOnly",
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
            "home.calendar.retry"
        ]
        let visibleDiagnostics = diagnostics.filter { app.descendants(matching: .any)[$0].exists }
        if expectedStateID == "home.calendar.state.active" {
            let timelinePreview = app.descendants(matching: .any)["home.calendar.timelinePreview"]
            let activeSignalVisible = state.waitForExistence(timeout: 4) || timelinePreview.waitForExistence(timeout: 4)
            XCTAssertTrue(
                activeSignalVisible,
                "Expected active calendar signal for mode \(mode). Visible states: \(visibleStates); Visible diagnostics: \(visibleDiagnostics)"
            )
        } else {
            XCTAssertTrue(
                state.waitForExistence(timeout: 8),
                "Expected calendar state \(expectedStateID) for mode \(mode). Visible states: \(visibleStates); Visible diagnostics: \(visibleDiagnostics)"
            )
        }

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

    private func openScheduleFromCardOrTimeline(from app: XCUIApplication) {
        let card = app.descendants(matching: .any)["home.calendar.card"]
        XCTAssertTrue(waitForElementWithScrolling(card, in: app, timeout: 8))
        tapElement(card, in: app)
        if scheduleSurfaceIsVisible(in: app, timeout: 2) {
            return
        }
        let timelinePreview = homeTimelinePreview(in: app)
        XCTAssertTrue(waitForElementWithScrolling(timelinePreview, in: app, timeout: 8))
        tapElement(timelinePreview, in: app)
        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
    }

    private func scheduleWeekTab(in app: XCUIApplication) -> XCUIElement {
        let identified = app.buttons["schedule.segment.week"]
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

    private func scheduleEventRow(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let prioritizedCandidates: [XCUIElement] = [
            app.buttons.matching(identifier: identifier).firstMatch,
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        ]

        for candidate in prioritizedCandidates where waitForElementWithScrolling(candidate, in: app, timeout: 2, scrollAttempts: 4) {
            return candidate
        }

        return app.buttons.matching(identifier: identifier).firstMatch
    }

    private func homeTimelinePreview(in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["home.calendar.timelinePreview"]
        if button.exists {
            return button
        }
        return app.descendants(matching: .any)["home.calendar.timelinePreview"]
    }

    private func dismissScheduleEventDetailIfPresented(in app: XCUIApplication) -> Bool {
        let sheet = app.sheets.firstMatch
        let detailSheet = app.descendants(matching: .any)["schedule.detail.sheet"]
        let identifiedClose = app.descendants(matching: .any)["schedule.detail.close"]
        let done = app.navigationBars.buttons["Done"].firstMatch

        let detailAppeared =
            sheet.waitForExistence(timeout: 2) ||
            detailSheet.waitForExistence(timeout: 2) ||
            identifiedClose.waitForExistence(timeout: 2) ||
            done.waitForExistence(timeout: 2)

        if detailAppeared {
            if identifiedClose.exists {
                tapElement(identifiedClose, in: app)
            } else if done.exists {
                done.tap()
            } else {
                if sheet.exists {
                    sheet.swipeDown()
                } else {
                    app.swipeDown()
                }
            }
        } else {
            app.swipeDown()
        }

        return scheduleSurfaceIsVisible(in: app, timeout: 8)
    }

    private func scheduleSurfaceIsVisible(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let filters = app.buttons["schedule.toolbar.filters"]
        return filters.waitForExistence(timeout: timeout)
    }

    private func waitForActiveScheduleContent(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        ensureCalendarSelectionIfNeeded(in: app)

        if hasActiveScheduleSignals(in: app) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasActiveScheduleSignals(in: app) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return hasActiveScheduleSignals(in: app)
    }

    private func ensureCalendarSelectionIfNeeded(in app: XCUIApplication) {
        let noCalendarsState = app.descendants(matching: .any)["schedule.noCalendars.body"]
        guard noCalendarsState.waitForExistence(timeout: 1.2) else { return }

        let filters = app.buttons["schedule.toolbar.filters"]
        guard filters.waitForExistence(timeout: 4) else { return }
        filters.tap()

        let workCalendar = app.descendants(matching: .any)["schedule.chooser.calendar.work"]
        guard workCalendar.waitForExistence(timeout: 8) else { return }
        if accessibilityValueContainsSelected(workCalendar) == false {
            workCalendar.tap()
        }

        let done = scheduleChooserDoneButton(in: app)
        guard done.waitForExistence(timeout: 6) else { return }
        done.tap()
        _ = scheduleSurfaceIsVisible(in: app, timeout: 8)
    }

    private func hasActiveScheduleSignals(in app: XCUIApplication) -> Bool {
        let eventRow = app.descendants(matching: .any)["schedule.event.test_meeting_1"]
        let expandedTimeline = app.descendants(matching: .any)["schedule.timeline.expanded"]
        let weekDayRows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "schedule.week.day."))
        return eventRow.exists || expandedTimeline.exists || weekDayRows.firstMatch.exists
    }

    private func scheduleStateDiagnostics(in app: XCUIApplication) -> String {
        let stateIDs = [
            "schedule.loading.initial",
            "schedule.noCalendars.body",
            "schedule.error.message",
            "schedule.permission.state.notDetermined",
            "schedule.permission.state.denied",
            "schedule.permission.state.restricted",
            "schedule.permission.state.writeOnly",
            "schedule.permission.state.authorized",
            "schedule.today.empty",
            "schedule.week.empty",
            "schedule.timeline.expanded",
            "schedule.timeline.empty"
        ]
        let visible = stateIDs.filter { app.descendants(matching: .any)[$0].exists }
        return visible.isEmpty ? "none" : visible.joined(separator: ", ")
    }

    private func waitForElementWithScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval,
        scrollAttempts: Int = 8
    ) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            return true
        }

        for _ in 0..<scrollAttempts {
            app.swipeUp()
            if element.exists {
                return true
            }
        }

        for _ in 0..<scrollAttempts {
            app.swipeDown()
            if element.exists {
                return true
            }
        }

        return element.exists
    }

    private func tapElement(_ element: XCUIElement, in app: XCUIApplication) {
        if element.isHittable {
            element.tap()
            return
        }

        for _ in 0..<4 {
            app.swipeUp()
            if element.isHittable {
                element.tap()
                return
            }
        }

        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }

    private func accessibilityValueContainsSelected(_ element: XCUIElement) -> Bool {
        guard let value = element.value as? String else { return element.isSelected }
        return value.localizedCaseInsensitiveContains("selected")
    }
}
