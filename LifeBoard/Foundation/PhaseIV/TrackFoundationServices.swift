import Foundation

public struct DefaultHabitGradeEngine: HabitGradeEngine {
    public init() {}

    public func evaluate(
        habitID: UUID,
        occurrences: [HabitOccurrenceEvidence],
        policy: HabitResiliencePolicy,
        now: Date,
        calendar: Calendar
    ) -> HabitGradeSnapshot {
        let today = PlanningDay(date: now, timeZone: calendar.timeZone, calendar: calendar)
        let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) ?? now
        let firstDay = PlanningDay(date: startDate, timeZone: calendar.timeZone, calendar: calendar)
        let relevant = occurrences
            .filter { $0.habitID == habitID && $0.day >= firstDay && $0.day <= today && $0.isDue }
            .sorted { $0.day < $1.day }
        let eligible = relevant.filter { policy.offDays.contains($0.day) == false }
        let completed = eligible.filter { $0.resolution == .completed || $0.resolution == .recovered }
        let grade = eligible.isEmpty ? nil : Double(completed.count) / Double(eligible.count)

        let byDay = Dictionary(relevant.map { ($0.day, $0) }, uniquingKeysWith: { _, newer in newer })
        var streak = 0
        var cursor = today
        while cursor >= firstDay {
            if policy.offDays.contains(cursor) {
                guard let previous = previousDay(cursor, calendar: calendar) else { break }
                cursor = previous
                continue
            }
            guard let occurrence = byDay[cursor], occurrence.isDue else {
                guard let previous = previousDay(cursor, calendar: calendar) else { break }
                cursor = previous
                continue
            }
            if occurrence.resolution == .completed || occurrence.resolution == .recovered {
                streak += 1
            } else {
                break
            }
            guard let previous = previousDay(cursor, calendar: calendar) else { break }
            cursor = previous
        }

        return HabitGradeSnapshot(
            habitID: habitID,
            completedEligibleCount: completed.count,
            eligibleDueCount: eligible.count,
            grade: grade,
            streak: streak,
            recoveredDays: eligible.filter { $0.resolution == .recovered }.map(\.day),
            generatedAt: now
        )
    }

    private func previousDay(_ day: PlanningDay, calendar: Calendar) -> PlanningDay? {
        guard let date = day.startDate(calendar: calendar),
              let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        let zone = TimeZone(identifier: day.timeZoneIdentifier) ?? calendar.timeZone
        return PlanningDay(date: previous, timeZone: zone, calendar: calendar)
    }
}

public struct DefaultRoutineExecutionService: RoutineExecutionService {
    public init() {}

    public func begin(_ routine: RoutineDefinition, at date: Date) -> RoutineRun {
        RoutineRun(
            id: UUID(),
            routineID: routine.id,
            versionSnapshot: routine,
            status: routine.steps.isEmpty ? .completed : .running,
            currentStepID: routine.steps.first?.id,
            events: [],
            startedAt: date,
            endedAt: routine.steps.isEmpty ? date : nil,
            updatedAt: date
        )
    }

    public func advance(
        run: RoutineRun,
        response: String?,
        skip: Bool,
        idempotencyKey: String,
        at date: Date
    ) -> RoutineTransition {
        guard run.status == .running,
              run.events.contains(where: { $0.idempotencyKey == idempotencyKey }) == false,
              let stepID = run.currentStepID,
              let step = run.versionSnapshot.steps.first(where: { $0.id == stepID }),
              skip == false || step.isSkippable else {
            return RoutineTransition(run: run, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: false)
        }

        var updated = run
        updated.events.append(.init(
            id: UUID(),
            stepID: stepID,
            response: response,
            wasSkipped: skip,
            occurredAt: date,
            idempotencyKey: idempotencyKey
        ))
        let nextID = branchedDestination(step: step, response: response)
            ?? nextStep(after: step, in: run.versionSnapshot)?.id
        updated.currentStepID = nextID
        updated.updatedAt = date
        if nextID == nil {
            updated.status = .completed
            updated.endedAt = date
        }
        return RoutineTransition(
            run: updated,
            linkedMutation: skip ? nil : step.linkedMutation,
            linkedEntityID: skip ? nil : step.linkedEntityID,
            didApplyEvent: true
        )
    }

    public func abandon(run: RoutineRun, at date: Date) -> RoutineRun {
        guard run.status == .running else { return run }
        var updated = run
        updated.status = run.events.isEmpty ? .abandoned : .partial
        updated.endedAt = date
        updated.updatedAt = date
        return updated
    }

    private func branchedDestination(step: RoutineStep, response: String?) -> UUID? {
        step.branches.first { branch in
            switch branch.operation {
            case .equals: response == branch.expectedResponse
            case .notEquals: response != branch.expectedResponse
            }
        }?.destinationStepID
    }

    private func nextStep(after step: RoutineStep, in routine: RoutineDefinition) -> RoutineStep? {
        routine.steps.first { candidate in
            (candidate.ordinal, candidate.id.uuidString) > (step.ordinal, step.id.uuidString)
        }
    }
}

public struct DefaultGoalProgressService: GoalProgressService {
    public init() {}

    public func progress(
        for goal: GoalDefinition,
        links: [GoalLink],
        samples: [GoalProgressSample]
    ) -> GoalProgressSnapshot {
        let relevantLinks = links.filter { $0.goalID == goal.id }
        let sampleByLink = Dictionary(samples.map { ($0.linkID, $0) }, uniquingKeysWith: { older, newer in
            older.measuredAt > newer.measuredAt ? older : newer
        })
        let resolved = relevantLinks.compactMap { sampleByLink[$0.id] }
        let missingCount = max(0, relevantLinks.count - resolved.count)

        let currentValue: Double?
        switch goal.type {
        case .completion:
            currentValue = resolved.isEmpty ? nil : Double(resolved.filter { $0.isComplete == true }.count)
        case .count, .quantity, .duration:
            let values = resolved.compactMap(\.value)
            currentValue = values.isEmpty ? nil : values.reduce(0, +)
        case .targetDate:
            currentValue = resolved.contains(where: { $0.isComplete == true }) ? 1 : 0
        }
        let target: Double? = goal.type == .completion
            ? Double(max(1, relevantLinks.count))
            : goal.type == .targetDate ? 1 : goal.targetValue
        let fraction = currentValue.flatMap { current in
            target.flatMap { $0 > 0 ? min(1, max(0, current / $0)) : nil }
        }
        let confidence = relevantLinks.isEmpty ? 0 : Double(resolved.count) / Double(relevantLinks.count)
        let nextAction: String
        if relevantLinks.isEmpty { nextAction = "Link a project, task, habit, routine, or measure." }
        else if missingCount > 0 { nextAction = "Add or sync missing linked progress." }
        else if fraction == 1 { nextAction = "Review and close the goal when it feels complete." }
        else { nextAction = "Continue the next linked action." }

        return GoalProgressSnapshot(
            goalID: goal.id,
            currentValue: currentValue,
            targetValue: target,
            progressFraction: fraction,
            trend: nil,
            confidence: confidence,
            missingLinkCount: missingCount,
            nextUsefulAction: nextAction
        )
    }
}

public enum HydrationMeasurementService {
    public static func milliliters(_ amount: Double, unit: HydrationUnit) -> Double {
        switch unit {
        case .milliliters: return max(0, amount)
        case .liters: return max(0, amount) * 1_000
        case .fluidOunces: return max(0, amount) * 29.573_529_562_5
        }
    }

    public static func convert(_ amount: Double, from source: HydrationUnit, to destination: HydrationUnit) -> Double {
        let milliliters = milliliters(amount, unit: source)
        switch destination {
        case .milliliters: return milliliters
        case .liters: return milliliters / 1_000
        case .fluidOunces: return milliliters / 29.573_529_562_5
        }
    }
}

public enum StarterPackCatalog {
    public static func preview(_ pack: StarterPack) -> StarterPackPreview {
        let items: [StarterPackItem]
        switch pack {
        case .morningFoundation:
            items = [item("morning-check-in", .habit, "Morning check-in"), item("morning-routine", .routine, "Morning foundation")]
        case .workdayReset:
            items = [item("reset-goal", .goal, "Protect focused work"), item("reset-routine", .routine, "Workday reset")]
        case .lowEnergyRecovery:
            items = [item("recovery-check-in", .habit, "Name your energy"), item("recovery-routine", .routine, "Low energy recovery")]
        case .medicationSupport:
            items = [item("medication-reminder", .reminder, "Medication check-in"), item("medication-routine", .routine, "Medication support")]
        case .eveningWindDown:
            items = [item("evening-habit", .habit, "Evening reflection"), item("evening-routine", .routine, "Evening wind-down")]
        }
        return StarterPackPreview(pack: pack, items: items)
    }

    private static func item(_ id: String, _ kind: StarterPackItemKind, _ title: String) -> StarterPackItem {
        StarterPackItem(id: id, kind: kind, title: title, isSelected: true)
    }
}
