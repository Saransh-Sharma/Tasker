import Foundation
import LifeBoardDomain

/// How Home presents and logs one habit.
///
/// Home's habit cards used to treat every habit as a build check-in, so a
/// quit habit said "Hold" and "Done" like a task. The four kinds differ in
/// what the ring means, what a hold does, and what the status line says.
public enum HomeHabitKind: Equatable, Sendable {
    /// Hold to mark done.
    case buildCheckIn
    /// Tap for a step, hold to finish, scrub to set.
    case buildAmount
    /// A quit habit confirmed daily: hold if the day stayed clean.
    case quitCheckIn
    /// A quit habit that stays quiet while clean; the only thing recorded is a slip.
    case quitLapseOnly

    static func resolve(kind: HabitKind, trackingMode: HabitTrackingMode, hasAmountTarget: Bool) -> HomeHabitKind {
        switch (kind, trackingMode) {
        case (.negative, .lapseOnly): return .quitLapseOnly
        case (.negative, _): return .quitCheckIn
        case (.positive, _): return hasAmountTarget ? .buildAmount : .buildCheckIn
        }
    }

    var isQuit: Bool { self == .quitCheckIn || self == .quitLapseOnly }
}

/// Home habit card wording, in one place and tested.
///
/// The rules: plain verbs, the person's own units, clean days counted as
/// progress, and a slip named once, without "missed", "failed", "broke" or
/// "relapse" (`docs/habits/product-feature.md`: no shame loop).
enum HomeHabitCopy {
    struct Amount: Equatable {
        let value: Double
        let target: Double
        let unit: String
        let isTimed: Bool
    }

    static let sectionTitle = String(localized: "Habits today")
    static let allHabits = String(localized: "All habits")
    static let allHandled = String(localized: "All done today")

    /// The one line under a habit's name.
    static func status(
        kind: HomeHabitKind,
        isDoneToday: Bool,
        slippedToday: Bool,
        cleanDays: Int,
        amount: Amount?
    ) -> String {
        switch kind {
        case .buildCheckIn:
            return isDoneToday ? String(localized: "Done today") : String(localized: "Hold to mark done")
        case .buildAmount:
            guard let amount else { return isDoneToday ? String(localized: "Done today") : String(localized: "Hold to finish") }
            let reading = HabitRingGeometry.accessibilityValue(value: amount.value, target: amount.target, unit: amount.unit, isTimed: amount.isTimed)
            return amount.value >= amount.target ? String(localized: "\(reading) · done") : reading
        case .quitCheckIn:
            return isDoneToday ? String(localized: "Stayed clean today") : String(localized: "Hold if you stayed clean")
        case .quitLapseOnly:
            return slippedToday ? slipStatus : cleanCount(cleanDays)
        }
    }

    static let slipStatus = String(localized: "Slip logged today")

    /// Clean days are progress, counted plainly.
    static func cleanCount(_ days: Int) -> String {
        switch days {
        case ..<1: return String(localized: "Clean so far today")
        case 1: return String(localized: "Clean 1 day")
        default: return String(localized: "Clean \(days) days")
        }
    }

    static func streakAccessibility(_ days: Int) -> String {
        String(localized: "\(days)-day streak")
    }

    /// Whether the flame badge shows: a streak worth noticing, and never on a
    /// quit habit, whose clean count already is its streak.
    static func showsStreakBadge(kind: HomeHabitKind, streak: Int) -> Bool {
        kind.isQuit == false && streak >= 2
    }

    /// The ramp step a streak shades the habit's colour to, on the eight-step
    /// ramp the Board and Habit Detail use. It starts at step 3 — the two
    /// palest steps vanish as a thin arc on paper — and deepens one step per
    /// streak day until the deepest.
    static func shadeDepth(streak: Int) -> Int {
        min(max(streak + 2, 3), 8)
    }

    // MARK: Slip

    static let logSlip = String(localized: "Log a slip…")
    static let undoSlip = String(localized: "Undo slip")
    static let slipConfirmTitle = String(localized: "Log a slip for today?")
    static let slipConfirmMessage = String(localized: "Your clean count restarts tomorrow.")
    static let slipConfirmAction = String(localized: "Log slip")

    static func slipReceipt(_ title: String) -> String {
        String(localized: "Slip logged · \(title)")
    }

    static func stayedCleanReceipt(_ title: String) -> String {
        String(localized: "Stayed clean · \(title)")
    }

    /// What VoiceOver reads as the card's value.
    static func accessibilityValue(status: String, kind: HomeHabitKind, streak: Int) -> String {
        showsStreakBadge(kind: kind, streak: streak) ? String(localized: "\(status), \(streakAccessibility(streak))") : status
    }
}
