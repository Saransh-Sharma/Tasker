import XCTest

final class HomeCalendarModuleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCalendarCardRendersInActiveStubMode() throws {
        let app = XCUIApplication()
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
        app.launch()

        let card = app.descendants(matching: .any)["home.calendar.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 12))

        let openScheduleButton = app.buttons["home.calendar.openSchedule"]
        XCTAssertTrue(openScheduleButton.waitForExistence(timeout: 8))
    }

    func testCalendarCardPermissionStateShowsConnectCTA() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.skipOnboarding.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue,
            XCUIApplication.LaunchArgumentKey.testCalendarStub.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testCalendarMode.rawValue):permission"
        ]
        app.launch()

        let card = app.descendants(matching: .any)["home.calendar.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 12))

        let filterButton = app.buttons["home.calendar.filters"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 8))
    }
}
