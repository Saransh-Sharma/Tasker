//
//  XCUIApplication+LaunchArguments.swift
//  To Do ListUITests
//
//  Extension for managing app launch arguments for UI testing
//

import XCTest

extension XCUIApplication {

    // MARK: - Launch Argument Keys

    enum LaunchArgumentKey: String {
        case resetAppState = "-RESET_APP_STATE"
        case uiTesting = "-UI_TESTING"
        case disableAnimations = "-DISABLE_ANIMATIONS"
        case enableLiquidMetalCTA = "-TASKER_ENABLE_LIQUID_METAL_CTA"
        case skipOnboarding = "-SKIP_ONBOARDING"
        case mockDate = "-MOCK_DATE"
        case mockNetworkFailure = "-MOCK_NETWORK_FAILURE"
        case disableCloudSync = "-DISABLE_CLOUD_SYNC"
        case enableDebugLogging = "-ENABLE_DEBUG_LOGGING"
        case mockInboxTasks = "-MOCK_INBOX_TASKS"
        case disableLLM = "-DISABLE_LLM"
        case testRoute = "-TASKER_TEST_ROUTE"
        case testSeedEstablishedWorkspace = "-TASKER_TEST_SEED_ESTABLISHED_WORKSPACE"
        case testSeedRescueWorkspace = "-TASKER_TEST_SEED_RESCUE_WORKSPACE"
        case testSeedCompactRescueWorkspace = "-TASKER_TEST_SEED_COMPACT_RESCUE_WORKSPACE"
        case testSeedFocusWorkspace = "-TASKER_TEST_SEED_FOCUS_WORKSPACE"
        case testSeedHabitBoardWorkspace = "-TASKER_TEST_SEED_HABIT_BOARD_WORKSPACE"
        case testSeedQuietTrackingWorkspace = "-TASKER_TEST_SEED_QUIET_TRACKING_WORKSPACE"
        case testPresentHabitBoard = "-TASKER_TEST_PRESENT_HABIT_BOARD"
        case testCalendarStub = "-TASKER_TEST_CALENDAR_STUB"
        case testCalendarMode = "-TASKER_TEST_CALENDAR_MODE"
        case testHabitDetailEditorSupportDelayMilliseconds = "-TASKER_TEST_HABIT_DETAIL_EDITOR_SUPPORT_DELAY_MS"
    }

    // MARK: - Convenience Launch Methods

    /// Launch with fresh app state (reset all data)
    func launchWithFreshState() {
        launchArguments = [
            LaunchArgumentKey.resetAppState.rawValue,
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.skipOnboarding.rawValue,
            LaunchArgumentKey.disableCloudSync.rawValue
        ]
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    /// Launch with mock data for testing
    func launchWithMockData(taskCount: Int = 5, date: String? = nil) {
        var arguments = [
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.skipOnboarding.rawValue,
            LaunchArgumentKey.mockInboxTasks.rawValue + ":\(taskCount)"
        ]

        if let date = date {
            arguments.append(LaunchArgumentKey.mockDate.rawValue + ":\(date)")
        }

        launchArguments = arguments
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    /// Launch with specific date (for testing date-based features)
    func launchWithDate(_ dateString: String) {
        launchArguments = [
            LaunchArgumentKey.resetAppState.rawValue,
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.mockDate.rawValue + ":\(dateString)"
        ]
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    /// Launch with network failure simulation (for testing offline mode)
    func launchWithNetworkFailure() {
        launchArguments = [
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.mockNetworkFailure.rawValue,
            LaunchArgumentKey.disableCloudSync.rawValue
        ]
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    /// Launch with debug logging enabled
    func launchWithDebugLogging() {
        launchArguments = [
            LaunchArgumentKey.resetAppState.rawValue,
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.enableDebugLogging.rawValue
        ]
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    /// Launch with a notification route payload (for route-driven UI tests)
    func launchWithTestRoute(_ payload: String, additionalArguments: [LaunchArgumentKey] = []) {
        launchArguments = [
            LaunchArgumentKey.resetAppState.rawValue,
            LaunchArgumentKey.uiTesting.rawValue,
            LaunchArgumentKey.disableAnimations.rawValue,
            LaunchArgumentKey.skipOnboarding.rawValue,
            LaunchArgumentKey.disableCloudSync.rawValue,
            "\(LaunchArgumentKey.testRoute.rawValue):\(payload)"
        ]
        launchArguments.append(contentsOf: additionalArguments.map(\.rawValue))
        launchEnvironment[LaunchEnvironmentKey.performanceTest.rawValue] = "1"
        launch()
    }

    // MARK: - Launch Argument Helpers

    /// Add custom launch argument
    func addLaunchArgument(_ key: LaunchArgumentKey, value: String? = nil) {
        if let value = value {
            launchArguments.append("\(key.rawValue):\(value)")
        } else {
            launchArguments.append(key.rawValue)
        }
    }

    /// Check if launch argument is set
    func hasLaunchArgument(_ key: LaunchArgumentKey) -> Bool {
        return launchArguments.contains { $0.starts(with: key.rawValue) }
    }
}

// MARK: - Launch Environment Keys

extension XCUIApplication {

    enum LaunchEnvironmentKey: String {
        case testScenario = "TEST_SCENARIO"
        case testData = "TEST_DATA"
        case performanceTest = "PERFORMANCE_TEST"
    }

    /// Set launch environment variable
    func setLaunchEnvironment(_ key: LaunchEnvironmentKey, value: String) {
        launchEnvironment[key.rawValue] = value
    }

    /// Set multiple launch environment variables
    func setLaunchEnvironment(_ variables: [LaunchEnvironmentKey: String]) {
        for (key, value) in variables {
            launchEnvironment[key.rawValue] = value
        }
    }
}
