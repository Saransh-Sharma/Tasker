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
    /// The receipt for the last quick water log, with the log it can undo.
    private(set) var hydrationReceipt: ActionReceiptPresentation?
    private var undoableHydrationLog: HydrationLog?
    /// Which control wrote the last quick water log, so its receipt appears
    /// under that control rather than somewhere else on the screen.
    private(set) var hydrationReceiptAnchor: TrackHydrationReceiptAnchor = .quickLog
    /// The last record deleted from a history row or composer, with the write
    /// that puts it back. Deleting a log is reversible, so it runs at once and
    /// offers Undo instead of asking first (DESIGN.md launch contract 1).
    private(set) var deletionReceipt: TrackDeletionReceipt?
    /// What the last routine run did, shown after the runner closes so the
    /// finish is more than a haptic.
    private(set) var routineFinishReceipt: ActionReceiptPresentation?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    var errorMessage: String?
    var activeRoutineRun: RoutineRun?
    /// The run the person tucked away with Minimize.
    ///
    /// A paused or interrupted run stays "active", and the runner used to be a
    /// full-screen cover bound to `activeRoutineRun != nil` with no way out
    /// except End — reopening Track threw it straight back over the screen.
    /// Persisted so a fresh store (another Track surface, a relaunch) honours it.
    var minimizedRoutineRunID: UUID? = RoutineRunnerMinimizeMemory.load() {
        didSet { RoutineRunnerMinimizeMemory.save(minimizedRoutineRunID) }
    }

    /// The run the runner should cover the screen for, if any.
    var presentedRoutineRun: RoutineRun? {
        guard let activeRoutineRun, activeRoutineRun.id != minimizedRoutineRunID else { return nil }
        return activeRoutineRun
    }

    /// An active run the person minimized — what the Resume banner offers.
    var minimizedRoutineRun: RoutineRun? {
        guard let activeRoutineRun, activeRoutineRun.id == minimizedRoutineRunID else { return nil }
        return activeRoutineRun
    }

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
    let starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)?
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

    @ObservationIgnored private let refreshDrain = PresentationRefreshDrain()

    func load() async {
        await refreshDrain.run { [weak self] in
            guard let self else { return }
            self.isLoading = !hasLoaded
            await self.performLoadPass()
            self.isLoading = false
        }
    }

    private func performLoadPass() async {
        let revision = refreshDrain.revision
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
            async let trackerEntriesValue = phaseIIRepository.fetchTrackerEntries(trackerID: nil, from: bounds.start, to: bounds.end)
            async let journalDaysValue = phaseIIRepository.fetchJournalEvidence(from: bounds.start, to: bounds.end)
            async let correctionValues = correctionReceiptRepository.fetchTrackCorrectionReceipts()

            let trackers: [TrackerDefinitionValue]
            let trackerEntries: [TrackerEntryValue]
            let journalDays: [JournalEvidenceSummary]
            let hydrationHistoryResult: [HydrationLog]
            let (definitions, links, routines, routineSchedules, routineRuns, habitPolicies, habitGroups, starterPackInstallations, hydrationLogs, target, sleepRecords, medications, medicationSchedules, medicationEvents, checkIns) = try await (
                goalsValue, linksValue, routinesValue, schedulesValue, runsValue, policiesValue, groupsValue, installationsValue,
                hydrationValue, targetValue, sleepValue, medicationsValue, medicationSchedulesValue, medicationEventsValue, checkInsValue
            )
            (trackers, trackerEntries, journalDays, hydrationHistoryResult) = try await (
                trackersValue, trackerEntriesValue, journalDaysValue, hydrationHistoryValue
            )
            let correctionReceipts = try await correctionValues

            let unresolved = medicationEvents.filter { $0.status == .unresolved || $0.status == .scheduled }
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
            var candidate = TrackTodaySnapshot(
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
            guard revision == refreshDrain.revision else { return }
            let previousGeneratedAt = snapshot.generatedAt
            candidate.generatedAt = previousGeneratedAt
            if !hasLoaded || candidate != snapshot {
                candidate.generatedAt = Date()
                snapshot = candidate
                PerformanceTrace.event("TrackPresentationCommitted")
            }
            if self.definitions != definitions { self.definitions = definitions }
            if self.goalLinks != links { self.goalLinks = links }
            if self.routines != routines { self.routines = routines }
            if self.routineSchedules != routineSchedules { self.routineSchedules = routineSchedules }
            if self.routineRuns != routineRuns { self.routineRuns = routineRuns }
            if self.habitPolicies != habitPolicies { self.habitPolicies = habitPolicies }
            if self.habitGroups != habitGroups { self.habitGroups = habitGroups }
            if self.starterPackInstallations != starterPackInstallations { self.starterPackInstallations = starterPackInstallations }
            if self.hydrationLogs != hydrationLogs { self.hydrationLogs = hydrationLogs }
            if self.sleepRecords != sleepRecords { self.sleepRecords = sleepRecords }
            if self.medications != medications { self.medications = medications }
            if self.medicationSchedules != medicationSchedules { self.medicationSchedules = medicationSchedules }
            if self.checkIns != checkIns { self.checkIns = checkIns }
            if self.hydrationHistory != hydrationHistoryResult { self.hydrationHistory = hydrationHistoryResult }
            if self.correctionReceipts != correctionReceipts { self.correctionReceipts = correctionReceipts }
            if self.habitOccurrenceHistory != evidence { self.habitOccurrenceHistory = evidence }
            let active = routineRuns.first {
                $0.status == .running || $0.status == .paused || $0.status == .interrupted
            }
            if activeRoutineRun != active { activeRoutineRun = active }
            if !hasLoaded {
                hasLoaded = true
                PerformanceTrace.event("TrackFirstUsableContent")
            }
            errorMessage = nil
        } catch {
            guard revision == refreshDrain.revision else { return }
            errorMessage = Self.readableFailure(error)
        }
    }

    /// Returns the log it wrote, so the caller can offer Undo on the receipt.
    @discardableResult
    func quickAddHydration(
        _ milliliters: Double,
        anchor: TrackHydrationReceiptAnchor = .quickLog
    ) async -> HydrationLog? {
        let log = HydrationLog(amount: milliliters, unit: .milliliters)
        do {
            try await repository.saveHydrationLog(log)
            Haptic.commit.play()
            undoableHydrationLog = log
            hydrationReceiptAnchor = anchor
            hydrationReceipt = ActionReceiptPresentation(
                message: String(localized: "Added \(Int(milliliters)) mL of water")
            )
            await load()
            return log
        } catch {
            errorMessage = Self.readableFailure(error)
            return nil
        }
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func correctHydration(_ log: HydrationLog, amountMilliliters: Double) async {
        var corrected = log
        corrected.amount = HydrationMeasurementService.convert(max(0, amountMilliliters), from: .milliliters, to: log.unit)
        corrected.correctedAt = Date()
        do {
            try await applyCorrection(previous: .hydration(log), corrected: .hydration(corrected))
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func clearHydrationReceipt() {
        hydrationReceipt = nil
        undoableHydrationLog = nil
    }

    /// Removes the log the receipt is about. A quick log is one tap, so undoing
    /// it must be one tap too.
    func undoLastHydration() async {
        guard let log = undoableHydrationLog else { return }
        clearHydrationReceipt()
        await deleteHydration(log)
        Haptic.decline.play()
    }

    func deleteHydration(_ log: HydrationLog, offersUndo: Bool = false) async {
        do {
            try await repository.deleteHydrationLog(id: log.id)
            if offersUndo {
                let repository = repository
                offerDeletionUndo(.hydration, message: String(localized: "Deleted water entry")) {
                    try await repository.saveHydrationLog(log)
                }
            }
            await load()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t delete water entry.")
        }
    }

    private func offerDeletionUndo(
        _ domain: TrackDeletionReceipt.Domain,
        message: String,
        restore: @escaping @MainActor () async throws -> Void
    ) {
        Haptic.commit.play()
        deletionReceipt = TrackDeletionReceipt(domain: domain, message: message, restore: restore)
    }

    func clearDeletionReceipt() {
        deletionReceipt = nil
    }

    /// Puts back the record the receipt is about. A failure keeps the receipt
    /// so the person can try again, and says what happened.
    func undoDeletion() async {
        guard let receipt = deletionReceipt else { return }
        do {
            try await receipt.restore()
            deletionReceipt = nil
            Haptic.pick.play()
            await load()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t restore entry. Try Undo again.")
        }
    }

    func clearRoutineFinishReceipt() {
        routineFinishReceipt = nil
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
            errorMessage = Self.readableFailure(error)
            return false
        }
    }

    func deleteMood(_ checkIn: MoodEnergyCheckInValue, offersUndo: Bool = false) async {
        do {
            try await phaseIIRepository.deleteMoodCheckIn(id: checkIn.id)
            if offersUndo {
                let phaseIIRepository = phaseIIRepository
                offerDeletionUndo(.mood, message: String(localized: "Deleted check-in")) {
                    try await phaseIIRepository.saveMoodCheckIn(checkIn)
                }
            }
            await load()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t delete check-in.")
        }
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
        } catch { errorMessage = Self.readableFailure(error) }
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func medicationName(id: UUID) -> String { medications.first(where: { $0.id == id })?.name ?? String(localized: "Medication") }

    func habitPolicy(for habitID: UUID) -> HabitResiliencePolicy {
        habitPolicies.first(where: { $0.habitID == habitID }) ?? HabitResiliencePolicy(habitID: habitID)
    }

    func saveHabitPolicy(_ policy: HabitResiliencePolicy) async {
        var updated = policy
        updated.updatedAt = Date()
        do {
            try await repository.saveHabitResiliencePolicy(updated)
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func recoverHabit(habitID: UUID, day: PlanningDay) async -> HabitRecoveryReceipt? {
        var policy = habitPolicy(for: habitID)
        guard policy.recoveryEnabled else {
            errorMessage = String(localized: "Recovery is off for this habit.")
            return nil
        }
        guard policy.recoveryReceipts.contains(where: { $0.day == day }) == false else {
            return policy.recoveryReceipts.first(where: { $0.day == day })
        }
        guard let habitRecoveryMutationApplier else {
            errorMessage = String(localized: "Habits are still loading. Try again.")
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
            Haptic.commit.play()
            await load()
            return receipt
        } catch {
            errorMessage = Self.readableFailure(error)
            return nil
        }
    }

    func undoHabitRecovery(habitID: UUID, day: PlanningDay) async -> Bool {
        let original = habitPolicy(for: habitID)
        guard let receipt = original.recoveryReceipts.first(where: { $0.day == day }) else { return true }
        guard let habitRecoveryMutationApplier else {
            errorMessage = String(localized: "Habits are still loading. Try again.")
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
            Haptic.commit.play()
            await load()
            return true
        } catch {
            errorMessage = Self.readableFailure(error)
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func deleteHabitGroup(_ group: HabitGroup) async {
        do {
            try await repository.deleteHabitGroup(id: group.id)
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func startRoutine(_ routine: RoutineDefinition) async {
        let run = routineService.begin(routine, at: Date())
        do {
            try await repository.saveRoutineRun(run)
            minimizedRoutineRunID = nil
            activeRoutineRun = run
            await RoutineLiveActivityCoordinator.shared.synchronize(run: run)
        } catch {
            activeRoutineRun = nil
            errorMessage = Self.readableFailure(error)
        }
    }

    func saveRoutineSchedule(_ schedule: RoutineSchedule) async {
        do {
            try await repository.saveRoutineSchedule(schedule)
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
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
        } catch { errorMessage = Self.readableFailure(error) }
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func deleteRoutine(_ routine: RoutineDefinition) async {
        guard activeRoutineRun?.routineID != routine.id else {
            errorMessage = String(localized: "End the routine before deleting it.")
            return
        }
        do {
            try await repository.deleteRoutine(id: routine.id)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = Self.readableFailure(error) }
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

    /// Pauses a running run and takes the runner off screen. The run, its place
    /// and its timer are kept; `reopenRoutine()` brings the runner back.
    func minimizeRoutine() async {
        guard let run = activeRoutineRun else { return }
        if run.status == .running { await pauseRoutine() }
        minimizedRoutineRunID = run.id
    }

    func reopenRoutine() {
        minimizedRoutineRunID = nil
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
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn’t complete this step. Try again.")]
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
                Haptic.commit.play()
            }
            if let summary = Self.routineFinishSummary(transition.run) {
                routineFinishReceipt = summary
            }
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func archiveGoal(_ goal: GoalDefinition) async {
        do {
            _ = try await goalLifecycleService.transition(goal, to: .archived, reason: "Archived by user")
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = Self.readableFailure(error) }
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
            errorMessage = Self.readableFailure(error)
            return nil
        }
    }

    func undoGoalTransition(_ receipt: GoalTransitionReceipt) async {
        do {
            _ = try await goalLifecycleService.undo(receipt)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func deleteGoal(_ goal: GoalDefinition) async {
        do {
            try await repository.deleteGoal(id: goal.id)
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func saveGoalLink(goalID: UUID, source: GoalLinkSource, sourceID: UUID) async {
        do {
            try await repository.saveGoalLink(.init(goalID: goalID, source: source, sourceID: sourceID))
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
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
        } catch { errorMessage = Self.readableFailure(error) }
    }

    func deleteSleep(_ record: SleepContextRecord, offersUndo: Bool = false) async {
        do {
            try await repository.deleteSleepContextRecord(id: record.id)
            if offersUndo {
                let repository = repository
                offerDeletionUndo(.sleep, message: String(localized: "Deleted sleep entry")) {
                    try await repository.saveSleepContextRecord(record)
                }
            }
            await load()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t delete sleep entry.")
        }
    }
}

extension TrackFoundationStore {
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
        } catch { errorMessage = Self.readableFailure(error) }
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

    /// "Morning reset finished · 4 done, 1 skipped". Nil while the run is
    /// still open. Linked task and habit completions stay done, so there is
    /// no Undo to offer here — only an honest account of what happened.
    static func routineFinishSummary(_ run: RoutineRun) -> ActionReceiptPresentation? {
        let title = run.versionSnapshot.title
        let verb: String
        switch run.status {
        case .running, .paused, .interrupted: return nil
        case .completed: verb = String(localized: "finished")
        case .partial: verb = String(localized: "ended early")
        case .abandoned, .skipped: verb = String(localized: "ended")
        }
        let skipped = run.events.filter(\.wasSkipped).count
        let done = run.events.count - skipped
        var parts: [String] = [String(localized: "\(done) done")]
        if skipped > 0 { parts.append(String(localized: "\(skipped) skipped")) }
        return ActionReceiptPresentation(message: String(localized: "\(title) \(verb)"), detail: parts.joined(separator: ", "))
    }

    /// Human copy for a failed write. Our own errors already carry a sentence
    /// written for people; a system error's text ("The operation couldn't be
    /// completed. (NSCocoaErrorDomain error 134030.)") never reaches the screen.
    static func readableFailure(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain.hasPrefix("TrackFoundationStore") {
            return nsError.localizedDescription
        }
        // A Swift error that describes itself was written for this app.
        // Foundation and Core Data errors were not.
        if nsError.domain != NSCocoaErrorDomain,
           let described = (error as? LocalizedError)?.errorDescription,
           described.isEmpty == false {
            return described
        }
        return String(localized: "Try again.")
    }

    private static func todayBounds() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: Date())
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

    private static func routineValidationMessage(_ report: RoutineValidationReport) -> String {
        guard let first = report.issues.first else { return String(localized: "This routine is ready.") }
        return switch first {
        case .noSteps:
            String(localized: "Add at least one step.")
        case .emptyTitle:
            String(localized: "Name every step.")
        case .duplicateStepID:
            String(localized: "Two steps conflict. Delete one and add it again.")
        case .duplicateOrdinal:
            String(localized: "Two steps share a position. Reorder them.")
        case .invalidChoice:
            String(localized: "Each choice needs its own label.")
        case .branchSourceMismatch:
            String(localized: "A branch starts from the wrong step.")
        case .missingBranchDestination:
            String(localized: "A branch points to a deleted step.")
        case .unreachableStep:
            String(localized: "A step can’t be reached from the start.")
        case .loop:
            String(localized: "Steps loop back. Point branches forward.")
        case .missingLinkedEntity:
            String(localized: "A linked step needs a task or habit.")
        case .linkedEntityUnavailable:
            String(localized: "Couldn’t find a linked task or habit.")
        }
    }

    nonisolated static func medicationWindowEnded(
        _ event: MedicationEventValue,
        schedules: [MedicationScheduleValue],
        now: Date
    ) -> Bool {
        let schedule = schedules.first { $0.medicationID == event.medicationID }
        let windowDuration = schedule.map { max(0, $0.windowEndMinutes - $0.windowStartMinutes) * 60 } ?? 0
        return now > event.scheduledAt.addingTimeInterval(TimeInterval(windowDuration))
    }

    nonisolated static func dueRoutines(
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
}
