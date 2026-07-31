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

/// Reads the loop's memory out of the planning receipt ledger.
///
/// Static and record-driven: callers fetch, this interprets. Keeps every rule
/// here testable without a Core Data stack.
public enum DayLoopLedger {
    public static let closePrefix = "planning.scenario.dayClose."
    public static let openPrefix = "planning.scenario.dayOpen."
    public static let defaultWindow = 14

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
