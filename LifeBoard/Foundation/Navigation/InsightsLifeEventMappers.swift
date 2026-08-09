import SwiftUI
import UIKit

/// The four life-event mappers Insights uses to fold planning receipts,
/// focus sessions and focus commands into the normalized evidence stream.
///
/// Lifted out of `InsightsDestination` because Eva's destination
/// calls them too, and a view type is a poor home for a shared mapper.
@MainActor
enum InsightsLifeEventMappers {
    static func planningEvent(_ record: PlanningReceiptRecord) -> NormalizedLifeEvent? {
        guard record.state != .prepared else { return nil }
        let occurredAt = record.undoneAt ?? record.appliedAt ?? record.receipt.createdAt
        let reversed = record.state == .undone
        return NormalizedLifeEventProjector().event(
            sourceID: record.receipt.id,
            domain: "plan",
            // `source` used to be dropped here, so a day-close arrived at
            // Insights as a generic `mutation_applied` — indistinguishable from
            // dragging a block. Carrying it is what lets the review lens say
            // anything about the loop at all.
            kind: planningEventKind(source: record.receipt.source, reversed: reversed),
            occurredAt: occurredAt,
            provenance: "Persisted LifeBoard planning receipt",
            evidenceDisplay: record.receipt.summary,
            receipt: .init(receiptID: record.receipt.id, summary: record.receipt.summary),
            reversal: reversed
                ? .reversed(receiptID: record.receipt.id)
                : .reversible(receiptID: record.receipt.id)
        )
    }

    /// Names the loop's own receipts so Insights can count days closed and
    /// opened rather than lumping them in with every plan edit.
    static func planningEventKind(source: String, reversed: Bool) -> String {
        if source.hasPrefix(DayLoopLedger.closePrefix) {
            return reversed ? DayLoopLedger.EventKind.closeReversed : DayLoopLedger.EventKind.closed
        }
        if source.hasPrefix(DayLoopLedger.openPrefix) {
            return reversed ? DayLoopLedger.EventKind.openReversed : DayLoopLedger.EventKind.opened
        }
        return reversed ? "mutation_reversed" : "mutation_applied"
    }

    static func focusEvents(
        _ session: FocusSessionV2,
        includesLegacyStateFallback: Bool
    ) -> [NormalizedLifeEvent] {
        let projector = NormalizedLifeEventProjector()
        var values = [projector.event(
            sourceID: session.id,
            domain: "focus",
            kind: "started",
            occurredAt: session.startedAt,
            numericValue: session.targetDuration,
            provenance: "Persisted LifeBoard Focus session",
            evidenceDisplay: "Focus session"
        )]
        if includesLegacyStateFallback, let endedAt = session.endedAt {
            values.append(projector.event(
                sourceID: session.id,
                domain: "focus",
                kind: "ended_\(session.outcome?.rawValue ?? "stopped")",
                occurredAt: endedAt,
                numericValue: session.focusedDuration(at: endedAt),
                provenance: "Persisted LifeBoard Focus completion",
                evidenceDisplay: "Focus completion",
                receipt: .init(receiptID: session.id, summary: "Focus \(session.outcome?.rawValue ?? "ended")")
            ))
        } else if includesLegacyStateFallback, session.state == .paused, let pausedAt = session.pausedAt {
            values.append(projector.event(
                sourceID: session.id,
                domain: "focus",
                kind: "paused",
                occurredAt: pausedAt,
                numericValue: session.focusedDuration(at: pausedAt),
                provenance: "Persisted LifeBoard Focus state",
                evidenceDisplay: "Paused Focus session"
            ))
        }
        return values
    }

    static func focusCommandEvent(_ receipt: FocusCommandReceipt) -> NormalizedLifeEvent {
        let commandValues: (kind: String, summary: String) = switch receipt.kind {
        case .pause:
            ("paused", "Paused Focus session")
        case .resume:
            ("resumed", "Resumed Focus session")
        case .end(let outcome):
            ("ended_\(outcome.rawValue)", "Focus \(outcome.rawValue)")
        }
        let values: (kind: String, summary: String)
        if receipt.wasApplied {
            values = commandValues
        } else {
            values = (
                kind: "ignored_\(commandValues.kind)",
                summary: "Ignored duplicate or stale Focus command"
            )
        }
        return NormalizedLifeEventProjector().event(
            sourceID: receipt.sessionID,
            domain: "focus",
            kind: values.kind,
            occurredAt: receipt.occurredAt,
            numericValue: receipt.focusedDuration,
            provenance: "Persisted LifeBoard Focus command receipt",
            evidenceDisplay: values.summary,
            receipt: .init(receiptID: receipt.id, summary: values.summary)
        )
    }
}
