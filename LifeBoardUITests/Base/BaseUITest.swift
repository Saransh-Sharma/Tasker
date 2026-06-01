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
    var shouldSkipOnboarding: Bool { true }

    // MARK: - Test Lifecycle

    override func setUpWithError() throws {
        try super.setUpWithError()

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
        if shouldSkipOnboarding {
            app.launchArguments.append("-SKIP_ONBOARDING")
        }
        app.launchArguments.append(contentsOf: additionalLaunchArguments)

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
        let homeIndicator = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
        let homeExists = homeIndicator.waitForExistence(timeout: shouldSkipOnboarding ? 12 : 6)

        if homeExists {
            return
        }

        if !shouldSkipOnboarding {
            let onboardingFlow = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.flow]
            let onboardingPrompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
            let onboardingFinish = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.finish]
            let onboardingExists =
                onboardingFlow.waitForExistence(timeout: 20)
                || onboardingPrompt.waitForExistence(timeout: 4)
                || onboardingFinish.waitForExistence(timeout: 4)
            if onboardingExists {
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

    // MARK: - Seeded Timeline Launch

    func launchSeededTimelineWorkspace(
        calendarMode: String = "active",
        skipOnboarding: Bool = true,
        evaActivationCompleted: Bool = false
    ) {
        app?.terminate()
        app = XCUIApplication()
        app.launchSeededTimelineWorkspace(
            calendarMode: calendarMode,
            skipOnboarding: skipOnboarding,
            evaActivationCompleted: evaActivationCompleted
        )
        ensureHomeTimelineReady()
    }

    @discardableResult
    func ensureHomeTimelineReady(
        timeout: TimeInterval = 14,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        dismissOnboardingIfNeeded()

        let home = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
        let allFilter = app.buttons[AccessibilityIdentifiers.Home.sunriseFilter("all")]
        let bottomBarHome = app.buttons[AccessibilityIdentifiers.Home.bottomBarHome]
        let bottomBarCalendar = app.buttons["home.bottomBar.calendar"]
        let timelineSurface = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineSurface]
        let timelineContent = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.timelineContent]
        let timelineCards = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                "home.timeline.task.",
                "home.timeline.event."
            )
        )

        let predicate = NSPredicate { _, _ in
            let hasHomeSignal = home.exists || allFilter.exists || bottomBarHome.exists || bottomBarCalendar.exists
            let hasTimelineSignal = timelineSurface.exists || timelineContent.exists || timelineCards.firstMatch.exists
            return hasHomeSignal && hasTimelineSignal
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Home timeline did not become ready for seeded UI test", file: file, line: line)
            return false
        }
        return true
    }

    private func dismissOnboardingIfNeeded() {
        let prompt = app.descendants(matching: .any)[AccessibilityIdentifiers.Onboarding.prompt]
        if prompt.waitForExistence(timeout: 1.5) {
            let dismissCandidates = [
                app.buttons[AccessibilityIdentifiers.Onboarding.promptDismiss],
                app.buttons["Not now"],
                app.buttons["Skip for now"]
            ]
            if let dismiss = dismissCandidates.first(where: { $0.exists && $0.isHittable }) {
                dismiss.tap()
            }
        }

        let successHome = app.buttons[AccessibilityIdentifiers.Onboarding.goHome]
        if successHome.waitForExistence(timeout: 1), successHome.isHittable {
            successHome.tap()
            return
        }

        let skip = app.buttons[AccessibilityIdentifiers.Onboarding.skipButton]
        if skip.waitForExistence(timeout: 1), skip.isHittable {
            skip.tap()
        }
    }

    @discardableResult
    func ensurePerformanceAppReady(
        timeout: TimeInterval = 14,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let home = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.view]
            let bottomBar = app.descendants(matching: .any)[AccessibilityIdentifiers.Home.bottomBar]
            if home.exists || bottomBar.exists {
                return true
            }

            dismissOnboardingIfNeeded()

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
            AccessibilityIdentifiers.Onboarding.flow,
            AccessibilityIdentifiers.Onboarding.prompt,
            AccessibilityIdentifiers.Onboarding.finish,
            "eva.activation.intro",
            "eva.activation.about_you",
            "eva.activation.goals",
            "eva.activation.model_choice",
            "eva.activation.install_model",
            "eva.activation.downloading_model"
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
