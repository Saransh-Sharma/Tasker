import Foundation

public final class CanonicalTrackHabitProjectionService: TrackHabitProjectionService, @unchecked Sendable {
    private let repository: any HabitRuntimeReadRepositoryProtocol

    public init(repository: any HabitRuntimeReadRepositoryProtocol) {
        self.repository = repository
    }

    public func occurrenceEvidence(
        from: Date,
        to: Date,
        now: Date,
        calendar: Calendar
    ) async throws -> [UUID: [HabitOccurrenceEvidence]] {
        let rows: [HabitLibraryRow] = try await withCheckedThrowingContinuation { continuation in
            repository.fetchHabitLibrary(includeArchived: false) { continuation.resume(with: $0) }
        }
        let active = rows.filter { !$0.isPaused && !$0.isArchived }
        guard !active.isEmpty else { return [:] }

        let span = max(30, (calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0) + 2)
        let history: [HabitHistoryWindow] = try await withCheckedThrowingContinuation { continuation in
            repository.fetchHistory(habitIDs: active.map(\.habitID), endingOn: now, dayCount: span) {
                continuation.resume(with: $0)
            }
        }

        let upperBound = min(to, now)
        return Dictionary(uniqueKeysWithValues: history.map { window in
            let evidence = window.marks.compactMap { mark -> HabitOccurrenceEvidence? in
                guard mark.date >= from && mark.date < to else { return nil }
                let day = PlanningDay(date: mark.date, timeZone: calendar.timeZone, calendar: calendar)
                switch mark.state {
                case .success:
                    return .init(habitID: window.habitID, day: day, resolution: .completed)
                case .failure:
                    return .init(habitID: window.habitID, day: day, resolution: .due)
                case .skipped:
                    return .init(habitID: window.habitID, day: day, resolution: .manuallySkipped)
                case .none:
                    return mark.date <= upperBound
                        ? .init(habitID: window.habitID, day: day, resolution: .due)
                        : nil
                case .future:
                    return .init(habitID: window.habitID, day: day, isDue: false)
                }
            }
            return (window.habitID, evidence)
        })
    }
}

public enum HabitRecoveryMutationError: LocalizedError {
    case invalidDay
    case missingOccurrence

    public var errorDescription: String? {
        switch self {
        case .invalidDay: "This local calendar day could not be resolved."
        case .missingOccurrence: "LifeBoard could not verify the habit occurrence after recovery."
        }
    }
}

/// Applies a recovery through the canonical habit runtime, then returns enough
/// provenance to reverse it. Recovery metadata is persisted by Track only after
/// this canonical mutation succeeds.
public final class CanonicalHabitRecoveryMutationApplier: HabitRecoveryMutationApplying, @unchecked Sendable {
    private let repository: any HabitRuntimeReadRepositoryProtocol
    private let resolveHabit: ResolveHabitOccurrenceUseCase
    private let resetHabit: ResetHabitOccurrenceUseCase
    private let resolveOccurrence: ResolveOccurrenceUseCase
    private let recomputeStreaks: RecomputeHabitStreaksUseCase

    public init(
        repository: any HabitRuntimeReadRepositoryProtocol,
        resolveHabit: ResolveHabitOccurrenceUseCase,
        resetHabit: ResetHabitOccurrenceUseCase,
        resolveOccurrence: ResolveOccurrenceUseCase,
        recomputeStreaks: RecomputeHabitStreaksUseCase
    ) {
        self.repository = repository
        self.resolveHabit = resolveHabit
        self.resetHabit = resetHabit
        self.resolveOccurrence = resolveOccurrence
        self.recomputeStreaks = recomputeStreaks
    }

    public func recover(habitID: UUID, day: PlanningDay) async throws -> HabitRecoveryReceipt {
        guard let date = day.startDate() else { throw HabitRecoveryMutationError.invalidDay }
        let before = try await summary(habitID: habitID, date: date)
        let previousState = before?.state ?? .pending
        if previousState != .completed {
            try await withCheckedThrowingContinuation { continuation in
                resolveHabit.execute(
                    habitID: habitID,
                    occurrenceID: before?.occurrenceID,
                    action: .complete,
                    on: date
                ) { continuation.resume(with: $0) }
            }
        }
        let after = try await summary(habitID: habitID, date: date)
        guard let occurrenceID = after?.occurrenceID ?? before?.occurrenceID else {
            throw HabitRecoveryMutationError.missingOccurrence
        }
        return HabitRecoveryReceipt(
            habitID: habitID,
            day: day,
            occurrenceID: occurrenceID,
            previousState: previousState
        )
    }

    public func revert(_ receipt: HabitRecoveryReceipt) async throws {
        guard receipt.previousState != .completed else { return }
        guard let date = receipt.day.startDate() else { throw HabitRecoveryMutationError.invalidDay }
        try await withCheckedThrowingContinuation { continuation in
            resetHabit.execute(
                habitID: receipt.habitID,
                occurrenceID: receipt.occurrenceID,
                on: date
            ) { continuation.resume(with: $0) }
        }

        guard let resolution = restorationResolution(for: receipt.previousState),
              let occurrenceID = receipt.occurrenceID else { return }
        try await withCheckedThrowingContinuation { continuation in
            resolveOccurrence.execute(id: occurrenceID, resolution: resolution) {
                continuation.resume(with: $0)
            }
        }
        _ = try await withCheckedThrowingContinuation { continuation in
            recomputeStreaks.execute(habitIDs: [receipt.habitID], referenceDate: date) {
                continuation.resume(with: $0)
            }
        }
    }

    private func summary(habitID: UUID, date: Date) async throws -> HabitOccurrenceSummary? {
        try await withCheckedThrowingContinuation { continuation in
            repository.fetchAgendaHabit(habitID: habitID, for: date) {
                continuation.resume(with: $0)
            }
        }
    }

    private func restorationResolution(for state: OccurrenceState) -> OccurrenceResolutionType? {
        switch state {
        case .pending: nil
        case .completed: .completed
        case .skipped: .skipped
        case .missed: .missed
        case .failed: .lapsed
        }
    }
}

public final class CanonicalRoutineLinkedMutationApplier: RoutineLinkedMutationApplying, @unchecked Sendable {
    private let taskRepository: any TaskDefinitionRepositoryProtocol
    private let habitRepository: any HabitRuntimeReadRepositoryProtocol
    private let completeTask: CompleteTaskDefinitionUseCase
    private let resolveHabit: ResolveHabitOccurrenceUseCase

    public init(
        taskRepository: any TaskDefinitionRepositoryProtocol,
        habitRepository: any HabitRuntimeReadRepositoryProtocol,
        completeTask: CompleteTaskDefinitionUseCase,
        resolveHabit: ResolveHabitOccurrenceUseCase
    ) {
        self.taskRepository = taskRepository
        self.habitRepository = habitRepository
        self.completeTask = completeTask
        self.resolveHabit = resolveHabit
    }

    public func isApplied(_ mutation: RoutineLinkedMutationKind, targetID: UUID, at date: Date) async throws -> Bool {
        switch mutation {
        case .completeTask:
            let task: TaskDefinition? = try await withCheckedThrowingContinuation { continuation in
                taskRepository.fetchTaskDefinition(id: targetID) { continuation.resume(with: $0) }
            }
            return task?.isComplete == true
        case .completeHabitOccurrence:
            let summary: HabitOccurrenceSummary? = try await withCheckedThrowingContinuation { continuation in
                habitRepository.fetchAgendaHabit(habitID: targetID, for: date) { continuation.resume(with: $0) }
            }
            return summary?.state == .completed
        }
    }

    public func apply(_ mutation: RoutineLinkedMutationKind, targetID: UUID, at date: Date) async throws {
        switch mutation {
        case .completeTask:
            let _: TaskDefinition = try await withCheckedThrowingContinuation { continuation in
                completeTask.execute(taskID: targetID) { continuation.resume(with: $0) }
            }
        case .completeHabitOccurrence:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                resolveHabit.execute(habitID: targetID, action: .complete, on: date) { continuation.resume(with: $0) }
            }
        }
    }
}

public final class CanonicalStarterPackMutationApplier: StarterPackCanonicalMutationApplying, @unchecked Sendable {
    private let lifeAreaRepository: any LifeAreaRepositoryProtocol
    private let createHabitUseCase: CreateHabitUseCase
    private let setHabitArchivedUseCase: SetHabitArchivedUseCase

    public init(
        lifeAreaRepository: any LifeAreaRepositoryProtocol,
        createHabitUseCase: CreateHabitUseCase,
        setHabitArchivedUseCase: SetHabitArchivedUseCase
    ) {
        self.lifeAreaRepository = lifeAreaRepository
        self.createHabitUseCase = createHabitUseCase
        self.setHabitArchivedUseCase = setHabitArchivedUseCase
    }

    public func createHabit(
        title: String,
        pack: StarterPack,
        itemKind: StarterPackItemKind
    ) async throws -> UUID {
        let areas: [LifeArea] = try await withCheckedThrowingContinuation { continuation in
            lifeAreaRepository.fetchAll { continuation.resume(with: $0) }
        }
        guard let area = areas.filter({ $0.isArchived == false }).sorted(by: { $0.sortOrder < $1.sortOrder }).first else {
            throw NSError(
                domain: "LifeBoard.StarterPack",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Create a life area before installing habit-based starter-pack items."]
            )
        }

        let schedule = Self.schedule(for: pack)
        let request = CreateHabitRequest(
            title: title,
            lifeAreaID: area.id,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            icon: .init(symbolName: itemKind == .reminder ? "bell.fill" : "sparkles", categoryKey: "starter-pack"),
            colorHex: "#E7BB7E",
            targetConfig: .init(notes: "Created from the \(Self.displayName(pack)) starter pack.", targetCountPerDay: 1),
            cadence: .daily(hour: schedule.hour, minute: schedule.minute),
            reminderWindowStart: itemKind == .reminder ? schedule.windowStart : nil,
            reminderWindowEnd: itemKind == .reminder ? schedule.windowEnd : nil
        )
        let created: HabitDefinitionRecord = try await withCheckedThrowingContinuation { continuation in
            createHabitUseCase.execute(request: request) { continuation.resume(with: $0) }
        }
        return created.id
    }

    public func archiveHabit(id: UUID) async throws {
        let _: HabitDefinitionRecord = try await withCheckedThrowingContinuation { continuation in
            setHabitArchivedUseCase.execute(id: id, isArchived: true) { continuation.resume(with: $0) }
        }
    }

    private static func schedule(for pack: StarterPack) -> (hour: Int, minute: Int, windowStart: String, windowEnd: String) {
        switch pack {
        case .morningFoundation: (8, 0, "07:30", "09:30")
        case .workdayReset: (14, 0, "13:30", "15:30")
        case .lowEnergyRecovery: (15, 0, "14:30", "16:30")
        case .medicationSupport: (9, 0, "08:30", "10:30")
        case .eveningWindDown: (21, 0, "20:30", "22:30")
        }
    }

    private static func displayName(_ pack: StarterPack) -> String {
        switch pack {
        case .morningFoundation: "Morning Foundation"
        case .workdayReset: "Workday Reset"
        case .lowEnergyRecovery: "Low Energy Recovery"
        case .medicationSupport: "Medication Support"
        case .eveningWindDown: "Evening Wind-down"
        }
    }
}

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
            .map { occurrence in
                var occurrence = occurrence
                // A recovery receipt is provenance, not a substitute for canonical
                // completion. Only an actually completed occurrence may be presented
                // and graded as recovered.
                if occurrence.resolution == .completed,
                   policy.recoveredDays.contains(occurrence.day) {
                    occurrence.resolution = .recovered
                }
                return occurrence
            }
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
