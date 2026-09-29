import Foundation

// MARK: - Contracts

public protocol TrackFoundationRepository: Sendable {
    func fetchGoals() async throws -> [GoalDefinition]
    func saveGoal(_ value: GoalDefinition) async throws
    func deleteGoal(id: UUID) async throws
    func fetchGoalLinks(goalID: UUID?) async throws -> [GoalLink]
    func saveGoalLink(_ value: GoalLink) async throws
    func fetchHabitResiliencePolicies() async throws -> [HabitResiliencePolicy]
    func saveHabitResiliencePolicy(_ value: HabitResiliencePolicy) async throws
    func fetchHabitGroups() async throws -> [HabitGroup]
    func saveHabitGroup(_ value: HabitGroup) async throws
    func deleteHabitGroup(id: UUID) async throws
    func fetchRoutines() async throws -> [RoutineDefinition]
    func saveRoutine(_ value: RoutineDefinition) async throws
    func deleteRoutine(id: UUID) async throws
    func fetchRoutineRuns(routineID: UUID?) async throws -> [RoutineRun]
    func saveRoutineRun(_ value: RoutineRun) async throws
    func fetchRoutineSchedules(routineID: UUID?) async throws -> [RoutineSchedule]
    func saveRoutineSchedule(_ value: RoutineSchedule) async throws
    func fetchRoutineLinkedMutationReceipt(idempotencyKey: String) async throws -> RoutineLinkedMutationReceipt?
    func saveRoutineLinkedMutationReceipt(_ value: RoutineLinkedMutationReceipt) async throws
    func fetchHydrationLogs(from: Date, to: Date) async throws -> [HydrationLog]
    func saveHydrationLog(_ value: HydrationLog) async throws
    func deleteHydrationLog(id: UUID) async throws
    func fetchHydrationTarget() async throws -> HydrationTarget?
    func saveHydrationTarget(_ value: HydrationTarget) async throws
    func fetchSleepContextRecords(from: Date, to: Date) async throws -> [SleepContextRecord]
    func saveSleepContextRecord(_ value: SleepContextRecord) async throws
    func deleteSleepContextRecord(id: UUID) async throws
    func fetchStarterPackInstallations() async throws -> [StarterPackInstallation]
    func saveStarterPackInstallation(_ value: StarterPackInstallation) async throws
}

public protocol GoalSampleRepository: Sendable {
    func samples(for links: [GoalLink], asOf date: Date) async throws -> [GoalProgressSample]
}

public protocol TrackHabitProjectionService: Sendable {
    func occurrenceEvidence(from: Date, to: Date, now: Date, calendar: Calendar) async throws -> [UUID: [HabitOccurrenceEvidence]]
}

public protocol HabitRecoveryMutationApplying: Sendable {
    func recover(habitID: UUID, day: PlanningDay) async throws -> HabitRecoveryReceipt
    func revert(_ receipt: HabitRecoveryReceipt) async throws
}

public protocol HabitGradeService: Sendable {
    func evaluate(
        habitID: UUID,
        occurrences: [HabitOccurrenceEvidence],
        policy: HabitResiliencePolicy,
        now: Date,
        calendar: Calendar
    ) -> HabitGradeSnapshot
}

public protocol RoutineExecutionService: Sendable {
    func begin(_ routine: RoutineDefinition, at date: Date) -> RoutineRun
    func advance(
        run: RoutineRun,
        response: String?,
        skip: Bool,
        idempotencyKey: String,
        at date: Date
    ) -> RoutineTransition
    func abandon(run: RoutineRun, at date: Date) -> RoutineRun
}

public protocol RoutineLinkedMutationApplying: Sendable {
    func isApplied(_ mutation: RoutineLinkedMutationKind, targetID: UUID, at date: Date) async throws -> Bool
    func apply(_ mutation: RoutineLinkedMutationKind, targetID: UUID, at date: Date) async throws
}

public protocol StarterPackCanonicalMutationApplying: Sendable {
    func createHabit(title: String, pack: StarterPack, itemKind: StarterPackItemKind) async throws -> UUID
    func archiveHabit(id: UUID) async throws
}

public protocol GoalProgressService: Sendable {
    func progress(
        for goal: GoalDefinition,
        links: [GoalLink],
        samples: [GoalProgressSample]
    ) -> GoalProgressSnapshot
}

// MARK: - Home context candidate providers (goals and routines)

/// Surfaces a goal whose user-chosen target date is inside its final week.
/// Deterministic and explainable: the reason names the exact date the user
/// picked; nothing is inferred about likelihood or effort.
public struct GoalHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "goals"
    private let repository: any TrackFoundationRepository
    private let thresholdDays: Int

    public init(repository: any TrackFoundationRepository, thresholdDays: Int = 7) {
        self.repository = repository
        self.thresholdDays = max(0, thresholdDays)
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        guard let goals = try? await repository.fetchGoals() else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: context.date)
        return goals.compactMap { goal -> HomeContextCandidate? in
            guard goal.isArchived == false,
                  let targetDate = goal.targetDate else { return nil }
            let target = calendar.startOfDay(for: targetDate)
            guard let days = calendar.dateComponents([.day], from: today, to: target).day,
                  days >= 0, days <= thresholdDays else { return nil }
            let reason = days == 0
                ? String(localized: "Target date is today.")
                : days == 1
                    ? String(localized: "Target date is tomorrow.")
                    : String(localized: "Target date in \(days) days.")
            return HomeContextCandidate(
                id: "goal-window:\(goal.id.uuidString)",
                widgetKind: .goals,
                title: goal.title,
                reason: .init(message: reason, signal: "goalTargetDate"),
                destination: .track,
                sensitivity: .privateStandard,
                priority: days == 0 ? 620 : 340 + (thresholdDays - days),
                relevantFrom: context.date,
                relevantUntil: target.addingTimeInterval(24 * 60 * 60),
                route: .goal(goal.id)
            )
        }
        .sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.id < $1.id
        }
    }
}

/// Surfaces routines scheduled for the current weekday and daypart that have
/// not produced a run today. Mirrors the Track store's due logic without
/// reaching through it, so Home candidates stay a pure domain projection.
public struct RoutineHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "routines"
    private let repository: any TrackFoundationRepository
    private let daypart: @Sendable (Date) -> ResolvedDaypart

    public init(
        repository: any TrackFoundationRepository,
        daypart: @escaping @Sendable (Date) -> ResolvedDaypart = { DaypartResolver.resolve(at: $0) }
    ) {
        self.repository = repository
        self.daypart = daypart
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        guard let routines = try? await repository.fetchRoutines(),
              let schedules = try? await repository.fetchRoutineSchedules(routineID: nil),
              let runs = try? await repository.fetchRoutineRuns(routineID: nil) else { return [] }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: context.date)
        let currentDaypart = daypart(context.date)
        let ranToday = Set(
            runs.filter { calendar.isDate($0.startedAt, inSameDayAs: context.date) }.map(\.routineID)
        )
        let eligibleIDs = Set(
            schedules.filter { schedule in
                schedule.isEnabled
                    && schedule.weekdays.contains(weekday)
                    && (schedule.daypart == nil || schedule.daypart == currentDaypart)
            }.map(\.routineID)
        )
        return routines.compactMap { routine -> HomeContextCandidate? in
            guard routine.isArchived == false,
                  eligibleIDs.contains(routine.id),
                  ranToday.contains(routine.id) == false else { return nil }
            return HomeContextCandidate(
                id: "routine-due:\(routine.id.uuidString)",
                widgetKind: .routines,
                title: routine.title,
                reason: .init(
                    message: String(localized: "Scheduled for now."),
                    signal: "routineSchedule"
                ),
                destination: .track,
                sensitivity: .privateStandard,
                priority: 400,
                relevantFrom: context.date,
                relevantUntil: calendar.date(byAdding: .hour, value: 6, to: context.date),
                route: .routine(routine.id)
            )
        }
        .sorted { $0.id < $1.id }
    }
}

// MARK: - Display names
//
// The raw values are storage keys ("targetDate", "completeHabitOccurrence").
// `rawValue.capitalized` turned them into "Targetdate" on screen; these are the
// words a person reads (DESIGN.md launch contract 5).

public extension RoutineStepKind {
    var displayName: String {
        switch self {
        case .task: String(localized: "Task")
        case .habit: String(localized: "Habit")
        case .checkIn: String(localized: "Check-in")
        case .timer: String(localized: "Timer")
        case .instruction: String(localized: "Instruction")
        case .choice: String(localized: "Choice")
        }
    }
}

public extension RoutineLinkedMutationKind {
    var displayName: String {
        switch self {
        case .completeTask: String(localized: "Completes a task")
        case .completeHabitOccurrence: String(localized: "Logs a habit")
        }
    }
}

public extension RoutineRunStatus {
    var displayName: String {
        switch self {
        case .running: String(localized: "In progress")
        case .paused: String(localized: "Paused")
        case .interrupted: String(localized: "Interrupted")
        case .completed: String(localized: "Finished")
        case .partial: String(localized: "Partly done")
        case .abandoned: String(localized: "Ended early")
        case .skipped: String(localized: "Skipped")
        }
    }
}

public extension GoalType {
    var displayName: String {
        switch self {
        case .completion: String(localized: "Done or not")
        case .count: String(localized: "Count")
        case .quantity: String(localized: "Amount")
        case .duration: String(localized: "Time spent")
        case .targetDate: String(localized: "By a date")
        }
    }
}

public extension GoalIntent {
    var displayName: String {
        switch self {
        case .outcome: String(localized: "Outcome")
        case .maintenance: String(localized: "Keep it up")
        case .milestone: String(localized: "Milestone")
        case .cumulative: String(localized: "Adds up")
        case .directional: String(localized: "Direction")
        }
    }
}

public extension GoalStatus {
    var displayName: String {
        switch self {
        case .active: String(localized: "Active")
        case .paused: String(localized: "Paused")
        case .revised: String(localized: "Revised")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        }
    }
}

public extension GoalLinkSource {
    var displayName: String {
        switch self {
        case .project: String(localized: "Project")
        case .task: String(localized: "Task")
        case .habit: String(localized: "Habit")
        case .routine: String(localized: "Routine")
        case .trackerMeasure: String(localized: "Tracker")
        }
    }
}

public extension GoalConfidence {
    var displayName: String {
        switch self {
        case .uncertain: String(localized: "Unsure")
        case .possible: String(localized: "Possible")
        case .confident: String(localized: "Confident")
        }
    }
}

// Types owned elsewhere get a Track-prefixed name so a later `displayName`
// added beside the enum itself cannot collide with this one.

public extension ResolvedDaypart {
    var trackDisplayName: String {
        switch self {
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .evening: String(localized: "Evening")
        case .night: String(localized: "Night")
        }
    }
}

public extension MedicationEventStatus {
    var trackDisplayName: String {
        switch self {
        case .scheduled: String(localized: "Scheduled")
        case .taken: String(localized: "Taken")
        case .skipped: String(localized: "Skipped")
        case .snoozed: String(localized: "Snoozed")
        case .rescheduled: String(localized: "Moved")
        case .unresolved: String(localized: "Not recorded")
        }
    }
}

public extension TrackerKind {
    var trackDisplayName: String {
        switch self {
        case .boolean: String(localized: "Yes or no")
        case .count: String(localized: "Count")
        case .quantity: String(localized: "Amount")
        case .rating: String(localized: "Rating")
        case .duration: String(localized: "Duration")
        case .text: String(localized: "Note")
        case .choice: String(localized: "Choice")
        case .timestamp: String(localized: "Time")
        }
    }
}
