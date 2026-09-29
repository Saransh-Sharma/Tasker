import XCTest

/// Calendar access and recovery in the live app.
///
/// The Home schedule face (`schedule.*`), its bottom-bar calendar button, and
/// Home's day handles are gone. Calendar settings live in Settings, and the
/// read-only calendar state shows on Plan's day (`PlanCalendarStateSection`).
@MainActor
final class HomeCalendarModuleUITests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func testSettingsCalendarControlsSmokePath() throws {
        let app = launchApp(calendarMode: "active")
        let homePage = HomePage(app: app)
        let settingsPage = homePage.tapSettings()
        XCTAssertTrue(settingsPage.verifyIsDisplayed(timeout: 8))
        XCTAssertTrue(settingsPage.openCategory("calendarAndHealth"), "Calendar settings live in the Calendar & Health category")

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
        XCTAssertTrue(settingsPage.openCategory("calendarAndHealth"), "Calendar settings live in the Calendar & Health category")

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

    func testCalendarPermissionPlanOffersReadOnlyAccess() throws {
        let app = launchApp(calendarMode: "permission")
        XCTAssertTrue(HomePage(app: app).openRoot("plan"), "Plan should open from the root chrome")

        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Plan.calendarNotRequested].firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "Plan should offer read-only calendar access when it has not been requested")
        XCTAssertTrue(app.buttons["Allow"].waitForExistence(timeout: 3), "The calendar prompt should offer Allow")
    }

    func testCalendarDeniedPlanShowsSettingsRecovery() throws {
        let app = launchApp(calendarMode: "denied")
        XCTAssertTrue(HomePage(app: app).openRoot("plan"), "Plan should open from the root chrome")

        let denied = app.descendants(matching: .any)[AccessibilityIdentifiers.Plan.calendarDenied].firstMatch
        XCTAssertTrue(denied.waitForExistence(timeout: 10), "Plan should say calendar is off when access is denied")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == 'Settings'")).firstMatch.waitForExistence(timeout: 3),
            "Denied calendar access should offer a way to Settings"
        )
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
