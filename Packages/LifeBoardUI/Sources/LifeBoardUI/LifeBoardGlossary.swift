import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// Where an unfinished thing goes — the one vocabulary for that decision.
///
/// Day Close, Rescue, Plan Repair, the weekly reset, and the weekly workspace
/// each used to word this differently ("Carry", "Release", "Defer", "Another
/// day", "Drop"). A surface may offer a subset, but a case always carries the
/// same title and symbol wherever it appears (DESIGN.md launch contract 4).
public enum DecisionDestination: String, CaseIterable, Identifiable, Sendable {
    case today
    case laterToday
    case tomorrow
    case pickDay
    case someday
    case letGo
    case alreadyDone

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .laterToday: String(localized: "Later today")
        case .tomorrow: String(localized: "Tomorrow")
        case .pickDay: String(localized: "Pick a day\u{2026}")
        case .someday: String(localized: "Someday")
        case .letGo: String(localized: "Let it go")
        case .alreadyDone: String(localized: "Already done")
        }
    }

    public var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .laterToday: "clock.arrow.circlepath"
        case .tomorrow: "sunrise"
        case .pickDay: "calendar"
        case .someday: "tray"
        case .letGo: "wind"
        case .alreadyDone: "checkmark.circle"
        }
    }
}

/// One way to write a duration.
///
/// Add Task wrote "15m", the Inbox "15 min", block composers "45 minutes", and
/// task detail "45 min". This is the single formatter: localized, abbreviated
/// ("45 min", "1 hr, 30 min"), and never "0 min" for a positive span.
public enum LifeBoardDuration {
    public static func text(minutes: Int) -> String {
        let clamped = max(minutes, 0)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = clamped >= 60 ? [.hour, .minute] : [.minute]
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(clamped * 60))
            ?? String(localized: "\(clamped) min")
    }

    public static func text(seconds: TimeInterval) -> String {
        text(minutes: Int((seconds / 60).rounded()))
    }
}

/// The device the person is holding, for copy such as "stored on this iPhone".
///
/// Eleven strings hardcoded "iPhone" and read wrongly on iPad and the Mac.
public enum DeviceNoun {
    @MainActor
    public static var current: String {
        #if targetEnvironment(macCatalyst)
        return String(localized: "Mac")
        #elseif canImport(UIKit) && !os(watchOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return String(localized: "iPad")
        case .mac: return String(localized: "Mac")
        default: return String(localized: "iPhone")
        }
        #else
        return String(localized: "Apple Watch")
        #endif
    }

    /// "this iPhone", "this iPad", "this Mac".
    @MainActor
    public static var this: String {
        String(localized: "this \(current)")
    }
}
