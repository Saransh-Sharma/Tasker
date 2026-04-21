import Foundation

public enum ReflectionNoteKind: String, Codable, CaseIterable, Hashable {
    case taskCompletion
    case weeklyReview
    case projectReflection
    case habitRecovery
    case freeform
}

public struct ReflectionNote: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var kind: ReflectionNoteKind
    public var linkedTaskID: UUID?
    public var linkedProjectID: UUID?
    public var linkedHabitID: UUID?
    public var linkedWeeklyPlanID: UUID?
    public var energy: Int?
    public var mood: Int?
    public var prompt: String?
    public var noteText: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: ReflectionNoteKind = .freeform,
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        energy: Int? = nil,
        mood: Int? = nil,
        prompt: String? = nil,
        noteText: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.energy = energy
        self.mood = mood
        self.prompt = prompt
        self.noteText = noteText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReflectionNoteQuery: Codable, Equatable, Hashable {
    public var linkedTaskID: UUID?
    public var linkedProjectID: UUID?
    public var linkedHabitID: UUID?
    public var linkedWeeklyPlanID: UUID?
    public var kinds: [ReflectionNoteKind]
    public var limit: Int?

    public init(
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        kinds: [ReflectionNoteKind] = [],
        limit: Int? = nil
    ) {
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.kinds = kinds
        self.limit = limit
    }
}


// MARK: - Daily Reflection Models

import Foundation

public enum DailyReflectionMode: String, Codable, CaseIterable, Hashable {
    case sameDay
    case catchUpYesterday
}

public enum ReflectionMood: String, Codable, CaseIterable, Hashable {
    case great
    case good
    case mixed
    case heavy
    case chaotic

    public var title: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .mixed: return "Mixed"
        case .heavy: return "Heavy"
        case .chaotic: return "Chaotic"
        }
    }
}

public enum ReflectionEnergy: String, Codable, CaseIterable, Hashable {
    case high
    case okay
    case low

    public var title: String {
        switch self {
        case .high: return "High"
        case .okay: return "Okay"
        case .low: return "Low"
        }
    }
}

public enum ReflectionFrictionTag: String, Codable, CaseIterable, Hashable {
    case meetings
    case distractions
    case lowEnergy
    case unclearTask
    case unexpectedWork
    case tooMuchPlanned

    public var title: String {
        switch self {
        case .meetings: return "Meetings"
        case .distractions: return "Distractions"
        case .lowEnergy: return "Low energy"
        case .unclearTask: return "Unclear task"
        case .unexpectedWork: return "Unexpected work"
        case .tooMuchPlanned: return "Too much planned"
        }
    }
}

public enum DailyPlanRisk: String, Codable, CaseIterable, Hashable {
    case overdueBacklogPressure
    case carryoverPressure
    case meetingCongestion
    case habitContinuityRisk

    public var title: String {
        switch self {
        case .overdueBacklogPressure: return "Overdue backlog pressure"
        case .carryoverPressure: return "Carryover pressure"
        case .meetingCongestion: return "Meeting congestion"
        case .habitContinuityRisk: return "Habit continuity risk"
        }
    }
}

public enum DailyPlanSource: String, Codable, CaseIterable, Hashable {
    case reflection
    case manual
}

public struct DailyReflectionTarget: Codable, Equatable, Hashable {
    public let mode: DailyReflectionMode
    public let reflectionDate: Date
    public let planningDate: Date

    public init(mode: DailyReflectionMode, reflectionDate: Date, planningDate: Date) {
        self.mode = mode
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
    }
}

public struct ReflectionHighlight: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String?

    public init(id: UUID = UUID(), title: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct ReflectionTaskMiniRow: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let projectName: String?

    public init(id: UUID, title: String, projectName: String? = nil) {
        self.id = id
        self.title = title
        self.projectName = projectName
    }
}

public struct ReflectionHabitMiniRow: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let colorFamily: HabitColorFamily
    public let currentStreak: Int
    public let last7Days: [HabitDayMark]

    public init(
        id: UUID,
        title: String,
        colorFamily: HabitColorFamily,
        currentStreak: Int,
        last7Days: [HabitDayMark]
    ) {
        self.id = id
        self.title = title
        self.colorFamily = colorFamily
        self.currentStreak = currentStreak
        self.last7Days = last7Days
    }
}

public struct ReflectionNarrativeSummary: Codable, Equatable, Hashable {
    public let homeCardLine: String
    public let planCardLine: String

    public init(homeCardLine: String, planCardLine: String) {
        self.homeCardLine = homeCardLine
        self.planCardLine = planCardLine
    }

    public static func make(
        completedCount: Int,
        keptCount: Int,
        missedTitles: [String]
    ) -> ReflectionNarrativeSummary {
        let taskLine: String
        switch completedCount {
        case 0:
            taskLine = "No tasks closed"
        case 1:
            taskLine = "1 task closed"
        default:
            taskLine = "\(completedCount) tasks closed"
        }

        let homeLine: String
        if missedTitles.isEmpty == false {
            homeLine = "\(taskLine), \(keptPhrase(count: keptCount, short: true)), missed \(missedPhrase(from: missedTitles))."
        } else if keptCount > 0 {
            homeLine = "\(taskLine), \(keptPhrase(count: keptCount, short: true)). Keep tomorrow tight."
        } else {
            homeLine = "\(taskLine). Keep tomorrow tight."
        }

        let planLine: String
        if missedTitles.isEmpty == false {
            planLine = "You closed \(taskCountPhrase(completedCount)), \(keptPhrase(count: keptCount, short: false)), and missed \(missedPhrase(from: missedTitles))."
        } else if keptCount > 0 {
            planLine = "You closed \(taskCountPhrase(completedCount)) and \(keptPhrase(count: keptCount, short: false)), so tomorrow can stay narrow."
        } else {
            planLine = "You closed \(taskCountPhrase(completedCount)), and tomorrow can stay narrow."
        }

        return ReflectionNarrativeSummary(
            homeCardLine: homeLine,
            planCardLine: planLine
        )
    }

    private static func taskCountPhrase(_ count: Int) -> String {
        switch count {
        case 0:
            return "no tasks"
        case 1:
            return "1 task"
        default:
            return "\(count) tasks"
        }
    }

    private static func keptPhrase(count: Int, short: Bool) -> String {
        switch count {
        case ..<1:
            return short ? "routines steady" : "kept routines steady"
        case 1:
            return short ? "1 habit kept" : "kept 1 habit streak alive"
        default:
            return short ? "\(count) habits kept" : "kept \(count) habit streaks alive"
        }
    }

    private static func missedPhrase(from titles: [String]) -> String {
        let cleaned = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard cleaned.isEmpty == false else { return "a few routines" }
        if cleaned.count == 1 {
            return cleaned[0]
        }
        if cleaned.count == 2 {
            return "\(cleaned[0]) and \(cleaned[1])"
        }
        return "\(cleaned[0]), \(cleaned[1]), and \(cleaned.count - 2) more"
    }
}

public struct TaskReflectionSummary: Codable, Equatable, Hashable {
    public let completedCount: Int
    public let scheduledCount: Int
    public let carryOverCount: Int
    public let overdueOpenCount: Int

    public init(completedCount: Int, scheduledCount: Int, carryOverCount: Int, overdueOpenCount: Int) {
        self.completedCount = completedCount
        self.scheduledCount = scheduledCount
        self.carryOverCount = carryOverCount
        self.overdueOpenCount = overdueOpenCount
    }
}

public struct HabitReflectionSummary: Codable, Equatable, Hashable {
    public let keptCount: Int
    public let targetCount: Int
    public let missedCount: Int
    public let atRiskHabitID: UUID?
    public let atRiskHabitTitle: String?
    public let currentStreak: Int?

    public init(
        keptCount: Int,
        targetCount: Int,
        missedCount: Int,
        atRiskHabitID: UUID?,
        atRiskHabitTitle: String?,
        currentStreak: Int?
    ) {
        self.keptCount = keptCount
        self.targetCount = targetCount
        self.missedCount = missedCount
        self.atRiskHabitID = atRiskHabitID
        self.atRiskHabitTitle = atRiskHabitTitle
        self.currentStreak = currentStreak
    }
}

public struct CalendarReflectionSummary: Codable, Equatable, Hashable {
    public let eventCount: Int
    public let meetingMinutes: Int
    public let bestFocusWindow: DateInterval?
    public let firstHardStop: Date?

    public init(eventCount: Int, meetingMinutes: Int, bestFocusWindow: DateInterval?, firstHardStop: Date?) {
        self.eventCount = eventCount
        self.meetingMinutes = meetingMinutes
        self.bestFocusWindow = bestFocusWindow
        self.firstHardStop = firstHardStop
    }
}

public struct DailyPlanTaskOption: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let projectName: String?
    public let dueDate: Date?
    public let priority: TaskPriority
    public let isCarryover: Bool
    public let isQuickStabilizer: Bool

    public init(
        id: UUID,
        title: String,
        projectName: String? = nil,
        dueDate: Date? = nil,
        priority: TaskPriority,
        isCarryover: Bool = false,
        isQuickStabilizer: Bool = false
    ) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.dueDate = dueDate
        self.priority = priority
        self.isCarryover = isCarryover
        self.isQuickStabilizer = isQuickStabilizer
    }
}

public struct DailyPlanSuggestion: Codable, Equatable, Hashable {
    public let topTasks: [DailyPlanTaskOption]
    public let swapPoolsBySlot: [String: [DailyPlanTaskOption]]
    public let focusWindow: DateInterval?
    public let protectedHabitID: UUID?
    public let protectedHabitTitle: String?
    public let protectedHabitStreak: Int?
    public let primaryRisk: DailyPlanRisk?
    public let primaryRiskDetail: String?

    public init(
        topTasks: [DailyPlanTaskOption],
        swapPoolsBySlot: [String: [DailyPlanTaskOption]] = [:],
        focusWindow: DateInterval? = nil,
        protectedHabitID: UUID? = nil,
        protectedHabitTitle: String? = nil,
        protectedHabitStreak: Int? = nil,
        primaryRisk: DailyPlanRisk? = nil,
        primaryRiskDetail: String? = nil
    ) {
        self.topTasks = topTasks
        self.swapPoolsBySlot = swapPoolsBySlot
        self.focusWindow = focusWindow
        self.protectedHabitID = protectedHabitID
        self.protectedHabitTitle = protectedHabitTitle
        self.protectedHabitStreak = protectedHabitStreak
        self.primaryRisk = primaryRisk
        self.primaryRiskDetail = primaryRiskDetail
    }

    public var topTaskIDs: [UUID] {
        topTasks.map(\.id)
    }
}

public struct DailyPlanDraft: Codable, Equatable, Hashable {
    public let date: Date
    public let topTasks: [DailyPlanTaskOption]
    public let suggestedFocusBlock: DateInterval?
    public let protectedHabitID: UUID?
    public let protectedHabitTitle: String?
    public let protectedHabitStreak: Int?
    public let primaryRisk: DailyPlanRisk?
    public let primaryRiskDetail: String?
    public let source: DailyPlanSource
    public let updatedAt: Date

    public init(
        date: Date,
        topTasks: [DailyPlanTaskOption],
        suggestedFocusBlock: DateInterval? = nil,
        protectedHabitID: UUID? = nil,
        protectedHabitTitle: String? = nil,
        protectedHabitStreak: Int? = nil,
        primaryRisk: DailyPlanRisk? = nil,
        primaryRiskDetail: String? = nil,
        source: DailyPlanSource,
        updatedAt: Date = Date()
    ) {
        self.date = date
        self.topTasks = topTasks
        self.suggestedFocusBlock = suggestedFocusBlock
        self.protectedHabitID = protectedHabitID
        self.protectedHabitTitle = protectedHabitTitle
        self.protectedHabitStreak = protectedHabitStreak
        self.primaryRisk = primaryRisk
        self.primaryRiskDetail = primaryRiskDetail
        self.source = source
        self.updatedAt = updatedAt
    }

    public var topTaskIDs: [UUID] {
        topTasks.map(\.id)
    }
}

public struct DailyReflectionSnapshot: Codable, Equatable, Hashable {
    public let reflectionDate: Date
    public let planningDate: Date
    public let mode: DailyReflectionMode
    public let pulseNote: String?
    public let biggestWins: [ReflectionHighlight]
    public let tasksSummary: TaskReflectionSummary
    public let habitsSummary: HabitReflectionSummary?
    public let calendarSummary: CalendarReflectionSummary?
    public let suggestedPlan: DailyPlanSuggestion

    public init(
        reflectionDate: Date,
        planningDate: Date,
        mode: DailyReflectionMode,
        pulseNote: String?,
        biggestWins: [ReflectionHighlight],
        tasksSummary: TaskReflectionSummary,
        habitsSummary: HabitReflectionSummary?,
        calendarSummary: CalendarReflectionSummary?,
        suggestedPlan: DailyPlanSuggestion
    ) {
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
        self.mode = mode
        self.pulseNote = pulseNote
        self.biggestWins = biggestWins
        self.tasksSummary = tasksSummary
        self.habitsSummary = habitsSummary
        self.calendarSummary = calendarSummary
        self.suggestedPlan = suggestedPlan
    }
}

public enum DailyReflectionLoadState: String, Codable, Equatable, Hashable {
    case idle
    case loadingCore
    case coreLoaded
    case fullyLoaded
    case coreFailed
}

public enum DailyReflectionOptionalLoadStatus: Codable, Equatable, Hashable {
    case loading
    case loaded
    case degraded(String)

    public var message: String? {
        switch self {
        case .loading, .loaded:
            return nil
        case .degraded(let message):
            return message
        }
    }
}

public struct DailyReflectionCoreSnapshot: Codable, Equatable, Hashable {
    public let reflectionDate: Date
    public let planningDate: Date
    public let mode: DailyReflectionMode
    public let pulseNote: String?
    public let biggestWins: [ReflectionHighlight]
    public let closedTasks: [ReflectionTaskMiniRow]
    public let habitGrid: [ReflectionHabitMiniRow]
    public let narrativeSummary: ReflectionNarrativeSummary
    public let tasksSummary: TaskReflectionSummary
    public let habitsSummary: HabitReflectionSummary?

    public init(
        reflectionDate: Date,
        planningDate: Date,
        mode: DailyReflectionMode,
        pulseNote: String?,
        biggestWins: [ReflectionHighlight],
        closedTasks: [ReflectionTaskMiniRow] = [],
        habitGrid: [ReflectionHabitMiniRow] = [],
        narrativeSummary: ReflectionNarrativeSummary = ReflectionNarrativeSummary(
            homeCardLine: "Keep tomorrow tight.",
            planCardLine: "Tomorrow can stay narrow."
        ),
        tasksSummary: TaskReflectionSummary,
        habitsSummary: HabitReflectionSummary?
    ) {
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
        self.mode = mode
        self.pulseNote = pulseNote
        self.biggestWins = biggestWins
        self.closedTasks = closedTasks
        self.habitGrid = habitGrid
        self.narrativeSummary = narrativeSummary
        self.tasksSummary = tasksSummary
        self.habitsSummary = habitsSummary
    }

    public func makeSnapshot(optionalContext: DailyReflectionOptionalContext) -> DailyReflectionSnapshot {
        DailyReflectionSnapshot(
            reflectionDate: reflectionDate,
            planningDate: planningDate,
            mode: mode,
            pulseNote: pulseNote,
            biggestWins: biggestWins,
            tasksSummary: tasksSummary,
            habitsSummary: habitsSummary,
            calendarSummary: optionalContext.calendarSummary,
            suggestedPlan: optionalContext.suggestedPlan
        )
    }
}

public struct DailyReflectionOptionalContext: Codable, Equatable, Hashable {
    public let calendarSummary: CalendarReflectionSummary?
    public let suggestedPlan: DailyPlanSuggestion
    public let status: DailyReflectionOptionalLoadStatus

    public init(
        calendarSummary: CalendarReflectionSummary?,
        suggestedPlan: DailyPlanSuggestion,
        status: DailyReflectionOptionalLoadStatus
    ) {
        self.calendarSummary = calendarSummary
        self.suggestedPlan = suggestedPlan
        self.status = status
    }
}

public struct DailyReflectionInput: Codable, Equatable, Hashable {
    public let mood: ReflectionMood?
    public let energy: ReflectionEnergy?
    public let frictionTags: [ReflectionFrictionTag]
    public let note: String?

    public init(
        mood: ReflectionMood? = nil,
        energy: ReflectionEnergy? = nil,
        frictionTags: [ReflectionFrictionTag] = [],
        note: String? = nil
    ) {
        self.mood = mood
        self.energy = energy
        self.frictionTags = frictionTags
        self.note = note
    }
}

public struct ReflectionPayload: Codable, Equatable, Hashable {
    public let reflectionDate: Date
    public let planningDate: Date
    public let mode: DailyReflectionMode
    public let mood: ReflectionMood?
    public let energy: ReflectionEnergy?
    public let frictionTags: [ReflectionFrictionTag]
    public let note: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        reflectionDate: Date,
        planningDate: Date,
        mode: DailyReflectionMode,
        mood: ReflectionMood?,
        energy: ReflectionEnergy?,
        frictionTags: [ReflectionFrictionTag],
        note: String?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
        self.mode = mode
        self.mood = mood
        self.energy = energy
        self.frictionTags = frictionTags
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct DailyReflectionEntryState: Codable, Equatable, Hashable, Identifiable {
    public let mode: DailyReflectionMode
    public let reflectionDate: Date
    public let planningDate: Date
    public let title: String
    public let subtitle: String
    public let summaryText: String
    public let badgeText: String?
    public let closedTasks: [ReflectionTaskMiniRow]
    public let habitGrid: [ReflectionHabitMiniRow]
    public let narrativeSummary: ReflectionNarrativeSummary

    public init(
        mode: DailyReflectionMode,
        reflectionDate: Date,
        planningDate: Date,
        title: String,
        subtitle: String,
        summaryText: String,
        badgeText: String?,
        closedTasks: [ReflectionTaskMiniRow] = [],
        habitGrid: [ReflectionHabitMiniRow] = [],
        narrativeSummary: ReflectionNarrativeSummary? = nil
    ) {
        self.mode = mode
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
        self.title = title
        self.subtitle = subtitle
        self.summaryText = summaryText
        self.badgeText = badgeText
        self.closedTasks = closedTasks
        self.habitGrid = habitGrid
        self.narrativeSummary = narrativeSummary ?? ReflectionNarrativeSummary(
            homeCardLine: summaryText,
            planCardLine: summaryText
        )
    }

    public var id: String {
        "\(mode.rawValue):\(reflectionDate.timeIntervalSince1970):\(planningDate.timeIntervalSince1970)"
    }
}

public struct EditableDailyPlan: Equatable {
    public var planningDate: Date
    public var topTasks: [DailyPlanTaskOption]
    public var swapPoolsBySlot: [String: [DailyPlanTaskOption]]
    public var focusWindow: DateInterval?
    public var protectedHabitID: UUID?
    public var protectedHabitTitle: String?
    public var protectedHabitStreak: Int?
    public var primaryRisk: DailyPlanRisk?
    public var primaryRiskDetail: String?
    public var source: DailyPlanSource

    public init(
        planningDate: Date,
        topTasks: [DailyPlanTaskOption],
        swapPoolsBySlot: [String: [DailyPlanTaskOption]] = [:],
        focusWindow: DateInterval? = nil,
        protectedHabitID: UUID? = nil,
        protectedHabitTitle: String? = nil,
        protectedHabitStreak: Int? = nil,
        primaryRisk: DailyPlanRisk? = nil,
        primaryRiskDetail: String? = nil,
        source: DailyPlanSource = .reflection
    ) {
        self.planningDate = planningDate
        self.topTasks = topTasks
        self.swapPoolsBySlot = swapPoolsBySlot
        self.focusWindow = focusWindow
        self.protectedHabitID = protectedHabitID
        self.protectedHabitTitle = protectedHabitTitle
        self.protectedHabitStreak = protectedHabitStreak
        self.primaryRisk = primaryRisk
        self.primaryRiskDetail = primaryRiskDetail
        self.source = source
    }

    public init(planningDate: Date, suggestion: DailyPlanSuggestion, source: DailyPlanSource = .reflection) {
        self.init(
            planningDate: planningDate,
            topTasks: suggestion.topTasks,
            swapPoolsBySlot: suggestion.swapPoolsBySlot,
            focusWindow: suggestion.focusWindow,
            protectedHabitID: suggestion.protectedHabitID,
            protectedHabitTitle: suggestion.protectedHabitTitle,
            protectedHabitStreak: suggestion.protectedHabitStreak,
            primaryRisk: suggestion.primaryRisk,
            primaryRiskDetail: suggestion.primaryRiskDetail,
            source: source
        )
    }

    public func makeDraft(updatedAt: Date = Date()) -> DailyPlanDraft {
        DailyPlanDraft(
            date: planningDate,
            topTasks: topTasks,
            suggestedFocusBlock: focusWindow,
            protectedHabitID: protectedHabitID,
            protectedHabitTitle: protectedHabitTitle,
            protectedHabitStreak: protectedHabitStreak,
            primaryRisk: primaryRisk,
            primaryRiskDetail: primaryRiskDetail,
            source: source,
            updatedAt: updatedAt
        )
    }

    public mutating func swapTask(at slotIndex: Int, with option: DailyPlanTaskOption) {
        guard topTasks.indices.contains(slotIndex) else { return }
        var updated = topTasks
        let previous = updated[slotIndex]
        updated[slotIndex] = option
        topTasks = deduplicating(tasks: updated, preferredCount: max(updated.count, 3))

        let key = Self.swapPoolKey(for: slotIndex)
        var pool = swapPoolsBySlot[key] ?? []
        pool.removeAll { $0.id == option.id }
        if !pool.contains(where: { $0.id == previous.id }) {
            pool.insert(previous, at: 0)
        }
        swapPoolsBySlot[key] = pool
    }

    public func swapOptions(for slotIndex: Int) -> [DailyPlanTaskOption] {
        let key = Self.swapPoolKey(for: slotIndex)
        let selectedIDs = Set(topTasks.map(\.id))
        return (swapPoolsBySlot[key] ?? []).filter { !selectedIDs.contains($0.id) || topTasks[safe: slotIndex]?.id == $0.id }
    }

    public static func swapPoolKey(for slotIndex: Int) -> String {
        "slot_\(slotIndex)"
    }

    private func deduplicating(tasks: [DailyPlanTaskOption], preferredCount: Int) -> [DailyPlanTaskOption] {
        var seen = Set<UUID>()
        var unique: [DailyPlanTaskOption] = []
        for task in tasks where seen.insert(task.id).inserted {
            unique.append(task)
        }
        return Array(unique.prefix(preferredCount))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
