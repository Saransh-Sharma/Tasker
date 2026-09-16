import SwiftUI
import UIKit

/// The review lens. Reports what the day loop did and stops — no score, no
/// completion percentage.
struct InsightsReviewSection: View {
    let events: [NormalizedLifeEvent]
    let dayLoopEvidenceReport: DayLoopEvidenceReport?
    let router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Reflection, not a report card", symbol: "calendar.badge.clock")
            Text(reviewSummary)
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            if let report = dayLoopEvidenceReport {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 12)],
                    spacing: 12
                ) {
                    InsightMetric(count: report.eligibleDays, label: "Eligible days")
                    InsightMetric(count: report.closes, label: "Days closed")
                    InsightMetric(count: report.opensBeforeEleven, label: "Opened before 11")
                    InsightMetric(count: report.daysWithBoth, label: "Opened and closed")
                    InsightMetric(count: report.reversals, label: "Taken back")
                    InsightMetric(count: report.knownProposalSignals, label: "Known proposals")
                    InsightMetric(
                        label: "Unedited proposal share",
                        // No sidecar means no record — not the word "Unknown"
                        // rendered where a number goes.
                        reading: report.uneditedShare.map {
                            .recorded(value: $0.formatted(.percent.precision(.fractionLength(0))), unit: nil)
                        } ?? .noRecord
                    )
                }
                Text("Proposal evidence is local and non-authoritative. Missing sidecars stay unknown; undone receipts stop counting.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            Button("Open weekly review") {
                router.push(.weeklyReview, in: .insights)
            }
            .buttonStyle(.lifeBoardChip)
            .frame(minHeight: 44)
        }
        .padding(18)
        .lifeBoardClaySurface(.raised)
    }

    private var loopReview: DayLoopReview {
        DayLoopLedger.review(events: events)
    }

    /// What the loop did, in the loop's own vocabulary.
    ///
    /// Previously this counted records and domains — the same sentence whether
    /// you had closed fourteen days or dragged fourteen blocks around. The
    /// receipts now name themselves, so the lens can report the thing the
    /// person actually did.
    ///
    /// Reports and stops. No percentage, no score, no "you only closed 4 of
    /// 14": days that were not closed are days that were lived, and the review
    /// lens is not a place to be told otherwise.
    private var reviewSummary: String {
        let review = loopReview
        guard review.hasNoHistory == false else {
            // Nothing recorded is not zero days closed. It is no history.
            return "No days have been opened or closed yet. When you start closing days, what you did with them shows up here."
        }
        guard review.meetsFloor else {
            let days = review.recordedDays
            return "\(days) \(days == 1 ? "day" : "days") recorded so far — not yet enough to read as a pattern."
        }

        var parts: [String] = []
        if review.daysClosed > 0 {
            parts.append("closed \(review.daysClosed) \(review.daysClosed == 1 ? "day" : "days")")
        }
        if review.daysOpened > 0 {
            parts.append("began \(review.daysOpened) deliberately")
        }
        let opening = parts.isEmpty
            ? "You have \(review.recordedDays) days of loop history"
            : "You've \(parts.joined(separator: " and "))"

        var sentence = "\(opening)."
        if review.daysWithBoth > 0 {
            sentence += " \(review.daysWithBoth) had both a beginning and an end."
        }
        if review.reversals > 0 {
            // Named plainly: taking something back is a normal use of Undo, and
            // burying it would make the other numbers quietly wrong.
            sentence += " \(review.reversals) \(review.reversals == 1 ? "was" : "were") taken back."
        }
        return sentence + " Choose one win, one friction point, and one adjustment."
    }}
