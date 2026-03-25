import Foundation

public enum HabitKind: String, Codable, CaseIterable, Hashable {
    case positive
    case negative
}

public enum HabitTrackingMode: String, Codable, CaseIterable, Hashable {
    case dailyCheckIn
    case lapseOnly
}

public enum HabitRiskState: String, Codable, CaseIterable, Hashable {
    case stable
    case atRisk
    case broken
}

public struct HabitIconMetadata: Codable, Equatable, Hashable {
    public var symbolName: String
    public var categoryKey: String

    public init(symbolName: String, categoryKey: String) {
        self.symbolName = symbolName
        self.categoryKey = categoryKey
    }
}

public struct HabitTargetConfig: Codable, Equatable, Hashable {
    public var notes: String?
    public var targetCountPerDay: Int?

    public init(notes: String? = nil, targetCountPerDay: Int? = nil) {
        self.notes = notes
        self.targetCountPerDay = targetCountPerDay
    }
}

public struct HabitMetricConfig: Codable, Equatable, Hashable {
    public var unitLabel: String?
    public var showNotesOnCompletion: Bool

    public init(unitLabel: String? = nil, showNotesOnCompletion: Bool = false) {
        self.unitLabel = unitLabel
        self.showNotesOnCompletion = showNotesOnCompletion
    }
}

public enum HabitCadenceDraft: Codable, Equatable, Hashable {
    case daily(hour: Int? = nil, minute: Int? = nil)
    case weekly(daysOfWeek: [Int], hour: Int? = nil, minute: Int? = nil)

    public var ruleType: String {
        switch self {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        }
    }
}

public enum HabitOccurrenceAction: String, Codable, CaseIterable, Hashable {
    case complete
    case skip
    case abstained
    case lapsed
}

public enum HabitDayState: Codable, Equatable, Hashable {
    case success
    case failure
    case skipped
    case none
    case future
}

public struct HabitDayMark: Codable, Equatable, Hashable {
    public let date: Date
    public let state: HabitDayState

    public init(date: Date, state: HabitDayState) {
        self.date = date
        self.state = state
    }
}

public struct HabitOccurrenceSummary: Codable, Equatable, Hashable, Identifiable {
    public let habitID: UUID
    public let occurrenceID: UUID?
    public var title: String
    public var kind: HabitKind
    public var trackingMode: HabitTrackingMode
    public var lifeAreaID: UUID
    public var lifeAreaName: String
    public var projectID: UUID?
    public var projectName: String?
    public var icon: HabitIconMetadata?
    public var dueAt: Date?
    public var state: OccurrenceState
    public var currentStreak: Int
    public var bestStreak: Int
    public var riskState: HabitRiskState
    public var last14Days: [HabitDayMark]

    public var id: UUID { habitID }

    public init(
        habitID: UUID,
        occurrenceID: UUID?,
        title: String,
        kind: HabitKind,
        trackingMode: HabitTrackingMode,
        lifeAreaID: UUID,
        lifeAreaName: String,
        projectID: UUID? = nil,
        projectName: String? = nil,
        icon: HabitIconMetadata? = nil,
        dueAt: Date? = nil,
        state: OccurrenceState = .pending,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        riskState: HabitRiskState = .stable,
        last14Days: [HabitDayMark] = []
    ) {
        self.habitID = habitID
        self.occurrenceID = occurrenceID
        self.title = title
        self.kind = kind
        self.trackingMode = trackingMode
        self.lifeAreaID = lifeAreaID
        self.lifeAreaName = lifeAreaName
        self.projectID = projectID
        self.projectName = projectName
        self.icon = icon
        self.dueAt = dueAt
        self.state = state
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.riskState = riskState
        self.last14Days = last14Days
    }
}

public struct HabitHistoryWindow: Codable, Equatable, Hashable {
    public let habitID: UUID
    public let marks: [HabitDayMark]

    public init(habitID: UUID, marks: [HabitDayMark]) {
        self.habitID = habitID
        self.marks = marks
    }
}

public struct HabitLibraryRow: Codable, Equatable, Hashable, Identifiable {
    public let habitID: UUID
    public let title: String
    public let kind: HabitKind
    public let trackingMode: HabitTrackingMode
    public let cadence: HabitCadenceDraft
    public let lifeAreaID: UUID?
    public let lifeAreaName: String
    public let projectID: UUID?
    public let projectName: String?
    public let icon: HabitIconMetadata?
    public let colorHex: String?
    public let isPaused: Bool
    public let isArchived: Bool
    public let currentStreak: Int
    public let bestStreak: Int
    public let last14Days: [HabitDayMark]
    public let nextDueAt: Date?
    public let lastCompletedAt: Date?
    public let reminderWindowStart: String?
    public let reminderWindowEnd: String?
    public let notes: String?

    public var id: UUID { habitID }

    public init(
        habitID: UUID,
        title: String,
        kind: HabitKind,
        trackingMode: HabitTrackingMode,
        cadence: HabitCadenceDraft = .daily(),
        lifeAreaID: UUID?,
        lifeAreaName: String,
        projectID: UUID? = nil,
        projectName: String? = nil,
        icon: HabitIconMetadata? = nil,
        colorHex: String? = nil,
        isPaused: Bool,
        isArchived: Bool,
        currentStreak: Int,
        bestStreak: Int,
        last14Days: [HabitDayMark] = [],
        nextDueAt: Date? = nil,
        lastCompletedAt: Date? = nil,
        reminderWindowStart: String? = nil,
        reminderWindowEnd: String? = nil,
        notes: String? = nil
    ) {
        self.habitID = habitID
        self.title = title
        self.kind = kind
        self.trackingMode = trackingMode
        self.cadence = cadence
        self.lifeAreaID = lifeAreaID
        self.lifeAreaName = lifeAreaName
        self.projectID = projectID
        self.projectName = projectName
        self.icon = icon
        self.colorHex = colorHex
        self.isPaused = isPaused
        self.isArchived = isArchived
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.last14Days = last14Days
        self.nextDueAt = nextDueAt
        self.lastCompletedAt = lastCompletedAt
        self.reminderWindowStart = reminderWindowStart
        self.reminderWindowEnd = reminderWindowEnd
        self.notes = notes
    }
}

public struct HabitRuntimeSyncResult: Codable, Equatable, Hashable {
    public let templatesRebuilt: Int
    public let occurrencesGenerated: Int
    public let rolloverUpdates: Int

    public init(templatesRebuilt: Int = 0, occurrencesGenerated: Int = 0, rolloverUpdates: Int = 0) {
        self.templatesRebuilt = templatesRebuilt
        self.occurrencesGenerated = occurrencesGenerated
        self.rolloverUpdates = rolloverUpdates
    }
}

public struct HabitInsightSignal: Codable, Equatable, Hashable {
    public let habitID: UUID
    public let title: String
    public let kind: HabitKind
    public let state: OccurrenceState
    public let currentStreak: Int
    public let riskState: HabitRiskState

    public init(
        habitID: UUID,
        title: String,
        kind: HabitKind,
        state: OccurrenceState,
        currentStreak: Int,
        riskState: HabitRiskState
    ) {
        self.habitID = habitID
        self.title = title
        self.kind = kind
        self.state = state
        self.currentStreak = currentStreak
        self.riskState = riskState
    }
}
