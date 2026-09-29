//
//  BaseUITest.swift
//  LifeBoardUITests
//
//  Base test class providing fresh app state, common utilities, and test lifecycle management
//

import XCTest

@MainActor
class BaseUITest: XCTestCase {

    // MARK: - Properties

    var app: XCUIApplication!
    var additionalLaunchArguments: [String] { [] }
    var additionalLaunchEnvironment: [String: String] { [:] }
    var shouldSkipOnboarding: Bool { true }

    // MARK: - Test Lifecycle

    override func setUp() async throws {
        try await super.setUp()

        // Stop immediately on failure for easier debugging
        continueAfterFailure = false

        // Initialize app with fresh state
        app = XCUIApplication()
        app.launchArguments = [
            XCUIApplication.LaunchArgumentKey.resetAppState.rawValue,
            XCUIApplication.LaunchArgumentKey.uiTesting.rawValue,
            XCUIApplication.LaunchArgumentKey.disableAnimations.rawValue,
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue
        ]
        app.launchEnvironment[XCUIApplication.LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        for (key, value) in additionalLaunchEnvironment {
            app.launchEnvironment[key] = value
        }
        if shouldSkipOnboarding {
            app.launchArguments.append("-SKIP_ONBOARDING")
        }
        app.launchArguments.append(contentsOf: additionalLaunchArguments)

        app.launch()
        waitForAppLaunch()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil

        try await super.tearDown()
    }

    // MARK: - App Launch

    /// Wait for app to finish launching and be ready for interaction
    func waitForAppLaunch() {
        let homeIndicator = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.header]
        let foundationHome = app.buttons["foundation.destination.home"]
        // At iPad and Mac widths the roots live in the top switcher, not the
        // dock; without this every iPad run failed here before its test began.
        let switcherHome = app.buttons["foundation.expanded.destination.home"]
        let predicate = NSPredicate { _, _ in
            homeIndicator.exists || foundationHome.exists || switcherHome.exists
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        let homeExists = XCTWaiter.wait(
            for: [expectation],
            timeout: shouldSkipOnboarding ? 12 : 6
        ) == .completed

        if homeExists {
            return
        }

        if !shouldSkipOnboarding {
            let lifeWeaveFlow = app.descendants(matching: .any)[AccessibilityIdentifiers.LifeWeave.flow]
            if lifeWeaveFlow.waitForExistence(timeout: 20) {
                return
            }
        }

        let navBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        XCTAssert(
            navBar.waitForExistence(timeout: 5) || tabBar.waitForExistence(timeout: 5),
            "App did not launch successfully within timeout"
        )
    }

    @discardableResult
    func ensurePerformanceAppReady(
        timeout: TimeInterval = 14,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let home = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.header]
            let foundationHome = app.buttons[AccessibilityIdentifiers.Shell.destination("home")]
            let switcherHome = app.buttons[AccessibilityIdentifiers.Shell.expandedDestination("home")]
            if home.exists || foundationHome.exists || switcherHome.exists {
                return true
            }

            if let blockingDescription = blockingSetupSurfaceDescription() {
                XCTFail(
                    "Performance test cannot start while setup is blocking the app: \(blockingDescription). Sign in or complete setup before measurement; sign-in time must not be included in performance metrics.",
                    file: file,
                    line: line
                )
                return false
            }

            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        }

        if let blockingDescription = blockingSetupSurfaceDescription() {
            XCTFail(
                "Performance test app did not reach Home because setup is blocking it: \(blockingDescription).",
                file: file,
                line: line
            )
        } else {
            XCTFail("Performance test app did not reach Home before measurement started.", file: file, line: line)
        }
        return false
    }

    private func blockingSetupSurfaceDescription() -> String? {
        let setupIdentifiers = [
            AccessibilityIdentifiers.LifeWeave.flow,
            "eva.activation.intro",
            "eva.activation.about_you",
            "eva.activation.model_choice"
        ]
        for identifier in setupIdentifiers {
            if app.descendants(matching: .any)[identifier].exists {
                return identifier
            }
        }

        let blockingTextPredicate = NSPredicate(
            format: "label MATCHES[c] %@ OR value MATCHES[c] %@",
            ".*(sign in|login|log in|passkey|passcode|password|authenticate|authentication|apple id|icloud).*",
            ".*(sign in|login|log in|passkey|passcode|password|authenticate|authentication|apple id|icloud).*"
        )
        if app.descendants(matching: .any).matching(blockingTextPredicate).firstMatch.exists {
            return "sign-in/passkey prompt in app"
        }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.matching(blockingTextPredicate).firstMatch.exists
            || springboard.sheets.matching(blockingTextPredicate).firstMatch.exists
            || springboard.descendants(matching: .any).matching(blockingTextPredicate).firstMatch.exists {
            return "system sign-in/passkey prompt"
        }

        return nil
    }

    // MARK: - Wait Helpers

    /// Wait for element to exist with timeout
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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

            if #available(iOS 15.0, *) {
                let selectAllCandidates: [XCUIElement] = [
                    app.menuItems["Select All"],
                    app.buttons["Select All"],
                    app.descendants(matching: .any)["Select All"]
                ]

                if let selectAll = selectAllCandidates.first(where: { $0.waitForExistence(timeout: 1) }) {
                    selectAll.tap()
                    app.typeText(XCUIKeyboardKey.delete.rawValue)
                } else {
                    // Backspaces delete behind the caret, and the double tap
                    // left it inside the first word, so the tail survived
                    // ("…update"). Put the caret after the last character
                    // (bottom-right covers multi-line fields) first.
                    element.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.9)).tap()
                    let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                    element.typeText(deleteString)
                }
            } else {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
                element.typeText(deleteString)
            }
        }

        element.typeText(text)
    }

    /// Swipe to delete element in table view
    func swipeToDelete(
        _ element: XCUIElement,
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
        file: StaticString = #filePath,
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
