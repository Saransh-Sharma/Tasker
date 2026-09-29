import Foundation

@MainActor
enum RootNavigationPerformanceTrace {
    private static var timeout: Task<Void, Never>?
    private(set) static var failedCount = 0
    private(set) static var supersededCount = 0
    private static var interval: PerformanceInterval?
    private static var destination: Destination?
    private static var generation: UInt64 = 0
    private static var startedAt: TimeInterval = 0
    private(set) static var completedCount = 0
    private(set) static var lastDurationMilliseconds = 0

    static func begin(destination: Destination, coldMount: Bool, generation: UInt64 = 0) {
        cancel()
        self.destination = destination
        self.generation = generation
        startedAt = ProcessInfo.processInfo.systemUptime
        interval = PerformanceTrace.begin("RootSwitchAttempt")
        timeout = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            markFailed(destination: destination, generation: generation)
        }
        PerformanceTrace.event("RootSwitchRequested", value:
            (Destination.allCases.firstIndex(of: destination) ?? 0) * 10 + (coldMount ? 1 : 0))
    }

    static func markInteractive(destination: Destination, generation: UInt64 = 0) {
        guard self.destination == destination, self.generation == generation,
              let interval else { return }
        timeout?.cancel()
        timeout = nil
        PerformanceTrace.end(interval)
        lastDurationMilliseconds = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        completedCount += 1
        PerformanceTrace.event("RootSwitchCompletedMilliseconds", value: lastDurationMilliseconds)
        self.interval = nil
        self.destination = nil
    }

    static func markFailed(destination: Destination, generation: UInt64) {
        guard self.destination == destination, self.generation == generation, let interval else { return }
        timeout?.cancel()
        timeout = nil
        failedCount += 1
        PerformanceTrace.event("RootSwitchFailed")
        PerformanceTrace.end(interval)
        self.interval = nil
        self.destination = nil
    }

    static func cancel() {
        guard let interval else { return }
        timeout?.cancel()
        timeout = nil
        supersededCount += 1
        PerformanceTrace.event("RootSwitchSuperseded")
        PerformanceTrace.end(interval)
        self.interval = nil
        destination = nil
    }
}

/// Measures the complete user-visible Eva navigation, beginning before the
/// selected root changes and ending only when Eva has usable content.
///
/// This sits above `ChatOpenToFirstTranscriptRender`: the chat-local interval
/// begins after SwiftUI has already constructed the activation hierarchy and
/// therefore cannot detect metadata stalls during the tab switch itself.
@MainActor
enum EvaNavigationPerformanceTrace {
    private static var openInterval: PerformanceInterval?

    static func begin() {
        cancel(reason: "superseded")
        openInterval = PerformanceTrace.begin("EvaTabOpenToInteractive")
    }

    static func markInteractive() {
        guard let openInterval else { return }
        PerformanceTrace.end(openInterval)
        self.openInterval = nil
        PerformanceTrace.event("EvaTabInteractive")
    }

    static func cancel(reason: StaticString = "navigation_cancelled") {
        guard let openInterval else { return }
        PerformanceTrace.end(openInterval)
        self.openInterval = nil
        PerformanceTrace.event(reason)
    }
}
