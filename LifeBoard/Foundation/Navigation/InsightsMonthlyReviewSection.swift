import SwiftUI
import LifeBoardDomain
import LifeBoardUI

/// The weekly review's entry on the Review lens.
///
/// This used to embed the whole `WeeklyReviewView` here: a navigation stack
/// and a vertical scroll view nested inside the Insights scroll view, which
/// collapsed to a clipped card with a Close button that did nothing. The
/// review is a sitting of its own, so the lens offers one clear way into it.
struct InsightsInlineWeeklyReview: View {
    let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("This week", symbol: "calendar")
            Button("Review week") { router.push(.weeklyReview, in: .insights) }
                .buttonStyle(.lifeBoardChip)
                .frame(minHeight: 44)
                .accessibilityIdentifier("insights.review.weekly.open")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.review.weekly")
    }
}

/// The month read back: boundaries kept, the notes written there, the usual
/// ranges that moved, and the experiments waiting for "Did it help?".
struct InsightsMonthlyReviewSection: View {
    let summary: MonthlyReviewSummary?
    /// `false` when the answer could not be saved; the row stays and says so.
    let recordVerdict: (InsightExperiment, InsightExperiment.Verdict) async -> Bool

    @State private var answering: UUID?
    @State private var failed: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("This month", symbol: "calendar.badge.clock")
            if let summary {
                if summary.daysClosed == 0, summary.weeklyReviews == 0 {
                    // A month with nothing closed yet reads as a fresh start,
                    // not as "0 Days closed" in large type.
                    Text("No days closed in \(Date.now.formatted(.dateTime.month(.wide))) yet")
                        .lifeboardFont(.support)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("insights.review.monthly.empty")
                } else {
                    HStack(spacing: 12) {
                        InsightMetric(count: summary.daysClosed, label: "Days closed")
                        InsightMetric(count: summary.weeklyReviews, label: "Weekly reviews")
                        if let energy = summary.averageCloseEnergy {
                            InsightMetric(label: "Energy at close", reading: .recorded(value: energy.formatted(.number.precision(.fractionLength(1))), unit: "of 5"))
                        }
                    }
                }
                if summary.shifts.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.shifts) { shift in
                            Label(MonthlyReviewSummary.sentence(for: shift), systemImage: shift.metric.systemImage)
                                .lifeboardFont(.support)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("insights.review.monthly.shifts")
                }
                if summary.closeNotes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From your day closes")
                            .lifeboardFont(.meta)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                        ForEach(summary.closeNotes) { note in
                            Text("“\(note.noteText)”")
                                .lifeboardFont(.support)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                ForEach(summary.dueExperiments) { experiment in
                    verdictRow(for: experiment)
                }
            } else {
                Text("Loading…")
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.review.monthly")
    }

    private func verdictRow(for experiment: InsightExperiment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Did it help?")
                .lifeboardFont(.bodyStrong)
            Text(experiment.hypothesis)
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach([InsightExperiment.Verdict.helped, .didNotHelp, .unsure], id: \.rawValue) { verdict in
                    Button(title(for: verdict)) {
                        guard answering != experiment.id else { return }
                        answering = experiment.id
                        failed = nil
                        Task {
                            let saved = await recordVerdict(experiment, verdict)
                            answering = nil
                            if saved == false { failed = experiment.id }
                        }
                    }
                    .buttonStyle(.lifeBoardChip)
                    .frame(minHeight: 44)
                    // Only the row being answered waits; the others stay live.
                    .disabled(answering == experiment.id)
                    .accessibilityIdentifier("insights.review.experiment.\(verdict.rawValue)")
                }
            }
            if failed == experiment.id {
                Text("Couldn’t save answer. Try again.")
                    .lifeboardFont(.meta)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .accessibilityIdentifier("insights.review.experiment.failed")
            }
        }
        .padding(.vertical, 6)
    }

    private func title(for verdict: InsightExperiment.Verdict) -> String {
        switch verdict {
        case .helped: String(localized: "It helped")
        case .didNotHelp: String(localized: "Not really")
        case .unsure: String(localized: "Not sure")
        }
    }
}
