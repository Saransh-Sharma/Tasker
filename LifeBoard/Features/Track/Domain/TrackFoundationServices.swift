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
                    return .init(habitID: window.habitID, day: day, resolution: .failed)
                case .skipped:
                    return .init(habitID: window.habitID, day: day, resolution: .manuallySkipped)
                case .none:
                    return mark.date <= upperBound
                        ? .init(habitID: window.habitID, day: day, resolution: .missing)
                        : nil
                case .future:
                    // `resolution` defaults to `.due`, so omitting it labelled
                    // every future day as due work — the exact thing this
                    // service promises not to invent — even though `isDue` was
                    // false. `.unresolved` is the honest label and is already
                    // the vocabulary the scoring paths below treat as "does not
                    // count against you", alongside `.offDay` and `.paused`.
                    // `.missing` would be wrong in the other direction: it
                    // scores as a miss, and a day that has not happened yet
                    // cannot have been missed.
                    return .init(
                        habitID: window.habitID,
                        day: day,
                        isDue: false,
                        resolution: .unresolved
                    )
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
            colorHex: SceneHex.apricot,
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

public struct DefaultHabitGradeService: HabitGradeService {
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
        let eligible = relevant.filter {
            policy.isIntentionalOffDay($0.day) == false
                && ![.offDay, .paused, .manuallySkipped, .unresolved].contains($0.resolution)
        }
        let completed = eligible.filter {
            [.completed, .recovered, .abstained].contains($0.resolution)
        }
        let grade = eligible.isEmpty ? nil : Double(completed.count) / Double(eligible.count)

        let byDay = Dictionary(relevant.map { ($0.day, $0) }, uniquingKeysWith: { _, newer in newer })
        var streak = 0
        var cursor = today
        while cursor >= firstDay {
            if policy.isIntentionalOffDay(cursor) {
                guard let previous = previousDay(cursor, calendar: calendar) else { break }
                cursor = previous
                continue
            }
            guard let occurrence = byDay[cursor], occurrence.isDue else {
                guard let previous = previousDay(cursor, calendar: calendar) else { break }
                cursor = previous
                continue
            }
            if [.completed, .recovered, .abstained].contains(occurrence.resolution) {
                streak += 1
            } else if [.offDay, .paused, .manuallySkipped, .unresolved].contains(occurrence.resolution) {
                guard let previous = previousDay(cursor, calendar: calendar) else { break }
                cursor = previous
                continue
            } else {
                break
            }
            guard let previous = previousDay(cursor, calendar: calendar) else { break }
            cursor = previous
        }

        let distribution = Dictionary(grouping: relevant, by: \.resolution)
            .mapValues { $0.count }
        let completionMinutes = completed.compactMap { occurrence -> Int? in
            guard let recordedAt = occurrence.recordedAt else { return nil }
            let components = calendar.dateComponents([.hour, .minute], from: recordedAt)
            guard let hour = components.hour, let minute = components.minute else { return nil }
            return hour * 60 + minute
        }
        let bestTime = completionMinutes.isEmpty
            ? nil
            : completionMinutes.sorted()[completionMinutes.count / 2]

        return HabitGradeSnapshot(
            habitID: habitID,
            completedEligibleCount: completed.count,
            eligibleDueCount: eligible.count,
            grade: grade,
            streak: streak,
            recoveredDays: eligible.filter { $0.resolution == .recovered }.map(\.day),
            distribution: distribution,
            bestTimeMinutesFromMidnight: bestTime,
            recoveryCount: eligible.filter { $0.resolution == .recovered }.count,
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

public enum RoutineTemplateCatalog {
    public static func definition(for kind: RoutineTemplateKind) -> RoutineDefinition? {
        switch kind {
        case .morning:
            make("Morning", [
                step("Arrive gently", .checkIn, minutes: 1, optional: true),
                step("Choose today’s anchor", .instruction),
                step("Begin the first small action", .timer, minutes: 10, optional: true)
            ])
        case .evening:
            make("Evening", [
                step("Close open loops", .instruction, optional: true),
                step("Set down tomorrow’s first step", .instruction),
                step("Quiet the space", .timer, minutes: 5, optional: true)
            ])
        case .workStart:
            make("Work start", [
                step("Clear the work surface", .timer, minutes: 2, optional: true),
                step("Name the outcome", .checkIn),
                step("Start a focus block", .timer, minutes: 25, optional: true)
            ])
        case .shutdown:
            make("Shutdown", [
                step("Capture unfinished thoughts", .instruction),
                step("Choose the next starting point", .instruction),
                step("Close work", .checkIn, optional: true)
            ])
        case .workout:
            make("Workout", [
                step("Set your intention", .checkIn, optional: true),
                step("Move in the way you planned", .timer, minutes: 20, optional: true),
                step("Cool down and note how it felt", .checkIn, optional: true)
            ])
        case .care:
            make("Care", [
                step("Check what you need", .checkIn),
                step("Take one care action", .instruction),
                step("Pause before continuing", .timer, minutes: 2, optional: true)
            ])
        case .custom:
            nil
        }
    }

    private static func make(_ title: String, _ steps: [RoutineStep]) -> RoutineDefinition {
        RoutineDefinition(title: title, steps: steps.enumerated().map { index, value in
            RoutineStep(
                id: value.id,
                title: value.title,
                kind: value.kind,
                ordinal: index,
                duration: value.duration,
                isRequired: value.isRequired,
                isSkippable: value.isSkippable,
                linkedEntityID: value.linkedEntityID,
                linkedMutation: value.linkedMutation,
                choices: value.choices,
                branches: value.branches
            )
        })
    }

    private static func step(
        _ title: String,
        _ kind: RoutineStepKind,
        minutes: Double? = nil,
        optional: Bool = false
    ) -> RoutineStep {
        RoutineStep(
            title: title,
            kind: kind,
            ordinal: 0,
            duration: minutes.map { $0 * 60 },
            isRequired: !optional,
            isSkippable: optional
        )
    }
}

public struct RoutineValidator: Sendable {
    public init() {}

    public func validate(
        _ routine: RoutineDefinition,
        availableLinkedEntityIDs: Set<UUID>? = nil
    ) -> RoutineValidationReport {
        let steps = routine.steps.sorted {
            ($0.ordinal, $0.id.uuidString) < ($1.ordinal, $1.id.uuidString)
        }
        guard !steps.isEmpty else {
            return RoutineValidationReport(issues: [.noSteps])
        }

        var issues: [RoutineValidationIssue] = []
        let ids = Set(steps.map(\.id))
        let duplicateIDs = Dictionary(grouping: steps, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted { $0.uuidString < $1.uuidString }
        issues.append(contentsOf: duplicateIDs.map(RoutineValidationIssue.duplicateStepID))
        let duplicateOrdinals = Dictionary(grouping: steps, by: \.ordinal)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        issues.append(contentsOf: duplicateOrdinals.map(RoutineValidationIssue.duplicateOrdinal))

        var edges: [UUID: Set<UUID>] = [:]
        for (index, step) in steps.enumerated() {
            if step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyTitle(stepID: step.id))
            }
            let normalizedChoices = step.choices.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let choiceCounts = Dictionary(grouping: normalizedChoices, by: { $0 })
            let invalidChoices = normalizedChoices.filter {
                $0.isEmpty || (choiceCounts[$0]?.count ?? 0) > 1
            }
            for choice in Set(invalidChoices).sorted() {
                issues.append(.invalidChoice(stepID: step.id, choice: choice))
            }
            if step.linkedMutation != nil, step.linkedEntityID == nil {
                issues.append(.missingLinkedEntity(stepID: step.id))
            }
            if let linkedID = step.linkedEntityID,
               let availableLinkedEntityIDs,
               !availableLinkedEntityIDs.contains(linkedID) {
                issues.append(.linkedEntityUnavailable(stepID: step.id, linkedEntityID: linkedID))
            }
            for branch in step.branches {
                if branch.sourceStepID != step.id {
                    issues.append(.branchSourceMismatch(
                        stepID: step.id,
                        sourceStepID: branch.sourceStepID
                    ))
                }
                if !ids.contains(branch.destinationStepID) {
                    issues.append(.missingBranchDestination(
                        sourceStepID: branch.sourceStepID,
                        destinationStepID: branch.destinationStepID
                    ))
                } else {
                    edges[step.id, default: []].insert(branch.destinationStepID)
                }
                let expected = branch.expectedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                if !step.choices.isEmpty, !normalizedChoices.contains(expected) {
                    issues.append(.invalidChoice(stepID: step.id, choice: expected))
                }
            }
            let explicitlyBranchedResponses = Set(
                step.branches
                    .filter { $0.operation == .equals }
                    .map { $0.expectedResponse.trimmingCharacters(in: .whitespacesAndNewlines) }
            )
            let isExhaustiveChoice = step.kind == .choice
                && !normalizedChoices.isEmpty
                && Set(normalizedChoices).isSubset(of: explicitlyBranchedResponses)
            if !isExhaustiveChoice,
               let next = steps.indices.contains(index + 1) ? steps[index + 1] : nil {
                edges[step.id, default: []].insert(next.id)
            }
        }

        var visited: Set<UUID> = []
        var visiting: Set<UUID> = []
        var stack: [UUID] = []
        var loops: Set<[UUID]> = []
        func walk(_ id: UUID) {
            if visiting.contains(id) {
                if let start = stack.firstIndex(of: id) {
                    loops.insert(Array(stack[start...]) + [id])
                }
                return
            }
            guard !visited.contains(id) else { return }
            visiting.insert(id)
            stack.append(id)
            for destination in (edges[id] ?? []).sorted(by: { $0.uuidString < $1.uuidString }) {
                walk(destination)
            }
            _ = stack.popLast()
            visiting.remove(id)
            visited.insert(id)
        }
        if let first = steps.first { walk(first.id) }
        for id in ids.subtracting(visited).sorted(by: { $0.uuidString < $1.uuidString }) {
            issues.append(.unreachableStep(id))
        }
        issues.append(contentsOf: loops.sorted {
            $0.map(\.uuidString).joined() < $1.map(\.uuidString).joined()
        }.map(RoutineValidationIssue.loop))
        return RoutineValidationReport(issues: issues)
    }
}

public extension RoutineExecutionService {
    func apply(
        command: RoutineRunCommand,
        to run: RoutineRun,
        at date: Date
    ) -> RoutineTransition {
        switch command {
        case let .advance(response, idempotencyKey):
            return advance(
                run: run,
                response: response,
                skip: false,
                idempotencyKey: idempotencyKey,
                at: date
            )
        case let .skip(reason, idempotencyKey):
            return advance(
                run: run,
                response: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                skip: true,
                idempotencyKey: idempotencyKey,
                at: date
            )
        case .pause:
            guard run.status == .running else {
                return .init(run: run, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: false)
            }
            var updated = run
            updated.status = .paused
            updated.pausedAt = date
            updated.updatedAt = date
            return .init(run: updated, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: true)
        case .interrupt:
            guard run.status == .running else {
                return .init(run: run, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: false)
            }
            var updated = run
            updated.status = .interrupted
            updated.pausedAt = date
            updated.updatedAt = date
            return .init(run: updated, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: true)
        case .resume:
            guard run.status == .paused || run.status == .interrupted else {
                return .init(run: run, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: false)
            }
            var updated = run
            if let pausedAt = run.pausedAt {
                let pausedDuration = max(0, date.timeIntervalSince(pausedAt))
                updated.accumulatedPausedDuration = run.effectivePausedDuration + pausedDuration
                updated.currentStepPausedDuration = run.effectiveCurrentStepPausedDuration + pausedDuration
            }
            updated.pausedAt = nil
            updated.status = .running
            updated.updatedAt = date
            return .init(run: updated, linkedMutation: nil, linkedEntityID: nil, didApplyEvent: true)
        case .stop:
            let updated = abandon(run: run, at: date)
            return .init(
                run: updated,
                linkedMutation: nil,
                linkedEntityID: nil,
                didApplyEvent: updated != run
            )
        }
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
        updated.currentStepPausedDuration = 0
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
        guard run.status == .running || run.status == .paused || run.status == .interrupted else {
            return run
        }
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
        let supportsPercentage = [.count, .quantity, .duration].contains(goal.type)
            && goal.effectiveIntent != .directional
        let fraction: Double? = supportsPercentage ? currentValue.flatMap { current -> Double? in
            target.flatMap { target in
                let baseline = goal.baselineValue ?? 0
                let span = target - baseline
                guard span.isFinite, span != 0 else { return nil }
                return min(1, max(0, (current - baseline) / span))
            }
        } : nil
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

public enum GoalLifecycleError: LocalizedError, Equatable, Sendable {
    case emptyTitle
    case invalidTarget
    case unchangedStatus

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "Give this goal a name."
        case .invalidTarget: "This goal needs a finite target that differs from its baseline."
        case .unchangedStatus: "The goal already has that status."
        }
    }
}

public struct GoalLifecycleService: Sendable {
    private let repository: any TrackFoundationRepository

    public init(repository: any TrackFoundationRepository) {
        self.repository = repository
    }

    public func save(
        draft: GoalDraft,
        existing: GoalDefinition? = nil,
        at date: Date = Date()
    ) async throws -> GoalDefinition {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw GoalLifecycleError.emptyTitle }
        if [.count, .quantity, .duration].contains(draft.type) {
            guard let target = draft.targetValue, target.isFinite,
                  draft.baselineValue.map({ $0.isFinite && $0 != target }) ?? true else {
                throw GoalLifecycleError.invalidTarget
            }
        }
        let unit = draft.unitLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = draft.whyItMatters?.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = existing?.effectiveStatus ?? .active
        let statusEvents = existing?.statusEvents ?? [
            GoalStatusEvent(goalID: existing?.id ?? UUID(), status: status, recordedAt: date)
        ]
        let goalID = existing?.id ?? statusEvents[0].goalID
        let value = GoalDefinition(
            id: goalID,
            areaID: draft.areaID,
            title: title,
            type: draft.type,
            targetValue: draft.targetValue,
            unitLabel: unit?.isEmpty == true ? nil : unit,
            targetDate: draft.targetDate,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? date,
            updatedAt: date,
            intent: draft.intent,
            status: status,
            baselineValue: draft.baselineValue,
            confidenceRaw: draft.confidence?.rawValue,
            whyItMatters: why?.isEmpty == true ? nil : why,
            checkInCadenceRaw: draft.checkInCadence.rawValue,
            pausedAt: existing?.pausedAt,
            statusEvents: statusEvents
        )
        try await repository.saveGoal(value)
        return value
    }

    public func transition(
        _ goal: GoalDefinition,
        to status: GoalStatus,
        reason: String?,
        at date: Date = Date()
    ) async throws -> GoalTransitionReceipt {
        guard goal.effectiveStatus != status else { throw GoalLifecycleError.unchangedStatus }
        let normalizedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = GoalStatusEvent(
            goalID: goal.id,
            status: status,
            reason: normalizedReason?.isEmpty == true ? nil : normalizedReason,
            recordedAt: date
        )
        var updated = goal
        updated.status = status
        updated.isArchived = status == .archived
        updated.pausedAt = status == .paused ? date : nil
        updated.updatedAt = date
        updated.statusEvents = (goal.statusEvents ?? []) + [event]
        try await repository.saveGoal(updated)
        return .init(before: goal, after: updated, event: event, createdAt: date)
    }

    /// Undo appends a compensating status event. Existing history is never
    /// deleted or rewritten.
    @discardableResult
    public func undo(
        _ receipt: GoalTransitionReceipt,
        at date: Date = Date()
    ) async throws -> GoalTransitionReceipt {
        let current = receipt.after
        return try await transition(
            current,
            to: receipt.before.effectiveStatus,
            reason: "Undid \(receipt.event.status.rawValue) transition",
            at: date
        )
    }
}

public struct GoalAssessmentService: Sendable {
    public init() {}

    public func assess(
        goal: GoalDefinition,
        samples: [GoalProgressSample],
        missedCheckIns: Int,
        asOf date: Date = Date()
    ) -> GoalProgressAssessment {
        let ordered = samples.sorted {
            $0.measuredAt == $1.measuredAt
                ? $0.linkID.uuidString < $1.linkID.uuidString
                : $0.measuredAt < $1.measuredAt
        }
        let numeric = ordered.compactMap { sample -> (Date, Double)? in
            sample.value.map { (sample.measuredAt, $0) }
        }
        let percentageEligible = [.count, .quantity, .duration].contains(goal.type)
            && goal.effectiveIntent != .directional
            && goal.targetValue.map(\.isFinite) == true
            && goal.targetValue != goal.baselineValue
        let current = numeric.last?.1
        let progress: Double? = percentageEligible ? current.flatMap { current -> Double? in
            guard let target = goal.targetValue else { return nil }
            let baseline = goal.baselineValue ?? 0
            let span = target - baseline
            guard span.isFinite, span != 0 else { return nil }
            return min(1, max(0, (current - baseline) / span))
        } : nil

        var missing: [String] = []
        if ordered.isEmpty { missing.append("No linked evidence yet") }
        if missedCheckIns > 0 { missing.append("\(missedCheckIns) scheduled check-in\(missedCheckIns == 1 ? "" : "s") missing") }

        let riskReason: GoalRiskReason?
        if missedCheckIns >= 2 {
            riskReason = .missedCheckIns(count: missedCheckIns)
        } else {
            riskReason = trajectoryRisk(goal: goal, values: numeric, asOf: date)
        }
        let presentation: GoalProgressPresentation = percentageEligible
            ? .percentage
            : goal.effectiveIntent == .directional ? .checkIns : .evidenceSummary
        return GoalProgressAssessment(
            goalID: goal.id,
            presentation: presentation,
            progressFraction: progress,
            isAtRisk: riskReason != nil,
            riskReason: riskReason,
            missingEvidence: missing,
            evidenceCount: ordered.count
        )
    }

    private func trajectoryRisk(
        goal: GoalDefinition,
        values: [(Date, Double)],
        asOf date: Date
    ) -> GoalRiskReason? {
        guard values.count >= 4,
              let target = goal.targetValue,
              let targetDate = goal.targetDate,
              targetDate > date,
              let first = values.first,
              let last = values.last,
              last.0.timeIntervalSince(first.0) >= 7 * 86_400 else { return nil }
        let baseline = goal.baselineValue ?? first.1
        let totalDuration = targetDate.timeIntervalSince(goal.createdAt)
        guard totalDuration > 0 else { return nil }
        let elapsedFraction = min(1, max(0, last.0.timeIntervalSince(goal.createdAt) / totalDuration))
        let expected = baseline + ((target - baseline) * elapsedFraction)
        let meaningfulGap = abs(target - baseline) * 0.1
        if target >= baseline, last.1 < expected - meaningfulGap {
            return .behindTrajectory(observed: last.1, expected: expected)
        }
        if target < baseline, last.1 > expected + meaningfulGap {
            return .behindTrajectory(observed: last.1, expected: expected)
        }
        return nil
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
