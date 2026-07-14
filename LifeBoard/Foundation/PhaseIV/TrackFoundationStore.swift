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
    private(set) var routineRuns: [RoutineRun] = []
    private(set) var medications: [LifeBoardMedicationDefinitionValue] = []
    private(set) var checkIns: [LifeBoardMoodEnergyCheckInValue] = []
    private(set) var sleepRecords: [SleepContextRecord] = []
    private(set) var hydrationLogs: [HydrationLog] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var activeRoutineRun: RoutineRun?

    let repository: any TrackFoundationRepository
    let phaseIIRepository: any LifeBoardPhaseIIRepository
    private let routineService: any RoutineExecutionService
    private let goalService: any GoalProgressService

    init(
        repository: any TrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        routineService: any RoutineExecutionService = DefaultRoutineExecutionService(),
        goalService: any GoalProgressService = DefaultGoalProgressService()
    ) {
        self.repository = repository
        self.phaseIIRepository = phaseIIRepository
        self.routineService = routineService
        self.goalService = goalService
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
            async let runsValue = repository.fetchRoutineRuns(routineID: nil)
            async let hydrationValue = repository.fetchHydrationLogs(from: bounds.start, to: bounds.end)
            async let targetValue = repository.fetchHydrationTarget()
            async let sleepValue = repository.fetchSleepContextRecords(from: Calendar.current.date(byAdding: .day, value: -7, to: bounds.start) ?? bounds.start, to: bounds.end)
            async let medicationsValue = phaseIIRepository.fetchMedications()
            async let medicationEventsValue = phaseIIRepository.fetchMedicationEvents(from: bounds.start, to: bounds.end)
            async let checkInsValue = phaseIIRepository.fetchMoodCheckIns(from: bounds.start, to: bounds.end)

            let links: [GoalLink]
            let target: HydrationTarget?
            let medicationEvents: [LifeBoardMedicationEventValue]
            (definitions, links, routines, routineRuns, hydrationLogs, target, sleepRecords, medications, medicationEvents, checkIns) = try await (
                goalsValue, linksValue, routinesValue, runsValue, hydrationValue, targetValue, sleepValue,
                medicationsValue, medicationEventsValue, checkInsValue
            )

            let unresolved = medicationEvents.compactMap { event -> LifeBoardMedicationEventValue? in
                guard event.status == .unresolved || event.status == .scheduled else { return nil }
                if event.status == .scheduled && event.scheduledAt >= Date() { return event }
                var copy = event
                copy.status = .unresolved
                return copy
            }
            let progress = definitions.map { goal in
                goalService.progress(for: goal, links: links.filter { $0.goalID == goal.id }, samples: [])
            }
            let hydrationTotal = hydrationLogs.reduce(0) { partial, log in
                partial + HydrationMeasurementService.convert(log.amount, from: log.unit, to: .milliliters)
            }
            let targetML = target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) }
            snapshot = TrackTodaySnapshot(
                unresolvedMedicationEvents: unresolved,
                habitGrades: [],
                dueRoutines: routines,
                goals: progress,
                hydrationAmountMilliliters: hydrationLogs.isEmpty && target == nil ? nil : hydrationTotal,
                hydrationTargetMilliliters: targetML,
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
            try await repository.saveHydrationTarget(.init(id: UUID(), amount: milliliters, unit: .milliliters, updatedAt: Date()))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        do {
            try await phaseIIRepository.saveMoodCheckIn(.init(mood: mood, energy: energy))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(event: LifeBoardMedicationEventValue, status: LifeBoardMedicationEventStatus) async {
        var value = event
        value.status = status
        value.resolvedAt = Date()
        do {
            try await phaseIIRepository.saveMedicationEvent(value)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func medicationName(id: UUID) -> String { medications.first(where: { $0.id == id })?.name ?? "Medication" }

    func startRoutine(_ routine: RoutineDefinition) async {
        let run = routineService.begin(routine, at: Date())
        activeRoutineRun = run
        do { try await repository.saveRoutineRun(run) }
        catch { errorMessage = error.localizedDescription }
    }

    func advanceRoutine(response: String? = nil, skip: Bool = false) async {
        guard let activeRoutineRun else { return }
        let key = "\(activeRoutineRun.id.uuidString):\(activeRoutineRun.currentStepID?.uuidString ?? "end"):user"
        let transition = routineService.advance(run: activeRoutineRun, response: response, skip: skip, idempotencyKey: key, at: Date())
        self.activeRoutineRun = transition.run.status == .running ? transition.run : nil
        do {
            try await repository.saveRoutineRun(transition.run)
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

    func saveGoal(title: String, target: Double?) async {
        do {
            try await repository.saveGoal(.init(title: title, type: target == nil ? .completion : .quantity, targetValue: target))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveSleep(bedtime: Date, wakeTime: Date, rest: Int?, interruptions: Int, notes: String?) async {
        do {
            try await repository.saveSleepContextRecord(.init(
                bedtime: bedtime, wakeTime: wakeTime, perceivedRest: rest,
                interruptionCount: interruptions, notes: notes
            ))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func installStarterPack(_ preview: StarterPackPreview) async {
        let selected = preview.items.filter(\.isSelected)
        do {
            for item in selected {
                switch item.kind {
                case .goal:
                    try await repository.saveGoal(.init(title: item.title, type: .completion))
                case .routine:
                    let steps = Self.steps(for: preview.pack)
                    try await repository.saveRoutine(.init(title: item.title, steps: steps))
                case .habit, .reminder:
                    // Habit/reminder installation stays explicit in the legacy editor until its canonical mutation repository is exposed.
                    continue
                }
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private static func todayBounds() -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: Date())
        return (start, Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
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
}
