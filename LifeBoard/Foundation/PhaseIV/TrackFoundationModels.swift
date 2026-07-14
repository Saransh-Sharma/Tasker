import Foundation

// MARK: - Goals

public enum GoalType: String, Codable, CaseIterable, Sendable {
    case completion
    case count
    case quantity
    case duration
    case targetDate
}

public enum GoalLinkSource: String, Codable, CaseIterable, Sendable {
    case project
    case task
    case habit
    case routine
    case trackerMeasure
}

public struct GoalDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var areaID: UUID?
    public var title: String
    public var type: GoalType
    public var targetValue: Double?
    public var unitLabel: String?
    public var targetDate: Date?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        areaID: UUID? = nil,
        title: String,
        type: GoalType,
        targetValue: Double? = nil,
        unitLabel: String? = nil,
        targetDate: Date? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.areaID = areaID
        self.title = title
        self.type = type
        self.targetValue = targetValue
        self.unitLabel = unitLabel
        self.targetDate = targetDate
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct GoalLink: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var goalID: UUID
    public var source: GoalLinkSource
    public var sourceID: UUID
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        goalID: UUID,
        source: GoalLinkSource,
        sourceID: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.goalID = goalID
        self.source = source
        self.sourceID = sourceID
        self.createdAt = createdAt
    }
}

public struct GoalProgressSample: Codable, Hashable, Sendable {
    public var linkID: UUID
    public var value: Double?
    public var isComplete: Bool?
    public var measuredAt: Date
}

public struct GoalProgressSnapshot: Codable, Equatable, Sendable {
    public var goalID: UUID
    public var currentValue: Double?
    public var targetValue: Double?
    public var progressFraction: Double?
    public var trend: Double?
    public var confidence: Double
    public var missingLinkCount: Int
    public var nextUsefulAction: String
}

// MARK: - Habit resilience

public enum HabitStreakPresentation: String, Codable, CaseIterable, Sendable {
    case gradeAndStreak
    case countsOnly
}

public struct HabitResiliencePolicy: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var habitID: UUID
    public var groupID: UUID?
    public var offDays: Set<PlanningDay>
    public var recoveryEnabled: Bool
    public var streakPresentation: HabitStreakPresentation
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        groupID: UUID? = nil,
        offDays: Set<PlanningDay> = [],
        recoveryEnabled: Bool = true,
        streakPresentation: HabitStreakPresentation = .gradeAndStreak,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.habitID = habitID
        self.groupID = groupID
        self.offDays = offDays
        self.recoveryEnabled = recoveryEnabled
        self.streakPresentation = streakPresentation
        self.updatedAt = updatedAt
    }
}

public enum HabitOccurrenceResolution: String, Codable, CaseIterable, Sendable {
    case due
    case completed
    case manuallySkipped
    case recovered
}

public struct HabitOccurrenceEvidence: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(habitID.uuidString):\(day.year)-\(day.month)-\(day.day):\(day.timeZoneIdentifier)" }
    public var habitID: UUID
    public var day: PlanningDay
    public var isDue: Bool
    public var resolution: HabitOccurrenceResolution

    public init(
        habitID: UUID,
        day: PlanningDay,
        isDue: Bool = true,
        resolution: HabitOccurrenceResolution = .due
    ) {
        self.habitID = habitID
        self.day = day
        self.isDue = isDue
        self.resolution = resolution
    }
}

public struct HabitGradeSnapshot: Codable, Equatable, Sendable {
    public var habitID: UUID
    public var completedEligibleCount: Int
    public var eligibleDueCount: Int
    public var grade: Double?
    public var streak: Int
    public var recoveredDays: [PlanningDay]
    public var generatedAt: Date
}

// MARK: - Routines

public enum RoutineStepKind: String, Codable, CaseIterable, Sendable {
    case task
    case habit
    case checkIn
    case timer
    case instruction
    case choice
}

public enum RoutineLinkedMutationKind: String, Codable, Sendable {
    case completeTask
    case completeHabitOccurrence
}

public enum RoutineBranchOperator: String, Codable, Sendable {
    case equals
    case notEquals
}

public struct RoutineBranchCondition: Codable, Hashable, Sendable {
    public var sourceStepID: UUID
    public var operation: RoutineBranchOperator
    public var expectedResponse: String
    public var destinationStepID: UUID
}

public struct RoutineStep: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var kind: RoutineStepKind
    public var ordinal: Int
    public var duration: TimeInterval?
    public var isRequired: Bool
    public var isSkippable: Bool
    public var linkedEntityID: UUID?
    public var linkedMutation: RoutineLinkedMutationKind?
    public var choices: [String]
    public var branches: [RoutineBranchCondition]

    public init(
        id: UUID = UUID(),
        title: String,
        kind: RoutineStepKind,
        ordinal: Int,
        duration: TimeInterval? = nil,
        isRequired: Bool = true,
        isSkippable: Bool = false,
        linkedEntityID: UUID? = nil,
        linkedMutation: RoutineLinkedMutationKind? = nil,
        choices: [String] = [],
        branches: [RoutineBranchCondition] = []
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.ordinal = ordinal
        self.duration = duration
        self.isRequired = isRequired
        self.isSkippable = isSkippable
        self.linkedEntityID = linkedEntityID
        self.linkedMutation = linkedMutation
        self.choices = choices
        self.branches = branches
    }
}

public struct RoutineDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var version: Int
    public var steps: [RoutineStep]
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        version: Int = 1,
        steps: [RoutineStep],
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.version = max(1, version)
        self.steps = steps.sorted { ($0.ordinal, $0.id.uuidString) < ($1.ordinal, $1.id.uuidString) }
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum RoutineRunStatus: String, Codable, CaseIterable, Sendable {
    case running
    case completed
    case partial
    case abandoned
    case skipped
}

public struct RoutineStepEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var stepID: UUID
    public var response: String?
    public var wasSkipped: Bool
    public var occurredAt: Date
    public var idempotencyKey: String
}

public struct RoutineRun: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var routineID: UUID
    public var versionSnapshot: RoutineDefinition
    public var status: RoutineRunStatus
    public var currentStepID: UUID?
    public var events: [RoutineStepEvent]
    public var startedAt: Date
    public var endedAt: Date?
    public var updatedAt: Date
}

public struct RoutineTransition: Codable, Hashable, Sendable {
    public var run: RoutineRun
    public var linkedMutation: RoutineLinkedMutationKind?
    public var linkedEntityID: UUID?
    public var didApplyEvent: Bool
}

public struct RoutineSchedule: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var routineID: UUID
    public var weekdays: Set<Int>
    public var daypart: ResolvedDaypart?
    public var reminderTimeMinutes: Int?
    public var timeZoneIdentifier: String
    public var isEnabled: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        routineID: UUID,
        weekdays: Set<Int> = [],
        daypart: ResolvedDaypart? = nil,
        reminderTimeMinutes: Int? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        isEnabled: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.routineID = routineID
        self.weekdays = Set(weekdays.filter { (1...7).contains($0) })
        self.daypart = daypart
        self.reminderTimeMinutes = reminderTimeMinutes.map { min(1_439, max(0, $0)) }
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isEnabled = isEnabled
        self.updatedAt = updatedAt
    }
}

public enum RoutineLinkedMutationStatus: String, Codable, CaseIterable, Sendable {
    case prepared
    case applied
    case reconciled
}

public struct RoutineLinkedMutationReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var runID: UUID
    public var stepID: UUID
    public var mutation: RoutineLinkedMutationKind
    public var targetID: UUID
    public var idempotencyKey: String
    public var status: RoutineLinkedMutationStatus
    public var preparedAt: Date
    public var appliedAt: Date?
    public var reconciledAt: Date?

    public init(
        id: UUID = UUID(),
        runID: UUID,
        stepID: UUID,
        mutation: RoutineLinkedMutationKind,
        targetID: UUID,
        idempotencyKey: String,
        status: RoutineLinkedMutationStatus = .prepared,
        preparedAt: Date = Date(),
        appliedAt: Date? = nil,
        reconciledAt: Date? = nil
    ) {
        self.id = id
        self.runID = runID
        self.stepID = stepID
        self.mutation = mutation
        self.targetID = targetID
        self.idempotencyKey = idempotencyKey
        self.status = status
        self.preparedAt = preparedAt
        self.appliedAt = appliedAt
        self.reconciledAt = reconciledAt
    }
}

// MARK: - Care modules

public enum HydrationUnit: String, Codable, CaseIterable, Sendable {
    case milliliters
    case liters
    case fluidOunces
}

public struct HydrationLog: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var amount: Double
    public var unit: HydrationUnit
    public var timestamp: Date
    public var note: String?
    public var correctedAt: Date?

    public init(
        id: UUID = UUID(),
        amount: Double,
        unit: HydrationUnit,
        timestamp: Date = Date(),
        note: String? = nil,
        correctedAt: Date? = nil
    ) {
        self.id = id
        self.amount = max(0, amount)
        self.unit = unit
        self.timestamp = timestamp
        self.note = note
        self.correctedAt = correctedAt
    }
}

public struct HydrationTarget: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var amount: Double
    public var unit: HydrationUnit
    public var updatedAt: Date
}

public struct SleepContextRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var bedtime: Date
    public var wakeTime: Date
    public var perceivedRest: Int?
    public var interruptionCount: Int
    public var notes: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        bedtime: Date,
        wakeTime: Date,
        perceivedRest: Int? = nil,
        interruptionCount: Int = 0,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bedtime = bedtime
        self.wakeTime = max(wakeTime, bedtime)
        self.perceivedRest = perceivedRest.map { min(5, max(1, $0)) }
        self.interruptionCount = max(0, interruptionCount)
        self.notes = notes
        self.createdAt = createdAt
    }

    public var sensitivity: DataSensitivity { .privateSensitive }
}

public enum StarterPack: String, Codable, CaseIterable, Sendable {
    case morningFoundation
    case workdayReset
    case lowEnergyRecovery
    case medicationSupport
    case eveningWindDown
}

public enum StarterPackItemKind: String, Codable, Sendable {
    case goal
    case habit
    case routine
    case reminder
}

public struct StarterPackItem: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var kind: StarterPackItemKind
    public var title: String
    public var isSelected: Bool
}

public struct StarterPackPreview: Codable, Hashable, Sendable {
    public var pack: StarterPack
    public var items: [StarterPackItem]
}

public struct StarterPackInstallation: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var pack: StarterPack
    public var createdIDs: [StarterPackItemKind: Set<UUID>]
    public var installedAt: Date
    public var removedAt: Date?

    public init(
        id: UUID = UUID(),
        pack: StarterPack,
        createdIDs: [StarterPackItemKind: Set<UUID>],
        installedAt: Date = Date(),
        removedAt: Date? = nil
    ) {
        self.id = id
        self.pack = pack
        self.createdIDs = createdIDs
        self.installedAt = installedAt
        self.removedAt = removedAt
    }
}

public enum ProjectionCompleteness: String, Codable, CaseIterable, Sendable {
    case complete
    case partial
    case unavailable
}

public struct TrackContextEnvelope: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var sourceID: UUID
    public var sourceType: String
    public var timestamp: Date
    public var localDay: PlanningDay
    public var completeness: ProjectionCompleteness
    public var sensitivity: DataSensitivity
    public var isAuthorized: Bool
    public var allowedDestinations: Set<LifeBoardDestination>
    public var provenance: String
}

public struct NormalizedLifeEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var sourceID: UUID
    public var domain: String
    public var kind: String
    public var occurredAt: Date
    public var localDay: PlanningDay
    public var numericValue: Double?
    public var completeness: ProjectionCompleteness
    public var sensitivity: DataSensitivity
    public var allowedDestinations: Set<LifeBoardDestination>
    public var provenance: String
}

public struct TrackTodaySnapshot: Codable, Equatable, Sendable {
    public var unresolvedMedicationEvents: [LifeBoardMedicationEventValue]
    public var habitGrades: [HabitGradeSnapshot]
    public var dueRoutines: [RoutineDefinition]
    public var goals: [GoalProgressSnapshot]
    public var hydrationAmountMilliliters: Double?
    public var hydrationTargetMilliliters: Double?
    public var context: [TrackContextEnvelope] = []
    public var normalizedEvents: [NormalizedLifeEvent] = []
    public var completeness: ProjectionCompleteness = .partial
    public var generatedAt: Date
}

// MARK: - Contracts

public protocol TrackFoundationRepository: Sendable {
    func fetchGoals() async throws -> [GoalDefinition]
    func saveGoal(_ value: GoalDefinition) async throws
    func fetchGoalLinks(goalID: UUID?) async throws -> [GoalLink]
    func saveGoalLink(_ value: GoalLink) async throws
    func fetchHabitResiliencePolicies() async throws -> [HabitResiliencePolicy]
    func saveHabitResiliencePolicy(_ value: HabitResiliencePolicy) async throws
    func fetchRoutines() async throws -> [RoutineDefinition]
    func saveRoutine(_ value: RoutineDefinition) async throws
    func fetchRoutineRuns(routineID: UUID?) async throws -> [RoutineRun]
    func saveRoutineRun(_ value: RoutineRun) async throws
    func fetchRoutineSchedules(routineID: UUID?) async throws -> [RoutineSchedule]
    func saveRoutineSchedule(_ value: RoutineSchedule) async throws
    func fetchRoutineLinkedMutationReceipt(idempotencyKey: String) async throws -> RoutineLinkedMutationReceipt?
    func saveRoutineLinkedMutationReceipt(_ value: RoutineLinkedMutationReceipt) async throws
    func fetchHydrationLogs(from: Date, to: Date) async throws -> [HydrationLog]
    func saveHydrationLog(_ value: HydrationLog) async throws
    func fetchHydrationTarget() async throws -> HydrationTarget?
    func saveHydrationTarget(_ value: HydrationTarget) async throws
    func fetchSleepContextRecords(from: Date, to: Date) async throws -> [SleepContextRecord]
    func saveSleepContextRecord(_ value: SleepContextRecord) async throws
    func fetchStarterPackInstallations() async throws -> [StarterPackInstallation]
    func saveStarterPackInstallation(_ value: StarterPackInstallation) async throws
}

public protocol GoalSampleProvider: Sendable {
    func samples(for links: [GoalLink], asOf date: Date) async throws -> [GoalProgressSample]
}

public protocol TrackHabitProjectionService: Sendable {
    func occurrenceEvidence(from: Date, to: Date, now: Date, calendar: Calendar) async throws -> [UUID: [HabitOccurrenceEvidence]]
}

public protocol HabitGradeEngine: Sendable {
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

public protocol GoalProgressService: Sendable {
    func progress(
        for goal: GoalDefinition,
        links: [GoalLink],
        samples: [GoalProgressSample]
    ) -> GoalProgressSnapshot
}
