import Foundation

/// Turns a set of end-of-day decisions into **one** `PlanningScenario`.
///
/// Deliberately pure and deliberately whole-batch. The alternative — writing each
/// card as it is swiped — was rejected for two reasons. It would produce N
/// receipts for one act, so Undo would unwind the day one card at a time and the
/// person would have to remember how many they had touched. And it would commit
/// before the ritual reached the moment where closing is actually agreed to,
/// which means backing out of Close the Day would silently leave half a
/// reconciliation applied.
///
/// Atomicity comes free from the existing ledger: `DefaultPlanningScenarioCoordinator`
/// wraps `proposedMutations` in a single `.batch`, `apply(receiptID:)` runs it
/// inside one Core Data `write`, and `PlanMutation.batch.inverse` reverses the
/// order. N cards in, one receipt out, one Undo.
public enum DayCloseScenarioBuilder {
    /// Builds the reconciliation.
    ///
    /// - Parameters:
    ///   - decisions: Resolved cards, keyed by task. Undecided tasks are simply
    ///     absent — a day may close with anything still undecided.
    ///   - anchorTaskID: Tomorrow's first thing, if one was named. May or may not
    ///     also appear in `decisions`; see the folding rule below.
    ///   - tasks: Every task either decision or anchor can refer to.
    ///   - snapshot: Today, used only to build the preview.
    ///   - tomorrow: Resolved by the caller, which owns the calendar and time zone.
    public static func make(
        decisions: [DayCloseDecision],
        anchorTaskID: UUID?,
        tasks: [PlanningTaskSummary],
        snapshot: PlanDaySnapshot,
        tomorrow: PlanningDay,
        now: Date = Date()
    ) -> PlanningScenario {
        let tasksByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Later decisions win. The deck only ever records one decision per card,
        // but "bring back the last card" plus a re-swipe can produce two entries
        // for the same task, and the newer one is the one the person saw.
        var resolved: [UUID: DayCloseDecision] = [:]
        for decision in decisions.sorted(by: { $0.decidedAt < $1.decidedAt }) {
            guard tasksByID[decision.taskID] != nil else { continue }
            resolved[decision.taskID] = decision
        }

        // The anchor is only meaningful on a task that will still exist tomorrow.
        // Anchoring something released or filed to someday would contradict the
        // decision made three cards earlier, so the anchor loses.
        let anchor: UUID? = anchorTaskID.flatMap { id in
            guard tasksByID[id] != nil else { return nil }
            switch resolved[id]?.direction {
            case .someday, .doneAnyway, .release: return nil
            case .tomorrow, .none: return id
            }
        }

        // One mutation per task, always. The anchor folds into an existing
        // `.tomorrow` decision rather than appending a second `.saveTaskMetadata`
        // for the same row: two mutations would still invert correctly, but they
        // would produce two diff lines and two `PlanningTouchedRecord`s for one
        // task, and the version check would then compare that task against itself.
        var mutations: [UUID: PlanMutation] = [:]
        var touched: [UUID: PlanningTouchedRecord] = [:]

        for (taskID, decision) in resolved {
            guard let task = tasksByID[taskID] else { continue }
            touched[taskID] = PlanningTouchedRecord(
                kind: "task",
                recordID: taskID,
                version: task.metadata.updatedAt
            )
            switch decision.direction {
            case .doneAnyway:
                mutations[taskID] = .setTaskCompletion(taskID: taskID, before: false, after: true)
            case .tomorrow, .someday, .release:
                var after = task.metadata
                apply(decision.direction, to: &after, tomorrow: tomorrow)
                if anchor == taskID { applyAnchor(to: &after, tomorrow: tomorrow) }
                after.updatedAt = now
                mutations[taskID] = .saveTaskMetadata(before: task.metadata, after: after)
            }
        }

        if let anchor, mutations[anchor] == nil, let task = tasksByID[anchor] {
            var after = task.metadata
            applyAnchor(to: &after, tomorrow: tomorrow)
            after.updatedAt = now
            mutations[anchor] = .saveTaskMetadata(before: task.metadata, after: after)
            touched[anchor] = PlanningTouchedRecord(
                kind: "task",
                recordID: anchor,
                version: task.metadata.updatedAt
            )
        }

        // Sorted so the receipt, the diff and the version check are byte-stable
        // across runs; dictionary order is not.
        let orderedIDs = mutations.keys.sorted { $0.uuidString < $1.uuidString }

        return PlanningScenario(
            source: .dayClose,
            receiptSource: receiptSource(for: snapshot.day),
            touchedRecords: orderedIDs.compactMap { touched[$0] },
            proposedMutations: orderedIDs.compactMap { mutations[$0] },
            diff: diff(resolved: resolved, anchor: anchor, tasksByID: tasksByID),
            preview: preview(snapshot: snapshot, resolved: resolved, anchor: anchor),
            // Always empty. A day is allowed to end in any condition, including
            // with nothing decided — there is no state of the day that should
            // block a person from closing it.
            validationIssues: [],
            createdAt: now
        )
    }

    /// Day-scoped so `hasAppliedReceipt(source:)` answers "was *this* day closed?"
    /// and cannot leak across days. This string is the entire persistence story
    /// for the ritual — see `DayCloseStore`.
    public static func receiptSource(for day: PlanningDay) -> String {
        String(
            format: "planning.scenario.dayClose.%04d-%02d-%02d",
            day.year,
            day.month,
            day.day
        )
    }

    // MARK: - Field application

    private static func apply(
        _ direction: DayCloseDirection,
        to metadata: inout PlanningTaskMetadata,
        tomorrow: PlanningDay
    ) {
        switch direction {
        case .tomorrow:
            metadata.planningDay = tomorrow
            // Deliberately does not clear `startDay`: a task that could not begin
            // until Thursday still cannot begin until Thursday just because it
            // was carried.
            metadata.unscheduledDisposition = .inbox
        case .someday:
            metadata.planningDay = nil
            metadata.unscheduledDisposition = .someday
            // Carrying a "must do" into an undated pile would keep it shouting
            // from the backlog forever.
            metadata.commitmentLevel = .standard
            metadata.pinOrder = nil
        case .release:
            metadata.planningDay = nil
            // `.archived`, never `.deleted`. "Let it go" means kept and never
            // chased; `.deleted` is a sync tombstone that every projection treats
            // as removed, which would make the copy a lie and lose the record.
            metadata.unscheduledDisposition = .archived
            metadata.commitmentLevel = .standard
            metadata.pinOrder = nil
        case .doneAnyway:
            break
        }
    }

    private static func applyAnchor(to metadata: inout PlanningTaskMetadata, tomorrow: PlanningDay) {
        metadata.planningDay = tomorrow
        metadata.commitmentLevel = .mustDo
        metadata.pinOrder = 0
        metadata.unscheduledDisposition = .inbox
    }

    // MARK: - Diff

    /// One row per direction that was actually used, plus the anchor. Grouped
    /// rather than per-task so a twelve-card reconciliation still previews as
    /// four readable lines.
    private static func diff(
        resolved: [UUID: DayCloseDecision],
        anchor: UUID?,
        tasksByID: [UUID: PlanningTaskSummary]
    ) -> [PlanningScenarioDiff] {
        var rows: [PlanningScenarioDiff] = DayCloseDirection.allCases.compactMap { direction in
            let titles = resolved.values
                .filter { $0.direction == direction }
                .compactMap { tasksByID[$0.taskID]?.title }
                .sorted()
            guard titles.isEmpty == false else { return nil }
            return PlanningScenarioDiff(
                title: "\(titles.count) \(direction.summaryVerb)",
                after: titles.joined(separator: ", ")
            )
        }
        if let anchor, let task = tasksByID[anchor] {
            rows.append(
                PlanningScenarioDiff(title: "Tomorrow starts with", after: task.title)
            )
        }
        return rows
    }

    // MARK: - Preview

    private static func preview(
        snapshot: PlanDaySnapshot,
        resolved: [UUID: DayCloseDecision],
        anchor: UUID?
    ) -> PlanDaySnapshot {
        var preview = snapshot
        // Everything decided leaves today's plan, including "already done" —
        // today's list is what remains open, and a completed task is not that.
        preview.plannedTasks.removeAll { resolved[$0.id] != nil }
        preview.unscheduledTasks.removeAll { resolved[$0.id] != nil }
        if let anchor {
            preview.plannedTasks.removeAll { $0.id == anchor }
            preview.unscheduledTasks.removeAll { $0.id == anchor }
        }
        return preview
    }
}

/// Assembles the retrospective. Pure, so the ribbon's honesty rules are testable
/// without a renderer.
public enum DayCloseRibbonBuilder {
    public static func make(
        blocks: [InternalTimeBlock],
        commitments: [PlanningFixedCommitment],
        sessions: [FocusExecutionReceipt],
        completions: [DayCloseCompletionMark],
        unfinishedCount: Int,
        windowStart: Date,
        windowEnd: Date,
        externalCalendarUnavailable: Bool = false
    ) -> DayCloseRibbon {
        let window = DateInterval(
            start: windowStart,
            end: max(windowEnd, windowStart)
        )

        let plannedSegments = blocks
            .filter { overlaps($0.startAt, $0.endAt, window) }
            .map {
                DayCloseRibbonSegment(
                    id: "block.\($0.id.uuidString)",
                    title: $0.title,
                    kind: .planned,
                    startAt: $0.startAt,
                    endAt: $0.endAt
                )
            }

        // External events only. `.internalBlock` commitments are the same rows as
        // `blocks` seen through the capacity lens, and drawing both would double
        // every authored block on the ribbon.
        let commitmentSegments = commitments
            .filter { $0.source == .externalCalendar && overlaps($0.startAt, $0.endAt, window) }
            .map {
                DayCloseRibbonSegment(
                    id: "commitment.\($0.id)",
                    title: $0.title,
                    kind: .commitment,
                    startAt: $0.startAt,
                    endAt: $0.endAt
                )
            }

        // A session with no measured focus is not a span. Drawing it as a
        // zero-width mark would claim time that was never spent.
        let focusSegments = sessions
            .filter { $0.actualFocusedDuration > 0 && overlaps($0.startedAt, $0.endedAt, window) }
            .map {
                DayCloseRibbonSegment(
                    id: "focus.\($0.id.uuidString)",
                    title: "Focus",
                    kind: .focused,
                    startAt: $0.startedAt,
                    endAt: $0.endedAt
                )
            }

        let segments = assignLanes(plannedSegments + commitmentSegments + focusSegments)

        let plannedMinutes: Int? = {
            let total = (plannedSegments + commitmentSegments).reduce(0) { $0 + $1.duration }
            // `nil`, never 0. "Nothing was planned" and "everything planned was
            // missed" are different facts, and only the ring knows which to draw.
            guard total > 0 else { return nil }
            return Int((total / 60).rounded())
        }()

        let focusedMinutes: Int? = {
            let total = sessions.reduce(0) { $0 + $1.actualFocusedDuration }
            guard total > 0 else { return nil }
            return Int((total / 60).rounded())
        }()

        return DayCloseRibbon(
            segments: segments,
            completionMarks: completions
                .filter { window.contains($0.completedAt) }
                .sorted { $0.completedAt < $1.completedAt },
            summary: DayCloseRingSummary(
                plannedMinutes: plannedMinutes,
                focusedMinutes: focusedMinutes,
                completedCount: completions.filter { window.contains($0.completedAt) }.count,
                unfinishedCount: unfinishedCount
            ),
            windowStart: window.start,
            windowEnd: window.end,
            externalCalendarUnavailable: externalCalendarUnavailable
        )
    }

    private static func overlaps(_ start: Date, _ end: Date, _ window: DateInterval) -> Bool {
        max(start, window.start) < min(end, window.end)
            || (start == end && window.contains(start))
    }

    /// First-fit lane packing, per kind.
    ///
    /// Kinds never share a lane: the ribbon reads as three stacked tracks, so a
    /// meeting must not slot into a gap between two focus sessions and imply it
    /// was one. Within a kind, overlapping spans stack.
    private static func assignLanes(_ segments: [DayCloseRibbonSegment]) -> [DayCloseRibbonSegment] {
        var laneEnds: [Date] = []
        var laneKinds: [DayCloseRibbonSegment.Kind] = []
        var result: [DayCloseRibbonSegment] = []

        for segment in segments.sorted(by: sortOrder) {
            let index = laneEnds.indices.first { index in
                laneKinds[index] == segment.kind && laneEnds[index] <= segment.startAt
            }
            var placed = segment
            if let index {
                placed.lane = index
                laneEnds[index] = segment.endAt
            } else {
                placed.lane = laneEnds.count
                laneEnds.append(segment.endAt)
                laneKinds.append(segment.kind)
            }
            result.append(placed)
        }
        return result
    }

    private static func sortOrder(_ lhs: DayCloseRibbonSegment, _ rhs: DayCloseRibbonSegment) -> Bool {
        if lhs.kind != rhs.kind { return kindRank(lhs.kind) < kindRank(rhs.kind) }
        if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
        return lhs.id < rhs.id
    }

    private static func kindRank(_ kind: DayCloseRibbonSegment.Kind) -> Int {
        switch kind {
        case .commitment: 0
        case .planned: 1
        case .focused: 2
        }
    }
}
