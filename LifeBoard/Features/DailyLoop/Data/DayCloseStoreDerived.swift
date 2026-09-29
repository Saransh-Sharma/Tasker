import Foundation

extension DayCloseStore {

    // MARK: - Derived

    /// The card currently in hand. Undecided only — a decided card leaves the
    /// deck even though its mutation has not been written yet.
    public var currentCard: PlanningTaskSummary? {
        unfinished.first { decisions[$0.id] == nil }
    }

    /// Every card still awaiting a decision, front card first.
    ///
    /// The deck renders only the front card, but it needs the whole queue:
    /// `lifeBoardDeckDepth` draws its backing cards from `count`. Handing it a
    /// single-element array made an eight-task evening look like a one-task one,
    /// which is the difference between "nearly done" and "this will take a while"
    /// — exactly the thing someone deciding whether to start needs to see.
    public var remainingCards: [PlanningTaskSummary] {
        unfinished.filter { decisions[$0.id] == nil }
    }

    public var remainingCount: Int {
        remainingCards.count
    }

    /// How far through the reconciliation the evening is, or `nil` when there
    /// was never anything to decide. Absent is not zero.
    public var reconciliationProgress: Double? {
        let total = decidedCount + remainingCount
        guard total > 0 else { return nil }
        return Double(decidedCount) / Double(total)
    }

    public var decidedCount: Int { decisions.count }

    /// Candidates for tomorrow's first thing: anything not filed away.
    ///
    /// Anchoring something just released would contradict the decision made
    /// seconds earlier, so those drop out here as well as in the builder.
    public var anchorCandidates: [PlanningTaskSummary] {
        unfinished.filter { task in
            switch decisions[task.id] {
            case .someday, .doneAnyway, .release: false
            case .tomorrow, .none: true
            }
        }
    }

    /// A one-line-per-direction account of what is about to happen.
    /// The same counts as `summaryLines`, but keeping the direction alongside
    /// the text. The view needs it to give each outcome its own feedback: only
    /// released rows should erode, and only rows that were already done should
    /// get a completion burst. Rendering plain strings meant the erosion ran
    /// over "moved to tomorrow" too, which reads as losing something that was
    /// in fact carried forward.
    public var summary: [DayCloseSummaryLine] {
        DayCloseDirection.allCases.compactMap { direction in
            let count = decisions.values.count { $0 == direction }
            guard count > 0 else { return nil }
            return DayCloseSummaryLine(
                direction: direction,
                text: "\(count) \(direction.summaryVerb)"
            )
        }
    }

    public var summaryLines: [String] { summary.map(\.text) }
}
