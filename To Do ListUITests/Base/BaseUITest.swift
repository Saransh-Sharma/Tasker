//
//  BaseUITest.swift
//  To Do ListUITests
//
//  Base test class providing fresh app state, common utilities, and test lifecycle management
//

import XCTest

class BaseUITest: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!

    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Stop immediately on failure for easier debugging
        continueAfterFailure = false

        // Initialize app with fresh state
        app = XCUIApplication()
        app.launchArguments = [
            "-RESET_APP_STATE",  // Reset all data
            "-UI_TESTING",       // Flag for UI testing mode
            "-DISABLE_ANIMATIONS" // Speed up tests
        ]

        // Launch the app
        app.launch()

        // Wait for app to be ready
        waitForAppLaunch()
    }

    override func tearDownWithError() throws {
        // Terminate the app
        app.terminate()
        app = nil

        try super.tearDownWithError()
    }

    // MARK: - App Launch

    /// Wait for app to finish launching and be ready for interaction
    func waitForAppLaunch() {
        // Wait for home screen to appear
        let homeIndicator = app.otherElements["home.view"]
        let exists = homeIndicator.waitForExistence(timeout: 10)

        if !exists {
            // Fallback: wait for any navigation bar or tab bar
            let navBar = app.navigationBars.firstMatch
            let tabBar = app.tabBars.firstMatch
            XCTAssert(
                navBar.waitForExistence(timeout: 5) || tabBar.waitForExistence(timeout: 5),
                "App did not launch successfully within timeout"
            )
        }
    }

    // MARK: - Wait Helpers

    /// Wait for element to exist with timeout
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            XCTFail(
                "Element \(element.debugDescription) did not appear within \(timeout) seconds",
                file: file,
                line: line
            )
        }
        return exists
    }

    /// Wait for element to disappear with timeout
    @discardableResult
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        if result != .completed {
            XCTFail(
                "Element \(element.debugDescription) did not disappear within \(timeout) seconds",
                file: file,
                line: line
            )
            return false
        }
        return true
    }

    /// Wait for element to be hittable (visible and enabled)
    @discardableResult
    func waitForElementToBeHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)

        if result != .completed {
            XCTFail(
                "Element \(element.debugDescription) did not become hittable within \(timeout) seconds",
                file: file,
                line: line
            )
            return false
        }
        return true
    }

    // MARK: - Interaction Helpers

    /// Tap element and wait for it to be hittable first
    func tapAndWait(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard waitForElementToBeHittable(element, timeout: timeout, file: file, line: line) else {
            return
        }
        element.tap()
    }

    /// Type text into element and wait for it to be hittable first
    func typeTextAndWait(
        _ element: XCUIElement,
        text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard waitForElementToBeHittable(element, timeout: timeout, file: file, line: line) else {
            return
        }
        element.tap()
        element.typeText(text)
    }

    /// Clear text from element and type new text
    func clearAndTypeText(
        _ element: XCUIElement,
        text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard waitForElementToBeHittable(element, timeout: timeout, file: file, line: line) else {
            return
        }

        element.tap()

        // Select all text and delete
        if let currentValue = element.value as? String, !currentValue.isEmpty {
            element.tap()
            element.doubleTap() // Select word

            // Try triple tap for full text
            if #available(iOS 15.0, *) {
                element.buttons["Select All"].tap()
            } else {
                // Fallback for older iOS
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                element.typeText(deleteString)
            }
        }

        element.typeText(text)
    }

    /// Swipe to delete element in table view
    func swipeToDelete(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard waitForElement(element, file: file, line: line) else {
            return
        }

        element.swipeLeft()

        // Tap delete button
        let deleteButton = element.buttons["Delete"]
        if waitForElementToBeHittable(deleteButton, timeout: 2) {
            deleteButton.tap()
        }
    }

    // MARK: - Verification Helpers

    /// Verify text exists in the app
    func verifyTextExists(
        _ text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.staticTexts[text]
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Text '\(text)' not found",
            file: file,
            line: line
        )
    }

    /// Verify element exists
    func verifyElementExists(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Element \(element.debugDescription) not found",
            file: file,
            line: line
        )
    }

    /// Verify element does not exist
    func verifyElementDoesNotExist(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            element.exists,
            "Element \(element.debugDescription) should not exist",
            file: file,
            line: line
        )
    }

    /// Verify element is hittable (visible and enabled)
    func verifyElementIsHittable(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.isHittable,
            "Element \(element.debugDescription) is not hittable (visible and enabled)",
            file: file,
            line: line
        )
    }

    // MARK: - Screenshot Helpers

    /// Take screenshot with custom name
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Debug Helpers

    /// Print element hierarchy for debugging
    func printElementHierarchy() {
        print("========== ELEMENT HIERARCHY ==========")
        print(app.debugDescription)
        print("=======================================")
    }

    /// Print all buttons in the app
    func printAllButtons() {
        print("========== ALL BUTTONS ==========")
        let buttons = app.buttons.allElementsBoundByIndex
        for (index, button) in buttons.enumerated() {
            print("Button \(index): label=\(button.label), identifier=\(button.identifier)")
        }
        print("=================================")
    }

    /// Print all text fields in the app
    func printAllTextFields() {
        print("========== ALL TEXT FIELDS ==========")
        let textFields = app.textFields.allElementsBoundByIndex
        for (index, textField) in textFields.enumerated() {
            print("TextField \(index): label=\(textField.label), identifier=\(textField.identifier), value=\(textField.value ?? "nil")")
        }
        print("=====================================")
    }
}
