import SwiftUI
import UIKit

// The view model and the services it leans on.

// MARK: - OverdueRescueViewModel

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


/// Native app-level ownership for launching and presenting Rescue.
///
/// Home supplies task services, but no longer owns the launcher's state. This
/// keeps Home, Plan, and universal-input Day Rescue on one run identity and one
/// presentation path while the decision deck remains independently testable.
@MainActor
@Observable
final class OverdueRescueLaunchCoordinator {
    private(set) var launcherState: HomeOverdueRescueLauncherState = .idle
    private(set) var plan: EvaRescuePlan?
    private(set) var normalTasksByID: [UUID: TaskDefinition] = [:]
    private(set) var dayRescueTasksByID: [UUID: TaskDefinition] = [:]
    private(set) var referenceDate: Date?
    private(set) var presentation: OverdueRescueLaunchContext?
    var lastBatchRunID: UUID?

    var isPresented: Bool { presentation != nil && launcherState == .ready }

    var presentedTasksByID: [UUID: TaskDefinition] {
        guard let presentation else { return [:] }
        return presentation.origin == .universalInputDayRescue
            ? dayRescueTasksByID
            : normalTasksByID
    }

    func begin(
        _ context: OverdueRescueLaunchContext,
        dayRescueTasksByID: [UUID: TaskDefinition] = [:]
    ) {
        presentation = context
        referenceDate = context.referenceDate
        launcherState = .loading
        plan = nil
        normalTasksByID = [:]
        self.dayRescueTasksByID = dayRescueTasksByID
    }

    func present(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        context: OverdueRescueLaunchContext
    ) {
        presentation = context
        referenceDate = context.referenceDate
        self.plan = plan
        if context.origin == .universalInputDayRescue {
            dayRescueTasksByID = tasksByID
        } else {
            normalTasksByID = tasksByID
        }
        launcherState = .ready
    }

    func fail(_ message: String) {
        launcherState = .failed(message)
        plan = nil
        normalTasksByID = [:]
    }

    func dismiss() {
        launcherState = .idle
        plan = nil
        normalTasksByID = [:]
        dayRescueTasksByID = [:]
        referenceDate = nil
        presentation = nil
    }
}

@MainActor
final class OverdueRescueViewModel: ObservableObject {


    static let sprintLimit = OverdueRescueEligibilityService.sprintLimit

    static let largeStackThreshold = OverdueRescueEligibilityService.largeStackThreshold

    @Published var state: OverdueRescueDeckState = .notStarted

    @Published var cards: [OverdueRescueCardModel] = []

    @Published var currentIndex = 0

    @Published var sprintTotal = 0

    @Published var sprintResolvedCount = 0

    @Published var summary = OverdueRescueSummary()

    @Published var undoRecords: [OverdueRescueUndoRecord] = []

    @Published var snackbar: SnackbarData?

    @Published var errorMessage: String?

    @Published var showLargeStackPreflight = false

    @Published var showSafeFixesConfirmation = false

    @Published var isDecisionInFlight = false

    /// True when the deck transitioned straight to `.completed` at launch
    /// because there were zero eligible cards. Drives the empty-at-launch
    /// copy in `OverdueRescueCompletionView` (today's "Nothing needs
    /// rescuing today" state for the universal-input Day-Rescue flow).
    private(set) var startedEmpty = false

    let allCount: Int

    let allCards: [OverdueRescueCardModel]

    let referenceDate: Date

    let projectsByID: [UUID: Project]

    let nowProvider: @Sendable () -> Date

    let launchContext: OverdueRescueLaunchContext

    var resolvedTaskIDs: Set<UUID> = []

    let runID: UUID

    let sessionScope: OverdueRescueSessionScope

    let sessionStore: UserDefaultsOverdueRescueSessionStore

    var lastRecoverableState: OverdueRescueDeckState = .notStarted

    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void

    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onApplyBulk: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onUndoBulk: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onSavePlanningMetadata: @Sendable (
        [PlanningTaskMetadata],
        @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> Void

    let onTrack: (String, [String: Any]) -> Void

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        launchContext: OverdueRescueLaunchContext? = nil,
        sessionScope: OverdueRescueSessionScope? = nil,
        sessionStore: UserDefaultsOverdueRescueSessionStore = UserDefaultsOverdueRescueSessionStore(),
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApplyBulk: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndoBulk: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onSavePlanningMetadata: @escaping @Sendable (
            [PlanningTaskMetadata],
            @escaping @Sendable (Result<Void, Error>) -> Void
        ) -> Void = { _, completion in completion(.success(())) },
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        let resolvedLaunchContext = launchContext ?? .home(referenceDate: referenceDate)
        let planRecommendations = Self.orderedRecommendations(from: plan)
        let recommendationByID = Dictionary(uniqueKeysWithValues: planRecommendations.map { ($0.taskID, $0) })
        let scope = sessionScope ?? resolvedLaunchContext.sessionScope()
        let decisionCalendar = resolvedLaunchContext.decisionCalendar()
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
                    now: referenceDate,
                    decisionAnchorDate: resolvedLaunchContext.targetDate(calendar: decisionCalendar),
                    decisionCalendar: decisionCalendar
                )
            }
            .sorted { lhs, rhs in
                OverdueRescueEligibilityService.sortCards(lhs, rhs, referenceDate: referenceDate)
            }

        self.allCards = cards
        self.allCount = cards.count
        self.referenceDate = referenceDate
        self.projectsByID = projectsByID
        self.nowProvider = nowProvider
        self.launchContext = resolvedLaunchContext
        self.sessionScope = scope
        self.sessionStore = sessionStore
        let savedSession: OverdueRescueSessionState?
        do {
            savedSession = try sessionStore.loadSync(scope: scope)
        } catch {
            logError("[OverdueRescue] Failed to load saved session scope=\(scope.storageKey): \(error)")
            savedSession = nil
        }
        self.runID = savedSession?.runID ?? UUID()
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApplyBulk = onApplyBulk
        self.onUndoBulk = onUndoBulk
        self.onSavePlanningMetadata = onSavePlanningMetadata
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
            self.startedEmpty = cards.isEmpty
            _ = transition(to: .loading)
            _ = transition(to: cards.isEmpty ? .completed : .active)
        }
    }
}

// MARK: - OverdueRescueEligibilityService

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


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
        guard OverdueRescueEligibilityPolicy.isStaleOverdueTask(task, referenceDate: referenceDate) else {
            return false
        }
        if let project = projectsByID[task.projectID], project.isArchived {
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

    static func rankingScore(_ card: OverdueRescueCardModel, referenceDate: Date) -> Int {
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

// MARK: - OverdueRescueMoveLaterResolver

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueMoveLaterResolver {
    static func resolveMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        if let suggested = recommendation?.toDate {
            let suggestedDay = calendar.startOfDay(for: suggested)
            if suggestedDay > today {
                return suggestedDay
            }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let lowUrgency = task.priority == .none || task.priority == .low
        if isWorkingDay(tomorrow, calendar: calendar), lowUrgency || task.priority.isHighPriority == false {
            return tomorrow
        }

        return nextWorkingDay(after: today, calendar: calendar)
    }

    static func buttonTitle(
        for date: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        guard let date else { return "Move later" }
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

    static func nextWorkingDay(after date: Date, calendar: Calendar) -> Date {
        var candidate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        while isWorkingDay(candidate, calendar: calendar) == false {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func isWorkingDay(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}
