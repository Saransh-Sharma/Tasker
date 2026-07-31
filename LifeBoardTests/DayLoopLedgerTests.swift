import XCTest
@testable import LifeBoard

/// The loop's memory, derived entirely from applied planning receipts.
final class DayLoopLedgerTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private func day(offsetFromNow offset: Int) -> PlanningDay {
        let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        return PlanningDay(
            date: date,
            timeZone: calendar.timeZone,
            calendar: calendar
        )
    }

    private func record(
        source: String,
        state: PlanningReceiptState = .applied,
        forward: PlanMutation = .batch([])
    ) -> PlanningReceiptRecord {
        PlanningReceiptRecord(
            receipt: PlanMutationReceipt(
                id: UUID(),
                source: source,
                summary: "test",
                forwardData: (try? JSONEncoder().encode(forward)) ?? Data(),
                undoData: Data(),
                createdAt: now
            ),
            state: state,
            appliedAt: state == .applied ? now : nil
        )
    }

    private func closeRecord(offset: Int, state: PlanningReceiptState = .applied) -> PlanningReceiptRecord {
        record(source: DayCloseScenarioBuilder.receiptSource(for: day(offsetFromNow: offset)), state: state)
    }

    // MARK: - Continuity

    func testARunCountsBackFromTodayWhenTodayIsClosed() {
        let records = (0...3).map { closeRecord(offset: -$0) }

        let summary = DayLoopLedger.summarize(records: records, now: now, calendar: calendar)

        XCTAssertEqual(summary.runLength, 4)
        XCTAssertEqual(summary.closedInWindow, 4)
    }

    func testADayStillInProgressDoesNotBreakTheRun() {
        // Counting from today would collapse the number to zero every morning
        // and rebuild it every night.
        let records = (1...3).map { closeRecord(offset: -$0) }

        let summary = DayLoopLedger.summarize(records: records, now: now, calendar: calendar)

        XCTAssertEqual(summary.runLength, 3)
    }

    func testAGapEndsTheRunButNotTheWindowCount() {
        // Closed today, yesterday missed, three before that closed.
        var records = [closeRecord(offset: 0)]
        records += (2...4).map { closeRecord(offset: -$0) }

        let summary = DayLoopLedger.summarize(records: records, now: now, calendar: calendar)

        // The run drops to 1 while the 14-day figure keeps the fuller picture —
        // the arithmetic that makes a bad day survivable.
        XCTAssertEqual(summary.runLength, 1)
        XCTAssertEqual(summary.closedInWindow, 4)
    }

    func testAnUndoneCloseStopsCounting() {
        let records = [
            closeRecord(offset: 0, state: .undone),
            closeRecord(offset: -1)
        ]

        let summary = DayLoopLedger.summarize(records: records, now: now, calendar: calendar)

        XCTAssertEqual(summary.runLength, 1)
        XCTAssertEqual(summary.closedInWindow, 1)
    }

    func testAPreparedButUnappliedReceiptNeverCounts() {
        let summary = DayLoopLedger.summarize(
            records: [closeRecord(offset: 0, state: .prepared)],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.runLength, 0)
        XCTAssertTrue(summary.hasNoHistory)
    }

    func testNoHistoryIsDistinctFromABrokenRun() {
        let empty = DayLoopLedger.summarize(records: [], now: now, calendar: calendar)
        XCTAssertTrue(empty.hasNoHistory)

        let lapsed = DayLoopLedger.summarize(
            records: [closeRecord(offset: -6)],
            now: now,
            calendar: calendar
        )
        // Someone who closed once a week ago has a story; showing them
        // "0 days running" alone would be a verdict on nothing.
        XCTAssertFalse(lapsed.hasNoHistory)
        XCTAssertEqual(lapsed.runLength, 0)
        XCTAssertEqual(lapsed.closedInWindow, 1)
    }

    func testDaysOutsideTheWindowDropOutOfTheWindowCount() {
        let records = [closeRecord(offset: 0), closeRecord(offset: -20)]

        let summary = DayLoopLedger.summarize(records: records, now: now, window: 14, calendar: calendar)

        XCTAssertEqual(summary.closedInWindow, 1)
        XCTAssertEqual(summary.closedStamps.count, 2, "the raw history is still there")
    }

    func testOpenAndCloseReceiptsAreCountedSeparately() {
        let closed = closeRecord(offset: 0)
        let opened = record(source: "planning.scenario.dayOpen.2026-07-24")

        let summary = DayLoopLedger.summarize(records: [closed, opened], now: now, calendar: calendar)

        XCTAssertEqual(summary.closedStamps.count, 1)
        XCTAssertEqual(summary.openedStamps, ["20260724"])
    }

    func testUnrelatedPlanningReceiptsAreIgnored() {
        let summary = DayLoopLedger.summarize(
            records: [record(source: "planning.scenario.repair")],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(summary.hasNoHistory)
        XCTAssertEqual(summary.runLength, 0)
    }

    // MARK: - The carry

    private func anchorMutation(taskID: UUID, targetDay: PlanningDay) -> PlanMutation {
        var after = PlanningTaskMetadata(taskID: taskID)
        after.planningDay = targetDay
        after.commitmentLevel = .mustDo
        after.pinOrder = 0
        return .batch([.saveTaskMetadata(before: PlanningTaskMetadata(taskID: taskID), after: after)])
    }

    func testTheAnchorIsReadOutOfTheReceiptNotTheTask() {
        let taskID = UUID()
        let yesterday = day(offsetFromNow: -1)
        let today = day(offsetFromNow: 0)
        let records = [
            record(
                source: DayCloseScenarioBuilder.receiptSource(for: yesterday),
                forward: anchorMutation(taskID: taskID, targetDay: today)
            )
        ]

        XCTAssertEqual(
            DayLoopLedger.anchorTaskID(in: records, closedOn: yesterday, targetDay: today),
            taskID
        )
    }

    func testAnOrdinaryCarryIsNotMistakenForADeliberateChoice() {
        // `.tomorrow` sets `planningDay` and nothing else. Without requiring the
        // full triple, every carried task would look like the chosen one.
        let taskID = UUID()
        let yesterday = day(offsetFromNow: -1)
        let today = day(offsetFromNow: 0)
        var after = PlanningTaskMetadata(taskID: taskID)
        after.planningDay = today
        let records = [
            record(
                source: DayCloseScenarioBuilder.receiptSource(for: yesterday),
                forward: .batch([.saveTaskMetadata(before: PlanningTaskMetadata(taskID: taskID), after: after)])
            )
        ]

        XCTAssertNil(DayLoopLedger.anchorTaskID(in: records, closedOn: yesterday, targetDay: today))
    }

    func testAnUndoneCloseCarriesNothing() {
        let taskID = UUID()
        let yesterday = day(offsetFromNow: -1)
        let today = day(offsetFromNow: 0)
        let records = [
            record(
                source: DayCloseScenarioBuilder.receiptSource(for: yesterday),
                state: .undone,
                forward: anchorMutation(taskID: taskID, targetDay: today)
            )
        ]

        XCTAssertNil(DayLoopLedger.anchorTaskID(in: records, closedOn: yesterday, targetDay: today))
    }

    func testAnAnchorPointingAtAnotherDayIsNotTodaysCarry() {
        let taskID = UUID()
        let yesterday = day(offsetFromNow: -1)
        let records = [
            record(
                source: DayCloseScenarioBuilder.receiptSource(for: yesterday),
                forward: anchorMutation(taskID: taskID, targetDay: day(offsetFromNow: 5))
            )
        ]

        XCTAssertNil(
            DayLoopLedger.anchorTaskID(in: records, closedOn: yesterday, targetDay: day(offsetFromNow: 0))
        )
    }

    func testNoCloseReceiptMeansNoCarry() {
        XCTAssertNil(
            DayLoopLedger.anchorTaskID(
                in: [],
                closedOn: day(offsetFromNow: -1),
                targetDay: day(offsetFromNow: 0)
            )
        )
    }
}
