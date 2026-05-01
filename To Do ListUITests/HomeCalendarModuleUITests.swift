import XCTest

final class HomeCalendarModuleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScheduleOpensFromBottomBarAcrossStubModes() throws {
        for mode in ["permission", "writeOnly", "denied", "deniedAfterAttempt", "noCalendars", "allDayOnly", "empty", "active", "error"] {
            let app = launchApp(calendarMode: mode)
            XCTAssertFalse(
                app.descendants(matching: .any)["home.calendar.card"].waitForExistence(timeout: 2),
                "Inline Home calendar card should be hidden for mode \(mode)."
            )

            openScheduleFromBottomBar(from: app)
            XCTAssertTrue(
                app.descendants(matching: .any)["schedule.list"].waitForExistence(timeout: 8),
                "Expected bottom bar calendar button to open schedule in \(mode) mode."
            )
            app.terminate()
        }
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

    func testSettingsCalendarDeniedShowsPrivacyRecoveryCopy() throws {
        let app = launchApp(calendarMode: "denied")
        let homePage = HomePage(app: app)
        let settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(timeout: 8))

        let accessRow = findInScrollableView(app: app, identifier: "settings.calendar.access.row", elementType: .any)
        XCTAssertTrue(accessRow.exists)
        XCTAssertTrue(
            accessRow.label.localizedCaseInsensitiveContains("Privacy & Security"),
            "Expected Settings recovery copy to mention Privacy & Security. Actual label: \(accessRow.label)"
        )
        XCTAssertTrue(
            accessRow.label.localizedCaseInsensitiveContains("reset Location & Privacy"),
            "Expected Settings recovery copy to mention reset Location & Privacy. Actual label: \(accessRow.label)"
        )
    }

    func testBottomBarCalendarButtonOpensSchedule() throws {
        let app = launchApp(calendarMode: "active")

        XCTAssertFalse(app.descendants(matching: .any)["home.calendar.card"].waitForExistence(timeout: 2))
        openScheduleFromBottomBar(from: app)

        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["schedule.list"].exists)
        XCTAssertFalse(
            app.sheets.firstMatch.waitForExistence(timeout: 1),
            "The bottom-bar schedule should render on the Home foredrop instead of opening a top-level sheet."
        )
    }

    func testScheduleFaceLiquidHandlesShiftDisplayedDay() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromBottomBar(from: app)

        let header = scheduleHeaderContext(in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 8))
        let initialHeader = header.label

        let nextDay = app.buttons[AccessibilityIdentifiers.Home.nextDayHandle].firstMatch
        XCTAssertTrue(nextDay.waitForExistence(timeout: 8), "Expected schedule face to keep the next-day liquid handle visible.")
        tapElement(nextDay, in: app)

        XCTAssertTrue(
            waitForHeader(header, toDifferFrom: initialHeader, timeout: 6),
            "Next-day liquid handle should shift the schedule header date."
        )
        let nextHeader = header.label

        let previousDay = app.buttons[AccessibilityIdentifiers.Home.previousDayHandle].firstMatch
        XCTAssertTrue(previousDay.waitForExistence(timeout: 8), "Expected schedule face to keep the previous-day liquid handle visible.")
        tapElement(previousDay, in: app)

        XCTAssertTrue(
            waitForHeader(header, toEqual: initialHeader, timeout: 6),
            "Previous-day liquid handle should return the schedule header to the original date. Next header was \(nextHeader)."
        )
        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
    }

    func testHomeTimelineEventOpensNativeEventDetailWithoutOpeningSchedule() throws {
        let app = launchApp(calendarMode: "active")

        let eventCard = homeCalendarEvent(in: app, identifier: "home.timeline.event.test_meeting_1")
        XCTAssertTrue(
            waitForElementWithScrolling(eventCard, in: app, timeout: 10, scrollAttempts: 4),
            "Expected Home calendar timeline event to be tappable in active calendar mode."
        )
        tapElement(eventCard, in: app)

        XCTAssertFalse(
            app.descendants(matching: .any)["schedule.list"].waitForExistence(timeout: 1),
            "Tapping a Home timeline event should not open the full schedule behind the event detail."
        )
        XCTAssertTrue(
            dismissEventDetailIfPresented(in: app),
            "Expected Home timeline event tap to present the native event detail sheet."
        )
    }

    func testHomeTimelineEventHideRemovesOnlyHomeTimelineOccurrence() throws {
        let app = launchApp(calendarMode: "active")

        let eventCard = homeCalendarEvent(in: app, identifier: "home.timeline.event.test_meeting_1")
        XCTAssertTrue(
            waitForElementWithScrolling(eventCard, in: app, timeout: 10, scrollAttempts: 4),
            "Expected Home calendar timeline event to be visible before hiding."
        )
        tapElement(eventCard, in: app)

        let hideButton = app.descendants(matching: .any)["schedule.detail.hideFromTimeline"]
        XCTAssertTrue(
            hideButton.waitForExistence(timeout: 4),
            "Expected Home timeline-origin event detail to expose Hide from Timeline."
        )
        tapElement(hideButton, in: app)

        XCTAssertFalse(
            app.descendants(matching: .any)["home.timeline.event.test_meeting_1"].waitForExistence(timeout: 2),
            "Hidden event should be removed from the Home timeline occurrence."
        )

        openScheduleFromBottomBar(from: app)
        XCTAssertTrue(
            waitForActiveScheduleContent(in: app, timeout: 10),
            "Expected schedule content to remain available after hiding a Home timeline event."
        )
        let scheduleEvent = scheduleEventRow(in: app, identifier: "schedule.event.test_meeting_1")
        XCTAssertTrue(
            waitForElementWithScrolling(scheduleEvent, in: app, timeout: 8),
            "Hidden Home timeline event should remain visible in Calendar Schedule."
        )
    }

    func testCalendarPermissionScheduleUsesConnectCTA() throws {
        let app = launchApp(calendarMode: "permission")

        XCTAssertFalse(app.descendants(matching: .any)["home.calendar.card"].waitForExistence(timeout: 2))
        openScheduleFromBottomBar(from: app)

        let connect = app.buttons["schedule.permission.connect"]
        XCTAssertTrue(
            connect.waitForExistence(timeout: 8),
            "Expected permission mode to expose the schedule calendar connect CTA."
        )

        connect.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["schedule.noCalendars.body"].waitForExistence(timeout: 8),
            "After the stub grants calendar access, schedule should ask for calendar selection."
        )
    }

    func testCalendarWriteOnlyScheduleRequestsFullAccessInsteadOfOpeningSettings() throws {
        let app = launchApp(calendarMode: "writeOnly")

        openScheduleFromBottomBar(from: app)

        let connect = app.buttons["schedule.permission.connect"]
        XCTAssertTrue(
            connect.waitForExistence(timeout: 8),
            "Expected write-only schedule mode to expose the full-access CTA."
        )
        XCTAssertTrue(
            connect.label.localizedCaseInsensitiveContains("Full Calendar Access"),
            "Expected write-only CTA to request full access. Actual label: \(connect.label)"
        )

        connect.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["schedule.noCalendars.body"].waitForExistence(timeout: 8),
            "After the stub upgrades full access, schedule should ask for calendar selection."
        )
    }

    func testCalendarDeniedScheduleShowsSettingsRecoveryCopyWithoutFullAccessPromptCTA() throws {
        let app = launchApp(calendarMode: "denied")

        openScheduleFromBottomBar(from: app)

        let deniedBody = app.descendants(matching: .any)["schedule.permission.state.denied"]
        XCTAssertTrue(
            deniedBody.waitForExistence(timeout: 8),
            "Expected denied mode to show denied recovery copy."
        )

        let connect = app.buttons["schedule.permission.connect"]
        XCTAssertTrue(
            connect.waitForExistence(timeout: 8),
            "Expected denied mode to expose a settings recovery CTA."
        )
        XCTAssertEqual(connect.label, "Open Settings")
        XCTAssertTrue(
            deniedBody.label.localizedCaseInsensitiveContains("Privacy & Security"),
            "Expected recovery copy to mention Privacy & Security. Actual label: \(deniedBody.label)"
        )
        XCTAssertTrue(
            deniedBody.label.localizedCaseInsensitiveContains("reset Location & Privacy"),
            "Expected recovery copy to mention reset Location & Privacy. Actual label: \(deniedBody.label)"
        )
    }

    func testCalendarDeniedAfterAttemptShowsSettingsRecoveryCopy() throws {
        let app = launchApp(calendarMode: "deniedAfterAttempt")

        openScheduleFromBottomBar(from: app)

        let deniedBody = app.descendants(matching: .any)["schedule.permission.state.denied"]
        XCTAssertTrue(
            deniedBody.waitForExistence(timeout: 8),
            "Expected denied-after-attempt mode to show denied recovery copy."
        )

        let connect = app.buttons["schedule.permission.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 4))
        XCTAssertEqual(connect.label, "Open Settings")
        XCTAssertTrue(
            deniedBody.label.localizedCaseInsensitiveContains("Privacy & Security"),
            "Expected recovery copy to mention Privacy & Security. Actual label: \(deniedBody.label)"
        )
    }

    func testInlineCalendarCardIsHiddenFromHomeTimeline() throws {
        let app = launchApp(calendarMode: "active")

        XCTAssertFalse(
            app.descendants(matching: .any)["home.calendar.card"].waitForExistence(timeout: 2),
            "The inline foreDrop calendar card should not render above the timeline."
        )
    }

    func testScheduleSwitchesBetweenTodayAndWeekTabs() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromBottomBar(from: app)

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

        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline, selectedSummary.label == initialSummary {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertNotEqual(initialSummary, selectedSummary.label, "Selected day summary should change when week strip selection changes.")
    }

    func testScheduleFiltersOpenCustomChooserAndCommitSelection() throws {
        let app = launchApp(calendarMode: "active")

        openScheduleFromBottomBar(from: app)

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

        openScheduleFromBottomBar(from: app)
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

        openScheduleFromBottomBar(from: app)
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

    private func openScheduleFromBottomBar(from app: XCUIApplication) {
        let calendarButton = bottomBarCalendarButton(in: app)
        XCTAssertTrue(
            calendarButton.waitForExistence(timeout: 8),
            "Expected bottom bar calendar button to exist."
        )
        tapElement(calendarButton, in: app)
        XCTAssertTrue(scheduleSurfaceIsVisible(in: app, timeout: 8))
    }

    private func bottomBarCalendarButton(in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["home.bottomBar.calendar"]
        if button.exists {
            return button
        }
        let any = app.descendants(matching: .any)["home.bottomBar.calendar"]
        if any.exists {
            return any
        }

        for _ in 0..<4 {
            app.swipeDown()
            if button.exists {
                return button
            }
            if any.exists {
                return any
            }
        }

        return any
    }

    private func scheduleWeekTab(in app: XCUIApplication) -> XCUIElement {
        let identified = app.buttons["schedule.segment.week"]
        if identified.exists {
            return identified
        }
        return app.buttons["Week"].firstMatch
    }

    private func scheduleHeaderContext(in app: XCUIApplication) -> XCUIElement {
        let identified = app.staticTexts["schedule.header.context"]
        if identified.exists {
            return identified
        }
        return app.descendants(matching: .any)["schedule.header.context"]
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

    private func homeCalendarEvent(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let button = app.buttons[identifier]
        if button.exists {
            return button
        }
        return app.descendants(matching: .any)[identifier]
    }

    private func dismissScheduleEventDetailIfPresented(in app: XCUIApplication) -> Bool {
        let detailAppeared = dismissEventDetailIfPresented(in: app)
        return detailAppeared && scheduleSurfaceIsVisible(in: app, timeout: 8)
    }

    private func dismissEventDetailIfPresented(in app: XCUIApplication) -> Bool {
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

        return detailAppeared
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

    private func waitForHeader(_ header: XCUIElement, toDifferFrom originalLabel: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if header.exists, header.label != originalLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return header.exists && header.label != originalLabel
    }

    private func waitForHeader(_ header: XCUIElement, toEqual expectedLabel: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if header.exists, header.label == expectedLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return header.exists && header.label == expectedLabel
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
