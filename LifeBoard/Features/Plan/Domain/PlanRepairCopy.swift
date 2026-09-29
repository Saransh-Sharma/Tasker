import Foundation

/// The words a repair uses, from the deck's button to the receipt.
///
/// The scenario diff used to title itself `"Repair: \(action.rawValue)"` and
/// carry the service explanation as its "before", so Home's receipt read
/// "Repair: moveLaterToday, moved from This planned block has passed…". The
/// deck already had readable names; the diff and the receipt now share them.
enum PlanRepairCopy {
    /// The deck's button title for an action.
    static func title(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: String(localized: "Resume")
        // The shared "where does this go" words (DESIGN.md contract 4).
        // "Another day" always meant tomorrow, so it now says so.
        case .moveLaterToday: DecisionDestination.laterToday.title
        case .moveToAnotherDay: DecisionDestination.tomorrow.title
        case .split: String(localized: "Split")
        // Back to the unscheduled list, which is what the receipt says.
        case .defer: String(localized: "Unschedule")
        // Not "Leave unchanged": the exit from a repair deck should sound like
        // a decision someone made, not like declining to fix something.
        // Not "Keep *today* as is" — Plan can show this deck for a day the
        // person has scrolled back to, and it would be wrong there.
        case .leaveUnchanged: String(localized: "Keep as is")
        case .askEva: String(localized: "Ask Eva")
        }
    }

    /// The applied receipt, past tense, naming the work.
    static func receipt(_ action: PlanRepairAction, workTitle: String?) -> String {
        let work = workTitle.map { "‘\($0)’" }
        switch action {
        case .resume:
            return work.map { String(localized: "Started focus on \($0)") } ?? String(localized: "Focus started")
        case .moveLaterToday:
            return work.map { String(localized: "Moved \($0) to later today") } ?? String(localized: "Moved to later today")
        case .moveToAnotherDay:
            return work.map { String(localized: "Moved \($0) to tomorrow") } ?? String(localized: "Moved to tomorrow")
        case .split:
            return work.map { String(localized: "Split \($0) in two") } ?? String(localized: "Split in two")
        case .defer:
            return work.map { String(localized: "Unscheduled \($0)") } ?? String(localized: "Unscheduled")
        case .leaveUnchanged, .askEva:
            return String(localized: "Plan unchanged")
        }
    }

    /// The receipt detail: where the work used to sit, when it had a time.
    static func previousWindowDetail(_ window: String?) -> String? {
        window.map { String(localized: "Was \($0)") }
    }
}
