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
    case archived
    /// A sync-safe deletion marker. Mutation receipts can restore the canonical task exactly,
    /// while every planning and linked-source projection treats it as removed.
    case deleted
    /// Kept for lookup, never scheduled and never chased.
    ///
    /// Additive and safe on older builds: `CoreDataPlanningRepository` decodes an
    /// unrecognized disposition as `.inbox`, so a device that has not shipped
    /// this case shows the item as untriaged again rather than losing it. That
    /// is the correct degradation — reference material reappearing in the Inbox
    /// is recoverable, a silently vanished capture is not.
    case reference
}

public struct PlanningTaskMetadata: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { taskID }
    public let taskID: UUID
    public var planningDay: PlanningDay?
    /// The earliest day work may begin, distinct from `planningDay` (when you
    /// intend to do it) and `dueDate` (when it must be finished).
    ///
    /// Without this the three collapse into one and a task you cannot start
    /// until next week still appears actionable today. Optional and additive:
    /// existing metadata decodes with no start constraint, which is the same
    /// behavior as before.
    public var startDay: PlanningDay?
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
        startDay: PlanningDay? = nil,
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
        self.startDay = startDay
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

/// User-facing freshness and failure state for read-only calendar context.
///
/// Authorization alone cannot distinguish an empty fresh calendar from a
/// failed fetch or an offline cache. Keeping that distinction typed prevents
/// Plan from presenting stale openings as current availability.
public enum PlanningCalendarState: Codable, Equatable, Sendable {
    case notRequested
    case denied
    case loading
    case fresh(fetchedAt: Date)
    case staleCached(fetchedAt: Date, message: String)
    case offlineCached(fetchedAt: Date)
    case failed(message: String)
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
    /// Identifier shared by every occurrence of a recurring series.
    ///
    /// Separate from `id` because `EKEvent.eventIdentifier` *is* the series
    /// identifier for a recurring event — every Monday standup reports the same
    /// one. Anything keyed on identity alone (a per-occurrence decision, a
    /// per-occurrence note) would apply to the whole series. Pair this with
    /// `startAt` through `CalendarOccurrenceIdentity.key` to address one
    /// occurrence.
    public var seriesID: String?
    /// The user's real RSVP, read from EventKit. Read-only forever: EventKit
    /// exposes attendee status without a setter, so LifeBoard must never show a
    /// control implying it can answer an invitation.
    public var participation: CalendarParticipation?
    public var eventState: CalendarEventState?

    /// All three new fields decode as `nil`, so commitments persisted before
    /// they existed keep restoring and simply carry no decision context.
    public init(
        id: String,
        calendarID: String,
        title: String,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        availability: String? = nil,
        seriesID: String? = nil,
        participation: CalendarParticipation? = nil,
        eventState: CalendarEventState? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
        self.isAllDay = isAllDay
        self.availability = availability
        self.seriesID = seriesID
        self.participation = participation
        self.eventState = eventState
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }

    public var durationMinutes: Int { Int(duration / 60) }

    /// EventKit's `EKEventAvailability.free` is `1`. A commitment marked free
    /// does not claim the time, so it never enters a capacity decision.
    public var isBusy: Bool {
        guard let availability else { return true }
        return availability != "1"
    }

    /// The occurrence key this commitment's decisions are stored under.
    public func occurrenceKey(calendar: Calendar = .current, timeZone: TimeZone = .current) -> String {
        CalendarOccurrenceIdentity.key(
            seriesID: seriesID ?? id,
            occurrenceStart: startAt,
            calendar: calendar,
            timeZone: timeZone
        )
    }
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

public struct TaskFreeWindowCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(taskID.uuidString):\(window.id)" }
    public let taskID: UUID
    public let taskTitle: String
    public let estimate: TimeInterval
    public let window: FreeWindow

    public init(
        taskID: UUID,
        taskTitle: String,
        estimate: TimeInterval,
        window: FreeWindow
    ) {
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.estimate = max(0, estimate)
        self.window = window
    }
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

public struct PlanningProjectSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let isArchived: Bool

    public init(id: UUID, name: String, isArchived: Bool) {
        self.id = id
        self.name = name
        self.isArchived = isArchived
    }
}

public struct PlanDaySnapshot: Codable, Equatable, Sendable {
    public var day: PlanningDay
    public var capacity: CapacityBudget
    public var commitments: [PlanningFixedCommitment]
    public var calendarAuthorization: PlanningCalendarAuthorization = .notDetermined
    public var calendarState: PlanningCalendarState = .notRequested
    public var freeWindows: [FreeWindow] = []
    public var fitsNextCandidates: [TaskFreeWindowCandidate] = []
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
    /// Kept for lookup, not deferred work.
    ///
    /// Distinct from `someday` on purpose: Someday is "not now", Reference is
    /// "never scheduled". Folding them together would make the Inbox's Reference
    /// destination silently mean Someday, and reference material would start
    /// appearing in deferral reviews asking when the user plans to do it.
    case reference
    case waiting
    case paused
    case archived
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
    case abandoned
    case continueLater
}

public enum FocusMode: Codable, Hashable, Sendable {
    case countdown(duration: TimeInterval)
    case stopwatch
    case pomodoro(focus: TimeInterval, breakDuration: TimeInterval, rounds: Int)
    case openEnded

    public static let standardPomodoro = FocusMode.pomodoro(
        focus: 25 * 60,
        breakDuration: 5 * 60,
        rounds: 4
    )

    public var initialTargetDuration: TimeInterval {
        switch self {
        case .countdown(let duration):
            max(0, duration)
        case .pomodoro(let focus, _, _):
            max(0, focus)
        case .stopwatch, .openEnded:
            0
        }
    }
}

public enum FocusPomodoroPhaseKind: String, Codable, CaseIterable, Sendable {
    case focus
    case rest
}

/// Durable phase state for an active Pomodoro session. Keeping the phase in the
/// companion record means a process restart cannot silently reset the user to
/// round one while the canonical FocusSession remains active.
public struct FocusPomodoroPhase: Codable, Hashable, Sendable {
    public var kind: FocusPomodoroPhaseKind
    public var round: Int
    public var phaseStartedAt: Date
    public var phaseEndsAt: Date

    public init(
        kind: FocusPomodoroPhaseKind = .focus,
        round: Int = 1,
        phaseStartedAt: Date,
        phaseEndsAt: Date
    ) {
        self.kind = kind
        self.round = max(1, round)
        self.phaseStartedAt = phaseStartedAt
        self.phaseEndsAt = max(phaseEndsAt, phaseStartedAt)
    }
}

public struct FocusInterruptionEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var recordedAt: Date
    public var reason: String?

    public init(id: UUID = UUID(), recordedAt: Date = Date(), reason: String? = nil) {
        self.id = id
        self.recordedAt = recordedAt
        let cleanedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reason = cleanedReason?.isEmpty == false ? cleanedReason : nil
    }
}

public struct FocusSessionCompanion: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { sessionID }
    public let sessionID: UUID
    public var mode: FocusMode
    public var intention: String
    public var subtaskID: UUID?
    public var checkedSubtaskIDs: Set<UUID>
    public var interruptions: [FocusInterruptionEvent]
    public var pomodoroPhase: FocusPomodoroPhase?
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        sessionID: UUID,
        mode: FocusMode,
        intention: String = "",
        subtaskID: UUID? = nil,
        checkedSubtaskIDs: Set<UUID> = [],
        interruptions: [FocusInterruptionEvent] = [],
        pomodoroPhase: FocusPomodoroPhase? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.intention = intention
        self.subtaskID = subtaskID
        self.checkedSubtaskIDs = checkedSubtaskIDs
        self.interruptions = interruptions
        self.pomodoroPhase = pomodoroPhase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct FocusExecutionReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sessionID: UUID
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

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        taskID: UUID?,
        timeBlockID: UUID?,
        targetDuration: TimeInterval,
        actualFocusedDuration: TimeInterval,
        interruptionCount: Int,
        outcome: FocusCompletionOutcome,
        energyAfter: Int?,
        reflection: String?,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.taskID = taskID
        self.timeBlockID = timeBlockID
        self.targetDuration = max(0, targetDuration)
        self.actualFocusedDuration = max(0, actualFocusedDuration)
        self.interruptionCount = max(0, interruptionCount)
        self.outcome = outcome
        self.energyAfter = energyAfter
        self.reflection = reflection
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
    }
}

public struct FocusSessionStartRequest: Codable, Hashable, Sendable {
    public var taskID: UUID?
    public var timeBlockID: UUID?
    public var mode: FocusMode
    public var intention: String
    public var subtaskID: UUID?
    public var startedAt: Date

    public init(
        taskID: UUID? = nil,
        timeBlockID: UUID? = nil,
        mode: FocusMode,
        intention: String = "",
        subtaskID: UUID? = nil,
        startedAt: Date = Date()
    ) {
        self.taskID = taskID
        self.timeBlockID = timeBlockID
        self.mode = mode
        self.intention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtaskID = subtaskID
        self.startedAt = startedAt
    }
}

public struct FocusSessionRecovery: Codable, Hashable, Sendable {
    public var session: FocusSessionV2
    public var companion: FocusSessionCompanion?

    public init(session: FocusSessionV2, companion: FocusSessionCompanion?) {
        self.session = session
        self.companion = companion
    }
}

public enum FocusSessionCommandError: LocalizedError, Sendable {
    case alreadyActive(UUID)
    case sessionNotFound(UUID)
    case sessionAlreadyEnded(UUID)
    case notPomodoro(UUID)
    case pomodoroComplete(UUID)

    public var errorDescription: String? {
        switch self {
        case .alreadyActive:
            "A focus session is already active."
        case .sessionNotFound:
            "That focus session could not be found."
        case .sessionAlreadyEnded:
            "That focus session has already ended."
        case .notPomodoro:
            "This focus session is not using a Pomodoro rhythm."
        case .pomodoroComplete:
            "Every Pomodoro round is complete."
        }
    }
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

public enum PlanningReceiptState: String, Codable, CaseIterable, Sendable {
    case prepared
    case applied
    case undone
}

public struct PlanningReceiptRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { receipt.id }
    public var receipt: PlanMutationReceipt
    public var state: PlanningReceiptState
    public var appliedAt: Date?
    public var undoneAt: Date?

    public init(
        receipt: PlanMutationReceipt,
        state: PlanningReceiptState,
        appliedAt: Date? = nil,
        undoneAt: Date? = nil
    ) {
        self.receipt = receipt
        self.state = state
        self.appliedAt = appliedAt
        self.undoneAt = undoneAt
    }
}

public enum PlanMutation: Codable, Hashable, Sendable {
    case saveTaskMetadata(before: PlanningTaskMetadata, after: PlanningTaskMetadata)
    case saveTimeBlock(before: InternalTimeBlock?, after: InternalTimeBlock)
    case deleteTimeBlock(InternalTimeBlock)
    /// Completion is planning state, not planning *metadata*: it lives on the
    /// canonical `TaskDefinition` rather than on `PlanningTaskMetadata`. Routing
    /// it through `PlanMutation` anyway is what gives a completion the same
    /// receipt and one-step Undo as every other planning change, which the
    /// batch-mutation contract requires. Appended last so previously encoded
    /// `forwardData`/`undoData` payloads keep decoding.
    case setTaskCompletion(taskID: UUID, before: Bool, after: Bool)
    indirect case batch([PlanMutation])
}

public enum PlanningScenarioSource: String, Codable, CaseIterable, Sendable {
    case manual
    case repair
    case minimumViableDay
    case multiItemReschedule
    /// End-of-day reconciliation: every unfinished commitment resolved in one
    /// batch, so the whole act is one receipt and one Undo.
    ///
    /// Additive and safe on older builds for the same reason as
    /// `UnscheduledDisposition.reference` — a scenario is never persisted, only
    /// the `PlanMutation` batch it produces is, and that batch uses cases that
    /// already shipped.
    case dayClose
    /// Morning commitment: today's shape confirmed in one batch.
    ///
    /// Deliberately distinct from `.minimumViableDay`, which builds a very
    /// similar batch. That one means "make today small"; this one means "this is
    /// today". Folding them would make a reduced day indistinguishable from an
    /// ordinary commit in the ledger, and the ledger is how the loop remembers.
    case dayOpen
}

public struct MinimumViableDaySelection: Codable, Equatable, Sendable {
    public var careTaskID: UUID?
    public var outcomeTaskID: UUID?
    public var restWindowID: String?

    public init(
        careTaskID: UUID? = nil,
        outcomeTaskID: UUID? = nil,
        restWindowID: String? = nil
    ) {
        self.careTaskID = careTaskID
        self.outcomeTaskID = outcomeTaskID
        self.restWindowID = restWindowID
    }
}

public struct PlanningTouchedRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(kind):\(recordID.uuidString)" }
    public var kind: String
    public var recordID: UUID
    public var version: Date

    public init(kind: String, recordID: UUID, version: Date) {
        self.kind = kind
        self.recordID = recordID
        self.version = version
    }
}

public struct PlanningScenarioDiff: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var before: String?
    public var after: String?

    public init(id: UUID = UUID(), title: String, before: String? = nil, after: String? = nil) {
        self.id = id
        self.title = title
        self.before = before
        self.after = after
    }
}

public struct PlanningScenario: Codable, Identifiable, Sendable {
    public let id: UUID
    public var source: PlanningScenarioSource
    public var receiptSource: String?
    public var touchedRecords: [PlanningTouchedRecord]
    public var proposedMutations: [PlanMutation]
    public var diff: [PlanningScenarioDiff]
    public var preview: PlanDaySnapshot
    public var validationIssues: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        source: PlanningScenarioSource,
        receiptSource: String? = nil,
        touchedRecords: [PlanningTouchedRecord],
        proposedMutations: [PlanMutation],
        diff: [PlanningScenarioDiff],
        preview: PlanDaySnapshot,
        validationIssues: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.receiptSource = receiptSource
        self.touchedRecords = touchedRecords
        self.proposedMutations = proposedMutations
        self.diff = diff
        self.preview = preview
        self.validationIssues = validationIssues
        self.createdAt = createdAt
    }

    public var isReadyToApply: Bool { validationIssues.isEmpty }
}

public enum PlanningScenarioApplyError: Error, Equatable, Sendable {
    case versionConflict(changedRecordIDs: [UUID])
}

public struct PlanningScenarioRefreshResult: Sendable {
    public let source: PlanningScenarioSource
    public let changedRecordIDs: [UUID]
    public let previousDiff: [PlanningScenarioDiff]
    public let refreshedScenario: PlanningScenario
    public let refreshedAt: Date

    public init(
        source: PlanningScenarioSource,
        changedRecordIDs: [UUID],
        previousDiff: [PlanningScenarioDiff],
        refreshedScenario: PlanningScenario,
        refreshedAt: Date = Date()
    ) {
        self.source = source
        self.changedRecordIDs = changedRecordIDs
        self.previousDiff = previousDiff
        self.refreshedScenario = refreshedScenario
        self.refreshedAt = refreshedAt
    }
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

public struct FocusCommandReceipt: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var sessionID: UUID
    public var kind: FocusSessionCommandKind
    public var occurredAt: Date
    public var resultingState: FocusSessionState
    public var focusedDuration: TimeInterval
    public var wasApplied: Bool

    public init(
        id: UUID,
        sessionID: UUID,
        kind: FocusSessionCommandKind,
        occurredAt: Date,
        resultingState: FocusSessionState,
        focusedDuration: TimeInterval,
        wasApplied: Bool
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.occurredAt = occurredAt
        self.resultingState = resultingState
        self.focusedDuration = max(0, focusedDuration)
        self.wasApplied = wasApplied
    }
}

// MARK: - Repository and service contracts

public protocol PlanningRepository: Sendable {
    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata]
    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws
    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws
}

public struct PlanningHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "planning"
    /// Widened to include `PlanningMutationRepository` so the carry can be read
    /// out of the close receipt. `CoreDataPlanningRepository` — the only
    /// production conformer — already satisfies all four.
    private let repository: any PlanningRepository & PlanningProjectionRepository & PlanningCalendarContextRepository & PlanningMutationRepository

    public init(repository: any PlanningRepository & PlanningProjectionRepository & PlanningCalendarContextRepository & PlanningMutationRepository) {
        self.repository = repository
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let now = context.date
        let horizon = now.addingTimeInterval(24 * 60 * 60)
        async let tasksResult = try? repository.fetchOpenPlanningTasks()
        async let calendarResult = try? repository.fetchCommitments(from: now, to: horizon)
        let tasks = await tasksResult ?? []
        let calendar = await calendarResult
        var result: [HomeContextCandidate] = []

        if let next = calendar?.commitments
            .filter({ $0.endAt > now && !$0.isAllDay })
            .sorted(by: { $0.startAt < $1.startAt }).first {
            result.append(.init(
                id: "planning-commitment:\(next.id)",
                widgetKind: .compactTimeline,
                title: next.startAt <= now ? next.title : "Next: \(next.title)",
                reason: .init(
                    message: next.startAt <= now ? "This commitment is happening now." : "This is your next scheduled commitment.",
                    signal: "calendar"
                ),
                destination: .plan,
                priority: next.startAt <= now ? 520 : 420,
                relevantFrom: now,
                relevantUntil: next.endAt
            ))
        }

        // What last night's close chose as today's first thing.
        //
        // Ranked above the next commitment because a deliberate choice made with
        // a clear head outranks whatever merely happens to be next on a calendar.
        // Resolved from the close receipt rather than from `pinOrder`, which an
        // ordinary manual reorder in Plan also writes.
        if let anchor = await carriedAnchor(tasks: tasks, now: now) {
            result.append(.init(
                id: "planning-carry:\(anchor.id.uuidString)",
                widgetKind: .focusNow,
                title: anchor.title,
                reason: .init(
                    message: "You chose this when you closed yesterday.",
                    signal: "yesterday's close"
                ),
                destination: .plan,
                priority: 560,
                relevantFrom: now,
                relevantUntil: Calendar.current.startOfDay(for: horizon)
            ))
        }

        // Overdue counts a task whose *planned day* has passed as well as one
        // past its deadline. A task put on Monday and never touched is exactly
        // what the weekly workspace exists to rescue, and counting only
        // `dueDate` made the commonest kind of backlog invisible on Home.
        let startOfToday = Calendar.current.startOfDay(for: now)
        let overdue = tasks.filter { task in
            guard task.metadata.unscheduledDisposition != .deleted,
                  task.metadata.availability == .actionable,
                  task.scheduledEndAt == nil else { return false }
            if let planned = task.metadata.planningDay?.startDate() {
                return planned < startOfToday
            }
            guard let due = task.dueDate else { return false }
            return due < now
        }.count
        if overdue > 0 {
            result.append(.init(
                id: "planning-overdue:\(startOfToday.timeIntervalSince1970)",
                widgetKind: .tasks,
                title: overdue == 1 ? "One task needs a gentle decision" : "\(overdue) tasks need a quick reset",
                reason: .init(message: "A short review can keep old tasks from quietly weighing on today.", signal: "unfinished tasks"),
                destination: .plan,
                priority: 310,
                relevantFrom: now,
                // Lands on the workspace's overdue briefing rather than on
                // Plan's Day lens: the card is about a backlog, so the first
                // thing it opens should be the decision about that backlog.
                route: .weeklyPlanningWorkspace(.overdue)
            ))
        }
        return result
    }

    /// Yesterday's chosen first thing, if it is still open today.
    ///
    /// Returns `nil` the moment the task is finished — a carry that has been
    /// done is not still the thing to start with, and leaving it on Home would
    /// be the app failing to notice.
    private func carriedAnchor(
        tasks: [PlanningTaskSummary],
        now: Date
    ) async -> PlanningTaskSummary? {
        let calendar = Calendar.current
        guard let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let today = PlanningDay(date: now)
        let yesterday = PlanningDay(date: yesterdayDate)

        let since = calendar.startOfDay(for: yesterdayDate)
        guard let records = try? await repository.fetchMutationReceipts(since: since) else { return nil }
        guard let anchorID = DayLoopLedger.anchorTaskID(
            in: records,
            closedOn: yesterday,
            targetDay: today
        ) else { return nil }

        return tasks.first { $0.id == anchorID && $0.metadata.planningDay == today }
    }
}

public protocol PlanningProjectionRepository: Sendable {
    func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary]
    func fetchPlanningTasks(includeCompleted: Bool) async throws -> [PlanningTaskSummary]
    func fetchPlanningProjects() async throws -> [PlanningProjectSummary]
}

public extension PlanningProjectionRepository {
    /// Compatibility default for projections that predate completed-task
    /// queries. Production persistence overrides this so Completed and All are
    /// backed by the same canonical rows as every other task scope.
    func fetchPlanningTasks(includeCompleted: Bool) async throws -> [PlanningTaskSummary] {
        try await fetchOpenPlanningTasks()
    }
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
    func hasAppliedReceipt(source: String) async throws -> Bool
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord]
}

public protocol FocusExecutionCoordinator: Sendable {
    func activeSession() async throws -> FocusSessionV2?
    func session(id: UUID) async throws -> FocusSessionV2?
    func sessions(since: Date?) async throws -> [FocusSessionV2]
    func commandReceipts(since: Date?) async throws -> [FocusCommandReceipt]
    func start(taskID: UUID?, timeBlockID: UUID?, targetDuration: TimeInterval, at: Date) async throws -> FocusSessionV2
    func handle(_ command: FocusSessionCommand) async throws -> FocusSessionV2
    func updateReflection(sessionID: UUID, energyAfter: Int?, reflection: String?) async throws -> FocusSessionV2
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

public protocol PlanningScenarioCoordinating: Sendable {
    func apply(_ scenario: PlanningScenario) async throws -> PlanMutationReceipt
}
