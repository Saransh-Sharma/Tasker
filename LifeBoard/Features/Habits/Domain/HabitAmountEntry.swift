import Foundation
import LifeBoardDomain

/// The pure part of "Enter amount": what the drum shows, what the store gets.
///
/// Timed targets are stored in seconds and edited in minutes; everything else
/// is edited in its own unit. The sheet commits one `.set`, so the amount use
/// case's own crossing logic decides whether this completes the habit, and it
/// fires once whichever direction the value moved.
enum HabitAmountEntry {
    struct Drum: Equatable {
        let label: String
        let unit: String
        let range: ClosedRange<Double>
        let step: Double
        let coarseStep: Double?
        let fractionDigits: Int
    }

    /// The drum for a target and the amount recorded so far.
    static func drum(for target: HabitTarget, current: Double) -> Drum? {
        guard let goal = HabitAmountRule.target(for: target) else { return nil }
        switch target {
        case .timed:
            let goalMinutes = (goal / 60).rounded()
            let upper = max(goalMinutes * 2, (current / 60).rounded(.up), 5)
            return Drum(label: String(localized: "Minutes"), unit: "min", range: 0...upper, step: 1, coarseStep: 5, fractionDigits: 0)
        case let .quantitative(_, unit):
            let step = HabitAmountRule.step(for: target)
            let upper = max(goal * 2, current, step)
            return Drum(label: String(localized: "Amount"), unit: unit, range: 0...upper, step: step, coarseStep: step * 5, fractionDigits: step < 1 ? 1 : 0)
        case .quota:
            let upper = max(goal * 2, current, 1)
            return Drum(label: String(localized: "Times"), unit: "times", range: 0...upper, step: 1, coarseStep: 5, fractionDigits: 0)
        case .binary, .avoidance:
            return nil
        }
    }

    /// Seconds → minutes for timed targets; identity otherwise.
    static func displayValue(_ stored: Double, target: HabitTarget) -> Double {
        if case .timed = target { return (stored / 60).rounded() }
        return stored
    }

    /// Minutes → seconds for timed targets; identity otherwise.
    static func storedValue(_ display: Double, target: HabitTarget) -> Double {
        if case .timed = target { return display * 60 }
        return display
    }

    /// The change to commit, or `nil` when the value is what is already
    /// recorded (so a sheet closed without moving the drum writes nothing).
    static func change(from current: Double, toDisplay display: Double, target: HabitTarget) -> HabitAmountChange? {
        let next = max(0, storedValue(display, target: target))
        guard abs(next - current) > 0.000_1 else { return nil }
        return .set(next)
    }

    /// "Water set to 5 of 8 glasses" / "Read set to 12 of 20 minutes".
    static func receipt(title: String, value: Double, target: HabitTarget) -> String {
        guard let goal = HabitAmountRule.target(for: target) else { return String(localized: "\(title) updated") }
        let isTimed: Bool = { if case .timed = target { return true }; return false }()
        let unit: String = { if case let .quantitative(_, unit) = target { return unit }; return "" }()
        let reading = HabitRingGeometry.accessibilityValue(value: value, target: goal, unit: unit, isTimed: isTimed)
        return String(localized: "\(title) set to \(reading)")
    }
}
