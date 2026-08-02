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
        forward: PlanMutation = .batch([]),
        id: UUID = UUID(),
        createdAt: Date? = nil,
        appliedAt: Date? = nil
    ) -> PlanningReceiptRecord {
        let createdAt = createdAt ?? now
        return PlanningReceiptRecord(
            receipt: PlanMutationReceipt(
                id: id,
                source: source,
                summary: "test",
                forwardData: (try? JSONEncoder().encode(forward)) ?? Data(),
                undoData: Data(),
                createdAt: createdAt
            ),
            state: state,
            appliedAt: state == .applied ? (appliedAt ?? createdAt) : nil,
            undoneAt: state == .undone ? createdAt : nil
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

    // MARK: - Morning evidence and policy

    func testEvidenceReportJoinsSignalsOnlyToAppliedOpenReceipts() {
        let today = day(offsetFromNow: 0)
        let appliedOpenID = UUID()
        let undoneOpenID = UUID()
        let morning = today.startDate(calendar: calendar)!.addingTimeInterval(9 * 3_600)
        let records = [
            record(source: DayCloseScenarioBuilder.receiptSource(for: today)),
            record(
                source: DayOpenScenarioBuilder.receiptSource(for: today),
                id: appliedOpenID,
                createdAt: morning,
                appliedAt: morning
            ),
            record(
                source: DayOpenScenarioBuilder.receiptSource(for: day(offsetFromNow: -1)),
                state: .undone,
                id: undoneOpenID
            )
        ]
        let report = DayLoopLedger.evidenceReport(
            records: records,
            proposalSignals: [
                DayOpenProposalSignal(
                    receiptID: appliedOpenID,
                    dayStamp: "20260724",
                    wasEdited: false,
                    committedAt: morning
                ),
                DayOpenProposalSignal(
                    receiptID: undoneOpenID,
                    dayStamp: "20260723",
                    wasEdited: true,
                    committedAt: morning
                )
            ],
            calendar: calendar
        )

        XCTAssertEqual(report.eligibleDays, 2)
        XCTAssertEqual(report.closes, 1)
        XCTAssertEqual(report.opensBeforeEleven, 1)
        XCTAssertEqual(report.daysWithBoth, 1)
        XCTAssertEqual(report.reversals, 1)
        XCTAssertEqual(report.knownProposalSignals, 1)
        XCTAssertEqual(report.uneditedShare, 1)
    }

    func testMissingProposalSidecarsRemainUnknownRatherThanEdited() {
        let openID = UUID()
        let report = DayLoopLedger.evidenceReport(
            records: [record(
                source: DayOpenScenarioBuilder.receiptSource(for: day(offsetFromNow: 0)),
                id: openID
            )],
            proposalSignals: [],
            calendar: calendar
        )

        XCTAssertEqual(report.knownProposalSignals, 0)
        XCTAssertEqual(report.uneditedProposalSignals, 0)
        XCTAssertNil(report.uneditedShare)
    }

    func testElevenOClockIsNotCountedAsBeforeEleven() {
        let today = day(offsetFromNow: 0)
        let eleven = today.startDate(calendar: calendar)!.addingTimeInterval(11 * 3_600)
        let report = DayLoopLedger.evidenceReport(
            records: [record(
                source: DayOpenScenarioBuilder.receiptSource(for: today),
                createdAt: eleven,
                appliedAt: eleven
            )],
            proposalSignals: [],
            calendar: calendar
        )

        XCTAssertEqual(report.opensBeforeEleven, 0)
    }

    func testMorningCommitPolicyAppliesTheFourteenDayFortyPercentRule() {
        let resolver = MorningCommitPolicyResolver()

        XCTAssertEqual(
            resolver.resolve(.init(eligibleDays: 13, opensBeforeEleven: 0)),
            .explicitConfirmation
        )
        XCTAssertEqual(
            resolver.resolve(.init(eligibleDays: 14, opensBeforeEleven: 5)),
            .zeroInteractionConfirmation
        )
        XCTAssertEqual(
            resolver.resolve(.init(eligibleDays: 15, opensBeforeEleven: 6)),
            .explicitConfirmation,
            "Exactly 40% stays explicit; only fewer than 40% changes policy."
        )
    }

    func testProposalSignalStoreIsVersionedAndKeyedByReceiptID() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DayOpenProposalSignalStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = DayOpenProposalSignalStore(rootURL: root)
        let receiptID = UUID()

        try await store.record(.init(
            receiptID: receiptID,
            dayStamp: "20260801",
            wasEdited: true,
            committedAt: now
        ))
        try await store.record(.init(
            receiptID: receiptID,
            dayStamp: "20260801",
            wasEdited: false,
            committedAt: now.addingTimeInterval(1)
        ))

        let signals = try await store.signals()
        XCTAssertEqual(signals.count, 1)
        XCTAssertEqual(signals.first?.schemaVersion, DayOpenProposalSignal.currentSchemaVersion)
        XCTAssertEqual(signals.first?.wasEdited, false)
        let localOnlyDirectory = root.appendingPathComponent("LifeBoard/LocalOnly", isDirectory: true)
        let resourceValues = try localOnlyDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resourceValues.isExcludedFromBackup, true)
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

    // MARK: - Review

    private func loopEvent(kind: String, day: PlanningDay) -> NormalizedLifeEvent {
        NormalizedLifeEvent(
            id: "\(kind)-\(day.year)-\(day.month)-\(day.day)",
            sourceID: UUID(),
            domain: "plan",
            kind: kind,
            occurredAt: now,
            localDay: day,
            numericValue: nil,
            completeness: .complete,
            sensitivity: .privateStandard,
            allowedDestinations: [.insights],
            provenance: "test"
        )
    }

    func testReviewCountsDaysNotRecords() {
        // Two receipts about the same day is one day, not two. Counting records
        // would report our bookkeeping instead of the person's life.
        let today = day(offsetFromNow: 0)
        let review = DayLoopLedger.review(events: [
            loopEvent(kind: DayLoopLedger.EventKind.closed, day: today),
            loopEvent(kind: DayLoopLedger.EventKind.closed, day: today)
        ])
        XCTAssertEqual(review.daysClosed, 1)
        XCTAssertEqual(review.recordedDays, 1)
    }

    func testAReversedCloseIsNotCountedAsClosed() {
        let review = DayLoopLedger.review(events: [
            loopEvent(kind: DayLoopLedger.EventKind.closeReversed, day: day(offsetFromNow: -1))
        ])
        XCTAssertEqual(review.daysClosed, 0)
        XCTAssertEqual(review.reversals, 1)
        // Still history: the person engaged with that day and took it back.
        XCTAssertEqual(review.recordedDays, 1)
    }

    func testDaysWithBothCountsOnlyDaysCarryingOpenAndClose() {
        let full = day(offsetFromNow: -1)
        let closeOnly = day(offsetFromNow: -2)
        let review = DayLoopLedger.review(events: [
            loopEvent(kind: DayLoopLedger.EventKind.opened, day: full),
            loopEvent(kind: DayLoopLedger.EventKind.closed, day: full),
            loopEvent(kind: DayLoopLedger.EventKind.closed, day: closeOnly)
        ])
        XCTAssertEqual(review.daysOpened, 1)
        XCTAssertEqual(review.daysClosed, 2)
        XCTAssertEqual(review.daysWithBoth, 1)
    }

    func testNonLoopEventsAreIgnored() {
        // The lens hands over the whole authorized stream; a dragged block must
        // not read as a closed day.
        let review = DayLoopLedger.review(events: [
            loopEvent(kind: "mutation_applied", day: day(offsetFromNow: 0)),
            loopEvent(kind: "started", day: day(offsetFromNow: 0))
        ])
        XCTAssertEqual(review, DayLoopReview())
        XCTAssertTrue(review.hasNoHistory)
    }

    func testTheFloorMatchesTheSharedPatternFloor() {
        var days: [NormalizedLifeEvent] = []
        for offset in 1...InsightsInterpretationEngine.minimumDaysForPattern {
            days.append(loopEvent(kind: DayLoopLedger.EventKind.closed, day: day(offsetFromNow: -offset)))
        }
        XCTAssertTrue(DayLoopLedger.review(events: days).meetsFloor)
        XCTAssertFalse(DayLoopLedger.review(events: Array(days.dropLast())).meetsFloor)
    }

    func testNoHistoryIsDistinctFromZeroDaysClosed() {
        // "Nothing recorded" and "recorded, none closed" must not collapse.
        let empty = DayLoopLedger.review(events: [])
        XCTAssertTrue(empty.hasNoHistory)

        let reversedOnly = DayLoopLedger.review(events: [
            loopEvent(kind: DayLoopLedger.EventKind.openReversed, day: day(offsetFromNow: -1))
        ])
        XCTAssertEqual(reversedOnly.daysClosed, 0)
        XCTAssertFalse(reversedOnly.hasNoHistory)
    }
}
