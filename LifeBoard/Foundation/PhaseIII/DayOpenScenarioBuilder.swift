import Foundation

/// One candidate for today, in the order the morning should read it.
public struct DayOpenCandidate: Identifiable, Hashable, Sendable {
    public enum Origin: String, Codable, Hashable, Sendable {
        /// Named by last night's close as today's first thing.
        case anchor
        /// Carried into today by last night's reconciliation.
        case carried
        /// Already sitting on today for some other reason.
        case standing
    }

    public var id: UUID { task.id }
    public let task: PlanningTaskSummary
    public let origin: Origin

    public init(task: PlanningTaskSummary, origin: Origin) {
        self.task = task
        self.origin = origin
    }
}

/// Turns "yes, this is today" into one `PlanningScenario`.
///
/// The morning is a **confirmation**, not an authoring session: the proposal is
/// already computed from what the evening decided, and the primary action agrees
/// with it. Editing exists, but it is secondary — a person who is already moving
/// will not compose a day, and a screen that asks them to will be skipped until
/// it is deleted.
///
/// Mirrors `DayCloseScenarioBuilder` exactly so both ends of the loop produce
/// the same shape of record: one day-scoped `receiptSource`, one batch, one Undo.
public enum DayOpenScenarioBuilder {
    /// How many commitments a morning may propose.
    ///
    /// Three, not "everything that carried". A proposal long enough to need
    /// scrolling is a backlog, and agreeing to a backlog is not a commitment.
    public static let proposalLimit = 3

    public static func receiptSource(for day: PlanningDay) -> String {
        String(
            format: "planning.scenario.dayOpen.%04d-%02d-%02d",
            day.year,
            day.month,
            day.day
        )
    }

    /// Ranks what today could be.
    ///
    /// - The anchor first, always: it is the only item chosen deliberately.
    /// - Then already-promised work, then everything else, each by identifier so
    ///   two runs of the same morning propose the same day.
    public static func proposal(
        tasks: [PlanningTaskSummary],
        anchorTaskID: UUID?,
        carriedTaskIDs: Set<UUID> = [],
        day: PlanningDay,
        limit: Int = proposalLimit
    ) -> [DayOpenCandidate] {
        // Expanded rather than a single multi-clause predicate: chained boolean
        // filters over a collection have repeatedly blown the Swift
        // type-checker's budget in this target, and it manifests as a hanging
        // build rather than a clear error.
        var eligible: [PlanningTaskSummary] = []
        for task in tasks {
            guard task.metadata.availability == .actionable else { continue }
            let disposition = task.metadata.unscheduledDisposition
            guard disposition != .deleted, disposition != .archived else { continue }
            eligible.append(task)
        }

        var candidates: [DayOpenCandidate] = []
        if let anchorTaskID, let anchor = eligible.first(where: { $0.id == anchorTaskID }) {
            candidates.append(DayOpenCandidate(task: anchor, origin: .anchor))
        }

        let remaining = eligible
            .filter { $0.id != anchorTaskID }
            .sorted { lhs, rhs in
                let lhsCarried = carriedTaskIDs.contains(lhs.id)
                let rhsCarried = carriedTaskIDs.contains(rhs.id)
                if lhsCarried != rhsCarried { return lhsCarried }
                if lhs.metadata.commitmentLevel != rhs.metadata.commitmentLevel {
                    return lhs.metadata.commitmentLevel == .mustDo
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { task in
                DayOpenCandidate(
                    task: task,
                    origin: carriedTaskIDs.contains(task.id) ? .carried : .standing
                )
            }

        candidates.append(contentsOf: remaining)
        return Array(candidates.prefix(max(0, limit)))
    }

    /// Builds the commitment.
    ///
    /// - Parameters:
    ///   - selected: what the person agreed to, in display order. `pinOrder`
    ///     follows that order so today opens reading the way it was confirmed.
    ///   - day: today.
    public static func make(
        selected: [PlanningTaskSummary],
        day: PlanningDay,
        snapshot: PlanDaySnapshot,
        now: Date = Date()
    ) -> PlanningScenario {
        // Deduplicated defensively: the same one-mutation-per-task invariant the
        // close builder holds, for the same reason — a legible diff and a single
        // touched record per row.
        var seen: Set<UUID> = []
        let ordered = selected.filter { seen.insert($0.id).inserted }

        let mutations: [PlanMutation] = ordered.enumerated().map { index, task in
            var after = task.metadata
            after.planningDay = day
            after.commitmentLevel = .mustDo
            after.pinOrder = index
            after.unscheduledDisposition = .inbox
            after.updatedAt = now
            return .saveTaskMetadata(before: task.metadata, after: after)
        }

        var preview = snapshot
        let selectedIDs = Set(ordered.map(\.id))
        preview.unscheduledTasks.removeAll { selectedIDs.contains($0.id) }
        preview.plannedTasks.append(contentsOf: ordered.map { task in
            var copy = task
            copy.metadata.planningDay = day
            copy.metadata.commitmentLevel = .mustDo
            return copy
        })

        return PlanningScenario(
            source: .dayOpen,
            receiptSource: receiptSource(for: day),
            touchedRecords: ordered.map {
                PlanningTouchedRecord(kind: "task", recordID: $0.id, version: $0.metadata.updatedAt)
            },
            proposedMutations: mutations,
            diff: diff(for: ordered),
            preview: preview,
            // A morning may be committed to as-is, including empty. Refusing to
            // record an intentionally clear day would mean the ledger only ever
            // remembers busy ones.
            validationIssues: [],
            createdAt: now
        )
    }

    private static func diff(for tasks: [PlanningTaskSummary]) -> [PlanningScenarioDiff] {
        guard tasks.isEmpty == false else {
            return [PlanningScenarioDiff(title: "Today stays open", after: "Nothing committed")]
        }
        return [
            PlanningScenarioDiff(
                title: tasks.count == 1 ? "1 thing for today" : "\(tasks.count) things for today",
                after: tasks.map(\.title).joined(separator: ", ")
            )
        ]
    }
}
