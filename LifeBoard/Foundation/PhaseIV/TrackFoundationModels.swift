import Foundation

// MARK: - Mood trends

public enum MoodTrendState: Equatable, Sendable {
    case empty
    case light(sampleCount: Int)
    case ready(MoodTrendSummary)
}

public struct MoodTrendSummary: Equatable, Sendable {
    public var sampleCount: Int
    public var averageValence: Double
    public var averageEnergy: Double?
    public var dailyPoints: [MoodTrendPoint]
}

public struct MoodTrendPoint: Equatable, Identifiable, Sendable {
    public var day: Date
    public var valence: Double
    public var energy: Double?
    public var sampleCount: Int
    public var id: Date { day }
}

public enum MoodTrendProjector {
    public static func project(
        _ checkIns: [LifeBoardMoodEnergyCheckInValue],
        minimumSamples: Int = 3,
        calendar: Calendar = .current
    ) -> MoodTrendState {
        guard checkIns.isEmpty == false else { return .empty }
        guard checkIns.count >= minimumSamples else { return .light(sampleCount: checkIns.count) }

        let valued = checkIns.compactMap { checkIn -> (LifeBoardMoodEnergyCheckInValue, Double)? in
            guard let index = LifeBoardJournalMood.dialOrder.firstIndex(of: checkIn.mood) else { return nil }
            return (checkIn, Double(index - 4))
        }
        guard valued.count >= minimumSamples else { return .light(sampleCount: checkIns.count) }

        let grouped = Dictionary(grouping: valued) { calendar.startOfDay(for: $0.0.createdAt) }
        let points = grouped.keys.sorted().compactMap { day -> MoodTrendPoint? in
            guard let values = grouped[day], values.isEmpty == false else { return nil }
            let valence = values.reduce(0) { $0 + $1.1 } / Double(values.count)
            let energies = values.compactMap { $0.0.energy.map(Double.init) }
            return MoodTrendPoint(
                day: day,
                valence: valence,
                energy: energies.isEmpty ? nil : energies.reduce(0, +) / Double(energies.count),
                sampleCount: values.count
            )
        }
        let energies = valued.compactMap { $0.0.energy.map(Double.init) }
        return .ready(MoodTrendSummary(
            sampleCount: valued.count,
            averageValence: valued.reduce(0) { $0 + $1.1 } / Double(valued.count),
            averageEnergy: energies.isEmpty ? nil : energies.reduce(0, +) / Double(energies.count),
            dailyPoints: points
        ))
    }
}

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

public struct HabitGroup: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var planningContext: PlanningContext
    public var ordinal: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        planningContext: PlanningContext = .neutral,
        ordinal: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.planningContext = planningContext
        self.ordinal = ordinal
        self.createdAt = createdAt
    }
}

public enum HabitStreakPresentation: String, Codable, CaseIterable, Sendable {
    case gradeAndStreak
    case countsOnly
}

public struct HabitRecoveryReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var habitID: UUID
    public var day: PlanningDay
    public var occurrenceID: UUID?
    public var previousState: OccurrenceState
    public var appliedAt: Date

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        day: PlanningDay,
        occurrenceID: UUID? = nil,
        previousState: OccurrenceState,
        appliedAt: Date = Date()
    ) {
        self.id = id
        self.habitID = habitID
        self.day = day
        self.occurrenceID = occurrenceID
        self.previousState = previousState
        self.appliedAt = appliedAt
    }
}

public struct HabitResiliencePolicy: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var habitID: UUID
    public var groupID: UUID?
    public var offDays: Set<PlanningDay>
    public var recoveryEnabled: Bool
    public var streakPresentation: HabitStreakPresentation
    public var recoveryReceipts: [HabitRecoveryReceipt]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        habitID: UUID,
        groupID: UUID? = nil,
        offDays: Set<PlanningDay> = [],
        recoveryEnabled: Bool = true,
        streakPresentation: HabitStreakPresentation = .gradeAndStreak,
        recoveryReceipts: [HabitRecoveryReceipt] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.habitID = habitID
        self.groupID = groupID
        self.offDays = offDays
        self.recoveryEnabled = recoveryEnabled
        self.streakPresentation = streakPresentation
        self.recoveryReceipts = recoveryReceipts
        self.updatedAt = updatedAt
    }

    public var recoveredDays: Set<PlanningDay> {
        Set(recoveryReceipts.map(\.day))
    }

    private enum CodingKeys: String, CodingKey {
        case id, habitID, groupID, offDays, recoveryEnabled, streakPresentation, recoveryReceipts, updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        habitID = try values.decode(UUID.self, forKey: .habitID)
        groupID = try values.decodeIfPresent(UUID.self, forKey: .groupID)
        offDays = try values.decodeIfPresent(Set<PlanningDay>.self, forKey: .offDays) ?? []
        recoveryEnabled = try values.decodeIfPresent(Bool.self, forKey: .recoveryEnabled) ?? true
        streakPresentation = try values.decodeIfPresent(HabitStreakPresentation.self, forKey: .streakPresentation) ?? .gradeAndStreak
        recoveryReceipts = try values.decodeIfPresent([HabitRecoveryReceipt].self, forKey: .recoveryReceipts) ?? []
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(habitID, forKey: .habitID)
        try values.encodeIfPresent(groupID, forKey: .groupID)
        try values.encode(offDays, forKey: .offDays)
        try values.encode(recoveryEnabled, forKey: .recoveryEnabled)
        try values.encode(streakPresentation, forKey: .streakPresentation)
        try values.encode(recoveryReceipts, forKey: .recoveryReceipts)
        try values.encode(updatedAt, forKey: .updatedAt)
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

/// A typed pointer back to the domain record a normalized event was derived from.
/// Lets Eva and Insights attach honest source chips without exposing managed objects.
public struct EvidenceReference: Codable, Equatable, Hashable, Sendable {
    public var sourceID: UUID
    /// Stable domain slug: task, habit, routine, goal, tracker, medication, mood, sleep,
    /// hydration, journal, focus, plan, care.
    public var kind: String
    public var display: String
    public var routeID: UUID?

    public init(sourceID: UUID, kind: String, display: String, routeID: UUID? = nil) {
        self.sourceID = sourceID
        self.kind = kind
        self.display = display
        self.routeID = routeID
    }
}

/// Deterministic freshness derived from how recently the source was observed, relative to
/// per-source thresholds. Distinguishes honest states so surfaces never fake progress.
public enum EventFreshness: String, Codable, CaseIterable, Sendable {
    case loading
    case complete
    case partial
    case stale
    case unavailable
}

/// Whether an event may be surfaced to a given destination. `requiresConsent` gates
/// sensitive evidence (e.g. Journal) out of Eva until the user explicitly authorizes it.
public enum EvidenceAuthorization: String, Codable, CaseIterable, Sendable {
    case authorized
    case requiresConsent
    case denied
}

/// How an event must be redacted before it crosses an external surface (widgets, Eva prompt,
/// exports). `sensitiveSummary` keeps aggregates but drops identifying detail.
public enum RedactionPolicy: String, Codable, CaseIterable, Sendable {
    case none
    case sensitiveSummary
    case fullyRedacted
}

/// A durable pointer to the mutation receipt that produced an event, when one exists.
public struct MutationReceiptReference: Codable, Equatable, Hashable, Sendable {
    public var receiptID: UUID
    public var summary: String

    public init(receiptID: UUID, summary: String) {
        self.receiptID = receiptID
        self.summary = summary
    }
}

/// Reversal metadata. Observations that cannot be undone use `.notApplicable` — we never
/// fabricate a reversible receipt for something that was only recorded, not mutated.
public enum ReversalState: Codable, Equatable, Hashable, Sendable {
    case reversible(receiptID: UUID)
    case reversed(receiptID: UUID)
    case notApplicable
}

/// Stable domains whose in-place edits must preserve the previous value. Correction receipts are
/// local-only recovery metadata: the primary records continue to use their existing sync stores.
public enum TrackCorrectionDomain: String, Codable, CaseIterable, Sendable {
    case hydration
    case sleep
    case mood
    case tracker
    case medication
    case fasting
}

/// A typed snapshot avoids lossy dictionaries and lets reversal restore the exact value that was
/// present before a correction. New cases are additive and do not alter any synced model schema.
public enum TrackCorrectionPayload: Codable, Hashable, Sendable {
    case hydration(HydrationLog)
    case sleep(SleepContextRecord)
    case mood(LifeBoardMoodEnergyCheckInValue)
    case tracker(LifeBoardTrackerEntryValue)
    case medication(LifeBoardMedicationEventValue)
    case fasting(LifeBoardFastingSessionValue)

    public var sourceID: UUID {
        switch self {
        case .hydration(let value): value.id
        case .sleep(let value): value.id
        case .mood(let value): value.id
        case .tracker(let value): value.id
        case .medication(let value): value.id
        case .fasting(let value): value.id
        }
    }

    public var domain: TrackCorrectionDomain {
        switch self {
        case .hydration: .hydration
        case .sleep: .sleep
        case .mood: .mood
        case .tracker: .tracker
        case .medication: .medication
        case .fasting: .fasting
        }
    }
}

public struct TrackCorrectionReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sourceID: UUID
    public let domain: TrackCorrectionDomain
    public let previous: TrackCorrectionPayload
    public let corrected: TrackCorrectionPayload
    public let appliedAt: Date
    public var reversedAt: Date?

    public init(
        id: UUID,
        previous: TrackCorrectionPayload,
        corrected: TrackCorrectionPayload,
        appliedAt: Date,
        reversedAt: Date? = nil
    ) {
        precondition(previous.sourceID == corrected.sourceID, "A correction must preserve source identity")
        precondition(previous.domain == corrected.domain, "A correction must preserve its domain")
        self.id = id
        sourceID = previous.sourceID
        domain = previous.domain
        self.previous = previous
        self.corrected = corrected
        self.appliedAt = appliedAt
        self.reversedAt = reversedAt
    }

    public var isReversed: Bool { reversedAt != nil }

    public var reference: MutationReceiptReference {
        MutationReceiptReference(receiptID: id, summary: "Corrected \(domain.rawValue)")
    }

    public var reversalState: ReversalState {
        reversedAt == nil ? .reversible(receiptID: id) : .reversed(receiptID: id)
    }
}

public protocol TrackCorrectionReceiptRepository: Sendable {
    func fetchTrackCorrectionReceipts() async throws -> [TrackCorrectionReceipt]
    func saveTrackCorrectionReceipt(_ receipt: TrackCorrectionReceipt) async throws
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
    // Additive evidence contract (Milestone 1). Defaults keep existing emission sites valid.
    public var evidence: [EvidenceReference] = []
    public var freshness: EventFreshness = .complete
    public var authorization: EvidenceAuthorization = .authorized
    public var redaction: RedactionPolicy = .none
    public var receipt: MutationReceiptReference? = nil
    public var reversal: ReversalState = .notApplicable
}

public struct NormalizedLifeEventProjector: Sendable {
    public var policy: EvidenceAuthorizationPolicy
    public var timeZone: TimeZone

    public init(
        policy: EvidenceAuthorizationPolicy = EvidenceAuthorizationPolicy(),
        timeZone: TimeZone = .current
    ) {
        self.policy = policy
        self.timeZone = timeZone
    }

    public func event(
        sourceID: UUID,
        domain: String,
        kind: String,
        occurredAt: Date,
        numericValue: Double? = nil,
        completeness: ProjectionCompleteness = .complete,
        sensitivity: DataSensitivity = .privateStandard,
        provenance: String,
        evidenceDisplay: String,
        evidenceRouteID: UUID? = nil,
        receipt: MutationReceiptReference? = nil,
        reversal: ReversalState = .notApplicable,
        now: Date = Date()
    ) -> NormalizedLifeEvent {
        NormalizedLifeEvent(
            id: "\(domain):\(kind):\(sourceID.uuidString):\(occurredAt.timeIntervalSince1970)",
            sourceID: sourceID,
            domain: domain,
            kind: kind,
            occurredAt: occurredAt,
            localDay: PlanningDay(date: occurredAt, timeZone: timeZone),
            numericValue: numericValue,
            completeness: completeness,
            sensitivity: sensitivity,
            allowedDestinations: policy.allowedDestinations(domain: domain, sensitivity: sensitivity),
            provenance: provenance,
            evidence: [.init(sourceID: sourceID, kind: domain, display: evidenceDisplay, routeID: evidenceRouteID)],
            freshness: policy.freshness(domain: domain, occurredAt: occurredAt, now: now),
            authorization: .authorized,
            redaction: .none,
            receipt: receipt,
            reversal: reversal
        )
    }
}

/// Deterministic authorization + redaction + freshness rules for normalized events. Replaces
/// the per-call-site literals so every domain answers "who may see this, how redacted, and how
/// fresh is it" the same way. Pure value type — no I/O, fully testable.
public struct EvidenceAuthorizationPolicy: Sendable {
    public init() {}

    /// Destinations permitted to see a domain's events by default. Sensitive domains stay off
    /// Insights/Eva; Journal is never authorized for Eva here (it needs explicit consent).
    public func allowedDestinations(domain: String, sensitivity: DataSensitivity) -> Set<LifeBoardDestination> {
        switch domain {
        case "journal": return [.track]
        case "mood", "sleep", "medication", "care": return [.home, .track]
        case "hydration": return [.home, .track, .insights]
        case "routine": return [.home, .track, .plan, .eva]
        case "habit": return [.home, .track, .insights, .eva]
        case "goal": return [.home, .track, .insights, .eva]
        case "focus", "plan", "task": return [.home, .plan, .insights, .eva]
        default:
            return sensitivity == .privateSensitive ? [.track] : [.home, .track, .insights]
        }
    }

    public func authorization(
        domain: String,
        destination: LifeBoardDestination,
        sensitivity: DataSensitivity,
        journalConsentGranted: Bool
    ) -> EvidenceAuthorization {
        if domain == "journal", destination == .eva {
            return journalConsentGranted ? .authorized : .requiresConsent
        }
        return allowedDestinations(domain: domain, sensitivity: sensitivity).contains(destination) ? .authorized : .denied
    }

    public func redaction(sensitivity: DataSensitivity, destination: LifeBoardDestination) -> RedactionPolicy {
        guard sensitivity == .privateSensitive else { return .none }
        switch destination {
        case .insights, .eva: return .sensitiveSummary
        default: return .none
        }
    }

    /// Freshness from age relative to a per-domain threshold. Future timestamps read as complete.
    public func freshness(domain: String, occurredAt: Date, now: Date) -> EventFreshness {
        let age = now.timeIntervalSince(occurredAt)
        guard age >= 0 else { return .complete }
        return age <= Self.freshnessThreshold(domain: domain) ? .complete : .stale
    }

    public static func freshnessThreshold(domain: String) -> TimeInterval {
        switch domain {
        case "hydration", "mood": return 60 * 60 * 18
        case "medication": return 60 * 60 * 24
        case "sleep": return 60 * 60 * 36
        case "routine", "goal": return 60 * 60 * 24 * 2
        default: return 60 * 60 * 24
        }
    }
}

/// A derived read of normalized events, authorized and redaction-tagged for a destination.
/// It is a projection over events already produced by the domain stores — not a new store.
public protocol LifeEventProjectionRepository: Sendable {
    func authorizedEvents(for destination: LifeBoardDestination, journalConsentGranted: Bool) -> [NormalizedLifeEvent]
}

/// Explicit, local-only consent for sensitive evidence entering Eva. Every switch defaults off;
/// ordinary action evidence continues to use the destination authorization matrix.
public struct EvaEvidenceSharingPolicy: Codable, Equatable, Sendable {
    public var permitsJournal: Bool
    public var permitsBody: Bool
    public var permitsMood: Bool
    public var permitsCare: Bool

    public init(
        permitsJournal: Bool = false,
        permitsBody: Bool = false,
        permitsMood: Bool = false,
        permitsCare: Bool = false
    ) {
        self.permitsJournal = permitsJournal
        self.permitsBody = permitsBody
        self.permitsMood = permitsMood
        self.permitsCare = permitsCare
    }

    public func permits(domain: String) -> Bool {
        switch domain {
        case "journal": permitsJournal
        case "hydration", "sleep": permitsBody
        case "mood": permitsMood
        case "medication", "care": permitsCare
        default: false
        }
    }
}

public enum EvaEvidenceSharingPolicyPersistence {
    public static let defaultsKey = "lifeboard.eva.evidence-sharing.v1"

    public static func load(from defaults: UserDefaults) -> EvaEvidenceSharingPolicy {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(EvaEvidenceSharingPolicy.self, from: data) else {
            return EvaEvidenceSharingPolicy()
        }
        return value
    }

    public static func save(_ policy: EvaEvidenceSharingPolicy, to defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(policy), forKey: defaultsKey)
    }
}

/// Concrete projection over a snapshot's normalized events. Applies `EvidenceAuthorizationPolicy`
/// so Insights and Eva never re-implement authorization or redaction inline.
public struct SnapshotLifeEventProjectionRepository: LifeEventProjectionRepository {
    private let allEvents: [NormalizedLifeEvent]
    private let policy: EvidenceAuthorizationPolicy

    public init(events: [NormalizedLifeEvent], policy: EvidenceAuthorizationPolicy = EvidenceAuthorizationPolicy()) {
        self.allEvents = events
        self.policy = policy
    }

    public func authorizedEvents(for destination: LifeBoardDestination, journalConsentGranted: Bool) -> [NormalizedLifeEvent] {
        authorizedEvents(
            for: destination,
            sharingPolicy: EvaEvidenceSharingPolicy(permitsJournal: journalConsentGranted)
        )
    }

    public func authorizedEvents(
        for destination: LifeBoardDestination,
        sharingPolicy: EvaEvidenceSharingPolicy
    ) -> [NormalizedLifeEvent] {
        allEvents.compactMap { event in
            let hasExplicitEvaConsent = destination == .eva && sharingPolicy.permits(domain: event.domain)
            let authorization: EvidenceAuthorization = hasExplicitEvaConsent
                ? .authorized
                : policy.authorization(
                    domain: event.domain,
                    destination: destination,
                    sensitivity: event.sensitivity,
                    journalConsentGranted: sharingPolicy.permitsJournal
                )
            guard authorization == .authorized else { return nil }
            guard event.allowedDestinations.contains(destination) || hasExplicitEvaConsent else { return nil }
            var projected = event
            if hasExplicitEvaConsent {
                projected.allowedDestinations.insert(destination)
            }
            projected.authorization = authorization
            projected.redaction = policy.redaction(sensitivity: event.sensitivity, destination: destination)
            return projected
        }
    }
}

/// A bounded, already-authorized evidence snapshot injected into Eva. It deliberately carries
/// normalized events rather than repository objects so the chat runtime cannot bypass destination
/// authorization or infer missing health, medication, mood, or Journal data.
public struct EvaAuthorizedEvidenceContext: Equatable, Sendable {
    public enum Availability: String, Equatable, Sendable {
        case notProvided
        case loading
        case ready
        case failed
    }

    public var availability: Availability
    public var events: [NormalizedLifeEvent]
    public var withheldDomains: [String]
    public var failureMessage: String?

    public init(
        availability: Availability,
        events: [NormalizedLifeEvent] = [],
        withheldDomains: [String] = [],
        failureMessage: String? = nil
    ) {
        self.availability = availability
        self.events = events
        self.withheldDomains = Array(Set(withheldDomains)).sorted()
        self.failureMessage = failureMessage
    }

    public static let notProvided = Self(availability: .notProvided)
    public static let loading = Self(availability: .loading)

    public struct Citation: Identifiable, Equatable, Sendable {
        public let id: String
        public let label: String
        public let reference: EvidenceReference

        public init(id: String, label: String, reference: EvidenceReference) {
            self.id = id
            self.label = label
            self.reference = reference
        }
    }

    /// Resolves only citation tokens that were actually supplied in this authorized snapshot.
    /// Duplicate tokens preserve first-mention order and never expose a sensitive source display.
    public func citations(in text: String) -> [Citation] {
        guard availability == .ready else { return [] }
        let pattern = #"\[LB-([A-Fa-f0-9]{8})\]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        var result: [Citation] = []

        for match in expression.matches(in: text, range: range) {
            guard let tokenRange = Range(match.range(at: 1), in: text) else { continue }
            let token = String(text[tokenRange]).uppercased()
            guard seen.insert(token).inserted else { continue }
            guard let event = events.first(where: {
                $0.authorization == .authorized
                    && $0.allowedDestinations.contains(.eva)
                    && $0.sourceID.uuidString.uppercased().hasPrefix(token)
            }), let reference = event.evidence.first else { continue }

            let label = event.redaction == .sensitiveSummary || event.sensitivity == .privateSensitive
                ? "\(event.domain.capitalized) evidence"
                : (reference.display.isEmpty ? "\(event.domain.capitalized) evidence" : reference.display)
            result.append(Citation(id: "LB-\(token)", label: label, reference: reference))
        }
        return result
    }

    /// Produces a compact evidence block for the system prompt. References are stable per source,
    /// sensitive summaries never include source display text or numeric values, and stale/partial
    /// state is explicit so Eva cannot silently promote weak evidence into a factual claim.
    public func promptBlock(maxCharacters: Int = 4_000) -> String? {
        guard availability != .notProvided else { return nil }

        var lines = [
            "LIFEBOARD AUTHORIZED EVIDENCE",
            "Use only the evidence below for LifeBoard-specific factual claims. Cite its [LB-…] reference in the same paragraph. Say when evidence is stale, partial, withheld, or unavailable. Never infer a missing value. Propose mutations without applying them; only a separate confirmed action may mutate data."
        ]

        switch availability {
        case .notProvided:
            return nil
        case .loading:
            lines.append("State: evidence is still loading; say it is not available yet.")
        case .failed:
            let detail = failureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("State: evidence is unavailable\(detail.map { " (\($0))" } ?? "").")
        case .ready:
            let authorized = events
                .filter { $0.authorization == .authorized && $0.allowedDestinations.contains(.eva) }
                .sorted {
                    if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                    return $0.id < $1.id
                }

            if authorized.isEmpty {
                lines.append("State: no authorized LifeBoard evidence is available for this turn.")
            } else {
                for event in authorized.prefix(24) {
                    let reference = "LB-\(event.sourceID.uuidString.prefix(8).uppercased())"
                    let completeness = event.completeness == .complete ? "complete" : "partial"
                    let timestamp = event.occurredAt.ISO8601Format()
                    var components = [
                        "[\(reference)]",
                        "\(event.domain)/\(event.kind)",
                        timestamp,
                        "freshness=\(event.freshness.rawValue)",
                        "completeness=\(completeness)"
                    ]
                    if event.redaction == .sensitiveSummary || event.sensitivity == .privateSensitive {
                        components.append("source=sensitive summary")
                    } else {
                        if let display = event.evidence.first?.display, display.isEmpty == false {
                            components.append("source=\(display)")
                        }
                        if let numericValue = event.numericValue {
                            components.append("value=\(numericValue.formatted())")
                        }
                    }
                    let candidate = components.joined(separator: " | ")
                    let prospectiveCount = lines.joined(separator: "\n").count + candidate.count + 1
                    guard prospectiveCount <= maxCharacters else { break }
                    lines.append(candidate)
                }
            }
        }

        if withheldDomains.isEmpty == false {
            lines.append("Withheld domains: \(withheldDomains.joined(separator: ", ")). Do not imply that withheld means zero or none.")
        }
        return String(lines.joined(separator: "\n").prefix(max(0, maxCharacters)))
    }

    /// Adds evidence as an additive JSON field when the existing context is a JSON object, keeping
    /// the planner's receipt and task parsers intact. Plain-text contexts receive a delimited block.
    public func injecting(into contextPayload: String, maxCharacters: Int = 4_000) -> String {
        guard let block = promptBlock(maxCharacters: maxCharacters) else { return contextPayload }
        if let data = contextPayload.data(using: .utf8),
           var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            object["authorized_lifeboard_evidence"] = block
            if let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
               let value = String(data: encoded, encoding: .utf8) {
                return value
            }
        }
        return "\(contextPayload)\n\n---\n\(block)"
    }
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

public protocol GoalSampleProvider: Sendable {
    func samples(for links: [GoalLink], asOf date: Date) async throws -> [GoalProgressSample]
}

public protocol TrackHabitProjectionService: Sendable {
    func occurrenceEvidence(from: Date, to: Date, now: Date, calendar: Calendar) async throws -> [UUID: [HabitOccurrenceEvidence]]
}

public protocol HabitRecoveryMutationApplying: Sendable {
    func recover(habitID: UUID, day: PlanningDay) async throws -> HabitRecoveryReceipt
    func revert(_ receipt: HabitRecoveryReceipt) async throws
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
public struct GoalHomeContextCandidateProvider: HomeContextCandidateProvider {
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
                ? "Today is the target date you set for this goal."
                : "The target date you set is \(days == 1 ? "tomorrow" : "in \(days) days")."
            return HomeContextCandidate(
                id: "goal-window:\(goal.id.uuidString)",
                widgetKind: .goals,
                title: goal.title,
                reason: .init(message: reason, signal: "goalTargetDate"),
                destination: .track,
                sensitivity: .privateStandard,
                priority: days == 0 ? 620 : 340 + (thresholdDays - days),
                relevantFrom: context.date,
                relevantUntil: target.addingTimeInterval(24 * 60 * 60)
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
public struct RoutineHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "routines"
    private let repository: any TrackFoundationRepository
    private let daypart: @Sendable (Date) -> ResolvedDaypart

    public init(
        repository: any TrackFoundationRepository,
        daypart: @escaping @Sendable (Date) -> ResolvedDaypart = { LifeBoardDaypartResolver.resolve(at: $0) }
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
                    message: "You scheduled this routine for this part of the day.",
                    signal: "routineSchedule"
                ),
                destination: .track,
                sensitivity: .privateStandard,
                priority: 400,
                relevantFrom: context.date,
                relevantUntil: calendar.date(byAdding: .hour, value: 6, to: context.date)
            )
        }
        .sorted { $0.id < $1.id }
    }
}
