import Foundation

/// What the loop remembers about itself.
///
/// Every figure here is derived from applied planning receipts — the same rows
/// that Undo reverses — so the loop's memory cannot disagree with the loop's
/// data. There is no separate streak counter to drift, no new entity, and no
/// model version.
public struct DayLoopSummary: Equatable, Sendable {
    /// `yyyyMMdd` stamps of days with an applied close receipt.
    public var closedStamps: Set<String>
    /// `yyyyMMdd` stamps of days with an applied open receipt.
    public var openedStamps: Set<String>
    /// Consecutive closed days ending today, or yesterday if today is still open.
    public var runLength: Int
    /// Closed days within `window`.
    public var closedInWindow: Int
    public var window: Int

    public init(
        closedStamps: Set<String> = [],
        openedStamps: Set<String> = [],
        runLength: Int = 0,
        closedInWindow: Int = 0,
        window: Int = 14
    ) {
        self.closedStamps = closedStamps
        self.openedStamps = openedStamps
        self.runLength = runLength
        self.closedInWindow = closedInWindow
        self.window = window
    }

    /// True when there is genuinely nothing to report yet.
    ///
    /// Distinct from a run of zero: a person who has closed four days and then
    /// missed one has a story; a person who has never closed a day does not, and
    /// showing them "0 days running" would be a verdict on nothing.
    public var hasNoHistory: Bool { closedStamps.isEmpty }
}

/// What the loop actually did over a stretch of days, for the review lens.
///
/// Counts of *days*, never of records: two closes of the same day (one undone,
/// one re-applied) is one day closed, and a lens that said "2" would be
/// counting our bookkeeping rather than the person's life.
public struct DayLoopReview: Equatable, Sendable {
    /// Days holding an applied close. Undone closes are excluded, not subtracted.
    public var daysClosed: Int
    public var daysOpened: Int
    /// Days that were both begun and ended deliberately — the loop's whole shape.
    public var daysWithBoth: Int
    /// Closes or commits the person took back. Reported, never scored.
    public var reversals: Int
    /// Distinct days holding any loop event at all, applied or reversed.
    public var recordedDays: Int

    public init(
        daysClosed: Int = 0,
        daysOpened: Int = 0,
        daysWithBoth: Int = 0,
        reversals: Int = 0,
        recordedDays: Int = 0
    ) {
        self.daysClosed = daysClosed
        self.daysOpened = daysOpened
        self.daysWithBoth = daysWithBoth
        self.reversals = reversals
        self.recordedDays = recordedDays
    }

    /// Below the shared pattern floor the lens must say it has nothing yet
    /// rather than narrate two days as if they were a habit.
    public var meetsFloor: Bool {
        recordedDays >= InsightsInterpretationEngine.minimumDaysForPattern
    }

    public var hasNoHistory: Bool { recordedDays == 0 }
}

/// Reads the loop's memory out of the planning receipt ledger.
///
/// Static and record-driven: callers fetch, this interprets. Keeps every rule
/// here testable without a Core Data stack.
public enum DayLoopLedger {
    public static let closePrefix = "planning.scenario.dayClose."
    public static let openPrefix = "planning.scenario.dayOpen."
    public static let defaultWindow = 14

    /// The event kinds the loop's receipts project into Insights.
    ///
    /// Named here rather than as literals at the emission site so the writer
    /// and every reader share one spelling. A receipt yields exactly one of
    /// these — an undone close is `closeReversed`, *not* `closed` plus a
    /// reversal — so counting them never double-counts a day.
    public enum EventKind {
        public static let closed = "day_closed"
        public static let closeReversed = "day_close_reversed"
        public static let opened = "day_opened"
        public static let openReversed = "day_open_reversed"
    }

    // MARK: - Review

    /// Counts what the loop did across the supplied events.
    ///
    /// Reads `localDay` rather than bucketing `occurredAt` by calendar: a close
    /// applied at 00:20 belongs to the day it was *about*, not the day the tap
    /// landed on. That distinction is the whole reason `.dayClose` receipts
    /// carry a day stamp.
    ///
    /// Events not produced by the loop are ignored, so this is safe to hand the
    /// whole authorized stream.
    public static func review(events: [NormalizedLifeEvent]) -> DayLoopReview {
        // Explicit loops rather than chained filter/map: this target's
        // type-checker has repeatedly blown its budget on the latter.
        var closedDays: Set<PlanningDay> = []
        var openedDays: Set<PlanningDay> = []
        var touchedDays: Set<PlanningDay> = []
        var reversals = 0

        for event in events {
            switch event.kind {
            case EventKind.closed:
                closedDays.insert(event.localDay)
                touchedDays.insert(event.localDay)
            case EventKind.opened:
                openedDays.insert(event.localDay)
                touchedDays.insert(event.localDay)
            case EventKind.closeReversed, EventKind.openReversed:
                // A taken-back day is still a day the person engaged with, so
                // it counts toward history — just not toward the totals.
                reversals += 1
                touchedDays.insert(event.localDay)
            default:
                continue
            }
        }

        return DayLoopReview(
            daysClosed: closedDays.count,
            daysOpened: openedDays.count,
            daysWithBoth: closedDays.intersection(openedDays).count,
            reversals: reversals,
            recordedDays: touchedDays.count
        )
    }

    // MARK: - Continuity

    public static func summarize(
        records: [PlanningReceiptRecord],
        now: Date = Date(),
        window: Int = defaultWindow,
        calendar: Calendar = .current
    ) -> DayLoopSummary {
        let closed = stamps(in: records, prefix: closePrefix)
        let opened = stamps(in: records, prefix: openPrefix)
        let today = DayLoopClosureLog.stamp(for: now, calendar: calendar)

        // A day still in progress is not a broken run. Counting back from
        // yesterday when today is open is what stops the number collapsing to
        // zero every morning and rebuilding every night.
        let anchorOffset = closed.contains(today) ? 0 : -1
        var run = 0
        var offset = anchorOffset
        while let day = calendar.date(byAdding: .day, value: offset, to: now),
              closed.contains(DayLoopClosureLog.stamp(for: day, calendar: calendar)) {
            run += 1
            offset -= 1
        }

        let windowStamps: Set<String> = Set((0..<window).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now)
                .map { DayLoopClosureLog.stamp(for: $0, calendar: calendar) }
        })

        return DayLoopSummary(
            closedStamps: closed,
            openedStamps: opened,
            runLength: run,
            closedInWindow: closed.intersection(windowStamps).count,
            window: window
        )
    }

    /// Applied receipts only, keyed by the day their source names.
    ///
    /// An undone close stops counting, because `state` flips to `.undone` — the
    /// same reason `hasAppliedReceipt` is trustworthy.
    /// Written as a loop rather than a filter/map/filter chain: this codebase
    /// has repeatedly hit the Swift type-checker's budget on chained collection
    /// expressions, and the failure mode is a build that hangs rather than one
    /// that errors clearly.
    private static func stamps(in records: [PlanningReceiptRecord], prefix: String) -> Set<String> {
        var result: Set<String> = []
        for record in records {
            guard record.state == .applied else { continue }
            let source = record.receipt.source
            guard source.hasPrefix(prefix) else { continue }
            let tail = String(source.dropFirst(prefix.count))
            let stamp = tail.replacingOccurrences(of: "-", with: "")
            guard stamp.count == 8 else { continue }
            result.insert(stamp)
        }
        return result
    }

    // MARK: - The carry

    /// The task last night's close named as tomorrow's first thing.
    ///
    /// Read out of the receipt rather than off the task, because `pinOrder == 0`
    /// is also written by an ordinary manual reorder in Plan — the field records
    /// a position, not a provenance. The receipt records who set it and when.
    public static func anchorTaskID(
        in records: [PlanningReceiptRecord],
        closedOn closedDay: PlanningDay,
        targetDay: PlanningDay,
        decoder: JSONDecoder = JSONDecoder()
    ) -> UUID? {
        let source = DayCloseScenarioBuilder.receiptSource(for: closedDay)
        guard let record = records.first(where: {
            $0.state == .applied && $0.receipt.source == source
        }) else { return nil }

        guard let mutation = try? decoder.decode(PlanMutation.self, from: record.receipt.forwardData) else {
            return nil
        }
        return anchor(in: mutation, targetDay: targetDay)
    }

    private static func anchor(in mutation: PlanMutation, targetDay: PlanningDay) -> UUID? {
        switch mutation {
        case let .batch(children):
            for child in children {
                if let found = anchor(in: child, targetDay: targetDay) { return found }
            }
            return nil
        case let .saveTaskMetadata(_, after):
            // The exact triple `applyAnchor` writes. Requiring all three keeps an
            // ordinary carry-to-tomorrow — which sets `planningDay` and nothing
            // else — from being mistaken for a deliberate choice.
            guard after.pinOrder == 0,
                  after.commitmentLevel == .mustDo,
                  after.planningDay == targetDay else { return nil }
            return after.taskID
        default:
            return nil
        }
    }
}
