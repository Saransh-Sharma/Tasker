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
    private(set) var goalLinks: [GoalLink] = []
    private(set) var routines: [RoutineDefinition] = []
    private(set) var routineSchedules: [RoutineSchedule] = []
    private(set) var routineRuns: [RoutineRun] = []
    private(set) var habitPolicies: [HabitResiliencePolicy] = []
    private(set) var habitGroups: [HabitGroup] = []
    private(set) var habitOccurrenceHistory: [UUID: [HabitOccurrenceEvidence]] = [:]
    private(set) var starterPackInstallations: [StarterPackInstallation] = []
    private(set) var medications: [MedicationDefinitionValue] = []
    private(set) var medicationSchedules: [MedicationScheduleValue] = []
    private(set) var checkIns: [MoodEnergyCheckInValue] = []
    private(set) var sleepRecords: [SleepContextRecord] = []
    private(set) var hydrationLogs: [HydrationLog] = []
    private(set) var hydrationHistory: [HydrationLog] = []
    private(set) var correctionReceipts: [TrackCorrectionReceipt] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var activeRoutineRun: RoutineRun?

    let repository: any TrackFoundationRepository
    let phaseIIRepository: any PhaseIIRepository
    private let trackerService: TrackerDefinitionService
    private let medicationService: MedicationScheduleService
    private let routineService: any RoutineExecutionService
    private let routineValidator: RoutineValidator
    private let goalService: any GoalProgressService
    private let goalLifecycleService: GoalLifecycleService
    private let goalSampleProvider: (any GoalSampleRepository)?
    private let habitProjectionService: (any TrackHabitProjectionService)?
    private let habitGradeEngine: any HabitGradeService
    private let linkedMutationApplier: (any RoutineLinkedMutationApplying)?
    private let starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)?
    private let habitRecoveryMutationApplier: (any HabitRecoveryMutationApplying)?
    private let correctionReceiptRepository: any TrackCorrectionReceiptRepository

    init(
        repository: any TrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        routineService: any RoutineExecutionService = DefaultRoutineExecutionService(),
        goalService: any GoalProgressService = DefaultGoalProgressService(),
        goalSampleProvider: (any GoalSampleRepository)? = nil,
        habitProjectionService: (any TrackHabitProjectionService)? = nil,
        habitGradeEngine: any HabitGradeService = DefaultHabitGradeService(),
        linkedMutationApplier: (any RoutineLinkedMutationApplying)? = nil,
        starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)? = nil,
        habitRecoveryMutationApplier: (any HabitRecoveryMutationApplying)? = nil,
        correctionReceiptRepository: any TrackCorrectionReceiptRepository = LocalTrackCorrectionReceiptRepository.shared
    ) {
        self.repository = repository
        self.phaseIIRepository = phaseIIRepository
        trackerService = TrackerDefinitionService(repository: phaseIIRepository)
        medicationService = MedicationScheduleService(repository: phaseIIRepository)
        self.routineService = routineService
        routineValidator = RoutineValidator()
        self.goalService = goalService
        goalLifecycleService = GoalLifecycleService(repository: repository)
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
            let medicationEvents: [MedicationEventValue]
            let trackers: [TrackerDefinitionValue]
            let trackerEntries: [TrackerEntryValue]
            let journalDays: [JournalDayValue]
            let hydrationHistoryResult: [HydrationLog]
            (definitions, links, routines, routineSchedules, routineRuns, habitPolicies, habitGroups, starterPackInstallations, hydrationLogs, target, sleepRecords, medications, medicationSchedules, medicationEvents, checkIns) = try await (
                goalsValue, linksValue, routinesValue, schedulesValue, runsValue, policiesValue, groupsValue, installationsValue,
                hydrationValue, targetValue, sleepValue, medicationsValue, medicationSchedulesValue, medicationEventsValue, checkInsValue
            )
            goalLinks = links
            (trackers, trackerEntries, journalDays, hydrationHistoryResult) = try await (
                trackersValue, trackerEntriesValue, journalDaysValue, hydrationHistoryValue
            )
            hydrationHistory = hydrationHistoryResult
            correctionReceipts = try await correctionValues

            var unresolved: [MedicationEventValue] = []
            for event in medicationEvents where event.status == .unresolved || event.status == .scheduled {
                var copy = event
                if event.status == .scheduled,
                   Self.medicationWindowEnded(event, schedules: medicationSchedules, now: Date()) {
                    copy.status = .unresolved
                    copy.resolvedAt = nil
                    if let medication = medications.first(where: { $0.id == copy.medicationID }) {
                        try await medicationService.saveEvent(medication: medication, event: copy)
                    }
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
            if let recoverable = routineRuns.first(where: {
                $0.status == .running || $0.status == .paused || $0.status == .interrupted
            }) {
                activeRoutineRun = recoverable
                await RoutineLiveActivityCoordinator.shared.synchronize(run: recoverable)
            } else {
                activeRoutineRun = nil
                await RoutineLiveActivityCoordinator.shared.endOrphanedActivities(except: nil)
            }
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

    func saveMood(_ mood: JournalMood, energy: Int?) async {
        await saveMood(.init(mood: mood, energy: energy))
    }

    /// Reports whether the check-in reached disk, so a composer can show a
    /// truthful commit phase. `@discardableResult` keeps Void call sites intact.
    @discardableResult
    func saveMood(_ checkIn: MoodEnergyCheckInValue) async -> Bool {
        do {
            if let previous = checkIns.first(where: { $0.id == checkIn.id }), previous != checkIn {
                try await applyCorrection(previous: .mood(previous), corrected: .mood(checkIn))
            } else {
                try await phaseIIRepository.saveMoodCheckIn(checkIn)
            }
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteMood(_ checkIn: MoodEnergyCheckInValue) async {
        do {
            try await phaseIIRepository.deleteMoodCheckIn(id: checkIn.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(event: MedicationEventValue, status: MedicationEventStatus) async {
        do {
            guard let medication = medications.first(where: { $0.id == event.medicationID }) else {
                throw MedicationScheduleServiceError.eventOutsideActiveRange
            }
            let value = try await medicationService.resolve(
                medication: medication,
                event: event,
                as: status
            )
            try await applyCorrection(previous: .medication(event), corrected: .medication(value))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func snoozeMedication(event: MedicationEventValue, by interval: TimeInterval = 15 * 60) async {
        var original = event
        original.status = .snoozed
        original.resolvedAt = Date()
        let replacement = MedicationEventValue(
            medicationID: event.medicationID,
            scheduledAt: Date().addingTimeInterval(max(60, interval)),
            status: .scheduled,
            note: "Rescheduled from \(event.id.uuidString)"
        )
        do {
            guard let medication = medications.first(where: { $0.id == event.medicationID }) else {
                throw MedicationScheduleServiceError.eventOutsideActiveRange
            }
            try await medicationService.saveEvent(medication: medication, event: original)
            do {
                try await medicationService.saveEvent(medication: medication, event: replacement)
            } catch {
                try? await medicationService.saveEvent(medication: medication, event: event)
                throw error
            }
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
        do {
            try await repository.saveRoutineRun(run)
            activeRoutineRun = run
            await RoutineLiveActivityCoordinator.shared.synchronize(run: run)
        } catch {
            activeRoutineRun = nil
            errorMessage = error.localizedDescription
        }
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
        let validation = routineValidator.validate(routine)
        guard validation.isValid else {
            errorMessage = Self.routineValidationMessage(validation)
            return
        }
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
            SystemSurfaceRefresher.requestRefreshSoon()
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
            SystemSurfaceRefresher.requestRefreshSoon()
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
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func advanceRoutine(response: String? = nil, skip: Bool = false) async {
        guard let activeRoutineRun else { return }
        let key = "\(activeRoutineRun.id.uuidString):\(activeRoutineRun.currentStepID?.uuidString ?? "end"):user"
        let command: RoutineRunCommand = skip
            ? .skip(reason: response ?? "Skipped by user", idempotencyKey: key)
            : .advance(response: response, idempotencyKey: key)
        await applyRoutineCommand(command)
    }

    func pauseRoutine() async {
        await applyRoutineCommand(.pause)
    }

    func resumeRoutine() async {
        await applyRoutineCommand(.resume)
    }

    func interruptRoutine() async {
        await applyRoutineCommand(.interrupt)
    }

    private func applyRoutineCommand(_ command: RoutineRunCommand) async {
        guard let activeRoutineRun else { return }
        let transition = routineService.apply(command: command, to: activeRoutineRun, at: Date())
        let idempotencyKey: String? = switch command {
        case let .advance(_, key), let .skip(_, key): key
        case .pause, .resume, .interrupt, .stop: nil
        }
        do {
            if transition.didApplyEvent,
               let mutation = transition.linkedMutation,
               let targetID = transition.linkedEntityID,
               let idempotencyKey {
                guard let linkedMutationApplier else {
                    throw NSError(
                        domain: "TrackFoundationStore.Routine",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "This linked step cannot be completed until its canonical task or habit service is available."]
                    )
                }
                let stepID = activeRoutineRun.currentStepID ?? transition.run.events.last?.stepID ?? UUID()
                var receipt = try await repository.fetchRoutineLinkedMutationReceipt(idempotencyKey: idempotencyKey)
                    ?? RoutineLinkedMutationReceipt(
                        runID: activeRoutineRun.id,
                        stepID: stepID,
                        mutation: mutation,
                        targetID: targetID,
                        idempotencyKey: idempotencyKey
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
            await RoutineLiveActivityCoordinator.shared.synchronize(run: transition.run)
            self.activeRoutineRun = switch transition.run.status {
            case .running, .paused, .interrupted: transition.run
            case .completed, .partial, .abandoned, .skipped: nil
            }
            if transition.run.status == .completed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func abandonRoutine() async {
        await applyRoutineCommand(.stop)
    }

    func saveGoal(
        existing: GoalDefinition? = nil,
        title: String,
        type: GoalType,
        target: Double?,
        unit: String?,
        targetDate: Date?,
        intent: GoalIntent? = nil,
        baseline: Double? = nil,
        confidence: GoalConfidence? = nil,
        whyItMatters: String? = nil,
        checkInCadence: GoalCheckInCadence? = nil
    ) async {
        await saveGoal(
            existing: existing,
            draft: .init(
                areaID: existing?.areaID,
                title: title,
                type: type,
                intent: intent ?? existing?.effectiveIntent ?? .outcome,
                targetValue: target,
                baselineValue: baseline ?? existing?.baselineValue,
                unitLabel: unit,
                targetDate: targetDate,
                confidence: confidence
                    ?? existing?.confidenceRaw.flatMap(GoalConfidence.init(rawValue:)),
                whyItMatters: whyItMatters ?? existing?.whyItMatters,
                checkInCadence: checkInCadence
                    ?? existing?.checkInCadenceRaw.flatMap(GoalCheckInCadence.init(rawValue:))
                    ?? .weekly
            )
        )
    }

    func saveGoal(
        existing: GoalDefinition? = nil,
        draft: GoalDraft
    ) async {
        do {
            _ = try await goalLifecycleService.save(
                draft: draft,
                existing: existing
            )
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveGoal(_ goal: GoalDefinition) async {
        do {
            _ = try await goalLifecycleService.transition(goal, to: .archived, reason: "Archived by user")
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = error.localizedDescription }
    }

    func transitionGoal(
        _ goal: GoalDefinition,
        to status: GoalStatus,
        reason: String? = nil
    ) async -> GoalTransitionReceipt? {
        do {
            let receipt = try await goalLifecycleService.transition(goal, to: status, reason: reason)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
            return receipt
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func undoGoalTransition(_ receipt: GoalTransitionReceipt) async {
        do {
            _ = try await goalLifecycleService.undo(receipt)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
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
        case .medication(let value):
            guard let medication = medications.first(where: { $0.id == value.medicationID }) else {
                throw MedicationScheduleServiceError.eventOutsideActiveRange
            }
            try await medicationService.saveEvent(medication: medication, event: value)
        case .tracker(let value):
            try await trackerService.saveEntry(value)
        case .fasting(let value): try await phaseIIRepository.saveFastingSession(value)
        }
    }

    private static func todayBounds() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: Date())
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

    private static func routineValidationMessage(_ report: RoutineValidationReport) -> String {
        guard let first = report.issues.first else { return "This routine is ready." }
        return switch first {
        case .noSteps:
            "Add at least one step."
        case .emptyTitle:
            "Every routine step needs a title."
        case .duplicateStepID:
            "Two steps share the same identity. Recreate one of them."
        case .duplicateOrdinal:
            "Two steps occupy the same position. Reorder the routine and try again."
        case .invalidChoice:
            "Choice labels must be unique, non-empty, and match their branch rules."
        case .branchSourceMismatch:
            "A branch is attached to the wrong source step."
        case .missingBranchDestination:
            "A branch points to a step that no longer exists."
        case .unreachableStep:
            "A step cannot be reached from the start of this routine."
        case .loop:
            "This routine contains a loop. Choose a forward destination."
        case .missingLinkedEntity:
            "A linked step needs a task or habit."
        case .linkedEntityUnavailable:
            "A linked task or habit is no longer available."
        }
    }

    private static func medicationWindowEnded(
        _ event: MedicationEventValue,
        schedules: [MedicationScheduleValue],
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
        let daypart = DaypartResolver.resolve(selection: .automatic, at: date, calendar: calendar)
        let dueIDs = Set(schedules.filter { schedule in
            schedule.isEnabled
                && schedule.weekdays.contains(weekday)
                && schedule.daypart == daypart
        }.map(\.routineID))
        return routines.filter { dueIDs.contains($0.id) }
    }

    private static func projections(
        hydrationLogs: [HydrationLog],
        medicationEvents: [MedicationEventValue],
        checkIns: [MoodEnergyCheckInValue],
        sleepRecords: [SleepContextRecord],
        routines: [RoutineDefinition],
        routineRuns: [RoutineRun],
        goals: [GoalProgressSnapshot],
        habitGrades: [HabitGradeSnapshot],
        trackers: [TrackerDefinitionValue],
        trackerEntries: [TrackerEntryValue],
        journalDays: [JournalDayValue],
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
            let destinations: Set<Destination> = [.home, .track, .insights]
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
            let moodValence = JournalMood.dialOrder.firstIndex(of: checkIn.mood).map { Double($0 - 4) }
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

enum RoutineLiveActivityAction: String, Codable, Hashable, Sendable {
    case pause
    case resume
    case stop

    var runCommand: RoutineRunCommand {
        switch self {
        case .pause: .pause
        case .resume: .resume
        case .stop: .stop
        }
    }
}

struct RoutineLiveActivityCommand: Codable, Hashable, Sendable {
    var id: UUID
    var runID: UUID
    var action: RoutineLiveActivityAction
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import OSLog

actor RoutineLiveActivityCoordinator {
    static let shared = RoutineLiveActivityCoordinator()
    private let logger = Logger(
        subsystem: "com.saransh1337.To-Do-List",
        category: "RoutineLiveActivity"
    )

    @discardableResult
    func synchronize(run: RoutineRun) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let state = contentState(for: run)
        let content = ActivityContent(state: state, staleDate: nil)
        let existing = Activity<RoutineActivityAttributes>.activities.first {
            $0.attributes.runID == run.id
        }
        let isTerminal = switch run.status {
        case .completed, .partial, .abandoned, .skipped: true
        case .running, .paused, .interrupted: false
        }
        if isTerminal {
            if let existing {
                await existing.end(content, dismissalPolicy: .immediate)
            }
            return true
        }
        if let existing {
            await existing.update(content)
            return true
        }
        do {
            _ = try Activity.request(
                attributes: RoutineActivityAttributes(
                    runID: run.id,
                    routineID: run.routineID,
                    title: run.versionSnapshot.title
                ),
                content: content,
                pushType: nil
            )
            return true
        } catch {
            logger.error(
                "Live Activity start failed; canonical routine state is unchanged: \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func endOrphanedActivities(except runID: UUID?) async {
        for activity in Activity<RoutineActivityAttributes>.activities
        where activity.attributes.runID != runID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(
        for run: RoutineRun
    ) -> RoutineActivityAttributes.ContentState {
        let currentTitle = run.currentStepID.flatMap { currentID in
            run.versionSnapshot.steps.first(where: { $0.id == currentID })?.title
        } ?? "Review complete"
        return .init(
            status: run.status.rawValue,
            stepTitle: currentTitle,
            completedStepCount: run.events.count,
            totalStepCount: run.versionSnapshot.steps.count,
            updatedAt: run.updatedAt
        )
    }
}

enum RoutineLiveActivityDeepLink {
    static func command(from url: URL) -> RoutineLiveActivityCommand? {
        guard
            url.scheme?.lowercased() == "lifeboard",
            url.host?.lowercased() == "routine",
            let runID = url.pathComponents.last.flatMap(UUID.init(uuidString:)),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let rawAction = components.queryItems?.first(where: { $0.name == "command" })?.value,
            let action = RoutineLiveActivityAction(rawValue: rawAction),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                .flatMap(UUID.init(uuidString:))
        else { return nil }
        return RoutineLiveActivityCommand(id: token, runID: runID, action: action)
    }
}
#else
actor RoutineLiveActivityCoordinator {
    static let shared = RoutineLiveActivityCoordinator()
    @discardableResult
    func synchronize(run: RoutineRun) async -> Bool { false }
    func endOrphanedActivities(except runID: UUID?) async {}
}

enum RoutineLiveActivityDeepLink {
    static func command(from url: URL) -> RoutineLiveActivityCommand? { nil }
}
#endif
