import Foundation

// MARK: - Planning identity and task metadata

public struct PlanningDay: Codable, Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let timeZoneIdentifier: String

    public init(year: Int, month: Int, day: Int, timeZoneIdentifier: String) {
        self.year = year
        self.month = month
        self.day = day
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public init(date: Date, timeZone: TimeZone = .current, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1,
            month: components.month ?? 1,
            day: components.day ?? 1,
            timeZoneIdentifier: timeZone.identifier
        )
    }

    public func startDate(calendar: Calendar = .current) -> Date? {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public static func < (lhs: PlanningDay, rhs: PlanningDay) -> Bool {
        (lhs.year, lhs.month, lhs.day, lhs.timeZoneIdentifier)
            < (rhs.year, rhs.month, rhs.day, rhs.timeZoneIdentifier)
    }
}

public enum PlanningContext: String, Codable, CaseIterable, Sendable {
    case neutral
    case work
    case personal
}

public enum TaskCommitmentLevel: String, Codable, CaseIterable, Sendable {
    case standard
    case mustDo
}

public enum TaskAvailability: String, Codable, CaseIterable, Sendable {
    case actionable
    case waiting
    case paused
}

public enum ProjectExecutionMode: String, Codable, CaseIterable, Sendable {
    case parallel
    case sequential
}

public enum UnscheduledDisposition: String, Codable, CaseIterable, Sendable {
    case inbox
    case someday
}

public struct PlanningTaskMetadata: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { taskID }
    public let taskID: UUID
    public var planningDay: PlanningDay?
    public var commitmentLevel: TaskCommitmentLevel
    public var availability: TaskAvailability
    public var planningContext: PlanningContext
    public var unscheduledDisposition: UnscheduledDisposition
    public var availabilityExplanation: String?
    public var resumeDate: Date?
    public var pinOrder: Int?
    public var updatedAt: Date

    public init(
        taskID: UUID,
        planningDay: PlanningDay? = nil,
        commitmentLevel: TaskCommitmentLevel = .standard,
        availability: TaskAvailability = .actionable,
        planningContext: PlanningContext = .neutral,
        unscheduledDisposition: UnscheduledDisposition = .inbox,
        availabilityExplanation: String? = nil,
        resumeDate: Date? = nil,
        pinOrder: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.taskID = taskID
        self.planningDay = planningDay
        self.commitmentLevel = commitmentLevel
        self.availability = availability
        self.planningContext = planningContext
        self.unscheduledDisposition = unscheduledDisposition
        self.availabilityExplanation = availabilityExplanation
        self.resumeDate = resumeDate
        self.pinOrder = pinOrder
        self.updatedAt = updatedAt
    }
}

public enum PlanningDayTravelPolicy: String, Codable, CaseIterable, Sendable {
    /// Keep the local year/month/day the user chose, even after the device time zone changes.
    case preserveIntendedDay
    /// Re-resolve the absolute start of the original day into the destination time zone.
    case followAbsoluteDate
}

public protocol PlanningDayResolver: Sendable {
    func resolve(
        _ day: PlanningDay,
        in destinationTimeZone: TimeZone,
        policy: PlanningDayTravelPolicy,
        calendar: Calendar
    ) -> PlanningDay
}

// MARK: - Time blocks and capacity

public struct InternalTimeBlock: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var startAt: Date
    public var endAt: Date
    public var taskID: UUID?
    public var planningContext: PlanningContext
    public var isFixed: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        startAt: Date,
        endAt: Date,
        taskID: UUID? = nil,
        planningContext: PlanningContext = .neutral,
        isFixed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
        self.taskID = taskID
        self.planningContext = planningContext
        self.isFixed = isFixed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

public struct WorkingHoursInterval: Codable, Hashable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(1_439, max(0, startMinute))
        self.endMinute = min(1_440, max(self.startMinute, endMinute))
    }

    public var duration: TimeInterval { TimeInterval(max(0, endMinute - startMinute) * 60) }
}

public struct WorkingHoursProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var intervalsByWeekday: [Int: [WorkingHoursInterval]]
    public var bufferDuration: TimeInterval
    public var isDefault: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Default",
        intervalsByWeekday: [Int: [WorkingHoursInterval]] = [:],
        bufferDuration: TimeInterval = 30 * 60,
        isDefault: Bool = true,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.intervalsByWeekday = intervalsByWeekday
        self.bufferDuration = max(0, bufferDuration)
        self.isDefault = isDefault
        self.updatedAt = updatedAt
    }
}

public struct CapacityBudget: Codable, Equatable, Sendable {
    public var workingDuration: TimeInterval
    public var fixedCalendarDuration: TimeInterval
    public var internalFixedDuration: TimeInterval
    public var bufferDuration: TimeInterval
    public var usableDuration: TimeInterval
    public var plannedEstimatedDuration: TimeInterval
    public var missingEstimateCount: Int
    public var confidence: Double

    public init(
        workingDuration: TimeInterval,
        fixedCalendarDuration: TimeInterval,
        internalFixedDuration: TimeInterval,
        bufferDuration: TimeInterval,
        plannedEstimatedDuration: TimeInterval,
        missingEstimateCount: Int
    ) {
        self.workingDuration = max(0, workingDuration)
        self.fixedCalendarDuration = max(0, fixedCalendarDuration)
        self.internalFixedDuration = max(0, internalFixedDuration)
        self.bufferDuration = max(0, bufferDuration)
        self.usableDuration = max(
            0,
            self.workingDuration - self.fixedCalendarDuration - self.internalFixedDuration - self.bufferDuration
        )
        self.plannedEstimatedDuration = max(0, plannedEstimatedDuration)
        self.missingEstimateCount = max(0, missingEstimateCount)
        self.confidence = missingEstimateCount == 0 ? 1 : max(0.25, 1 - Double(missingEstimateCount) * 0.15)
    }

    public var overloadDuration: TimeInterval { max(0, plannedEstimatedDuration - usableDuration) }
    public var remainingKnownCapacity: TimeInterval { max(0, usableDuration - plannedEstimatedDuration) }
    public var isEstimateIncomplete: Bool { missingEstimateCount > 0 }
}

public struct PlanningFixedCommitment: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var startAt: Date
    public var endAt: Date
    public var source: Source

    public enum Source: String, Codable, Sendable {
        case externalCalendar
        case internalBlock
    }

    public init(id: String, title: String, startAt: Date, endAt: Date, source: Source) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
        self.source = source
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

public enum PlanningCalendarAuthorization: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unavailable
}

/// A read-only view of an EventKit commitment. LifeBoard never persists or mutates it.
public struct CalendarCommitment: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var calendarID: String
    public var title: String
    public var startAt: Date
    public var endAt: Date
    public var isAllDay: Bool
    public var availability: String?

    public init(
        id: String,
        calendarID: String,
        title: String,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        availability: String? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
        self.isAllDay = isAllDay
        self.availability = availability
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

public struct FreeWindow: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(startAt.timeIntervalSinceReferenceDate)-\(endAt.timeIntervalSinceReferenceDate)" }
    public var startAt: Date
    public var endAt: Date

    public init(startAt: Date, endAt: Date) {
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

public struct PlanningCalendarContext: Codable, Equatable, Sendable {
    public var authorization: PlanningCalendarAuthorization
    public var commitments: [CalendarCommitment]
    public var fetchedAt: Date

    public init(
        authorization: PlanningCalendarAuthorization,
        commitments: [CalendarCommitment] = [],
        fetchedAt: Date = Date()
    ) {
        self.authorization = authorization
        self.commitments = commitments
        self.fetchedAt = fetchedAt
    }
}

public struct PlanningTaskSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var projectID: UUID?
    public var dueDate: Date?
    public var estimatedDuration: TimeInterval?
    public var metadata: PlanningTaskMetadata
    public var dependenciesReady: Bool
    public var priority: FocusPriorityBand
    public var requiredEnergy: Int?
    public var locationContext: String?
    public var scheduledStartAt: Date?
    public var scheduledEndAt: Date?
    public var alignsWithWeeklyOutcome: Bool
    public var projectExecutionMode: ProjectExecutionMode

    public init(
        id: UUID,
        title: String,
        projectID: UUID? = nil,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        metadata: PlanningTaskMetadata,
        dependenciesReady: Bool = true,
        priority: FocusPriorityBand = .medium,
        requiredEnergy: Int? = nil,
        locationContext: String? = nil,
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        alignsWithWeeklyOutcome: Bool = false,
        projectExecutionMode: ProjectExecutionMode = .parallel
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.metadata = metadata
        self.dependenciesReady = dependenciesReady
        self.priority = priority
        self.requiredEnergy = requiredEnergy
        self.locationContext = locationContext
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.alignsWithWeeklyOutcome = alignsWithWeeklyOutcome
        self.projectExecutionMode = projectExecutionMode
    }
}

public struct PlanDaySnapshot: Codable, Equatable, Sendable {
    public var day: PlanningDay
    public var capacity: CapacityBudget
    public var commitments: [PlanningFixedCommitment]
    public var calendarAuthorization: PlanningCalendarAuthorization = .notDetermined
    public var freeWindows: [FreeWindow] = []
    public var blocks: [InternalTimeBlock]
    public var plannedTasks: [PlanningTaskSummary]
    public var unscheduledTasks: [PlanningTaskSummary]
    public var generatedAt: Date
}

public struct PlanWeekDaySummary: Codable, Equatable, Identifiable, Sendable {
    public var id: PlanningDay { day }
    public var day: PlanningDay
    public var capacity: CapacityBudget
    public var mustDoCount: Int
    public var deadlineCount: Int
}

public struct PlanWeekSnapshot: Codable, Equatable, Sendable {
    public var days: [PlanWeekDaySummary]
    public var unplannedTasks: [PlanningTaskSummary]
    public var generatedAt: Date
}

public enum BacklogGroup: String, Codable, CaseIterable, Sendable {
    case inbox
    case thisWeek
    case nextWeek
    case later
    case someday
    case waiting
    case paused
}

public struct PlanBacklogSnapshot: Codable, Equatable, Sendable {
    public var groups: [BacklogGroup: [PlanningTaskSummary]]
    public var generatedAt: Date
}

// MARK: - Focus ranking

public enum FocusPriorityBand: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case urgent
}

public enum FocusRankComponent: String, Codable, CaseIterable, Sendable {
    case urgency
    case priority
    case freeWindowFit
    case durationFit
    case energyFit
    case contextFit
    case dependencyReadiness
    case weeklyOutcomeAlignment
}

public enum FocusEligibilityExclusion: String, Codable, CaseIterable, Sendable {
    case completed
    case waiting
    case paused
    case dependencyBlocked
}

public struct FocusRankReason: Codable, Equatable, Hashable, Sendable {
    public var component: FocusRankComponent
    public var text: String

    public init(component: FocusRankComponent, text: String) {
        self.component = component
        self.text = text
    }
}

public struct FocusRankCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var availability: TaskAvailability
    public var dependenciesReady: Bool
    public var isActiveSession: Bool
    public var pinOrder: Int?
    public var commitmentLevel: TaskCommitmentLevel
    public var priority: FocusPriorityBand
    public var planningDay: PlanningDay?
    public var dueDate: Date?
    public var estimatedDuration: TimeInterval?
    public var requiredEnergy: Int?
    public var planningContext: PlanningContext?
    public var alignsWithWeeklyOutcome: Bool

    public init(
        id: UUID,
        title: String,
        isCompleted: Bool = false,
        availability: TaskAvailability = .actionable,
        dependenciesReady: Bool = true,
        isActiveSession: Bool = false,
        pinOrder: Int? = nil,
        commitmentLevel: TaskCommitmentLevel = .standard,
        priority: FocusPriorityBand = .medium,
        planningDay: PlanningDay? = nil,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        requiredEnergy: Int? = nil,
        planningContext: PlanningContext? = nil,
        alignsWithWeeklyOutcome: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.availability = availability
        self.dependenciesReady = dependenciesReady
        self.isActiveSession = isActiveSession
        self.pinOrder = pinOrder
        self.commitmentLevel = commitmentLevel
        self.priority = priority
        self.planningDay = planningDay
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.requiredEnergy = requiredEnergy
        self.planningContext = planningContext
        self.alignsWithWeeklyOutcome = alignsWithWeeklyOutcome
    }
}

public struct FocusRankContext: Codable, Equatable, Sendable {
    public var now: Date
    public var timeZoneIdentifier: String
    public var freeWindowDuration: TimeInterval?
    public var availableEnergy: Int?
    public var planningContext: PlanningContext?

    public init(
        now: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier,
        freeWindowDuration: TimeInterval? = nil,
        availableEnergy: Int? = nil,
        planningContext: PlanningContext? = nil
    ) {
        self.now = now
        self.timeZoneIdentifier = timeZoneIdentifier
        self.freeWindowDuration = freeWindowDuration
        self.availableEnergy = availableEnergy
        self.planningContext = planningContext
    }
}

public struct FocusRankResult: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { candidateID }
    public let candidateID: UUID
    public var totalScore: Int
    public var componentScores: [FocusRankComponent: Int]
    public var eligibilityExclusions: [FocusEligibilityExclusion]
    public var confidence: Double
    public var reasons: [FocusRankReason]
    public var missingInformation: [String]

    public init(
        candidateID: UUID,
        totalScore: Int,
        componentScores: [FocusRankComponent: Int],
        eligibilityExclusions: [FocusEligibilityExclusion] = [],
        confidence: Double,
        reasons: [FocusRankReason],
        missingInformation: [String]
    ) {
        self.candidateID = candidateID
        self.totalScore = min(100, max(0, totalScore))
        self.componentScores = componentScores
        self.eligibilityExclusions = eligibilityExclusions
        self.confidence = min(1, max(0, confidence))
        self.reasons = Array(reasons.prefix(3))
        self.missingInformation = missingInformation
    }

    public var isEligible: Bool { eligibilityExclusions.isEmpty }
}

// MARK: - Focus execution and repair

public enum FocusCompletionOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case stopped
    case interrupted
    case intentionallyDeferred
}

public struct FocusExecutionReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var taskID: UUID?
    public var timeBlockID: UUID?
    public var targetDuration: TimeInterval
    public var actualFocusedDuration: TimeInterval
    public var interruptionCount: Int
    public var outcome: FocusCompletionOutcome
    public var energyAfter: Int?
    public var reflection: String?
    public var startedAt: Date
    public var endedAt: Date
}

public struct EstimateCalibrationSuggestion: Codable, Equatable, Sendable {
    public var taskID: UUID
    public var suggestedDuration: TimeInterval
    public var evidenceSessionCount: Int
    public var observedMinimum: TimeInterval
    public var observedMaximum: TimeInterval
    public var generatedAt: Date
}

public enum PlanRepairTrigger: String, Codable, CaseIterable, Sendable {
    case slippedTask
    case overrunBlock
    case missedPlannedWork
    case overloadedWindow
}

public enum PlanRepairAction: String, Codable, CaseIterable, Sendable {
    case resume
    case moveLaterToday
    case moveToAnotherDay
    case split
    case `defer`
    case leaveUnchanged
    case askEva
}

public struct PlanRepairProposal: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var trigger: PlanRepairTrigger
    public var taskID: UUID?
    public var timeBlockID: UUID?
    public var actions: [PlanRepairAction]
    public var explanation: String
    public var createdAt: Date
}

public struct PlanMutationReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var source: String
    public var summary: String
    public var forwardData: Data
    public var undoData: Data
    public var createdAt: Date
}

public enum PlanMutation: Codable, Hashable, Sendable {
    case saveTaskMetadata(before: PlanningTaskMetadata, after: PlanningTaskMetadata)
    case saveTimeBlock(before: InternalTimeBlock?, after: InternalTimeBlock)
    case deleteTimeBlock(InternalTimeBlock)
    indirect case batch([PlanMutation])
}

public enum FocusSessionState: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case paused
    case ended
}

public struct FocusSessionV2: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var taskID: UUID?
    public var timeBlockID: UUID?
    public var targetDuration: TimeInterval
    public var state: FocusSessionState
    public var startedAt: Date
    public var pausedAt: Date?
    public var endedAt: Date?
    public var accumulatedPauseDuration: TimeInterval
    public var interruptionCount: Int
    public var outcome: FocusCompletionOutcome?
    public var energyAfter: Int?
    public var reflection: String?
    public var appliedCommandIDs: Set<UUID>

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        timeBlockID: UUID? = nil,
        targetDuration: TimeInterval,
        state: FocusSessionState = .running,
        startedAt: Date = Date(),
        pausedAt: Date? = nil,
        endedAt: Date? = nil,
        accumulatedPauseDuration: TimeInterval = 0,
        interruptionCount: Int = 0,
        outcome: FocusCompletionOutcome? = nil,
        energyAfter: Int? = nil,
        reflection: String? = nil,
        appliedCommandIDs: Set<UUID> = []
    ) {
        self.id = id
        self.taskID = taskID
        self.timeBlockID = timeBlockID
        self.targetDuration = max(0, targetDuration)
        self.state = state
        self.startedAt = startedAt
        self.pausedAt = pausedAt
        self.endedAt = endedAt
        self.accumulatedPauseDuration = max(0, accumulatedPauseDuration)
        self.interruptionCount = max(0, interruptionCount)
        self.outcome = outcome
        self.energyAfter = energyAfter
        self.reflection = reflection
        self.appliedCommandIDs = appliedCommandIDs
    }

    public func focusedDuration(at now: Date = Date()) -> TimeInterval {
        let terminal = endedAt ?? pausedAt ?? now
        return max(0, terminal.timeIntervalSince(startedAt) - accumulatedPauseDuration)
    }
}

public enum FocusSessionCommandKind: Codable, Hashable, Sendable {
    case pause
    case resume
    case end(FocusCompletionOutcome)
}

public struct FocusSessionCommand: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sessionID: UUID
    public var kind: FocusSessionCommandKind
    public var occurredAt: Date

    public init(id: UUID = UUID(), sessionID: UUID, kind: FocusSessionCommandKind, occurredAt: Date = Date()) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.occurredAt = occurredAt
    }
}

// MARK: - Repository and service contracts

public protocol PlanningRepository: Sendable {
    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata]
    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws
    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws
}

public protocol PlanningProjectionRepository: Sendable {
    func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary]
}

public protocol PlanningCalendarContextRepository: Sendable {
    func authorization() async -> PlanningCalendarAuthorization
    func requestAccess() async -> PlanningCalendarAuthorization
    func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext
}

public protocol PlanningMutationRepository: Sendable {
    func prepare(_ mutation: PlanMutation, source: String, summary: String) async throws -> PlanMutationReceipt
    func apply(receiptID: UUID) async throws
    func undo(receiptID: UUID) async throws
}

public protocol FocusExecutionCoordinator: Sendable {
    func activeSession() async throws -> FocusSessionV2?
    func start(taskID: UUID?, timeBlockID: UUID?, targetDuration: TimeInterval, at: Date) async throws -> FocusSessionV2
    func handle(_ command: FocusSessionCommand) async throws -> FocusSessionV2
}

public protocol InternalTimeBlockRepository: Sendable {
    func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock]
    func saveTimeBlock(_ value: InternalTimeBlock) async throws
    func deleteTimeBlock(id: UUID) async throws
    func fetchWorkingHoursProfiles() async throws -> [WorkingHoursProfile]
    func saveWorkingHoursProfile(_ value: WorkingHoursProfile) async throws
}

public protocol FocusRankingService: Sendable {
    func rank(_ candidates: [FocusRankCandidate], context: FocusRankContext) -> [FocusRankResult]
}

public protocol PlanRepairService: Sendable {
    func proposals(for snapshot: PlanDaySnapshot, now: Date) -> [PlanRepairProposal]
}
