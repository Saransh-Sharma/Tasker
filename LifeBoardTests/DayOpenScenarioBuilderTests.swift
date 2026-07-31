import XCTest
@testable import LifeBoard

/// The morning commitment: a proposal computed from last night, confirmed once.
final class DayOpenScenarioBuilderTests: XCTestCase {

    private let today = PlanningDay(year: 2026, month: 8, day: 1, timeZoneIdentifier: "Asia/Kolkata")
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    private func task(
        _ title: String,
        mustDo: Bool = false,
        availability: TaskAvailability = .actionable,
        disposition: UnscheduledDisposition = .inbox
    ) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            metadata: PlanningTaskMetadata(
                taskID: id,
                commitmentLevel: mustDo ? .mustDo : .standard,
                availability: availability,
                unscheduledDisposition: disposition,
                updatedAt: Date(timeIntervalSince1970: 500_000)
            )
        )
    }

    private func snapshot() -> PlanDaySnapshot {
        PlanDaySnapshot(
            day: today,
            capacity: CapacityBudget(
                workingDuration: 0, fixedCalendarDuration: 0, internalFixedDuration: 0,
                bufferDuration: 0, plannedEstimatedDuration: 0, missingEstimateCount: 0
            ),
            commitments: [], blocks: [], plannedTasks: [], unscheduledTasks: [], generatedAt: now
        )
    }

    // MARK: - The proposal

    func testTheAnchorLeadsTheProposal() {
        let anchor = task("Ship the thing")
        let others = (0..<4).map { task("Other \($0)") }

        let proposal = DayOpenScenarioBuilder.proposal(
            tasks: others + [anchor],
            anchorTaskID: anchor.id,
            day: today
        )

        // The only item chosen deliberately goes first, regardless of ordering
        // among everything that merely survived.
        XCTAssertEqual(proposal.first?.task.id, anchor.id)
        XCTAssertEqual(proposal.first?.origin, .anchor)
    }

    func testTheProposalIsCappedSoAgreeingIsNotAgreeingToABacklog() {
        let tasks = (0..<9).map { task("Task \($0)") }

        let proposal = DayOpenScenarioBuilder.proposal(tasks: tasks, anchorTaskID: nil, day: today)

        XCTAssertEqual(proposal.count, DayOpenScenarioBuilder.proposalLimit)
    }

    func testArchivedWaitingAndDeletedWorkIsNeverProposed() {
        let live = task("Live")
        let candidates = [
            live,
            task("Waiting", availability: .waiting),
            task("Released", disposition: .archived),
            task("Gone", disposition: .deleted)
        ]

        let proposal = DayOpenScenarioBuilder.proposal(tasks: candidates, anchorTaskID: nil, day: today)

        XCTAssertEqual(proposal.map(\.task.id), [live.id])
    }

    func testTheProposalIsStableAcrossRuns() {
        let tasks = (0..<6).map { task("Task \($0)") }

        let first = DayOpenScenarioBuilder.proposal(tasks: tasks, anchorTaskID: nil, day: today)
        let second = DayOpenScenarioBuilder.proposal(tasks: tasks.reversed(), anchorTaskID: nil, day: today)

        // Two runs of the same morning must propose the same day.
        XCTAssertEqual(first.map(\.task.id), second.map(\.task.id))
    }

    func testCarriedWorkOutranksStandingWork() {
        let standing = task("Standing")
        let carried = task("Carried")

        let proposal = DayOpenScenarioBuilder.proposal(
            tasks: [standing, carried],
            anchorTaskID: nil,
            carriedTaskIDs: [carried.id],
            day: today
        )

        XCTAssertEqual(proposal.first?.task.id, carried.id)
        XCTAssertEqual(proposal.first?.origin, .carried)
        XCTAssertEqual(proposal.last?.origin, .standing)
    }

    // MARK: - The commitment

    func testCommittingSetsTodayMustDoAndTheConfirmedOrder() {
        let first = task("First")
        let second = task("Second")

        let scenario = DayOpenScenarioBuilder.make(
            selected: [first, second],
            day: today,
            snapshot: snapshot(),
            now: now
        )

        XCTAssertEqual(scenario.source, .dayOpen)
        XCTAssertEqual(scenario.proposedMutations.count, 2)

        guard case let .saveTaskMetadata(_, after) = scenario.proposedMutations[0] else {
            return XCTFail("Expected metadata mutations")
        }
        XCTAssertEqual(after.planningDay, today)
        XCTAssertEqual(after.commitmentLevel, .mustDo)
        // Today opens reading the way it was confirmed.
        XCTAssertEqual(after.pinOrder, 0)
    }

    func testOneMutationPerTaskEvenIfSomethingIsSelectedTwice() {
        let repeated = task("Repeated")

        let scenario = DayOpenScenarioBuilder.make(
            selected: [repeated, repeated],
            day: today,
            snapshot: snapshot(),
            now: now
        )

        XCTAssertEqual(scenario.proposedMutations.count, 1)
        XCTAssertEqual(scenario.touchedRecords.count, 1)
    }

    func testADeliberatelyClearDayStillCommits() {
        let scenario = DayOpenScenarioBuilder.make(
            selected: [],
            day: today,
            snapshot: snapshot(),
            now: now
        )

        // A ledger that only records busy days would misreport the loop.
        XCTAssertTrue(scenario.isReadyToApply)
        XCTAssertTrue(scenario.proposedMutations.isEmpty)
        XCTAssertEqual(scenario.diff.first?.title, "Today stays open")
    }

    func testTheBatchInverseRestoresWhatTheMorningFound() {
        let carried = task("Carried", mustDo: false)

        let scenario = DayOpenScenarioBuilder.make(
            selected: [carried],
            day: today,
            snapshot: snapshot(),
            now: now
        )

        guard case let .batch(inverted) = PlanMutation.batch(scenario.proposedMutations).inverse,
              case let .saveTaskMetadata(_, restored) = inverted[0] else {
            return XCTFail("A batch must invert to a batch of metadata writes")
        }
        XCTAssertNil(restored.planningDay)
        XCTAssertEqual(restored.commitmentLevel, .standard)
        XCTAssertNil(restored.pinOrder)
    }

    func testTheReceiptSourceIsDayScopedAndDistinctFromTheClose() {
        XCTAssertEqual(
            DayOpenScenarioBuilder.receiptSource(for: today),
            "planning.scenario.dayOpen.2026-08-01"
        )
        // Distinct prefixes are what let the ledger count opens and closes apart.
        XCTAssertNotEqual(
            DayOpenScenarioBuilder.receiptSource(for: today),
            DayCloseScenarioBuilder.receiptSource(for: today)
        )
        XCTAssertTrue(
            DayOpenScenarioBuilder.receiptSource(for: today).hasPrefix(DayLoopLedger.openPrefix)
        )
    }
}
