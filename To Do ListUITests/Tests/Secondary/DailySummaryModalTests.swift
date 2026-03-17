//
//  DailySummaryModalTests.swift
//  To Do ListUITests
//
//  Secondary tests for notification-routed daily summary modals.
//

import XCTest

final class DailySummaryModalTests: BaseUITest {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func summaryElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func testMorningRoutePresentsMorningSummaryModal() {
        app.launchWithTestRoute(
            "daily_summary:morning:20260225",
            additionalArguments: [.enableLiquidMetalCTA]
        )

        let modal = summaryElement(AccessibilityIdentifiers.Home.dailySummaryModal)
        XCTAssertTrue(modal.waitForExistence(timeout: 10), "Morning summary modal should appear")

        let startTodayButton = app.buttons["Start Today"]
        XCTAssertTrue(app.staticTexts["Morning Plan"].waitForExistence(timeout: 4))
        XCTAssertTrue(startTodayButton.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Complete Morning Routine"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Start Triage"].waitForExistence(timeout: 4))
        startTodayButton.tap()
        waitForElementToDisappear(modal, timeout: 2)
    }

    func testNightlyRoutePresentsNightlySummaryModal() {
        app.launchWithTestRoute(
            "daily_summary:nightly:20260225",
            additionalArguments: [.enableLiquidMetalCTA]
        )

        let modal = summaryElement(AccessibilityIdentifiers.Home.dailySummaryModal)
        XCTAssertTrue(modal.waitForExistence(timeout: 10), "Nightly summary modal should appear")

        let planTomorrowButton = app.buttons["Plan Tomorrow"]
        XCTAssertTrue(app.staticTexts["Day Retrospective"].waitForExistence(timeout: 4))
        XCTAssertTrue(planTomorrowButton.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Review Done"].waitForExistence(timeout: 4))
        planTomorrowButton.tap()
        waitForElementToDisappear(modal, timeout: 2)
    }
}
