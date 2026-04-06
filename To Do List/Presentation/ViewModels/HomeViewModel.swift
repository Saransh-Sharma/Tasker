//
//  HomeViewModel.swift
//  Tasker
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum HomeTaskMutationEvent: String, Codable, CaseIterable {
    case created
    case updated
    case deleted
    case completed
    case reopened
    case rescheduled
    case projectChanged
    case priorityChanged
    case typeChanged
    case dueDateChanged
    case bulkChanged
}

public enum HomeReloadScope: String, CaseIterable, Hashable {
    case visibleTasks
    case facets
    case analytics
    case charts
    case savedViews
}

public struct HomeDataRevision: Equatable, Hashable {
    public static let zero = HomeDataRevision(rawValue: 0)
    public private(set) var rawValue: UInt64

    public init(rawValue: UInt64 = 0) {
        self.rawValue = rawValue
    }

    mutating func advance() {
        rawValue &+= 1
    }
}

private final class HomeReloadBatchTracker {
    private let lock = NSLock()
    private let onComplete: () -> Void
    private var pendingOperations: Int = 0
    private var finishedScheduling = false
    private var completed = false

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func registerOperation() {
        lock.lock()
        pendingOperations += 1
        lock.unlock()
    }

    func completeOperation() {
        let shouldComplete: Bool = lock.withLock {
            pendingOperations = max(0, pendingOperations - 1)
            return finishedScheduling && pendingOperations == 0 && completed == false
        }
        if shouldComplete {
            finish()
        }
    }

    func finishSchedulingOperations() {
        let shouldComplete: Bool = lock.withLock {
            finishedScheduling = true
            return pendingOperations == 0 && completed == false
        }
        if shouldComplete {
            finish()
        }
    }

    private func finish() {
        let shouldRun: Bool = lock.withLock {
            guard completed == false else { return false }
            completed = true
            return true
        }
        if shouldRun {
            onComplete()
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}

public enum FocusPinResult: Equatable {
    case pinned
    case alreadyPinned
    case capacityReached(limit: Int)
    case taskIneligible
}

public enum FocusPromotionResult: Equatable {
    case promoted
    case alreadyPinned
    case alreadyVisible
    case replacementRequired(currentFocusTaskIDs: [UUID])
    case taskIneligible
}

public extension Notification.Name {
    static let homeTaskMutation = Notification.Name("HomeTaskMutationEvent")
}

public enum CelebrationKind: String {
    case milestone
    case levelUp
    case achievementUnlock
    case xpBurst
}

public struct CelebrationEvent: Equatable {
    public let kind: CelebrationKind
    public let awardedXP: Int
    public let level: Int
    public let milestone: XPCalculationEngine.Milestone?
    public let achievementKey: String?
    public let occurredAt: Date
    public let signature: String

    public static func from(_ result: XPEventResult) -> CelebrationEvent? {
        guard result.awardedXP > 0 else { return nil }
        let unlockedKey = result.unlockedAchievements
            .map(\.achievementKey)
            .sorted()
            .first

        if let milestone = result.crossedMilestone {
            return CelebrationEvent(
                kind: .milestone,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: milestone,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "milestone:\(result.totalXP):\(milestone.xpThreshold)"
            )
        }
        if result.didLevelUp {
            return CelebrationEvent(
                kind: .levelUp,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: nil,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "levelup:\(result.totalXP):\(result.level)"
            )
        }
        if let unlockedKey {
            return CelebrationEvent(
                kind: .achievementUnlock,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: nil,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "achievement:\(result.totalXP):\(unlockedKey)"
            )
        }
        return CelebrationEvent(
            kind: .xpBurst,
            awardedXP: result.awardedXP,
            level: result.level,
            milestone: nil,
            achievementKey: nil,
            occurredAt: result.celebration?.occurredAt ?? Date(),
            signature: "xpburst:\(result.totalXP):\(result.awardedXP):\(result.level)"
        )
    }
}

public struct CelebrationPresentation: Equatable {
    public let event: CelebrationEvent
}

public protocol CelebrationRouter: AnyObject {
    func route(event: CelebrationEvent) -> CelebrationPresentation?
}

public final class DefaultCelebrationRouter: CelebrationRouter {
    private var lastShownAtByKind: [CelebrationKind: Date] = [:]
    private var lastSignature: String?

    private let cooldownByKind: [CelebrationKind: TimeInterval] = [
        .milestone: 0,
        .levelUp: 0.4,
        .achievementUnlock: 1.0,
        .xpBurst: 4.0
    ]

    public init() {}

    public func route(event: CelebrationEvent) -> CelebrationPresentation? {
        if lastSignature == event.signature {
            return nil
        }
        let cooldown = cooldownByKind[event.kind] ?? 0
        if let last = lastShownAtByKind[event.kind],
           cooldown > 0,
           event.occurredAt.timeIntervalSince(last) < cooldown {
            return nil
        }

        lastShownAtByKind[event.kind] = event.occurredAt
        lastSignature = event.signature
        return CelebrationPresentation(event: event)
    }
}

public struct InsightsLaunchRequest: Equatable {
    public let token: UUID
    public let targetTab: InsightsViewModel.InsightsTab
    public let highlightedAchievementKey: String?

    public init(
        token: UUID = UUID(),
        targetTab: InsightsViewModel.InsightsTab = .today,
        highlightedAchievementKey: String? = nil
    ) {
        self.token = token
        self.targetTab = targetTab
        self.highlightedAchievementKey = highlightedAchievementKey
    }

    public static var `default`: InsightsLaunchRequest {
        InsightsLaunchRequest(targetTab: .today)
    }
}

/// ViewModel for the Home screen
/// Manages all business logic and state for the home view
public final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties (Observable State)

    @Published public private(set) var todayTasks: TodayTasksResult?
    @Published public private(set) var selectedDate: Date = Date() {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var selectedProject: String = "All"
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var dailyScore: Int = 0
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var completionRate: Double = 0.0

    // Gamification v2
    @Published public private(set) var currentLevel: Int = 1
    @Published public private(set) var dailyXPCap: Int = GamificationTokens.dailyXPCap
    @Published public private(set) var totalXP: Int64 = 0
    @Published public private(set) var nextLevelXP: Int64 = 0
    @Published public private(set) var lastXPResult: XPEventResult? {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var insightsLaunchRequest: InsightsLaunchRequest?
    @Published public private(set) var insightsLaunchToken: UUID?

    // TaskDefinition lists by category
    @Published public private(set) var morningTasks: [TaskDefinition] = []
    @Published public private(set) var eveningTasks: [TaskDefinition] = []
    @Published public private(set) var overdueTasks: [TaskDefinition] = []
    @Published public private(set) var dailyCompletedTasks: [TaskDefinition] = []
    @Published public private(set) var upcomingTasks: [TaskDefinition] = []
    @Published public private(set) var completedTasks: [TaskDefinition] = []
    @Published public private(set) var doneTimelineTasks: [TaskDefinition] = []
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var dueTodayRows: [HomeTodayRow] = [] {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var dueTodaySection: HomeListSection? {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var todaySections: [HomeListSection] = [] {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var focusNowSectionState = FocusNowSectionState(rows: [], pinnedTaskIDs: []) {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var todayAgendaSectionState = TodayAgendaSectionState(sections: []) {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var rescueSectionState = RescueSectionState(rows: []) {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var quietTrackingSummaryState = QuietTrackingSummaryState(stableRows: []) {
        didSet { scheduleHomeRenderStateRefresh() }
    }

    // Focus Engine
    @Published public private(set) var activeFilterState: HomeFilterState = .default {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var savedHomeViews: [SavedHomeView] = [] {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var quickViewCounts: [HomeQuickView: Int] = [:]
    @Published public private(set) var pointsPotential: Int = 0
    @Published public private(set) var progressState: HomeProgressState = .empty
    @Published public private(set) var focusTasks: [TaskDefinition] = []
    @Published public private(set) var focusWhyShuffleCandidates: [TaskDefinition] = []
    @Published public private(set) var focusRows: [HomeTodayRow] = [] {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var pinnedFocusTaskIDs: [UUID] = []
    @Published public private(set) var emptyStateMessage: String?
    @Published public private(set) var emptyStateActionTitle: String?
    @Published public private(set) var focusEngineEnabled: Bool = true
    @Published public private(set) var activeScope: HomeListScope = .today {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaHomeInsights: EvaHomeInsights?
    @Published public private(set) var evaFocusWhySheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaTriageSheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaRescueSheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaTriageScope: EvaTriageScope = .visible {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaTriageQueueLoading: Bool = false {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaTriageQueueErrorMessage: String? {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaTriageQueue: [EvaTriageQueueItem] = [] {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaRescuePlan: EvaRescuePlan? {
        didSet { scheduleHomeRenderStateRefresh() }
    }
    @Published public private(set) var evaLastBatchRunID: UUID? {
        didSet { scheduleHomeRenderStateRefresh() }
    }

    private(set) var homeChromeState: HomeChromeState = .empty
    private(set) var homeTasksState: HomeTasksState = .empty
    private(set) var homeOverlayState: HomeOverlayState = .empty
    @Published private(set) var homeRenderTransaction: HomeRenderTransaction = .empty

    // Next Action Module: total open tasks for today
    public var todayOpenTaskCount: Int {
        if activeScope.quickView == .today, !todaySections.isEmpty {
            return todaySections
                .flatMap(\.rows)
                .filter(\.isOpenForHomeCount)
                .count
        }
        return (morningTasks + eveningTasks).filter { !$0.isComplete }.count
    }

    // Projects
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var tags: [TagDefinition] = []
    @Published public private(set) var selectedProjectTasks: [TaskDefinition] = []

    // MARK: - Dependencies

    private let useCaseCoordinator: UseCaseCoordinator
    private let homeFilteredTasksUseCase: GetHomeFilteredTasksUseCase
    private let computeEvaHomeInsightsUseCase: ComputeEvaHomeInsightsUseCase
    private let getInboxTriageQueueUseCase: GetInboxTriageQueueUseCase
    private let getOverdueRescuePlanUseCase: GetOverdueRescuePlanUseCase
    private let buildEvaBatchProposalUseCase: BuildEvaBatchProposalUseCase
    private let getDailySummaryModalUseCase: GetDailySummaryModalUseCase
    private let buildHomeAgendaUseCase: BuildHomeAgendaUseCase
    private let buildHabitHomeProjectionUseCase: BuildHabitHomeProjectionUseCase
    private let savedHomeViewRepository: SavedHomeViewRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol?
    private let aiSuggestionService: AISuggestionService?
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private lazy var retainedInsightsViewModel: InsightsViewModel = {
        InsightsViewModel(
            engine: useCaseCoordinator.gamificationEngine,
            repository: useCaseCoordinator.gamificationRepository,
            taskReadModelRepository: useCaseCoordinator.taskReadModelRepository,
            reminderRepository: useCaseCoordinator.reminderRepository,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics
        )
    }()
    private lazy var retainedHomeSearchViewModel = LGSearchViewModel(useCaseCoordinator: useCaseCoordinator)

    // MARK: - Persistence Keys

    private static let lastFilterStateKey = "home.focus.lastFilterState.v2"
    private static let pinnedFocusTaskIDsKey = "home.focus.pinnedTaskIDs.v2"
    private static let recentShuffleTaskIDsKey = "home.eva.recentShuffleTaskIDs.v1"
    private static let maxPinnedFocusTasks = 3
    private static let maxShuffleHistorySize = 10
    private static let defaultShuffleExclusionWindow = 3

    // MARK: - Session State

    private var homeOpenedAt: Date = Date()
    private var didTrackFirstCompletionLatency = false
    private var completionOverrides: [UUID: Bool] = [:]
    private var reloadGeneration: Int = 0
    private var dataRevision: HomeDataRevision = .zero
    private var suppressCompletionReloadUntil: Date?
    private var lastRecurringTopUpAt: Date?
    private var pendingRecurringTopUpWorkItem: DispatchWorkItem?
    private var recentShuffledFocusTaskIDs: [UUID] = []

    private let completionNotificationDebounceMS = 120
    private let completionReloadSuppressionSeconds: TimeInterval = 0.35
    private let mutationNotificationDebounceMS = 90
    private let reloadDebounceMS = 120
    private let analyticsDebounceMS = 120
    private let recurringTopUpDelaySeconds: TimeInterval = 5.0
    private let recurringTopUpThrottleSeconds: TimeInterval = 90
    private let ledgerMutationWatchdogDelaySeconds: TimeInterval = 1.0
    private static let mutationNotificationSource = "homeViewModel"
    private var pendingLedgerMutationWatchdog: DispatchWorkItem?
    private var lastLedgerMutationObservedAt: Date = .distantPast
    private var pendingReloadWorkItem: DispatchWorkItem?
    private var pendingReloadSources: Set<String> = []
    private var pendingReloadReasons: Set<HomeTaskMutationEvent> = []
    private var pendingReloadScopes: Set<HomeReloadScope> = []
    private var pendingReloadTaskIDs: Set<UUID> = []
    private var pendingReloadInvalidateCaches = false
    private var pendingReloadIncludeAnalytics = false
    private var pendingReloadRepostEvent = false
    private var isApplyingReloadBatch = false
    private var queuedReloadAfterCurrentBatch = false
    private var pendingAnalyticsWorkItem: DispatchWorkItem?
    private var pendingDeferredAnalyticsRefreshWorkItem: DispatchWorkItem?
    private var pendingAnalyticsIncludeGamificationRefresh = false
    private var pendingAnalyticsCompletions: [() -> Void] = []
    private var analyticsGeneration: Int = 0
    private var pendingHomeRenderStateWorkItem: DispatchWorkItem?
    private var homeRenderStateRefreshBatchDepth: Int = 0
    private var needsHomeRenderStateRefresh = false
    private var currentHabitSignals: [TaskerHabitSignal] = []
    private var evaInsightsGeneration: Int = 0

    deinit {
        pendingRecurringTopUpWorkItem?.cancel()
    }

    var currentDataRevision: HomeDataRevision {
        dataRevision
    }

    private func scheduleHomeRenderStateRefresh() {
        if Foundation.Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.scheduleHomeRenderStateRefresh()
            }
            return
        }
        if homeRenderStateRefreshBatchDepth > 0 {
            needsHomeRenderStateRefresh = true
            return
        }

        pendingHomeRenderStateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshHomeRenderStates()
        }
        pendingHomeRenderStateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func performHomeRenderStateBatch(_ work: () -> Void) {
        guard Foundation.Thread.isMainThread else {
            work()
            return
        }

        homeRenderStateRefreshBatchDepth += 1
        work()
        homeRenderStateRefreshBatchDepth = max(0, homeRenderStateRefreshBatchDepth - 1)

        guard homeRenderStateRefreshBatchDepth == 0, needsHomeRenderStateRefresh else { return }
        needsHomeRenderStateRefresh = false
        scheduleHomeRenderStateRefresh()
    }

    private func refreshHomeRenderStates() {
        let transaction = HomeRenderTransaction(
            chrome: buildHomeChromeState(),
            tasks: buildHomeTasksState(),
            overlay: buildHomeOverlayState()
        )
        guard homeRenderTransaction != transaction else { return }

        homeChromeState = transaction.chrome
        homeTasksState = transaction.tasks
        homeOverlayState = transaction.overlay
        homeRenderTransaction = transaction
    }

    private func buildHomeChromeState() -> HomeChromeState {
        HomeChromeState(
            selectedDate: selectedDate,
            activeScope: activeScope,
            activeFilterState: activeFilterState,
            savedHomeViews: savedHomeViews,
            quickViewCounts: quickViewCounts,
            progressState: progressState,
            dailyScore: dailyScore,
            completionRate: completionRate,
            projects: projects,
            // Reflection stays tied to the default Today scope, not custom-date views.
            reflectionEligible: activeScope == .today && !isDailyReflectionCompletedToday(),
            momentumGuidanceText: makeMomentumGuidanceText()
        )
    }

    private func buildHomeTasksState() -> HomeTasksState {
        let projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        var projectByName = Dictionary(uniqueKeysWithValues: projects.map { ($0.name, $0) })
        projectByName[ProjectConstants.inboxProjectName] = Project.createInbox()
        let tagNameByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        let rescueTasks = overdueTasks + morningTasks + eveningTasks + evaTriageQueue.map(\.task)
        let rescueTasksByID = Dictionary(uniqueKeysWithValues: rescueTasks.map { ($0.id, $0) })
        let todayXPSoFar: Int? =
            (V2FeatureFlags.gamificationV2Enabled && progressState.todayTargetXP <= 0)
            ? nil
            : progressState.earnedXP

        return HomeTasksState(
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            dueTodaySection: dueTodaySection,
            todaySections: todaySections,
            focusNowSectionState: focusNowSectionState,
            todayAgendaSectionState: todayAgendaSectionState,
            rescueSectionState: rescueSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            inlineCompletedTasks: activeScope.quickView == .today ? completedTasks : [],
            doneTimelineTasks: doneTimelineTasks,
            projects: projects,
            projectsByID: projectByID,
            projectsByName: projectByName,
            tagNameByID: tagNameByID,
            rescueTasksByID: rescueTasksByID,
            activeQuickView: activeScope.quickView,
            todayXPSoFar: todayXPSoFar,
            projectGroupingMode: activeFilterState.projectGroupingMode,
            customProjectOrderIDs: activeFilterState.customProjectOrderIDs,
            emptyStateMessage: emptyStateMessage,
            emptyStateActionTitle: emptyStateActionTitle,
            canUseManualFocusDrag: false,
            focusTasks: focusTasks,
            focusRows: focusRows,
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            todayOpenTaskCount: todayOpenTaskCount
        )
    }

    private func buildHomeOverlayState() -> HomeOverlayState {
        HomeOverlayState(
            guidanceState: nil,
            focusWhyPresented: evaFocusWhySheetPresented,
            triagePresented: evaTriageSheetPresented,
            triageScope: evaTriageScope,
            triageQueueLoading: evaTriageQueueLoading,
            triageQueueErrorMessage: evaTriageQueueErrorMessage,
            triageQueue: evaTriageQueue,
            rescuePresented: evaRescueSheetPresented,
            rescuePlan: evaRescuePlan,
            lastBatchRunID: evaLastBatchRunID,
            lastXPResult: lastXPResult
        )
    }

    private func makeMomentumGuidanceText() -> String {
        if progressState.todayTargetXP > 0 && progressState.earnedXP >= progressState.todayTargetXP {
            return "Momentum secured. Protect the streak with one clean finish."
        }
        if todayOpenTaskCount > 0 {
            return "Pick one visible task and finish it before switching surfaces."
        }
        return "Your surface is clear. Add one intentional task for today."
    }

    // MARK: - Initialization

    /// Initializes a new instance.
    init(
        useCaseCoordinator: UseCaseCoordinator,
        savedHomeViewRepository: SavedHomeViewRepositoryProtocol = UserDefaultsSavedHomeViewRepository(),
        analyticsService: AnalyticsServiceProtocol? = nil,
        aiSuggestionService: AISuggestionService? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.homeFilteredTasksUseCase = useCaseCoordinator.getHomeFilteredTasks
        self.computeEvaHomeInsightsUseCase = useCaseCoordinator.computeEvaHomeInsights
        self.getInboxTriageQueueUseCase = useCaseCoordinator.getInboxTriageQueue
        self.getOverdueRescuePlanUseCase = useCaseCoordinator.getOverdueRescuePlan
        self.buildEvaBatchProposalUseCase = useCaseCoordinator.buildEvaBatchProposal
        self.buildHomeAgendaUseCase = BuildHomeAgendaUseCase()
        self.buildHabitHomeProjectionUseCase = useCaseCoordinator.buildHabitHomeProjection
        self.getDailySummaryModalUseCase = GetDailySummaryModalUseCase(
            getTasksUseCase: useCaseCoordinator.getTasks,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics
        )
        self.savedHomeViewRepository = savedHomeViewRepository
        self.analyticsService = analyticsService
        self.aiSuggestionService = aiSuggestionService
        self.userDefaults = userDefaults

        setupBindings()
        loadInitialData()
    }

    // MARK: - Public Methods

    /// Load tasks for the selected date.
    public func loadTasksForSelectedDate() {
        focusEngineEnabled = true
        activeScope = .customDate(selectedDate)
        var state = activeFilterState
        state.quickView = .today
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false, generation: nextReloadGeneration())
    }

    /// Executes loadTasksForSelectedDate.
    private func loadTasksForSelectedDate(generation: Int) {
        scheduleRecurringTopUpIfNeeded()
        focusEngineEnabled = true
        activeScope = .customDate(selectedDate)
        applyFocusFilters(trackAnalytics: false, generation: generation)
    }

    /// Load tasks for today.
    public func loadTodayTasks() {
        loadTodayTasks(generation: nextReloadGeneration())
    }

    /// Executes loadTodayTasks.
    private func loadTodayTasks(generation: Int) {
        scheduleRecurringTopUpIfNeeded()
        focusEngineEnabled = true
        activeScope = .today
        selectedDate = Date()
        var state = activeFilterState
        state.quickView = .today
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false, generation: generation)
        loadDailyAnalytics()
    }

    /// Executes scheduleRecurringTopUpIfNeeded.
    private func scheduleRecurringTopUpIfNeeded() {
        let now = Date()
        if let lastRecurringTopUpAt,
           now.timeIntervalSince(lastRecurringTopUpAt) < recurringTopUpThrottleSeconds {
            return
        }
        pendingRecurringTopUpWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lastRecurringTopUpAt = Date()
            self.useCaseCoordinator.createTaskDefinition.maintainRecurringSeries(daysAhead: 45) { _ in }
        }
        pendingRecurringTopUpWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + recurringTopUpDelaySeconds,
            execute: workItem
        )
    }

    /// Toggle task completion.
    public func toggleTaskCompletion(_ task: TaskDefinition) {
        setTaskCompletion(
            taskID: task.id,
            to: !task.isComplete,
            taskSnapshot: task
        ) { _ in }
    }

    public func completeHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, source: source)
    }

    public func skipHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .skip, source: source)
    }

    public func lapseHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .lapsed, source: source)
    }

    public func logHabitProgress(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, on: date, source: source)
    }

    public func logHabitLapse(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: .lapsed, on: date, source: source)
    }

    /// Deterministically sets completion to a desired value.
    public func setTaskCompletion(
        taskID: UUID,
        to desiredCompletion: Bool,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        setTaskCompletion(
            taskID: taskID,
            to: desiredCompletion,
            taskSnapshot: currentTaskSnapshot(for: taskID),
            completion: completion
        )
    }

    /// Create a new task.
    public func createTask(request: CreateTaskDefinitionRequest) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.enqueueReload(
                        source: "create_task",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Delete a task.
    public func deleteTask(_ task: TaskDefinition) {
        deleteTask(taskID: task.id) { _ in }
    }

    /// Executes deleteTask.
    public func deleteTask(
        taskID: UUID,
        scope: TaskDeleteScope = .single,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: scope) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.removePinnedFocusTaskID(taskID)
                    self?.enqueueReload(
                        source: "delete_task",
                        reason: .deleted,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(()))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Reschedule a task.
    public func rescheduleTask(_ task: TaskDefinition, to newDate: Date?) {
        rescheduleTask(taskID: task.id, to: newDate) { _ in }
    }

    /// Executes rescheduleTask.
    public func rescheduleTask(
        taskID: UUID,
        to newDate: Date?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.rescheduleTaskDefinition.execute(taskID: taskID, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let task):
                    self?.enqueueReload(
                        source: "reschedule_task",
                        reason: .rescheduled,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes updateTask.
    public func updateTask(
        taskID: UUID,
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        var normalizedRequest = request
        normalizedRequest.updatedAt = Date()
        useCaseCoordinator.updateTaskDefinition.execute(request: normalizedRequest) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let task):
                    self?.enqueueReload(
                        source: "update_task",
                        reason: self?.mutationReason(for: request) ?? .updated,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(task))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes loadTaskDetailMetadata.
    public func loadTaskDetailMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        var loadedProjects: [Project] = projects
        var loadedSections: [TaskerProjectSection] = []

        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        useCaseCoordinator.manageProjects.getAllProjects { result in
            defer { group.leave() }
            switch result {
            case .success(let projectsWithStats):
                loadedProjects = projectsWithStats.map(\.project)
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageSections.list(projectID: projectID) { result in
            defer { group.leave() }
            switch result {
            case .success(let sections):
                loadedSections = sections
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(TaskDetailMetadataPayload(
                projects: loadedProjects,
                sections: loadedSections
            )))
        }
    }

    public func loadTaskDetailRelationshipMetadata(
        projectID: UUID,
        completion: @escaping (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        var loadedLifeAreas: [LifeArea] = []
        var loadedTags: [TagDefinition] = []
        var availableTasks: [TaskDefinition] = []

        /// Executes record.
        func record(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        useCaseCoordinator.manageLifeAreas.list { result in
            defer { group.leave() }
            switch result {
            case .success(let lifeAreas):
                loadedLifeAreas = lifeAreas
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.manageTags.list { result in
            defer { group.leave() }
            switch result {
            case .success(let tags):
                loadedTags = tags
            case .failure(let error):
                record(error)
            }
        }

        group.enter()
        useCaseCoordinator.getTasks.getTasksForProject(projectID, includeCompleted: false) { result in
            defer { group.leave() }
            switch result {
            case .success(let slice):
                availableTasks = slice.tasks
            case .failure(let error):
                record(error)
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(TaskDetailRelationshipMetadataPayload(
                lifeAreas: loadedLifeAreas,
                tags: loadedTags,
                availableTasks: availableTasks
            )))
        }
    }

    /// Executes loadTaskChildren.
    public func loadTaskChildren(
        parentTaskID: UUID,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        useCaseCoordinator.getTaskChildren.execute(parentTaskID: parentTaskID) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Executes createTaskDefinition.
    public func createTaskDefinition(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.createTaskDefinition.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdTask):
                    self?.enqueueReload(
                        source: "create_task_definition",
                        reason: .created,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    completion(.success(createdTask))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes createTagForTaskDetail.
    public func createTagForTaskDetail(
        name: String,
        completion: @escaping (Result<TagDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.manageTags.create(name: name, color: nil, icon: nil) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let createdTag) = result {
                    self?.upsertTag(createdTag)
                }
                completion(result)
            }
        }
    }

    /// Executes createProjectForTaskDetail.
    public func createProjectForTaskDetail(
        name: String,
        completion: @escaping (Result<Project, Error>) -> Void
    ) {
        useCaseCoordinator.manageProjects.createProject(request: CreateProjectRequest(name: name)) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let project):
                    self?.loadProjects()
                    completion(.success(project))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    /// Track Home interactions from view-layer events (animations, collapse toggles, etc.).
    public func trackHomeInteraction(action: String, metadata: [String: Any] = [:]) {
        trackFeatureUsage(action: action, metadata: metadata)
    }

    public var canUseManualFocusDrag: Bool {
        false
    }

    /// Executes pinTaskToFocus.
    @discardableResult
    public func pinTaskToFocus(_ taskID: UUID) -> FocusPinResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
            return .capacityReached(limit: Self.maxPinnedFocusTasks)
        }

        pinnedFocusTaskIDs.append(taskID)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
        return .pinned
    }

    /// Executes unpinTaskFromFocus.
    public func unpinTaskFromFocus(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
    }

    public func promoteTaskToFocus(_ taskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        if currentFocus.contains(where: { $0.id == taskID }) {
            if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
                return .alreadyVisible
            }

            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        if pinnedFocusTaskIDs.count < Self.maxPinnedFocusTasks {
            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        return .replacementRequired(currentFocusTaskIDs: Array(currentFocus.prefix(Self.maxPinnedFocusTasks).map(\.id)))
    }

    public func replaceFocusTask(with taskID: UUID, replacing replacedTaskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        guard currentFocus.contains(where: { $0.id == replacedTaskID }) else {
            return .taskIneligible
        }

        if taskID == replacedTaskID {
            return .alreadyVisible
        }

        let curatedFocusIDs = [taskID] + currentFocus
            .map(\.id)
            .filter { $0 != taskID && $0 != replacedTaskID }
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(curatedFocusIDs)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
        return .promoted
    }

    /// Change selected date.
    public func selectDate(_ date: Date) {
        selectedDate = date

        if Calendar.current.isDateInToday(date) {
            focusEngineEnabled = true
            activeScope = .today
            loadTodayTasks()
            return
        }

        focusEngineEnabled = true
        activeScope = .customDate(date)
        loadTasksForSelectedDate()
    }

    /// Change selected project filter (legacy path).
    public func selectProject(_ projectName: String) {
        selectedProject = projectName

        if projectName == "All" {
            focusEngineEnabled = true
            applyFocusFilters(trackAnalytics: false)
        } else {
            focusEngineEnabled = true
            if let project = projects.first(where: { $0.name.caseInsensitiveCompare(projectName) == .orderedSame }) {
                setProjectFilters([project.id])
            } else {
                applyFocusFilters(trackAnalytics: false)
            }
        }
    }

    /// Focus Engine: set quick view.
    public func setQuickView(_ quickView: HomeQuickView) {
        focusEngineEnabled = true
        activeScope = .fromQuickView(quickView)
        if quickView == .today {
            selectedDate = Date()
        }
        var state = activeFilterState
        state.quickView = quickView
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    public func taskSnapshot(for taskID: UUID) -> TaskDefinition? {
        currentTaskSnapshot(for: taskID)
    }

    public func loadDailySummaryModal(
        kind: TaskerDailySummaryKind,
        dateStamp: String?,
        completion: @escaping (Result<DailySummaryModalData, Error>) -> Void
    ) {
        let date = Self.summaryDate(from: dateStamp) ?? Date()
        let normalizedDateStamp = Self.summaryDateStamp(from: date)

        getDailySummaryModalUseCase.execute(kind: kind, date: date) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let summary):
                    self?.trackHomeInteraction(
                        action: "daily_summary_modal_opened",
                        metadata: [
                            "kind": kind.rawValue,
                            "date_stamp": normalizedDateStamp,
                            "source": "notification",
                            "snapshot": summary.analyticsSnapshot
                        ]
                    )
                    completion(.success(summary))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func trackDailySummaryCTA(
        kind: TaskerDailySummaryKind,
        cta: String,
        countsSnapshot: [String: Any]
    ) {
        trackHomeInteraction(
            action: "daily_summary_cta_tapped",
            metadata: [
                "kind": kind.rawValue,
                "cta": cta,
                "counts_snapshot": countsSnapshot
            ]
        )
    }

    public func trackDailySummaryActionResult(cta: String, success: Bool, error: Error?) {
        var metadata: [String: Any] = [
            "cta": cta,
            "success": success
        ]
        if let error {
            metadata["error"] = error.localizedDescription
        }
        trackHomeInteraction(
            action: "daily_summary_action_result",
            metadata: metadata
        )
    }

    public func performEndOfDayCleanup(completion: @escaping (Result<CleanupResult, Error>) -> Void) {
        useCaseCoordinator.performEndOfDayCleanup { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cleanup):
                    self?.enqueueReload(
                        source: "end_of_day_cleanup",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: true,
                        repostEvent: true
                    )
                    completion(.success(cleanup))
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Focus Engine: set Today grouping mode.
    public func setProjectGroupingMode(_ mode: HomeProjectGroupingMode) {
        focusEngineEnabled = true
        var state = activeFilterState
        guard state.projectGroupingMode != mode else { return }
        state.projectGroupingMode = mode
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: set explicit custom project section order (Inbox excluded).
    public func setCustomProjectOrder(_ orderedProjectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        let normalizedOrder = normalizedCustomProjectOrder(
            from: orderedProjectIDs,
            currentOrder: state.customProjectOrderIDs,
            availableProjects: projects
        )
        guard state.customProjectOrderIDs != normalizedOrder else { return }
        state.customProjectOrderIDs = normalizedOrder
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: toggle a project facet chip (OR across selected IDs).
    public func toggleProjectFilter(_ projectID: UUID) {
        focusEngineEnabled = true
        var ids = activeFilterState.selectedProjectIDs

        if let index = ids.firstIndex(of: projectID) {
            ids.remove(at: index)
        } else {
            ids.append(projectID)
        }

        var state = activeFilterState
        state.selectedProjectIDs = ids
        state.selectedSavedViewID = nil
        activeFilterState = state

        bumpPinnedProject(projectID)
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set explicit selected project IDs.
    public func setProjectFilters(_ projectIDs: [UUID]) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = Array(Set(projectIDs))
        state.selectedSavedViewID = nil
        activeFilterState = state

        for id in projectIDs {
            bumpPinnedProject(id)
        }

        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: clear project filter facets.
    public func clearProjectFilters() {
        focusEngineEnabled = true
        var state = activeFilterState
        state.selectedProjectIDs = []
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_cleared", metadata: ["scope": "projects"])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: apply advanced composable filter.
    public func applyAdvancedFilter(_ filter: HomeAdvancedFilter?, showCompletedInline: Bool? = nil) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.advancedFilter = filter?.isEmpty == false ? filter : nil
        if let showCompletedInline {
            state.showCompletedInline = showCompletedInline
        }
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: set show completed inline flag.
    public func setShowCompletedInline(_ value: Bool) {
        focusEngineEnabled = true
        var state = activeFilterState
        state.showCompletedInline = value
        state.selectedSavedViewID = nil
        activeFilterState = state
        persistLastFilterState()
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: save current filter state as a reusable view.
    public func saveCurrentFilterAsView(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Saved view name cannot be empty"
            return
        }

        if savedHomeViews.count >= 20 {
            errorMessage = "You can save up to 20 Home views"
            return
        }

        let now = Date()
        let saved = SavedHomeView(
            name: trimmedName,
            quickView: activeFilterState.quickView,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            advancedFilter: activeFilterState.advancedFilter,
            showCompletedInline: activeFilterState.showCompletedInline,
            createdAt: now,
            updatedAt: now
        )

        savedHomeViewRepository.save(saved) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    self?.trackFeatureUsage(action: "home_filter_saved_view_created", metadata: ["name": trimmedName])
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: apply a previously saved filter state.
    public func applySavedView(id: UUID) {
        guard let saved = savedHomeViews.first(where: { $0.id == id }) else {
            return
        }

        focusEngineEnabled = true
        activeScope = .fromQuickView(saved.quickView)
        var restoredState = saved.asFilterState(pinnedProjectIDs: activeFilterState.pinnedProjectIDs)
        restoredState.projectGroupingMode = activeFilterState.projectGroupingMode
        restoredState.customProjectOrderIDs = activeFilterState.customProjectOrderIDs
        activeFilterState = restoredState
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_saved_view_used", metadata: ["id": id.uuidString])
        applyFocusFilters(trackAnalytics: false)
    }

    /// Focus Engine: delete a saved filter view.
    public func deleteSavedView(id: UUID) {
        savedHomeViewRepository.delete(id: id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                    if self?.activeFilterState.selectedSavedViewID == id {
                        self?.activeFilterState.selectedSavedViewID = nil
                        self?.persistLastFilterState()
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: reset all filters to default state.
    public func resetAllFilters() {
        focusEngineEnabled = true
        activeScope = .today
        selectedDate = Date()
        activeFilterState = .default
        persistLastFilterState()
        trackFeatureUsage(action: "home_filter_reset", metadata: [:])
        applyFocusFilters(trackAnalytics: true)
    }

    /// Focus Engine: load saved views from persistence.
    public func loadSavedViews() {
        savedHomeViewRepository.fetchAll { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let views):
                    self?.savedHomeViews = views.sorted { $0.updatedAt > $1.updatedAt }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Focus Engine: restore last persisted filter state.
    public func restoreLastFilterState() {
        guard let data = userDefaults.data(forKey: Self.lastFilterStateKey) else {
            activeFilterState = .default
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode(HomeFilterState.self, from: data)
            guard decoded.version == HomeFilterState.schemaVersion else {
                activeFilterState = .default
                return
            }
            activeFilterState = sanitizeFilterState(decoded, availableProjects: projects)
        } catch {
            activeFilterState = .default
        }
    }

    /// Load all projects.
    public func loadProjects() {
        loadProjects(generation: nextReloadGeneration())
    }

    /// Executes loadProjects.
    private func loadProjects(generation: Int) {
        let interval = TaskerPerformanceTrace.begin("HomeLoadProjects")
        useCaseCoordinator.manageProjects.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=projects generation=\(generation)")
                    return
                }
                switch result {
                case .success(let projectsWithStats):
                    let loadedProjects = projectsWithStats.map { $0.project }
                    self.assignIfChanged(\.projects, loadedProjects)
                    self.seedPinnedProjectsIfNeeded(from: loadedProjects)
                    self.normalizeCustomProjectOrderIfNeeded(from: loadedProjects)

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadLifeAreas.
    private func loadLifeAreas(generation: Int) {
        useCaseCoordinator.manageLifeAreas.list { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else { return }

                switch result {
                case .success(let loadedLifeAreas):
                    let sortedLifeAreas = loadedLifeAreas
                        .filter { !$0.isArchived }
                        .sorted {
                            if $0.sortOrder != $1.sortOrder {
                                return $0.sortOrder < $1.sortOrder
                            }
                            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }
                    self.assignIfChanged(\.lifeAreas, sortedLifeAreas)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTags.
    private func loadTags(generation: Int) {
        let interval = TaskerPerformanceTrace.begin("HomeLoadTags")
        useCaseCoordinator.manageTags.list { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=tags generation=\(generation)")
                    return
                }

                switch result {
                case .success(let loadedTags):
                    let sortedTags = loadedTags.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    self.assignIfChanged(\.tags, sortedTags)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Clears task-related cache entries to force fresh reads.
    public func invalidateTaskCaches() {
        useCaseCoordinator.cacheService?.clearAll()
        useCaseCoordinator.calculateAnalytics.invalidateCaches()
        homeFilteredTasksUseCase.invalidateCaches()
        dataRevision.advance()
        TaskerPerformanceTrace.event("HomeDataInvalidated")
        logDebug("HOME_CACHE invalidated scope=all")
    }

    /// Executes completionOverride.
    func completionOverride(for taskID: UUID) -> Bool? {
        completionOverrides[taskID]
    }

    /// Load upcoming tasks for legacy upcoming mode.
    public func loadUpcomingTasks() {
        focusEngineEnabled = true
        setQuickView(.upcoming)
    }

    /// Load completed tasks for legacy history mode.
    public func loadCompletedTasks() {
        focusEngineEnabled = true
        setQuickView(.done)
    }

    /// Complete morning routine.
    public func completeMorningRoutine(completion: ((Result<MorningRoutineResult, Error>) -> Void)? = nil) {
        useCaseCoordinator.completeMorningRoutine { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let routineResult):
                    self?.dailyScore += routineResult.totalScore
                    self?.refreshProgressState()
                    self?.loadTodayTasks()
                    completion?(.success(routineResult))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Reschedule all overdue tasks.
    public func rescheduleOverdueTasks(completion: ((Result<RescheduleAllResult, Error>) -> Void)? = nil) {
        useCaseCoordinator.rescheduleAllOverdueTasks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rescheduleResult):
                    self?.loadTodayTasks()
                    completion?(.success(rescheduleResult))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }

    public func evaFocusInsight(for taskID: UUID) -> EvaFocusTaskInsight? {
        evaHomeInsights?.focus.taskInsights.first(where: { $0.taskID == taskID })
    }

    public func setEvaFocusWhyPresented(_ value: Bool) {
        evaFocusWhySheetPresented = value
        if value == false {
            assignIfChanged(\.focusWhyShuffleCandidates, [])
        }
    }

    public func setEvaTriagePresented(_ value: Bool) {
        evaTriageSheetPresented = value
    }

    public func setEvaRescuePresented(_ value: Bool) {
        evaRescueSheetPresented = value
    }

    public func openFocusWhy() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        refreshFocusWhyShuffleCandidates()
        evaFocusWhySheetPresented = true
        trackHomeInteraction(action: "focus_now_why_open", metadata: [:])
    }

    @discardableResult
    public func refreshFocusWhyShuffleCandidates() -> [TaskDefinition] {
        let candidates = computeFocusWhyShuffleCandidates()
        assignIfChanged(\.focusWhyShuffleCandidates, candidates)
        return candidates
    }

    private func refreshFocusWhyCandidatesIfPresented() {
        guard evaFocusWhySheetPresented else { return }
        assignIfChanged(\.focusWhyShuffleCandidates, computeFocusWhyShuffleCandidates())
    }

    public func shuffleFocusNow() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        guard activeScope.quickView == .today else { return }
        guard activeScope.quickView != .done else { return }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.count > 1 else { return }
        let pinnedSet = Set(pinnedFocusTaskIDs)
        let candidates = openTasks.filter { !pinnedSet.contains($0.id) }
        guard candidates.isEmpty == false else { return }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        let autoFill = Array(ranked.prefix(max(0, Self.maxPinnedFocusTasks - pinnedFocusTaskIDs.count)))
        let pinned = pinnedFocusTaskIDs.compactMap { id in openTasks.first(where: { $0.id == id }) }
        let newSelection = Array((pinned + autoFill).prefix(Self.maxPinnedFocusTasks))
        guard newSelection.isEmpty == false else { return }

        updateFocusSelection(newSelection)
        for task in newSelection {
            recentShuffledFocusTaskIDs.append(task.id)
        }
        recentShuffledFocusTaskIDs = Array(recentShuffledFocusTaskIDs.suffix(Self.maxShuffleHistorySize))
        persistRecentShuffleTaskIDs()
        refreshEvaInsights()
        trackHomeInteraction(action: "focus_now_shuffle_tap", metadata: [
            "result_count": newSelection.count
        ])
    }

    public func startTriage() {
        startTriage(scope: .visible)
    }

    public func startFocusSession(
        taskID: UUID?,
        targetDurationSeconds: Int = 25 * 60,
        completion: @escaping (Result<FocusSessionDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.startSession(
            taskID: taskID,
            targetDurationSeconds: targetDurationSeconds,
            completion: { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        )
    }

    public func endFocusSession(
        sessionID: UUID,
        completion: @escaping (Result<FocusSessionResult, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.endSession(sessionID: sessionID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let focusResult):
                    if focusResult.xpResult?.awardedXP ?? 0 > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "focus_session_end")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(focusResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func fetchActiveFocusSession(
        completion: @escaping (Result<FocusSessionDefinition?, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.fetchActiveSession { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    public func completeDailyReflection(
        completion: @escaping (Result<XPEventResult, Error>) -> Void
    ) {
        useCaseCoordinator.markDailyReflection.execute { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let xpResult):
                    if xpResult.awardedXP > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "daily_reflection_complete")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(xpResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func isDailyReflectionCompletedToday() -> Bool {
        useCaseCoordinator.markDailyReflection.isCompletedToday()
    }

    public func launchInsights(_ request: InsightsLaunchRequest = .default) {
        let resolved = InsightsLaunchRequest(
            targetTab: request.targetTab,
            highlightedAchievementKey: request.highlightedAchievementKey
        )
        insightsLaunchRequest = resolved
        insightsLaunchToken = resolved.token
        trackHomeInteraction(
            action: "insights_launch_requested",
            metadata: [
                "target_tab": resolved.targetTab.rawValue.lowercased(),
                "has_highlighted_achievement": resolved.highlightedAchievementKey == nil ? "false" : "true"
            ]
        )
    }

    public func dispatchCelebration(_ result: XPEventResult?) {
        guard let result else { return }
        lastXPResult = result
    }

    public func makeInsightsViewModel() -> InsightsViewModel {
        retainedInsightsViewModel
    }

    func makeHomeSearchViewModel() -> LGSearchViewModel {
        retainedHomeSearchViewModel
    }

    public func startTriage(scope: EvaTriageScope) {
        guard V2FeatureFlags.evaTriageEnabled else { return }
        evaTriageSheetPresented = true
        trackHomeInteraction(action: "triage_open", metadata: [
            "scope": scope.rawValue
        ])
        refreshTriageQueue(scope: scope)
    }

    public func refreshTriageQueue(scope: EvaTriageScope) {
        refreshTriageQueue(scope: scope, completion: nil)
    }

    public func refreshTriageQueue(
        scope: EvaTriageScope,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        guard V2FeatureFlags.evaTriageEnabled else {
            completion?(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Eva triage disabled"]
            )))
            return
        }

        evaTriageScope = scope
        evaTriageQueueLoading = true
        evaTriageQueueErrorMessage = nil

        let visibleOpenTasks = focusOpenTasksForCurrentState()
        let visibleInbox = visibleOpenTasks.filter {
            !$0.isComplete && $0.projectID == ProjectConstants.inboxProjectID
        }

        switch scope {
        case .visible:
            evaTriageQueue = getInboxTriageQueueUseCase.execute(
                inboxTasks: visibleInbox,
                allTasks: visibleOpenTasks,
                projects: projects,
                maxItems: 20
            )
            evaTriageQueueLoading = false
            trackHomeInteraction(action: "triage_scope_changed", metadata: [
                "scope": scope.rawValue,
                "queue_count": evaTriageQueue.count
            ])
            completion?(.success(()))

        case .allInbox:
            useCaseCoordinator.getTasks.getTasksForProject(ProjectConstants.inboxProjectID, includeCompleted: false) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let inboxResult):
                        let inboxOpen = inboxResult.tasks.filter { !$0.isComplete }
                        let allTasks = self.uniqueTasks(visibleOpenTasks + inboxOpen)
                        self.evaTriageQueue = self.getInboxTriageQueueUseCase.execute(
                            inboxTasks: inboxOpen,
                            allTasks: allTasks,
                            projects: self.projects,
                            maxItems: 20
                        )
                        self.evaTriageQueueErrorMessage = nil
                        self.evaTriageQueueLoading = false
                        self.trackHomeInteraction(action: "triage_scope_changed", metadata: [
                            "scope": scope.rawValue,
                            "queue_count": self.evaTriageQueue.count
                        ])
                        completion?(.success(()))
                    case .failure(let error):
                        self.evaTriageQueue = self.getInboxTriageQueueUseCase.execute(
                            inboxTasks: visibleInbox,
                            allTasks: visibleOpenTasks,
                            projects: self.projects,
                            maxItems: 20
                        )
                        self.evaTriageQueueErrorMessage = "Couldn’t load backlog inbox. Showing visible tasks only."
                        self.evaTriageQueueLoading = false
                        self.trackHomeInteraction(action: "triage_error", metadata: [
                            "scope": scope.rawValue,
                            "error": error.localizedDescription
                        ])
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    public func openRescue() {
        guard V2FeatureFlags.evaRescueEnabled else { return }
        let referenceDate = selectedDate
        evaRescueSheetPresented = true
        useCaseCoordinator.getTasks.getOverdueTasks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                let tasks: [TaskDefinition]
                switch result {
                case .success(let overdue):
                    tasks = overdue
                case .failure:
                    tasks = self.overdueTasks
                }
                let rescueEligibleTasks = tasks.filter {
                    !($0.isComplete) && self.isRescueEligibleTask($0, on: referenceDate)
                }
                self.evaRescuePlan = self.getOverdueRescuePlanUseCase.execute(
                    overdueTasks: rescueEligibleTasks,
                    now: referenceDate
                )
                self.trackHomeInteraction(action: "rescue_open", metadata: [
                    "scope": "two_week_overdue",
                    "overdue_count": rescueEligibleTasks.count
                ])
            }
        }
    }

    public func removeTriageQueueItem(taskID: UUID) {
        evaTriageQueue.removeAll { $0.task.id == taskID }
    }

    public func applyTriageDecision(
        for item: EvaTriageQueueItem,
        decision: EvaTriageDecision,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let suggestionThreshold = 0.45
        var request = UpdateTaskDefinitionRequest(id: item.task.id)
        var mutated = false

        if decision.useSuggestedProject,
           item.suggestions.projectConfidence >= suggestionThreshold,
           let projectID = item.suggestions.projectID,
           projectID != item.task.projectID {
            request.projectID = projectID
            mutated = true
        } else if !decision.useSuggestedProject,
                  let selectedProjectID = decision.selectedProjectID,
                  selectedProjectID != item.task.projectID {
            request.projectID = selectedProjectID
            mutated = true
        }

        if let deferPreset = decision.deferPreset {
            let deferDate = deferPreset.resolveDueDate()
            if item.task.dueDate != deferDate {
                request.dueDate = deferDate
                request.clearDueDate = false
                mutated = true
            }
        } else if decision.useSuggestedDue,
                  item.suggestions.dueConfidence >= suggestionThreshold {
            let dueDate = dueDate(for: item.suggestions.dueBucket)
            switch item.suggestions.dueBucket {
            case .someday:
                if item.task.dueDate != nil {
                    request.clearDueDate = true
                    mutated = true
                }
            case .none:
                break
            default:
                if item.task.dueDate != dueDate {
                    request.dueDate = dueDate
                    mutated = true
                }
            }
        } else if !decision.useSuggestedDue {
            if decision.clearDueDate {
                if item.task.dueDate != nil {
                    request.clearDueDate = true
                    mutated = true
                }
            } else if let selectedDueDate = decision.selectedDueDate,
                      item.task.dueDate != selectedDueDate {
                request.dueDate = selectedDueDate
                mutated = true
            }
        }

        if decision.useSuggestedDuration,
           item.suggestions.durationConfidence >= suggestionThreshold,
           let suggestedDuration = item.suggestions.durationSeconds,
           item.task.estimatedDuration != suggestedDuration {
            request.estimatedDuration = suggestedDuration
            mutated = true
        } else if !decision.useSuggestedDuration {
            if decision.clearDuration {
                if item.task.estimatedDuration != nil {
                    request.clearEstimatedDuration = true
                    mutated = true
                }
            } else if let selectedDuration = decision.selectedDurationSeconds,
                      item.task.estimatedDuration != selectedDuration {
                request.estimatedDuration = selectedDuration
                mutated = true
            }
        }

        guard mutated else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Select at least one change or defer option to continue."]
            )))
            return
        }

        updateTask(taskID: item.task.id, request: request) { [weak self] result in
            guard let self else {
                completion(result)
                return
            }
            switch result {
            case .success(let updatedTask):
                self.removeTriageQueueItem(taskID: updatedTask.id)
                self.trackHomeInteraction(action: "triage_apply_next", metadata: [
                    "task_id": updatedTask.id.uuidString,
                    "defer_preset": decision.deferPreset?.rawValue ?? "none",
                    "used_suggested_project": decision.useSuggestedProject,
                    "used_suggested_due": decision.useSuggestedDue,
                    "used_suggested_duration": decision.useSuggestedDuration
                ])
                completion(.success(updatedTask))
            case .failure(let error):
                self.trackHomeInteraction(action: "triage_error", metadata: [
                    "task_id": item.task.id.uuidString,
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func applyTriageSuggestion(
        for item: EvaTriageQueueItem,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        let decision = EvaTriageDecision(
            selectedProjectID: nil,
            useSuggestedProject: item.suggestions.projectID != nil,
            selectedDueDate: nil,
            clearDueDate: false,
            useSuggestedDue: item.suggestions.dueBucket != nil,
            selectedDurationSeconds: nil,
            clearDuration: false,
            useSuggestedDuration: item.suggestions.durationSeconds != nil,
            stateHint: item.suggestions.stateHint,
            useSuggestedState: item.suggestions.stateHint != nil,
            deferPreset: nil
        )
        applyTriageDecision(for: item, decision: decision, completion: completion)
    }

    public func applyEvaBatchPlan(
        source: EvaBatchSource,
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard mutations.isEmpty == false else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "No Eva mutations to apply"]
            )))
            return
        }
        let openTasks = focusOpenTasksForCurrentState() + completedTasks + doneTimelineTasks + evaTriageQueue.map(\.task)
        let tasksByID = openTasks.reduce(into: [UUID: TaskDefinition]()) { partialResult, task in
            partialResult[task.id] = task
        }
        let proposal = buildEvaBatchProposalUseCase.execute(
            source: source,
            tasksByID: tasksByID,
            mutations: mutations
        )

        useCaseCoordinator.assistantActionPipeline.propose(threadID: proposal.threadID, envelope: proposal.envelope) { [weak self] proposeResult in
            switch proposeResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .success(let proposedRun):
                self?.useCaseCoordinator.assistantActionPipeline.confirm(runID: proposedRun.id) { confirmResult in
                    switch confirmResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    case .success:
                        self?.useCaseCoordinator.assistantActionPipeline.applyConfirmedRun(id: proposedRun.id) { applyResult in
                            DispatchQueue.main.async {
                                switch applyResult {
                                case .success(let run):
                                    self?.evaLastBatchRunID = run.id
                                    self?.enqueueReload(
                                        source: "eva_batch_apply",
                                        reason: .bulkChanged,
                                        invalidateCaches: true,
                                        includeAnalytics: false,
                                        repostEvent: true
                                    )
                                    self?.trackHomeInteraction(action: source == .triage ? "triage_bulk_apply" : "rescue_apply_confirmed", metadata: [
                                        "mutation_count": mutations.count
                                    ])
                                    completion(.success(run))
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func applyAllTriageSuggestions(
        confidenceThreshold: Double = 0.75,
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        let mutations = evaTriageQueue.compactMap { item -> EvaBatchMutationInstruction? in
            var mutation = EvaBatchMutationInstruction(taskID: item.task.id)
            var hasChange = false

            if item.suggestions.projectConfidence >= confidenceThreshold,
               let projectID = item.suggestions.projectID,
               projectID != item.task.projectID {
                mutation.projectID = projectID
                hasChange = true
            }
            if item.suggestions.dueConfidence >= confidenceThreshold {
                switch item.suggestions.dueBucket {
                case .someday:
                    if item.task.dueDate != nil {
                        mutation.clearDueDate = true
                        hasChange = true
                    }
                case .none:
                    break
                default:
                    let suggestedDate = dueDate(for: item.suggestions.dueBucket)
                    if item.task.dueDate != suggestedDate {
                        mutation.dueDate = suggestedDate
                        hasChange = true
                    }
                }
            }
            if item.suggestions.durationConfidence >= confidenceThreshold,
               let duration = item.suggestions.durationSeconds,
               item.task.estimatedDuration != duration {
                mutation.estimatedDuration = duration
                hasChange = true
            }
            return hasChange ? mutation : nil
        }

        applyEvaBatchPlan(source: .triage, mutations: mutations) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.evaTriageQueue.removeAll()
                }
                completion(result)
            }
        }
    }

    public func applyRescuePlan(
        mutations: [EvaBatchMutationInstruction],
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_apply_tap", metadata: [
            "mutation_count": mutations.count
        ])
        applyEvaBatchPlan(source: .rescue, mutations: mutations) { [weak self] result in
            switch result {
            case .success(let run):
                self?.trackHomeInteraction(action: "rescue_apply_success", metadata: [
                    "run_id": run.id.uuidString,
                    "mutation_count": mutations.count
                ])
                completion(.success(run))
            case .failure(let error):
                self?.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func undoEvaBatchPlan(
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        guard let runID = evaLastBatchRunID else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No Eva batch run available to undo"]
            )))
            return
        }
        useCaseCoordinator.assistantActionPipeline.undoAppliedRun(id: runID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let run):
                    self?.enqueueReload(
                        source: "eva_batch_undo",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    self?.trackHomeInteraction(action: "rescue_undo", metadata: [
                        "run_id": run.id.uuidString
                    ])
                    completion(.success(run))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func undoRescueRun(
        completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_undo_tap", metadata: [:])
        undoEvaBatchPlan { [weak self] result in
            switch result {
            case .success(let run):
                self?.trackHomeInteraction(action: "rescue_undo_success", metadata: [
                    "run_id": run.id.uuidString
                ])
                completion(.success(run))
            case .failure(let error):
                self?.trackHomeInteraction(action: "rescue_undo_error", metadata: [
                    "error": error.localizedDescription
                ])
                completion(.failure(error))
            }
        }
    }

    public func createSplitChildren(
        parentTaskID: UUID,
        draft: EvaSplitDraft,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        guard let parent = currentTaskSnapshot(for: parentTaskID) ?? focusOpenTasksForCurrentState().first(where: { $0.id == parentTaskID }) ?? overdueTasks.first(where: { $0.id == parentTaskID }) else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Parent task no longer exists."]
            )))
            return
        }

        let childTitles = draft.children
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard childTitles.count >= 2 else {
            completion(.failure(NSError(
                domain: "HomeViewModel",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "Add at least two subtasks to split."]
            )))
            return
        }

        let dueDate = draft.childDuePreset?.resolveDueDate()
        let group = DispatchGroup()
        let lock = NSLock()
        var created: [TaskDefinition] = []
        var firstError: Error?

        trackHomeInteraction(action: "rescue_split_open", metadata: [
            "parent_task_id": parentTaskID.uuidString
        ])

        for title in childTitles {
            group.enter()
            let request = CreateTaskDefinitionRequest(
                title: title,
                details: nil,
                projectID: parent.projectID,
                projectName: parent.projectName,
                dueDate: dueDate,
                parentTaskID: parent.id,
                priority: parent.priority,
                type: parent.type,
                energy: parent.energy,
                category: parent.category,
                context: parent.context,
                isEveningTask: parent.isEveningTask,
                estimatedDuration: nil
            )

            useCaseCoordinator.createTaskDefinition.execute(request: request) { result in
                lock.lock()
                defer { lock.unlock() }
                switch result {
                case .success(let task):
                    created.append(task)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let firstError {
                self.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "split_parent_task_id": parentTaskID.uuidString,
                    "error": firstError.localizedDescription
                ])
                completion(.failure(firstError))
                return
            }
            self.enqueueReload(
                source: "rescue_split_created",
                reason: .updated,
                invalidateCaches: true,
                includeAnalytics: false,
                repostEvent: true
            )
            self.trackHomeInteraction(action: "rescue_split_created", metadata: [
                "parent_task_id": parentTaskID.uuidString,
                "child_count": created.count
            ])
            completion(.success(created))
        }
    }

    public func undoCreatedSplitChildren(
        childTaskIDs: [UUID],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard childTaskIDs.isEmpty == false else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for taskID in childTaskIDs {
            group.enter()
            useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: .single) { result in
                lock.lock()
                if case .failure(let error) = result, firstError == nil {
                    firstError = error
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let firstError {
                completion(.failure(firstError))
                return
            }
            self.enqueueReload(
                source: "rescue_split_undo",
                reason: .updated,
                invalidateCaches: true,
                includeAnalytics: false,
                repostEvent: true
            )
            self.trackHomeInteraction(action: "rescue_split_undo", metadata: [
                "child_count": childTaskIDs.count
            ])
            completion(.success(()))
        }
    }

    // MARK: - Private Methods

    /// Executes setupBindings.
    private func setupBindings() {
        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.enqueueReload(
                    source: "notification_task_created",
                    reason: .created,
                    invalidateCaches: true,
                    includeAnalytics: false,
                    repostEvent: true
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.enqueueReload(
                    source: "notification_task_updated",
                    reason: .updated,
                    invalidateCaches: true,
                    includeAnalytics: false,
                    repostEvent: true
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.enqueueReload(
                    source: "notification_task_deleted",
                    reason: .deleted,
                    invalidateCaches: true,
                    includeAnalytics: false,
                    repostEvent: true
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(completionNotificationDebounceMS), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if let suppressUntil = self.suppressCompletionReloadUntil, Date() <= suppressUntil {
                    logDebug("HOME_ROW_STATE vm.notification_suppressed source=TaskCompletionChanged")
                    return
                }
                self.enqueueReload(
                    source: "notification_task_completion_changed",
                    reason: .bulkChanged,
                    invalidateCaches: true,
                    includeAnalytics: true,
                    repostEvent: true
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .homeTaskMutation)
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(mutationNotificationDebounceMS), scheduler: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }

                let source = notification.userInfo?["source"] as? String
                guard source != Self.mutationNotificationSource else { return }

                let reasonRaw = notification.userInfo?["reason"] as? String
                let reason = reasonRaw.flatMap(HomeTaskMutationEvent.init(rawValue:)) ?? .updated
                self.handleExternalMutation(reason: reason, repostEvent: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .gamificationLedgerDidMutate)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let mutation = notification.gamificationLedgerMutation else { return }
                self?.handleGamificationLedgerMutation(mutation)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .homeHabitMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.enqueueReload(
                    source: "notification_habit_mutation",
                    reason: .updated,
                    invalidateCaches: true,
                    includeAnalytics: true,
                    repostEvent: false
                )
            }
            .store(in: &cancellables)
    }

    /// Executes setTaskCompletion.
    private func setTaskCompletion(
        taskID: UUID,
        to requestedCompletion: Bool,
        taskSnapshot: TaskDefinition?,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        logDebug(
            "HOME_ROW_STATE vm.toggle_input id=\(taskID.uuidString) " +
            "isComplete=\(String(describing: taskSnapshot?.isComplete)) requested=\(requestedCompletion)"
        )
        useCaseCoordinator.completeTaskDefinition.setCompletion(
            taskID: taskID,
            to: requestedCompletion
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTask):
                    self?.completionOverrides[updatedTask.id] = updatedTask.isComplete
                    self?.suppressCompletionReloadUntil = Date().addingTimeInterval(self?.completionReloadSuppressionSeconds ?? 0.35)
                    self?.applyCompletionResultLocally(updatedTask)
                    let stateMatchesRequest = updatedTask.isComplete == requestedCompletion
                    if stateMatchesRequest {
                        if V2FeatureFlags.gamificationV2Enabled {
                            // v2: XP state is driven by post-commit ledger mutation notifications.
                        } else {
                            if updatedTask.isComplete {
                                self?.dailyScore += updatedTask.priority.scorePoints
                            } else {
                                self?.dailyScore = max(0, (self?.dailyScore ?? 0) - updatedTask.priority.scorePoints)
                            }
                        }
                        self?.refreshProgressState()
                    } else {
                        logDebug(
                            "HOME_ROW_STATE vm.toggle_mismatch id=\(updatedTask.id.uuidString) " +
                            "requested=\(requestedCompletion) result=\(updatedTask.isComplete) " +
                            "forcing_analytics_reload=true"
                        )
                    }
                    if updatedTask.isComplete {
                        self?.scheduleLedgerMutationWatchdog(trigger: "task_completion")
                    }
                    self?.enqueueReload(
                        source: "set_task_completion",
                        reason: updatedTask.isComplete ? .completed : .reopened,
                        taskID: updatedTask.id,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: false
                    )
                    self?.scheduleDeferredAnalyticsRefresh(
                        reason: updatedTask.isComplete ? "task_completion" : "task_reopen",
                        includeGamificationRefresh: false
                    )
                    self?.trackFirstCompletionLatencyIfNeeded()
                    completion(.success(updatedTask))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    /// Executes currentTaskSnapshot.
    private func currentTaskSnapshot(for id: UUID) -> TaskDefinition? {
        let candidates = morningTasks + eveningTasks + overdueTasks + dailyCompletedTasks + upcomingTasks + completedTasks + doneTimelineTasks
        return candidates.first(where: { $0.id == id })
    }

    /// Executes mutationReason.
    private func mutationReason(for request: UpdateTaskDefinitionRequest) -> HomeTaskMutationEvent {
        HomeTaskMutationReasonResolver.reason(for: request)
    }

    /// Executes loadInitialData.
    private func loadInitialData() {
        let interval = TaskerPerformanceTrace.begin("HomeInitialLoad")
        defer { TaskerPerformanceTrace.end(interval) }

        homeOpenedAt = Date()
        didTrackFirstCompletionLatency = false

        restoreLastFilterState()
        restorePinnedFocusTaskIDs()
        restoreRecentShuffleTaskIDs()
        activeScope = .fromQuickView(activeFilterState.quickView)
        if case .today = activeScope {
            selectedDate = Date()
        }
        loadSavedViews()
        let generation = nextReloadGeneration()
        loadProjects(generation: generation)
        loadLifeAreas(generation: generation)
        loadTags(generation: generation)
        applyFocusFilters(trackAnalytics: false, generation: generation) { [weak self] in
            self?.scheduleDeferredAnalyticsRefresh(
                reason: "initial_load",
                includeGamificationRefresh: true
            )
        }
    }

    /// Executes loadDailyAnalytics.
    private func loadDailyAnalytics(
        includeGamificationRefresh: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        pendingAnalyticsIncludeGamificationRefresh = pendingAnalyticsIncludeGamificationRefresh || includeGamificationRefresh
        if let completion {
            pendingAnalyticsCompletions.append(completion)
        }
        pendingAnalyticsWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let shouldIncludeGamificationRefresh = self.pendingAnalyticsIncludeGamificationRefresh
            let completions = self.pendingAnalyticsCompletions
            self.pendingAnalyticsIncludeGamificationRefresh = false
            self.pendingAnalyticsCompletions = []
            self.pendingAnalyticsWorkItem = nil
            self.performDailyAnalyticsRefresh(
                includeGamificationRefresh: shouldIncludeGamificationRefresh,
                completions: completions
            )
        }
        pendingAnalyticsWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(analyticsDebounceMS),
            execute: workItem
        )
    }

    private func scheduleDeferredAnalyticsRefresh(
        reason: String,
        includeGamificationRefresh: Bool,
        delayMilliseconds: Int = 450
    ) {
        pendingDeferredAnalyticsRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let interval = TaskerPerformanceTrace.begin("HomeDeferredAnalyticsRefresh")
            self.loadDailyAnalytics(includeGamificationRefresh: includeGamificationRefresh) {
                TaskerPerformanceTrace.end(interval)
                logWarning(
                    event: "home_deferred_analytics_refresh",
                    message: "Deferred analytics refresh completed",
                    fields: [
                        "reason": reason,
                        "include_gamification_refresh": includeGamificationRefresh ? "true" : "false"
                    ]
                )
            }
        }
        pendingDeferredAnalyticsRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(delayMilliseconds),
            execute: workItem
        )
    }

    private func performDailyAnalyticsRefresh(
        includeGamificationRefresh: Bool,
        completions: [() -> Void]
    ) {
        let generation = nextAnalyticsGeneration()
        let completionGroup = DispatchGroup()
        if V2FeatureFlags.gamificationV2Enabled {
            guard includeGamificationRefresh else {
                completionGroup.enter()
                useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
                    for: Date(),
                    habitSignals: self.currentHabitSignals
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        defer { completionGroup.leave() }
                        guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    }
                }
                completionGroup.notify(queue: .main) {
                    completions.forEach { $0() }
                }
                return
            }
            let engine = useCaseCoordinator.gamificationEngine

            completionGroup.enter()
            engine.fetchTodayXP { [weak self] result in
                DispatchQueue.main.async {
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let todayXP) = result {
                        self.dailyScore = todayXP
                        self.refreshProgressState()
                    }
                }
            }

            completionGroup.enter()
            engine.fetchCurrentProfile { [weak self] result in
                DispatchQueue.main.async {
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let profile) = result {
                        self.currentLevel = profile.level
                        self.totalXP = profile.xpTotal
                        self.nextLevelXP = profile.nextLevelXP
                        self.streak = profile.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        } else {
            completionGroup.enter()
            refreshDailyScoreFromCompletedTasksToday(generation: generation) {
                completionGroup.leave()
            }
        }

        completionGroup.enter()
        useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
            for: Date(),
            habitSignals: currentHabitSignals
        ) { [weak self] _ in
            DispatchQueue.main.async {
                defer { completionGroup.leave() }
                guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
            }
        }

        if !V2FeatureFlags.gamificationV2Enabled {
            completionGroup.enter()
            useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
                DispatchQueue.main.async {
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let streakInfo) = result {
                        self.streak = streakInfo.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        }

        completionGroup.notify(queue: .main) {
            completions.forEach { $0() }
        }
    }

    private func refreshDueTodayAgenda(
        openTaskRows: [TaskDefinition],
        generation: Int
    ) {
        let group = DispatchGroup()
        var agendaHabitRows: [HomeHabitRow] = []
        var trackingHabitRows: [HomeHabitRow] = []
        var historyByHabitID: [UUID: [HabitDayMark]] = [:]

        group.enter()
        buildHabitHomeProjectionUseCase.execute(date: selectedDate) { result in
            agendaHabitRows = (try? result.get()) ?? []
            group.leave()
        }

        group.enter()
        useCaseCoordinator.getHabitLibrary.execute(includeArchived: false) { [weak self] result in
            guard let self else {
                group.leave()
                return
            }
            switch result {
            case .failure:
                group.leave()
            case .success(let libraryRows):
                guard libraryRows.isEmpty == false else {
                    trackingHabitRows = self.trackingHomeRows(from: libraryRows, historyByHabitID: historyByHabitID, on: self.selectedDate)
                    group.leave()
                    return
                }
                group.enter()
                self.useCaseCoordinator.getHabitHistory.execute(
                    habitIDs: libraryRows.map(\.habitID),
                    endingOn: self.selectedDate,
                    dayCount: 1
                ) { historyResult in
                    if case .success(let windows) = historyResult {
                        historyByHabitID = windows.reduce(into: [:]) { partialResult, window in
                            partialResult[window.habitID] = window.marks
                        }
                    }
                    trackingHabitRows = self.trackingHomeRows(
                        from: libraryRows,
                        historyByHabitID: historyByHabitID,
                        on: self.selectedDate
                    )
                    group.leave()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self, self.isCurrentReloadGeneration(generation) else { return }

            let allHabitRows = self.mergeHabitRows(agenda: agendaHabitRows, tracking: trackingHabitRows)
            self.currentHabitSignals = self.habitSignals(from: allHabitRows)
            let rescueEligibleTaskIDs = Set(
                openTaskRows
                    .filter { self.isRescueEligibleTask($0, on: self.selectedDate) }
                    .map(\.id)
            )
            let agendaTaskRows = openTaskRows.filter { !rescueEligibleTaskIDs.contains($0.id) }
            let focusTaskRows = openTaskRows.filter { !rescueEligibleTaskIDs.contains($0.id) }

            let agenda = self.buildHomeAgendaUseCase.execute(
                date: self.selectedDate,
                taskRows: agendaTaskRows,
                habitRows: agendaHabitRows
            )

            self.assignIfChanged(\.dueTodayRows, agenda.rows)
            self.assignIfChanged(\.dueTodaySection, nil)
            let todaySections = HomeMixedSectionBuilder.buildTodaySections(
                taskRows: agendaTaskRows,
                habitRows: allHabitRows.filter(self.includeHabitInAgenda(_:)),
                projects: self.projects,
                lifeAreas: self.lifeAreas
            )
            self.assignIfChanged(\.todaySections, todaySections)

            let focusRows = self.composeFocusRows(taskRows: focusTaskRows, habitRows: allHabitRows)
            self.assignIfChanged(\.focusRows, focusRows)
            self.assignIfChanged(
                \.focusNowSectionState,
                FocusNowSectionState(
                    rows: focusRows,
                    pinnedTaskIDs: self.pinnedFocusTaskIDs
                )
            )
            self.assignIfChanged(
                \.todayAgendaSectionState,
                TodayAgendaSectionState(sections: todaySections)
            )
            self.assignIfChanged(
                \.rescueSectionState,
                self.buildRescueSectionState(
                    rescueEligibleTasks: openTaskRows.filter { rescueEligibleTaskIDs.contains($0.id) },
                    focusRows: focusRows
                )
            )
            self.assignIfChanged(
                \.quietTrackingSummaryState,
                QuietTrackingSummaryState(
                    stableRows: allHabitRows.filter(self.isStableQuietTrackingRow(_:))
                )
            )

            if Calendar.current.isDate(self.selectedDate, inSameDayAs: Date()) {
                self.loadDailyAnalytics(includeGamificationRefresh: false)
            }
        }
    }

    private func habitSignals(from rows: [HomeHabitRow]) -> [TaskerHabitSignal] {
        rows.map { row in
            TaskerHabitSignal(
                habitID: row.habitID,
                title: row.title,
                isPositive: row.kind == .positive,
                trackingModeRaw: row.trackingMode.rawValue,
                lifeAreaName: row.lifeAreaName,
                projectName: row.projectName,
                iconSymbolName: row.iconSymbolName,
                iconCategoryKey: nil,
                dueAt: row.dueAt,
                isDueToday: row.state == .due,
                isOverdue: row.state == .overdue,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                riskStateRaw: row.riskState.rawValue,
                outcomeRaw: habitOutcomeRaw(for: row.state),
                occurredAt: row.dueAt,
                keywords: [row.title, row.lifeAreaName, row.projectName].compactMap { $0 }
            )
        }
    }

    private func habitOutcomeRaw(for state: HomeHabitRowState) -> String? {
        switch state {
        case .completedToday:
            return "completed"
        case .lapsedToday:
            return "lapsed"
        case .skippedToday:
            return "skipped"
        case .overdue:
            return "missed"
        case .due, .tracking:
            return nil
        }
    }

    private func mergeHabitRows(
        agenda: [HomeHabitRow],
        tracking: [HomeHabitRow]
    ) -> [HomeHabitRow] {
        var merged: [String: HomeHabitRow] = [:]
        for row in agenda {
            merged[row.id] = row
        }
        for row in tracking where merged[row.id] == nil {
            merged[row.id] = row
        }
        return merged.values.sorted { lhs, rhs in
            if lhs.projectName != rhs.projectName {
                return (lhs.projectName ?? lhs.lifeAreaName).localizedCaseInsensitiveCompare(rhs.projectName ?? rhs.lifeAreaName) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func includeHabitInAgenda(_ row: HomeHabitRow) -> Bool {
        switch row.state {
        case .overdue:
            return true
        case .due:
            if row.kind == .positive {
                return true
            }
            return row.riskState != .stable
        case .tracking:
            return false
        case .completedToday, .lapsedToday, .skippedToday:
            return false
        }
    }

    private func isStableQuietTrackingRow(_ row: HomeHabitRow) -> Bool {
        row.trackingMode == .lapseOnly
            && row.state == .tracking
            && row.riskState == .stable
    }

    private func buildRescueSectionState(
        rescueEligibleTasks: [TaskDefinition],
        focusRows: [HomeTodayRow]
    ) -> RescueSectionState {
        guard activeScope.quickView == .today else {
            return RescueSectionState(rows: [])
        }

        let rows = rescueEligibleTasks
            .map(HomeTodayRow.task)
            .sorted(by: compareRescueRows(_:_:))
        let isExpandedByDefault = rows.count < 3 || focusRows.isEmpty
        return RescueSectionState(rows: rows, isExpandedByDefault: isExpandedByDefault)
    }

    private func isRescueEligibleTask(_ task: TaskDefinition, on referenceDate: Date) -> Bool {
        guard !task.isComplete, let dueDate = task.dueDate else {
            return false
        }

        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: referenceDate)
        let rescueCutoff = calendar.date(byAdding: .day, value: -14, to: anchorDay) ?? anchorDay
        return dueDate < rescueCutoff
    }

    private func compareRescueRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        let lhsPriority = rescuePriority(for: lhs)
        let rhsPriority = rescuePriority(for: rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func rescuePriority(for row: HomeTodayRow) -> Int {
        switch row {
        case .task(let task):
            return task.priority.scorePoints
        case .habit:
            return 0
        }
    }

    private func trackingHomeRows(
        from rows: [HabitLibraryRow],
        historyByHabitID: [UUID: [HabitDayMark]] = [:],
        on date: Date
    ) -> [HomeHabitRow] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return rows.compactMap { row in
            guard !row.isArchived, !row.isPaused, row.trackingMode == .lapseOnly else {
                return nil
            }

            let marks = historyByHabitID[row.habitID] ?? row.last14Days
            let todayMark = marks.first(where: { mark in
                let markDate = calendar.startOfDay(for: mark.date)
                return markDate >= startOfDay && markDate < endOfDay
            })
            let state: HomeHabitRowState
            switch todayMark?.state {
            case .failure:
                state = .lapsedToday
            default:
                state = .tracking
            }

            return HomeHabitRow(
                habitID: row.habitID,
                title: row.title,
                kind: row.kind,
                trackingMode: row.trackingMode,
                lifeAreaID: row.lifeAreaID,
                lifeAreaName: row.lifeAreaName,
                projectID: row.projectID,
                projectName: row.projectName,
                iconSymbolName: row.icon?.symbolName ?? "circle.dashed",
                dueAt: row.nextDueAt,
                state: state,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                last14Days: row.last14Days,
                riskState: todayMark?.state == .failure ? .broken : .stable
            )
        }
    }

    private func composeFocusRows(
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow]
    ) -> [HomeTodayRow] {
        let openTasks = taskRows.filter { !$0.isComplete }
        let openTaskByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        let pinnedTaskRows = pinnedFocusTaskIDs.compactMap { openTaskByID[$0] }.map(HomeTodayRow.task)
        let pinnedTaskIDs = Set(pinnedTaskRows.compactMap { row -> UUID? in
            if case .task(let task) = row { return task.id }
            return nil
        })

        let rankedTaskRows = rankedFocusTasks(
            from: openTasks.filter { !pinnedTaskIDs.contains($0.id) },
            relativeTo: activeScope
        ).map(HomeTodayRow.task)

        var results = pinnedTaskRows
        for row in rankedTaskRows where results.count < Self.maxPinnedFocusTasks && !results.contains(where: { $0.id == row.id }) {
            results.append(row)
        }

        if results.isEmpty {
            let highPriorityHabits = habitRows
                .filter { row in
                    row.trackingMode == .dailyCheckIn
                        && row.kind == .positive
                        && (row.state == .overdue || row.riskState == .atRisk)
                }
                .sorted { lhs, rhs in
                    if lhs.state != rhs.state {
                        return lhs.state == .overdue
                    }
                    let lhsDue = lhs.dueAt ?? .distantFuture
                    let rhsDue = rhs.dueAt ?? .distantFuture
                    return lhsDue < rhsDue
                }
                .map(HomeTodayRow.habit)

            for row in highPriorityHabits where results.count < 1 {
                results.append(row)
            }
        }

        return Array(results.prefix(Self.maxPinnedFocusTasks))
    }

    private func compareFocusRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
        let lhsRank = focusPriority(for: lhs)
        let rhsRank = focusPriority(for: rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        let lhsDue = lhs.dueDate ?? Date.distantFuture
        let rhsDue = rhs.dueDate ?? Date.distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func updateFocusSelection(_ tasks: [TaskDefinition]) {
        let limitedTasks = Array(tasks.prefix(Self.maxPinnedFocusTasks))
        assignIfChanged(\.focusTasks, limitedTasks)
        let rows = limitedTasks.map(HomeTodayRow.task)
        assignIfChanged(\.focusRows, rows)
        assignIfChanged(
            \.focusNowSectionState,
            FocusNowSectionState(rows: rows, pinnedTaskIDs: pinnedFocusTaskIDs)
        )

        refreshFocusWhyCandidatesIfPresented()
    }

    private func computeFocusWhyShuffleCandidates() -> [TaskDefinition] {
        guard V2FeatureFlags.evaFocusEnabled else { return [] }
        guard activeScope.quickView == .today else { return [] }

        let openTasks = focusOpenTasksForCurrentState()
        let currentFocusIDs = Set(focusTasks.filter { !$0.isComplete }.prefix(Self.maxPinnedFocusTasks).map(\.id))
        guard currentFocusIDs.isEmpty == false else { return [] }

        let candidates = openTasks.filter { !currentFocusIDs.contains($0.id) }
        guard candidates.isEmpty == false else { return [] }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        return Array(ranked.prefix(Self.maxPinnedFocusTasks))
    }

    private func focusPriority(for row: HomeTodayRow) -> Int {
        switch row {
        case .task(let task):
            if task.isOverdue { return 0 }
            if task.priority.isHighPriority, task.dueDate != nil { return 3 }
            return 5

        case .habit(let habit):
            if habit.state == .overdue { return 1 }
            if habit.kind == .negative, habit.riskState == .atRisk { return 2 }
            return 4
        }
    }

    private func resolveHabit(
        _ row: HomeHabitRow,
        action: HabitOccurrenceAction,
        source: String
    ) {
        resolveHabit(row, action: action, on: selectedDate, source: source)
    }

    private func resolveHabit(
        _ row: HomeHabitRow,
        action: HabitOccurrenceAction,
        on date: Date,
        source: String
    ) {
        useCaseCoordinator.resolveHabitOccurrence.execute(
            habitID: row.habitID,
            occurrenceID: row.occurrenceID,
            action: action,
            on: date
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success:
                    self.enqueueReload(
                        source: source,
                        reason: .updated,
                        invalidateCaches: false,
                        includeAnalytics: true,
                        repostEvent: false
                    )
                }
            }
        }
    }

    /// Fetches gamification state from the v2 XP ledger.
    private func refreshGamificationV2State(generation: Int? = nil) {
        let engine = useCaseCoordinator.gamificationEngine

        engine.fetchTodayXP { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if let generation, !self.isCurrentAnalyticsGeneration(generation) { return }
                if case .success(let todayXP) = result {
                    self.dailyScore = todayXP
                    self.refreshProgressState()
                }
            }
        }

        engine.fetchCurrentProfile { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if let generation, !self.isCurrentAnalyticsGeneration(generation) { return }
                if case .success(let profile) = result {
                    self.currentLevel = profile.level
                    self.totalXP = profile.xpTotal
                    self.nextLevelXP = profile.nextLevelXP
                    self.streak = profile.currentStreak
                    self.refreshProgressState()
                }
            }
        }
    }

    /// Executes refreshDailyScoreFromCompletedTasksToday.
    private func refreshDailyScoreFromCompletedTasksToday(
        referenceDate: Date = Date(),
        generation: Int? = nil,
        completion: (() -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion?()
            return
        }

        useCaseCoordinator.getTasks.searchTasks(query: "", in: .all) { [weak self] result in
            DispatchQueue.main.async {
                defer { completion?() }
                guard let self else { return }
                if let generation, !self.isCurrentAnalyticsGeneration(generation) { return }

                switch result {
                case .success(let tasks):
                    let completedTasks = tasks.filter(\.isComplete)
                    let totalScore = completedTasks.reduce(0) { partial, task in
                        let countsForToday: Bool
                        if let completionDate = task.dateCompleted {
                            countsForToday = completionDate >= startOfDay && completionDate < endOfDay
                        } else if let dueDate = task.dueDate {
                            // Legacy fallback for records missing dateCompleted.
                            countsForToday = dueDate >= startOfDay && dueDate < endOfDay
                        } else {
                            countsForToday = false
                        }

                        guard countsForToday else { return partial }
                        return partial + task.priority.scorePoints
                    }

                    self.dailyScore = totalScore
                    self.refreshProgressState()

                case .failure(let error):
                    logWarning(
                        event: "home_daily_score_refresh_failed",
                        message: "Failed to refresh completion-date XP score",
                        fields: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    /// Executes loadProjectTasks.
    private func loadProjectTasks(_ projectID: UUID) {
        loadProjectTasks(projectID, generation: nextReloadGeneration())
    }

    /// Executes loadProjectTasks.
    private func loadProjectTasks(_ projectID: UUID, generation: Int) {
        isLoading = true

        useCaseCoordinator.getTasks.getTasksForProject(projectID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=project generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let projectResult):
                    let projectTasks = projectResult.tasks
                    let overridden = self.applyCompletionOverrides(
                        openTasks: projectTasks.filter { !$0.isComplete },
                        doneTasks: projectTasks.filter(\.isComplete)
                    )
                    self.selectedProjectTasks = overridden.openTasks + overridden.doneTasks

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes reloadCurrentModeTasks.
    private func reloadCurrentModeTasks() {
        let generation = nextReloadGeneration()
        applyReloadScopes([.visibleTasks], generation: generation)
    }

    private func applyReloadScopes(
        _ scopes: Set<HomeReloadScope>,
        generation: Int,
        visibleTasksCompletion: (() -> Void)? = nil
    ) {
        if scopes.contains(.savedViews) {
            loadSavedViews()
        }
        if scopes.contains(.facets) {
            loadProjects(generation: generation)
            loadTags(generation: generation)
        }
        if scopes.contains(.visibleTasks) {
            applyFocusFilters(
                trackAnalytics: false,
                generation: generation,
                completion: visibleTasksCompletion
            )
        }
    }

    /// Executes upsertTag.
    private func upsertTag(_ tag: TagDefinition) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
        } else {
            tags.append(tag)
        }
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Executes applyFocusFilters.
    private func applyFocusFilters(trackAnalytics: Bool) {
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: nextReloadGeneration())
    }

    /// Executes applyFocusFilters.
    private func applyFocusFilters(
        trackAnalytics: Bool,
        generation: Int,
        completion: (() -> Void)? = nil
    ) {
        let interval = TaskerPerformanceTrace.begin("HomeApplyFilters")
        isLoading = true
        errorMessage = nil

        homeFilteredTasksUseCase.execute(
            state: activeFilterState,
            scope: activeScope,
            revision: dataRevision
        ) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                defer { completion?() }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=focus generation=\(generation)")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let filteredResult):
                    self.performHomeRenderStateBatch {
                        self.assignIfChanged(\.quickViewCounts, filteredResult.quickViewCounts)
                        self.assignIfChanged(\.pointsPotential, filteredResult.pointsPotential)
                        self.applyResultToSections(filteredResult, generation: generation)
                        self.refreshProgressState()

                        if trackAnalytics {
                            self.trackFeatureUsage(action: "home_filter_applied", metadata: [
                                "quick_view": self.activeScope.quickView.analyticsAction,
                                "scope": self.scopeAnalyticsAction(self.activeScope),
                                "project_count": self.activeFilterState.selectedProjectIDs.count,
                                "saved_view": self.activeFilterState.selectedSavedViewID?.uuidString ?? "",
                                "advanced_filter": self.activeFilterState.advancedFilter != nil
                            ])
                        }
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes applyResultToSections.
    private func applyResultToSections(_ result: HomeFilteredTasksResult, generation: Int) {
        let overriddenResult = applyCompletionOverrides(
            openTasks: result.openTasks,
            doneTasks: result.doneTimelineTasks
        )
        let openTasks = overriddenResult.openTasks
        let incomingDoneTasks = overriddenResult.doneTasks
        let shouldKeepCompletedInline = shouldKeepCompletedInline(for: activeScope)
        let doneTasks = mergedInlineDoneTasks(
            incomingDoneTasks: incomingDoneTasks,
            openTasks: openTasks,
            shouldKeepCompletedInline: shouldKeepCompletedInline
        )
        let visibleTasks = shouldKeepCompletedInline ? (openTasks + doneTasks) : openTasks

        logDebug(
            "HOME_ROW_STATE vm.apply_result quick=\(activeScope.quickView.rawValue) " +
            "open=\(summarizeRowState(openTasks)) done=\(summarizeRowState(doneTasks))"
        )

        if activeScope.quickView == .today {
            prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set(openTasks.map(\.id)))
        }
        assignIfChanged(\.focusTasks, composedFocusTasks(from: openTasks))
        assignIfChanged(\.focusRows, composedFocusTasks(from: openTasks).map(HomeTodayRow.task))
        refreshFocusWhyCandidatesIfPresented()
        refreshEvaInsights(openTasks: openTasks)

        if activeScope == .done {
            assignIfChanged(\.doneTimelineTasks, doneTasks)
            assignIfChanged(\.dailyCompletedTasks, doneTasks)
            assignIfChanged(\.completedTasks, doneTasks)
            assignIfChanged(\.dueTodayRows, [])
            assignIfChanged(\.dueTodaySection, nil)
            assignIfChanged(\.todaySections, [])
            assignIfChanged(\.todayAgendaSectionState, TodayAgendaSectionState(sections: []))
            assignIfChanged(\.rescueSectionState, RescueSectionState(rows: []))
            assignIfChanged(\.quietTrackingSummaryState, QuietTrackingSummaryState(stableRows: []))
            currentHabitSignals = []
            assignIfChanged(\.focusTasks, [])
            assignIfChanged(\.focusRows, [])
            assignIfChanged(\.focusNowSectionState, FocusNowSectionState(rows: [], pinnedTaskIDs: pinnedFocusTaskIDs))
            refreshFocusWhyCandidatesIfPresented()
            refreshEvaInsights(openTasks: [])
            assignIfChanged(\.upcomingTasks, [])
            assignIfChanged(\.morningTasks, [])
            assignIfChanged(\.eveningTasks, [])
            assignIfChanged(\.overdueTasks, [])
            assignIfChanged(\.emptyStateMessage, "No completed tasks in last 30 days")
            assignIfChanged(\.emptyStateActionTitle, nil)
            updateCompletionRateFromFocusResult(openTasks: openTasks, doneTasks: doneTasks)
            writeTaskListWidgetSnapshot(reason: "apply_result_done")
            return
        }

        assignIfChanged(\.doneTimelineTasks, [])
        assignIfChanged(\.completedTasks, doneTasks)
        assignIfChanged(\.dailyCompletedTasks, doneTasks)
        refreshDueTodayAgenda(
            openTaskRows: openTasks,
            generation: generation
        )

        let overdue = visibleTasks.filter { isTaskOverdue($0, relativeTo: activeScope) }
        let nonOverdue = visibleTasks.filter { !isTaskOverdue($0, relativeTo: activeScope) }

        let computedEvening = nonOverdue.filter { isEveningTaskHybrid($0) }.sorted(by: sortByPriorityThenDue)
        let computedMorning = nonOverdue.filter { !isEveningTaskHybrid($0) }.sorted(by: sortByPriorityThenDue)
        let computedOverdue = overdue.sorted(by: sortByPriorityThenDue)

        if shouldKeepCompletedInline {
            let retained = retainingInlineCompletedRows(
                computedMorning: computedMorning,
                computedEvening: computedEvening,
                computedOverdue: computedOverdue,
                doneTasks: doneTasks
            )
            assignIfChanged(\.morningTasks, retained.morning)
            assignIfChanged(\.eveningTasks, retained.evening)
            assignIfChanged(\.overdueTasks, retained.overdue)
        } else {
            assignIfChanged(\.morningTasks, computedMorning)
            assignIfChanged(\.eveningTasks, computedEvening)
            assignIfChanged(\.overdueTasks, computedOverdue)
        }

        switch activeScope.quickView {
        case .upcoming:
            assignIfChanged(\.upcomingTasks, openTasks)
            assignIfChanged(\.emptyStateMessage, "No upcoming tasks in 14 days")
            assignIfChanged(\.emptyStateActionTitle, nil)
        case .overdue:
            assignIfChanged(\.upcomingTasks, [])
            assignIfChanged(\.emptyStateMessage, "No overdue tasks. Great job.")
            assignIfChanged(\.emptyStateActionTitle, nil)
        case .morning:
            assignIfChanged(\.upcomingTasks, [])
            assignIfChanged(\.emptyStateMessage, "No morning tasks. Add one to start strong.")
            assignIfChanged(\.emptyStateActionTitle, "Add Morning TaskDefinition")
        case .evening:
            assignIfChanged(\.upcomingTasks, [])
            assignIfChanged(\.emptyStateMessage, "No evening tasks. Plan your wind-down.")
            assignIfChanged(\.emptyStateActionTitle, "Add Evening TaskDefinition")
        case .today:
            assignIfChanged(\.upcomingTasks, [])
            assignIfChanged(\.emptyStateMessage, nil)
            assignIfChanged(\.emptyStateActionTitle, nil)
        case .done:
            // handled above
            break
        }

        updateCompletionRateFromFocusResult(openTasks: openTasks, doneTasks: doneTasks)
        writeTaskListWidgetSnapshot(reason: "apply_result_\(activeScope.quickView.rawValue)")
    }

    /// Executes updateCompletionRateFromFocusResult.
    private func updateCompletionRateFromFocusResult(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let total = openTasks.count + doneTasks.count
        assignIfChanged(\.completionRate, total > 0 ? Double(doneTasks.count) / Double(total) : 0)
    }

    /// Executes refreshProgressState.
    private func refreshProgressState() {
        let earnedXP = max(0, dailyScore)
        let remainingPotentialXP: Int
        let targetXP: Int

        if V2FeatureFlags.gamificationV2Enabled {
            remainingPotentialXP = max(0, dailyXPCap - earnedXP)
            targetXP = dailyXPCap
        } else {
            remainingPotentialXP = max(0, pointsPotential)
            targetXP = earnedXP + remainingPotentialXP
        }

        let streakDays = max(0, streak)

        assignIfChanged(\.progressState, HomeProgressState(
            earnedXP: earnedXP,
            remainingPotentialXP: remainingPotentialXP,
            todayTargetXP: targetXP,
            streakDays: streakDays,
            isStreakSafeToday: earnedXP > 0
        ))
    }

    /// Executes persistLastFilterState.
    private func persistLastFilterState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(activeFilterState) {
            userDefaults.set(data, forKey: Self.lastFilterStateKey)
        }
    }

    /// Executes restorePinnedFocusTaskIDs.
    private func restorePinnedFocusTaskIDs() {
        let persistedIDs = userDefaults
            .stringArray(forKey: Self.pinnedFocusTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(persistedIDs)
    }

    /// Executes persistPinnedFocusTaskIDs.
    private func persistPinnedFocusTaskIDs() {
        let normalized = normalizedPinnedFocusTaskIDs(pinnedFocusTaskIDs)
        if normalized != pinnedFocusTaskIDs {
            pinnedFocusTaskIDs = normalized
        }
        userDefaults.set(normalized.map(\.uuidString), forKey: Self.pinnedFocusTaskIDsKey)
    }

    /// Executes restoreRecentShuffleTaskIDs.
    private func restoreRecentShuffleTaskIDs() {
        recentShuffledFocusTaskIDs = userDefaults
            .stringArray(forKey: Self.recentShuffleTaskIDsKey)?
            .compactMap(UUID.init(uuidString:))
            ?? []
    }

    /// Executes persistRecentShuffleTaskIDs.
    private func persistRecentShuffleTaskIDs() {
        userDefaults.set(recentShuffledFocusTaskIDs.map(\.uuidString), forKey: Self.recentShuffleTaskIDsKey)
    }

    private var shuffleExclusionWindow: Int {
        #if DEBUG
        if userDefaults.object(forKey: "debug.eva.focus.shuffleExclusionWindow") != nil {
            let configured = userDefaults.integer(forKey: "debug.eva.focus.shuffleExclusionWindow")
            return max(1, min(8, configured))
        }
        #endif
        return Self.defaultShuffleExclusionWindow
    }

    /// Executes seedPinnedProjectsIfNeeded.
    private func seedPinnedProjectsIfNeeded(from projects: [Project]) {
        guard activeFilterState.pinnedProjectIDs.isEmpty else { return }
        let seeded = Array(projects.prefix(5).map(\.id))
        guard !seeded.isEmpty else { return }
        activeFilterState.pinnedProjectIDs = seeded
        persistLastFilterState()
    }

    /// Executes normalizeCustomProjectOrderIfNeeded.
    private func normalizeCustomProjectOrderIfNeeded(from projects: [Project]) {
        let normalized = normalizedCustomProjectOrder(
            from: activeFilterState.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: projects
        )
        guard activeFilterState.customProjectOrderIDs != normalized else { return }
        activeFilterState.customProjectOrderIDs = normalized
        persistLastFilterState()
    }

    /// Executes bumpPinnedProject.
    private func bumpPinnedProject(_ id: UUID) {
        var pinned = activeFilterState.pinnedProjectIDs
        pinned.removeAll { $0 == id }
        pinned.insert(id, at: 0)

        if pinned.count > 5 {
            pinned = Array(pinned.prefix(5))
        }

        activeFilterState.pinnedProjectIDs = pinned
    }

    /// Executes refreshEvaInsights.
    private func refreshEvaInsights(openTasks: [TaskDefinition]? = nil) {
        guard V2FeatureFlags.evaFocusEnabled || V2FeatureFlags.evaTriageEnabled || V2FeatureFlags.evaRescueEnabled else {
            evaHomeInsights = nil
            return
        }
        let sourceOpenTasks = openTasks ?? focusOpenTasksForCurrentState()
        let anchorDate = activeScope.referenceDate
        evaInsightsGeneration += 1
        let requestGeneration = evaInsightsGeneration
        useCaseCoordinator.computeEvaHomeInsights.execute(
            openTasks: sourceOpenTasks,
            focusTasks: focusTasks,
            anchorDate: anchorDate
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.evaInsightsGeneration == requestGeneration else { return }
                switch result {
                case .success(let insights):
                    self.evaHomeInsights = insights
                case .failure(let error):
                    logWarning(
                        event: "eva_home_insights_failed",
                        message: "Failed to compute Eva home insights",
                        fields: ["error": error.localizedDescription]
                    )
                }
            }
        }
    }

    /// Executes dueDate.
    private func dueDate(for bucket: EvaDueBucket?) -> Date? {
        guard let bucket else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch bucket {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            let daysUntilEndOfWeek = 7 - calendar.component(.weekday, from: today)
            return calendar.date(byAdding: .day, value: max(daysUntilEndOfWeek, 2), to: today)
        case .someday:
            return nil
        }
    }

    private func uniqueTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        var seen = Set<UUID>()
        var unique: [TaskDefinition] = []
        unique.reserveCapacity(tasks.count)
        for task in tasks where !seen.contains(task.id) {
            seen.insert(task.id)
            unique.append(task)
        }
        return unique
    }

    /// Executes sanitizeFilterState.
    private func sanitizeFilterState(_ state: HomeFilterState, availableProjects: [Project]) -> HomeFilterState {
        var sanitized = state
        sanitized.customProjectOrderIDs = normalizedCustomProjectOrder(
            from: state.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: availableProjects
        )
        return sanitized
    }

    /// Executes normalizedCustomProjectOrder.
    private func normalizedCustomProjectOrder(
        from requestedOrder: [UUID],
        currentOrder: [UUID],
        availableProjects: [Project]
    ) -> [UUID] {
        let customProjects = availableProjects
            .filter { !$0.isInbox && $0.id != ProjectConstants.inboxProjectID }

        let dedupedRequested = Array(NSOrderedSet(array: requestedOrder).compactMap { $0 as? UUID })
            .filter { $0 != ProjectConstants.inboxProjectID }

        let dedupedCurrent = Array(NSOrderedSet(array: currentOrder).compactMap { $0 as? UUID })
            .filter { $0 != ProjectConstants.inboxProjectID }

        guard !customProjects.isEmpty else {
            var merged = dedupedRequested
            for id in dedupedCurrent where !merged.contains(id) {
                merged.append(id)
            }
            return merged
        }

        let customByID = Dictionary(uniqueKeysWithValues: customProjects.map { ($0.id, $0) })
        let requestedPresent = dedupedRequested.filter { customByID[$0] != nil }
        let currentPresent = dedupedCurrent.filter { customByID[$0] != nil }

        var merged = requestedPresent
        for id in currentPresent where !merged.contains(id) {
            merged.append(id)
        }

        let missing = customProjects
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(\.id)
            .filter { !merged.contains($0) }

        return merged + missing
    }

    /// Executes sortByPriorityThenDue.
    private func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    /// Executes isEveningTaskHybrid.
    private func isEveningTaskHybrid(_ task: TaskDefinition) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    /// Executes rankedFocusTasks.
    private func rankedFocusTasks(from tasks: [TaskDefinition], relativeTo scope: HomeListScope) -> [TaskDefinition] {
        guard !tasks.isEmpty else { return [] }

        let calendar = Calendar.current
        let anchorStart = calendar.startOfDay(for: scope.referenceDate)
        let anchorEnd = calendar.date(byAdding: .day, value: 1, to: anchorStart) ?? anchorStart

        /// Executes isOverdue.
        func isOverdue(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate < anchorStart
        }

        /// Executes isDueToday.
        func isDueToday(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= anchorStart && dueDate < anchorEnd
        }

        if V2FeatureFlags.evaFocusEnabled {
            let scored = tasks.map { task in
                let overdueDays = task.dueDate.map { max(0, calendar.dateComponents([.day], from: $0, to: anchorStart).day ?? 0) } ?? 0
                let urgency = Double(overdueDays) * 1.4 + (isDueToday(task) ? 2.0 : 0)
                let quickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800 ? 1.0 : 0
                let unblocked = task.dependencies.isEmpty ? 1.0 : -1.2
                let importance = Double(task.priority.scorePoints) * 0.6
                let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: Date()).day ?? 0)
                let freshness = staleDays >= 14 ? -0.8 : 0.3
                let score = urgency + quickWin + unblocked + importance + freshness
                return (task: task, score: score)
            }
            let sortedScored = scored.sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                let lhsDue = lhs.task.dueDate ?? Date.distantFuture
                let rhsDue = rhs.task.dueDate ?? Date.distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.task.id.uuidString < rhs.task.id.uuidString
            }
            return Array(sortedScored.map(\.task).prefix(Self.maxPinnedFocusTasks))
        }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsOverdue = isOverdue(lhs)
            let rhsOverdue = isOverdue(rhs)
            if lhsOverdue != rhsOverdue {
                return lhsOverdue
            }

            let lhsDueToday = isDueToday(lhs)
            let rhsDueToday = isDueToday(rhs)
            if lhsDueToday != rhsDueToday {
                return lhsDueToday
            }

            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }

            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        return Array(sorted.prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes composedFocusTasks.
    private func composedFocusTasks(from openTasks: [TaskDefinition]) -> [TaskDefinition] {
        guard !openTasks.isEmpty else { return [] }
        guard activeScope.quickView == .today else {
            return rankedFocusTasks(from: openTasks, relativeTo: activeScope)
        }

        let openByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        let pinnedOpen = pinnedFocusTaskIDs.compactMap { openByID[$0] }
        let pinnedSet = Set(pinnedOpen.map(\.id))
        let rankedAutoFill = rankedFocusTasks(
            from: openTasks.filter { !pinnedSet.contains($0.id) },
            relativeTo: activeScope
        )

        return Array((pinnedOpen + rankedAutoFill).prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes prunePinnedFocusTaskIDs.
    private func prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set<UUID>) {
        let filtered = pinnedFocusTaskIDs.filter { keepingOpenTaskIDs.contains($0) }
        guard filtered != pinnedFocusTaskIDs else { return }
        pinnedFocusTaskIDs = filtered
        persistPinnedFocusTaskIDs()
    }

    /// Executes removePinnedFocusTaskID.
    private func removePinnedFocusTaskID(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
    }

    /// Executes normalizedPinnedFocusTaskIDs.
    private func normalizedPinnedFocusTaskIDs(_ ids: [UUID]) -> [UUID] {
        var deduped: [UUID] = []
        deduped.reserveCapacity(min(ids.count, Self.maxPinnedFocusTasks))

        for id in ids where !deduped.contains(id) {
            deduped.append(id)
            if deduped.count == Self.maxPinnedFocusTasks {
                break
            }
        }

        return deduped
    }

    /// Executes focusOpenTasksForCurrentState.
    private func focusOpenTasksForCurrentState() -> [TaskDefinition] {
        switch activeScope.quickView {
        case .done:
            return []
        case .upcoming:
            return upcomingTasks.filter { !$0.isComplete }
        case .overdue:
            return overdueTasks.filter { !$0.isComplete }
        case .today, .morning, .evening:
            return (morningTasks + eveningTasks + overdueTasks).filter { !$0.isComplete }
        }
    }

    /// Executes refreshFocusTasksFromCurrentState.
    private func refreshFocusTasksFromCurrentState() {
        if activeScope.quickView == .done {
            updateFocusSelection([])
            refreshEvaInsights(openTasks: [])
            return
        }

        let openTasks = focusOpenTasksForCurrentState()
        if activeScope.quickView == .today {
            prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set(openTasks.map(\.id)))
        }
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
    }

    private func writeTaskListWidgetSnapshot(reason: String = "home_event") {
        guard V2FeatureFlags.taskListWidgetsEnabled else { return }
        TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: reason)
    }

    private func buildTaskListWidgetSnapshot() -> TaskListWidgetSnapshot {
        let openUnion = uniqueTasks(
            morningTasks.filter { !$0.isComplete } +
            eveningTasks.filter { !$0.isComplete } +
            overdueTasks.filter { !$0.isComplete } +
            upcomingTasks.filter { !$0.isComplete } +
            focusTasks.filter { !$0.isComplete }
        )
        let sortedOpen = sortTasksByPriorityThenDue(openUnion)
        let topTasks = Array((focusTasks.filter { !$0.isComplete }.isEmpty ? sortedOpen : focusTasks.filter { !$0.isComplete }).prefix(3))
        let overdueTop = Array(sortTasksByPriorityThenDue(overdueTasks.filter { !$0.isComplete }).prefix(3))

        let now = Date()
        let fortyEightHours = now.addingTimeInterval(48 * 60 * 60)
        let dueSoon = sortTasksByPriorityThenDue(
            openUnion.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= fortyEightHours
            }
        )

        let quickWinCandidates = sortTasksByPriorityThenDue(
            openUnion.filter { task in
                guard let minutes = task.estimatedDuration.map({ Int($0 / 60) }) else { return false }
                return minutes > 0 && minutes <= 15
            }
        )

        let waiting = Array(
            sortTasksByPriorityThenDue(openUnion.filter { !$0.dependencies.isEmpty })
                .prefix(3)
        )

        let completedToday = dailyCompletedTasks.filter { task in
            guard let completedAt = task.dateCompleted else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }

        let projectSlices: [TaskListWidgetProjectSlice] = Dictionary(
            grouping: openUnion,
            by: { task in
                task.projectID
            }
        )
        .map { projectID, tasks in
            let projectName = tasks.first?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = (projectName?.isEmpty == false ? projectName : nil) ?? "Inbox"
            return TaskListWidgetProjectSlice(
                projectID: projectID,
                projectName: normalizedName,
                openCount: tasks.count,
                overdueCount: tasks.filter(\.isOverdue).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.openCount != rhs.openCount {
                return lhs.openCount > rhs.openCount
            }
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        let energyBuckets: [TaskListWidgetEnergyBucket] = TaskEnergy.allCases.map { energy in
            TaskListWidgetEnergyBucket(
                energy: energy.rawValue,
                count: openUnion.filter { $0.energy == energy }.count
            )
        }

        return TaskListWidgetSnapshot(
            updatedAt: Date(),
            todayTopTasks: topTasks.map(widgetTask(from:)),
            upcomingTasks: Array(dueSoon.prefix(3)).map(widgetTask(from:)),
            overdueTasks: overdueTop.map(widgetTask(from:)),
            quickWins: Array(quickWinCandidates.prefix(3)).map(widgetTask(from:)),
            projectSlices: Array(projectSlices.prefix(4)),
            doneTodayCount: completedToday.count,
            focusNow: Array(focusTasks.filter { !$0.isComplete }.prefix(3)).map(widgetTask(from:)),
            waitingOn: waiting.map(widgetTask(from:)),
            energyBuckets: energyBuckets
        )
    }

    private func widgetTask(from task: TaskDefinition) -> TaskListWidgetTask {
        let minutes = task.estimatedDuration.map { duration in
            max(1, Int(duration / 60))
        }
        return TaskListWidgetTask(
            id: task.id,
            title: task.title,
            projectID: task.projectID,
            projectName: task.projectName,
            priorityCode: task.priority.code,
            dueDate: task.dueDate,
            isOverdue: task.isOverdue,
            estimatedDurationMinutes: minutes,
            energy: task.energy.rawValue,
            context: task.context.rawValue,
            isComplete: task.isComplete,
            hasDependencies: !task.dependencies.isEmpty
        )
    }

    private func reloadTaskListWidgetTimelines() {
        #if canImport(WidgetKit)
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    /// Executes trackFeatureUsage.
    private func trackFeatureUsage(action: String, metadata: [String: Any]? = nil) {
        analyticsService?.trackFeatureUsage(feature: "home_filter", action: action, metadata: metadata)
    }

    /// Executes handleExternalMutation.
    public func handleExternalMutation(reason: HomeTaskMutationEvent, repostEvent: Bool = true) {
        enqueueReload(
            source: "external_mutation_\(reason.rawValue)",
            reason: reason,
            taskID: nil,
            invalidateCaches: true,
            includeAnalytics: true,
            repostEvent: repostEvent
        )
    }

    public func enqueueReload(
        source: String,
        reason: HomeTaskMutationEvent? = nil,
        taskID: UUID? = nil,
        invalidateCaches: Bool,
        includeAnalytics: Bool,
        repostEvent: Bool
    ) {
        pendingReloadSources.insert(source)
        if let reason {
            pendingReloadReasons.insert(reason)
        }
        pendingReloadScopes.formUnion(
            reloadScopes(for: reason, includeAnalytics: includeAnalytics, repostEvent: repostEvent)
        )
        if let taskID {
            pendingReloadTaskIDs.insert(taskID)
        }
        pendingReloadInvalidateCaches = pendingReloadInvalidateCaches || invalidateCaches
        pendingReloadIncludeAnalytics = pendingReloadIncludeAnalytics || includeAnalytics
        pendingReloadRepostEvent = pendingReloadRepostEvent || repostEvent

        pendingReloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushQueuedReloads()
        }
        pendingReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(reloadDebounceMS),
            execute: workItem
        )
    }

    private func flushQueuedReloads() {
        if isApplyingReloadBatch {
            queuedReloadAfterCurrentBatch = true
            return
        }
        isApplyingReloadBatch = true

        let reasons = pendingReloadReasons
        let sources = pendingReloadSources
        let scopes = pendingReloadScopes
        let shouldInvalidate = pendingReloadInvalidateCaches
        let shouldIncludeAnalytics = pendingReloadIncludeAnalytics
        let shouldRepostEvent = pendingReloadRepostEvent

        pendingReloadReasons = []
        pendingReloadSources = []
        pendingReloadScopes = []
        pendingReloadTaskIDs = []
        pendingReloadInvalidateCaches = false
        pendingReloadIncludeAnalytics = false
        pendingReloadRepostEvent = false
        pendingReloadWorkItem = nil

        let reloadStartedAt = Date()
        if shouldInvalidate {
            invalidateTaskCaches()
        }
        let interval = TaskerPerformanceTrace.begin("HomeReloadBatch")
        let generation = nextReloadGeneration()
        let tracker = HomeReloadBatchTracker { [weak self] in
            TaskerPerformanceTrace.end(interval)
            logWarning(
                event: "home_reload_batch_applied",
                message: "Applied coalesced Home reload batch",
                fields: [
                    "source_count": String(sources.count),
                    "reason_count": String(reasons.count),
                    "scope_count": String(scopes.count),
                    "invalidate_caches": shouldInvalidate ? "true" : "false",
                    "include_analytics": shouldIncludeAnalytics ? "true" : "false",
                    "repost_event": shouldRepostEvent ? "true" : "false",
                    "duration_ms": String(Int(Date().timeIntervalSince(reloadStartedAt) * 1_000))
                ]
            )
            self?.completeReloadBatchLifecycle()
        }

        if scopes.contains(.visibleTasks) {
            tracker.registerOperation()
        }
        applyReloadScopes(
            scopes,
            generation: generation,
            visibleTasksCompletion: scopes.contains(.visibleTasks) ? { tracker.completeOperation() } : nil
        )

        if shouldIncludeAnalytics || scopes.contains(.analytics) {
            tracker.registerOperation()
            loadDailyAnalytics(includeGamificationRefresh: false) {
                tracker.completeOperation()
            }
        }
        tracker.finishSchedulingOperations()
    }

    private func completeReloadBatchLifecycle() {
        isApplyingReloadBatch = false
        if queuedReloadAfterCurrentBatch {
            queuedReloadAfterCurrentBatch = false
            if pendingReloadSources.isEmpty == false {
                flushQueuedReloads()
            }
        }
    }

    private func reloadScopes(
        for reason: HomeTaskMutationEvent?,
        includeAnalytics: Bool,
        repostEvent: Bool
    ) -> Set<HomeReloadScope> {
        var scopes: Set<HomeReloadScope> = [.visibleTasks]
        if includeAnalytics {
            scopes.insert(.analytics)
        }
        return scopes
    }

    private func prioritizedReloadReason(from reasons: Set<HomeTaskMutationEvent>) -> HomeTaskMutationEvent? {
        let priorityOrder: [HomeTaskMutationEvent] = [
            .completed,
            .reopened,
            .created,
            .deleted,
            .rescheduled,
            .projectChanged,
            .priorityChanged,
            .typeChanged,
            .dueDateChanged,
            .updated,
            .bulkChanged
        ]
        return priorityOrder.first(where: { reasons.contains($0) }) ?? reasons.first
    }

    private func prioritizedTaskID(from taskIDs: Set<UUID>, for reason: HomeTaskMutationEvent) -> UUID? {
        guard taskIDs.isEmpty == false else { return nil }

        switch reason {
        case .completed, .reopened, .created, .deleted, .rescheduled, .projectChanged, .priorityChanged, .typeChanged, .dueDateChanged, .updated:
            return taskIDs.first
        case .bulkChanged:
            return nil
        }
    }

    private func handleGamificationLedgerMutation(_ mutation: GamificationLedgerMutation) {
        lastLedgerMutationObservedAt = Date()
        pendingLedgerMutationWatchdog?.cancel()
        pendingLedgerMutationWatchdog = nil

        dailyScore = max(0, mutation.dailyXPSoFar)
        totalXP = mutation.totalXP
        currentLevel = max(1, mutation.level)
        streak = max(0, mutation.streakDays)
        let levelInfo = XPCalculationEngine.levelForXP(mutation.totalXP)
        nextLevelXP = levelInfo.nextThreshold
        dailyXPCap = XPCalculationEngine.dailyCap
        refreshProgressState()

        let celebrationEligibleCategories: Set<XPActionCategory> = [.complete, .focus, .reflection]
        guard celebrationEligibleCategories.contains(mutation.category), mutation.awardedXP > 0 else { return }

        let milestone = XPCalculationEngine.milestoneCrossed(
            previousXP: max(0, mutation.totalXP - Int64(mutation.awardedXP)),
            newXP: mutation.totalXP
        )
        let celebration = XPCelebrationPayload(
            awardedXP: mutation.awardedXP,
            level: mutation.level,
            didLevelUp: mutation.level > mutation.previousLevel,
            crossedMilestone: milestone,
            cooldownSeconds: GamificationEngine.celebrationCooldownSeconds,
            occurredAt: mutation.occurredAt
        )
        let unlockedAchievements = mutation.unlockedAchievementKeys.map { key in
            AchievementUnlockDefinition(
                id: UUID(),
                achievementKey: key,
                unlockedAt: mutation.occurredAt,
                sourceEventID: mutation.originatingEventID
            )
        }

        dispatchCelebration(XPEventResult(
            awardedXP: mutation.awardedXP,
            totalXP: mutation.totalXP,
            level: mutation.level,
            previousLevel: mutation.previousLevel,
            currentStreak: mutation.streakDays,
            didLevelUp: mutation.level > mutation.previousLevel,
            dailyXPSoFar: mutation.dailyXPSoFar,
            dailyCap: XPCalculationEngine.dailyCap,
            unlockedAchievements: unlockedAchievements,
            crossedMilestone: milestone,
            celebration: celebration
        ))
    }

    private func scheduleLedgerMutationWatchdog(trigger: String) {
        guard V2FeatureFlags.gamificationV2Enabled else { return }

        pendingLedgerMutationWatchdog?.cancel()
        let observedAtScheduleTime = lastLedgerMutationObservedAt
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.lastLedgerMutationObservedAt <= observedAtScheduleTime else { return }

            logWarning(
                event: "gamification_ledger_watchdog_refresh",
                message: "Ledger mutation signal not observed in time; forcing one-shot XP state refresh",
                fields: ["trigger": trigger]
            )
            self.refreshGamificationV2State()
            NotificationCenter.default.post(
                name: Notification.Name("DataDidChangeFromCloudSync"),
                object: nil
            )
        }

        pendingLedgerMutationWatchdog = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ledgerMutationWatchdogDelaySeconds,
            execute: workItem
        )
    }

    /// Executes requestChartRefresh.
    public func requestChartRefresh(reason: HomeTaskMutationEvent, taskID: UUID? = nil) {
        let userInfo = HomeTaskMutationPayload(
            reason: reason,
            source: Self.mutationNotificationSource,
            taskID: taskID
        ).userInfo
        NotificationCenter.default.post(
            name: .homeTaskMutation,
            object: nil,
            userInfo: userInfo
        )
    }

    /// Executes scopeAnalyticsAction.
    private func scopeAnalyticsAction(_ scope: HomeListScope) -> String {
        switch scope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    /// Executes trackFirstCompletionLatencyIfNeeded.
    private func trackFirstCompletionLatencyIfNeeded() {
        guard !didTrackFirstCompletionLatency else { return }
        didTrackFirstCompletionLatency = true

        let latency = Date().timeIntervalSince(homeOpenedAt)
        trackFeatureUsage(action: "home_filter_time_to_first_completion_sec", metadata: ["seconds": latency])
    }

    /// Executes updateCompletionRate.
    private func updateCompletionRate(_ result: TodayTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes updateCompletionRate.
    private func updateCompletionRate(_ result: DateTasksResult) {
        let total = result.totalCount
        let completed = result.completedTasks.count
        completionRate = total > 0 ? Double(completed) / Double(total) : 0
    }

    /// Executes applyCompletionResultLocally.
    private func applyCompletionResultLocally(_ updatedTask: TaskDefinition) {
        let keepsCompletedInline = shouldKeepCompletedInline(for: activeScope)

        if keepsCompletedInline {
            upsertTaskInOpenProjectionPreservingPosition(updatedTask)
        } else {
            removeTaskFromOpenProjections(id: updatedTask.id)
        }
        selectedProjectTasks = replacingTask(in: selectedProjectTasks, with: updatedTask)

        if updatedTask.isComplete {
            completedTasks = upsertingTaskInPlace(in: completedTasks, with: updatedTask)
            dailyCompletedTasks = upsertingTaskInPlace(in: dailyCompletedTasks, with: updatedTask)
            doneTimelineTasks = upsertingTaskInPlace(in: doneTimelineTasks, with: updatedTask)
        } else {
            if !keepsCompletedInline {
                insertTaskIntoOpenProjection(updatedTask)
                if activeFilterState.quickView == .upcoming {
                    upcomingTasks = upsertingTaskInPlace(in: upcomingTasks, with: updatedTask)
                }
            }
            completedTasks = removingTask(id: updatedTask.id, from: completedTasks)
            dailyCompletedTasks = removingTask(id: updatedTask.id, from: dailyCompletedTasks)
            doneTimelineTasks = removingTask(id: updatedTask.id, from: doneTimelineTasks)
        }

        if let snapshot = todayTasks {
            var snapshotMorning = snapshot.morningTasks
            var snapshotEvening = snapshot.eveningTasks
            var snapshotOverdue = snapshot.overdueTasks
            let snapshotCompletedSeed = snapshot.completedTasks
            var snapshotCompleted = removingTask(id: updatedTask.id, from: snapshotCompletedSeed)

            let snapshotWasInMorning = snapshotMorning.contains(where: { $0.id == updatedTask.id })
            let snapshotWasInEvening = snapshotEvening.contains(where: { $0.id == updatedTask.id })
            let snapshotWasInOverdue = snapshotOverdue.contains(where: { $0.id == updatedTask.id })

            if updatedTask.isComplete {
                snapshotCompleted = upsertingTaskInPlace(in: snapshotCompleted, with: updatedTask)
                if keepsCompletedInline {
                    if snapshotWasInMorning {
                        snapshotMorning = replacingTaskIfPresent(in: snapshotMorning, with: updatedTask)
                    } else if snapshotWasInEvening {
                        snapshotEvening = replacingTaskIfPresent(in: snapshotEvening, with: updatedTask)
                    } else if snapshotWasInOverdue {
                        snapshotOverdue = replacingTaskIfPresent(in: snapshotOverdue, with: updatedTask)
                    } else if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                } else {
                    snapshotMorning = removingTask(id: updatedTask.id, from: snapshotMorning)
                    snapshotEvening = removingTask(id: updatedTask.id, from: snapshotEvening)
                    snapshotOverdue = removingTask(id: updatedTask.id, from: snapshotOverdue)
                }
            } else {
                if keepsCompletedInline {
                    if snapshotWasInMorning {
                        snapshotMorning = replacingTaskIfPresent(in: snapshotMorning, with: updatedTask)
                    } else if snapshotWasInEvening {
                        snapshotEvening = replacingTaskIfPresent(in: snapshotEvening, with: updatedTask)
                    } else if snapshotWasInOverdue {
                        snapshotOverdue = replacingTaskIfPresent(in: snapshotOverdue, with: updatedTask)
                    } else if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                } else {
                    snapshotMorning = removingTask(id: updatedTask.id, from: snapshotMorning)
                    snapshotEvening = removingTask(id: updatedTask.id, from: snapshotEvening)
                    snapshotOverdue = removingTask(id: updatedTask.id, from: snapshotOverdue)
                    if updatedTask.isOverdue {
                        snapshotOverdue = upsertingTaskInPlace(in: snapshotOverdue, with: updatedTask)
                    } else if isEveningTaskHybrid(updatedTask) {
                        snapshotEvening = upsertingTaskInPlace(in: snapshotEvening, with: updatedTask)
                    } else {
                        snapshotMorning = upsertingTaskInPlace(in: snapshotMorning, with: updatedTask)
                    }
                }
            }

            let updatedSnapshot = TodayTasksResult(
                morningTasks: sortTasksByPriorityThenDue(snapshotMorning),
                eveningTasks: sortTasksByPriorityThenDue(snapshotEvening),
                overdueTasks: sortTasksByPriorityThenDue(snapshotOverdue),
                completedTasks: snapshotCompleted,
                totalCount: snapshot.totalCount
            )
            todayTasks = updatedSnapshot
        }

        logDebug(
            "HOME_ROW_STATE vm.local_apply id=\(updatedTask.id.uuidString) isComplete=\(updatedTask.isComplete) " +
            "morning=\(morningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "evening=\(eveningTasks.contains(where: { $0.id == updatedTask.id })) " +
            "overdue=\(overdueTasks.contains(where: { $0.id == updatedTask.id })) " +
            "completed=\(completedTasks.contains(where: { $0.id == updatedTask.id })) " +
            "doneTimeline=\(doneTimelineTasks.contains(where: { $0.id == updatedTask.id }))"
        )

        if updatedTask.isComplete {
            removePinnedFocusTaskID(updatedTask.id)
        }
        refreshFocusTasksFromCurrentState()
        refreshProgressState()
        writeTaskListWidgetSnapshot(reason: "local_completion_apply")
    }

    /// Executes replacingTask.
    private func replacingTask(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        tasks.map { task in
            task.id == updatedTask.id ? updatedTask : task
        }
    }

    /// Executes upsertingTaskInPlace.
    private func upsertingTaskInPlace(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks + [updatedTask]
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    /// Executes replacingTaskIfPresent.
    private func replacingTaskIfPresent(in tasks: [TaskDefinition], with updatedTask: TaskDefinition) -> [TaskDefinition] {
        guard let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) else {
            return tasks
        }

        var updated = tasks
        updated[index] = updatedTask
        return updated
    }

    /// Executes removingTask.
    private func removingTask(id: UUID, from tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.filter { $0.id != id }
    }

    /// Executes removeTaskFromOpenProjections.
    private func removeTaskFromOpenProjections(id: UUID) {
        morningTasks = removingTask(id: id, from: morningTasks)
        eveningTasks = removingTask(id: id, from: eveningTasks)
        overdueTasks = removingTask(id: id, from: overdueTasks)
        upcomingTasks = removingTask(id: id, from: upcomingTasks)
    }

    /// Executes upsertTaskInOpenProjectionPreservingPosition.
    private func upsertTaskInOpenProjectionPreservingPosition(_ task: TaskDefinition) {
        if morningTasks.contains(where: { $0.id == task.id }) {
            morningTasks = replacingTaskIfPresent(in: morningTasks, with: task)
            return
        }
        if eveningTasks.contains(where: { $0.id == task.id }) {
            eveningTasks = replacingTaskIfPresent(in: eveningTasks, with: task)
            return
        }
        if overdueTasks.contains(where: { $0.id == task.id }) {
            overdueTasks = replacingTaskIfPresent(in: overdueTasks, with: task)
            return
        }
        if upcomingTasks.contains(where: { $0.id == task.id }) {
            upcomingTasks = replacingTaskIfPresent(in: upcomingTasks, with: task)
            return
        }

        insertTaskIntoOpenProjection(task)
    }

    /// Executes insertTaskIntoOpenProjection.
    private func insertTaskIntoOpenProjection(_ task: TaskDefinition) {
        if task.isOverdue {
            overdueTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: overdueTasks, with: task))
            return
        }

        if isEveningTaskHybrid(task) {
            eveningTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: eveningTasks, with: task))
        } else {
            morningTasks = sortTasksByPriorityThenDue(upsertingTaskInPlace(in: morningTasks, with: task))
        }
    }

    /// Executes sortTasksByPriorityThenDue.
    private func sortTasksByPriorityThenDue(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted(by: sortByPriorityThenDue)
    }

    private enum InlineSection {
        case morning
        case evening
        case overdue
    }

    /// Executes retainingInlineCompletedRows.
    private func retainingInlineCompletedRows(
        computedMorning: [TaskDefinition],
        computedEvening: [TaskDefinition],
        computedOverdue: [TaskDefinition],
        doneTasks: [TaskDefinition]
    ) -> (morning: [TaskDefinition], evening: [TaskDefinition], overdue: [TaskDefinition]) {
        var morning = computedMorning
        var evening = computedEvening
        var overdue = computedOverdue

        var visibleIDs = Set((morning + evening + overdue).map(\.id))
        let doneByID = Dictionary(uniqueKeysWithValues: doneTasks.map { ($0.id, $0) })

        let priorCompleted: [(InlineSection, Int, TaskDefinition)] = {
            let morningRows = morningTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.morning, index, task) : nil
            }
            let eveningRows = eveningTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.evening, index, task) : nil
            }
            let overdueRows = overdueTasks.enumerated().compactMap { index, task in
                task.isComplete ? (InlineSection.overdue, index, task) : nil
            }
            return morningRows + eveningRows + overdueRows
        }()

        for (section, previousIndex, previousTask) in priorCompleted {
            if visibleIDs.contains(previousTask.id) {
                continue
            }

            let completionOverride = completionOverrides[previousTask.id]
            guard doneByID[previousTask.id] != nil || completionOverride == true else {
                continue
            }
            if completionOverride == false {
                continue
            }

            var restoredTask = doneByID[previousTask.id] ?? previousTask
            if completionOverride == true {
                restoredTask.isComplete = true
                restoredTask.dateCompleted = restoredTask.dateCompleted ?? Date()
            }
            guard isTaskCompletedOnActiveScopeDay(restoredTask) else {
                continue
            }

            switch section {
            case .morning:
                insertTaskIfMissing(&morning, task: restoredTask, preferredIndex: previousIndex)
            case .evening:
                insertTaskIfMissing(&evening, task: restoredTask, preferredIndex: previousIndex)
            case .overdue:
                insertTaskIfMissing(&overdue, task: restoredTask, preferredIndex: previousIndex)
            }
            visibleIDs.insert(restoredTask.id)
        }

        return (morning: morning, evening: evening, overdue: overdue)
    }

    /// Executes insertTaskIfMissing.
    private func insertTaskIfMissing(_ tasks: inout [TaskDefinition], task: TaskDefinition, preferredIndex: Int) {
        if let existingIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[existingIndex] = task
            return
        }

        let targetIndex = max(0, min(preferredIndex, tasks.count))
        tasks.insert(task, at: targetIndex)
    }

    /// Executes isTaskOverdue.
    private func isTaskOverdue(_ task: TaskDefinition, relativeTo scope: HomeListScope) -> Bool {
        guard let dueDate = task.dueDate else { return false }

        switch scope {
        case .today:
            return dueDate < Calendar.current.startOfDay(for: Date())
        case .customDate(let anchorDate):
            return dueDate < Calendar.current.startOfDay(for: anchorDate)
        case .upcoming, .overdue, .done, .morning, .evening:
            return task.isOverdue
        }
    }

    /// Executes shouldKeepCompletedInline.
    private func shouldKeepCompletedInline(for scope: HomeListScope) -> Bool {
        switch scope {
        case .today, .customDate:
            return true
        case .upcoming, .overdue, .done, .morning, .evening:
            return false
        }
    }

    /// Executes isTaskCompletedOnScopeDay.
    private func isTaskCompletedOnScopeDay(_ task: TaskDefinition, scope: HomeListScope) -> Bool {
        guard task.isComplete, let completionDate = task.dateCompleted else { return false }
        let calendar = Calendar.current
        let startOfScopeDay = calendar.startOfDay(for: scope.referenceDate)
        guard let startOfNextScopeDay = calendar.date(byAdding: .day, value: 1, to: startOfScopeDay) else {
            return false
        }
        return completionDate >= startOfScopeDay && completionDate < startOfNextScopeDay
    }

    /// Executes isTaskCompletedOnActiveScopeDay.
    private func isTaskCompletedOnActiveScopeDay(_ task: TaskDefinition) -> Bool {
        isTaskCompletedOnScopeDay(task, scope: activeScope)
    }

    /// Executes mergedInlineDoneTasks.
    private func mergedInlineDoneTasks(
        incomingDoneTasks: [TaskDefinition],
        openTasks: [TaskDefinition],
        shouldKeepCompletedInline: Bool
    ) -> [TaskDefinition] {
        guard shouldKeepCompletedInline else {
            return incomingDoneTasks
        }

        let openIDs = Set(openTasks.map(\.id))
        let retainedPriorDone = completedTasks.filter { task in
            !openIDs.contains(task.id) && isTaskCompletedOnActiveScopeDay(task)
        }

        var merged: [TaskDefinition] = []
        var seen = Set<UUID>()
        for task in incomingDoneTasks + retainedPriorDone where task.isComplete && isTaskCompletedOnActiveScopeDay(task) {
            if seen.insert(task.id).inserted {
                merged.append(task)
            }
        }
        return merged
    }

    /// Executes normalizedSections.
    private func normalizedSections(
        morning: [TaskDefinition],
        evening: [TaskDefinition],
        overdue: [TaskDefinition],
        completed: [TaskDefinition]
    ) -> (morning: [TaskDefinition], evening: [TaskDefinition], overdue: [TaskDefinition], completed: [TaskDefinition]) {
        let overridden = applyCompletionOverrides(
            openTasks: morning + evening + overdue,
            doneTasks: completed
        )

        let openTasks = overridden.openTasks
        let normalizedOverdue = sortTasksByPriorityThenDue(openTasks.filter(\.isOverdue))
        let nonOverdue = openTasks.filter { !$0.isOverdue }
        let normalizedEvening = sortTasksByPriorityThenDue(nonOverdue.filter { isEveningTaskHybrid($0) })
        let normalizedMorning = sortTasksByPriorityThenDue(nonOverdue.filter { !isEveningTaskHybrid($0) })

        return (
            morning: normalizedMorning,
            evening: normalizedEvening,
            overdue: normalizedOverdue,
            completed: overridden.doneTasks
        )
    }

    /// Executes nextReloadGeneration.
    @discardableResult
    private func nextReloadGeneration() -> Int {
        reloadGeneration += 1
        return reloadGeneration
    }

    @discardableResult
    private func nextAnalyticsGeneration() -> Int {
        analyticsGeneration += 1
        return analyticsGeneration
    }

    /// Executes isCurrentReloadGeneration.
    private func isCurrentReloadGeneration(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }

    private func isCurrentAnalyticsGeneration(_ generation: Int) -> Bool {
        generation == analyticsGeneration
    }

    private func assignIfChanged<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<HomeViewModel, Value>,
        _ newValue: Value
    ) {
        guard self[keyPath: keyPath] != newValue else { return }
        self[keyPath: keyPath] = newValue
        scheduleHomeRenderStateRefresh()
    }

    /// Executes applyCompletionOverrides.
    private func applyCompletionOverrides(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) -> (openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let normalizedOpen = openTasks.map(applyingCompletionOverrideIfNeeded)
        let normalizedDone = doneTasks.map(applyingCompletionOverrideIfNeeded)

        var mergedOpen: [TaskDefinition] = []
        var openIDs = Set<UUID>()
        for task in normalizedOpen where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }
        for task in normalizedDone where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }

        var mergedDone: [TaskDefinition] = []
        var doneIDs = Set<UUID>()
        for task in normalizedDone where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }
        for task in normalizedOpen where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }

        reconcileCompletionOverrides(persistedTasks: openTasks + doneTasks)
        return (openTasks: mergedOpen, doneTasks: mergedDone)
    }

    /// Executes applyingCompletionOverrideIfNeeded.
    private func applyingCompletionOverrideIfNeeded(_ task: TaskDefinition) -> TaskDefinition {
        guard let expectedCompletion = completionOverrides[task.id],
              expectedCompletion != task.isComplete else {
            return task
        }

        var updated = task
        updated.isComplete = expectedCompletion
        updated.dateCompleted = expectedCompletion ? (updated.dateCompleted ?? Date()) : nil
        return updated
    }

    /// Executes reconcileCompletionOverrides.
    private func reconcileCompletionOverrides(persistedTasks: [TaskDefinition]) {
        guard !completionOverrides.isEmpty else { return }

        var resolvedIDs: [UUID] = []
        for (id, expectedCompletion) in completionOverrides {
            guard let persistedTask = persistedTasks.first(where: { $0.id == id }) else { continue }
            if persistedTask.isComplete == expectedCompletion {
                resolvedIDs.append(id)
            }
        }

        guard !resolvedIDs.isEmpty else { return }
        for id in resolvedIDs {
            completionOverrides.removeValue(forKey: id)
        }

        let resolvedSummary = resolvedIDs.map { $0.uuidString.prefix(8) }.joined(separator: ",")
        logDebug("HOME_ROW_STATE vm.override_cleared ids=[\(resolvedSummary)]")
    }

    /// Executes summarizeRowState.
    private func summarizeRowState(_ tasks: [TaskDefinition], limit: Int = 4) -> String {
        let summary = tasks.prefix(limit).map { task in
            let state = task.isComplete ? "done" : "open"
            return "\(task.id.uuidString.prefix(8)):\(state):\(task.title)"
        }.joined(separator: "|")
        return "[\(summary)] total=\(tasks.count)"
    }

    private static func summaryDate(from dateStamp: String?) -> Date? {
        guard let dateStamp, dateStamp.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateStamp)
    }

    private static func summaryDateStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

// MARK: - View State

extension HomeViewModel {

    /// Combined state for the view.
    public var viewState: HomeViewState {
        HomeViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            selectedDate: selectedDate,
            selectedProject: selectedProject,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            dueTodayRows: dueTodayRows,
            dueTodaySection: dueTodaySection,
            todaySections: todaySections,
            focusNowSectionState: focusNowSectionState,
            todayAgendaSectionState: todayAgendaSectionState,
            rescueSectionState: rescueSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            upcomingTasks: upcomingTasks,
            completedTasks: completedTasks,
            doneTimelineTasks: doneTimelineTasks,
            projects: projects,
            dailyScore: dailyScore,
            streak: streak,
            completionRate: completionRate,
            activeQuickView: activeFilterState.quickView,
            activeScope: activeScope,
            selectedProjectIDs: activeFilterState.selectedProjectIDs,
            pointsPotential: pointsPotential,
            progressState: progressState,
            focusTasks: focusTasks,
            focusRows: focusRows,
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            quickViewCounts: quickViewCounts,
            savedHomeViews: savedHomeViews,
            emptyStateMessage: emptyStateMessage,
            emptyStateActionTitle: emptyStateActionTitle,
            showCompletedInline: activeFilterState.showCompletedInline,
            pinnedProjectIDs: activeFilterState.pinnedProjectIDs
        )
    }
}

/// State structure for the home view.
public struct HomeViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let selectedDate: Date
    public let selectedProject: String
    public let morningTasks: [TaskDefinition]
    public let eveningTasks: [TaskDefinition]
    public let overdueTasks: [TaskDefinition]
    public let dueTodayRows: [HomeTodayRow]
    public let dueTodaySection: HomeListSection?
    public let todaySections: [HomeListSection]
    public let focusNowSectionState: FocusNowSectionState
    public let todayAgendaSectionState: TodayAgendaSectionState
    public let rescueSectionState: RescueSectionState
    public let quietTrackingSummaryState: QuietTrackingSummaryState
    public let upcomingTasks: [TaskDefinition]
    public let completedTasks: [TaskDefinition]
    public let doneTimelineTasks: [TaskDefinition]
    public let projects: [Project]
    public let dailyScore: Int
    public let streak: Int
    public let completionRate: Double
    public let activeQuickView: HomeQuickView
    public let activeScope: HomeListScope
    public let selectedProjectIDs: [UUID]
    public let pointsPotential: Int
    public let progressState: HomeProgressState
    public let focusTasks: [TaskDefinition]
    public let focusRows: [HomeTodayRow]
    public let pinnedFocusTaskIDs: [UUID]
    public let quickViewCounts: [HomeQuickView: Int]
    public let savedHomeViews: [SavedHomeView]
    public let emptyStateMessage: String?
    public let emptyStateActionTitle: String?
    public let showCompletedInline: Bool
    public let pinnedProjectIDs: [UUID]
}

public struct HomeProgressState: Equatable {
    public let earnedXP: Int
    public let remainingPotentialXP: Int
    public let todayTargetXP: Int
    public let streakDays: Int
    public let isStreakSafeToday: Bool

    public static let empty = HomeProgressState(
        earnedXP: 0,
        remainingPotentialXP: 0,
        todayTargetXP: 0,
        streakDays: 0,
        isStreakSafeToday: false
    )

    public var progressFraction: Double {
        guard todayTargetXP > 0 else { return 0 }
        return min(1, Double(earnedXP) / Double(todayTargetXP))
    }
}

public struct SummaryTaskRow: Equatable, Identifiable {
    public let taskID: UUID
    public let title: String
    public let priority: TaskPriority
    public let dueDate: Date?
    public let isOverdue: Bool
    public let estimatedDuration: TimeInterval?
    public let isBlocked: Bool
    public let projectName: String?

    public var id: UUID { taskID }
}

public struct MorningPlanSummary: Equatable {
    public let date: Date
    public let openTodayCount: Int
    public let highPriorityCount: Int
    public let overdueCount: Int
    public let potentialXP: Int
    public let focusTasks: [SummaryTaskRow]
    public let blockedCount: Int
    public let longTaskCount: Int
    public let morningPlannedCount: Int
    public let eveningPlannedCount: Int
}

public struct NightlyRetrospectiveSummary: Equatable {
    public let date: Date
    public let completedCount: Int
    public let totalCount: Int
    public let xpEarned: Int
    public let completionRate: Double
    public let streakCount: Int
    public let biggestWins: [SummaryTaskRow]
    public let carryOverDueTodayCount: Int
    public let carryOverOverdueCount: Int
    public let tomorrowPreview: [SummaryTaskRow]
    public let morningCompletedCount: Int
    public let eveningCompletedCount: Int
}

public enum DailySummaryModalData: Equatable {
    case morning(MorningPlanSummary)
    case nightly(NightlyRetrospectiveSummary)

    public var analyticsSnapshot: [String: Any] {
        switch self {
        case .morning(let summary):
            return [
                "open_today_count": summary.openTodayCount,
                "high_priority_count": summary.highPriorityCount,
                "overdue_count": summary.overdueCount,
                "potential_xp": summary.potentialXP,
                "focus_count": summary.focusTasks.count,
                "blocked_count": summary.blockedCount,
                "long_task_count": summary.longTaskCount
            ]
        case .nightly(let summary):
            return [
                "completed_count": summary.completedCount,
                "total_count": summary.totalCount,
                "xp_earned": summary.xpEarned,
                "carry_over_due_today_count": summary.carryOverDueTodayCount,
                "carry_over_overdue_count": summary.carryOverOverdueCount,
                "tomorrow_preview_count": summary.tomorrowPreview.count,
                "streak_count": summary.streakCount
            ]
        }
    }
}

final class TaskListWidgetSnapshotService {
    static let shared = TaskListWidgetSnapshotService()

    private let queue = DispatchQueue(label: "tasker.tasklist.widget.snapshot", qos: .utility)
    private let debounceDelay: TimeInterval = 0.25
    private var pendingWorkItem: DispatchWorkItem?

    private init() {}

    func scheduleRefresh(reason: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.pendingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.refreshNow(reason: reason)
            }
            self.pendingWorkItem = workItem
            self.queue.asyncAfter(deadline: .now() + self.debounceDelay, execute: workItem)
        }
    }

    private func refreshNow(reason: String) {
        guard V2FeatureFlags.taskListWidgetsEnabled else { return }
        guard let coordinator = currentCoordinator() else { return }

        coordinator.getTasks.searchTasks(query: "", in: .all) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                logWarning(
                    event: "task_list_widget_snapshot_refresh_failed",
                    message: "Failed to refresh task list widget snapshot",
                    fields: [
                        "reason": reason,
                        "error": error.localizedDescription
                    ]
                )
            case .success(let tasks):
                let snapshot = self.buildSnapshot(tasks: tasks)
                self.persistIfChanged(snapshot: snapshot, reason: reason)
            }
        }
    }

    private func currentCoordinator() -> UseCaseCoordinator? {
        let container = PresentationDependencyContainer.shared
        guard container.isConfiguredForRuntime else { return nil }
        return container.coordinator
    }

    private func buildSnapshot(tasks: [TaskDefinition], now: Date = Date()) -> TaskListWidgetSnapshot {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let fortyEightHours = now.addingTimeInterval(48 * 60 * 60)

        let openTasks = tasks.filter { !$0.isComplete }
        let sortedOpen = openTasks.sorted(by: sortByPriorityThenDue)
        let overdueOpen = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            .sorted(by: sortByPriorityThenDue)
        let todayOpen = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfToday && dueDate < endOfToday
            }
            .sorted(by: sortByPriorityThenDue)
        let dueSoon = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= fortyEightHours
            }
            .sorted(by: sortByPriorityThenDue)
        let quickWins = openTasks
            .filter { task in
                guard let duration = task.estimatedDuration else { return false }
                let minutes = Int(duration / 60)
                return minutes > 0 && minutes <= 15
            }
            .sorted(by: sortByPriorityThenDue)
        let waitingOn = openTasks
            .filter { !$0.dependencies.isEmpty }
            .sorted(by: sortByPriorityThenDue)

        let completedToday = tasks
            .filter(\.isComplete)
            .filter { task in
                guard let completedAt = task.dateCompleted else { return false }
                return calendar.isDateInToday(completedAt)
            }
            .sorted(by: sortCompletedDescending)

        let focusNow = Array((todayOpen.isEmpty ? sortedOpen : todayOpen).prefix(3))
        let topTasks = Array((todayOpen + overdueOpen).isEmpty ? sortedOpen.prefix(3) : (todayOpen + overdueOpen).prefix(3))

        let projectSlices: [TaskListWidgetProjectSlice] = Dictionary(
            grouping: openTasks,
            by: { $0.projectID }
        )
        .map { projectID, projectTasks in
            let projectName = projectTasks.first?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TaskListWidgetProjectSlice(
                projectID: projectID,
                projectName: (projectName?.isEmpty == false ? projectName : nil) ?? "Inbox",
                openCount: projectTasks.count,
                overdueCount: projectTasks.filter(\.isOverdue).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.openCount != rhs.openCount {
                return lhs.openCount > rhs.openCount
            }
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        let energyBuckets: [TaskListWidgetEnergyBucket] = TaskEnergy.allCases.map { energy in
            TaskListWidgetEnergyBucket(
                energy: energy.rawValue,
                count: openTasks.filter { $0.energy == energy }.count
            )
        }

        return TaskListWidgetSnapshot(
            schemaVersion: TaskListWidgetSnapshot.currentSchemaVersion,
            updatedAt: now,
            todayTopTasks: topTasks.map(widgetTask(from:)),
            upcomingTasks: Array(dueSoon.prefix(3)).map(widgetTask(from:)),
            overdueTasks: Array(overdueOpen.prefix(3)).map(widgetTask(from:)),
            quickWins: Array(quickWins.prefix(3)).map(widgetTask(from:)),
            projectSlices: Array(projectSlices.prefix(6)),
            doneTodayCount: completedToday.count,
            focusNow: focusNow.map(widgetTask(from:)),
            waitingOn: Array(waitingOn.prefix(3)).map(widgetTask(from:)),
            energyBuckets: energyBuckets,
            openTodayCount: todayOpen.count + overdueOpen.count,
            openTaskPool: Array(sortedOpen.prefix(25)).map(widgetTask(from:)),
            completedTodayTasks: Array(completedToday.prefix(8)).map(widgetTask(from:)),
            snapshotHealth: TaskListWidgetSnapshotHealth(
                source: "full_query",
                generatedAt: now,
                isStale: false,
                hasCorruptionFallback: false
            )
        )
    }

    private func widgetTask(from task: TaskDefinition) -> TaskListWidgetTask {
        TaskListWidgetTask(
            id: task.id,
            title: task.title,
            projectID: task.projectID,
            projectName: task.projectName,
            priorityCode: task.priority.code,
            dueDate: task.dueDate,
            isOverdue: task.isOverdue,
            estimatedDurationMinutes: task.estimatedDuration.map { max(1, Int($0 / 60)) },
            energy: task.energy.rawValue,
            context: task.context.rawValue,
            isComplete: task.isComplete,
            hasDependencies: !task.dependencies.isEmpty
        )
    }

    private func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func sortCompletedDescending(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        let lhsDate = lhs.dateCompleted ?? Date.distantPast
        let rhsDate = rhs.dateCompleted ?? Date.distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func persistIfChanged(snapshot: TaskListWidgetSnapshot, reason: String) {
        let current = TaskListWidgetSnapshot.load()
        if normalized(snapshot) == normalized(current) {
            return
        }
        snapshot.save()
        reloadTaskListTimelines()
        logDebug("TASK_WIDGET_SNAPSHOT refreshed reason=\(reason)")
    }

    private func normalized(_ snapshot: TaskListWidgetSnapshot) -> TaskListWidgetSnapshot {
        var value = snapshot
        value.updatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.generatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.hasCorruptionFallback = false
        return value
    }

    private func reloadTaskListTimelines() {
        #if canImport(WidgetKit)
        let kinds = [
            "TopTaskNowWidget", "TodayCounterNextWidget", "OverdueRescueWidget", "QuickWin15mWidget",
            "MorningKickoffWidget", "EveningWrapWidget", "WaitingOnWidget", "InboxTriageWidget",
            "DueSoonRadarWidget", "EnergyMatchWidget", "ProjectSpotlightWidget", "CalendarTaskBridgeWidget",
            "TodayTop3Widget", "NowLaneWidget", "OverdueBoardWidget", "Upcoming48hWidget",
            "MorningEveningPlanWidget", "QuickViewSwitcherWidget", "ProjectSprintWidget",
            "PriorityMatrixLiteWidget", "ContextWidget", "FocusSessionQueueWidget",
            "RecoveryWidget", "DoneReflectionWidget",
            "TodayPlannerBoardWidget", "WeekTaskPlannerWidget", "ProjectCockpitWidget",
            "BacklogHealthWidget", "KanbanLiteWidget", "DeadlineHeatmapWidget",
            "ExecutionDashboardWidget", "DeepWorkAgendaWidget", "AssistantPlanPreviewWidget",
            "LifeAreasBoardWidget",
            "InlineNextTaskWidget", "InlineDueSoonWidget",
            "CircularTodayProgressWidget", "CircularQuickAddWidget",
            "RectangularTop2TasksWidget", "RectangularOverdueAlertWidget",
            "RectangularFocusNowWidget", "RectangularWaitingOnWidget",
            "DeskTodayBoardWidget", "CountdownPanelWidget", "NightlyResetWidget",
            "MorningBriefPanelWidget", "ProjectPulseWidget", "FocusDockWidget"
        ]
        DispatchQueue.main.async {
            let center = WidgetCenter.shared
            for kind in kinds {
                center.reloadTimelines(ofKind: kind)
            }
        }
        #endif
    }
}

enum DailySummaryModalError: LocalizedError {
    case tasksUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .tasksUnavailable(let message):
            return message
        }
    }
}

final class GetDailySummaryModalUseCase {
    private let getTasksUseCase: GetTasksUseCase
    private let analyticsUseCase: CalculateAnalyticsUseCase
    private let calendar: Calendar
    private let now: () -> Date

    init(
        getTasksUseCase: GetTasksUseCase,
        analyticsUseCase: CalculateAnalyticsUseCase,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.getTasksUseCase = getTasksUseCase
        self.analyticsUseCase = analyticsUseCase
        self.calendar = calendar
        self.now = now
    }

    func execute(
        kind: TaskerDailySummaryKind,
        date: Date,
        completion: @escaping (Result<DailySummaryModalData, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()

        var allTasksResult: Result<[TaskDefinition], GetTasksError>?
        var analytics: DailyAnalytics?
        var streakCount: Int?
        var dateTasks: DateTasksResult?

        group.enter()
        getTasksUseCase.searchTasks(query: "", in: .all) { result in
            lock.lock()
            allTasksResult = result
            lock.unlock()
            group.leave()
        }

        group.enter()
        analyticsUseCase.calculateDailyAnalytics(for: date) { result in
            lock.lock()
            if case .success(let value) = result {
                analytics = value
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        analyticsUseCase.calculateStreak { result in
            lock.lock()
            if case .success(let value) = result {
                streakCount = value.currentStreak
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        getTasksUseCase.getTasksForDate(date) { result in
            lock.lock()
            if case .success(let value) = result {
                dateTasks = value
            }
            lock.unlock()
            group.leave()
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            lock.lock()
            let resolvedTasksResult = allTasksResult
            let resolvedAnalytics = analytics
            let resolvedStreak = streakCount
            let resolvedDateTasks = dateTasks
            lock.unlock()

            guard let resolvedTasksResult else {
                completion(.failure(DailySummaryModalError.tasksUnavailable("Task data unavailable")))
                return
            }

            switch resolvedTasksResult {
            case .failure(let error):
                completion(.failure(DailySummaryModalError.tasksUnavailable(error.localizedDescription)))
            case .success(let allTasks):
                completion(.success(
                    self.buildSummary(
                        kind: kind,
                        date: date,
                        allTasks: allTasks,
                        analytics: resolvedAnalytics,
                        streakCount: resolvedStreak,
                        dateTasks: resolvedDateTasks
                    )
                ))
            }
        }
    }

    func buildSummary(
        kind: TaskerDailySummaryKind,
        date: Date,
        allTasks: [TaskDefinition],
        analytics: DailyAnalytics?,
        streakCount: Int?,
        dateTasks: DateTasksResult? = nil
    ) -> DailySummaryModalData {
        switch kind {
        case .morning:
            return .morning(buildMorningSummary(date: date, allTasks: allTasks, dateTasks: dateTasks))
        case .nightly:
            return .nightly(
                buildNightlySummary(
                    date: date,
                    allTasks: allTasks,
                    analytics: analytics,
                    streakCount: streakCount,
                    dateTasks: dateTasks
                )
            )
        }
    }

    private func buildMorningSummary(
        date: Date,
        allTasks: [TaskDefinition],
        dateTasks: DateTasksResult?
    ) -> MorningPlanSummary {
        let dayRange = dateRange(for: date)
        let openTasks = allTasks.filter { !$0.isComplete }
        let dueTodayOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }
        let overdueOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < dayRange.start
        }
        let actionable = sortByUrgency(tasks: dueTodayOpen + overdueOpen)
        let focusTasks = Array(actionable.prefix(3)).map(makeSummaryRow)
        let highPriorityCount = actionable.filter { $0.priority.isHighPriority }.count
        let potentialXP = actionable.reduce(0) { $0 + $1.priority.scorePoints }
        let blockedCount = actionable.filter { !$0.dependencies.isEmpty }.count
        let longTaskCount = actionable.filter { ($0.estimatedDuration ?? 0) >= 3600 }.count
        let morningPlannedCount: Int
        let eveningPlannedCount: Int
        if let dateTasks {
            morningPlannedCount = dateTasks.morningTasks.filter { !$0.isComplete }.count
            eveningPlannedCount = dateTasks.eveningTasks.filter { !$0.isComplete }.count
        } else {
            eveningPlannedCount = dueTodayOpen.filter(isEveningTask).count
            morningPlannedCount = max(0, dueTodayOpen.count - eveningPlannedCount)
        }

        return MorningPlanSummary(
            date: dayRange.start,
            openTodayCount: actionable.count,
            highPriorityCount: highPriorityCount,
            overdueCount: overdueOpen.count,
            potentialXP: potentialXP,
            focusTasks: focusTasks,
            blockedCount: blockedCount,
            longTaskCount: longTaskCount,
            morningPlannedCount: morningPlannedCount,
            eveningPlannedCount: eveningPlannedCount
        )
    }

    private func buildNightlySummary(
        date: Date,
        allTasks: [TaskDefinition],
        analytics: DailyAnalytics?,
        streakCount: Int?,
        dateTasks: DateTasksResult?
    ) -> NightlyRetrospectiveSummary {
        let dayRange = dateRange(for: date)
        let tomorrowStart = dayRange.end
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart

        let completedToday = sortByUrgency(tasks: allTasks.filter { task in
            guard task.isComplete, let dateCompleted = task.dateCompleted else { return false }
            return dateCompleted >= dayRange.start && dateCompleted < dayRange.end
        })

        let openTasks = allTasks.filter { !$0.isComplete }
        let dueTodayOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }
        let overdueOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < dayRange.start
        }
        let tomorrowPreview = sortByUrgency(tasks: openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= tomorrowStart && dueDate < tomorrowEnd
        })

        let dueTodayCount = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }.count
        let calendarTotalCount = dateTasks.map {
            $0.morningTasks.count + $0.eveningTasks.count + $0.completedTasks.count
        } ?? 0
        let analyticsTotalCount = analytics?.totalTasks ?? 0
        let baselineTotalCount = max(dueTodayCount, max(calendarTotalCount, analyticsTotalCount))
        let totalCount = max(completedToday.count, baselineTotalCount)
        let xpEarned = completedToday.reduce(0) { $0 + $1.priority.scorePoints }
        let fallbackCompletionRate = totalCount > 0 ? Double(completedToday.count) / Double(totalCount) : 0
        let completionRate = analytics?.completionRate ?? fallbackCompletionRate
        let morningCompletedCount = analytics?.morningTasksCompleted
            ?? completedToday.filter { !$0.isEveningTask && $0.type != .evening }.count
        let eveningCompletedCount = analytics?.eveningTasksCompleted
            ?? completedToday.filter(isEveningTask).count

        return NightlyRetrospectiveSummary(
            date: dayRange.start,
            completedCount: completedToday.count,
            totalCount: totalCount,
            xpEarned: xpEarned,
            completionRate: completionRate,
            streakCount: max(0, streakCount ?? 0),
            biggestWins: Array(completedToday.prefix(3)).map(makeSummaryRow),
            carryOverDueTodayCount: dueTodayOpen.count,
            carryOverOverdueCount: overdueOpen.count,
            tomorrowPreview: Array(tomorrowPreview.prefix(3)).map(makeSummaryRow),
            morningCompletedCount: morningCompletedCount,
            eveningCompletedCount: eveningCompletedCount
        )
    }

    private func makeSummaryRow(_ task: TaskDefinition) -> SummaryTaskRow {
        let startOfToday = calendar.startOfDay(for: now())
        let overdue = (task.dueDate.map { $0 < startOfToday } ?? false) && !task.isComplete
        return SummaryTaskRow(
            taskID: task.id,
            title: task.title,
            priority: task.priority,
            dueDate: task.dueDate,
            isOverdue: overdue,
            estimatedDuration: task.estimatedDuration,
            isBlocked: !task.dependencies.isEmpty,
            projectName: task.projectName
        )
    }

    private func sortByUrgency(tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func dateRange(for date: Date) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func isEveningTask(_ task: TaskDefinition) -> Bool {
        task.isEveningTask || task.type == .evening
    }
}
