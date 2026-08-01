import Foundation

/// What has drifted on a day, and which records it came from.
///
/// Drift is a *fact about the plan*, not a judgement about the person. It says
/// only that time passed a block whose task is still open — never that the work
/// is late, missed, or owed.
public struct PlanDrift: Equatable, Sendable {
    /// Ordered by when the block ended, then by id so equal ends stay stable.
    public var driftedBlockIDs: [UUID]
    /// Same order as `driftedBlockIDs`. A task planned into two drifted blocks
    /// appears once — the person has one piece of work to think about, not two.
    public var driftedTaskIDs: [UUID]

    public init(driftedBlockIDs: [UUID] = [], driftedTaskIDs: [UUID] = []) {
        self.driftedBlockIDs = driftedBlockIDs
        self.driftedTaskIDs = driftedTaskIDs
    }

    public var count: Int { driftedBlockIDs.count }
    public var isEmpty: Bool { driftedBlockIDs.isEmpty }
}

/// The single definition of plan drift, shared by Plan and Home.
///
/// This exists so the two surfaces cannot disagree. `DeterministicPlanRepairService`
/// owned the rule inline, and Home needed the same rule to decide whether the
/// loop is in `.repair`. Two copies of a predicate this quiet would drift apart
/// silently — a spine that says "worth a look" over a Plan screen with nothing
/// to repair, or the reverse.
///
/// Deliberately *not* the same thing as the repair service's whole output: that
/// also proposes `.overloadedWindow` when estimates exceed capacity, which is a
/// statement about the shape of the day, not about time having passed. Counting
/// it as drift would push the spine into `.repair` on a busy-but-on-track day.
public enum PlanDriftResolver {
    /// The one drift rule: a planned block whose end has passed while its task
    /// is still on the day's planned list.
    ///
    /// "Still planned" is the honest proxy for "unstarted or unfinished" —
    /// completing a task removes it from `plannedTasks`, so anything remaining
    /// is work the day still expects. There is no "started" flag on a task to
    /// consult; a focus session is evidence of a start, but a session that ran
    /// and stopped without finishing the work is still drift.
    ///
    /// Returns blocks in `snapshot.blocks` order, which is what the repair
    /// service iterates. Callers wanting a stable order should use `drift(in:now:)`.
    public static func driftedBlocks(
        in snapshot: PlanDaySnapshot,
        now: Date
    ) -> [(block: InternalTimeBlock, taskID: UUID)] {
        // An explicit loop rather than a filter/compactMap chain: chained
        // collection expressions have repeatedly blown the type-checker's
        // budget in this target, and the failure mode is a hanging build.
        var drifted: [(block: InternalTimeBlock, taskID: UUID)] = []
        for block in snapshot.blocks where block.endAt < now {
            // A block with no task is a calendar commitment or a held window,
            // not work that can drift.
            guard let taskID = block.taskID else { continue }
            guard snapshot.plannedTasks.contains(where: { $0.id == taskID }) else { continue }
            drifted.append((block: block, taskID: taskID))
        }
        return drifted
    }

    /// The same rule, in a stable order, with tasks de-duplicated.
    public static func drift(in snapshot: PlanDaySnapshot, now: Date) -> PlanDrift {
        let drifted = driftedBlocks(in: snapshot, now: now).sorted { lhs, rhs in
            if lhs.block.endAt != rhs.block.endAt { return lhs.block.endAt < rhs.block.endAt }
            return lhs.block.id.uuidString < rhs.block.id.uuidString
        }

        var blockIDs: [UUID] = []
        var taskIDs: [UUID] = []
        var seenTasks: Set<UUID> = []
        for entry in drifted {
            blockIDs.append(entry.block.id)
            if seenTasks.insert(entry.taskID).inserted {
                taskIDs.append(entry.taskID)
            }
        }
        return PlanDrift(driftedBlockIDs: blockIDs, driftedTaskIDs: taskIDs)
    }
}

/// When drift is worth interrupting someone about.
///
/// The repair stage is the one beat of the loop most at risk of feeling like
/// nagging — it is the only stage that asks something extra of a day that is
/// already not going to plan. So the rule for *surfacing* it is deliberately
/// separate from the rule for *detecting* it, and lives here where it can be
/// tuned without touching either the predicate or the stage machine.
public struct PlanDriftPolicy: Equatable, Sendable {
    /// One thing slipping is a normal day. Two is a shape worth looking at.
    public static let `default` = PlanDriftPolicy(
        minimumDriftToSurface: 2,
        minimumAge: 15 * 60
    )

    public var minimumDriftToSurface: Int
    /// How long a block must have been past before it counts.
    ///
    /// Without this the spine flips to `.repair` at the exact second a block's
    /// end time passes — the stage would change while the person is looking at
    /// it, which reads as a stopwatch rather than an observation.
    public var minimumAge: TimeInterval

    public init(minimumDriftToSurface: Int, minimumAge: TimeInterval) {
        self.minimumDriftToSurface = max(1, minimumDriftToSurface)
        self.minimumAge = max(0, minimumAge)
    }

    /// How much drift to surface, given proposals that have already had the
    /// person's acknowledgements filtered out.
    ///
    /// Takes proposals rather than a raw snapshot on purpose: `PlanStore`
    /// removes repairs the person already resolved, and resolving one via
    /// "leave today as it is" writes a receipt *without* changing the snapshot.
    /// Recomputing from the snapshot would resurface a dismissed repair forever.
    ///
    /// The snapshot comes in too, but only to age the proposals — a proposal
    /// carries `createdAt` (when it was generated, i.e. now) rather than when
    /// its block ended, so the block is the only place the age can come from.
    /// A proposal whose block is no longer in the snapshot is dropped rather
    /// than assumed old: we cannot age what we cannot see.
    public func surfacedCount(
        proposals: [PlanRepairProposal],
        in snapshot: PlanDaySnapshot,
        now: Date
    ) -> Int {
        var blockEnds: [UUID: Date] = [:]
        for block in snapshot.blocks { blockEnds[block.id] = block.endAt }

        var surfaced = 0
        for proposal in proposals where proposal.trigger == .missedPlannedWork {
            guard let blockID = proposal.timeBlockID, let endAt = blockEnds[blockID] else { continue }
            guard now.timeIntervalSince(endAt) >= minimumAge else { continue }
            surfaced += 1
        }
        return surfaced >= minimumDriftToSurface ? surfaced : 0
    }
}
