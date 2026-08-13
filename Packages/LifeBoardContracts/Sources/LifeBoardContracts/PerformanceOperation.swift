import Foundation
import OSLog

public struct PerformanceInterval: Sendable {
    fileprivate let name: StaticString
    fileprivate let signpostID: OSSignpostID?
    fileprivate let isEnabled: Bool
}

public enum PerformanceTrace {
    private static let arguments = Set(ProcessInfo.processInfo.arguments)
    private static let environment = ProcessInfo.processInfo.environment
    private static let log = OSLog(subsystem: "com.saransh1337.LifeBoard", category: "performance")
    private static let pointsOfInterest = OSLog(
        subsystem: "com.saransh1337.LifeBoard",
        category: .pointsOfInterest
    )
    private static let tracingEnabled = environment["PERFORMANCE_TEST"] == "1"
        || arguments.contains("-LIFEBOARD_ENABLE_PERF_TRACE")
        || arguments.contains("-LIFEBOARD_VERBOSE_PERF_TRACE")
    private static let pointsOfInterestEnabled = tracingEnabled
        || environment["OS_ACTIVITY_TOOLS_PRIVACY"] == "YES"
        || environment["OS_LOG_DT_HOOK_MODE"] != nil

    public static func begin(_ name: StaticString) -> PerformanceInterval {
        guard tracingEnabled || pointsOfInterestEnabled else {
            return PerformanceInterval(name: name, signpostID: nil, isEnabled: false)
        }
        let identifier = OSSignpostID(log: log)
        if tracingEnabled { os_signpost(.begin, log: log, name: name, signpostID: identifier) }
        if pointsOfInterestEnabled {
            os_signpost(.begin, log: pointsOfInterest, name: name, signpostID: identifier)
        }
        return PerformanceInterval(name: name, signpostID: identifier, isEnabled: true)
    }

    public static func end(_ interval: PerformanceInterval) {
        guard interval.isEnabled, let identifier = interval.signpostID else { return }
        if tracingEnabled { os_signpost(.end, log: log, name: interval.name, signpostID: identifier) }
        if pointsOfInterestEnabled {
            os_signpost(.end, log: pointsOfInterest, name: interval.name, signpostID: identifier)
        }
    }
}

public enum PerformanceOperation: CaseIterable, Sendable {
    case homeCardSnapshot
    case homeContextEvaluation
    case composerResolution
    case journalDerivedRebuild
    case persistentStoreMigration
    case signatureShaderWarmup
    case systemSurfaceRefresh

    private var signpostName: StaticString {
        switch self {
        case .homeCardSnapshot: "LifeOS.HomeCardSnapshot"
        case .homeContextEvaluation: "LifeOS.HomeContextEvaluation"
        case .composerResolution: "LifeOS.ComposerResolution"
        case .journalDerivedRebuild: "LifeOS.JournalDerivedRebuild"
        case .persistentStoreMigration: "LifeOS.PersistentStoreMigration"
        case .signatureShaderWarmup: "LifeOS.SignatureShaderWarmup"
        case .systemSurfaceRefresh: "LifeOS.SystemSurfaceRefresh"
        }
    }

    public func begin() -> PerformanceInterval { PerformanceTrace.begin(signpostName) }
    public func end(_ interval: PerformanceInterval) { PerformanceTrace.end(interval) }
}
