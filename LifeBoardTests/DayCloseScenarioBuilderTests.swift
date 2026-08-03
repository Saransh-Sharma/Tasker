import XCTest
@testable import LifeBoard

/// Contract tests for the end-of-day reconciliation.
///
/// These pin the properties that make Close the Day safe to undo: one mutation
/// per task, a batch inverse that restores every field it touched, and the
/// distinction between "nothing was planned" and "nothing was achieved".
final class DayCloseScenarioBuilderTests: XCTestCase {

    private let today = PlanningDay(year: 2026, month: 7, day: 31, timeZoneIdentifier: "Asia/Kolkata")
    private let tomorrow = PlanningDay(year: 2026, month: 8, day: 1, timeZoneIdentifier: "Asia/Kolkata")
    private let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Fixtures

    private func snapshot(
        planned: [PlanningTaskSummary] = [],
        unscheduled: [PlanningTaskSummary] = []
    ) -> PlanDaySnapshot {
        PlanDaySnapshot(
            day: today,
            capacity: CapacityBudget(
                workingDuration: 8 * 3_600,
                fixedCalendarDuration: 0,
                internalFixedDuration: 0,
                bufferDuration: 0,
                plannedEstimatedDuration: 0,
                missingEstimateCount: 0
            ),
            commitments: [],
            blocks: [],
            plannedTasks: planned,
            unscheduledTasks: unscheduled,
            generatedAt: now
        )
    }

    private func task(
        _ title: String,
        id: UUID = UUID(),
        commitment: TaskCommitmentLevel = .standard,
        pinOrder: Int? = nil
    ) -> PlanningTaskSummary {
        PlanningTaskSummary(
            id: id,
            title: title,
            metadata: PlanningTaskMetadata(
                taskID: id,
                planningDay: today,
                commitmentLevel: commitment,
                unscheduledDisposition: .inbox,
                pinOrder: pinOrder,
                updatedAt: Date(timeIntervalSince1970: 500_000)
            )
        )
    }

    private func metadata(in mutation: PlanMutation) -> (before: PlanningTaskMetadata, after: PlanningTaskMetadata)? {
        guard case let .saveTaskMetadata(before, after) = mutation else { return nil }
        return (before, after)
    }

    // MARK: - Direction mapping

    func testEveryDirectionProducesExactlyOneMutationAndOneTouchedRecord() {
        let tasks = DayCloseDirection.allCases.map { task("Task \($0.rawValue)") }
        let decisions = zip(DayCloseDirection.allCases, tasks).map {
            DayCloseDecision(taskID: $1.id, direction: $0, decidedAt: now)
        }

        let scenario = DayCloseScenarioBuilder.make(
            decisions: decisions,
            anchorTaskID: nil,
            tasks: tasks,
            snapshot: snapshot(planned: tasks),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertEqual(scenario.proposedMutations.count, 4)
        XCTAssertEqual(scenario.touchedRecords.count, 4)
        XCTAssertEqual(Set(scenario.touchedRecords.map(\.recordID)).count, 4)
        XCTAssertEqual(scenario.source, .dayClose)
    }

    func testTomorrowCarriesThePlanningDayWithoutClearingTheStartConstraint() throws {
        var item = task("Ship the thing")
        let thursday = PlanningDay(year: 2026, month: 8, day: 6, timeZoneIdentifier: "Asia/Kolkata")
        item.metadata.startDay = thursday

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: item.id, direction: .tomorrow, decidedAt: now)],
            anchorTaskID: nil,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        let fields = try XCTUnwrap(metadata(in: scenario.proposedMutations[0]))
        XCTAssertEqual(fields.after.planningDay, tomorrow)
        // A task that could not begin until Thursday still cannot, just because
        // it was carried.
        XCTAssertEqual(fields.after.startDay, thursday)
    }

    func testReleaseArchivesAndNeverDeletes() {
        let item = task("An idea that passed")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: item.id, direction: .release, decidedAt: now)],
            anchorTaskID: nil,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        let fields = metadata(in: scenario.proposedMutations[0])
        // "Let it go" means kept and never chased. `.deleted` is a tombstone
        // every projection treats as removed — it would make the copy a lie.
        XCTAssertEqual(fields?.after.unscheduledDisposition, .archived)
        XCTAssertNotEqual(fields?.after.unscheduledDisposition, .deleted)
        XCTAssertNil(fields?.after.planningDay)
    }

    func testSomedayDropsMustDoSoItStopsShoutingFromTheBacklog() {
        let item = task("Big rewrite", commitment: .mustDo, pinOrder: 2)

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: item.id, direction: .someday, decidedAt: now)],
            anchorTaskID: nil,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        let fields = metadata(in: scenario.proposedMutations[0])
        XCTAssertEqual(fields?.after.unscheduledDisposition, .someday)
        XCTAssertEqual(fields?.after.commitmentLevel, .standard)
        XCTAssertNil(fields?.after.pinOrder)
    }

    func testDoneAnywayUsesCompletionNotMetadata() {
        let item = task("Already handled")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: item.id, direction: .doneAnyway, decidedAt: now)],
            anchorTaskID: nil,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        guard case let .setTaskCompletion(taskID, before, after) = scenario.proposedMutations[0] else {
            return XCTFail("Expected a completion mutation")
        }
        XCTAssertEqual(taskID, item.id)
        XCTAssertFalse(before)
        XCTAssertTrue(after)
    }

    // MARK: - The one-mutation-per-task invariant

    func testAnchorAndTomorrowDecisionCollapseIntoOneMutation() {
        let item = task("Tomorrow's opener")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: item.id, direction: .tomorrow, decidedAt: now)],
            anchorTaskID: item.id,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        // Two mutations would still invert correctly, but they would produce two
        // diff lines and two touched records for one row, and the version check
        // would then compare the task against itself.
        XCTAssertEqual(scenario.proposedMutations.count, 1)
        XCTAssertEqual(scenario.touchedRecords.count, 1)

        let fields = metadata(in: scenario.proposedMutations[0])
        XCTAssertEqual(fields?.after.planningDay, tomorrow)
        XCTAssertEqual(fields?.after.commitmentLevel, .mustDo)
        XCTAssertEqual(fields?.after.pinOrder, 0)
    }

    func testAnchorOnAnUndecidedTaskStillProducesItsOwnMutation() {
        let carried = task("Carried")
        let anchored = task("Anchored")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: carried.id, direction: .tomorrow, decidedAt: now)],
            anchorTaskID: anchored.id,
            tasks: [carried, anchored],
            snapshot: snapshot(planned: [carried, anchored]),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertEqual(scenario.proposedMutations.count, 2)
        XCTAssertEqual(Set(scenario.touchedRecords.map(\.recordID)), [carried.id, anchored.id])
    }

    func testAnchorIsIgnoredWhenTheSameTaskWasReleasedOrDeferred() {
        for direction in [DayCloseDirection.release, .someday, .doneAnyway] {
            let item = task("Contradiction")

            let scenario = DayCloseScenarioBuilder.make(
                decisions: [DayCloseDecision(taskID: item.id, direction: direction, decidedAt: now)],
                anchorTaskID: item.id,
                tasks: [item],
                snapshot: snapshot(planned: [item]),
                tomorrow: tomorrow,
                now: now
            )

            // The decision the person made on the card wins over the anchor;
            // anchoring something they just let go would contradict it.
            XCTAssertEqual(scenario.proposedMutations.count, 1, "\(direction)")
            if let fields = metadata(in: scenario.proposedMutations[0]) {
                XCTAssertNotEqual(fields.after.pinOrder, 0, "\(direction)")
            }
            XCTAssertFalse(
                scenario.diff.contains { $0.title == "Tomorrow starts with" },
                "\(direction) should not be advertised as tomorrow's first thing"
            )
        }
    }

    func testTheLatestDecisionWinsWhenACardIsBroughtBackAndReSwiped() {
        let item = task("Changed my mind")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [
                DayCloseDecision(taskID: item.id, direction: .release, decidedAt: now),
                DayCloseDecision(taskID: item.id, direction: .tomorrow, decidedAt: now.addingTimeInterval(5))
            ],
            anchorTaskID: nil,
            tasks: [item],
            snapshot: snapshot(planned: [item]),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertEqual(scenario.proposedMutations.count, 1)
        XCTAssertEqual(metadata(in: scenario.proposedMutations[0])?.after.planningDay, tomorrow)
    }

    // MARK: - Undo

    func testBatchInverseRestoresEveryFieldTheReconciliationTouched() {
        let carried = task("Carried", commitment: .mustDo, pinOrder: 3)
        let deferred = task("Deferred", commitment: .mustDo, pinOrder: 1)
        let released = task("Released")
        let finished = task("Finished")
        let tasks = [carried, deferred, released, finished]

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [
                DayCloseDecision(taskID: carried.id, direction: .tomorrow, decidedAt: now),
                DayCloseDecision(taskID: deferred.id, direction: .someday, decidedAt: now),
                DayCloseDecision(taskID: released.id, direction: .release, decidedAt: now),
                DayCloseDecision(taskID: finished.id, direction: .doneAnyway, decidedAt: now)
            ],
            anchorTaskID: carried.id,
            tasks: tasks,
            snapshot: snapshot(planned: tasks),
            tomorrow: tomorrow,
            now: now
        )

        guard case let .batch(inverted) = PlanMutation.batch(scenario.proposedMutations).inverse else {
            return XCTFail("A batch must invert to a batch")
        }

        // Reverse order: the last write unwinds first.
        XCTAssertEqual(inverted.count, scenario.proposedMutations.count)

        var restored: [UUID: PlanningTaskMetadata] = [:]
        var completion: [UUID: Bool] = [:]
        for mutation in inverted {
            switch mutation {
            case let .saveTaskMetadata(_, after): restored[after.taskID] = after
            case let .setTaskCompletion(taskID, _, after): completion[taskID] = after
            default: XCTFail("Unexpected mutation in a day-close batch")
            }
        }

        for original in [carried, deferred, released] {
            let back = restored[original.id]
            XCTAssertEqual(back?.planningDay, original.metadata.planningDay, original.title)
            XCTAssertEqual(back?.commitmentLevel, original.metadata.commitmentLevel, original.title)
            XCTAssertEqual(back?.pinOrder, original.metadata.pinOrder, original.title)
            XCTAssertEqual(
                back?.unscheduledDisposition,
                original.metadata.unscheduledDisposition,
                original.title
            )
            XCTAssertEqual(back?.updatedAt, original.metadata.updatedAt, original.title)
        }
        XCTAssertEqual(completion[finished.id], false)
    }

    // MARK: - Closing an unremarkable day

    func testSkippedCardsProduceNoMutation() {
        let untouched = task("Left undecided")

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [],
            anchorTaskID: nil,
            tasks: [untouched],
            snapshot: snapshot(planned: [untouched]),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertTrue(scenario.proposedMutations.isEmpty)
        XCTAssertTrue(scenario.touchedRecords.isEmpty)
    }

    func testAnEmptyReconciliationIsStillApplicable() {
        let scenario = DayCloseScenarioBuilder.make(
            decisions: [],
            anchorTaskID: nil,
            tasks: [],
            snapshot: snapshot(),
            tomorrow: tomorrow,
            now: now
        )

        // There is no state of a day that should stop someone closing it.
        XCTAssertTrue(scenario.validationIssues.isEmpty)
        XCTAssertTrue(scenario.isReadyToApply)
    }

    func testDecisionsReferringToUnknownTasksAreDropped() {
        let scenario = DayCloseScenarioBuilder.make(
            decisions: [DayCloseDecision(taskID: UUID(), direction: .tomorrow, decidedAt: now)],
            anchorTaskID: UUID(),
            tasks: [],
            snapshot: snapshot(),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertTrue(scenario.proposedMutations.isEmpty)
    }

    // MARK: - Receipt identity

    func testReceiptSourceIsDayScopedSoClosingCannotLeakAcrossDays() {
        XCTAssertEqual(
            DayCloseScenarioBuilder.receiptSource(for: today),
            "planning.scenario.dayClose.2026-07-31"
        )
        XCTAssertNotEqual(
            DayCloseScenarioBuilder.receiptSource(for: today),
            DayCloseScenarioBuilder.receiptSource(for: tomorrow)
        )

        let scenario = DayCloseScenarioBuilder.make(
            decisions: [],
            anchorTaskID: nil,
            tasks: [],
            snapshot: snapshot(),
            tomorrow: tomorrow,
            now: now
        )
        XCTAssertEqual(scenario.receiptSource, "planning.scenario.dayClose.2026-07-31")
    }

    func testMutationOrderIsStableAcrossBuilds() {
        let tasks = (0..<6).map { task("Task \($0)") }
        let decisions = tasks.map { DayCloseDecision(taskID: $0.id, direction: .tomorrow, decidedAt: now) }

        let first = DayCloseScenarioBuilder.make(
            decisions: decisions,
            anchorTaskID: nil,
            tasks: tasks,
            snapshot: snapshot(planned: tasks),
            tomorrow: tomorrow,
            now: now
        )
        let second = DayCloseScenarioBuilder.make(
            decisions: decisions.reversed(),
            anchorTaskID: nil,
            tasks: tasks.reversed(),
            snapshot: snapshot(planned: tasks),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertEqual(
            first.touchedRecords.map(\.recordID),
            second.touchedRecords.map(\.recordID)
        )
    }

    // MARK: - Diff

    func testDiffGroupsByDirectionSoALongReconciliationStaysReadable() {
        let tasks = (0..<5).map { task("Task \($0)") }
        let decisions = tasks.map { DayCloseDecision(taskID: $0.id, direction: .tomorrow, decidedAt: now) }

        let scenario = DayCloseScenarioBuilder.make(
            decisions: decisions,
            anchorTaskID: nil,
            tasks: tasks,
            snapshot: snapshot(planned: tasks),
            tomorrow: tomorrow,
            now: now
        )

        XCTAssertEqual(scenario.diff.count, 1)
        XCTAssertEqual(scenario.diff[0].title, "5 moved to tomorrow")
    }
}

/// The retrospective's honesty rules.
final class DayCloseRibbonBuilderTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private var end: Date { start.addingTimeInterval(12 * 3_600) }

    private func block(_ title: String, offsetHours: Double, hours: Double) -> InternalTimeBlock {
        InternalTimeBlock(
            title: title,
            startAt: start.addingTimeInterval(offsetHours * 3_600),
            endAt: start.addingTimeInterval((offsetHours + hours) * 3_600)
        )
    }

    private func session(offsetHours: Double, focused: TimeInterval) -> FocusExecutionReceipt {
        FocusExecutionReceipt(
            sessionID: UUID(),
            taskID: nil,
            timeBlockID: nil,
            targetDuration: focused,
            actualFocusedDuration: focused,
            interruptionCount: 0,
            outcome: .completed,
            energyAfter: nil,
            reflection: nil,
            startedAt: start.addingTimeInterval(offsetHours * 3_600),
            endedAt: start.addingTimeInterval(offsetHours * 3_600 + focused)
        )
    }

    func testNothingPlannedReportsNilNotZero() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [],
            commitments: [],
            sessions: [],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        // "You planned nothing" and "you planned nothing and hit none of it" are
        // different statements, and only one of them is true.
        XCTAssertNil(ribbon.summary.plannedMinutes)
        XCTAssertNil(ribbon.summary.focusedMinutes)
        XCTAssertNil(ribbon.summary.focusRatio)
        XCTAssertTrue(ribbon.summary.hasNothingToReport)
    }

    func testFocusRatioIsNilWhenNothingWasPlannedEvenIfFocusHappened() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [],
            commitments: [],
            sessions: [session(offsetHours: 1, focused: 1_800)],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertEqual(ribbon.summary.focusedMinutes, 30)
        XCTAssertNil(ribbon.summary.plannedMinutes)
        XCTAssertNil(ribbon.summary.focusRatio)
    }

    func testFocusRatioIsNotClampedSoOverrunStaysVisible() throws {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [block("Deep work", offsetHours: 1, hours: 1)],
            commitments: [],
            sessions: [session(offsetHours: 1, focused: 2 * 3_600)],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertEqual(try XCTUnwrap(ribbon.summary.focusRatio), 2, accuracy: 0.01)
    }

    func testExternalCommitmentsAndAuthoredBlocksStayDistinct() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [block("Deep work", offsetHours: 1, hours: 1)],
            commitments: [
                PlanningFixedCommitment(
                    id: "evt-1",
                    title: "Standup",
                    startAt: start.addingTimeInterval(3_600),
                    endAt: start.addingTimeInterval(5_400),
                    source: .externalCalendar
                ),
                // The capacity lens reports authored blocks as commitments too;
                // drawing both would double every block on the ribbon.
                PlanningFixedCommitment(
                    id: "internal-1",
                    title: "Deep work",
                    startAt: start.addingTimeInterval(3_600),
                    endAt: start.addingTimeInterval(7_200),
                    source: .internalBlock
                )
            ],
            sessions: [],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertEqual(ribbon.segments.filter { $0.kind == .planned }.count, 1)
        XCTAssertEqual(ribbon.segments.filter { $0.kind == .commitment }.count, 1)
    }

    func testOverlappingSegmentsOfTheSameKindStackButKindsNeverShareALane() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [
                block("A", offsetHours: 1, hours: 2),
                block("B", offsetHours: 2, hours: 2)
            ],
            commitments: [],
            sessions: [session(offsetHours: 6, focused: 3_600)],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        let planned = ribbon.segments.filter { $0.kind == .planned }
        XCTAssertEqual(Set(planned.map(\.lane)).count, 2, "overlapping blocks must stack")

        let focusLanes = Set(ribbon.segments.filter { $0.kind == .focused }.map(\.lane))
        let plannedLanes = Set(planned.map(\.lane))
        XCTAssertTrue(
            focusLanes.isDisjoint(with: plannedLanes),
            "a focus session must never slot into a gap between blocks and read as one"
        )
    }

    func testZeroDurationFocusSessionsAreNotDrawnAsSpans() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [],
            commitments: [],
            sessions: [session(offsetHours: 1, focused: 0)],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertTrue(ribbon.segments.isEmpty)
        XCTAssertNil(ribbon.summary.focusedMinutes)
    }

    func testCompletionsOutsideTheWindowAreDropped() {
        let inside = DayCloseCompletionMark(
            id: UUID(),
            title: "Inside",
            completedAt: start.addingTimeInterval(3_600)
        )
        let outside = DayCloseCompletionMark(
            id: UUID(),
            title: "Outside",
            completedAt: end.addingTimeInterval(3_600)
        )

        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [],
            commitments: [],
            sessions: [],
            completions: [inside, outside],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertEqual(ribbon.completionMarks.map(\.title), ["Inside"])
        XCTAssertEqual(ribbon.summary.completedCount, 1)
    }

    func testPositionMapsIntoTheWindowAndRejectsStrayTimestamps() throws {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [],
            commitments: [],
            sessions: [],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end
        )

        XCTAssertEqual(ribbon.position(of: start), 0)
        XCTAssertEqual(ribbon.position(of: end), 1)
        XCTAssertEqual(try XCTUnwrap(ribbon.position(of: start.addingTimeInterval(6 * 3_600))), 0.5, accuracy: 0.001)
        XCTAssertNil(ribbon.position(of: start.addingTimeInterval(-60)))
        XCTAssertNil(ribbon.position(of: end.addingTimeInterval(60)))
    }

    func testAnUnreadableCalendarIsReportedRatherThanShownAsEmpty() {
        let ribbon = DayCloseRibbonBuilder.make(
            blocks: [block("Deep work", offsetHours: 1, hours: 1)],
            commitments: [],
            sessions: [],
            completions: [],
            unfinishedCount: 0,
            windowStart: start,
            windowEnd: end,
            externalCalendarUnavailable: true
        )

        // Absent data must never be reported as a confident value: no external
        // segments here means "we could not look", not "your calendar was clear".
        XCTAssertTrue(ribbon.externalCalendarUnavailable)
        XCTAssertFalse(ribbon.summary.hasNothingToReport)
    }
}
