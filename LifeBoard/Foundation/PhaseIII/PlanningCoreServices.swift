import Foundation

public struct DefaultPlanningDayResolver: PlanningDayResolver {
    public init() {}

    public func resolve(
        _ day: PlanningDay,
        in destinationTimeZone: TimeZone,
        policy: PlanningDayTravelPolicy,
        calendar: Calendar = .current
    ) -> PlanningDay {
        switch policy {
        case .preserveIntendedDay:
            return PlanningDay(
                year: day.year,
                month: day.month,
                day: day.day,
                timeZoneIdentifier: day.timeZoneIdentifier
            )
        case .followAbsoluteDate:
            guard let absoluteStart = day.startDate(calendar: calendar) else { return day }
            return PlanningDay(date: absoluteStart, timeZone: destinationTimeZone, calendar: calendar)
        }
    }
}

public enum FreeWindowService {
    public static func calculate(
        workingIntervals: [DateInterval],
        occupiedIntervals: [DateInterval],
        minimumDuration: TimeInterval = 15 * 60
    ) -> [FreeWindow] {
        let minimumDuration = max(0, minimumDuration)
        let mergedOccupied = merge(occupiedIntervals)
        return merge(workingIntervals).flatMap { work -> [FreeWindow] in
            var cursor = work.start
            var windows: [FreeWindow] = []
            for occupied in mergedOccupied where occupied.end > work.start && occupied.start < work.end {
                let busyStart = max(work.start, occupied.start)
                let busyEnd = min(work.end, occupied.end)
                if busyStart.timeIntervalSince(cursor) >= minimumDuration {
                    windows.append(FreeWindow(startAt: cursor, endAt: busyStart))
                }
                cursor = max(cursor, busyEnd)
                if cursor >= work.end { break }
            }
            if work.end.timeIntervalSince(cursor) >= minimumDuration {
                windows.append(FreeWindow(startAt: cursor, endAt: work.end))
            }
            return windows
        }
    }

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }
        var result: [DateInterval] = []
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                result.append(current)
                current = interval
            }
        }
        result.append(current)
        return result
    }
}

public enum CapacityBudgetService {
    public static func calculate(
        workingIntervals: [DateInterval],
        fixedCalendarCommitments: [DateInterval],
        internalFixedBlocks: [DateInterval],
        userBuffer: TimeInterval,
        plannedEstimates: [TimeInterval?]
    ) -> CapacityBudget {
        let working = unionDuration(workingIntervals)
        let fixedCalendar = clippedUnionDuration(fixedCalendarCommitments, within: workingIntervals)
        let allBusy = clippedUnionDuration(fixedCalendarCommitments + internalFixedBlocks, within: workingIntervals)
        // Calendar context and LifeBoard blocks can overlap. Capacity pays for that
        // occupied time once while retaining an explainable category breakdown.
        let internalFixed = max(0, allBusy - fixedCalendar)
        return CapacityBudget(
            workingDuration: working,
            fixedCalendarDuration: fixedCalendar,
            internalFixedDuration: internalFixed,
            bufferDuration: userBuffer,
            plannedEstimatedDuration: plannedEstimates.compactMap { $0 }.reduce(0, +),
            missingEstimateCount: plannedEstimates.filter { $0 == nil }.count
        )
    }

    private static func clippedUnionDuration(_ intervals: [DateInterval], within working: [DateInterval]) -> TimeInterval {
        let clipped = intervals.flatMap { interval in
            working.compactMap { work -> DateInterval? in
                let start = max(interval.start, work.start)
                let end = min(interval.end, work.end)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
        }
        return unionDuration(clipped)
    }

    private static func unionDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var duration: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                duration += current.duration
                current = interval
            }
        }
        return duration + current.duration
    }
}

public struct DeterministicFocusRankingService: FocusRankingService {
    public init() {}

    public func rank(_ candidates: [FocusRankCandidate], context: FocusRankContext) -> [FocusRankResult] {
        let scored = candidates.map { candidate in
            (candidate: candidate, result: result(for: candidate, context: context))
        }
        return scored.sorted { lhs, rhs in
            compare(lhs, rhs, context: context)
        }.map(\.result)
    }

    private func result(for candidate: FocusRankCandidate, context: FocusRankContext) -> FocusRankResult {
        var exclusions: [FocusEligibilityExclusion] = []
        if candidate.isCompleted { exclusions.append(.completed) }
        if candidate.availability == .waiting { exclusions.append(.waiting) }
        if candidate.availability == .paused { exclusions.append(.paused) }
        if candidate.dependenciesReady == false { exclusions.append(.dependencyBlocked) }

        var missing: [String] = []
        let urgency = urgencyScore(dueDate: candidate.dueDate, now: context.now)
        let priority = candidate.commitmentLevel == .mustDo ? 20 : priorityScore(candidate.priority)

        let freeWindowFit: Int
        let durationFit: Int
        switch (candidate.estimatedDuration, context.freeWindowDuration) {
        case let (estimate?, window?):
            let ratio = window > 0 ? estimate / window : .infinity
            freeWindowFit = ratio <= 1 ? 15 : ratio <= 1.25 ? 8 : 0
            durationFit = ratio <= 0.75 ? 10 : ratio <= 1 ? 8 : ratio <= 1.25 ? 3 : 0
        case (nil, _):
            freeWindowFit = 8
            durationFit = 5
            missing.append("task estimate")
        case (_, nil):
            freeWindowFit = 8
            durationFit = 5
            missing.append("current free-window duration")
        }

        let energyFit: Int
        switch (candidate.requiredEnergy, context.availableEnergy) {
        case let (required?, available?): energyFit = available >= required ? 10 : max(0, 10 - (required - available) * 5)
        default:
            energyFit = 5
            missing.append("energy signal")
        }

        let contextFit: Int
        switch (candidate.planningContext, context.planningContext) {
        case (.neutral?, _), (_, .neutral?): contextFit = 5
        case let (taskContext?, activeContext?): contextFit = taskContext == activeContext ? 10 : 0
        default:
            contextFit = 5
            missing.append("work or personal context")
        }

        let dependency = candidate.dependenciesReady ? 5 : 0
        let weekly = candidate.alignsWithWeeklyOutcome ? 5 : 0
        let components: [FocusRankComponent: Int] = [
            .urgency: urgency,
            .priority: priority,
            .freeWindowFit: freeWindowFit,
            .durationFit: durationFit,
            .energyFit: energyFit,
            .contextFit: contextFit,
            .dependencyReadiness: dependency,
            .weeklyOutcomeAlignment: weekly
        ]

        let reasons = humanReasons(
            candidate: candidate,
            components: components,
            estimateMissing: candidate.estimatedDuration == nil
        )
        return FocusRankResult(
            candidateID: candidate.id,
            totalScore: components.values.reduce(0, +),
            componentScores: components,
            eligibilityExclusions: exclusions,
            confidence: max(0.25, 1 - Double(Set(missing).count) * 0.15),
            reasons: reasons,
            missingInformation: Array(Set(missing)).sorted()
        )
    }

    private func compare(
        _ lhs: (candidate: FocusRankCandidate, result: FocusRankResult),
        _ rhs: (candidate: FocusRankCandidate, result: FocusRankResult),
        context: FocusRankContext
    ) -> Bool {
        if lhs.result.isEligible != rhs.result.isEligible { return lhs.result.isEligible }
        if lhs.candidate.isActiveSession != rhs.candidate.isActiveSession { return lhs.candidate.isActiveSession }
        let lhsPinned = lhs.candidate.pinOrder != nil
        let rhsPinned = rhs.candidate.pinOrder != nil
        if lhsPinned != rhsPinned { return lhsPinned }
        if lhs.candidate.pinOrder != rhs.candidate.pinOrder {
            return (lhs.candidate.pinOrder ?? .max) < (rhs.candidate.pinOrder ?? .max)
        }
        if lhs.candidate.commitmentLevel != rhs.candidate.commitmentLevel {
            return lhs.candidate.commitmentLevel == .mustDo
        }
        if lhs.result.totalScore != rhs.result.totalScore { return lhs.result.totalScore > rhs.result.totalScore }
        if lhs.candidate.planningDay != rhs.candidate.planningDay {
            return optionalDay(lhs.candidate.planningDay, precedes: rhs.candidate.planningDay)
        }
        if lhs.candidate.dueDate != rhs.candidate.dueDate {
            return (lhs.candidate.dueDate ?? .distantFuture) < (rhs.candidate.dueDate ?? .distantFuture)
        }
        return lhs.candidate.id.uuidString < rhs.candidate.id.uuidString
    }

    private func optionalDay(_ lhs: PlanningDay?, precedes rhs: PlanningDay?) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): lhs < rhs
        case (_?, nil): true
        default: false
        }
    }

    private func urgencyScore(dueDate: Date?, now: Date) -> Int {
        guard let dueDate else { return 0 }
        let days = dueDate.timeIntervalSince(now) / 86_400
        if days < 0 { return 25 }
        if days <= 1 { return 23 }
        if days <= 3 { return 20 }
        if days <= 7 { return 15 }
        if days <= 14 { return 10 }
        return 5
    }

    private func priorityScore(_ priority: FocusPriorityBand) -> Int {
        switch priority {
        case .low: 5
        case .medium: 10
        case .high: 15
        case .urgent: 20
        }
    }

    private func humanReasons(
        candidate: FocusRankCandidate,
        components: [FocusRankComponent: Int],
        estimateMissing: Bool
    ) -> [FocusRankReason] {
        var reasons: [FocusRankReason] = []
        if candidate.commitmentLevel == .mustDo {
            reasons.append(.init(component: .priority, text: "Marked Must Do for this plan."))
        }
        if (components[.urgency] ?? 0) >= 20 {
            reasons.append(.init(component: .urgency, text: "Its deadline needs attention soon."))
        }
        if (components[.freeWindowFit] ?? 0) >= 15 {
            reasons.append(.init(component: .freeWindowFit, text: "It fits the current free window."))
        }
        if (components[.energyFit] ?? 0) >= 10 {
            reasons.append(.init(component: .energyFit, text: "It matches the available energy."))
        }
        if candidate.alignsWithWeeklyOutcome {
            reasons.append(.init(component: .weeklyOutcomeAlignment, text: "It advances a weekly outcome."))
        }
        if estimateMissing {
            reasons.append(.init(component: .durationFit, text: "Duration fit is neutral until an estimate is added."))
        }
        if reasons.count < 2 {
            reasons.append(.init(component: .dependencyReadiness, text: "Its dependencies are ready."))
        }
        return Array(reasons.prefix(3))
    }
}

public enum PlanningDependencyService {
    public static func cycle(taskIDs: Set<UUID>, dependencies: [UUID: Set<UUID>]) -> [UUID]? {
        enum Mark { case visiting, visited }
        var marks: [UUID: Mark] = [:]
        var stack: [UUID] = []

        func visit(_ id: UUID) -> [UUID]? {
            if marks[id] == .visiting {
                guard let index = stack.firstIndex(of: id) else { return [id] }
                return Array(stack[index...]) + [id]
            }
            if marks[id] == .visited { return nil }
            marks[id] = .visiting
            stack.append(id)
            for dependency in (dependencies[id] ?? []).sorted(by: { $0.uuidString < $1.uuidString })
            where taskIDs.contains(dependency) {
                if let cycle = visit(dependency) { return cycle }
            }
            _ = stack.popLast()
            marks[id] = .visited
            return nil
        }

        for id in taskIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            if let cycle = visit(id) { return cycle }
        }
        return nil
    }

    public static func dependencyReady(
        taskID: UUID,
        dependencies: [UUID: Set<UUID>],
        completedTaskIDs: Set<UUID>
    ) -> Bool {
        (dependencies[taskID] ?? []).isSubset(of: completedTaskIDs)
    }
}

public struct DeterministicPlanRepairService: PlanRepairService {
    public init() {}

    public func proposals(for snapshot: PlanDaySnapshot, now: Date) -> [PlanRepairProposal] {
        var proposals: [PlanRepairProposal] = []
        for block in snapshot.blocks where block.endAt < now {
            guard let taskID = block.taskID,
                  snapshot.plannedTasks.contains(where: { $0.id == taskID }) else { continue }
            proposals.append(.init(
                id: stableID(seed: "missed:\(block.id.uuidString):\(snapshot.day.year)-\(snapshot.day.month)-\(snapshot.day.day)"),
                trigger: .missedPlannedWork,
                taskID: taskID,
                timeBlockID: block.id,
                actions: [.resume, .moveLaterToday, .moveToAnotherDay, .split, .`defer`, .leaveUnchanged, .askEva],
                explanation: "This planned block has passed without a completion receipt.",
                createdAt: now
            ))
        }
        if snapshot.capacity.overloadDuration > 0 {
            proposals.append(.init(
                id: stableID(seed: "overload:\(snapshot.day.year)-\(snapshot.day.month)-\(snapshot.day.day)"),
                trigger: .overloadedWindow,
                taskID: nil,
                timeBlockID: nil,
                actions: [.moveToAnotherDay, .split, .`defer`, .leaveUnchanged, .askEva],
                explanation: "Known estimates exceed usable capacity.",
                createdAt: now
            ))
        }
        return proposals.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func stableID(seed: String) -> UUID {
        var bytes = Array(seed.utf8)
        while bytes.count < 16 { bytes.append(UInt8(bytes.count)) }
        var output = [UInt8](repeating: 0, count: 16)
        for (index, byte) in bytes.enumerated() { output[index % 16] &+= byte &+ UInt8(index % 251) }
        output[6] = (output[6] & 0x0F) | 0x40
        output[8] = (output[8] & 0x3F) | 0x80
        return UUID(uuid: (
            output[0], output[1], output[2], output[3], output[4], output[5], output[6], output[7],
            output[8], output[9], output[10], output[11], output[12], output[13], output[14], output[15]
        ))
    }
}

public enum EstimateCalibrationService {
    public static func suggestion(
        taskID: UUID,
        comparableDurations: [TimeInterval],
        now: Date = Date()
    ) -> EstimateCalibrationSuggestion? {
        let evidence = comparableDurations.filter { $0 > 0 }.sorted()
        guard evidence.count >= 3 else { return nil }
        let median = evidence[evidence.count / 2]
        let rounded = max(5 * 60, (median / (5 * 60)).rounded() * (5 * 60))
        return .init(
            taskID: taskID,
            suggestedDuration: rounded,
            evidenceSessionCount: evidence.count,
            observedMinimum: evidence.first ?? rounded,
            observedMaximum: evidence.last ?? rounded,
            generatedAt: now
        )
    }
}

public enum FocusSessionStateMachine {
    public static func applying(_ command: FocusSessionCommand, to session: FocusSessionV2) -> FocusSessionV2 {
        guard command.sessionID == session.id,
              session.appliedCommandIDs.contains(command.id) == false else { return session }

        var updated = session
        updated.appliedCommandIDs.insert(command.id)
        switch command.kind {
        case .pause:
            guard updated.state == .running else { return updated }
            updated.state = .paused
            updated.pausedAt = max(command.occurredAt, updated.startedAt)
            updated.interruptionCount += 1
        case .resume:
            guard updated.state == .paused, let pausedAt = updated.pausedAt else { return updated }
            updated.accumulatedPauseDuration += max(0, command.occurredAt.timeIntervalSince(pausedAt))
            updated.pausedAt = nil
            updated.state = .running
        case .end(let outcome):
            guard updated.state != .ended else { return updated }
            if let pausedAt = updated.pausedAt {
                updated.accumulatedPauseDuration += max(0, command.occurredAt.timeIntervalSince(pausedAt))
                updated.pausedAt = nil
            }
            updated.endedAt = max(command.occurredAt, updated.startedAt)
            updated.outcome = outcome
            updated.state = .ended
        }
        return updated
    }
}

public extension PlanMutation {
    var inverse: PlanMutation {
        switch self {
        case .saveTaskMetadata(let before, let after):
            .saveTaskMetadata(before: after, after: before)
        case .saveTimeBlock(let before, let after):
            if let before { .saveTimeBlock(before: after, after: before) }
            else { .deleteTimeBlock(after) }
        case .deleteTimeBlock(let block):
            .saveTimeBlock(before: nil, after: block)
        case .batch(let mutations):
            .batch(mutations.reversed().map(\.inverse))
        }
    }
}
