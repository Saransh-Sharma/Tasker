import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class TrackFoundationStore {
    private(set) var snapshot = TrackTodaySnapshot(
        unresolvedMedicationEvents: [], habitGrades: [], dueRoutines: [], goals: [],
        hydrationAmountMilliliters: nil, hydrationTargetMilliliters: nil, generatedAt: .distantPast
    )
    private(set) var definitions: [GoalDefinition] = []
    private(set) var routines: [RoutineDefinition] = []
    private(set) var routineSchedules: [RoutineSchedule] = []
    private(set) var routineRuns: [RoutineRun] = []
    private(set) var habitPolicies: [HabitResiliencePolicy] = []
    private(set) var habitGroups: [HabitGroup] = []
    private(set) var habitOccurrenceHistory: [UUID: [HabitOccurrenceEvidence]] = [:]
    private(set) var starterPackInstallations: [StarterPackInstallation] = []
    private(set) var medications: [LifeBoardMedicationDefinitionValue] = []
    private(set) var medicationSchedules: [LifeBoardMedicationScheduleValue] = []
    private(set) var checkIns: [LifeBoardMoodEnergyCheckInValue] = []
    private(set) var sleepRecords: [SleepContextRecord] = []
    private(set) var hydrationLogs: [HydrationLog] = []
    private(set) var hydrationHistory: [HydrationLog] = []
    private(set) var correctionReceipts: [TrackCorrectionReceipt] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var activeRoutineRun: RoutineRun?

    let repository: any TrackFoundationRepository
    let phaseIIRepository: any LifeBoardPhaseIIRepository
    private let routineService: any RoutineExecutionService
    private let goalService: any GoalProgressService
    private let goalSampleProvider: (any GoalSampleProvider)?
    private let habitProjectionService: (any TrackHabitProjectionService)?
    private let habitGradeEngine: any HabitGradeEngine
    private let linkedMutationApplier: (any RoutineLinkedMutationApplying)?
    private let starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)?
    private let habitRecoveryMutationApplier: (any HabitRecoveryMutationApplying)?
    private let correctionReceiptRepository: any TrackCorrectionReceiptRepository

    init(
        repository: any TrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        routineService: any RoutineExecutionService = DefaultRoutineExecutionService(),
        goalService: any GoalProgressService = DefaultGoalProgressService(),
        goalSampleProvider: (any GoalSampleProvider)? = nil,
        habitProjectionService: (any TrackHabitProjectionService)? = nil,
        habitGradeEngine: any HabitGradeEngine = DefaultHabitGradeEngine(),
        linkedMutationApplier: (any RoutineLinkedMutationApplying)? = nil,
        starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)? = nil,
        habitRecoveryMutationApplier: (any HabitRecoveryMutationApplying)? = nil,
        correctionReceiptRepository: any TrackCorrectionReceiptRepository = LocalTrackCorrectionReceiptRepository.shared
    ) {
        self.repository = repository
        self.phaseIIRepository = phaseIIRepository
        self.routineService = routineService
        self.goalService = goalService
        self.goalSampleProvider = goalSampleProvider
        self.habitProjectionService = habitProjectionService
        self.habitGradeEngine = habitGradeEngine
        self.linkedMutationApplier = linkedMutationApplier
        self.starterPackMutationApplier = starterPackMutationApplier
        self.habitRecoveryMutationApplier = habitRecoveryMutationApplier
        self.correctionReceiptRepository = correctionReceiptRepository
    }

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let bounds = Self.todayBounds()
            async let goalsValue = repository.fetchGoals()
            async let linksValue = repository.fetchGoalLinks(goalID: nil)
            async let routinesValue = repository.fetchRoutines()
            async let schedulesValue = repository.fetchRoutineSchedules(routineID: nil)
            async let runsValue = repository.fetchRoutineRuns(routineID: nil)
            async let policiesValue = repository.fetchHabitResiliencePolicies()
            async let groupsValue = repository.fetchHabitGroups()
            async let installationsValue = repository.fetchStarterPackInstallations()
            async let hydrationValue = repository.fetchHydrationLogs(from: bounds.start, to: bounds.end)
            let careHistoryStart = Calendar.current.date(byAdding: .day, value: -29, to: bounds.start) ?? bounds.start
            async let hydrationHistoryValue = repository.fetchHydrationLogs(from: careHistoryStart, to: bounds.end)
            async let targetValue = repository.fetchHydrationTarget()
            async let sleepValue = repository.fetchSleepContextRecords(from: careHistoryStart, to: bounds.end)
            async let medicationsValue = phaseIIRepository.fetchMedications()
            async let medicationSchedulesValue = phaseIIRepository.fetchMedicationSchedules(medicationID: nil)
            async let medicationEventsValue = phaseIIRepository.fetchMedicationEvents(from: bounds.start, to: bounds.end)
            let moodHistoryStart = Calendar.current.date(byAdding: .day, value: -29, to: bounds.start) ?? bounds.start
            async let checkInsValue = phaseIIRepository.fetchMoodCheckIns(from: moodHistoryStart, to: bounds.end)
            async let trackersValue = phaseIIRepository.fetchTrackers()
            async let trackerEntriesValue = phaseIIRepository.fetchTrackerEntries(trackerID: nil)
            async let journalDaysValue = phaseIIRepository.fetchJournalDays(search: nil, starredOnly: false, mood: nil)
            async let correctionValues = correctionReceiptRepository.fetchTrackCorrectionReceipts()

            let links: [GoalLink]
            let target: HydrationTarget?
            let medicationEvents: [LifeBoardMedicationEventValue]
            let trackers: [LifeBoardTrackerDefinitionValue]
            let trackerEntries: [LifeBoardTrackerEntryValue]
            let journalDays: [LifeBoardJournalDayValue]
            let hydrationHistoryResult: [HydrationLog]
            (definitions, links, routines, routineSchedules, routineRuns, habitPolicies, habitGroups, starterPackInstallations, hydrationLogs, target, sleepRecords, medications, medicationSchedules, medicationEvents, checkIns) = try await (
                goalsValue, linksValue, routinesValue, schedulesValue, runsValue, policiesValue, groupsValue, installationsValue,
                hydrationValue, targetValue, sleepValue, medicationsValue, medicationSchedulesValue, medicationEventsValue, checkInsValue
            )
            (trackers, trackerEntries, journalDays, hydrationHistoryResult) = try await (
                trackersValue, trackerEntriesValue, journalDaysValue, hydrationHistoryValue
            )
            hydrationHistory = hydrationHistoryResult
            correctionReceipts = try await correctionValues

            var unresolved: [LifeBoardMedicationEventValue] = []
            for event in medicationEvents where event.status == .unresolved || event.status == .scheduled {
                var copy = event
                if event.status == .scheduled,
                   Self.medicationWindowEnded(event, schedules: medicationSchedules, now: Date()) {
                    copy.status = .unresolved
                    copy.resolvedAt = nil
                    try await phaseIIRepository.saveMedicationEvent(copy)
                }
                unresolved.append(copy)
            }
            let goalSamples = try await goalSampleProvider?.samples(for: links, asOf: Date()) ?? []
            let progress = definitions.map { goal in
                goalService.progress(
                    for: goal,
                    links: links.filter { $0.goalID == goal.id },
                    samples: goalSamples
                )
            }
            let historyStart = Calendar.current.date(byAdding: .day, value: -29, to: bounds.start) ?? bounds.start
            let evidence = try await habitProjectionService?.occurrenceEvidence(
                from: historyStart,
                to: bounds.end,
                now: Date(),
                calendar: .current
            ) ?? [:]
            habitOccurrenceHistory = evidence
            let policyByHabitID = Dictionary(habitPolicies.map { ($0.habitID, $0) }, uniquingKeysWith: { _, newer in newer })
            let grades = evidence.keys.sorted(by: { $0.uuidString < $1.uuidString }).map { habitID in
                habitGradeEngine.evaluate(
                    habitID: habitID,
                    occurrences: evidence[habitID] ?? [],
                    policy: policyByHabitID[habitID] ?? HabitResiliencePolicy(habitID: habitID),
                    now: Date(),
                    calendar: .current
                )
            }
            let hydrationTotal = hydrationLogs.reduce(0) { partial, log in
                partial + HydrationMeasurementService.convert(log.amount, from: log.unit, to: .milliliters)
            }
            let targetML = target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) }
            let dueRoutines = Self.dueRoutines(
                routines: routines,
                schedules: routineSchedules,
                at: Date(),
                calendar: .current
            )
            let projections = Self.projections(
                hydrationLogs: hydrationLogs,
                medicationEvents: medicationEvents,
                checkIns: checkIns,
                sleepRecords: sleepRecords,
                routines: dueRoutines,
                routineRuns: routineRuns,
                goals: progress,
                habitGrades: grades,
                trackers: trackers,
                trackerEntries: trackerEntries.filter { $0.timestamp >= bounds.start && $0.timestamp < bounds.end },
                journalDays: journalDays.filter { $0.day >= bounds.start && $0.day < bounds.end },
                correctionReceipts: correctionReceipts,
                now: Date()
            )
            snapshot = TrackTodaySnapshot(
                unresolvedMedicationEvents: unresolved,
                habitGrades: grades,
                dueRoutines: dueRoutines,
                goals: progress,
                hydrationAmountMilliliters: hydrationLogs.isEmpty && target == nil ? nil : hydrationTotal,
                hydrationTargetMilliliters: targetML,
                context: projections.context,
                normalizedEvents: projections.events,
                completeness: .complete,
                generatedAt: Date()
            )
            if let running = routineRuns.first(where: { $0.status == .running }) { activeRoutineRun = running }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func quickAddHydration(_ milliliters: Double) async {
        do {
            try await repository.saveHydrationLog(.init(amount: milliliters, unit: .milliliters))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func setHydrationTarget(_ milliliters: Double) async {
        do {
            let existing = try await repository.fetchHydrationTarget()
            try await repository.saveHydrationTarget(.init(
                id: existing?.id ?? UUID(),
                amount: milliliters,
                unit: .milliliters,
                updatedAt: Date()
            ))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func correctHydration(_ log: HydrationLog, amountMilliliters: Double) async {
        var corrected = log
        corrected.amount = HydrationMeasurementService.convert(max(0, amountMilliliters), from: .milliliters, to: log.unit)
        corrected.correctedAt = Date()
        do {
            try await applyCorrection(previous: .hydration(log), corrected: .hydration(corrected))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteHydration(_ log: HydrationLog) async {
        do {
            try await repository.deleteHydrationLog(id: log.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        await saveMood(.init(mood: mood, energy: energy))
    }

    func saveMood(_ checkIn: LifeBoardMoodEnergyCheckInValue) async {
        do {
            if let previous = checkIns.first(where: { $0.id == checkIn.id }), previous != checkIn {
                try await applyCorrection(previous: .mood(previous), corrected: .mood(checkIn))
            } else {
                try await phaseIIRepository.saveMoodCheckIn(checkIn)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteMood(_ checkIn: LifeBoardMoodEnergyCheckInValue) async {
        do {
            try await phaseIIRepository.deleteMoodCheckIn(id: checkIn.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(event: LifeBoardMedicationEventValue, status: LifeBoardMedicationEventStatus) async {
        var value = event
        value.status = status
        value.resolvedAt = Date()
        do {
            try await applyCorrection(previous: .medication(event), corrected: .medication(value))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func snoozeMedication(event: LifeBoardMedicationEventValue, by interval: TimeInterval = 15 * 60) async {
        var original = event
        original.status = .snoozed
        original.resolvedAt = Date()
        let replacement = LifeBoardMedicationEventValue(
            medicationID: event.medicationID,
            scheduledAt: Date().addingTimeInterval(max(60, interval)),
            status: .scheduled,
            note: "Rescheduled from \(event.id.uuidString)"
        )
        do {
            try await phaseIIRepository.saveMedicationEvent(original)
            try await phaseIIRepository.saveMedicationEvent(replacement)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func medicationName(id: UUID) -> String { medications.first(where: { $0.id == id })?.name ?? "Medication" }

    func habitPolicy(for habitID: UUID) -> HabitResiliencePolicy {
        habitPolicies.first(where: { $0.habitID == habitID }) ?? HabitResiliencePolicy(habitID: habitID)
    }

    func saveHabitPolicy(_ policy: HabitResiliencePolicy) async {
        var updated = policy
        updated.updatedAt = Date()
        do {
            try await repository.saveHabitResiliencePolicy(updated)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func recoverHabit(habitID: UUID, day: PlanningDay) async -> HabitRecoveryReceipt? {
        var policy = habitPolicy(for: habitID)
        guard policy.recoveryEnabled else {
            errorMessage = "Recovery completions are disabled for this habit."
            return nil
        }
        guard policy.recoveryReceipts.contains(where: { $0.day == day }) == false else {
            return policy.recoveryReceipts.first(where: { $0.day == day })
        }
        guard let habitRecoveryMutationApplier else {
            errorMessage = "Habit recovery is unavailable until the canonical habit runtime finishes loading."
            return nil
        }

        do {
            let receipt = try await habitRecoveryMutationApplier.recover(habitID: habitID, day: day)
            policy.recoveryReceipts.removeAll { $0.day == day }
            policy.recoveryReceipts.append(receipt)
            policy.updatedAt = Date()
            do {
                try await repository.saveHabitResiliencePolicy(policy)
            } catch {
                // Do not leave an unlabelled completion behind if Track metadata
                // failed to persist.
                try? await habitRecoveryMutationApplier.revert(receipt)
                throw error
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
            return receipt
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func undoHabitRecovery(habitID: UUID, day: PlanningDay) async -> Bool {
        let original = habitPolicy(for: habitID)
        guard let receipt = original.recoveryReceipts.first(where: { $0.day == day }) else { return true }
        guard let habitRecoveryMutationApplier else {
            errorMessage = "Habit recovery is unavailable until the canonical habit runtime finishes loading."
            return false
        }
        var updated = original
        updated.recoveryReceipts.removeAll { $0.day == day }
        updated.updatedAt = Date()

        do {
            try await repository.saveHabitResiliencePolicy(updated)
            do {
                try await habitRecoveryMutationApplier.revert(receipt)
            } catch {
                // Restore the visible receipt if the canonical reversal fails.
                try? await repository.saveHabitResiliencePolicy(original)
                throw error
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveHabitGroup(_ group: HabitGroup) async {
        var value = group
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.title.isEmpty == false else { return }
        do {
            try await repository.saveHabitGroup(value)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteHabitGroup(_ group: HabitGroup) async {
        do {
            try await repository.deleteHabitGroup(id: group.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func startRoutine(_ routine: RoutineDefinition) async {
        let run = routineService.begin(routine, at: Date())
        activeRoutineRun = run
        do { try await repository.saveRoutineRun(run) }
        catch { errorMessage = error.localizedDescription }
    }

    func saveRoutineSchedule(_ schedule: RoutineSchedule) async {
        do {
            try await repository.saveRoutineSchedule(schedule)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveRoutine(
        existing: RoutineDefinition? = nil,
        title: String,
        steps: [RoutineStep],
        weekdays: Set<Int>,
        daypart: ResolvedDaypart?
    ) async {
        let normalized = steps.enumerated().map { index, step in
            RoutineStep(
                id: step.id,
                title: step.title,
                kind: step.kind,
                ordinal: index,
                duration: step.duration,
                isRequired: step.isRequired,
                isSkippable: step.isSkippable,
                linkedEntityID: step.linkedEntityID,
                linkedMutation: step.linkedMutation,
                choices: step.choices,
                branches: step.branches
            )
        }
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              normalized.isEmpty == false else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let routine = RoutineDefinition(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            version: existing.map { $0.version + 1 } ?? 1,
            steps: normalized,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        do {
            try await repository.saveRoutine(routine)
            let existingSchedule = existing.flatMap { definition in
                routineSchedules.first(where: { $0.routineID == definition.id })
            }
            try await repository.saveRoutineSchedule(.init(
                id: existingSchedule?.id ?? UUID(),
                routineID: routine.id,
                weekdays: weekdays,
                daypart: daypart,
                reminderTimeMinutes: existingSchedule?.reminderTimeMinutes,
                timeZoneIdentifier: existingSchedule?.timeZoneIdentifier ?? TimeZone.current.identifier,
                isEnabled: existingSchedule?.isEnabled ?? true,
                updatedAt: Date()
            ))
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func createRoutine(
        title: String,
        steps: [RoutineStep],
        weekdays: Set<Int>,
        daypart: ResolvedDaypart?
    ) async {
        await saveRoutine(existing: nil, title: title, steps: steps, weekdays: weekdays, daypart: daypart)
    }

    func archiveRoutine(_ routine: RoutineDefinition) async {
        var value = routine
        value.isArchived = true
        value.updatedAt = Date()
        do {
            try await repository.saveRoutine(value)
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteRoutine(_ routine: RoutineDefinition) async {
        guard activeRoutineRun?.routineID != routine.id else {
            errorMessage = "End the active run before deleting this routine."
            return
        }
        do {
            try await repository.deleteRoutine(id: routine.id)
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func advanceRoutine(response: String? = nil, skip: Bool = false) async {
        guard let activeRoutineRun else { return }
        let key = "\(activeRoutineRun.id.uuidString):\(activeRoutineRun.currentStepID?.uuidString ?? "end"):user"
        let transition = routineService.advance(run: activeRoutineRun, response: response, skip: skip, idempotencyKey: key, at: Date())
        do {
            if transition.didApplyEvent,
               let mutation = transition.linkedMutation,
               let targetID = transition.linkedEntityID {
                guard let linkedMutationApplier else {
                    throw NSError(
                        domain: "TrackFoundationStore.Routine",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "This linked step cannot be completed until its canonical task or habit service is available."]
                    )
                }
                let stepID = activeRoutineRun.currentStepID ?? transition.run.events.last?.stepID ?? UUID()
                var receipt = try await repository.fetchRoutineLinkedMutationReceipt(idempotencyKey: key)
                    ?? RoutineLinkedMutationReceipt(
                        runID: activeRoutineRun.id,
                        stepID: stepID,
                        mutation: mutation,
                        targetID: targetID,
                        idempotencyKey: key
                    )
                if receipt.status == .prepared {
                    try await repository.saveRoutineLinkedMutationReceipt(receipt)
                    if try await linkedMutationApplier.isApplied(mutation, targetID: targetID, at: Date()) {
                        receipt.status = .reconciled
                        receipt.reconciledAt = Date()
                    } else {
                        try await linkedMutationApplier.apply(mutation, targetID: targetID, at: Date())
                        receipt.status = .applied
                        receipt.appliedAt = Date()
                    }
                    try await repository.saveRoutineLinkedMutationReceipt(receipt)
                }
            }
            try await repository.saveRoutineRun(transition.run)
            self.activeRoutineRun = transition.run.status == .running ? transition.run : nil
            if transition.run.status != .running { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func abandonRoutine() async {
        guard let activeRoutineRun else { return }
        let run = routineService.abandon(run: activeRoutineRun, at: Date())
        self.activeRoutineRun = nil
        do { try await repository.saveRoutineRun(run); await load() }
        catch { errorMessage = error.localizedDescription }
    }

    func saveGoal(
        existing: GoalDefinition? = nil,
        title: String,
        type: GoalType,
        target: Double?,
        unit: String?,
        targetDate: Date?
    ) async {
        let normalizedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await repository.saveGoal(.init(
                id: existing?.id ?? UUID(),
                areaID: existing?.areaID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                targetValue: target,
                unitLabel: normalizedUnit.flatMap { $0.isEmpty ? nil : $0 },
                targetDate: targetDate,
                isArchived: existing?.isArchived ?? false,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            ))
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveGoal(_ goal: GoalDefinition) async {
        var archived = goal
        archived.isArchived = true
        archived.updatedAt = Date()
        do {
            try await repository.saveGoal(archived)
            await load()
            LifeBoardSystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteGoal(_ goal: GoalDefinition) async {
        do {
            try await repository.deleteGoal(id: goal.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveGoalLink(goalID: UUID, source: GoalLinkSource, sourceID: UUID) async {
        do {
            try await repository.saveGoalLink(.init(goalID: goalID, source: source, sourceID: sourceID))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveSleep(bedtime: Date, wakeTime: Date, rest: Int?, interruptions: Int, notes: String?) async {
        await saveSleep(.init(
            bedtime: bedtime, wakeTime: wakeTime, perceivedRest: rest,
            interruptionCount: interruptions, notes: notes
        ))
    }

    func saveSleep(_ record: SleepContextRecord) async {
        do {
            if let previous = sleepRecords.first(where: { $0.id == record.id }), previous != record {
                try await applyCorrection(previous: .sleep(previous), corrected: .sleep(record))
            } else {
                try await repository.saveSleepContextRecord(record)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteSleep(_ record: SleepContextRecord) async {
        do {
            try await repository.deleteSleepContextRecord(id: record.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func installStarterPack(_ preview: StarterPackPreview) async {
        let selected = preview.items.filter(\.isSelected)
        var createdIDs: [StarterPackItemKind: Set<UUID>] = [:]
        var createdGoals: [GoalDefinition] = []
        var createdRoutines: [RoutineDefinition] = []
        do {
            for item in selected {
                switch item.kind {
                case .goal:
                    let goal = GoalDefinition(title: item.title, type: .completion)
                    try await repository.saveGoal(goal)
                    createdGoals.append(goal)
                    createdIDs[.goal, default: []].insert(goal.id)
                case .routine:
                    let steps = Self.steps(for: preview.pack)
                    let routine = RoutineDefinition(title: item.title, steps: steps)
                    try await repository.saveRoutine(routine)
                    try await repository.saveRoutineSchedule(Self.defaultSchedule(for: preview.pack, routineID: routine.id))
                    createdRoutines.append(routine)
                    createdIDs[.routine, default: []].insert(routine.id)
                case .habit, .reminder:
                    guard let starterPackMutationApplier else {
                        throw NSError(
                            domain: "LifeBoard.StarterPack",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Habit creation is temporarily unavailable. No starter-pack receipt was saved."]
                        )
                    }
                    let id = try await starterPackMutationApplier.createHabit(
                        title: item.title,
                        pack: preview.pack,
                        itemKind: item.kind
                    )
                    createdIDs[item.kind, default: []].insert(id)
                }
            }
            try await repository.saveStarterPackInstallation(.init(pack: preview.pack, createdIDs: createdIDs))
            await load()
        } catch {
            for var goal in createdGoals {
                goal.isArchived = true
                goal.updatedAt = Date()
                try? await repository.saveGoal(goal)
            }
            for var routine in createdRoutines {
                routine.isArchived = true
                routine.updatedAt = Date()
                try? await repository.saveRoutine(routine)
            }
            if let starterPackMutationApplier {
                let habitIDs = (createdIDs[.habit] ?? []).union(createdIDs[.reminder] ?? [])
                for id in habitIDs { try? await starterPackMutationApplier.archiveHabit(id: id) }
            }
            errorMessage = error.localizedDescription
            await load()
        }
    }

    func removeStarterPack(_ installation: StarterPackInstallation) async {
        guard installation.removedAt == nil else { return }
        do {
            let goalIDs = installation.createdIDs[.goal] ?? []
            for var goal in definitions where goalIDs.contains(goal.id) {
                goal.isArchived = true
                goal.updatedAt = Date()
                try await repository.saveGoal(goal)
            }
            let routineIDs = installation.createdIDs[.routine] ?? []
            for var routine in routines where routineIDs.contains(routine.id) {
                routine.isArchived = true
                routine.updatedAt = Date()
                try await repository.saveRoutine(routine)
            }
            if let starterPackMutationApplier {
                let habitIDs = (installation.createdIDs[.habit] ?? []).union(installation.createdIDs[.reminder] ?? [])
                for id in habitIDs {
                    try await starterPackMutationApplier.archiveHabit(id: id)
                }
            }
            var removed = installation
            removed.removedAt = Date()
            try await repository.saveStarterPackInstallation(removed)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func activeCorrection(domain: TrackCorrectionDomain, sourceID: UUID) -> TrackCorrectionReceipt? {
        correctionReceipts
            .filter { $0.domain == domain && $0.sourceID == sourceID && $0.isReversed == false }
            .max { lhs, rhs in lhs.appliedAt < rhs.appliedAt }
    }

    func undoCorrection(_ receipt: TrackCorrectionReceipt) async {
        do {
            guard activeCorrection(domain: receipt.domain, sourceID: receipt.sourceID)?.id == receipt.id else {
                throw TrackCorrectionReceiptFailure.staleReceipt
            }
            try await saveCorrectionPayload(receipt.previous)
            var reversed = receipt
            reversed.reversedAt = Date()
            do {
                try await correctionReceiptRepository.saveTrackCorrectionReceipt(reversed)
            } catch {
                try? await saveCorrectionPayload(receipt.corrected)
                throw error
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func applyCorrection(previous: TrackCorrectionPayload, corrected: TrackCorrectionPayload) async throws {
        guard previous != corrected else { return }
        let receipt = try TrackCorrectionReceipt.deterministic(previous: previous, corrected: corrected)
        try await saveCorrectionPayload(corrected)
        do {
            try await correctionReceiptRepository.saveTrackCorrectionReceipt(receipt)
        } catch {
            try? await saveCorrectionPayload(previous)
            throw error
        }
    }

    private func saveCorrectionPayload(_ payload: TrackCorrectionPayload) async throws {
        switch payload {
        case .hydration(let value): try await repository.saveHydrationLog(value)
        case .sleep(let value): try await repository.saveSleepContextRecord(value)
        case .mood(let value): try await phaseIIRepository.saveMoodCheckIn(value)
        case .medication(let value): try await phaseIIRepository.saveMedicationEvent(value)
        case .tracker(let value): try await phaseIIRepository.saveTrackerEntry(value)
        case .fasting(let value): try await phaseIIRepository.saveFastingSession(value)
        }
    }

    private static func todayBounds() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: Date())
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

    private static func medicationWindowEnded(
        _ event: LifeBoardMedicationEventValue,
        schedules: [LifeBoardMedicationScheduleValue],
        now: Date
    ) -> Bool {
        let schedule = schedules.first { $0.medicationID == event.medicationID }
        let windowDuration = schedule.map { max(0, $0.windowEndMinutes - $0.windowStartMinutes) * 60 } ?? 0
        return now > event.scheduledAt.addingTimeInterval(TimeInterval(windowDuration))
    }

    private static func steps(for pack: StarterPack) -> [RoutineStep] {
        switch pack {
        case .morningFoundation:
            [.init(title: "Name your energy", kind: .checkIn, ordinal: 0), .init(title: "Choose today's anchor", kind: .choice, ordinal: 1, choices: ["Focus", "Care", "Recovery"])]
        case .workdayReset:
            [.init(title: "Close distractions", kind: .instruction, ordinal: 0), .init(title: "Breathe for two minutes", kind: .timer, ordinal: 1, duration: 120)]
        case .lowEnergyRecovery:
            [.init(title: "Name what you need", kind: .choice, ordinal: 0, choices: ["Rest", "Water", "A smaller step"]), .init(title: "Take one gentle action", kind: .instruction, ordinal: 1)]
        case .medicationSupport:
            [.init(title: "Check your medication schedule", kind: .instruction, ordinal: 0), .init(title: "Record the outcome", kind: .checkIn, ordinal: 1)]
        case .eveningWindDown:
            [.init(title: "Close the day", kind: .instruction, ordinal: 0), .init(title: "Reflect briefly", kind: .checkIn, ordinal: 1, isRequired: false, isSkippable: true)]
        }
    }

    private static func defaultSchedule(for pack: StarterPack, routineID: UUID) -> RoutineSchedule {
        let daypart: ResolvedDaypart
        switch pack {
        case .morningFoundation: daypart = .morning
        case .workdayReset, .lowEnergyRecovery, .medicationSupport: daypart = .afternoon
        case .eveningWindDown: daypart = .evening
        }
        return RoutineSchedule(routineID: routineID, weekdays: Set(1...7), daypart: daypart)
    }

    private static func dueRoutines(
        routines: [RoutineDefinition],
        schedules: [RoutineSchedule],
        at date: Date,
        calendar: Calendar
    ) -> [RoutineDefinition] {
        let weekday = calendar.component(.weekday, from: date)
        let daypart = LifeBoardDaypartResolver.resolve(selection: .automatic, at: date, calendar: calendar)
        let dueIDs = Set(schedules.filter { schedule in
            schedule.isEnabled
                && schedule.weekdays.contains(weekday)
                && schedule.daypart == daypart
        }.map(\.routineID))
        return routines.filter { dueIDs.contains($0.id) }
    }

    private static func projections(
        hydrationLogs: [HydrationLog],
        medicationEvents: [LifeBoardMedicationEventValue],
        checkIns: [LifeBoardMoodEnergyCheckInValue],
        sleepRecords: [SleepContextRecord],
        routines: [RoutineDefinition],
        routineRuns: [RoutineRun],
        goals: [GoalProgressSnapshot],
        habitGrades: [HabitGradeSnapshot],
        trackers: [LifeBoardTrackerDefinitionValue],
        trackerEntries: [LifeBoardTrackerEntryValue],
        journalDays: [LifeBoardJournalDayValue],
        correctionReceipts: [TrackCorrectionReceipt],
        now: Date
    ) -> (context: [TrackContextEnvelope], events: [NormalizedLifeEvent]) {
        let zone = TimeZone.current
        func day(_ date: Date) -> PlanningDay { PlanningDay(date: date, timeZone: zone) }
        let policy = EvidenceAuthorizationPolicy()
        let projector = NormalizedLifeEventProjector(policy: policy, timeZone: zone)
        var context: [TrackContextEnvelope] = []
        var events: [NormalizedLifeEvent] = []

        func makeEvent(
            id: String,
            sourceID: UUID,
            domain: String,
            kind: String,
            occurredAt: Date,
            numericValue: Double?,
            completeness: ProjectionCompleteness,
            sensitivity: DataSensitivity,
            provenance: String,
            evidence: [EvidenceReference],
            receipt: MutationReceiptReference? = nil,
            reversal: ReversalState = .notApplicable
        ) -> NormalizedLifeEvent {
            NormalizedLifeEvent(
                id: id, sourceID: sourceID, domain: domain, kind: kind,
                occurredAt: occurredAt, localDay: day(occurredAt), numericValue: numericValue,
                completeness: completeness, sensitivity: sensitivity,
                allowedDestinations: policy.allowedDestinations(domain: domain, sensitivity: sensitivity),
                provenance: provenance, evidence: evidence,
                freshness: policy.freshness(domain: domain, occurredAt: occurredAt, now: now),
                authorization: .authorized, redaction: .none,
                receipt: receipt, reversal: reversal
            )
        }

        func correctionMetadata(
            domain: TrackCorrectionDomain,
            sourceID: UUID
        ) -> (MutationReceiptReference?, ReversalState) {
            guard let receipt = correctionReceipts
                .filter({ $0.domain == domain && $0.sourceID == sourceID })
                .max(by: { lhs, rhs in lhs.appliedAt < rhs.appliedAt }) else {
                return (nil, .notApplicable)
            }
            return (receipt.reference, receipt.reversalState)
        }

        for log in hydrationLogs {
            let correction = correctionMetadata(domain: .hydration, sourceID: log.id)
            let destinations: Set<LifeBoardDestination> = [.home, .track, .insights]
            context.append(.init(
                id: "hydration:\(log.id.uuidString)", sourceID: log.id, sourceType: "hydration",
                timestamp: log.timestamp, localDay: day(log.timestamp), completeness: .complete,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: destinations, provenance: "LifeBoard hydration log"
            ))
            events.append(projector.event(
                sourceID: log.id, domain: "hydration", kind: "recorded", occurredAt: log.timestamp,
                numericValue: HydrationMeasurementService.milliliters(log.amount, unit: log.unit),
                provenance: "LifeBoard hydration log", evidenceDisplay: "Hydration log",
                receipt: correction.0, reversal: correction.1, now: now
            ))
        }
        for event in medicationEvents {
            let correction = correctionMetadata(domain: .medication, sourceID: event.id)
            context.append(.init(
                id: "medication:\(event.id.uuidString)", sourceID: event.id, sourceType: "medicationEvent",
                timestamp: event.scheduledAt, localDay: day(event.scheduledAt), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.home, .track], provenance: "LifeBoard medication event"
            ))
            events.append(makeEvent(
                id: "medication:\(event.id.uuidString)", sourceID: event.id, domain: "medication",
                kind: event.status.rawValue, occurredAt: event.scheduledAt, numericValue: nil,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "LifeBoard medication event",
                evidence: [EvidenceReference(sourceID: event.id, kind: "medication", display: "Medication event")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for checkIn in checkIns {
            let correction = correctionMetadata(domain: .mood, sourceID: checkIn.id)
            let timestamp = checkIn.createdAt
            context.append(.init(
                id: "mood:\(checkIn.id.uuidString)", sourceID: checkIn.id, sourceType: "moodEnergy",
                timestamp: timestamp, localDay: day(timestamp), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.track], provenance: "LifeBoard mood and energy check-in"
            ))
            let moodValence = LifeBoardJournalMood.dialOrder.firstIndex(of: checkIn.mood).map { Double($0 - 4) }
            events.append(makeEvent(
                id: "mood:\(checkIn.id.uuidString)", sourceID: checkIn.id, domain: "mood",
                kind: checkIn.mood.rawValue, occurredAt: timestamp, numericValue: moodValence,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "LifeBoard mood and energy check-in",
                evidence: [EvidenceReference(sourceID: checkIn.id, kind: "mood", display: "Mood & energy check-in")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for record in sleepRecords {
            let correction = correctionMetadata(domain: .sleep, sourceID: record.id)
            context.append(.init(
                id: "sleep:\(record.id.uuidString)", sourceID: record.id, sourceType: "sleepContext",
                timestamp: record.createdAt, localDay: day(record.createdAt), completeness: .complete,
                sensitivity: .privateSensitive, isAuthorized: true,
                allowedDestinations: [.track], provenance: "Manual LifeBoard sleep context"
            ))
            events.append(makeEvent(
                id: "sleep:\(record.id.uuidString)", sourceID: record.id, domain: "sleep",
                kind: "context", occurredAt: record.createdAt, numericValue: nil,
                completeness: .complete, sensitivity: .privateSensitive,
                provenance: "Manual LifeBoard sleep context",
                evidence: [EvidenceReference(sourceID: record.id, kind: "sleep", display: "Sleep context")],
                receipt: correction.0, reversal: correction.1
            ))
        }
        for routine in routines {
            context.append(.init(
                id: "routine:\(routine.id.uuidString)", sourceID: routine.id, sourceType: "dueRoutine",
                timestamp: now, localDay: day(now), completeness: .complete,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: [.home, .track, .plan], provenance: "LifeBoard routine schedule"
            ))
            events.append(makeEvent(
                id: "routine:\(routine.id.uuidString)", sourceID: routine.id, domain: "routine",
                kind: "due", occurredAt: now, numericValue: nil,
                completeness: .complete, sensitivity: .privateStandard,
                provenance: "LifeBoard routine schedule",
                evidence: [EvidenceReference(sourceID: routine.id, kind: "routine", display: routine.title)]
            ))
        }
        for run in routineRuns {
            events.append(projector.event(
                sourceID: run.id, domain: "routine", kind: run.status.rawValue,
                occurredAt: run.endedAt ?? run.updatedAt, provenance: "LifeBoard routine run",
                evidenceDisplay: run.versionSnapshot.title, evidenceRouteID: run.routineID, now: now
            ))
        }
        for grade in habitGrades {
            events.append(projector.event(
                sourceID: grade.habitID, domain: "habit", kind: "thirty_day_grade",
                occurredAt: grade.generatedAt, numericValue: grade.grade,
                completeness: grade.grade == nil ? .partial : .complete,
                provenance: "Canonical 30-day habit occurrence history",
                evidenceDisplay: "Habit history", now: now
            ))
        }
        let trackerByID = Dictionary(uniqueKeysWithValues: trackers.map { ($0.id, $0) })
        for entry in trackerEntries {
            let definition = trackerByID[entry.trackerID]
            let correction = correctionMetadata(domain: .tracker, sourceID: entry.id)
            events.append(projector.event(
                sourceID: entry.id, domain: "tracker", kind: definition?.kind.rawValue ?? "entry",
                occurredAt: entry.timestamp,
                numericValue: entry.numericValue ?? entry.booleanValue.map { $0 ? 1 : 0 },
                provenance: "LifeBoard tracker entry",
                evidenceDisplay: definition?.title ?? "Tracker entry", evidenceRouteID: entry.trackerID,
                receipt: correction.0, reversal: correction.1, now: now
            ))
        }
        for journal in journalDays {
            // The shared exclusion contract applies before a journal source
            // can become Eva evidence, even when this projection carries only
            // a display-safe identity and no journal text.
            guard journal.aiExclusion.permitsAssistantEvidence else { continue }
            events.append(projector.event(
                sourceID: journal.id, domain: "journal", kind: "day_updated",
                occurredAt: journal.updatedAt, sensitivity: .privateSensitive,
                provenance: "Private LifeBoard Journal day",
                evidenceDisplay: "Journal entry", now: now
            ))
        }
        for goal in goals {
            let completeness: ProjectionCompleteness = goal.missingLinkCount == 0 ? .complete : .partial
            context.append(.init(
                id: "goal:\(goal.goalID.uuidString)", sourceID: goal.goalID, sourceType: "goalProgress",
                timestamp: now, localDay: day(now),
                completeness: completeness,
                sensitivity: .privateStandard, isAuthorized: true,
                allowedDestinations: [.home, .track, .insights], provenance: "Explicit LifeBoard goal links"
            ))
            events.append(makeEvent(
                id: "goal:\(goal.goalID.uuidString)", sourceID: goal.goalID, domain: "goal",
                kind: "progress", occurredAt: now, numericValue: goal.progressFraction,
                completeness: completeness, sensitivity: .privateStandard,
                provenance: "Explicit LifeBoard goal links",
                evidence: [EvidenceReference(sourceID: goal.goalID, kind: "goal", display: "Goal progress")]
            ))
        }
        return (context, events)
    }
}
