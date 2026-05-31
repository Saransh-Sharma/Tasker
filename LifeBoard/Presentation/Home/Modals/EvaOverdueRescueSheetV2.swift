//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueDeckState: String, Codable, Equatable, Sendable {
    case notStarted
    case loading
    case active
    case editing
    case confirmingDelete
    case paused
    case applyingBulk
    case completed
    case error
}

enum OverdueRescueDecisionSource: String, Codable, Sendable {
    case swipe
    case tap
    case edit
    case delete
    case bulk
}

enum OverdueRescueDecisionAction: String, Codable, Sendable {
    case keepToday
    case moveLater
    case edit
    case delete
}

struct RecurrenceInstanceSnapshot: Codable, Equatable, Sendable {
    let recurrenceSeriesID: UUID?
    let repeatPattern: TaskRepeatPattern?
    let dueDate: Date?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
}

struct OverdueRescueUndoRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let runID: UUID?
    let taskID: UUID
    let source: OverdueRescueDecisionSource
    let action: OverdueRescueDecisionAction
    let previousDueDate: Date?
    let previousProjectID: UUID?
    let previousDurationMinutes: Int?
    let previousPriority: TaskPriority?
    let previousCompletionState: Bool
    let previousDeletedState: Bool
    let previousRecurrenceState: RecurrenceInstanceSnapshot?
    let fullSnapshot: AssistantTaskSnapshot
    let createdAt: Date

    init(
        taskSnapshot: TaskDefinition,
        source: OverdueRescueDecisionSource,
        action: OverdueRescueDecisionAction,
        runID: UUID?
    ) {
        self.id = UUID()
        self.runID = runID
        self.taskID = taskSnapshot.id
        self.source = source
        self.action = action
        self.previousDueDate = taskSnapshot.dueDate
        self.previousProjectID = taskSnapshot.projectID
        self.previousDurationMinutes = taskSnapshot.estimatedDuration.map { Int(($0 / 60).rounded()) }
        self.previousPriority = taskSnapshot.priority
        self.previousCompletionState = taskSnapshot.isComplete
        self.previousDeletedState = false
        self.previousRecurrenceState = RecurrenceInstanceSnapshot(
            recurrenceSeriesID: taskSnapshot.recurrenceSeriesID,
            repeatPattern: taskSnapshot.repeatPattern,
            dueDate: taskSnapshot.dueDate,
            scheduledStartAt: taskSnapshot.scheduledStartAt,
            scheduledEndAt: taskSnapshot.scheduledEndAt
        )
        self.fullSnapshot = AssistantTaskSnapshot(task: taskSnapshot)
        self.createdAt = Date()
    }

    var taskSnapshot: TaskDefinition {
        fullSnapshot.toTaskDefinition()
    }
}

struct OverdueRescueSummary: Equatable, Sendable {
    var kept = 0
    var moved = 0
    var edited = 0
    var deleted = 0

    var reviewed: Int { kept + moved + edited + deleted }
}

struct OverdueRescueSessionScope: Codable, Equatable, Hashable, Sendable {
    var accountScopeID: String
    var workspaceID: String?
    var rescueDay: Date

    var storageKey: String {
        let dayStamp = Int(Calendar.current.startOfDay(for: rescueDay).timeIntervalSince1970)
        return "overdueRescue.session.v1.\(accountScopeID).\(workspaceID ?? "default").\(dayStamp)"
    }
}

struct OverdueRescueSessionState: Codable, Equatable, Sendable {
    var runID: UUID
    var accountScopeID: String
    var workspaceID: String?
    var referenceDate: Date
    var deckState: OverdueRescueDeckState
    var eligibleTaskIDs: [UUID]
    var remainingTaskIDs: [UUID]
    var resolvedTaskIDs: [UUID]
    var currentIndex: Int
    var keptCount: Int
    var movedCount: Int
    var deletedCount: Int
    var editedCount: Int
    var bulkAppliedCount: Int
    var largeStackAcknowledged: Bool
    var undoStack: [OverdueRescueUndoRecord]
    var lastRecoverableState: OverdueRescueDeckState
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    var summary: OverdueRescueSummary {
        OverdueRescueSummary(kept: keptCount, moved: movedCount, edited: editedCount, deleted: deletedCount)
    }
}

protocol OverdueRescueSessionStore {
    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState?
    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws
    func clear(scope: OverdueRescueSessionScope) async throws
}

struct UserDefaultsOverdueRescueSessionStore: OverdueRescueSessionStore {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState? {
        try loadSync(scope: scope)
    }

    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws {
        try saveSync(session, scope: scope)
    }

    func clear(scope: OverdueRescueSessionScope) async throws {
        clearSync(scope: scope)
    }

    func loadSync(scope: OverdueRescueSessionScope) throws -> OverdueRescueSessionState? {
        guard let data = userDefaults.data(forKey: scope.storageKey) else { return nil }
        return try JSONDecoder().decode(OverdueRescueSessionState.self, from: data)
    }

    func saveSync(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) throws {
        let data = try JSONEncoder().encode(session)
        userDefaults.set(data, forKey: scope.storageKey)
    }

    func clearSync(scope: OverdueRescueSessionScope) {
        userDefaults.removeObject(forKey: scope.storageKey)
    }
}

enum OverdueRescueStateMachine {
    static func canTransition(from current: OverdueRescueDeckState, to next: OverdueRescueDeckState) -> Bool {
        if next == .error {
            return current != .completed
        }
        switch (current, next) {
        case (.notStarted, .loading),
             (.loading, .active),
             (.loading, .completed),
             (.loading, .error),
             (.active, .editing),
             (.editing, .active),
             (.active, .confirmingDelete),
             (.confirmingDelete, .active),
             (.active, .paused),
             (.editing, .paused),
             (.confirmingDelete, .paused),
             (.paused, .active),
             (.active, .applyingBulk),
             (.applyingBulk, .active),
             (.active, .completed),
             (.applyingBulk, .completed),
             (.completed, .loading),
             (.completed, .active),
             (.error, .active),
             (.error, .editing),
             (.error, .confirmingDelete),
             (.error, .paused),
             (.error, .applyingBulk):
            return true
        default:
            return current == next
        }
    }

    static func isRecoverable(_ state: OverdueRescueDeckState) -> Bool {
        switch state {
        case .active, .editing, .confirmingDelete, .paused, .applyingBulk:
            return true
        case .notStarted, .loading, .completed, .error:
            return false
        }
    }
}

struct OverdueRescueDeckLayoutMetrics: Equatable {
    var containerSize: CGSize
    var bottomInset: CGFloat
    var dynamicTypeIsExpanded: Bool

    var horizontalInset: CGFloat {
        min(32, max(24, containerSize.width * 0.07))
    }

    var contentWidth: CGFloat {
        min(max(containerSize.width - horizontalInset * 2, 280), 390)
    }

    var cardWidth: CGFloat {
        contentWidth
    }

    var cardHeight: CGFloat {
        let height = containerSize.height > 0 ? containerSize.height : 844
        return min(420, max(340, height * 0.42))
    }

    var deckHeight: CGFloat {
        cardHeight + 40
    }

    var progressWidth: CGFloat {
        min(260, max(210, contentWidth * 0.68))
    }

    var actionButtonHeight: CGFloat {
        dynamicTypeIsExpanded ? 88 : 80
    }

    var actionGridUsesSingleColumn: Bool {
        dynamicTypeIsExpanded || contentWidth < 330
    }

    var bottomClearance: CGFloat {
        max(108, bottomInset + 20)
    }

    static func make(size: CGSize, bottomInset: CGFloat, dynamicTypeSize: DynamicTypeSize) -> OverdueRescueDeckLayoutMetrics {
        OverdueRescueDeckLayoutMetrics(
            containerSize: CGSize(
                width: max(size.width, 320),
                height: max(size.height, 640)
            ),
            bottomInset: bottomInset,
            dynamicTypeIsExpanded: dynamicTypeSize.isAccessibilitySize
        )
    }
}

enum OverdueRescueDeckCopy {
    static let keepToday = "Keep today"
    static let moveLater = "Move later"
    static let edit = "Edit"
    static let delete = "Delete"
}

enum OverdueRescuePalette {
    static let progressTrack = Color(red: 0.91, green: 0.88, blue: 0.83)

    static let keepFill = Color(red: 0.90, green: 0.96, blue: 0.92)
    static let keepForeground = Color(red: 0.18, green: 0.49, blue: 0.31)

    static let moveFill = Color(red: 1.0, green: 0.94, blue: 0.85)
    static let moveForeground = Color(red: 0.77, green: 0.48, blue: 0.07)

    static let editFill = Color(red: 0.91, green: 0.94, blue: 1.0)
    static let editForeground = Color(red: 0.29, green: 0.40, blue: 0.78)

    static let deleteFill = Color(red: 1.0, green: 0.92, blue: 0.91)
    static let deleteForeground = Color(red: 0.78, green: 0.27, blue: 0.27)
}

enum OverdueRescueSwipeRevealKind: Equatable {
    case none
    case keep
    case move
}

struct OverdueRescueDragResolution: Equatable {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let visibleOffset: CGSize
    let commitAction: OverdueRescueDecisionAction?
    let tiltDegrees: Double
}

enum OverdueRescueDragResolver {
    static let horizontalDominanceRatio: CGFloat = 1.15

    static func commitThreshold(cardWidth: CGFloat) -> CGFloat {
        max(96, cardWidth * 0.28)
    }

    static func maxDragOffset(cardWidth: CGFloat) -> CGFloat {
        cardWidth * 0.3
    }

    static func resolve(translation: CGSize, cardWidth: CGFloat, reduceMotion: Bool = false) -> OverdueRescueDragResolution {
        let reveal = revealKind(for: translation)
        let threshold = commitThreshold(cardWidth: cardWidth)
        let progress = reveal == .none ? 0 : revealProgress(for: translation.width, threshold: threshold)
        let clampLimit = maxDragOffset(cardWidth: cardWidth)
        let clampedWidth = max(-clampLimit, min(clampLimit, translation.width))
        let visibleOffset = reveal == .none ? .zero : CGSize(width: clampedWidth, height: translation.height * 0.06)
        let commitAction = commitAction(for: translation, cardWidth: cardWidth)
        let tilt = reduceMotion || reveal == .none ? 0 : Double(max(-5.5, min(5.5, translation.width / cardWidth * 6)))

        return OverdueRescueDragResolution(
            reveal: reveal,
            progress: progress,
            visibleOffset: visibleOffset,
            commitAction: commitAction,
            tiltDegrees: tilt
        )
    }

    static func revealKind(for translation: CGSize) -> OverdueRescueSwipeRevealKind {
        let width = translation.width
        let height = translation.height
        guard abs(width) > 8, abs(width) > abs(height) * horizontalDominanceRatio else {
            return .none
        }
        return width > 0 ? .keep : .move
    }

    static func commitAction(for translation: CGSize, cardWidth: CGFloat) -> OverdueRescueDecisionAction? {
        let reveal = revealKind(for: translation)
        guard reveal != .none, abs(translation.width) >= commitThreshold(cardWidth: cardWidth) else {
            return nil
        }
        return reveal == .keep ? .keepToday : .moveLater
    }

    private static func revealProgress(for width: CGFloat, threshold: CGFloat) -> Double {
        let start = max(8, threshold * 0.08)
        let distance = abs(width)
        guard distance > start else { return 0 }
        return min(1, Double((distance - start) / max(1, threshold - start)))
    }
}

struct OverdueRescueCardModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let task: TaskDefinition
    let recommendation: EvaRescueRecommendation?
    let overdueDays: Int
    let projectLabel: String
    let confidenceLabel: String
    let reasonTitle: String
    let reasonBody: String
    let moveDate: Date?
    let moveButtonTitle: String
    let requiresDeleteConfirmation: Bool

    static func make(
        task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        projectsByID: [UUID: Project],
        now: Date
    ) -> OverdueRescueCardModel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dueDay = task.dueDate.map { calendar.startOfDay(for: $0) } ?? today
        let overdueDays = max(1, calendar.dateComponents([.day], from: dueDay, to: today).day ?? 1)
        let confidence = recommendation?.confidence ?? 0
        let reason = Self.reasonCopy(for: task, recommendation: recommendation, overdueDays: overdueDays)
        let moveDate = OverdueRescueMoveLaterResolver.resolveMoveDate(
            for: task,
            recommendation: recommendation,
            now: now
        )

        return OverdueRescueCardModel(
            id: task.id,
            task: task,
            recommendation: recommendation,
            overdueDays: overdueDays,
            projectLabel: task.projectID == ProjectConstants.inboxProjectID
                ? "No project"
                : (projectsByID[task.projectID]?.name ?? task.projectName ?? "No project"),
            confidenceLabel: confidence >= 0.75 ? "High confidence" : (confidence >= 0.45 ? "Needs your call" : "Needs your call"),
            reasonTitle: reason.title,
            reasonBody: reason.body,
            moveDate: moveDate,
            moveButtonTitle: OverdueRescueMoveLaterResolver.buttonTitle(for: moveDate, now: now),
            requiresDeleteConfirmation: Self.requiresDeleteConfirmation(task, now: now)
        )
    }

    var overdueText: String {
        overdueDays == 1 ? "Overdue by 1 day" : "Overdue by \(overdueDays) days"
    }

    var isHighConfidence: Bool {
        (recommendation?.confidence ?? 0) >= 0.75
    }

    private static func reasonCopy(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        overdueDays: Int
    ) -> (title: String, body: String) {
        if let recommendation, recommendation.reasons.isEmpty == false {
            let joined = recommendation.reasons
                .map { $0.replacingOccurrences(of: "Overdue \\d+d", with: "", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")

            switch recommendation.action {
            case .doToday:
                return ("Still relevant", joined.isEmpty ? "Relevant to current projects." : "\(joined).")
            case .move:
                return ("Today looks full", "This can move out of today’s board without risk.")
            case .split:
                return ("Needs a smaller next step", joined.isEmpty ? "Break this down before it blocks the day." : "\(joined).")
            case .dropCandidate:
                return ("Looks stale", joined.isEmpty ? "This has not moved in a while." : "\(joined).")
            }
        }

        if task.projectID != ProjectConstants.inboxProjectID {
            return ("Still relevant", "Relevant to current projects.")
        }
        if overdueDays >= 14 {
            return ("Looks stale", "This looks stale and has not moved in 2 weeks.")
        }
        return ("Needs your call", "Not enough signal to suggest a safe change.")
    }

    static func resolvedMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date = Date()
    ) -> Date {
        OverdueRescueMoveLaterResolver.resolveMoveDate(for: task, recommendation: recommendation, now: now)
    }

    static func moveButtonTitle(for date: Date?, now: Date = Date()) -> String {
        OverdueRescueMoveLaterResolver.buttonTitle(for: date, now: now)
    }

    static func requiresDeleteConfirmation(_ task: TaskDefinition, now: Date = Date()) -> Bool {
        let hasNotes = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasSubtasks = task.subtasks.isEmpty == false
        let hasRecurrence = task.recurrenceSeriesID != nil || task.repeatPattern != nil
        let hasProject = task.projectID != ProjectConstants.inboxProjectID
        let hasCalendarLink = task.scheduledStartAt != nil || task.scheduledEndAt != nil
        let hasRecentEdits = Calendar.current.dateComponents([.hour], from: task.updatedAt, to: now).hour ?? 999 < 24
        return hasNotes || hasSubtasks || hasRecurrence || hasProject || hasCalendarLink || hasRecentEdits
    }
}

enum OverdueRescueMoveLaterResolver {
    static func resolveMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date
    ) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if let suggested = recommendation?.toDate {
            let suggestedDay = calendar.startOfDay(for: suggested)
            if suggestedDay > today {
                return suggestedDay
            }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let lowUrgency = task.priority == .none || task.priority == .low
        if lowUrgency, isWorkingDay(tomorrow, calendar: calendar) {
            return tomorrow
        }

        if isWorkingDay(tomorrow, calendar: calendar), lowUrgency {
            return tomorrow
        }

        if isWorkingDay(tomorrow, calendar: calendar), task.priority.isHighPriority == false {
            return tomorrow
        }

        return nextWorkingDay(after: today, calendar: calendar)
    }

    static func buttonTitle(for date: Date?, now: Date) -> String {
        guard let date else { return "Move later" }
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now) {
            return "Move tomorrow"
        }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        if days > 0, days <= 7 {
            let weekday = calendar.component(.weekday, from: date)
            return "Move to \(calendar.weekdaySymbols[max(0, weekday - 1)])"
        }
        return "Move later"
    }

    private static func nextWorkingDay(after date: Date, calendar: Calendar) -> Date {
        var candidate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        while isWorkingDay(candidate, calendar: calendar) == false {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func isWorkingDay(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}

enum OverdueRescueEligibilityService {
    static let sprintLimit = 12
    static let maximumSprintLimit = 15
    static let largeStackThreshold = 20

    static func eligibleTasks(
        from tasksByID: [UUID: TaskDefinition],
        recommendations: [EvaRescueRecommendation],
        projectsByID: [UUID: Project],
        referenceDate: Date
    ) -> [TaskDefinition] {
        let taskIDs = Set(tasksByID.keys).union(recommendations.map(\.taskID))
        return taskIDs
            .compactMap { tasksByID[$0] }
            .filter { isEligible($0, projectsByID: projectsByID, referenceDate: referenceDate) }
    }

    static func isEligible(
        _ task: TaskDefinition,
        projectsByID: [UUID: Project],
        referenceDate: Date
    ) -> Bool {
        guard task.isComplete == false, let dueDate = task.dueDate else { return false }
        if let project = projectsByID[task.projectID], project.isArchived {
            return false
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard dueDate < today else { return false }
        if let deferred = task.deferredFromWeekStart, calendar.isDate(deferred, inSameDayAs: today) {
            return false
        }
        if task.recurrenceSeriesID != nil, dueDate >= today {
            return false
        }
        return true
    }

    static func sortCards(
        _ lhs: OverdueRescueCardModel,
        _ rhs: OverdueRescueCardModel,
        referenceDate: Date
    ) -> Bool {
        let lhsScore = rankingScore(lhs, referenceDate: referenceDate)
        let rhsScore = rankingScore(rhs, referenceDate: referenceDate)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.overdueDays != rhs.overdueDays { return lhs.overdueDays > rhs.overdueDays }
        return lhs.task.title.localizedCaseInsensitiveCompare(rhs.task.title) == .orderedAscending
    }

    private static func rankingScore(_ card: OverdueRescueCardModel, referenceDate: Date) -> Int {
        var score = 0
        if card.task.priority.isHighPriority { score += 1_000 }
        if Calendar.current.isDate(card.task.dueDate ?? .distantPast, inSameDayAs: referenceDate) { score += 800 }
        if (card.task.estimatedDuration ?? .greatestFiniteMagnitude) <= 1_800 { score += 300 }
        if Calendar.current.dateComponents([.day], from: card.task.updatedAt, to: referenceDate).day ?? 999 <= 7 { score += 200 }
        if card.task.projectID != ProjectConstants.inboxProjectID { score += 100 }
        if card.projectLabel == "No project" { score -= 80 }
        if card.isHighConfidence == false { score -= 100 }
        if card.overdueDays >= 14 { score -= 120 }
        return score
    }
}

@MainActor
final class OverdueRescueViewModel: ObservableObject {
    static let sprintLimit = OverdueRescueEligibilityService.sprintLimit
    static let largeStackThreshold = OverdueRescueEligibilityService.largeStackThreshold

    @Published private(set) var state: OverdueRescueDeckState = .notStarted
    @Published private(set) var cards: [OverdueRescueCardModel] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var sprintTotal = 0
    @Published private(set) var sprintResolvedCount = 0
    @Published private(set) var summary = OverdueRescueSummary()
    @Published private(set) var undoRecords: [OverdueRescueUndoRecord] = []
    @Published var snackbar: SnackbarData?
    @Published var errorMessage: String?
    @Published var showLargeStackPreflight = false
    @Published var showSafeFixesConfirmation = false

    let allCount: Int
    private let allCards: [OverdueRescueCardModel]
    private let referenceDate: Date
    private let projectsByID: [UUID: Project]
    private var resolvedTaskIDs: Set<UUID> = []
    private let runID: UUID
    private let sessionScope: OverdueRescueSessionScope
    private let sessionStore: UserDefaultsOverdueRescueSessionStore
    private var lastRecoverableState: OverdueRescueDeckState = .notStarted
    private let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    private let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    private let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    private let onApplyBulk: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    private let onUndoBulk: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    private let onTrack: (String, [String: Any]) -> Void

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        sessionScope: OverdueRescueSessionScope? = nil,
        sessionStore: UserDefaultsOverdueRescueSessionStore = UserDefaultsOverdueRescueSessionStore(),
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApplyBulk: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndoBulk: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        let planRecommendations = Self.orderedRecommendations(from: plan)
        let recommendationByID = Dictionary(uniqueKeysWithValues: planRecommendations.map { ($0.taskID, $0) })
        let scope = sessionScope ?? OverdueRescueSessionScope(
            accountScopeID: "default",
            workspaceID: nil,
            rescueDay: referenceDate
        )
        let eligibleTasks = OverdueRescueEligibilityService.eligibleTasks(
            from: tasksByID,
            recommendations: planRecommendations,
            projectsByID: projectsByID,
            referenceDate: referenceDate
        )
        let cards = eligibleTasks
            .map { task in
                OverdueRescueCardModel.make(
                    task: task,
                    recommendation: recommendationByID[task.id],
                    projectsByID: projectsByID,
                    now: referenceDate
                )
            }
            .sorted { lhs, rhs in
                OverdueRescueEligibilityService.sortCards(lhs, rhs, referenceDate: referenceDate)
            }

        self.allCards = cards
        self.allCount = cards.count
        self.referenceDate = referenceDate
        self.projectsByID = projectsByID
        self.sessionScope = scope
        self.sessionStore = sessionStore
        let savedSession = try? sessionStore.loadSync(scope: scope)
        self.runID = savedSession?.runID ?? UUID()
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApplyBulk = onApplyBulk
        self.onUndoBulk = onUndoBulk
        self.onTrack = onTrack

        if let savedSession,
           savedSession.deckState != .completed,
           savedSession.eligibleTaskIDs.contains(where: { tasksByID[$0] != nil }) {
            restore(session: savedSession)
        } else {
            let firstSprintCards = Array(cards.prefix(Self.sprintLimit))
            self.cards = firstSprintCards
            self.sprintTotal = firstSprintCards.count
            self.showLargeStackPreflight = cards.count >= Self.largeStackThreshold
            _ = transition(to: .loading)
            _ = transition(to: cards.isEmpty ? .completed : .active)
        }
    }

    var currentCard: OverdueRescueCardModel? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    var progressText: String {
        guard sprintTotal > 0 else { return "0 of 0" }
        return "\(min(sprintResolvedCount + 1, sprintTotal)) of \(sprintTotal)"
    }

    var progress: Double {
        guard sprintTotal > 0 else { return 1 }
        return Double(min(sprintResolvedCount, sprintTotal)) / Double(sprintTotal)
    }

    var remainingCount: Int {
        max(0, sprintTotal - sprintResolvedCount)
    }

    var totalRemainingCount: Int {
        max(0, allCount - resolvedTaskIDs.count)
    }

    var safeFixes: [OverdueRescueCardModel] {
        allCards.filter { card in
            guard resolvedTaskIDs.contains(card.id) == false else { return false }
            guard let recommendation = card.recommendation else { return false }
            guard recommendation.confidence >= 0.75 else { return false }
            guard recommendation.action == .doToday || recommendation.action == .move else { return false }
            guard card.task.recurrenceSeriesID == nil, card.task.repeatPattern == nil else { return false }
            return true
        }
    }

    var safeFixBreakdown: (move: Int, stay: Int, duration: Int) {
        let move = safeFixes.filter { $0.recommendation?.action == .move }.count
        let stay = safeFixes.filter { $0.recommendation?.action == .doToday }.count
        let duration = 0
        return (move, stay, duration)
    }

    func pause() {
        guard state == .active || state == .editing || state == .confirmingDelete else { return }
        transition(to: .paused)
        onTrack("rescue_pause", ["reviewed": summary.reviewed, "remaining": remainingCount])
    }

    func resume() {
        guard state == .paused else { return }
        transition(to: .active)
        onTrack("rescue_resume", ["reviewed": summary.reviewed, "remaining": remainingCount])
    }

    func startManualReview() {
        showLargeStackPreflight = false
        if cards.isEmpty, totalRemainingCount > 0 {
            _ = transition(to: .loading)
            loadNextSprint()
        }
        _ = transition(to: cards.isEmpty ? .completed : .active)
    }

    func requestEdit() {
        guard state == .active, currentCard != nil else { return }
        transition(to: .editing)
        LifeBoardFeedback.selection()
    }

    func cancelEdit() {
        guard state == .editing else { return }
        _ = transition(to: .active)
    }

    func keepToday(source: OverdueRescueDecisionSource) {
        guard let card = currentCard else { return }
        let today = Calendar.current.startOfDay(for: referenceDate)
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(id: card.id, dueDate: today),
            action: .keepToday,
            source: source,
            message: "Kept on today"
        )
    }

    func moveLater(source: OverdueRescueDecisionSource) {
        guard let card = currentCard else { return }
        let dueDate = card.moveDate ?? OverdueRescueMoveLaterResolver.resolveMoveDate(
            for: card.task,
            recommendation: card.recommendation,
            now: referenceDate
        )
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(id: card.id, dueDate: dueDate),
            action: .moveLater,
            source: source,
            message: card.moveButtonTitle == "Move tomorrow" ? "Moved to tomorrow" : "Moved later"
        )
    }

    func saveEdit(draft: OverdueRescueEditDraft) {
        guard let card = currentCard else { return }
        let significant = draft.projectID != card.task.projectID || draft.priority != card.task.priority
        applyUpdate(
            task: card.task,
            request: UpdateTaskDefinitionRequest(
                id: card.id,
                projectID: draft.projectID == card.task.projectID ? nil : draft.projectID,
                dueDate: draft.dueDate,
                clearDueDate: draft.dueDate == nil,
                priority: draft.priority == card.task.priority ? nil : draft.priority,
                estimatedDuration: draft.duration,
                clearEstimatedDuration: draft.duration == nil
            ),
            action: .edit,
            source: .edit,
            message: significant ? "Updated and kept today" : "Updated"
        )
    }

    func requestDelete() {
        guard state == .active, let card = currentCard else { return }
        if card.requiresDeleteConfirmation {
            _ = transition(to: .confirmingDelete)
        } else {
            deleteCurrent()
        }
    }

    func cancelDelete() {
        guard state == .confirmingDelete else { return }
        _ = transition(to: .active)
    }

    func confirmDelete() {
        guard state == .confirmingDelete else { return }
        deleteCurrent()
    }

    func applySafeFixes() {
        let fixes = safeFixes
        guard fixes.isEmpty == false else { return }
        guard transition(to: .applyingBulk) else { return }
        let today = Calendar.current.startOfDay(for: referenceDate)
        let mutations = fixes.compactMap { card -> EvaBatchMutationInstruction? in
            switch card.recommendation?.action {
            case .doToday:
                return EvaBatchMutationInstruction(taskID: card.id, dueDate: today)
            case .move:
                return EvaBatchMutationInstruction(taskID: card.id, dueDate: card.moveDate)
            default:
                return nil
            }
        }
        onApplyBulk(mutations) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let run):
                    for card in fixes {
                        self.undoRecords.append(OverdueRescueUndoRecord(
                            taskSnapshot: card.task,
                            source: .bulk,
                            action: card.recommendation?.action == .doToday ? .keepToday : .moveLater,
                            runID: run.id
                        ))
                    }
                    self.summary.kept += fixes.filter { $0.recommendation?.action == .doToday }.count
                    self.summary.moved += fixes.filter { $0.recommendation?.action == .move }.count
                    let fixedIDs = Set(fixes.map(\.id))
                    self.resolvedTaskIDs.formUnion(fixedIDs)
                    self.sprintResolvedCount = min(self.sprintTotal, self.sprintResolvedCount + fixes.count)
                    self.cards.removeAll { fixedIDs.contains($0.id) }
                    self.currentIndex = min(self.currentIndex, max(0, self.cards.count - 1))
                    self.snackbar = SnackbarData(message: "Applied \(fixes.count) safe fixes", actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.showSafeFixesConfirmation = false
                    _ = self.transition(to: self.cards.isEmpty ? .completed : .active)
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    func undoLast() {
        guard let record = undoRecords.popLast() else { return }
        if record.source == .bulk, let runID = record.runID {
            let relatedRecords = [record] + undoRecords.filter { $0.runID == runID }
            undoRecords.removeAll { $0.runID == runID }
            onUndoBulk { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.snackbar = SnackbarData(message: "Safe fixes undone")
                        self?.restoreUndoRecords(relatedRecords)
                        _ = self?.transition(to: .active)
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
            return
        }

        switch record.action {
        case .delete:
            onRestore(record.taskSnapshot) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.restoreUndoRecords([record])
                        _ = self?.transition(to: .active)
                        self?.snackbar = SnackbarData(message: "Delete undone")
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        case .keepToday, .moveLater, .edit:
            let request = UpdateTaskDefinitionRequest(
                id: record.taskSnapshot.id,
                projectID: record.taskSnapshot.projectID,
                dueDate: record.taskSnapshot.dueDate,
                clearDueDate: record.taskSnapshot.dueDate == nil,
                priority: record.taskSnapshot.priority,
                isComplete: record.taskSnapshot.isComplete,
                estimatedDuration: record.taskSnapshot.estimatedDuration,
                clearEstimatedDuration: record.taskSnapshot.estimatedDuration == nil
            )
            onUpdate(request) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        self?.restoreUndoRecords([record])
                        _ = self?.transition(to: .active)
                        self?.snackbar = SnackbarData(message: "Change undone")
                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func applyUpdate(
        task: TaskDefinition,
        request: UpdateTaskDefinitionRequest,
        action: OverdueRescueDecisionAction,
        source: OverdueRescueDecisionSource,
        message: String
    ) {
        guard state == .active || state == .editing else { return }
        onUpdate(request) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.undoRecords.append(OverdueRescueUndoRecord(taskSnapshot: task, source: source, action: action, runID: nil))
                    switch action {
                    case .keepToday: self.summary.kept += 1
                    case .moveLater: self.summary.moved += 1
                    case .edit: self.summary.edited += 1
                    case .delete: self.summary.deleted += 1
                    }
                    self.snackbar = SnackbarData(message: message, actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.advance()
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    private func deleteCurrent() {
        guard let card = currentCard else { return }
        onDelete(card.id) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.undoRecords.append(OverdueRescueUndoRecord(taskSnapshot: card.task, source: .delete, action: .delete, runID: nil))
                    self.summary.deleted += 1
                    self.snackbar = SnackbarData(message: "Deleted", actions: [SnackbarAction(title: "Undo") { self.undoLast() }])
                    self.advance()
                    LifeBoardFeedback.success()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    _ = self.transition(to: .error)
                }
            }
        }
    }

    private func advance() {
        if cards.indices.contains(currentIndex) {
            resolvedTaskIDs.insert(cards[currentIndex].id)
            sprintResolvedCount = min(sprintTotal, sprintResolvedCount + 1)
            cards.remove(at: currentIndex)
        }
        if cards.isEmpty {
            currentIndex = 0
            _ = transition(to: .completed)
        } else {
            currentIndex = min(currentIndex, cards.count - 1)
            _ = transition(to: .active)
        }
    }

    private func loadNextSprint() {
        let nextCards = allCards.filter { resolvedTaskIDs.contains($0.id) == false }
        cards = Array(nextCards.prefix(Self.sprintLimit))
        currentIndex = 0
        sprintTotal = cards.count
        sprintResolvedCount = 0
    }

    private func restore(session: OverdueRescueSessionState) {
        let remainingIDs = session.remainingTaskIDs
        let cardByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let restoredCards = remainingIDs.compactMap { cardByID[$0] }
        let fallbackCards = allCards.filter { session.resolvedTaskIDs.contains($0.id) == false }
        cards = restoredCards.isEmpty ? Array(fallbackCards.prefix(Self.sprintLimit)) : restoredCards
        currentIndex = min(max(0, session.currentIndex), max(0, cards.count - 1))
        sprintTotal = max(cards.count + session.resolvedTaskIDs.count, cards.count)
        sprintResolvedCount = min(session.resolvedTaskIDs.count, sprintTotal)
        summary = session.summary
        undoRecords = session.undoStack
        resolvedTaskIDs = Set(session.resolvedTaskIDs)
        lastRecoverableState = session.lastRecoverableState
        showLargeStackPreflight = allCount >= Self.largeStackThreshold && session.largeStackAcknowledged == false
        errorMessage = session.errorMessage

        if session.deckState == .loading {
            state = cards.isEmpty ? .completed : .active
        } else if session.deckState == .completed, cards.isEmpty == false {
            state = .active
        } else {
            state = session.deckState
        }
    }

    func finishAndClearSession() {
        sessionStore.clearSync(scope: sessionScope)
    }

    private func currentSessionState() -> OverdueRescueSessionState {
        let now = Date()
        return OverdueRescueSessionState(
            runID: runID,
            accountScopeID: sessionScope.accountScopeID,
            workspaceID: sessionScope.workspaceID,
            referenceDate: referenceDate,
            deckState: state,
            eligibleTaskIDs: allCards.map(\.id),
            remainingTaskIDs: cards.map(\.id),
            resolvedTaskIDs: Array(resolvedTaskIDs),
            currentIndex: currentIndex,
            keptCount: summary.kept,
            movedCount: summary.moved,
            deletedCount: summary.deleted,
            editedCount: summary.edited,
            bulkAppliedCount: undoRecords.filter { $0.source == .bulk }.count,
            largeStackAcknowledged: showLargeStackPreflight == false,
            undoStack: undoRecords,
            lastRecoverableState: lastRecoverableState,
            errorMessage: errorMessage,
            createdAt: now,
            updatedAt: now
        )
    }

    private func persistSession() {
        do {
            try sessionStore.saveSync(currentSessionState(), scope: sessionScope)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreUndoRecords(_ records: [OverdueRescueUndoRecord]) {
        guard records.isEmpty == false else { return }
        for record in records {
            resolvedTaskIDs.remove(record.taskSnapshot.id)
            decrementSummary(for: record.action)
        }
        let restoredCards = records
            .filter { record in cards.contains(where: { $0.id == record.taskSnapshot.id }) == false }
            .map { record in
                OverdueRescueCardModel.make(
                    task: record.taskSnapshot,
                    recommendation: nil,
                    projectsByID: projectsByID,
                    now: referenceDate
                )
            }
        cards.insert(contentsOf: restoredCards, at: min(currentIndex, cards.count))
        sprintResolvedCount = max(0, sprintResolvedCount - records.count)
        if sprintTotal == 0 {
            sprintTotal = cards.count
        }
    }

    private func decrementSummary(for action: OverdueRescueDecisionAction) {
        switch action {
        case .keepToday: summary.kept = max(0, summary.kept - 1)
        case .moveLater: summary.moved = max(0, summary.moved - 1)
        case .edit: summary.edited = max(0, summary.edited - 1)
        case .delete: summary.deleted = max(0, summary.deleted - 1)
        }
    }

    @discardableResult
    private func transition(to next: OverdueRescueDeckState) -> Bool {
        guard Self.canTransition(from: state, to: next) else {
            assertionFailure("Invalid Overdue Rescue transition: \(state) -> \(next)")
            return false
        }
        if Self.isRecoverable(state) {
            lastRecoverableState = state
        }
        state = next
        persistSession()
        return true
    }

    static func canTransition(from current: OverdueRescueDeckState, to next: OverdueRescueDeckState) -> Bool {
        OverdueRescueStateMachine.canTransition(from: current, to: next)
    }

    private static func isRecoverable(_ state: OverdueRescueDeckState) -> Bool {
        OverdueRescueStateMachine.isRecoverable(state)
    }

    private static func orderedRecommendations(from plan: EvaRescuePlan?) -> [EvaRescueRecommendation] {
        guard let plan else { return [] }
        return plan.doToday + plan.move + plan.split + plan.dropCandidate
    }
}

struct OverdueRescueEditDraft: Equatable {
    var dueDate: Date?
    var duration: TimeInterval?
    var projectID: UUID
    var priority: TaskPriority

    init(card: OverdueRescueCardModel) {
        dueDate = card.task.dueDate
        duration = card.task.estimatedDuration
        projectID = card.task.projectID
        priority = card.task.priority
    }
}

struct EvaOverdueRescueSheetV2: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let projectsByID: [UUID: Project]
    let referenceDate: Date
    let lastBatchRunID: UUID?
    let bottomInset: CGFloat
    let onClose: () -> Void
    let onExit: () -> Void
    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void

    @StateObject private var viewModel: OverdueRescueViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        lastBatchRunID: UUID?,
        bottomInset: CGFloat = 0,
        onClose: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {},
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApply: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndo: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        self.plan = plan
        self.tasksByID = tasksByID
        self.projectsByID = projectsByID
        self.referenceDate = referenceDate
        self.lastBatchRunID = lastBatchRunID
        self.bottomInset = bottomInset
        self.onClose = onClose
        self.onExit = onExit
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApply = onApply
        self.onUndo = onUndo
        self.onTrack = onTrack
        _viewModel = StateObject(wrappedValue: OverdueRescueViewModel(
            plan: plan,
            tasksByID: tasksByID,
            projectsByID: projectsByID,
            referenceDate: referenceDate,
            onUpdate: onUpdate,
            onDelete: onDelete,
            onRestore: onRestore,
            onApplyBulk: onApply,
            onUndoBulk: onUndo,
            onTrack: onTrack
        ))
    }

    var body: some View {
        ZStack {
            OverdueRescueBackground()

            switch viewModel.state {
            case .paused:
                OverdueRescuePauseView(viewModel: viewModel, bottomInset: bottomInset, onDismiss: onClose)
            case .completed:
                OverdueRescueCompletionView(summary: viewModel.summary, remaining: viewModel.totalRemainingCount, bottomInset: bottomInset) {
                    viewModel.finishAndClearSession()
                    onExit()
                } reviewRemaining: {
                    viewModel.startManualReview()
                }
            case .error:
                OverdueRescueErrorView(message: viewModel.errorMessage ?? "Something went wrong while updating the rescue deck.") {
                    viewModel.startManualReview()
                } close: {
                    onExit()
                }
            default:
                OverdueRescueDeckView(viewModel: viewModel, bottomInset: bottomInset, close: {
                    viewModel.pause()
                    onClose()
                })
            }
        }
        .overlay {
            if viewModel.state == .confirmingDelete {
                OverdueRescueDeleteOverlay(
                    taskTitle: viewModel.currentCard?.task.title,
                    onConfirm: { viewModel.confirmDelete() },
                    onCancel: { viewModel.cancelDelete() }
                )
                .transition(.opacity)
                .zIndex(60)
            }
        }
        .animation(reduceMotion ? nil : LifeBoardAnimation.snappy, value: viewModel.state == .confirmingDelete)
        .lifeboardSnackbar($viewModel.snackbar, bottomPadding: bottomInset + 20)
        .sheet(isPresented: Binding(
            get: { viewModel.state == .editing },
            set: { if !$0 { viewModel.cancelEdit() } }
        )) {
            if let card = viewModel.currentCard {
                OverdueRescueQuickEditSheet(
                    card: card,
                    projects: Array(projectsByID.values).sorted { $0.name < $1.name },
                    save: { viewModel.saveEdit(draft: $0) },
                    cancel: { viewModel.cancelEdit() }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSafeFixesConfirmation) {
            OverdueRescueSafeFixesView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLargeStackPreflight) {
            OverdueRescueLargeStackView(
                count: viewModel.allCount,
                safeCount: viewModel.safeFixes.count,
                applySafeFixes: {
                    viewModel.showLargeStackPreflight = false
                    viewModel.showSafeFixesConfirmation = true
                },
                startManualReview: viewModel.startManualReview
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.pause()
        }
        .accessibilityIdentifier("home.rescue.overlay")
    }
}

private struct OverdueRescueDeckView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    let bottomInset: CGFloat
    let close: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @State private var commitOffset: CGSize = .zero
    @State private var viewportSize: CGSize = CGSize(width: 390, height: 844)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let metrics = OverdueRescueDeckLayoutMetrics.make(
            size: viewportSize,
            bottomInset: bottomInset,
            dynamicTypeSize: dynamicTypeSize
        )

        ViewThatFits(in: .vertical) {
            deckContent(metrics: metrics, scrollFallback: false)
            ScrollView(.vertical, showsIndicators: false) {
                deckContent(metrics: metrics, scrollFallback: true)
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            viewportSize = newSize
        }
    }

    private func deckContent(metrics: OverdueRescueDeckLayoutMetrics, scrollFallback: Bool) -> some View {
        VStack(spacing: 0) {
            header(metrics: metrics)
                .padding(.top, scrollFallback ? 12 : 8)

            Color.clear.frame(height: 40)

            if let card = viewModel.currentCard {
                let drag = activeDragResolution(metrics: metrics)
                ZStack(alignment: .center) {
                    OverdueRescueBackCards(metrics: metrics)

                    OverdueRescueRevealPanel(
                        reveal: drag.reveal,
                        progress: drag.progress,
                        metrics: metrics
                    )

                    OverdueRescueTaskCard(card: card)
                        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                        .offset(activeCardOffset(metrics: metrics))
                        .rotationEffect(.degrees(reduceMotion ? 0 : drag.tiltDegrees))
                        .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: card.id)
                        .gesture(cardGesture(metrics: metrics), including: voiceOverEnabled ? .subviews : .all)
                }
                .frame(maxWidth: .infinity)
                .frame(width: metrics.cardWidth + 32, height: metrics.deckHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Overdue Rescue. Card \(viewModel.progressText). \(card.task.title). \(card.confidenceLabel). \(card.overdueText). Actions: Keep today, \(card.moveButtonTitle), Edit, Delete.")
                .accessibilityAction(named: Text("Keep today")) {
                    viewModel.keepToday(source: .tap)
                }
                .accessibilityAction(named: Text(card.moveButtonTitle)) {
                    viewModel.moveLater(source: .tap)
                }
                .accessibilityAction(named: Text("Edit")) {
                    viewModel.requestEdit()
                }

                OverdueRescueSwipeHint(
                    reveal: drag.reveal,
                    progress: drag.progress
                )
                .padding(.top, 18)

                OverdueRescueActionGrid(
                    metrics: metrics,
                    keep: { viewModel.keepToday(source: .tap) },
                    move: { viewModel.moveLater(source: .tap) },
                    edit: viewModel.requestEdit,
                    delete: viewModel.requestDelete
                )
                .frame(width: metrics.contentWidth)
                .padding(.top, 18)
            } else {
                Spacer()
            }

            if scrollFallback {
                Color.clear.frame(height: metrics.bottomClearance + 22)
            } else {
                Spacer(minLength: 0)
                Color.clear.frame(height: metrics.bottomClearance)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func header(metrics: OverdueRescueDeckLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button("Close", systemImage: "xmark") {
                    close()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white.opacity(0.82)))
                .accessibilityLabel("Close rescue")

                Spacer()

                Menu {
                    if viewModel.safeFixes.isEmpty == false {
                        Button("Apply high-confidence fixes") {
                            viewModel.showSafeFixesConfirmation = true
                        }
                    }
                    Button("Pause rescue") {
                        viewModel.pause()
                    }
                    Button("Restart sprint") {
                        viewModel.startManualReview()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.white.opacity(0.82)))
                }
                    .accessibilityLabel("More rescue actions")
            }
            .padding(.horizontal, 28)

            VStack(spacing: 7) {
                Text("Overdue Rescue")
                    .font(.lifeboard(.title2))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("Swipe or tap to sort what still matters.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
                Text(viewModel.progressText)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .padding(.top, 8)
                LifeBoardProgressBar(
                    progress: viewModel.progress,
                    colors: [Color.lifeboard.accentPrimary],
                    trackColor: OverdueRescuePalette.progressTrack,
                    height: 7
                )
                .frame(width: metrics.progressWidth)
            }
        }
    }

    private func cardGesture(metrics: OverdueRescueDeckLayoutMetrics) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                if let action = OverdueRescueDragResolver.commitAction(
                    for: value.translation,
                    cardWidth: metrics.cardWidth
                ) {
                    commitDrag(action, metrics: metrics)
                } else {
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.stateChange) {
                        commitOffset = .zero
                    }
                }
            }
    }

    private func activeDragResolution(metrics: OverdueRescueDeckLayoutMetrics) -> OverdueRescueDragResolution {
        if commitOffset != .zero {
            return OverdueRescueDragResolution(
                reveal: commitOffset.width > 0 ? .keep : .move,
                progress: 1,
                visibleOffset: commitOffset,
                commitAction: commitOffset.width > 0 ? .keepToday : .moveLater,
                tiltDegrees: reduceMotion ? 0 : Double(max(-5.5, min(5.5, commitOffset.width / metrics.cardWidth * 6)))
            )
        }
        return OverdueRescueDragResolver.resolve(
            translation: dragTranslation,
            cardWidth: metrics.cardWidth,
            reduceMotion: reduceMotion
        )
    }

    private func activeCardOffset(metrics: OverdueRescueDeckLayoutMetrics) -> CGSize {
        activeDragResolution(metrics: metrics).visibleOffset
    }

    private func commitDrag(_ action: OverdueRescueDecisionAction, metrics: OverdueRescueDeckLayoutMetrics) {
        withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.panelOut) {
            switch action {
            case .keepToday:
                commitOffset = CGSize(width: metrics.cardWidth + 120, height: 0)
            case .moveLater:
                commitOffset = CGSize(width: -metrics.cardWidth - 120, height: 0)
            case .edit, .delete:
                commitOffset = .zero
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.01 : 0.20)) {
            commitOffset = .zero
            switch action {
            case .keepToday: viewModel.keepToday(source: .swipe)
            case .moveLater: viewModel.moveLater(source: .swipe)
            case .edit, .delete: break
            }
        }
    }
}

private struct OverdueRescueBackCards: View {
    let metrics: OverdueRescueDeckLayoutMetrics

    var body: some View {
        ZStack(alignment: .center) {
            ForEach(0..<4, id: \.self) { index in
                let reverseIndex = 3 - index
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(backCardColor(index))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )
                    .frame(
                        width: metrics.cardWidth - CGFloat(reverseIndex) * 8,
                        height: metrics.cardHeight - CGFloat(reverseIndex) * 5
                    )
                    .offset(
                        x: horizontalOffset(reverseIndex),
                        y: -CGFloat(reverseIndex) * 17
                    )
                    .scaleEffect(1.0 - Double(reverseIndex) * 0.018)
                    .shadow(color: Color.black.opacity(0.05 + Double(index) * 0.012), radius: 14 + CGFloat(index) * 4, y: 7 + CGFloat(index) * 2)
            }
        }
    }

    private func horizontalOffset(_ reverseIndex: Int) -> CGFloat {
        switch reverseIndex {
        case 1: return 6
        case 2: return -8
        case 3: return 10
        default: return 0
        }
    }

    private func backCardColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color(red: 1.0, green: 0.91, blue: 0.83)
        case 1: return Color(red: 0.91, green: 0.96, blue: 1.0)
        case 2: return Color(red: 0.94, green: 0.90, blue: 1.0)
        default: return Color(red: 1.0, green: 0.96, blue: 0.86)
        }
    }
}

private struct OverdueRescueTaskCard: View {
    let card: OverdueRescueCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(card.task.title)
                    .font(.lifeboard(.title2))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)

                Label(card.projectLabel, systemImage: "folder")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                Text(card.confidenceLabel)
                    .font(.lifeboard(.caption1))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.lifeboard.accentPrimary.opacity(0.10)))
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(card.overdueText)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text(card.reasonBody)
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(decorative: "rescue_decor_plant")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 88)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.70))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
            )
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.99, blue: 0.95), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color(red: 0.96, green: 0.86, blue: 0.68), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10), radius: 28, y: 14)
        )
        .overlay(alignment: .topTrailing) {
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .opacity(0.7)
                .padding(20)
                .accessibilityHidden(true)
        }
    }
}

private struct OverdueRescueRevealPanel: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let metrics: OverdueRescueDeckLayoutMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(panelForeground.opacity(0.16), lineWidth: 1)
            )
            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
            .shadow(color: Color.black.opacity(0.05 * easedProgress), radius: 16, y: 8)
            .overlay(alignment: reveal == .keep ? .leading : .trailing) {
                if reveal != .none {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 42, weight: .semibold))
                        Text(title)
                            .font(.lifeboard(.title2))
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(panelForeground)
                    .opacity(easedProgress)
                    .scaleEffect(0.86 + 0.14 * easedProgress)
                    .padding(.horizontal, 36)
                }
            }
            .offset(x: panelOffsetX, y: 0)
            .opacity(reveal == .none ? 0 : easedProgress)
            .accessibilityHidden(true)
    }

    private var easedProgress: Double {
        progress * progress * (3 - 2 * progress)
    }

    private var panelOffsetX: CGFloat {
        switch reveal {
        case .keep: return -metrics.cardWidth * 0.12
        case .move: return metrics.cardWidth * 0.12
        case .none: return 0
        }
    }

    private var panelFill: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepFill
        case .move: return OverdueRescuePalette.moveFill
        case .none: return .clear
        }
    }

    private var panelForeground: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepForeground
        case .move: return OverdueRescuePalette.moveForeground
        case .none: return Color.clear
        }
    }

    private var title: String {
        switch reveal {
        case .keep: return "Keep\ntoday"
        case .move: return "Move\nlater"
        case .none: return ""
        }
    }

    private var icon: String {
        switch reveal {
        case .keep: return "checkmark.circle"
        case .move: return "clock"
        case .none: return "circle"
        }
    }
}

private struct OverdueRescueDeleteOverlay: View {
    let taskTitle: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(OverdueRescuePalette.deleteForeground)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(OverdueRescuePalette.deleteFill))

                    Text("Delete this task?")
                        .font(.lifeboard(.title3))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This removes it from your board. You can undo right after deleting.")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Delete task")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.statusDanger)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.lifeboard(.button))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.lifeboard.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.lifeboard.bgCanvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 30, y: 16)
            )
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(deleteAccessibilityLabel)
    }

    private var deleteAccessibilityLabel: String {
        if let taskTitle, taskTitle.isEmpty == false {
            return "Delete \(taskTitle)? This removes it from your board. You can undo right after deleting."
        }
        return "Delete this task? This removes it from your board. You can undo right after deleting."
    }
}

private struct OverdueRescueSwipeHint: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(Color.lifeboard.textSecondary)
        .frame(height: 24)
        .accessibilityHidden(true)
    }

    private var icon: String {
        switch reveal {
        case .keep: return "hand.point.right"
        case .move: return "hand.point.left"
        case .none: return "hand.draw.fill"
        }
    }

    private var text: String {
        switch reveal {
        case .keep: return "Swipe right to keep"
        case .move: return "Swipe left to move later"
        case .none: return "Swipe left or right or tap a choice below."
        }
    }
}

private struct OverdueRescueActionGrid: View {
    let metrics: OverdueRescueDeckLayoutMetrics
    let keep: () -> Void
    let move: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        Group {
            if metrics.actionGridUsesSingleColumn {
                VStack(spacing: 12) {
                    keepButton
                    moveButton
                    editButton
                    deleteButton
                }
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        keepButton
                        moveButton
                    }
                    HStack(spacing: 14) {
                        editButton
                        deleteButton
                    }
                }
            }
        }
    }

    private var keepButton: some View {
        actionButton(title: OverdueRescueDeckCopy.keepToday, icon: "checkmark.circle", fill: OverdueRescuePalette.keepFill, foreground: OverdueRescuePalette.keepForeground, action: keep)
    }

    private var moveButton: some View {
        actionButton(title: OverdueRescueDeckCopy.moveLater, icon: "clock", fill: OverdueRescuePalette.moveFill, foreground: OverdueRescuePalette.moveForeground, action: move)
    }

    private var editButton: some View {
        actionButton(title: OverdueRescueDeckCopy.edit, icon: "pencil", fill: OverdueRescuePalette.editFill, foreground: OverdueRescuePalette.editForeground, action: edit)
    }

    private var deleteButton: some View {
        actionButton(title: OverdueRescueDeckCopy.delete, icon: "trash", fill: OverdueRescuePalette.deleteFill, foreground: OverdueRescuePalette.deleteForeground, action: delete)
    }

    private func actionButton(title: String, icon: String, fill: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.lifeboard(.button))
                .fontWeight(.semibold)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: metrics.actionButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(foreground.opacity(0.12), lineWidth: 1)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityHint(accessibilityHint(for: title))
    }

    private func accessibilityHint(for title: String) -> String {
        if title == OverdueRescueDeckCopy.keepToday { return "Keeps this task on today’s board and moves to the next card." }
        if title == OverdueRescueDeckCopy.edit { return "Opens quick edit for this task." }
        if title == OverdueRescueDeckCopy.delete { return "Removes this task from your board." }
        return "Moves this task out of today and moves to the next card."
    }
}

private struct OverdueRescueQuickEditSheet: View {
    let card: OverdueRescueCardModel
    let projects: [Project]
    let save: (OverdueRescueEditDraft) -> Void
    let cancel: () -> Void

    @State private var draft: OverdueRescueEditDraft
    @Environment(\.dismiss) private var dismiss

    init(
        card: OverdueRescueCardModel,
        projects: [Project],
        save: @escaping (OverdueRescueEditDraft) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.card = card
        self.projects = projects
        self.save = save
        self.cancel = cancel
        _draft = State(initialValue: OverdueRescueEditDraft(card: card))
    }

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(Color.lifeboard.strokeHairline)
                .frame(width: 58, height: 6)
                .padding(.top, 12)
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                Text("Adjust task")
                    .font(.lifeboard(.title2))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Spacer()
                Button("Close", systemImage: "xmark") {
                    cancel()
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.white.opacity(0.84)))
                .foregroundStyle(Color.lifeboard.textPrimary)
            }

            HStack {
                Text(card.task.title)
                    .font(.lifeboard(.title3))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(3)
                Spacer()
                OverdueRescuePlant()
                    .frame(width: 86, height: 94)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.68))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lifeboard.strokeHairline))
            )

            VStack(spacing: 0) {
                Menu {
                    Button("Today") { draft.dueDate = DatePreset.today.resolvedDueDate() }
                    Button("Tomorrow") { draft.dueDate = DatePreset.tomorrow.resolvedDueDate() }
                    Button("This week") { draft.dueDate = DatePreset.thisWeek.resolvedDueDate() }
                } label: {
                    editRow(icon: "calendar", title: "Due date", value: dueText)
                }
                Divider()
                Menu {
                    Button("15 min") { draft.duration = 15 * 60 }
                    Button("30 min") { draft.duration = 30 * 60 }
                    Button("45 min") { draft.duration = 45 * 60 }
                    Button("1 hour") { draft.duration = 60 * 60 }
                    Button("No duration") { draft.duration = nil }
                } label: {
                    editRow(icon: "clock", title: "Duration", value: durationText)
                }
                Divider()
                Menu {
                    Button("No project") { draft.projectID = ProjectConstants.inboxProjectID }
                    ForEach(projects, id: \.id) { project in
                        Button(project.name) { draft.projectID = project.id }
                    }
                } label: {
                    editRow(icon: "folder", title: "Project", value: projectText)
                }
                Divider()
                Menu {
                    ForEach(TaskPriority.uiOrder, id: \.self) { priority in
                        Button(priority.displayName) { draft.priority = priority }
                    }
                } label: {
                    editRow(
                        icon: "flag",
                        title: "Priority",
                        value: draft.priority.displayName,
                        valueColor: draft.priority.isHighPriority ? Color.lifeboard.statusDanger : Color.lifeboard.textSecondary,
                        iconColor: draft.priority.isHighPriority ? Color.lifeboard.statusDanger : Color.lifeboard.textSecondary
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.76))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lifeboard.strokeHairline))
            )

            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.confidenceLabel)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                    Text("Based on project relevance and overdue status.")
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.lifeboard.accentPrimary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.lifeboard.accentPrimary.opacity(0.12)))
            )

            Spacer()

            Button("Save and continue") {
                save(draft)
                dismiss()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.lifeboard.accentPrimary)
            )
            .buttonStyle(.plain)
            .scaleOnPress()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func editRow(
        icon: String,
        title: String,
        value: String,
        valueColor: Color = Color.lifeboard.textSecondary,
        iconColor: Color = Color.lifeboard.textSecondary
    ) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Spacer()
            Text(value)
                .font(.lifeboard(.headline))
                .foregroundStyle(valueColor)
            Image(systemName: "chevron.down")
                .font(.callout.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .frame(minHeight: 74)
        .padding(.horizontal, 20)
    }

    private var dueText: String {
        guard let dueDate = draft.dueDate else { return "No due date" }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        return dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var durationText: String {
        guard let duration = draft.duration else { return "No duration" }
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60) hour" : "\(minutes) min"
    }

    private var projectText: String {
        if draft.projectID == ProjectConstants.inboxProjectID { return "No project" }
        return projects.first(where: { $0.id == draft.projectID })?.name ?? "Project"
    }
}

private struct OverdueRescueSafeFixesView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.white.opacity(0.84)))
                Spacer()
            }
            OverdueRescueShieldHero()
                .frame(width: 220, height: 180)
            Text("Apply \(viewModel.safeFixes.count) safe fixes?")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
                .multilineTextAlignment(.center)
            Text("LifeBoard found \(viewModel.safeFixes.count) changes it is confident about.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 0) {
                if viewModel.safeFixBreakdown.move > 0 {
                    safeRow(icon: "clock", title: "\(viewModel.safeFixBreakdown.move) move later", value: "\(viewModel.safeFixBreakdown.move)", color: Color.lifeboard.statusWarning)
                }
                if viewModel.safeFixBreakdown.move > 0, viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.stay > 0 {
                    safeRow(icon: "checkmark.circle", title: "\(viewModel.safeFixBreakdown.stay) stay today", value: "\(viewModel.safeFixBreakdown.stay)", color: Color.lifeboard.statusSuccess)
                }
                if viewModel.safeFixBreakdown.duration > 0, viewModel.safeFixBreakdown.move + viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.duration > 0 {
                    safeRow(icon: "calendar", title: "\(viewModel.safeFixBreakdown.duration) gets a duration", value: "\(viewModel.safeFixBreakdown.duration)", color: Color.lifeboard.accentPrimary)
                }
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.lifeboard.strokeHairline))
            )

            Label("These changes are non-destructive and can be undone.", systemImage: "shield")
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 34)

            Spacer()
            Button("Apply \(viewModel.safeFixes.count) fixes") {
                dismiss()
                viewModel.applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.lifeboard.accentPrimary))
            .disabled(viewModel.safeFixes.isEmpty)
            Button("Review first") {
                dismiss()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(RoundedRectangle(cornerRadius: 22).stroke(Color.lifeboard.accentPrimary.opacity(0.32)))
        }
        .padding(28)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
    }

    private func safeRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.12)))
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Spacer()
            Text(value)
                .font(.lifeboard(.headline))
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 22)
        .frame(height: 82)
    }
}

private struct OverdueRescuePauseView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    let bottomInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                HStack {
                    Button("Close", systemImage: "xmark") { onDismiss() }
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.white.opacity(0.84)))
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueCupHero()
                    .frame(width: 220, height: 210)

                VStack(spacing: 10) {
                    Text("Pause rescue?")
                        .font(.lifeboard(.title1))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("You reviewed \(viewModel.sprintResolvedCount) of \(viewModel.sprintTotal) tasks.\nYour changes are saved.\n\(viewModel.remainingCount) tasks can wait.")
                        .font(.lifeboard(.title3))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                }

                HStack(spacing: 18) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Pause", systemImage: "cup.and.saucer")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(RoundedRectangle(cornerRadius: 24).stroke(Color.lifeboard.accentPrimary.opacity(0.38)))
                    }
                    .foregroundStyle(Color.lifeboard.accentPrimary)

                    Button {
                        viewModel.resume()
                    } label: {
                        Label("Keep going", systemImage: "arrow.right")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color.lifeboard.accentPrimary))
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 28)

                Button {
                    viewModel.resume()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "lifepreserver")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.white.opacity(0.58)))
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Resume overdue rescue")
                                .font(.lifeboard(.headline))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text("\(viewModel.summary.reviewed) done · \(viewModel.remainingCount) left")
                                .font(.lifeboard(.title3))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                            LifeBoardProgressBar(progress: viewModel.progress, colors: [Color.lifeboard.accentPrimary])
                        }
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.68))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.lifeboard.statusWarning.opacity(0.18)))
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                Color.clear.frame(height: max(28, bottomInset))
            }
        }
    }
}

private struct OverdueRescueCompletionView: View {
    let summary: OverdueRescueSummary
    let remaining: Int
    let bottomInset: CGFloat
    let viewToday: () -> Void
    let reviewRemaining: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 26) {
                HStack {
                    Button("Close", systemImage: "xmark", action: viewToday)
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.white.opacity(0.84)))
                    Spacer()
                    Button("More", systemImage: "ellipsis") {}
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color.white.opacity(0.84)))
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueSunriseHero()
                    .frame(width: 260, height: 220)
                Text("Board cleaned up")
                    .font(.lifeboard(.title1))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("You sorted what still matters.")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                HStack(spacing: 14) {
                    statCard(icon: "checkmark.circle", value: summary.kept, label: "kept", color: Color.lifeboard.statusSuccess)
                    statCard(icon: "clock", value: summary.moved, label: "moved later", color: Color.lifeboard.statusWarning)
                    statCard(icon: "trash", value: summary.deleted, label: "deleted", color: Color.lifeboard.statusDanger)
                }
                .padding(.horizontal, 28)

                Text("Your board should feel lighter now.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                Button("View today", action: viewToday)
                    .font(.lifeboard(.button))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.lifeboard.accentPrimary))
                    .padding(.horizontal, 42)

                if remaining > 0 {
                    Button("Review remaining", systemImage: "list.bullet", action: reviewRemaining)
                        .font(.lifeboard(.button))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(RoundedRectangle(cornerRadius: 22).stroke(Color.lifeboard.accentPrimary.opacity(0.32)))
                        .padding(.horizontal, 42)
                }

                Color.clear.frame(height: max(28, bottomInset))
            }
        }
    }

    private func statCard(icon: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title.weight(.semibold))
            Text("\(value)")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
            Text(label)
                .font(.lifeboard(.caption1))
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 126)
        .background(RoundedRectangle(cornerRadius: 24).fill(color.opacity(0.07)))
    }
}

private struct OverdueRescueLargeStackView: View {
    let count: Int
    let safeCount: Int
    let applySafeFixes: () -> Void
    let startManualReview: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            OverdueRescueShieldHero()
                .frame(width: 220, height: 180)
            Text("Large overdue stack")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text("\(count) tasks need review. Start with high-confidence fixes or review manually.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Apply safe fixes") {
                dismiss()
                applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.lifeboard.accentPrimary))
            .disabled(safeCount == 0)
            Button("Start manual review") {
                dismiss()
                startManualReview()
            }
            .font(.lifeboard(.button))
            .foregroundStyle(Color.lifeboard.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: 62)
        }
        .padding(28)
        .background(OverdueRescueBackground())
    }
}

private struct OverdueRescueErrorView: View {
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text("Rescue paused")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text(message)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Close", action: close)
            Spacer()
        }
        .padding(28)
    }
}

private struct OverdueRescueBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.995, blue: 0.97),
                Color(red: 1.0, green: 0.97, blue: 0.91),
                Color(red: 1.0, green: 0.995, blue: 0.98)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct OverdueRescuePlant: View {
    var body: some View {
        Image(decorative: "rescue_decor_plant")
            .resizable()
            .scaledToFit()
    }
}

private struct OverdueRescueCupHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_cup")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .opacity(0.8)
                .offset(x: -72, y: -68)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .opacity(0.6)
                .offset(x: 76, y: -44)
        }
    }
}

private struct OverdueRescueShieldHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_shield")
                .resizable()
                .scaledToFit()
            OverdueRescuePlant()
                .frame(width: 72, height: 88)
                .offset(x: 82, y: 32)
        }
    }
}

private struct OverdueRescueSunriseHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_sunrise")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .opacity(0.7)
                .offset(x: -88, y: -52)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .opacity(0.5)
                .offset(x: 92, y: -38)
            OverdueRescuePlant()
                .frame(width: 80, height: 96)
                .offset(x: 86, y: 16)
        }
    }
}

struct LifeBoardProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.lifeboard.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(animate ? LifeBoardAnimation.stateChange : .linear(duration: 0.01), value: clampedProgress)
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}
