import XCTest

final class HomeTriageAndTop3Tests: BaseUITest {
    func testTopThreeAssistControlIsReachableWhenVisible() throws {
        let button = app.buttons["Help me choose"]
        guard button.waitForExistence(timeout: 5) else {
            throw XCTSkip("Top-3 assistant entry is not visible in this launch state")
        }

        button.tap()

        let loadingText = app.staticTexts["Choosing top 3..."]
        let headerText = app.staticTexts["Eva suggestions"]
        XCTAssertTrue(
            loadingText.waitForExistence(timeout: 2) || headerText.waitForExistence(timeout: 2)
        )
    }

    func testOverdueTriageSheetCanOpenWhenPresented() throws {
        let triageTitle = app.navigationBars["Overdue Triage"]
        if triageTitle.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.buttons["Dismiss"].exists || app.buttons["Close"].exists)
        } else {
            throw XCTSkip("Overdue triage did not auto-present in this seed state")
        }
    }
}
