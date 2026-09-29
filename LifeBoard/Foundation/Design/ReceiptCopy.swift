import Foundation

/// Receipt wording, in one place.
///
/// `DESIGN.md`: a receipt "names what changed and exposes Undo when reversal
/// is supported", in copy that is personal, plain and specific. Messages used
/// to be inline strings at each call site, which is how a raw enum value
/// ("Goal completed" spelled from `rawValue`) and service wording ("Repair:
/// moveLaterToday") reached people. `ReceiptCopyTests` holds the budgets: a
/// message of at most six words, a detail of at most ten, no judgement and no
/// causal claims.
enum ReceiptCopy {
    // MARK: Track

    static func goalTransition(_ status: GoalStatus, title: String) -> String {
        let goal = "‘\(title)’"
        switch status {
        case .active: return String(localized: "Resumed \(goal)")
        case .paused: return String(localized: "Paused \(goal)")
        case .revised: return String(localized: "Revising \(goal)")
        case .completed: return String(localized: "Completed \(goal)")
        case .archived: return String(localized: "Archived \(goal)")
        }
    }

    // MARK: Journal

    static let moodSaved = String(localized: "Mood saved")

    static func journalTitle(cleared: Bool) -> String {
        cleared ? String(localized: "Title cleared") : String(localized: "Title saved")
    }

    // MARK: Insights

    static func experimentStarted(_ title: String) -> String {
        String(localized: "Trying ‘\(title)’ for a week")
    }

    static let experimentStartedDetail = String(localized: "Added as a habit")
    static let experimentFailed = String(localized: "Couldn’t start experiment")

    static func verdict(_ verdict: InsightExperiment.Verdict) -> String {
        switch verdict {
        case .helped: String(localized: "Noted: it helped")
        case .didNotHelp: String(localized: "Noted: not really")
        case .unsure: String(localized: "Noted: hard to say")
        }
    }
}
