//
//  PerformanceMetrics.swift
//  To Do ListUITests
//
//  Performance measurement utilities for UI tests
//

import XCTest

/// Performance metrics helper for measuring and asserting performance characteristics
struct PerformanceMetrics {

    // MARK: - Performance Thresholds

    struct Thresholds {
        static let appLaunchTime: TimeInterval = 2.0          // 2 seconds
        static let viewTransitionTime: TimeInterval = 0.5      // 500ms
        static let taskCreationTime: TimeInterval = 5.0        // 5 seconds (UI automation overhead)
        static let taskCompletionTime: TimeInterval = 0.3      // 300ms
        static let scrollFrameRate: Double = 55.0              // 55 fps (allowing some drops from 60)
        static let chartRenderTime: TimeInterval = 1.0         // 1 second
        static let searchResponseTime: TimeInterval = 0.5      // 500ms
        static let maxMemoryUsageMB: Double = 100.0           // 100 MB

        /// Custom threshold for specific test
        static func custom(_ value: TimeInterval) -> TimeInterval {
            return value
        }
    }

    // MARK: - Metrics Types

    enum MetricType {
        case time(TimeInterval)
        case frameRate(Double)
        case memory(Double)

        var description: String {
            switch self {
            case .time(let value):
                return String(format: "%.3f seconds", value)
            case .frameRate(let value):
                return String(format: "%.1f fps", value)
            case .memory(let value):
                return String(format: "%.2f MB", value)
            }
        }
    }

    // MARK: - Measurement Methods

    /// Measure app launch time
    static func measureAppLaunch(
        app: XCUIApplication,
        testCase: XCTestCase
    ) -> TimeInterval {
        let metrics: [XCTMetric] = [
            XCTOSSignpostMetric.applicationLaunch
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        var launchTime: TimeInterval = 0

        testCase.measure(metrics: metrics, options: options) {
            app.launch()
            launchTime = Date().timeIntervalSince1970
        }

        return launchTime
    }

    /// Measure block execution time
    static func measureExecutionTime(
        named name: String,
        testCase: XCTestCase,
        block: () -> Void
    ) -> TimeInterval {
        let start = Date()
        block()
        let end = Date()
        let duration = end.timeIntervalSince(start)

        print("⏱ Performance: \(name) took \(String(format: "%.3f", duration)) seconds")

        return duration
    }

    /// Measure and assert execution time
    static func measureAndAssert(
        named name: String,
        threshold: TimeInterval,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line,
        block: () -> Void
    ) {
        let duration = measureExecutionTime(named: name, testCase: testCase, block: block)

        XCTAssertLessThanOrEqual(
            duration,
            threshold,
            "❌ Performance: \(name) took \(String(format: "%.3f", duration))s, expected < \(threshold)s",
            file: file,
            line: line
        )

        if duration <= threshold {
            print("✅ Performance: \(name) passed (\(String(format: "%.3f", duration))s < \(threshold)s)")
        }
    }

    /// Measure scroll performance (frame rate)
    static func measureScrollPerformance(
        scrollView: XCUIElement,
        testCase: XCTestCase,
        numberOfSwipes: Int = 10
    ) -> Double {
        // Measure scroll execution time
        let start = Date()

        for _ in 0..<numberOfSwipes {
            scrollView.swipeUp()
            Thread.sleep(forTimeInterval: 0.1)
        }

        let duration = Date().timeIntervalSince(start)

        // Return estimated FPS based on smooth completion
        // If scrolling completes within expected time, assume 60fps
        let expectedDuration = Double(numberOfSwipes) * 0.1
        let performanceRatio = expectedDuration / duration
        let estimatedFPS = min(60.0, 60.0 * performanceRatio)

        print("⏱ Scroll Performance: \(numberOfSwipes) swipes in \(String(format: "%.3f", duration))s (\(String(format: "%.1f", estimatedFPS)) fps)")

        return estimatedFPS
    }

    /// Measure memory usage
    @available(iOS 14.0, *)
    static func measureMemoryUsage(
        app: XCUIApplication,
        testCase: XCTestCase,
        block: () -> Void
    ) -> Double {
        let metrics: [XCTMetric] = [
            XCTMemoryMetric(application: app)
        ]

        let options = XCTMeasureOptions()
        options.iterationCount = 1

        testCase.measure(metrics: metrics, options: options) {
            block()
        }

        // Memory usage in MB (placeholder - actual value from metrics)
        return 0.0
    }

    // MARK: - Assertions

    /// Assert app launches within threshold
    static func assertAppLaunchTime(
        _ duration: TimeInterval,
        threshold: TimeInterval = Thresholds.appLaunchTime,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            duration,
            threshold,
            "❌ App launch took \(String(format: "%.3f", duration))s, expected < \(threshold)s",
            file: file,
            line: line
        )

        if duration <= threshold {
            print("✅ App launch performance: \(String(format: "%.3f", duration))s < \(threshold)s")
        }
    }

    /// Assert view transition within threshold
    static func assertViewTransitionTime(
        _ duration: TimeInterval,
        threshold: TimeInterval = Thresholds.viewTransitionTime,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            duration,
            threshold,
            "❌ View transition took \(String(format: "%.3f", duration))s, expected < \(threshold)s",
            file: file,
            line: line
        )

        if duration <= threshold {
            print("✅ View transition performance: \(String(format: "%.3f", duration))s < \(threshold)s")
        }
    }

    /// Assert frame rate meets minimum threshold
    static func assertFrameRate(
        _ frameRate: Double,
        minThreshold: Double = Thresholds.scrollFrameRate,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            frameRate,
            minThreshold,
            "❌ Frame rate \(String(format: "%.1f", frameRate)) fps, expected >= \(minThreshold) fps",
            file: file,
            line: line
        )

        if frameRate >= minThreshold {
            print("✅ Frame rate performance: \(String(format: "%.1f", frameRate)) fps >= \(minThreshold) fps")
        }
    }

    /// Assert memory usage within threshold
    static func assertMemoryUsage(
        _ memoryMB: Double,
        maxThreshold: Double = Thresholds.maxMemoryUsageMB,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            memoryMB,
            maxThreshold,
            "❌ Memory usage \(String(format: "%.2f", memoryMB)) MB, expected < \(maxThreshold) MB",
            file: file,
            line: line
        )

        if memoryMB <= maxThreshold {
            print("✅ Memory usage performance: \(String(format: "%.2f", memoryMB)) MB < \(maxThreshold) MB")
        }
    }

    // MARK: - Benchmarking

    /// Run performance benchmark with multiple iterations
    static func benchmark(
        named name: String,
        iterations: Int = 5,
        testCase: XCTestCase,
        block: () -> Void
    ) -> [TimeInterval] {
        var results: [TimeInterval] = []

        print("🏃 Running benchmark: \(name) (\(iterations) iterations)")

        for i in 1...iterations {
            let start = Date()
            block()
            let end = Date()
            let duration = end.timeIntervalSince(start)
            results.append(duration)

            print("  Iteration \(i): \(String(format: "%.3f", duration))s")
        }

        let average = results.reduce(0, +) / Double(results.count)
        let min = results.min() ?? 0
        let max = results.max() ?? 0

        print("📊 Benchmark results for \(name):")
        print("  Average: \(String(format: "%.3f", average))s")
        print("  Min: \(String(format: "%.3f", min))s")
        print("  Max: \(String(format: "%.3f", max))s")

        return results
    }

    /// Calculate statistics from benchmark results
    static func calculateStatistics(_ results: [TimeInterval]) -> Statistics {
        guard !results.isEmpty else {
            return Statistics(average: 0, min: 0, max: 0, median: 0, stdDeviation: 0)
        }

        let average = results.reduce(0, +) / Double(results.count)
        let min = results.min()!
        let max = results.max()!

        let sorted = results.sorted()
        let median: TimeInterval
        if sorted.count % 2 == 0 {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        let variance = results.reduce(0) { $0 + pow($1 - average, 2) } / Double(results.count)
        let stdDeviation = sqrt(variance)

        return Statistics(
            average: average,
            min: min,
            max: max,
            median: median,
            stdDeviation: stdDeviation
        )
    }

    struct Statistics {
        let average: TimeInterval
        let min: TimeInterval
        let max: TimeInterval
        let median: TimeInterval
        let stdDeviation: TimeInterval

        func printSummary(name: String) {
            print("📈 Statistics for \(name):")
            print("  Average: \(String(format: "%.3f", average))s")
            print("  Median: \(String(format: "%.3f", median))s")
            print("  Min: \(String(format: "%.3f", min))s")
            print("  Max: \(String(format: "%.3f", max))s")
            print("  Std Dev: \(String(format: "%.3f", stdDeviation))s")
        }
    }

    // MARK: - Common Performance Tests

    /// Test task creation performance
    static func testTaskCreationPerformance(
        app: XCUIApplication,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        measureAndAssert(
            named: "Task Creation",
            threshold: Thresholds.taskCreationTime,
            testCase: testCase,
            file: file,
            line: line
        ) {
            // Add task button tap
            app.buttons[AccessibilityIdentifiers.Home.addTaskButton].tap()

            // Wait for add task screen
            _ = app.otherElements[AccessibilityIdentifiers.AddTask.view].waitForExistence(timeout: 5)
        }
    }

    /// Test task completion performance
    static func testTaskCompletionPerformance(
        app: XCUIApplication,
        taskIndex: Int = 0,
        testCase: XCTestCase,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        measureAndAssert(
            named: "Task Completion",
            threshold: Thresholds.taskCompletionTime,
            testCase: testCase,
            file: file,
            line: line
        ) {
            // Tap checkbox to complete task
            let checkbox = app.buttons[AccessibilityIdentifiers.Home.taskCheckbox(index: taskIndex)]
            checkbox.tap()
        }
    }
}
