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

        let timelinePreview = app.descendants(matching: .any)["home.calendar.timelinePreview"]
        XCTAssertTrue(timelinePreview.waitForExistence(timeout: 12))

        timelinePreview.tap()

        let segmentedControl = app.descendants(matching: .any)["schedule.segmented"]
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["schedule.list"].exists)
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
}
