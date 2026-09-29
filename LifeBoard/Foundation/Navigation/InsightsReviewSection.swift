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
            SectionHeader("Your days", symbol: "calendar.badge.clock")
            Text(reviewSummary)
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            if let report = dayLoopEvidenceReport {
                // Only what a person did with their days. The proposal and
                // eligibility counts were bookkeeping, not something to act on.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 12)],
                    spacing: 12
                ) {
                    InsightMetric(count: report.closes, label: "Days closed")
                    InsightMetric(count: report.opensBeforeEleven, label: "Started before 11")
                    InsightMetric(count: report.daysWithBoth, label: "Started and closed")
                }
            }
            // The weekly review has its own entry card on this lens.
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
            return String(localized: "No days closed yet")
        }
        guard review.meetsFloor else {
            let remaining = max(1, InsightsInterpretationService.minimumDaysForPattern - review.recordedDays)
            return remaining == 1
                ? String(localized: "Needs 1 more day")
                : String(localized: "Needs \(remaining) more days")
        }

        var parts: [String] = []
        if review.daysClosed > 0 {
            parts.append(review.daysClosed == 1
                ? String(localized: "1 day closed")
                : String(localized: "\(review.daysClosed) days closed"))
        }
        if review.daysOpened > 0 {
            parts.append(review.daysOpened == 1
                ? String(localized: "1 day started")
                : String(localized: "\(review.daysOpened) days started"))
        }
        if review.reversals > 0 {
            // Named plainly: taking something back is a normal use of Undo, and
            // burying it would make the other numbers quietly wrong.
            parts.append(String(localized: "\(review.reversals) undone"))
        }
        guard parts.isEmpty == false else {
            return String(localized: "\(review.recordedDays) days recorded")
        }
        return parts.joined(separator: " · ")
    }}
