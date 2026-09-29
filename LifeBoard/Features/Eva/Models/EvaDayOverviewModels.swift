import Foundation

enum EvaDayOverviewSectionKind: String, Codable, Equatable, Hashable, Sendable {
    case overdueTasks
    case todayTasks
    case focusCandidates
    case dueHabits
    case recoveryHabits
    case quietTracking
    case emptyState
}

enum EvaDayTaskAction: String, Codable, Equatable, Hashable, Sendable {
    case done
    case reopen
    case tomorrow
    case open
}

enum EvaDayHabitAction: String, Codable, Equatable, Hashable, Sendable {
    case done
    case skip
    case stayedClean
    case lapsed
    case logLapse
    case open
}

struct EvaDayStatusChip: Codable, Equatable, Hashable, Sendable {
    let text: String
    let tone: String
}

struct EvaDayTaskCard: Codable, Equatable, Hashable, Identifiable, Sendable {
    let taskID: UUID
    let taskSnapshot: TaskDefinition
    let title: String
    let projectName: String
    let dueLabel: String?
    let priorityLabel: String?
    let durationLabel: String?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let dueDate: Date?
    let isOverdue: Bool
    let statusChips: [EvaDayStatusChip]
    let actions: [EvaDayTaskAction]

    var id: UUID { taskID }
}

struct EvaDayHabitCard: Codable, Equatable, Hashable, Identifiable, Sendable {
    let habitID: UUID
    let title: String
    let kind: HabitKind
    let trackingMode: HabitTrackingMode
    let lifeAreaName: String?
    let projectName: String?
    let iconSymbolName: String?
    let accentHex: String?
    let cadence: HabitCadenceDraft?
    let cadenceLabel: String
    let dueAt: Date?
    let dueLabel: String?
    let currentStreak: Int
    let bestStreak: Int
    let riskState: HabitRiskState
    let last14Days: [HabitDayMark]
    let statusChips: [EvaDayStatusChip]
    let actions: [EvaDayHabitAction]

    var id: UUID { habitID }
}

struct EvaDayOverviewSection: Codable, Equatable, Hashable, Identifiable, Sendable {
    let kind: EvaDayOverviewSectionKind
    let title: String
    let subtitle: String?
    let taskCards: [EvaDayTaskCard]
    let habitCards: [EvaDayHabitCard]
    let message: String?

    var id: String { kind.rawValue }
}

struct EvaDayOverviewPayload: Codable, Equatable, Sendable {
    let prompt: String
    let summaryMarkdown: String
    let contextReceipt: EvaContextReceipt
    let isPartialContext: Bool
    let sections: [EvaDayOverviewSection]
    let generatedAt: Date
}

typealias EvaDayTaskActionHandler = (
    _ action: EvaDayTaskAction,
    _ card: EvaDayTaskCard,
    _ completion: @escaping @Sendable (Result<Void, Error>) -> Void
) -> Void

typealias EvaDayHabitActionHandler = (
    _ action: EvaDayHabitAction,
    _ card: EvaDayHabitCard,
    _ completion: @escaping @Sendable (Result<Void, Error>) -> Void
) -> Void
