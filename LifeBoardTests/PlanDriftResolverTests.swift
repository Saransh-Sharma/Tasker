import XCTest
@testable import LifeBoard

/// The one definition of plan drift, and the rule for when it is worth
/// surfacing. Plan and Home both read these, so a disagreement here is a
/// disagreement between two screens the person sees minutes apart.
final class PlanDriftResolverTests: XCTestCase {

    private let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")

    /// Noon, with everything else expressed as an offset from it.
    private let now = Date(timeIntervalSince1970: 100_000)

    private func snapshot(
        blocks: [InternalTimeBlock],
        plannedTasks: [PlanningTaskSummary],
        plannedEstimatedDuration: TimeInterval = 0,
        workingDuration: TimeInterval = 28_800
    ) -> PlanDaySnapshot {
        PlanDaySnapshot(
            day: day,
            capacity: CapacityBudget(
                workingDuration: workingDuration,
                fixedCalendarDuration: 0,
                internalFixedDuration: 0,
                bufferDuration: 0,
                plannedEstimatedDuration: plannedEstimatedDuration,
                missingEstimateCount: 0
            ),
            commitments: [],
            blocks: blocks,
            plannedTasks: plannedTasks,
            unscheduledTasks: [],
            generatedAt: now
        )
    }

    private func task(_ id: UUID, title: String = "Work") -> PlanningTaskSummary {
        PlanningTaskSummary(id: id, title: title, metadata: .init(taskID: id))
    }

    /// A block ending `secondsAgo` before `now`.
    private func block(taskID: UUID?, endedSecondsAgo: TimeInterval, title: String = "Block") -> InternalTimeBlock {
        let end = now.addingTimeInterval(-endedSecondsAgo)
        return InternalTimeBlock(
            title: title,
            startAt: end.addingTimeInterval(-3_600),
            endAt: end,
            taskID: taskID
        )
    }

    // MARK: - The predicate

    func testABlockThatHasNotEndedIsNotDrift() {
        let id = UUID()
        // Still running: it ends an hour from now.
        let running = block(taskID: id, endedSecondsAgo: -3_600)
        let drift = PlanDriftResolver.drift(
            in: snapshot(blocks: [running], plannedTasks: [task(id)]),
            now: now
        )
        XCTAssertTrue(drift.isEmpty, "Work still inside its window has not drifted")
    }

    func testAnEndedBlockWhoseTaskLeftThePlanIsNotDrift() {
        let id = UUID()
        // Completing a task removes it from `plannedTasks`. That is the only
        // signal available that the work is done, and it must not read as drift.
        let drift = PlanDriftResolver.drift(
            in: snapshot(blocks: [block(taskID: id, endedSecondsAgo: 3_600)], plannedTasks: []),
            now: now
        )
        XCTAssertTrue(drift.isEmpty, "A task no longer planned is finished, not drifted")
    }

    func testABlockWithNoTaskIsNotDrift() {
        // A calendar commitment or a held window. Nothing about it can be
        // repaired, so counting it would push the spine into `.repair` over a
        // meeting that simply happened.
        let drift = PlanDriftResolver.drift(
            in: snapshot(blocks: [block(taskID: nil, endedSecondsAgo: 3_600)], plannedTasks: []),
            now: now
        )
        XCTAssertTrue(drift.isEmpty)
    }

    func testDriftIsOrderedByWhenTheBlockEnded() {
        let first = UUID()
        let second = UUID()
        let older = block(taskID: first, endedSecondsAgo: 7_200, title: "Older")
        let newer = block(taskID: second, endedSecondsAgo: 1_800, title: "Newer")
        let drift = PlanDriftResolver.drift(
            // Deliberately supplied newest-first so the sort is doing the work.
            in: snapshot(blocks: [newer, older], plannedTasks: [task(first), task(second)]),
            now: now
        )
        XCTAssertEqual(drift.driftedBlockIDs, [older.id, newer.id])
        XCTAssertEqual(drift.driftedTaskIDs, [first, second])
    }

    func testATaskPlannedIntoTwoDriftedBlocksIsCountedOnce() {
        let id = UUID()
        let morning = block(taskID: id, endedSecondsAgo: 7_200, title: "Morning")
        let afternoon = block(taskID: id, endedSecondsAgo: 1_800, title: "Afternoon")
        let drift = PlanDriftResolver.drift(
            in: snapshot(blocks: [morning, afternoon], plannedTasks: [task(id)]),
            now: now
        )
        XCTAssertEqual(drift.driftedBlockIDs.count, 2)
        XCTAssertEqual(drift.driftedTaskIDs, [id], "One piece of work to think about, not two")
    }

    // MARK: - Agreement with the repair service

    func testDriftMatchesDeterministicPlanRepairServiceMissedWork() {
        // The reason this file exists. If these two ever disagree, Home shows
        // "worth a look" over a Plan screen with nothing to repair, or the
        // reverse — and neither surface can be trusted.
        let planned = UUID()
        let finished = UUID()
        let fixture = snapshot(
            blocks: [
                block(taskID: planned, endedSecondsAgo: 7_200, title: "Drifted"),
                block(taskID: finished, endedSecondsAgo: 3_600, title: "Completed"),
                block(taskID: nil, endedSecondsAgo: 1_800, title: "Meeting"),
                block(taskID: planned, endedSecondsAgo: -3_600, title: "Upcoming")
            ],
            plannedTasks: [task(planned)]
        )

        let serviceBlockIDs = Set(
            DeterministicPlanRepairService()
                .proposals(for: fixture, now: now)
                .filter { $0.trigger == .missedPlannedWork }
                .compactMap(\.timeBlockID)
        )
        let resolverBlockIDs = Set(PlanDriftResolver.drift(in: fixture, now: now).driftedBlockIDs)

        XCTAssertEqual(resolverBlockIDs, serviceBlockIDs)
        XCTAssertEqual(resolverBlockIDs.count, 1)
    }

    func testDriftIgnoresOverloadedCapacity() {
        // The repair service also proposes `.overloadedWindow` when estimates
        // exceed capacity. That is a statement about the shape of the day, not
        // about time having passed — counting it would flip the spine into
        // `.repair` on a busy day that is entirely on track.
        let overloaded = snapshot(
            blocks: [],
            plannedTasks: [],
            plannedEstimatedDuration: 36_000,
            workingDuration: 3_600
        )
        let proposals = DeterministicPlanRepairService().proposals(for: overloaded, now: now)

        XCTAssertEqual(proposals.map(\.trigger), [.overloadedWindow], "Fixture must actually overload")
        XCTAssertTrue(PlanDriftResolver.drift(in: overloaded, now: now).isEmpty)
        XCTAssertEqual(
            PlanDriftPolicy.default.surfacedCount(proposals: proposals, in: overloaded, now: now),
            0
        )
    }

    // MARK: - The surfacing policy

    private func proposals(for snapshot: PlanDaySnapshot) -> [PlanRepairProposal] {
        DeterministicPlanRepairService().proposals(for: snapshot, now: now)
    }

    func testPolicySurfacesOnlyAtOrAboveTheThreshold() {
        // One thing slipping is a normal day.
        let single = UUID()
        let oneDrifted = snapshot(
            blocks: [block(taskID: single, endedSecondsAgo: 3_600)],
            plannedTasks: [task(single)]
        )
        XCTAssertEqual(
            PlanDriftPolicy.default.surfacedCount(proposals: proposals(for: oneDrifted), in: oneDrifted, now: now),
            0,
            "A single slipped block must not interrupt anyone"
        )

        let first = UUID()
        let second = UUID()
        let twoDrifted = snapshot(
            blocks: [
                block(taskID: first, endedSecondsAgo: 7_200),
                block(taskID: second, endedSecondsAgo: 3_600)
            ],
            plannedTasks: [task(first), task(second)]
        )
        XCTAssertEqual(
            PlanDriftPolicy.default.surfacedCount(proposals: proposals(for: twoDrifted), in: twoDrifted, now: now),
            2
        )
    }

    func testPolicyIgnoresProposalsThatAreNotMissedPlannedWork() {
        let id = UUID()
        let mixed = snapshot(
            blocks: [
                block(taskID: id, endedSecondsAgo: 7_200),
                block(taskID: nil, endedSecondsAgo: 3_600)
            ],
            plannedTasks: [task(id)],
            plannedEstimatedDuration: 36_000,
            workingDuration: 3_600
        )
        let all = proposals(for: mixed)
        XCTAssertTrue(all.contains { $0.trigger == .overloadedWindow }, "Fixture must include a non-drift proposal")

        // One real drift + one overload must not clear a threshold of 2.
        XCTAssertEqual(PlanDriftPolicy.default.surfacedCount(proposals: all, in: mixed, now: now), 0)
    }

    func testABlockThatEndedMomentsAgoIsNotYetDrift() {
        // Without the age gate the spine flips to `.repair` at the exact second
        // a block's end passes — the stage would change while the person is
        // looking at it.
        let first = UUID()
        let second = UUID()
        let justPassed = snapshot(
            blocks: [
                block(taskID: first, endedSecondsAgo: 60),
                block(taskID: second, endedSecondsAgo: 120)
            ],
            plannedTasks: [task(first), task(second)]
        )
        let all = proposals(for: justPassed)

        XCTAssertEqual(all.filter { $0.trigger == .missedPlannedWork }.count, 2, "Both are drift by the predicate")
        XCTAssertEqual(
            PlanDriftPolicy.default.surfacedCount(proposals: all, in: justPassed, now: now),
            0,
            "…but neither is old enough to surface"
        )
    }

    func testAProposalWhoseBlockLeftTheSnapshotIsNotAged() {
        // We cannot age what we cannot see, and assuming "old" would surface a
        // repair for a block that no longer exists.
        let first = UUID()
        let second = UUID()
        let present = snapshot(
            blocks: [
                block(taskID: first, endedSecondsAgo: 7_200),
                block(taskID: second, endedSecondsAgo: 3_600)
            ],
            plannedTasks: [task(first), task(second)]
        )
        let all = proposals(for: present)
        let emptied = snapshot(blocks: [], plannedTasks: [task(first), task(second)])

        XCTAssertEqual(PlanDriftPolicy.default.surfacedCount(proposals: all, in: emptied, now: now), 0)
    }
}
