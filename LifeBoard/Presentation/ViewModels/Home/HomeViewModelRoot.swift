//
//  HomeViewModel.swift
//  LifeBoard
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

@MainActor
public final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties (Observable State)

    @Published public internal(set) var todayTasks: TodayTasksResult?

    @Published public internal(set) var selectedProject: String = "All"

    @Published public internal(set) var isLoading: Bool = false

    @Published public internal(set) var errorMessage: String?

    @Published public internal(set) var dailyScore: Int = 0

    @Published public internal(set) var streak: Int = 0

    @Published public internal(set) var completionRate: Double = 0.0

    @Published public internal(set) var currentLevel: Int = 1

    @Published public internal(set) var totalXP: Int64 = 0

    @Published public internal(set) var nextLevelXP: Int64 = 0

    @Published public internal(set) var insightsLaunchRequest: InsightsLaunchRequest?

    @Published public internal(set) var insightsLaunchToken: UUID?

    @Published public internal(set) var habitRecoveryReflectionPrompt: HabitRecoveryReflectionPrompt?

    // TaskDefinition lists by category

    @Published public internal(set) var morningTasks: [TaskDefinition] = []

    @Published public internal(set) var eveningTasks: [TaskDefinition] = []

    @Published public internal(set) var overdueTasks: [TaskDefinition] = []

    @Published public internal(set) var dailyCompletedTasks: [TaskDefinition] = []

    @Published public internal(set) var upcomingTasks: [TaskDefinition] = []

    @Published public internal(set) var completedTasks: [TaskDefinition] = []
    @Published public internal(set) var doneTimelineTasks: [TaskDefinition] = []

    @Published public internal(set) var lifeAreas: [LifeArea] = []

    @Published public internal(set) var habitMutationFeedback: HomeHabitMutationFeedback?

    @Published public internal(set) var quickViewCounts: [HomeQuickView: Int] = [:]

    @Published public internal(set) var pointsPotential: Int = 0

    @Published public internal(set) var progressState: HomeProgressState = .empty

    @Published public internal(set) var focusTasks: [TaskDefinition] = []

    @Published public internal(set) var focusWhyShuffleCandidates: [TaskDefinition] = []

    @Published public internal(set) var emptyStateMessage: String?

    @Published public internal(set) var emptyStateActionTitle: String?

    @Published public internal(set) var focusEngineEnabled: Bool = true

    @Published public internal(set) var evaHomeInsights: EvaHomeInsights?

    @Published var homeRenderTransaction: HomeRenderTransaction = .empty

    // Next Action Module: total open tasks for today

    @Published public internal(set) var projects: [Project] = []

    @Published public internal(set) var tags: [TagDefinition] = []

    @Published public internal(set) var selectedProjectTasks: [TaskDefinition] = []

    // MARK: - Dependencies

    let useCaseCoordinator: UseCaseCoordinator

    let homeFilteredTasksUseCase: GetHomeFilteredTasksUseCase

    let computeEvaHomeInsightsUseCase: ComputeEvaHomeInsightsUseCase

    let getOverdueRescuePlanUseCase: GetOverdueRescuePlanUseCase

    let buildEvaBatchProposalUseCase: BuildEvaBatchProposalUseCase

    let getDailySummaryModalUseCase: GetDailySummaryModalUseCase

    let buildHomeAgendaUseCase: BuildHomeAgendaUseCase

    let buildHabitHomeProjectionUseCase: BuildHabitHomeProjectionUseCase

    let resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase

    let calendarIntegrationService: CalendarIntegrationService

    let savedHomeViewRepository: SavedHomeViewRepositoryProtocol

    let analyticsService: AnalyticsServiceProtocol?

    let aiSuggestionService: AISuggestionService?

    let userDefaults: UserDefaults

    let workspacePreferencesProvider: () -> LifeBoardWorkspacePreferences

    let hiddenCalendarEventStore: HomeTimelineHiddenCalendarEventStore

    let timelineProjectionBuilder = HomeTimelineProjectionBuilder()

    let needsReplanViewModel: HomeNeedsReplanViewModel

    var cancellables = Set<AnyCancellable>()

    var retainedInsightsViewModel: InsightsViewModel?

    var retainedHomeSearchViewModel: HomeSearchViewModel?

    var cachedGlobalReplanRevision: HomeDataRevision?

    var activeGlobalReplanFetchToken: UUID?

    var activeGlobalReplanFetchRevision: HomeDataRevision?

    var pendingGlobalReplanRefreshRevision: HomeDataRevision?

    var latestFocusOpenTasks: [TaskDefinition] = []

    /// Most recent per-project activity (open count + nearest due) used to auto-fill the lens row.
    /// Refreshed whenever we have the unfiltered forward open-task set (Upcoming lens).
    var cachedLifeAreaLensActivity: [UUID: HomeLensLifeAreaActivity] = [:]

    // MARK: - Persistence Keys

    static let lastFilterStateKey = "home.focus.lastFilterState.v2"

    static let pinnedFocusTaskIDsKey = "home.focus.pinnedTaskIDs.v2"

    static let recentShuffleTaskIDsKey = "home.eva.recentShuffleTaskIDs.v1"

    static let maxPinnedFocusTasks = 3

    static let maxShuffleHistorySize = 10

    static let defaultShuffleExclusionWindow = 3

    static let maxInlineCompletedRetention = 24

    // MARK: - Session State

    var homeOpenedAt: Date = Date()

    var didTrackFirstCompletionLatency = false

    var completionOverrides: [UUID: Bool] = [:]

    var pendingHabitMutationKeys: Set<HomeHabitMutationKey> = []

    var pendingHabitMutationSnapshots: [HomeHabitMutationKey: HomeHabitMutationSnapshot] = [:]

    var pendingHabitMutationIntervals: [HomeHabitMutationKey: LifeBoardPerformanceInterval] = [:]

    var selfOriginatedHabitMutationContextIDs: Set<UUID> = []

    var reloadGeneration: Int = 0

    var dataRevision: HomeDataRevision = .zero

    var timelineSnapshotCache: (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot)?

    var timelineProjectionTasks: [TaskDefinition] = []

    var timelineProjectionCacheKey: String?

    var timelineProjectionSelectedDay: Date?

    /// Filter/revision the cached projection was loaded under, so the fast-path can
    /// detect when the cache is stale even though the selected day is unchanged.
    var timelineProjectionRevision: HomeDataRevision?

    var timelineProjectionProjectIDs: [UUID]?

    var timelineProjectionRequestKey: String?

    var timelineProjectionRequestToken: UUID?

    var suppressCompletionReloadUntil: Date?

    var suppressTaskReloadsForHabitMutationUntil: Date?

    var lastRecurringTopUpAt: Date?

    var pendingRecurringTopUpTask: Task<Void, Never>?

    var pendingAdjacentDayPrefetchTask: Task<Void, Never>?

    var recentShuffledFocusTaskIDs: [UUID] = []

    let completionNotificationDebounceMS = 120

    let completionReloadSuppressionSeconds: TimeInterval = 0.35

    let habitMutationReloadSuppressionSeconds: TimeInterval = 0.75

    let mutationNotificationDebounceMS = 90

    let reloadDebounceMS = 120

    let analyticsDebounceMS = 120

    static let recurringTopUpDelay: Duration = .seconds(5)

    let recurringTopUpThrottleSeconds: TimeInterval = 90

    let ledgerMutationWatchdogDelaySeconds: TimeInterval = 1.0

    static let mutationNotificationSource = "homeViewModel"

    var pendingLedgerMutationWatchdogTask: Task<Void, Never>?

    var pendingLedgerMutationWatchdogID: Int = 0

    var lastLedgerMutationObservedAt: Date = .distantPast

    var pendingReloadTask: Task<Void, Never>?

    var pendingReloadDebounceID: Int = 0

    var pendingReloadSources: Set<String> = []

    var pendingReloadReasons: Set<HomeTaskMutationEvent> = []

    var pendingReloadScopes: Set<HomeReloadScope> = []

    var pendingReloadTaskIDs: Set<UUID> = []

    var pendingReloadInvalidateCaches = false

    var pendingReloadIncludeAnalytics = false

    var pendingReloadRepostEvent = false

    var isApplyingReloadBatch = false

    var queuedReloadAfterCurrentBatch = false

    var pendingAnalyticsTask: Task<Void, Never>?

    var pendingDeferredAnalyticsRefreshTask: Task<Void, Never>?

    var pendingAnalyticsIncludeGamificationRefresh = false

    var pendingAnalyticsCompletions: [@Sendable () -> Void] = []

    var analyticsGeneration: Int = 0

    var weeklySummaryGeneration: Int = 0

    var pendingHomeRenderStateWorkItem: DispatchWorkItem?

    var homeRenderStateRefreshBatchDepth: Int = 0

    var needsHomeRenderStateRefresh = false

    /// True once the user dismisses the Resume prompt; resets next launch.
    var resumeDismissedForSession = false

    var pendingHomeRenderInvalidation: HomeRenderInvalidation = .all

    var currentHabitSignals: [LifeBoardHabitSignal] = []

    var habitLibraryRowsByID: [UUID: HabitLibraryRow] = [:]

    var taskRowsDerivationRevision: UInt64 = 0

    var habitRowsDerivationRevision: UInt64 = 0

    var cachedOpenTaskRowsForHabitMutation: HomeDerivedTaskRowsCache?

    var cachedMergedHabitRows: HomeDerivedHabitRowsCache?

    var evaInsightsGeneration: Int = 0

    var lastTaskListSnapshotRevision: HomeDataRevision?

    var catchUpReflectionPreviewTask: Task<Void, Never>?

    var catchUpReflectionPreviewKey: String?

    var reflectionContextPrefetchTask: Task<Void, Never>?

    var reflectionContextPrefetchKey: String?

    static let reflectionContextPrefetchDelay: Duration = .milliseconds(250)

    init(
        useCaseCoordinator: UseCaseCoordinator,
        savedHomeViewRepository: SavedHomeViewRepositoryProtocol = UserDefaultsSavedHomeViewRepository(),
        analyticsService: AnalyticsServiceProtocol? = nil,
        aiSuggestionService: AISuggestionService? = nil,
        workspacePreferencesProvider: @escaping () -> LifeBoardWorkspacePreferences = { LifeBoardWorkspacePreferencesStore.shared.load() },
        userDefaults: UserDefaults = .standard,
        hiddenCalendarEventStore: HomeTimelineHiddenCalendarEventStore? = nil
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.homeFilteredTasksUseCase = useCaseCoordinator.getHomeFilteredTasks
        self.computeEvaHomeInsightsUseCase = useCaseCoordinator.computeEvaHomeInsights
        self.getOverdueRescuePlanUseCase = useCaseCoordinator.getOverdueRescuePlan
        self.buildEvaBatchProposalUseCase = useCaseCoordinator.buildEvaBatchProposal
        self.buildHomeAgendaUseCase = BuildHomeAgendaUseCase()
        self.buildHabitHomeProjectionUseCase = useCaseCoordinator.buildHabitHomeProjection
        self.resetHabitOccurrenceUseCase = useCaseCoordinator.resetHabitOccurrence
        self.calendarIntegrationService = useCaseCoordinator.calendarIntegrationService
        self.getDailySummaryModalUseCase = GetDailySummaryModalUseCase(
            getTasksUseCase: useCaseCoordinator.getTasks,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics
        )
        self.savedHomeViewRepository = savedHomeViewRepository
        self.analyticsService = analyticsService
        self.aiSuggestionService = aiSuggestionService
        self.workspacePreferencesProvider = workspacePreferencesProvider
        self.userDefaults = userDefaults
        self.needsReplanViewModel = HomeNeedsReplanViewModel(userDefaults: userDefaults)
        self.hiddenCalendarEventStore = hiddenCalendarEventStore ?? HomeTimelineHiddenCalendarEventStore(defaults: userDefaults)
        self.hiddenHomeTimelineCalendarEvents = self.hiddenCalendarEventStore.load()
        self.homeCalendarSnapshot = Self.buildHomeCalendarSnapshot(
            from: calendarIntegrationService.snapshot,
            selectedDate: selectedDate,
            accessAction: calendarIntegrationService.accessAction(
                for: calendarIntegrationService.snapshot.authorizationStatus
            )
        )

        setupBindings()
        loadInitialData()
    }

    @Published public internal(set) var selectedDate: Date = Date() {
        didSet {
            refreshPassiveNeedsReplanState()
            scheduleHomeRenderStateRefresh(.all)
        }
    }

    @Published public internal(set) var weeklySummary: HomeWeeklySummary? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    @Published public internal(set) var weeklySummaryIsLoading: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    @Published public internal(set) var weeklySummaryErrorMessage: String? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    // Gamification v2

    @Published public internal(set) var lastXPResult: XPEventResult? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published public internal(set) var dueTodayRows: [HomeTodayRow] = [] {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }

    @Published public internal(set) var dueTodaySection: HomeListSection? {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }

    @Published public internal(set) var todaySections: [HomeListSection] = [] {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks, .timeline]) }
    }

    @Published public internal(set) var focusNowSectionState = FocusNowSectionState(rows: [], pinnedTaskIDs: []) {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }

    @Published public internal(set) var todayAgendaSectionState = TodayAgendaSectionState(sections: []) {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }

    @Published public internal(set) var agendaTailItems: [HomeAgendaTailItem] = [] {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }

    @Published public internal(set) var habitHomeSectionState = HabitHomeSectionState(primaryRows: [], recoveryRows: []) {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .habits]) }
    }

    @Published public internal(set) var quietTrackingSummaryState = QuietTrackingSummaryState(stableRows: []) {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .habits]) }
    }

    @Published public internal(set) var habitMutationErrorMessage: String? {
        didSet {
            guard oldValue != habitMutationErrorMessage else { return }
            scheduleHomeRenderStateRefresh(.habits)
        }
    }

    // Focus Engine

    @Published public internal(set) var activeFilterState: HomeFilterState = .default {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks]) }
    }

    @Published public internal(set) var savedHomeViews: [SavedHomeView] = [] {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    @Published public internal(set) var focusRows: [HomeTodayRow] = [] {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks, .timeline]) }
    }

    @Published public internal(set) var pinnedFocusTaskIDs: [UUID] = [] {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }

    @Published public internal(set) var activeScope: HomeListScope = .today {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks]) }
    }

    @Published public internal(set) var evaFocusWhySheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published public internal(set) var evaRescueSheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published public internal(set) var evaRescueLauncherState: HomeOverdueRescueLauncherState = .idle {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published public internal(set) var evaRescuePlan: EvaRescuePlan? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published public internal(set) var evaLastBatchRunID: UUID? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }

    @Published var homeReplanState: HomeReplanSessionState = .hidden {
        didSet { scheduleHomeRenderStateRefresh([.overlay, .timeline]) }
    }

    @Published var homeCalendarSnapshot: HomeCalendarSnapshot = .empty {
        didSet { scheduleHomeRenderStateRefresh([.calendar, .timeline]) }
    }

    @Published var hiddenHomeTimelineCalendarEvents: Set<HomeTimelineHiddenCalendarEventKey> = [] {
        didSet { scheduleHomeRenderStateRefresh(.timeline) }
    }

    @Published var catchUpDailyReflectionEntryPreview: DailyReflectionEntryState? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    public var todayOpenTaskCount: Int {
        if activeScope.quickView == .today, !todaySections.isEmpty {
            let agendaOpenTaskIDs = Set(
                todaySections
                    .flatMap(\.rows)
                    .compactMap(Self.openTaskID(for:))
            )
            let visibleFocusOpenTaskIDs = Set(
                focusRows
                    .compactMap(Self.openTaskID(for:))
            )
            return agendaOpenTaskIDs.union(visibleFocusOpenTaskIDs).count
        }
        return (morningTasks + eveningTasks).filter { !$0.isComplete }.count
    }

    // Projects
    var needsReplanCandidates: [HomeReplanCandidate] {
        get { needsReplanViewModel.passiveCandidates }
        set { needsReplanViewModel.passiveCandidates = newValue }
    }

    var activeReplanCandidates: [HomeReplanCandidate] {
        get { needsReplanViewModel.activeCandidates }
        set { needsReplanViewModel.activeCandidates = newValue }
    }

    var replanUndoStack: [HomeReplanUndoEntry] {
        get { needsReplanViewModel.undoStack }
        set { needsReplanViewModel.undoStack = newValue }
    }

    var replanApplyingAction: HomeReplanApplyingAction? {
        get { needsReplanViewModel.applyingAction }
        set { needsReplanViewModel.applyingAction = newValue }
    }

    static let reflectionContextPrefetchTimeoutSeconds: TimeInterval = 0.8

    deinit {
        pendingRecurringTopUpTask?.cancel()
        pendingAdjacentDayPrefetchTask?.cancel()
        catchUpReflectionPreviewTask?.cancel()
        reflectionContextPrefetchTask?.cancel()
    }

}
