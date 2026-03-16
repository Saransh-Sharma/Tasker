//
//  DailySummaryModalTests.swift
//  To Do ListUITests
//
//  Secondary tests for notification-routed daily summary modals.
//

import XCTest

final class DailySummaryModalTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        try super.tearDownWithError()
    }

    func testMorningRoutePresentsMorningSummaryModal() {
        app.launchWithTestRoute(
            "daily_summary:morning:20260225",
            additionalArguments: [.enableLiquidMetalCTA]
        )

        let modal = app.otherElements[AccessibilityIdentifiers.Home.dailySummaryModal]
        XCTAssertTrue(modal.waitForExistence(timeout: 10), "Morning summary modal should appear")

        XCTAssertTrue(app.otherElements[AccessibilityIdentifiers.Home.dailySummaryHeroOpenCount].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAStartToday].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTACompleteMorning].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAStartTriage].waitForExistence(timeout: 2))

        app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAStartToday].tap()
        XCTAssertFalse(modal.waitForExistence(timeout: 2), "Primary morning CTA should remain tappable and dismiss the modal")
    }

    func testNightlyRoutePresentsNightlySummaryModal() {
        app.launchWithTestRoute(
            "daily_summary:nightly:20260225",
            additionalArguments: [.enableLiquidMetalCTA]
        )

        let modal = app.otherElements[AccessibilityIdentifiers.Home.dailySummaryModal]
        XCTAssertTrue(modal.waitForExistence(timeout: 10), "Nightly summary modal should appear")

        XCTAssertTrue(app.otherElements[AccessibilityIdentifiers.Home.dailySummaryHeroCompleted].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAPlanTomorrow].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAReviewDone].waitForExistence(timeout: 2))

        app.buttons[AccessibilityIdentifiers.Home.dailySummaryCTAPlanTomorrow].tap()
        XCTAssertFalse(modal.waitForExistence(timeout: 2), "Primary nightly CTA should remain tappable and dismiss the modal")
    }
}
