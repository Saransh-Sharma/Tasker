import Foundation

public enum HabitKind: String, Codable, CaseIterable, Hashable, Sendable {
    case positive
    case negative
}

public enum HabitTrackingMode: String, Codable, CaseIterable, Hashable, Sendable {
    case dailyCheckIn
    case lapseOnly
}

public enum HabitRiskState: String, Codable, CaseIterable, Hashable, Sendable {
    case stable
    case atRisk
    case broken
}

public struct HabitIconMetadata: Codable, Equatable, Hashable, Sendable {
    public var symbolName: String
    public var categoryKey: String

    public init(symbolName: String, categoryKey: String) {
        self.symbolName = symbolName
        self.categoryKey = categoryKey
    }
}

public struct HabitTargetConfig: Codable, Equatable, Hashable, Sendable {
    public var notes: String?
    public var targetCountPerDay: Int?

    public init(notes: String? = nil, targetCountPerDay: Int? = nil) {
        self.notes = notes
        self.targetCountPerDay = targetCountPerDay
    }
}

public struct HabitMetricConfig: Codable, Equatable, Hashable, Sendable {
    public var unitLabel: String?
    public var showNotesOnCompletion: Bool

    public init(unitLabel: String? = nil, showNotesOnCompletion: Bool = false) {
        self.unitLabel = unitLabel
        self.showNotesOnCompletion = showNotesOnCompletion
    }
}

public enum HabitCadenceDraft: Codable, Equatable, Hashable, Sendable {
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

public enum HabitOccurrenceAction: String, Codable, CaseIterable, Hashable, Sendable {
    case complete
    case skip
    case abstained
    case lapsed
}

public enum HabitDayState: Codable, Equatable, Hashable, Sendable {
    case success
    case failure
    case skipped
    case none
    case future
}

public struct HabitDayMark: Codable, Equatable, Hashable, Sendable {
    public let date: Date
    public let state: HabitDayState

    public init(date: Date, state: HabitDayState) {
        self.date = date
        self.state = state
    }
}

public enum HabitColorFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case green
    case blue
    case orange
    case coral
    case purple
    case teal
    case gray

    public var title: String {
        switch self {
        case .green: return "Leaf"
        case .blue: return "Sky"
        case .orange: return "Glow"
        case .coral: return "Spark"
        case .purple: return "Plum"
        case .teal: return "Wave"
        case .gray: return "Stone"
        }
    }

    public var canonicalHex: String {
        switch self {
        case .green: return "#4E9A2F"
        case .blue: return "#4A86E8"
        case .orange: return "#F5B23C"
        case .coral: return "#E94C3D"
        case .purple: return "#8A46B5"
        case .gray: return "#8C8E94"
        case .teal: return "#5AA7A4"
        }
    }

    public static func family(for hex: String?, fallback: HabitColorFamily = .green) -> HabitColorFamily {
        guard let normalized = normalizeHex(hex) else {
            return fallback
        }

        let canonicalMatch = Self.allCases.first { family in
            normalizeHex(family.canonicalHex) == normalized
        }
        if let canonicalMatch {
            return canonicalMatch
        }

        switch normalized {
        case "#4E9A2F", "#30A511", "#43C618", "#63DF2E", "#8EEA5D":
            return .green
        case "#4A86E8", "#287FFF", "#1E5EEA", "#102DA5", "#3EA5FF":
            return .blue
        case "#F5B23C", "#F4A70F", "#E98A08", "#D96A05":
            return .orange
        case "#E94C3D", "#DE6250", "#CA5342", "#B04638":
            return .coral
        case "#8A46B5", "#A250C2", "#701E92", "#450D5D":
            return .purple
        case "#5AA7A4", "#3A9EA0", "#2D8285", "#194F51":
            return .teal
        case "#8C8E94", "#AEAEAE", "#787878", "#4D4D4D":
            return .gray
        default:
            return fallback
        }
    }

    private static func normalizeHex(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let rawHex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard rawHex.count == 6 else { return nil }
        let normalized = rawHex.uppercased()
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard normalized.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return "#\(normalized)"
    }
}

public enum HabitBridgeSource: String, Codable, Hashable, Sendable {
    case skipped
    case notScheduled
}

public enum HabitBridgeKind: String, Codable, Hashable, Sendable {
    case single
    case start
    case middle
    case end
}

public enum HabitBoardCellState: Equatable, Hashable, Sendable {
    case done(depth: Int)
    case missed
    case bridge(kind: HabitBridgeKind, source: HabitBridgeSource)
    case todayPending
    case future
}

public struct HabitBoardCell: Equatable, Hashable, Sendable {
    public let date: Date
    public let state: HabitBoardCellState
    public let isToday: Bool
    public let isWeekend: Bool

    public init(
        date: Date,
        state: HabitBoardCellState,
        isToday: Bool,
        isWeekend: Bool
    ) {
        self.date = date
        self.state = state
        self.isToday = isToday
        self.isWeekend = isWeekend
    }
}

public enum HabitBoardSummaryMode: String, Codable, CaseIterable, Hashable {
    case streaks
    case counts
}

public struct HabitBoardAggregateDay: Equatable, Hashable {
    public let date: Date
    public let completedCount: Int
    public let habitCount: Int
    public let isToday: Bool

    public init(
        date: Date,
        completedCount: Int,
        habitCount: Int,
        isToday: Bool
    ) {
        self.date = date
        self.completedCount = completedCount
        self.habitCount = habitCount
        self.isToday = isToday
    }
}

public struct HabitBoardRowMetrics: Equatable, Hashable {
    public let currentStreak: Int
    public let bestStreak: Int
    public let totalCount: Int
    public let weekCount: Int
    public let monthCount: Int
    public let yearCount: Int

    public init(
        currentStreak: Int,
        bestStreak: Int,
        totalCount: Int,
        weekCount: Int,
        monthCount: Int,
        yearCount: Int
    ) {
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.totalCount = totalCount
        self.weekCount = weekCount
        self.monthCount = monthCount
        self.yearCount = yearCount
    }
}

public struct HabitBoardRowPresentation: Equatable, Hashable, Identifiable {
    public let habitID: UUID
    public let title: String
    public let iconSymbolName: String
    public let accentHex: String?
    public let colorFamily: HabitColorFamily
    public let currentStreak: Int
    public let bestStreak: Int
    public let cells: [HabitBoardCell]
    public let metrics: HabitBoardRowMetrics

    public var id: UUID { habitID }

    public init(
        habitID: UUID,
        title: String,
        iconSymbolName: String,
        accentHex: String?,
        colorFamily: HabitColorFamily,
        currentStreak: Int,
        bestStreak: Int,
        cells: [HabitBoardCell],
        metrics: HabitBoardRowMetrics
    ) {
        self.habitID = habitID
        self.title = title
        self.iconSymbolName = iconSymbolName
        self.accentHex = accentHex
        self.colorFamily = colorFamily
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.cells = cells
        self.metrics = metrics
    }
}

public struct HabitOccurrenceSummary: Codable, Equatable, Hashable, Identifiable, Sendable {
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
    public var colorHex: String?
    public var cadence: HabitCadenceDraft
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
        colorHex: String? = nil,
        cadence: HabitCadenceDraft = .daily(),
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
        self.colorHex = colorHex
        self.cadence = cadence
        self.dueAt = dueAt
        self.state = state
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.riskState = riskState
        self.last14Days = last14Days
    }
}

public struct HabitHistoryWindow: Codable, Equatable, Hashable, Sendable {
    public let habitID: UUID
    public let marks: [HabitDayMark]

    public init(habitID: UUID, marks: [HabitDayMark]) {
        self.habitID = habitID
        self.marks = marks
    }
}

public struct HabitLibraryRow: Codable, Equatable, Hashable, Identifiable, Sendable {
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

public struct HabitRuntimeSyncResult: Codable, Equatable, Hashable, Sendable {
    public let templatesRebuilt: Int
    public let occurrencesGenerated: Int
    public let rolloverUpdates: Int

    public init(templatesRebuilt: Int = 0, occurrencesGenerated: Int = 0, rolloverUpdates: Int = 0) {
        self.templatesRebuilt = templatesRebuilt
        self.occurrencesGenerated = occurrencesGenerated
        self.rolloverUpdates = rolloverUpdates
    }
}

public struct HabitInsightSignal: Codable, Equatable, Hashable, Sendable {
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
