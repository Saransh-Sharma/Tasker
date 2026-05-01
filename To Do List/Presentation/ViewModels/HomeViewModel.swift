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
    case habits
    case facets
    case analytics
    case charts
    case savedViews
}

public enum HomeDateNavigationSource: String {
    case datePicker
    case weekStrip
    case swipe
    case backToToday
    case replan
    case dailyReflection
}

public enum HomeDayNavigationDirection: Equatable {
    case previous
    case next
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

private struct HomeRenderInvalidation: OptionSet {
    let rawValue: Int

    static let chrome = HomeRenderInvalidation(rawValue: 1 << 0)
    static let tasks = HomeRenderInvalidation(rawValue: 1 << 1)
    static let habits = HomeRenderInvalidation(rawValue: 1 << 2)
    static let calendar = HomeRenderInvalidation(rawValue: 1 << 3)
    static let overlay = HomeRenderInvalidation(rawValue: 1 << 4)
    static let timeline = HomeRenderInvalidation(rawValue: 1 << 5)

    static let all: HomeRenderInvalidation = [.chrome, .tasks, .habits, .calendar, .overlay, .timeline]

    func includes(_ other: HomeRenderInvalidation) -> Bool {
        intersection(other).isEmpty == false
    }
}

private struct HomeTimelineWorkspacePreferencesSignature: Equatable {
    let weekStartsOn: Weekday
    let showCalendarEventsInTimeline: Bool
    let riseAndShineHour: Int
    let riseAndShineMinute: Int
    let windDownHour: Int
    let windDownMinute: Int

    init(_ preferences: TaskerWorkspacePreferences) {
        weekStartsOn = preferences.weekStartsOn
        showCalendarEventsInTimeline = preferences.showCalendarEventsInTimeline
        riseAndShineHour = preferences.timelineRiseAndShineHour
        riseAndShineMinute = preferences.timelineRiseAndShineMinute
        windDownHour = preferences.timelineWindDownHour
        windDownMinute = preferences.timelineWindDownMinute
    }
}

private struct HomeTimelineEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: TaskerCalendarEventAvailability
    let status: TaskerCalendarEventStatus
    let participationStatus: TaskerCalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: TaskerCalendarEventSnapshot) {
        id = event.id
        calendarID = event.calendarID
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        availability = event.availability
        status = event.eventStatus
        participationStatus = event.participationStatus
        lastModifiedAt = event.lastModifiedAt
    }
}

private struct HomeTimelineSnapshotCacheKey: Equatable {
    let dataRevision: HomeDataRevision
    let selectedDay: Date
    let currentMinuteStamp: Int
    let foredropAnchor: ForedropAnchor
    let calendarSignature: HomeTimelineCalendarSignature
    let workspacePreferences: HomeTimelineWorkspacePreferencesSignature
    let hiddenCalendarEvents: [HomeTimelineHiddenCalendarEventKey]
    let pinnedFocusTaskIDs: [UUID]
    let needsReplanCandidates: [HomeTimelineReplanCandidateSignature]
    let replanState: HomeTimelineReplanStateSignature
}

private struct HomeTimelineCalendarSignature: Equatable {
    let moduleState: HomeCalendarModuleState
    let selectedDate: Date
    let selectedDayEvents: [HomeTimelineEventSignature]
    let selectedDayTimelineEvents: [HomeTimelineEventSignature]
    let isLoading: Bool
    let errorMessage: String?

    init(_ snapshot: HomeCalendarSnapshot) {
        moduleState = snapshot.moduleState
        selectedDate = snapshot.selectedDate
        selectedDayEvents = snapshot.selectedDayEvents.map(HomeTimelineEventSignature.init)
        selectedDayTimelineEvents = snapshot.selectedDayTimelineEvents.map(HomeTimelineEventSignature.init)
        isLoading = snapshot.isLoading
        errorMessage = snapshot.errorMessage
    }
}

private struct HomeTimelineReplanCandidateSignature: Equatable {
    let taskID: UUID
    let kind: HomeReplanCandidateKind
    let anchorDate: Date?
    let anchorEndDate: Date?

    init(_ candidate: HomeReplanCandidate) {
        taskID = candidate.task.id
        kind = candidate.kind
        anchorDate = candidate.anchorDate
        anchorEndDate = candidate.anchorEndDate
    }
}

private enum HomeTimelineReplanPhaseSignature: Equatable {
    case trayHidden
    case trayVisible(total: Int)
    case launcher(total: Int)
    case card(candidateIndex: Int)
    case placement(candidateID: UUID, defaultDay: Date)
    case summary(totalResolved: Int, skippedCount: Int)
    case skippedReview

    init(_ phase: HomeReplanSessionPhase) {
        switch phase {
        case .trayHidden:
            self = .trayHidden
        case .trayVisible(let summary):
            self = .trayVisible(total: summary.count)
        case .launcher(let summary):
            self = .launcher(total: summary.count)
        case .card(let candidateIndex):
            self = .card(candidateIndex: candidateIndex)
        case .placement(let candidate, let defaultDay):
            self = .placement(candidateID: candidate.id, defaultDay: defaultDay)
        case .summary(let outcomes, let skippedCount):
            self = .summary(totalResolved: outcomes.totalResolved, skippedCount: skippedCount)
        case .skippedReview:
            self = .skippedReview
        }
    }
}

private struct HomeTimelineReplanStateSignature: Equatable {
    let phase: HomeTimelineReplanPhaseSignature
    let currentCandidateID: UUID?
    let candidateIndex: Int
    let candidateTotal: Int
    let isApplying: Bool
    let applyingAction: HomeReplanApplyingAction?
    let errorMessage: String?
    let placementCandidate: TimelinePlacementCandidate?

    init(_ state: HomeReplanSessionState) {
        phase = HomeTimelineReplanPhaseSignature(state.phase)
        currentCandidateID = state.currentCandidate?.id
        candidateIndex = state.candidateIndex
        candidateTotal = state.candidateTotal
        isApplying = state.isApplying
        applyingAction = state.applyingAction
        errorMessage = state.errorMessage
        placementCandidate = state.placementCandidate
    }
}

private enum HomeReplanResolutionKind: Equatable {
    case rescheduled
    case movedToInbox
    case completed
    case deleted
}

private struct HomeReplanUndoEntry: Equatable {
    let runID: UUID
    let action: HomeReplanResolutionKind
    let candidate: HomeReplanCandidate
}

public struct HabitRecoveryReflectionPrompt: Equatable, Identifiable {
    public let habitID: UUID
    public let habitTitle: String
    public let date: Date

    public init(habitID: UUID, habitTitle: String, date: Date) {
        self.habitID = habitID
        self.habitTitle = habitTitle
        self.date = date
    }

    public var id: String {
        "\(habitID.uuidString):\(date.timeIntervalSince1970)"
    }
}

public enum HomeHabitMutationFeedbackHaptic: Equatable {
    case selection
    case success
    case warning
}

public struct HomeHabitMutationFeedback: Equatable, Identifiable {
    public let id: UUID
    public let message: String
    public let haptic: HomeHabitMutationFeedbackHaptic

    public init(
        id: UUID = UUID(),
        message: String,
        haptic: HomeHabitMutationFeedbackHaptic
    ) {
        self.id = id
        self.message = message
        self.haptic = haptic
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

private enum HomeHabitMutationRequest {
    case resolve(HabitOccurrenceAction)
    case reset
}

private struct HomeHabitMutationKey: Hashable {
    let habitID: UUID
    let day: Date
}

private struct HomeHabitMutationSnapshot {
    let dueTodayRows: [HomeTodayRow]
    let dueTodaySection: HomeListSection?
    let todayAgendaSectionState: TodayAgendaSectionState
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let focusRows: [HomeTodayRow]
    let focusNowSectionState: FocusNowSectionState
    let currentHabitSignals: [TaskerHabitSignal]
}

private struct HomeDerivedTaskRowsCache {
    let revision: UInt64
    let quickView: HomeQuickView
    let rows: [TaskDefinition]
}

private struct HomeDerivedHabitRowsCache {
    let revision: UInt64
    let rows: [HomeHabitRow]
}

private struct HomeHabitMutationSectionPatch {
    let allHabitRows: [HomeHabitRow]
    let dueTodayRows: [HomeTodayRow]
    let dueTodaySection: HomeListSection?
    let habitHomeSectionState: HabitHomeSectionState
    let quietTrackingSummaryState: QuietTrackingSummaryState
    let focusRows: [HomeTodayRow]?
    let focusNowSectionState: FocusNowSectionState?
    let currentHabitSignals: [TaskerHabitSignal]
    let affectedRowCount: Int
    let affectedSectionCount: Int
}

private enum HomeHabitRowPlacementBucket {
    case primary
    case recovery
    case quiet
}

private struct HomeHabitRowPlacement {
    let bucket: HomeHabitRowPlacementBucket
    let index: Int
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
        didSet {
            refreshPassiveNeedsReplanState()
            scheduleHomeRenderStateRefresh(.all)
        }
    }
    @Published public private(set) var selectedProject: String = "All"
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var dailyScore: Int = 0
    @Published public private(set) var streak: Int = 0
    @Published public private(set) var completionRate: Double = 0.0
    @Published public private(set) var weeklySummary: HomeWeeklySummary? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }
    @Published public private(set) var weeklySummaryIsLoading: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }
    @Published public private(set) var weeklySummaryErrorMessage: String? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    // Gamification v2
    @Published public private(set) var currentLevel: Int = 1
    @Published public private(set) var dailyXPCap: Int = GamificationTokens.dailyXPCap
    @Published public private(set) var totalXP: Int64 = 0
    @Published public private(set) var nextLevelXP: Int64 = 0
    @Published public private(set) var lastXPResult: XPEventResult? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var insightsLaunchRequest: InsightsLaunchRequest?
    @Published public private(set) var insightsLaunchToken: UUID?
    @Published public private(set) var habitRecoveryReflectionPrompt: HabitRecoveryReflectionPrompt?

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
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }
    @Published public private(set) var dueTodaySection: HomeListSection? {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }
    @Published public private(set) var todaySections: [HomeListSection] = [] {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }
    @Published public private(set) var focusNowSectionState = FocusNowSectionState(rows: [], pinnedTaskIDs: []) {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }
    @Published public private(set) var todayAgendaSectionState = TodayAgendaSectionState(sections: []) {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }
    @Published public private(set) var agendaTailItems: [HomeAgendaTailItem] = [] {
        didSet { scheduleHomeRenderStateRefresh(.tasks) }
    }
    @Published public private(set) var habitHomeSectionState = HabitHomeSectionState(primaryRows: [], recoveryRows: []) {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .habits]) }
    }
    @Published public private(set) var quietTrackingSummaryState = QuietTrackingSummaryState(stableRows: []) {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .habits]) }
    }
    @Published public private(set) var habitMutationFeedback: HomeHabitMutationFeedback?
    @Published public private(set) var habitMutationErrorMessage: String? {
        didSet {
            guard oldValue != habitMutationErrorMessage else { return }
            scheduleHomeRenderStateRefresh(.habits)
        }
    }

    // Focus Engine
    @Published public private(set) var activeFilterState: HomeFilterState = .default {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks]) }
    }
    @Published public private(set) var savedHomeViews: [SavedHomeView] = [] {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }
    @Published public private(set) var quickViewCounts: [HomeQuickView: Int] = [:]
    @Published public private(set) var pointsPotential: Int = 0
    @Published public private(set) var progressState: HomeProgressState = .empty
    @Published public private(set) var focusTasks: [TaskDefinition] = []
    @Published public private(set) var focusWhyShuffleCandidates: [TaskDefinition] = []
    @Published public private(set) var focusRows: [HomeTodayRow] = [] {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }
    @Published public private(set) var pinnedFocusTaskIDs: [UUID] = [] {
        didSet { scheduleHomeRenderStateRefresh([.tasks, .timeline]) }
    }
    @Published public private(set) var emptyStateMessage: String?
    @Published public private(set) var emptyStateActionTitle: String?
    @Published public private(set) var focusEngineEnabled: Bool = true
    @Published public private(set) var activeScope: HomeListScope = .today {
        didSet { scheduleHomeRenderStateRefresh([.chrome, .tasks]) }
    }
    @Published public private(set) var evaHomeInsights: EvaHomeInsights?
    @Published public private(set) var evaFocusWhySheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaTriageSheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaRescueSheetPresented: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaTriageScope: EvaTriageScope = .visible {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaTriageQueueLoading: Bool = false {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaTriageQueueErrorMessage: String? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaTriageQueue: [EvaTriageQueueItem] = [] {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaRescuePlan: EvaRescuePlan? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published public private(set) var evaLastBatchRunID: UUID? {
        didSet { scheduleHomeRenderStateRefresh(.overlay) }
    }
    @Published private(set) var homeReplanState: HomeReplanSessionState = .hidden {
        didSet { scheduleHomeRenderStateRefresh([.overlay, .timeline]) }
    }
    @Published private(set) var homeCalendarSnapshot: HomeCalendarSnapshot = .empty {
        didSet { scheduleHomeRenderStateRefresh([.calendar, .timeline]) }
    }
    @Published private var hiddenHomeTimelineCalendarEvents: Set<HomeTimelineHiddenCalendarEventKey> = [] {
        didSet { scheduleHomeRenderStateRefresh(.timeline) }
    }
    @Published private(set) var catchUpDailyReflectionEntryPreview: DailyReflectionEntryState? {
        didSet { scheduleHomeRenderStateRefresh(.chrome) }
    }

    @Published private(set) var homeRenderTransaction: HomeRenderTransaction = .empty

    // Next Action Module: total open tasks for today
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
    private let resetHabitOccurrenceUseCase: ResetHabitOccurrenceUseCase
    private let calendarIntegrationService: CalendarIntegrationService
    private let savedHomeViewRepository: SavedHomeViewRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol?
    private let aiSuggestionService: AISuggestionService?
    private let userDefaults: UserDefaults
    private let workspacePreferencesProvider: () -> TaskerWorkspacePreferences
    private let hiddenCalendarEventStore: HomeTimelineHiddenCalendarEventStore
    private var cancellables = Set<AnyCancellable>()
    private var retainedInsightsViewModel: InsightsViewModel?
    private var retainedHomeSearchViewModel: LGSearchViewModel?
    private var needsReplanCandidates: [HomeReplanCandidate] = []
    private var activeReplanCandidates: [HomeReplanCandidate] = []
    private var skippedReplanCandidates: [HomeReplanCandidate] = []
    private var replanUndoStack: [HomeReplanUndoEntry] = []
    private var replanOutcomes = HomeReplanOutcomeSummary()
    private var replanSessionTotal: Int = 0
    private var replanSessionProgress: Int = 0
    private var replanScopedDate: Date?
    private var replanApplyingAction: HomeReplanApplyingAction?
    private var replanErrorMessage: String?
    private var cachedGlobalReplanRevision: HomeDataRevision?
    private var activeGlobalReplanFetchToken: UUID?
    private var activeGlobalReplanFetchRevision: HomeDataRevision?
    private var pendingGlobalReplanRefreshRevision: HomeDataRevision?

    // MARK: - Persistence Keys

    private static let lastFilterStateKey = "home.focus.lastFilterState.v2"
    private static let pinnedFocusTaskIDsKey = "home.focus.pinnedTaskIDs.v2"
    private static let recentShuffleTaskIDsKey = "home.eva.recentShuffleTaskIDs.v1"
    private static let needsReplanDismissedDayKey = "home.needsReplan.dismissedDayKey.v1"
    private static let maxPinnedFocusTasks = 3
    private static let maxShuffleHistorySize = 10
    private static let defaultShuffleExclusionWindow = 3
    private static let maxInlineCompletedRetention = 24

    // MARK: - Session State

    private var homeOpenedAt: Date = Date()
    private var didTrackFirstCompletionLatency = false
    private var completionOverrides: [UUID: Bool] = [:]
    private var pendingHabitMutationKeys: Set<HomeHabitMutationKey> = []
    private var pendingHabitMutationSnapshots: [HomeHabitMutationKey: HomeHabitMutationSnapshot] = [:]
    private var pendingHabitMutationIntervals: [HomeHabitMutationKey: TaskerPerformanceInterval] = [:]
    private var selfOriginatedHabitMutationContextIDs: Set<UUID> = []
    private var reloadGeneration: Int = 0
    private var dataRevision: HomeDataRevision = .zero
    private var timelineSnapshotCache: (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot)?
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
    private var weeklySummaryGeneration: Int = 0
    private var pendingHomeRenderStateWorkItem: DispatchWorkItem?
    private var homeRenderStateRefreshBatchDepth: Int = 0
    private var needsHomeRenderStateRefresh = false
    private var pendingHomeRenderInvalidation: HomeRenderInvalidation = .all
    private var currentHabitSignals: [TaskerHabitSignal] = []
    private var habitLibraryRowsByID: [UUID: HabitLibraryRow] = [:]
    private var taskRowsDerivationRevision: UInt64 = 0
    private var habitRowsDerivationRevision: UInt64 = 0
    private var cachedOpenTaskRowsForHabitMutation: HomeDerivedTaskRowsCache?
    private var cachedMergedHabitRows: HomeDerivedHabitRowsCache?
    private var evaInsightsGeneration: Int = 0
    private var lastTaskListSnapshotRevision: HomeDataRevision?
    private var catchUpReflectionPreviewTask: Task<Void, Never>?
    private var catchUpReflectionPreviewKey: String?
    private var reflectionContextPrefetchTask: Task<Void, Never>?
    private var reflectionContextPrefetchKey: String?
    private static let reflectionContextPrefetchDelayNanoseconds: UInt64 = 250_000_000
    private static let reflectionContextPrefetchTimeoutSeconds: TimeInterval = 0.8

    deinit {
        pendingRecurringTopUpWorkItem?.cancel()
        catchUpReflectionPreviewTask?.cancel()
        reflectionContextPrefetchTask?.cancel()
    }

    var currentDataRevision: HomeDataRevision {
        dataRevision
    }

    public func habitLibraryRow(for habitID: UUID) -> HabitLibraryRow? {
        habitLibraryRowsByID[habitID]
    }

    private func habitMutationKey(for row: HomeHabitRow, on date: Date) -> HomeHabitMutationKey {
        HomeHabitMutationKey(
            habitID: row.habitID,
            day: normalizedDay(date)
        )
    }

    private func normalizedDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func selectedDayMatches(_ targetDay: Date, scope: HomeListScope) -> Bool {
        guard scope.quickView == .today else { return true }
        return Calendar.current.isDate(selectedDate, inSameDayAs: targetDay)
    }

    private func captureHabitMutationSnapshot() -> HomeHabitMutationSnapshot {
        HomeHabitMutationSnapshot(
            dueTodayRows: dueTodayRows,
            dueTodaySection: dueTodaySection,
            todayAgendaSectionState: todayAgendaSectionState,
            habitHomeSectionState: habitHomeSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            focusRows: focusRows,
            focusNowSectionState: focusNowSectionState,
            currentHabitSignals: currentHabitSignals
        )
    }

    private func restoreHabitMutationSnapshot(_ snapshot: HomeHabitMutationSnapshot) {
        performHomeRenderStateBatch {
            assignIfChanged(\.dueTodayRows, snapshot.dueTodayRows)
            assignIfChanged(\.dueTodaySection, snapshot.dueTodaySection)
            assignIfChanged(\.todayAgendaSectionState, snapshot.todayAgendaSectionState)
            assignIfChanged(\.habitHomeSectionState, snapshot.habitHomeSectionState)
            assignIfChanged(\.quietTrackingSummaryState, snapshot.quietTrackingSummaryState)
            assignIfChanged(\.focusRows, snapshot.focusRows)
            assignIfChanged(\.focusNowSectionState, snapshot.focusNowSectionState)
            currentHabitSignals = snapshot.currentHabitSignals
        }
    }

    private func isHabitMutationPending(for key: HomeHabitMutationKey) -> Bool {
        pendingHabitMutationKeys.contains(key)
    }

    private func registerSelfOriginatedHabitMutationContext(_ context: HabitMutationContext) {
        selfOriginatedHabitMutationContextIDs.insert(context.mutationID)
    }

    private func removeSelfOriginatedHabitMutationContext(_ context: HabitMutationContext) {
        selfOriginatedHabitMutationContextIDs.remove(context.mutationID)
    }

    private func consumeSelfOriginatedHabitMutationContext(_ context: HabitMutationContext?) -> Bool {
        guard let context else {
            return false
        }
        if selfOriginatedHabitMutationContextIDs.remove(context.mutationID) != nil {
            let interval = TaskerPerformanceTrace.begin("HomeHabitNotificationSuppressed")
            TaskerPerformanceTrace.end(interval)
            return true
        }
        return false
    }

    private func habitMutationNotification(from notificationObject: Any?) -> HomeHabitMutationNotification? {
        if let notification = notificationObject as? HomeHabitMutationNotification {
            return notification
        }
        if let habitID = notificationObject as? UUID {
            return HomeHabitMutationNotification(habitID: habitID)
        }
        if let habit = notificationObject as? HabitDefinitionRecord {
            return HomeHabitMutationNotification(habitID: habit.id)
        }
        return nil
    }

    private func scheduleHomeRenderStateRefresh(_ invalidation: HomeRenderInvalidation = .all) {
        if Foundation.Thread.isMainThread == false {
            DispatchQueue.main.async { [weak self] in
                self?.scheduleHomeRenderStateRefresh(invalidation)
            }
            return
        }
        pendingHomeRenderInvalidation.formUnion(invalidation)
        if invalidation.includes(.timeline) {
            timelineSnapshotCache = nil
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
        scheduleHomeRenderStateRefresh(pendingHomeRenderInvalidation)
    }

    private func refreshHomeRenderStates() {
        let interval = TaskerPerformanceTrace.begin("HomeRenderStateBuild")
        defer { TaskerPerformanceTrace.end(interval) }
        let invalidation = pendingHomeRenderInvalidation.isEmpty ? .all : pendingHomeRenderInvalidation
        pendingHomeRenderInvalidation = []
        if invalidation.includes(.timeline) {
            timelineSnapshotCache = nil
        }
        if invalidation.includes(.chrome) {
            refreshDailyReflectionEntryPreviewIfNeeded()
        }
        let previousTransaction = homeRenderTransaction
        let transaction = HomeRenderTransaction(
            chrome: invalidation.includes(.chrome) ? buildHomeChromeState() : previousTransaction.chrome,
            tasks: invalidation.includes(.tasks) ? buildHomeTasksState() : previousTransaction.tasks,
            habits: invalidation.includes(.habits) ? buildHomeHabitsState() : previousTransaction.habits,
            calendar: invalidation.includes(.calendar) ? buildHomeCalendarState() : previousTransaction.calendar,
            overlay: invalidation.includes(.overlay) ? buildHomeOverlayState() : previousTransaction.overlay
        )
        guard homeRenderTransaction != transaction else { return }

        homeRenderTransaction = transaction
    }

    private func buildHomeChromeState() -> HomeChromeState {
        let reflectionEntryState = makeDailyReflectionEntryState()
        return HomeChromeState(
            selectedDate: selectedDate,
            activeScope: activeScope,
            activeFilterState: activeFilterState,
            savedHomeViews: savedHomeViews,
            quickViewCounts: quickViewCounts,
            progressState: progressState,
            dailyScore: dailyScore,
            completionRate: completionRate,
            weeklySummary: weeklySummary,
            weeklySummaryIsLoading: weeklySummaryIsLoading,
            weeklySummaryErrorMessage: weeklySummaryErrorMessage,
            projects: projects,
            dailyReflectionEntryState: reflectionEntryState,
            dailyPlanDraft: dailyPlanDraftForSelectedDate(),
            momentumGuidanceText: makeMomentumGuidanceText()
        )
    }

    private func buildHomeTasksState() -> HomeTasksState {
        let projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let tagNameByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
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
            agendaTailItems: agendaTailItems,
            habitHomeSectionState: habitHomeSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            inlineCompletedTasks: activeScope.quickView == .today ? completedTasks : [],
            doneTimelineTasks: doneTimelineTasks,
            projects: projects,
            projectsByID: projectByID,
            tagNameByID: tagNameByID,
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

    private func buildHomeHabitsState() -> HomeHabitsSnapshot {
        HomeHabitsSnapshot(
            habitHomeSectionState: habitHomeSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            errorMessage: habitMutationErrorMessage
        )
    }

    public func clearHabitMutationErrorMessage() {
        habitMutationErrorMessage = nil
    }

    private func buildHomeCalendarState() -> HomeCalendarSnapshot {
        homeCalendarSnapshot
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
            lastXPResult: lastXPResult,
            replanState: homeReplanState
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

    private func makeDailyReflectionEntryState() -> DailyReflectionEntryState? {
        guard activeScope == .today,
              let target = useCaseCoordinator.resolveDailyReflectionTarget.execute() else {
            return nil
        }

        switch target.mode {
        case .sameDay:
            return makeSameDayReflectionEntryState(target: target)
        case .catchUpYesterday:
            if let catchUpDailyReflectionEntryPreview,
               catchUpDailyReflectionEntryPreview.mode == target.mode,
               catchUpDailyReflectionEntryPreview.reflectionDate == target.reflectionDate,
               catchUpDailyReflectionEntryPreview.planningDate == target.planningDate {
                return catchUpDailyReflectionEntryPreview
            }
            return makeBaseDailyReflectionEntryState(target: target)
        }
    }

    private func refreshDailyReflectionEntryPreviewIfNeeded() {
        guard activeScope == .today,
              let target = useCaseCoordinator.resolveDailyReflectionTarget.execute() else {
            clearCatchUpReflectionPreview()
            clearReflectionContextPrefetch()
            return
        }

        scheduleReflectionContextPrefetchIfNeeded(target: target)

        guard target.mode == .catchUpYesterday else {
            clearCatchUpReflectionPreview()
            return
        }

        let previewKey = "\(target.mode.rawValue):\(target.reflectionDate.timeIntervalSince1970):\(target.planningDate.timeIntervalSince1970)"
        guard catchUpReflectionPreviewKey != previewKey else { return }
        catchUpReflectionPreviewTask?.cancel()
        catchUpReflectionPreviewKey = previewKey

        catchUpReflectionPreviewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let bundle = try await useCaseCoordinator.dailyReflectionLoadCoordinator.loadCore(target: target)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    guard self.catchUpReflectionPreviewKey == previewKey else { return }
                    self.catchUpDailyReflectionEntryPreview = self.makeLoadedReflectionEntryState(
                        target: target,
                        coreSnapshot: bundle.coreSnapshot
                    )
                }
            } catch {
                await MainActor.run {
                    if self.catchUpReflectionPreviewKey == previewKey {
                        self.catchUpReflectionPreviewKey = nil
                    }
                }
            }
        }
    }

    private func clearCatchUpReflectionPreview() {
        catchUpReflectionPreviewTask?.cancel()
        catchUpReflectionPreviewTask = nil
        catchUpReflectionPreviewKey = nil
        if catchUpDailyReflectionEntryPreview != nil {
            catchUpDailyReflectionEntryPreview = nil
        }
    }

    private func clearReflectionContextPrefetch() {
        reflectionContextPrefetchTask?.cancel()
        reflectionContextPrefetchTask = nil
        reflectionContextPrefetchKey = nil
    }

    private func scheduleReflectionContextPrefetchIfNeeded(target: DailyReflectionTarget) {
        let prefetchKey = "\(target.mode.rawValue):\(target.planningDate.timeIntervalSince1970)"
        guard reflectionContextPrefetchKey != prefetchKey else { return }
        reflectionContextPrefetchTask?.cancel()
        reflectionContextPrefetchKey = prefetchKey

        reflectionContextPrefetchTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            try? await _Concurrency.Task.sleep(nanoseconds: Self.reflectionContextPrefetchDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            guard self.activeScope == .today else { return }

            await self.useCaseCoordinator.dailyReflectionLoadCoordinator.prefetchContext(
                for: target,
                timeoutSeconds: Self.reflectionContextPrefetchTimeoutSeconds
            )
        }
    }

    private func makeSameDayReflectionEntryState(target: DailyReflectionTarget) -> DailyReflectionEntryState {
        let closedTasks = reflectionClosedTasks(from: completedTasks)
        let habitRows = currentAllHabitRows()
        let habitGrid = reflectionHabitGrid(from: habitRows)
        let narrativeSummary = ReflectionNarrativeSummary.make(
            completedCount: completedTasks.count,
            keptCount: habitRows.filter { $0.state == .completedToday }.count,
            missedTitles: habitRows
                .filter { $0.state == .overdue || $0.state == .lapsedToday || $0.state == .skippedToday }
                .map(\.title)
        )

        return DailyReflectionEntryState(
            mode: target.mode,
            reflectionDate: target.reflectionDate,
            planningDate: target.planningDate,
            title: "Reflect & plan",
            subtitle: "Close today cleanly, then shape tomorrow.",
            summaryText: narrativeSummary.homeCardLine,
            badgeText: nil,
            closedTasks: closedTasks,
            habitGrid: habitGrid,
            narrativeSummary: narrativeSummary
        )
    }

    private func makeLoadedReflectionEntryState(
        target: DailyReflectionTarget,
        coreSnapshot: DailyReflectionCoreSnapshot
    ) -> DailyReflectionEntryState {
        let base = makeBaseDailyReflectionEntryState(target: target)
        return DailyReflectionEntryState(
            mode: base.mode,
            reflectionDate: base.reflectionDate,
            planningDate: base.planningDate,
            title: base.title,
            subtitle: base.subtitle,
            summaryText: coreSnapshot.narrativeSummary.homeCardLine,
            badgeText: base.badgeText,
            closedTasks: coreSnapshot.closedTasks,
            habitGrid: coreSnapshot.habitGrid,
            narrativeSummary: coreSnapshot.narrativeSummary
        )
    }

    private func makeBaseDailyReflectionEntryState(target: DailyReflectionTarget) -> DailyReflectionEntryState {
        switch target.mode {
        case .sameDay:
            return DailyReflectionEntryState(
                mode: target.mode,
                reflectionDate: target.reflectionDate,
                planningDate: target.planningDate,
                title: "Reflect & plan",
                subtitle: "Close today cleanly, then shape tomorrow.",
                summaryText: "Capture the day and lock tomorrow's top three before the surface resets.",
                badgeText: nil
            )
        case .catchUpYesterday:
            return DailyReflectionEntryState(
                mode: target.mode,
                reflectionDate: target.reflectionDate,
                planningDate: target.planningDate,
                title: "Reflect & plan",
                subtitle: "Yesterday is still open. Close it before today sprawls.",
                summaryText: "Reflect on yesterday, then keep today's board focused with a smaller plan.",
                badgeText: "Yesterday"
            )
        }
    }

    private func reflectionClosedTasks(from tasks: [TaskDefinition]) -> [ReflectionTaskMiniRow] {
        tasks
            .sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(3)
            .map { task in
                ReflectionTaskMiniRow(id: task.id, title: task.title, projectName: task.projectName)
            }
    }

    private func reflectionHabitGrid(from rows: [HomeHabitRow]) -> [ReflectionHabitMiniRow] {
        rows
            .sorted { lhs, rhs in
                let lhsRisk = reflectionHabitRiskRank(lhs.riskState)
                let rhsRisk = reflectionHabitRiskRank(rhs.riskState)
                if lhsRisk != rhsRisk {
                    return lhsRisk > rhsRisk
                }
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(4)
            .map { row in
                ReflectionHabitMiniRow(
                    id: row.habitID,
                    title: row.title,
                    colorFamily: HabitColorFamily.family(for: row.accentHex),
                    currentStreak: row.currentStreak,
                    last7Days: Array(row.last14Days.suffix(7))
                )
            }
    }

    private func reflectionHabitRiskRank(_ risk: HabitRiskState) -> Int {
        switch risk {
        case .broken:
            return 2
        case .atRisk:
            return 1
        case .stable:
            return 0
        }
    }

    private func dailyPlanDraftForSelectedDate() -> DailyPlanDraft? {
        useCaseCoordinator.dailyReflectionStore.fetchPlanDraft(on: selectedDate)
    }

    private func bumpTaskRowsDerivationRevision() {
        taskRowsDerivationRevision &+= 1
        cachedOpenTaskRowsForHabitMutation = nil
    }

    private func bumpHabitRowsDerivationRevision() {
        habitRowsDerivationRevision &+= 1
        cachedMergedHabitRows = nil
    }

    private func invalidateDerivedRowCaches(for keyPath: AnyKeyPath) {
        switch keyPath {
        case \HomeViewModel.morningTasks,
             \HomeViewModel.eveningTasks,
             \HomeViewModel.overdueTasks,
             \HomeViewModel.upcomingTasks:
            bumpTaskRowsDerivationRevision()
        case \HomeViewModel.habitHomeSectionState,
             \HomeViewModel.quietTrackingSummaryState:
            bumpHabitRowsDerivationRevision()
        default:
            break
        }
    }

    private func keyPathTriggersHomeRenderRefreshViaDidSet(_ keyPath: AnyKeyPath) -> Bool {
        switch keyPath {
        case \HomeViewModel.selectedDate,
             \HomeViewModel.weeklySummary,
             \HomeViewModel.weeklySummaryIsLoading,
             \HomeViewModel.weeklySummaryErrorMessage,
             \HomeViewModel.lastXPResult,
             \HomeViewModel.dueTodayRows,
             \HomeViewModel.dueTodaySection,
             \HomeViewModel.todaySections,
             \HomeViewModel.focusNowSectionState,
             \HomeViewModel.todayAgendaSectionState,
             \HomeViewModel.agendaTailItems,
             \HomeViewModel.habitHomeSectionState,
             \HomeViewModel.quietTrackingSummaryState,
             \HomeViewModel.activeFilterState,
             \HomeViewModel.savedHomeViews,
             \HomeViewModel.focusRows,
             \HomeViewModel.activeScope,
             \HomeViewModel.evaFocusWhySheetPresented,
             \HomeViewModel.evaTriageSheetPresented,
             \HomeViewModel.evaRescueSheetPresented,
             \HomeViewModel.evaTriageScope,
             \HomeViewModel.evaTriageQueueLoading,
             \HomeViewModel.evaTriageQueueErrorMessage,
             \HomeViewModel.evaTriageQueue,
             \HomeViewModel.evaRescuePlan,
             \HomeViewModel.evaLastBatchRunID,
             \HomeViewModel.homeReplanState,
             \HomeViewModel.homeCalendarSnapshot:
            return true
        default:
            return false
        }
    }

    private func homeRenderInvalidation(forAssignedKeyPath keyPath: AnyKeyPath) -> HomeRenderInvalidation {
        switch keyPath {
        case \HomeViewModel.projects,
             \HomeViewModel.lifeAreas,
             \HomeViewModel.tags,
             \HomeViewModel.emptyStateMessage,
             \HomeViewModel.emptyStateActionTitle:
            return .tasks
        case \HomeViewModel.morningTasks,
             \HomeViewModel.eveningTasks,
             \HomeViewModel.overdueTasks,
             \HomeViewModel.upcomingTasks,
             \HomeViewModel.focusTasks,
             \HomeViewModel.doneTimelineTasks,
             \HomeViewModel.dailyCompletedTasks,
             \HomeViewModel.completedTasks:
            return [.tasks, .timeline]
        case \HomeViewModel.quickViewCounts,
             \HomeViewModel.pointsPotential,
             \HomeViewModel.completionRate,
             \HomeViewModel.progressState:
            return .chrome
        case \HomeViewModel.focusWhyShuffleCandidates:
            return .overlay
        default:
            return .all
        }
    }

    // MARK: - Initialization

    /// Initializes a new instance.
    init(
        useCaseCoordinator: UseCaseCoordinator,
        savedHomeViewRepository: SavedHomeViewRepositoryProtocol = UserDefaultsSavedHomeViewRepository(),
        analyticsService: AnalyticsServiceProtocol? = nil,
        aiSuggestionService: AISuggestionService? = nil,
        workspacePreferencesProvider: @escaping () -> TaskerWorkspacePreferences = { TaskerWorkspacePreferencesStore.shared.load() },
        userDefaults: UserDefaults = .standard,
        hiddenCalendarEventStore: HomeTimelineHiddenCalendarEventStore? = nil
    ) {
        self.useCaseCoordinator = useCaseCoordinator
        self.homeFilteredTasksUseCase = useCaseCoordinator.getHomeFilteredTasks
        self.computeEvaHomeInsightsUseCase = useCaseCoordinator.computeEvaHomeInsights
        self.getInboxTriageQueueUseCase = useCaseCoordinator.getInboxTriageQueue
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

    // MARK: - Public Methods

    /// Load tasks for the selected date.
    public func loadTasksForSelectedDate() {
        applySelectedDay(selectedDate, source: .datePicker, trackAnalytics: false, forceReload: true)
    }

    /// Executes loadTasksForSelectedDate.
    private func loadTasksForSelectedDate(generation: Int) {
        applySelectedDay(
            selectedDate,
            source: .datePicker,
            trackAnalytics: false,
            generation: generation,
            forceReload: true
        )
    }

    /// Load tasks for today.
    public func loadTodayTasks() {
        returnToToday(source: .backToToday)
    }

    public func refreshWeeklySummaryNow() {
        refreshWeeklySummary()
    }

    public func refreshAfterWeeklyReviewCompletion() {
        refreshWeeklySummary()
        reloadCurrentModeTasks()
    }

    public func requestCalendarPermission(openSystemSettings: @escaping () -> Void = {}) {
        _ = calendarIntegrationService.performAccessAction(source: "home", openSystemSettings: openSystemSettings)
    }

    public func refreshCalendarContext(reason: String = "home_manual_refresh") {
        calendarIntegrationService.refreshContext(referenceDate: selectedDate, reason: reason)
    }

    /// Refresh visible Home content without changing the active scope or selected date.
    public func refreshCurrentScopeContent(source: String = "home_scope_preserving_refresh") {
        calendarIntegrationService.refreshContext(referenceDate: selectedDate, reason: source)
        enqueueReload(
            source: source,
            reason: .updated,
            taskID: nil,
            invalidateCaches: true,
            includeAnalytics: false,
            repostEvent: false,
            overrideScopes: [.visibleTasks]
        )
    }

    /// Executes loadTodayTasks.
    private func loadTodayTasks(generation: Int) {
        applySelectedDay(
            Date(),
            source: .backToToday,
            trackAnalytics: false,
            generation: generation,
            forceReload: true
        )
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

    public func performHabitLastCellAction(
        _ row: HomeHabitRow,
        source: String = "habit_home_last_cell"
    ) {
        let interaction = HomeHabitLastCellInteraction.resolve(for: row)
        switch interaction.action {
        case .complete:
            completeHabit(row, source: source)
        case .skip:
            skipHabit(row, source: source)
        case .lapse:
            lapseHabit(row, source: source)
        case .clear:
            resetHabit(row, source: source)
        }
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
        var weeklyOutcomes: [WeeklyOutcome] = []

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

        group.enter()
        useCaseCoordinator.buildWeeklyPlanSnapshot.execute(referenceDate: Date()) { result in
            defer { group.leave() }
            switch result {
            case .success(let snapshot):
                weeklyOutcomes = snapshot.outcomes.sorted { $0.orderIndex < $1.orderIndex }
            case .failure(let error):
                logWarning(
                    event: "task_detail_metadata_weekly_snapshot_failed",
                    message: "Weekly snapshot unavailable while loading task detail metadata",
                    fields: ["error": error.localizedDescription]
                )
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            let projectMotivation = loadedProjects.first(where: { $0.id == projectID }).map {
                ProjectWeeklyMotivation(
                    why: $0.motivationWhy,
                    successLooksLike: $0.motivationSuccessLooksLike,
                    costOfNeglect: $0.motivationCostOfNeglect
                )
            }
            completion(.success(TaskDetailMetadataPayload(
                projects: loadedProjects,
                sections: loadedSections,
                weeklyOutcomes: weeklyOutcomes,
                projectMotivation: projectMotivation
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
        var recentReflectionNotes: [ReflectionNote] = []

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

        group.enter()
        useCaseCoordinator.reflectionNoteRepository.fetchNotes(
            query: ReflectionNoteQuery(linkedProjectID: projectID, limit: 6)
        ) { result in
            defer { group.leave() }
            switch result {
            case .success(let notes):
                recentReflectionNotes = notes
            case .failure(let error):
                logWarning(
                    event: "task_detail_relationship_metadata_reflections_failed",
                    message: "Reflection notes unavailable while loading task relationship metadata",
                    fields: ["error": error.localizedDescription]
                )
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
                availableTasks: availableTasks,
                recentReflectionNotes: recentReflectionNotes
            )))
        }
    }

    public func saveReflectionNote(
        _ note: ReflectionNote,
        completion: @escaping (Result<ReflectionNote, Error>) -> Void
    ) {
        useCaseCoordinator.reflectionNoteRepository.saveNote(note) { [weak self] result in
            guard let self else { return }

            if case .success(let savedNote) = result {
                self.useCaseCoordinator.gamificationEngine.recordEvent(
                    context: XPEventContext(
                        category: .reflectionCapture,
                        source: .manual,
                        taskID: savedNote.linkedTaskID,
                        habitID: savedNote.linkedHabitID,
                        completedAt: savedNote.createdAt
                    )
                ) { _ in }
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    public func clearHabitRecoveryReflectionPrompt() {
        habitRecoveryReflectionPrompt = nil
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
        refreshTodayAgendaForCurrentFocusSelection()
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
        refreshTodayAgendaForCurrentFocusSelection()
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
            refreshTodayAgendaForCurrentFocusSelection()
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        if pinnedFocusTaskIDs.count < Self.maxPinnedFocusTasks {
            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshTodayAgendaForCurrentFocusSelection()
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
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        return .promoted
    }

    /// Change selected date.
    public func selectDate(_ date: Date, source: HomeDateNavigationSource = .datePicker) {
        applySelectedDay(date, source: source, trackAnalytics: source == .swipe)
    }

    public func shiftSelectedDay(
        byDays days: Int,
        source: HomeDateNavigationSource = .swipe
    ) {
        guard days != 0 else { return }
        let baseDay = normalizedDay(selectedDate)
        let targetDay = Calendar.current.date(byAdding: .day, value: days, to: baseDay) ?? baseDay
        selectDate(targetDay, source: source)
    }

    public func returnToToday(source: HomeDateNavigationSource = .backToToday) {
        applySelectedDay(Date(), source: source, trackAnalytics: source == .backToToday, forceReload: true)
    }

    private func applySelectedDay(
        _ day: Date,
        source: HomeDateNavigationSource,
        trackAnalytics: Bool,
        forceReload: Bool = false
    ) {
        applySelectedDay(
            day,
            source: source,
            trackAnalytics: trackAnalytics,
            generation: nextReloadGeneration(),
            forceReload: forceReload
        )
    }

    private func applySelectedDay(
        _ day: Date,
        source: HomeDateNavigationSource,
        trackAnalytics: Bool,
        generation: Int,
        forceReload: Bool = false
    ) {
        scheduleRecurringTopUpIfNeeded()

        let targetDay = normalizedDay(day)
        let targetScope: HomeListScope = Calendar.current.isDateInToday(targetDay) ? .today : .customDate(targetDay)
        let currentDay = normalizedDay(selectedDate)
        let isSameDay = Calendar.current.isDate(currentDay, inSameDayAs: targetDay)
        let alreadySelected = isSameDay && activeScope == targetScope && activeFilterState.quickView == .today

        guard alreadySelected == false || forceReload else {
            TaskerPerformanceTrace.event("HomeDaySwipeCancelled")
            return
        }

        performHomeRenderStateBatch {
            focusEngineEnabled = true
            activeScope = targetScope
            selectedDate = targetDay
            var state = activeFilterState
            state.quickView = .today
            state.selectedSavedViewID = nil
            activeFilterState = state
        }

        persistLastFilterState()
        if isSameDay {
            calendarIntegrationService.refreshContext(
                referenceDate: targetDay,
                reason: "home_selected_date_changed_\(source.rawValue)"
            )
        }
        if source == .swipe {
            TaskerPerformanceTrace.event("HomeDaySwipeCommitted")
        }
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: generation)
        if Calendar.current.isDateInToday(targetDay) {
            loadDailyAnalytics()
        }
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
        if quickView == .today {
            applySelectedDay(Date(), source: .datePicker, trackAnalytics: true)
            return
        }

        focusEngineEnabled = true
        activeScope = .fromQuickView(quickView)
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
        cachedGlobalReplanRevision = nil
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

    public func refreshAfterDailyReflectPlanSave(planningDate: Date) {
        refreshWeeklySummary()
        loadDailyAnalytics(includeGamificationRefresh: false)
        selectDate(planningDate, source: .dailyReflection)
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
        if let retainedInsightsViewModel {
            return retainedInsightsViewModel
        }

        let resolvedViewModel = InsightsViewModel(
            engine: useCaseCoordinator.gamificationEngine,
            repository: useCaseCoordinator.gamificationRepository,
            taskReadModelRepository: useCaseCoordinator.taskReadModelRepository,
            reminderRepository: useCaseCoordinator.reminderRepository,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics,
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            calculateWeeklyMomentumUseCase: useCaseCoordinator.calculateWeeklyMomentum,
            buildRecoveryInsightsUseCase: useCaseCoordinator.buildRecoveryInsights,
            weeklyReviewDraftStore: useCaseCoordinator.weeklyReviewDraftStore
        )
        retainedInsightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func makeHomeSearchViewModel() -> LGSearchViewModel {
        if let retainedHomeSearchViewModel {
            return retainedHomeSearchViewModel
        }

        let resolvedViewModel = LGSearchViewModel(useCaseCoordinator: useCaseCoordinator)
        retainedHomeSearchViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func releaseInsightsViewModel() {
        retainedInsightsViewModel = nil
    }

    func releaseHomeSearchViewModel() {
        retainedHomeSearchViewModel?.purgeCaches()
        retainedHomeSearchViewModel = nil
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
        calendarIntegrationService.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.homeCalendarSnapshot = Self.buildHomeCalendarSnapshot(
                    from: snapshot,
                    selectedDate: self.selectedDate,
                    accessAction: self.calendarIntegrationService.accessAction(for: snapshot.authorizationStatus)
                )
            }
            .store(in: &cancellables)

        $selectedDate
            .removeDuplicates(by: Self.isSameCalendarDay(_:_:))
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedDate in
                guard let self else { return }
                self.homeCalendarSnapshot = Self.buildHomeCalendarSnapshot(
                    from: self.calendarIntegrationService.snapshot,
                    selectedDate: selectedDate,
                    accessAction: self.calendarIntegrationService.accessAction(
                        for: self.calendarIntegrationService.snapshot.authorizationStatus
                    )
                )
                self.calendarIntegrationService.refreshContext(
                    referenceDate: selectedDate,
                    reason: "home_selected_date_changed"
                )
            }
            .store(in: &cancellables)

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
            .sink { [weak self] notification in
                guard let self else { return }
                guard let mutation = self.habitMutationNotification(from: notification.object) else {
                    return
                }
                if self.consumeSelfOriginatedHabitMutationContext(mutation.context) {
                    logDebug("HOME_HABIT_STATE vm.notification_suppressed id=\(mutation.habitID.uuidString)")
                    return
                }
                self.reconcileHabitMutation(habitID: mutation.habitID, on: self.selectedDate)
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
        if let task = morningTasks.first(where: { $0.id == id }) { return task }
        if let task = eveningTasks.first(where: { $0.id == id }) { return task }
        if let task = overdueTasks.first(where: { $0.id == id }) { return task }
        if let task = dailyCompletedTasks.first(where: { $0.id == id }) { return task }
        if let task = upcomingTasks.first(where: { $0.id == id }) { return task }
        if let task = completedTasks.first(where: { $0.id == id }) { return task }
        return doneTimelineTasks.first(where: { $0.id == id })
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
        TaskerMemoryDiagnostics.checkpoint(
            event: "home_initial_load_started",
            message: "Starting home initial load",
            counts: [
                "saved_view_count": savedHomeViews.count,
                "pinned_focus_count": pinnedFocusTaskIDs.count
            ]
        )
        loadSavedViews()
        let generation = nextReloadGeneration()
        loadProjects(generation: generation)
        loadLifeAreas(generation: generation)
        loadTags(generation: generation)
        calendarIntegrationService.refreshContext(referenceDate: selectedDate, reason: "home_initial_load")
        applyFocusFilters(trackAnalytics: false, generation: generation) { [weak self] in
            TaskerMemoryDiagnostics.checkpoint(
                event: "home_initial_load_finished",
                message: "Finished home initial load",
                counts: [
                    "morning_count": self?.morningTasks.count ?? 0,
                    "evening_count": self?.eveningTasks.count ?? 0,
                    "overdue_count": self?.overdueTasks.count ?? 0
                ]
            )
            self?.scheduleInitialDeferredAnalyticsRefreshIfNeeded()
        }
    }

    private func scheduleInitialDeferredAnalyticsRefreshIfNeeded() {
        guard activeScope.quickView == .today else { return }
        scheduleDeferredAnalyticsRefresh(
            reason: "initial_load",
            includeGamificationRefresh: true,
            delayMilliseconds: 1_500
        )
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

    private func openTaskRowsForHabitReconciliation() -> [TaskDefinition] {
        if let cachedOpenTaskRowsForHabitMutation,
           cachedOpenTaskRowsForHabitMutation.revision == taskRowsDerivationRevision,
           cachedOpenTaskRowsForHabitMutation.quickView == activeScope.quickView {
            return cachedOpenTaskRowsForHabitMutation.rows
        }

        let rows: [TaskDefinition]
        switch activeScope.quickView {
        case .done:
            rows = []
        case .upcoming:
            rows = upcomingTasks.filter { !$0.isComplete }
        case .overdue:
            rows = overdueTasks.filter { !$0.isComplete }
        case .morning:
            rows = morningTasks.filter { !$0.isComplete }
        case .evening:
            rows = eveningTasks.filter { !$0.isComplete }
        case .today:
            rows = uniqueTasks((morningTasks + eveningTasks + overdueTasks).filter { !$0.isComplete })
        }

        cachedOpenTaskRowsForHabitMutation = HomeDerivedTaskRowsCache(
            revision: taskRowsDerivationRevision,
            quickView: activeScope.quickView,
            rows: rows
        )
        return rows
    }

    private func refreshDueTodayAgenda(
        openTaskRows: [TaskDefinition],
        generation: Int,
        targetDay: Date,
        scope: HomeListScope,
        includeAnalyticsRefresh: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let day = normalizedDay(targetDay)
        let group = DispatchGroup()
        let stateLock = NSLock()
        var agendaHabitRows: [HomeHabitRow] = []
        var trackingHabitRows: [HomeHabitRow] = []
        var historyByHabitID: [UUID: [HabitDayMark]] = [:]
        var libraryRowsByID: [UUID: HabitLibraryRow] = [:]

        group.enter()
        buildHabitHomeProjectionUseCase.execute(date: day) { result in
            stateLock.lock()
            agendaHabitRows = (try? result.get()) ?? []
            stateLock.unlock()
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
                stateLock.lock()
                libraryRowsByID = [:]
                stateLock.unlock()
                group.leave()
            case .success(let libraryRows):
                stateLock.lock()
                libraryRowsByID = Dictionary(uniqueKeysWithValues: libraryRows.map { ($0.habitID, $0) })
                stateLock.unlock()
                guard libraryRows.isEmpty == false else {
                    stateLock.lock()
                    let lockedHistory = historyByHabitID
                    trackingHabitRows = self.trackingHomeRows(
                        from: libraryRows,
                        historyByHabitID: lockedHistory,
                        on: day
                    )
                    stateLock.unlock()
                    group.leave()
                    return
                }
                group.enter()
                self.useCaseCoordinator.getHabitHistory.execute(
                    habitIDs: libraryRows.map(\.habitID),
                    endingOn: day,
                    dayCount: 30
                ) { historyResult in
                    var resolvedHistoryByHabitID: [UUID: [HabitDayMark]] = [:]
                    if case .success(let windows) = historyResult {
                        resolvedHistoryByHabitID = windows.reduce(into: [:]) { partialResult, window in
                            partialResult[window.habitID] = window.marks
                        }
                    }
                    let resolvedTrackingRows = self.trackingHomeRows(
                        from: libraryRows,
                        historyByHabitID: resolvedHistoryByHabitID,
                        on: day
                    )
                    stateLock.lock()
                    historyByHabitID = resolvedHistoryByHabitID
                    trackingHabitRows = resolvedTrackingRows
                    stateLock.unlock()
                    group.leave()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            defer { completion?() }
            guard let self, self.isCurrentReloadGeneration(generation) else {
                TaskerPerformanceTrace.event("HomeDaySwipeStaleDrop")
                return
            }
            guard self.selectedDayMatches(day, scope: scope) else {
                TaskerPerformanceTrace.event("HomeDaySwipeStaleDrop")
                return
            }

            stateLock.lock()
            let resolvedAgendaHabitRows = agendaHabitRows
            let resolvedTrackingHabitRows = trackingHabitRows
            let resolvedLibraryRowsByID = libraryRowsByID
            stateLock.unlock()

            let allHabitRows = self.mergeHabitRows(
                agenda: resolvedAgendaHabitRows,
                tracking: resolvedTrackingHabitRows
            )
            let splitHabitRows = HabitBoardPresentationBuilder.splitHomeRows(allHabitRows)
            self.currentHabitSignals = self.habitSignals(from: allHabitRows)
            self.habitLibraryRowsByID = resolvedLibraryRowsByID
            let rescueSplit = self.splitRescueEligibleTasks(from: openTaskRows, on: day)

            let focusRows = self.composeFocusRows(taskRows: rescueSplit.focusTaskRows, habitRows: allHabitRows)
            let agendaTaskRows =
                scope.quickView == .today
                ? Self.excludingVisibleFocusTasks(from: rescueSplit.agendaTaskRows, focusRows: focusRows)
                : rescueSplit.agendaTaskRows

            let agenda = self.buildHomeAgendaUseCase.execute(
                date: day,
                taskRows: agendaTaskRows,
                habitRows: resolvedAgendaHabitRows
            )

            self.assignIfChanged(\.dueTodayRows, agenda.rows)
            self.assignIfChanged(\.dueTodaySection, nil)
            let todaySections = HomeMixedSectionBuilder.buildTodaySections(
                taskRows: agendaTaskRows,
                habitRows: [],
                projects: self.projects,
                lifeAreas: self.lifeAreas,
                useAdaptiveDayGrouping: true
            )
            self.assignIfChanged(\.todaySections, todaySections)

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
                \.agendaTailItems,
                self.buildAgendaTailItems(
                    rescueEligibleTasks: rescueSplit.rescueEligibleTasks
                )
            )
            self.assignIfChanged(
                \.habitHomeSectionState,
                HabitHomeSectionState(
                    primaryRows: splitHabitRows.primary,
                    recoveryRows: splitHabitRows.recovery
                )
            )
            self.assignIfChanged(
                \.quietTrackingSummaryState,
                QuietTrackingSummaryState(
                    stableRows: splitHabitRows.quiet
                )
            )

            if includeAnalyticsRefresh,
               Calendar.current.isDate(day, inSameDayAs: Date()) {
                self.loadDailyAnalytics(includeGamificationRefresh: false)
            }
        }
    }

    private struct CanonicalHabitMutationState {
        let row: HomeHabitRow?
        let libraryRow: HabitLibraryRow?
    }

    private func fetchCanonicalHabitMutationState(
        habitID: UUID,
        on date: Date,
        completion: @escaping (Result<CanonicalHabitMutationState, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let stateLock = NSLock()
        var projectionRow: HomeHabitRow?
        var libraryRow: HabitLibraryRow?
        var historyByHabitID: [UUID: [HabitDayMark]] = [:]
        var reconciliationError: Error?

        group.enter()
        buildHabitHomeProjectionUseCase.execute(date: date, habitID: habitID) { result in
            switch result {
            case .failure(let error):
                stateLock.lock()
                reconciliationError = reconciliationError ?? error
                stateLock.unlock()
            case .success(let row):
                stateLock.lock()
                projectionRow = row
                stateLock.unlock()
            }
            group.leave()
        }

        group.enter()
        useCaseCoordinator.getHabitLibrary.execute(habitIDs: [habitID], includeArchived: false) { [weak self] result in
            guard let self else {
                group.leave()
                return
            }
            switch result {
            case .failure(let error):
                stateLock.lock()
                reconciliationError = reconciliationError ?? error
                stateLock.unlock()
                group.leave()
            case .success(let rows):
                stateLock.lock()
                libraryRow = rows.first
                let hasLibraryRow = libraryRow != nil
                stateLock.unlock()
                guard hasLibraryRow else {
                    group.leave()
                    return
                }
                group.enter()
                self.useCaseCoordinator.getHabitHistory.execute(
                    habitIDs: [habitID],
                    endingOn: date,
                    dayCount: 30
                ) { historyResult in
                    switch historyResult {
                    case .failure(let error):
                        stateLock.lock()
                        reconciliationError = reconciliationError ?? error
                        stateLock.unlock()
                    case .success(let windows):
                        stateLock.lock()
                        historyByHabitID = windows.reduce(into: [:]) { partialResult, window in
                            partialResult[window.habitID] = window.marks
                        }
                        stateLock.unlock()
                    }
                    group.leave()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            stateLock.lock()
            let resolvedProjectionRow = projectionRow
            let resolvedLibraryRow = libraryRow
            let resolvedHistoryByHabitID = historyByHabitID
            let resolvedError = reconciliationError
            stateLock.unlock()

            if let resolvedError {
                completion(.failure(resolvedError))
                return
            }

            let trackingRow: HomeHabitRow?
            if let resolvedLibraryRow, let strongSelf = self {
                trackingRow = strongSelf.trackingHomeRows(
                    from: [resolvedLibraryRow],
                    historyByHabitID: resolvedHistoryByHabitID,
                    on: date
                ).first
            } else {
                trackingRow = nil
            }

            let canonicalRow = self?.mergeHabitRows(
                agenda: resolvedProjectionRow.map { [$0] } ?? [],
                tracking: trackingRow.map { [$0] } ?? []
            ).first

            completion(.success(
                CanonicalHabitMutationState(
                    row: canonicalRow,
                    libraryRow: resolvedLibraryRow
                )
            ))
        }
    }

    private func reconcileHabitMutation(
        habitID: UUID,
        on date: Date
    ) {
        let interval = TaskerPerformanceTrace.begin("HomeHabitRowReconcile")
        fetchCanonicalHabitMutationState(habitID: habitID, on: date) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                guard let self else { return }
                guard Calendar.current.isDate(date, inSameDayAs: self.selectedDate) else { return }

                switch result {
                case .failure(let error):
                    logWarning(
                        event: "home_habit_reconcile_failed",
                        message: "Failed to reconcile canonical habit state after mutation",
                        fields: [
                            "habit_id": habitID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )

                case .success(let canonicalState):
                    let patch = self.buildHabitMutationSectionPatch(
                        habitID: habitID,
                        canonicalRow: canonicalState.row
                    )

                    self.performHomeRenderStateBatch {
                        self.applyHabitMutationSectionPatch(patch)
                    }

                    if let libraryRow = canonicalState.libraryRow {
                        self.habitLibraryRowsByID[habitID] = libraryRow
                    } else {
                        self.habitLibraryRowsByID.removeValue(forKey: habitID)
                    }

                    TaskerPerformanceTrace.event("HomeUserMutationRecomputedRows", value: patch.affectedRowCount)
                    TaskerPerformanceTrace.event("HomeUserMutationRecomputedSections", value: patch.affectedSectionCount)
                    logDebug(
                        "HOME_HABIT_STATE vm.reconcile_apply id=\(habitID.uuidString) " +
                        "rows=\(patch.affectedRowCount) sections=\(patch.affectedSectionCount)"
                    )
                }
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
                keywords: [row.title, row.lifeAreaName, row.projectName].compactMap { $0 },
                last14Days: row.last14Days,
                colorHex: row.accentHex,
                cadence: row.cadence
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

    private func sortHabitRows(_ rows: [HomeHabitRow]) -> [HomeHabitRow] {
        rows.sorted { lhs, rhs in
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

    private func buildAgendaTailItems(
        rescueEligibleTasks: [TaskDefinition]
    ) -> [HomeAgendaTailItem] {
        guard activeScope.quickView == .today, V2FeatureFlags.evaRescueEnabled else {
            return []
        }

        let rows = rescueEligibleTasks
            .map(HomeTodayRow.task)
            .sorted(by: compareRescueRows(_:_:))
        guard rows.isEmpty == false else {
            return []
        }

        let mode: RescueTailMode = rows.count <= 3 ? .compact : .expanded
        let subtitle: String
        if rows.count == 1 {
            subtitle = "1 task is 2+ weeks overdue"
        } else {
            subtitle = "\(rows.count) tasks are 2+ weeks overdue"
        }

        return [
            .rescue(
                RescueTailState(
                    rows: rows,
                    mode: mode,
                    isInlineExpanded: mode == .expanded,
                    subtitle: subtitle
                )
            )
        ]
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

            let compactCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 7,
                calendar: calendar
            )
            let expandedCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 30,
                calendar: calendar
            )

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
                accentHex: row.colorHex,
                cadence: row.cadence,
                cadenceLabel: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar),
                dueAt: row.nextDueAt,
                state: state,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                last14Days: marks,
                boardCellsCompact: compactCells,
                boardCellsExpanded: expandedCells,
                riskState: todayMark?.state == .failure ? .broken : .stable,
                helperText: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar)
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
            for row in habitFocusFallbackRows(from: habitRows) where results.count < 1 {
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
        performHabitMutation(
            row,
            request: .resolve(action),
            on: date,
            source: source
        )
    }

    private func resetHabit(
        _ row: HomeHabitRow,
        source: String
    ) {
        performHabitMutation(
            row,
            request: .reset,
            on: selectedDate,
            source: source
        )
    }

    private func performHabitMutation(
        _ row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date,
        source: String
    ) {
        let key = habitMutationKey(for: row, on: date)
        guard !isHabitMutationPending(for: key) else {
            logDebug("HOME_HABIT_STATE vm.mutation_ignored_pending id=\(row.habitID.uuidString)")
            return
        }

        habitMutationErrorMessage = nil
        pendingHabitMutationKeys.insert(key)
        pendingHabitMutationIntervals[key] = TaskerPerformanceTrace.begin("HomeUserMutation")
        if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            pendingHabitMutationSnapshots[key] = captureHabitMutationSnapshot()

            let applyInterval = TaskerPerformanceTrace.begin("HomeHabitOptimisticApply")
            let didApplyOptimisticUpdate = applyOptimisticHabitMutation(
                row,
                request: request,
                on: date
            )
            TaskerPerformanceTrace.end(applyInterval)

            guard didApplyOptimisticUpdate else {
                if let interval = pendingHabitMutationIntervals.removeValue(forKey: key) {
                    TaskerPerformanceTrace.end(interval)
                }
                pendingHabitMutationKeys.remove(key)
                pendingHabitMutationSnapshots.removeValue(forKey: key)
                return
            }
            habitMutationFeedback = makeHabitMutationFeedback(for: request, row: row, date: date)
            TaskerPerformanceTrace.event("HomeUserMutationOptimisticApplied")
        }

        let mutationContext = HabitMutationContext(source: source)
        registerSelfOriginatedHabitMutationContext(mutationContext)
        let recoveryReflectionPrompt = recoveryReflectionPromptIfNeeded(for: row, request: request, on: date)

        switch request {
        case .resolve(let action):
            useCaseCoordinator.resolveHabitOccurrence.execute(
                habitID: row.habitID,
                occurrenceID: row.occurrenceID,
                action: action,
                on: date,
                mutationContext: mutationContext
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleHabitMutationResult(
                        result,
                        key: key,
                        habitID: row.habitID,
                        date: date,
                        mutationContext: mutationContext,
                        recoveryReflectionPrompt: recoveryReflectionPrompt
                    )
                }
            }

        case .reset:
            resetHabitOccurrenceUseCase.execute(
                habitID: row.habitID,
                occurrenceID: row.occurrenceID,
                on: date,
                mutationContext: mutationContext
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleHabitMutationResult(
                        result,
                        key: key,
                        habitID: row.habitID,
                        date: date,
                        mutationContext: mutationContext,
                        recoveryReflectionPrompt: recoveryReflectionPrompt
                    )
                }
            }
        }
    }

    private func handleHabitMutationResult(
        _ result: Result<Void, Error>,
        key: HomeHabitMutationKey,
        habitID: UUID,
        date: Date,
        mutationContext: HabitMutationContext,
        recoveryReflectionPrompt: HabitRecoveryReflectionPrompt?
    ) {
        defer {
            if let interval = pendingHabitMutationIntervals.removeValue(forKey: key) {
                TaskerPerformanceTrace.end(interval)
            }
        }

        switch result {
        case .failure(let error):
            removeSelfOriginatedHabitMutationContext(mutationContext)
            if let snapshot = pendingHabitMutationSnapshots[key] {
                restoreHabitMutationSnapshot(snapshot)
            }
            pendingHabitMutationSnapshots.removeValue(forKey: key)
            pendingHabitMutationKeys.remove(key)
            habitMutationErrorMessage = error.localizedDescription
            errorMessage = error.localizedDescription

        case .success:
            TaskerPerformanceTrace.event("HomeUserMutationPersistenceComplete")
            pendingHabitMutationSnapshots.removeValue(forKey: key)
            pendingHabitMutationKeys.remove(key)
            habitMutationErrorMessage = nil
            let isSelectedDayMutation = Calendar.current.isDate(date, inSameDayAs: selectedDate)
            if isSelectedDayMutation {
                habitRecoveryReflectionPrompt = recoveryReflectionPrompt
            }
            guard isSelectedDayMutation else { return }
            reconcileHabitMutation(habitID: habitID, on: date)
        }
    }

    private func recoveryReflectionPromptIfNeeded(
        for row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HabitRecoveryReflectionPrompt? {
        guard Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return nil }
        guard isRecoveryHabitRow(row) else { return nil }
        switch request {
        case .reset:
            return nil
        case .resolve(let action):
            switch action {
            case .complete, .abstained:
                return HabitRecoveryReflectionPrompt(
                    habitID: row.habitID,
                    habitTitle: row.title,
                    date: date
                )
            case .skip, .lapsed:
                return nil
            }
        }
    }

    private func makeHabitMutationFeedback(
        for request: HomeHabitMutationRequest,
        row: HomeHabitRow,
        date: Date,
        calendar: Calendar = .current
    ) -> HomeHabitMutationFeedback {
        let stateLabel: String
        let haptic: HomeHabitMutationFeedbackHaptic

        switch request {
        case .resolve(.complete):
            stateLabel = "Marked done"
            haptic = .success
        case .resolve(.abstained):
            stateLabel = row.kind == .negative ? "Marked clean" : "Marked done"
            haptic = .success
        case .resolve(.skip):
            stateLabel = "Marked skipped"
            haptic = .selection
        case .resolve(.lapsed):
            stateLabel = "Marked lapsed"
            haptic = .warning
        case .reset:
            stateLabel = row.trackingMode == .lapseOnly ? "Cleared to tracking" : "Cleared to empty"
            haptic = .selection
        }

        let dayLabel = Self.habitMutationFeedbackDateFormatter.string(from: calendar.startOfDay(for: date))
        return HomeHabitMutationFeedback(message: "\(dayLabel): \(stateLabel)", haptic: haptic)
    }

    @MainActor
    public func consumeHabitMutationFeedback(id: UUID) {
        guard habitMutationFeedback?.id == id else { return }
        habitMutationFeedback = nil
    }

    private func isRecoveryHabitRow(_ row: HomeHabitRow) -> Bool {
        row.state == .overdue || row.state == .lapsedToday || row.riskState != .stable
    }

    private func applyOptimisticHabitMutation(
        _ row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> Bool {
        guard let updatedRow = optimisticHabitRow(from: row, request: request, on: date) else {
            return false
        }

        let patch = buildHabitMutationSectionPatch(
            habitID: row.habitID,
            canonicalRow: updatedRow
        )

        performHomeRenderStateBatch {
            applyHabitMutationSectionPatch(patch)
        }

        logDebug(
            "HOME_HABIT_STATE vm.local_apply id=\(row.habitID.uuidString) " +
            "state=\(updatedRow.state.rawValue) rows=\(patch.affectedRowCount) sections=\(patch.affectedSectionCount)"
        )
        TaskerPerformanceTrace.event("HomeUserMutationRecomputedRows", value: patch.affectedRowCount)
        TaskerPerformanceTrace.event("HomeUserMutationRecomputedSections", value: patch.affectedSectionCount)
        return true
    }

    private func currentAllHabitRows() -> [HomeHabitRow] {
        if let cachedMergedHabitRows,
           cachedMergedHabitRows.revision == habitRowsDerivationRevision {
            return cachedMergedHabitRows.rows
        }

        var rowsByHabitID: [UUID: HomeHabitRow] = [:]
        let rowsInDisplayOrder =
            habitHomeSectionState.primaryRows
            + habitHomeSectionState.recoveryRows
            + quietTrackingSummaryState.stableRows
        for row in rowsInDisplayOrder {
            rowsByHabitID[row.habitID] = row
        }
        let rows = rowsInDisplayOrder.filter { row in
            rowsByHabitID[row.habitID]?.id == row.id
        }
        cachedMergedHabitRows = HomeDerivedHabitRowsCache(
            revision: habitRowsDerivationRevision,
            rows: rows
        )
        return rows
    }

    private func splitRescueEligibleTasks(
        from openTaskRows: [TaskDefinition],
        on date: Date
    ) -> (agendaTaskRows: [TaskDefinition], focusTaskRows: [TaskDefinition], rescueEligibleTasks: [TaskDefinition]) {
        let rescueEligibleTaskIDs = V2FeatureFlags.evaRescueEnabled
            ? Set(
                openTaskRows
                    .filter { isRescueEligibleTask($0, on: date) }
                    .map(\.id)
            )
            : Set<UUID>()
        let rescueEligibleTasks = openTaskRows.filter { rescueEligibleTaskIDs.contains($0.id) }
        let remainingTaskRows = openTaskRows.filter { !rescueEligibleTaskIDs.contains($0.id) }
        return (
            agendaTaskRows: remainingTaskRows,
            focusTaskRows: remainingTaskRows,
            rescueEligibleTasks: rescueEligibleTasks
        )
    }

    private func refreshTodayAgendaForCurrentFocusSelection() {
        guard activeScope.quickView == .today else { return }
        refreshDueTodayAgenda(
            openTaskRows: focusOpenTasksForCurrentState(),
            generation: reloadGeneration,
            targetDay: normalizedDay(selectedDate),
            scope: activeScope,
            includeAnalyticsRefresh: false
        )
    }

    static func excludingVisibleFocusTasks(
        from agendaTaskRows: [TaskDefinition],
        focusRows: [HomeTodayRow]
    ) -> [TaskDefinition] {
        let visibleFocusTaskIDs = Set(
            focusRows.compactMap { row -> UUID? in
                guard case .task(let task) = row else { return nil }
                return task.id
            }
        )
        guard visibleFocusTaskIDs.isEmpty == false else { return agendaTaskRows }
        return agendaTaskRows.filter { !visibleFocusTaskIDs.contains($0.id) }
    }

    private static func openTaskID(for row: HomeTodayRow) -> UUID? {
        guard case .task(let task) = row, !task.isComplete else { return nil }
        return task.id
    }

    private func isEligibleForHabitFocusFallback(_ row: HomeHabitRow) -> Bool {
        row.trackingMode == .dailyCheckIn
            && row.kind == .positive
            && (row.state == .overdue || row.riskState == .atRisk)
    }

    private func isShowingHabitBackedFocusFallback() -> Bool {
        let rows = focusNowSectionState.rows
        guard rows.isEmpty == false else { return false }
        guard focusTasks.isEmpty else { return false }
        return rows.allSatisfy(\.isHabit)
    }

    private func shouldRecomputeHabitFocusFallback(for habitID: UUID) -> Bool {
        guard focusTasks.isEmpty else { return false }
        guard focusNowSectionState.rows.isEmpty == false else { return true }

        let displayedHabitRows = focusNowSectionState.rows.compactMap { row -> HomeHabitRow? in
            guard case .habit(let habitRow) = row else { return nil }
            return habitRow
        }
        guard displayedHabitRows.count == focusNowSectionState.rows.count else { return false }
        return displayedHabitRows.contains(where: { $0.habitID == habitID })
    }

    private func currentHabitRowPlacementMap() -> [UUID: HomeHabitRowPlacement] {
        var placements: [UUID: HomeHabitRowPlacement] = [:]

        for (index, row) in habitHomeSectionState.primaryRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .primary, index: index)
        }
        for (index, row) in habitHomeSectionState.recoveryRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .recovery, index: index)
        }
        for (index, row) in quietTrackingSummaryState.stableRows.enumerated() {
            placements[row.habitID] = HomeHabitRowPlacement(bucket: .quiet, index: index)
        }

        return placements
    }

    private func placementBucket(for row: HomeHabitRow) -> HomeHabitRowPlacementBucket {
        if row.trackingMode == .lapseOnly, row.state == .tracking, row.riskState == .stable {
            return .quiet
        }
        if row.state == .overdue || row.state == .lapsedToday || row.riskState != .stable {
            return .recovery
        }
        return .primary
    }

    private func replacingHabitRow(
        habitID: UUID,
        with canonicalRow: HomeHabitRow?
    ) -> (primary: [HomeHabitRow], recovery: [HomeHabitRow], quiet: [HomeHabitRow]) {
        var primaryRows = habitHomeSectionState.primaryRows.filter { $0.habitID != habitID }
        var recoveryRows = habitHomeSectionState.recoveryRows.filter { $0.habitID != habitID }
        var quietRows = quietTrackingSummaryState.stableRows.filter { $0.habitID != habitID }

        guard let canonicalRow else {
            return (primaryRows, recoveryRows, quietRows)
        }

        let placementMap = currentHabitRowPlacementMap()
        let targetPlacement = placementMap[habitID]
            ?? HomeHabitRowPlacement(
                bucket: placementBucket(for: canonicalRow),
                index: Int.max
            )

        switch targetPlacement.bucket {
        case .primary:
            primaryRows.insert(canonicalRow, at: min(targetPlacement.index, primaryRows.count))
        case .recovery:
            recoveryRows.insert(canonicalRow, at: min(targetPlacement.index, recoveryRows.count))
        case .quiet:
            quietRows.insert(canonicalRow, at: min(targetPlacement.index, quietRows.count))
        }

        return (primaryRows, recoveryRows, quietRows)
    }

    private func patchAgendaRowsForHabitMutation(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> [HomeTodayRow] {
        var patchedRows = dueTodayRows
        let existingIndex = patchedRows.firstIndex { row in
            guard case .habit(let habitRow) = row else { return false }
            return habitRow.habitID == habitID
        }

        switch (existingIndex, canonicalRow.map(includeHabitInAgenda(_:)) ?? false, canonicalRow) {
        case let (.some(index), true, .some(updatedRow)):
            patchedRows[index] = .habit(updatedRow)
        case (.some, true, .none):
            break
        case let (.some(index), false, _):
            patchedRows.remove(at: index)
        case let (.none, true, .some(updatedRow)):
            patchedRows.append(.habit(updatedRow))
        case (.none, false, _),
             (.none, true, .none):
            break
        }

        return patchedRows
    }

    private func patchDueTodaySection(
        rows: [HomeTodayRow]
    ) -> HomeListSection? {
        dueTodaySection.map { section in
            HomeListSection(
                anchor: section.anchor,
                rows: rows,
                isOverdueSection: section.isOverdueSection,
                accentHex: section.accentHex
            )
        }
    }

    private func patchCurrentHabitSignals(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> [TaskerHabitSignal] {
        var signals = currentHabitSignals
        if let index = signals.firstIndex(where: { $0.habitID == habitID }) {
            if let canonicalRow {
                signals[index] = habitSignals(from: [canonicalRow])[0]
            } else {
                signals.remove(at: index)
            }
            return signals
        }

        guard let canonicalRow else { return signals }
        signals.append(habitSignals(from: [canonicalRow])[0])
        return signals
    }

    private func buildHabitMutationSectionPatch(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> HomeHabitMutationSectionPatch {
        let replacement = replacingHabitRow(habitID: habitID, with: canonicalRow)
        let allHabitRows = replacement.primary + replacement.recovery + replacement.quiet
        let agendaRows = patchAgendaRowsForHabitMutation(
            habitID: habitID,
            canonicalRow: canonicalRow
        )
        let updatedDueTodaySection = patchDueTodaySection(rows: agendaRows)

        let updatedFocusRows: [HomeTodayRow]?
        let updatedFocusNowSectionState: FocusNowSectionState?
        if shouldRecomputeHabitFocusFallback(for: habitID) {
            let focusRows = habitFocusFallbackRows(from: allHabitRows)
            updatedFocusRows = focusRows
            updatedFocusNowSectionState = FocusNowSectionState(
                rows: focusRows,
                pinnedTaskIDs: pinnedFocusTaskIDs
            )
        } else {
            updatedFocusRows = nil
            updatedFocusNowSectionState = nil
        }

        return HomeHabitMutationSectionPatch(
            allHabitRows: allHabitRows,
            dueTodayRows: agendaRows,
            dueTodaySection: updatedDueTodaySection,
            habitHomeSectionState: HabitHomeSectionState(
                primaryRows: replacement.primary,
                recoveryRows: replacement.recovery
            ),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: replacement.quiet),
            focusRows: updatedFocusRows,
            focusNowSectionState: updatedFocusNowSectionState,
            currentHabitSignals: patchCurrentHabitSignals(
                habitID: habitID,
                canonicalRow: canonicalRow
            ),
            affectedRowCount: 1 + (updatedFocusRows?.count ?? 0),
            affectedSectionCount: 1 + (updatedFocusRows == nil ? 0 : 1)
        )
    }

    private func applyHabitMutationSectionPatch(_ patch: HomeHabitMutationSectionPatch) {
        assignForHabitMutation(\.dueTodayRows, patch.dueTodayRows)
        assignForHabitMutation(\.dueTodaySection, patch.dueTodaySection)
        assignForHabitMutation(\.habitHomeSectionState, patch.habitHomeSectionState)
        assignForHabitMutation(\.quietTrackingSummaryState, patch.quietTrackingSummaryState)
        if let focusRows = patch.focusRows {
            assignForHabitMutation(\.focusRows, focusRows)
        }
        if let focusNowSectionState = patch.focusNowSectionState {
            assignForHabitMutation(\.focusNowSectionState, focusNowSectionState)
        }
        currentHabitSignals = patch.currentHabitSignals
    }

    private func habitFocusFallbackRows(from habitRows: [HomeHabitRow]) -> [HomeTodayRow] {
        let highPriorityHabits = habitRows
            .filter(isEligibleForHabitFocusFallback(_:))
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state == .overdue
                }
                let lhsDue = lhs.dueAt ?? .distantFuture
                let rhsDue = rhs.dueAt ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return compareFocusRows(.habit(lhs), .habit(rhs))
            }
            .map(HomeTodayRow.habit)

        return Array(highPriorityHabits.prefix(1))
    }

    private func optimisticHabitRow(
        from row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HomeHabitRow? {
        let optimisticDayState = optimisticHabitDayState(for: request)
        let referenceDate = Calendar.current.startOfDay(for: date)
        let marks = optimisticallyPatchedHabitDayMarks(
            from: row.last14Days,
            dayState: optimisticDayState,
            on: referenceDate
        )
        let compactCells = optimisticallyPatchedBoardCells(
            from: row.boardCellsCompact,
            marks: marks,
            cadence: row.cadence,
            referenceDate: referenceDate,
            fallbackDayCount: 7
        )
        let expandedCells = optimisticallyPatchedBoardCells(
            from: row.boardCellsExpanded,
            marks: marks,
            cadence: row.cadence,
            referenceDate: referenceDate,
            fallbackDayCount: 30
        )
        let metrics = HabitBoardPresentationBuilder.metrics(for: expandedCells)
        let occurrenceState = optimisticOccurrenceState(for: request)
        let state = optimisticHomeHabitState(
            for: row,
            request: request,
            on: referenceDate
        )
        let riskState = HabitRuntimeSupport.riskState(
            for: marks,
            dueAt: row.dueAt,
            occurrenceState: occurrenceState,
            referenceDate: referenceDate
        )

        return HomeHabitRow(
            habitID: row.habitID,
            occurrenceID: row.occurrenceID,
            title: row.title,
            kind: row.kind,
            trackingMode: row.trackingMode,
            lifeAreaID: row.lifeAreaID,
            lifeAreaName: row.lifeAreaName,
            projectID: row.projectID,
            projectName: row.projectName,
            iconSymbolName: row.iconSymbolName,
            accentHex: row.accentHex,
            cadence: row.cadence,
            cadenceLabel: row.cadenceLabel,
            dueAt: row.dueAt,
            state: state,
            currentStreak: metrics.currentStreak,
            bestStreak: max(row.bestStreak, metrics.bestStreak),
            last14Days: marks,
            boardCellsCompact: compactCells,
            boardCellsExpanded: expandedCells,
            riskState: riskState,
            helperText: row.helperText
        )
    }

    private func optimisticHabitDayState(for request: HomeHabitMutationRequest) -> HabitDayState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .success
        case .resolve(.skip):
            return .skipped
        case .resolve(.lapsed):
            return .failure
        case .reset:
            return .none
        }
    }

    private func optimisticOccurrenceState(for request: HomeHabitMutationRequest) -> OccurrenceState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .completed
        case .resolve(.skip):
            return .skipped
        case .resolve(.lapsed):
            return .failed
        case .reset:
            return .pending
        }
    }

    private func optimisticHomeHabitState(
        for row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HomeHabitRowState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .completedToday
        case .resolve(.skip):
            return .skippedToday
        case .resolve(.lapsed):
            return .lapsedToday
        case .reset:
            if row.trackingMode == .lapseOnly {
                return .tracking
            }
            if let dueAt = row.dueAt, dueAt < Calendar.current.startOfDay(for: date) {
                return .overdue
            }
            return .due
        }
    }

    private func optimisticallyPatchedHabitDayMarks(
        from existingMarks: [HabitDayMark],
        dayState: HabitDayState,
        on date: Date
    ) -> [HabitDayMark] {
        var marks = existingMarks
        if marks.isEmpty {
            marks = HabitRuntimeSupport.dayMarks(
                from: [],
                endingOn: date,
                dayCount: 30
            )
        }

        let day = Calendar.current.startOfDay(for: date)
        if let index = marks.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            marks[index] = HabitDayMark(date: marks[index].date, state: dayState)
        } else {
            marks.append(HabitDayMark(date: day, state: dayState))
            marks.sort { $0.date < $1.date }
        }
        return marks
    }

    private func optimisticallyPatchedBoardCells(
        from existingCells: [HabitBoardCell],
        marks: [HabitDayMark],
        cadence: HabitCadenceDraft,
        referenceDate: Date,
        fallbackDayCount: Int
    ) -> [HabitBoardCell] {
        let calendar = Calendar.current
        let resolvedCells: [HabitBoardCell]
        if existingCells.isEmpty {
            resolvedCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: cadence,
                referenceDate: referenceDate,
                dayCount: fallbackDayCount,
                calendar: calendar
            )
        } else {
            let marksByDay = Dictionary(uniqueKeysWithValues: marks.map {
                (calendar.startOfDay(for: $0.date), $0)
            })
            let referenceDay = calendar.startOfDay(for: referenceDate)
            let patched = existingCells.map { cell in
                let day = calendar.startOfDay(for: cell.date)
                return HabitBoardCell(
                    date: day,
                    state: optimisticBoardCellState(
                        on: day,
                        marksByDay: marksByDay,
                        cadence: cadence,
                        referenceDay: referenceDay,
                        calendar: calendar
                    ),
                    isToday: calendar.isDate(day, inSameDayAs: referenceDay),
                    isWeekend: calendar.isDateInWeekend(day)
                )
            }
            resolvedCells = classifyOptimisticBridgeKinds(
                in: HabitBoardPresentationBuilder.remapVisibleDisplayDepths(in: patched)
            )
        }

        return resolvedCells
    }

    private func optimisticBoardCellState(
        on day: Date,
        marksByDay: [Date: HabitDayMark],
        cadence: HabitCadenceDraft,
        referenceDay: Date,
        calendar: Calendar
    ) -> HabitBoardCellState {
        if day > referenceDay {
            return .future
        }

        if let mark = marksByDay[day] {
            switch mark.state {
            case .success:
                return .done(depth: 1)
            case .failure:
                return .missed
            case .skipped:
                return .bridge(kind: .single, source: .skipped)
            case .future:
                return .future
            case .none:
                break
            }
        }

        if optimisticHabitShouldOccur(on: day, cadence: cadence, calendar: calendar) {
            return calendar.isDate(day, inSameDayAs: referenceDay) ? .todayPending : .missed
        }

        return .bridge(kind: .single, source: .notScheduled)
    }

    private func optimisticHabitShouldOccur(
        on date: Date,
        cadence: HabitCadenceDraft,
        calendar: Calendar
    ) -> Bool {
        switch cadence {
        case .daily:
            return true
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek.contains(calendar.component(.weekday, from: date))
        }
    }

    private func classifyOptimisticBridgeKinds(in cells: [HabitBoardCell]) -> [HabitBoardCell] {
        var resolved = cells
        var index = 0

        while index < resolved.count {
            guard case let .bridge(_, source) = resolved[index].state else {
                index += 1
                continue
            }

            let start = index
            var end = index
            while end + 1 < resolved.count {
                guard case .bridge = resolved[end + 1].state else { break }
                end += 1
            }

            let previousDone = optimisticNearestDoneState(in: resolved, before: start)
            let nextDone = optimisticNearestDoneState(in: resolved, after: end)
            let count = (start...end).count

            for current in start...end {
                let kind: HabitBridgeKind
                if count == 1 {
                    if previousDone && nextDone {
                        kind = .single
                    } else if previousDone {
                        kind = .start
                    } else if nextDone {
                        kind = .end
                    } else {
                        kind = .middle
                    }
                } else if current == start {
                    kind = previousDone ? .start : .middle
                } else if current == end {
                    kind = nextDone ? .end : .middle
                } else {
                    kind = .middle
                }

                resolved[current] = HabitBoardCell(
                    date: resolved[current].date,
                    state: .bridge(kind: kind, source: source),
                    isToday: resolved[current].isToday,
                    isWeekend: resolved[current].isWeekend
                )
            }

            index = end + 1
        }

        return resolved
    }

    private func optimisticNearestDoneState(in cells: [HabitBoardCell], before index: Int) -> Bool {
        guard index > 0 else { return false }
        for cursor in stride(from: index - 1, through: 0, by: -1) {
            switch cells[cursor].state {
            case .done:
                return true
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                return false
            }
        }
        return false
    }

    private func optimisticNearestDoneState(in cells: [HabitBoardCell], after index: Int) -> Bool {
        guard index < cells.count - 1 else { return false }
        for cursor in (index + 1)..<cells.count {
            switch cells[cursor].state {
            case .done:
                return true
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                return false
            }
        }
        return false
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
        visibleTasksCompletion: (() -> Void)? = nil,
        habitsCompletion: (() -> Void)? = nil
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
        if scopes.contains(.habits) {
            let interval = TaskerPerformanceTrace.begin("HomeHabitScopedReload")
            let targetDay = normalizedDay(activeScope.referenceDate)
            let scope = activeScope
            refreshDueTodayAgenda(
                openTaskRows: openTaskRowsForHabitReconciliation(),
                generation: generation,
                targetDay: targetDay,
                scope: scope,
                includeAnalyticsRefresh: false,
                completion: {
                    TaskerPerformanceTrace.end(interval)
                    habitsCompletion?()
                }
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
        let filterState = activeFilterState
        let scope = activeScope
        let revision = dataRevision
        let targetDay = normalizedDay(scope.referenceDate)
        if scope.quickView == .today {
            TaskerPerformanceTrace.event(
                homeFilteredTasksUseCase.hasCachedResult(
                    state: filterState,
                    scope: scope,
                    revision: revision
                ) ? "HomeDaySwipeCacheHit" : "HomeDaySwipeCacheMiss"
            )
        }
        isLoading = true
        errorMessage = nil

        homeFilteredTasksUseCase.execute(
            state: filterState,
            scope: scope,
            revision: revision
        ) { [weak self] result in
            DispatchQueue.main.async {
                defer { TaskerPerformanceTrace.end(interval) }
                defer { completion?() }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=focus generation=\(generation)")
                    TaskerPerformanceTrace.event("HomeDaySwipeStaleDrop")
                    return
                }
                guard self.selectedDayMatches(targetDay, scope: scope) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_day source=focus generation=\(generation)")
                    TaskerPerformanceTrace.event("HomeDaySwipeStaleDrop")
                    return
                }
                self.isLoading = false

                switch result {
                case .success(let filteredResult):
                    self.performHomeRenderStateBatch {
                        self.assignIfChanged(\.quickViewCounts, filteredResult.quickViewCounts)
                        self.assignIfChanged(\.pointsPotential, filteredResult.pointsPotential)
                        self.applyResultToSections(
                            filteredResult,
                            generation: generation,
                            targetDay: targetDay,
                            scope: scope
                        )
                        self.refreshProgressState()
                        self.refreshWeeklySummary()

                        if trackAnalytics {
                            self.trackFeatureUsage(action: "home_filter_applied", metadata: [
                                "quick_view": scope.quickView.analyticsAction,
                                "scope": self.scopeAnalyticsAction(scope),
                                "project_count": filterState.selectedProjectIDs.count,
                                "saved_view": filterState.selectedSavedViewID?.uuidString ?? "",
                                "advanced_filter": filterState.advancedFilter != nil
                            ])
                        }
                        if scope.quickView == .today {
                            self.prefetchAdjacentDays(around: targetDay)
                        }
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func prefetchAdjacentDays(around targetDay: Date) {
        let calendar = Calendar.current
        let baseDay = normalizedDay(targetDay)
        var state = activeFilterState
        state.quickView = .today
        state.selectedSavedViewID = nil
        let revision = dataRevision

        for dayOffset in [-1, 1] {
            guard let adjacentDay = calendar.date(byAdding: .day, value: dayOffset, to: baseDay) else {
                continue
            }

            let scope: HomeListScope = calendar.isDateInToday(adjacentDay) ? .today : .customDate(adjacentDay)
            guard homeFilteredTasksUseCase.hasCachedResult(state: state, scope: scope, revision: revision) == false else {
                continue
            }

            homeFilteredTasksUseCase.execute(
                state: state,
                scope: scope,
                revision: revision
            ) { result in
                if case .success = result {
                    TaskerPerformanceTrace.event("HomeDaySwipePrefetchReady")
                }
            }
        }
    }

    /// Executes applyResultToSections.
    private func applyResultToSections(
        _ result: HomeFilteredTasksResult,
        generation: Int,
        targetDay: Date,
        scope: HomeListScope
    ) {
        let overriddenResult = applyCompletionOverrides(
            openTasks: result.openTasks,
            doneTasks: result.doneTimelineTasks
        )
        let openTasks = overriddenResult.openTasks
        let incomingDoneTasks = overriddenResult.doneTasks
        let shouldKeepCompletedInline = shouldKeepCompletedInline(for: scope)
        let doneTasks = mergedInlineDoneTasks(
            incomingDoneTasks: incomingDoneTasks,
            openTasks: openTasks,
            shouldKeepCompletedInline: shouldKeepCompletedInline
        )
        let visibleTasks = shouldKeepCompletedInline ? (openTasks + doneTasks) : openTasks

        logDebug(
            "HOME_ROW_STATE vm.apply_result quick=\(scope.quickView.rawValue) " +
            "open=\(summarizeRowState(openTasks)) done=\(summarizeRowState(doneTasks))"
        )

        if scope.quickView == .today {
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
            assignIfChanged(\.agendaTailItems, [])
            assignIfChanged(\.habitHomeSectionState, HabitHomeSectionState(primaryRows: [], recoveryRows: []))
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
            refreshNeedsReplanCandidates()
            writeTaskListWidgetSnapshot(reason: "apply_result_done")
            return
        }

        assignIfChanged(\.doneTimelineTasks, [])
        assignIfChanged(\.completedTasks, doneTasks)
        assignIfChanged(\.dailyCompletedTasks, doneTasks)
        refreshDueTodayAgenda(
            openTaskRows: openTasks,
            generation: generation,
            targetDay: targetDay,
            scope: scope
        )

        let overdue = visibleTasks.filter { isTaskOverdue($0, relativeTo: scope) }
        let nonOverdue = visibleTasks.filter { !isTaskOverdue($0, relativeTo: scope) }

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

        switch scope.quickView {
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
        refreshNeedsReplanCandidates()
        writeTaskListWidgetSnapshot(reason: "apply_result_\(scope.quickView.rawValue)")
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

    private func refreshWeeklySummary() {
        let generation = nextWeeklySummaryGeneration()
        assignIfChanged(\.weeklySummaryIsLoading, true)
        assignIfChanged(\.weeklySummaryErrorMessage, nil)
        useCaseCoordinator.getWeeklySummary.execute(referenceDate: Date()) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.isCurrentWeeklySummaryGeneration(generation) else {
                    logDebug("HOME_WEEKLY_SUMMARY vm.drop_stale generation=\(generation)")
                    return
                }
                self.assignIfChanged(\.weeklySummaryIsLoading, false)
                switch result {
                case .success(let summary):
                    self.assignIfChanged(\.weeklySummary, summary)
                    self.assignIfChanged(\.weeklySummaryErrorMessage, nil)
                case .failure(let error):
                    if self.weeklySummary == nil {
                        self.assignIfChanged(
                            \.weeklySummaryErrorMessage,
                            "Couldn't load weekly summary. Try again."
                        )
                    }
                    logWarning(
                        event: "home_weekly_summary_refresh_failed",
                        message: "Failed to refresh weekly summary",
                        fields: ["error": error.localizedDescription]
                    )
                }
            }
        }
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
        if reason.hasPrefix("apply_result_"), lastTaskListSnapshotRevision == dataRevision {
            return
        }
        lastTaskListSnapshotRevision = dataRevision
        TaskerMemoryDiagnostics.checkpoint(
            event: "widget_snapshot_scheduled",
            message: "Scheduling task list widget snapshot refresh",
            fields: ["reason": reason],
            counts: [
                "morning_count": morningTasks.count,
                "evening_count": eveningTasks.count,
                "overdue_count": overdueTasks.count,
                "focus_count": focusTasks.count
            ]
        )
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
        repostEvent: Bool,
        overrideScopes: Set<HomeReloadScope>? = nil
    ) {
        pendingReloadSources.insert(source)
        if let reason {
            pendingReloadReasons.insert(reason)
        }
        let scopes = overrideScopes ?? reloadScopes(for: reason, includeAnalytics: includeAnalytics, repostEvent: repostEvent)
        pendingReloadScopes.formUnion(scopes)
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
        if scopes.contains(.habits) {
            tracker.registerOperation()
        }
        applyReloadScopes(
            scopes,
            generation: generation,
            visibleTasksCompletion: scopes.contains(.visibleTasks) ? { tracker.completeOperation() } : nil,
            habitsCompletion: scopes.contains(.habits) ? { tracker.completeOperation() } : nil
        )

        if scopes.contains(.habits),
           !scopes.contains(.analytics),
           Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
            scheduleDeferredAnalyticsRefresh(
                reason: "habit_reload_scope",
                includeGamificationRefresh: false
            )
        }

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

    // MARK: - Needs Replan

    public func openNeedsReplanLauncher() {
        beginReplanLauncher(with: needsReplanCandidates, scopedTo: nil)
    }

    func needsReplanCandidatesForTesting(
        from tasks: [TaskDefinition],
        scopedTo date: Date? = nil
    ) -> [HomeReplanCandidate] {
        deriveNeedsReplanCandidates(from: tasks, scopedTo: date)
    }

    func defaultReplanPlacementDayForTesting(now: Date) -> Date {
        defaultReplanPlacementDay(now: now)
    }

    func beginReplanPlacementForTesting(candidate: HomeReplanCandidate) {
        activeReplanCandidates = [candidate]
        skippedReplanCandidates = []
        replanUndoStack = []
        replanOutcomes = HomeReplanOutcomeSummary()
        replanSessionTotal = 1
        replanSessionProgress = 0
        replanApplyingAction = nil
        replanErrorMessage = nil
        updateReplanState(phase: .placement(candidate, defaultDay: Date()))
    }

    func setReplanApplyingForTesting(_ action: HomeReplanApplyingAction?) {
        replanApplyingAction = action
        updateReplanState(phase: homeReplanState.phase)
    }

    public func openNeedsReplanLauncher(for date: Date) {
        let calendar = Calendar.current
        guard calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()) else { return }
        let scopedCandidates = needsReplanCandidates.filter {
            guard let anchorDate = $0.anchorDate else { return false }
            return calendar.isDate(anchorDate, inSameDayAs: date)
        }
        beginReplanLauncher(with: scopedCandidates, scopedTo: date)
    }

    public func startNeedsReplanSession() {
        guard replanApplyingAction == nil else { return }
        replanErrorMessage = nil
        guard activeReplanCandidates.isEmpty == false else {
            updateReplanState(phase: .summary(replanOutcomes, skippedCount: 0))
            return
        }
        updateReplanState(phase: .card(candidateIndex: replanSessionProgress + 1))
    }

    public func dismissNeedsReplanLater() {
        guard replanApplyingAction == nil else { return }
        if replanScopedDate == nil,
           (activeReplanCandidates.isEmpty == false || needsReplanCandidates.isEmpty == false) {
            userDefaults.set(needsReplanDayKey(for: Date()), forKey: Self.needsReplanDismissedDayKey)
        }
        resetReplanSession(keepPassiveCandidates: true)
        refreshPassiveNeedsReplanState()
    }

    public func finishNeedsReplanSession() {
        guard replanApplyingAction == nil else { return }
        if skippedReplanCandidates.isEmpty == false, replanScopedDate == nil {
            userDefaults.set(needsReplanDayKey(for: Date()), forKey: Self.needsReplanDismissedDayKey)
        }
        resetReplanSession(keepPassiveCandidates: true)
        refreshPassiveNeedsReplanState()
    }

    public func dismissNeedsReplanSessionUI() {
        guard replanApplyingAction == nil else { return }
        resetReplanSession(keepPassiveCandidates: true)
        refreshPassiveNeedsReplanState()
    }

    public func reviewSkippedReplanCandidates() {
        guard replanApplyingAction == nil else { return }
        guard skippedReplanCandidates.isEmpty == false else {
            finishNeedsReplanSession()
            return
        }
        replanErrorMessage = nil
        activeReplanCandidates = skippedReplanCandidates
        skippedReplanCandidates = []
        replanSessionTotal = activeReplanCandidates.count
        replanSessionProgress = 0
        updateReplanState(phase: .skippedReview)
        updateReplanState(phase: .card(candidateIndex: 1))
    }

    public func skipCurrentReplanCandidate() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        replanErrorMessage = nil
        skippedReplanCandidates.append(candidate)
        activeReplanCandidates.removeFirst()
        replanSessionProgress += 1
        advanceReplanSession()
    }

    public func moveCurrentReplanCandidateToInbox() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        var updated = candidate.task
        updated.projectID = ProjectConstants.inboxProjectID
        updated.projectName = ProjectConstants.inboxProjectName
        updated.type = .inbox
        updated.dueDate = nil
        updated.scheduledStartAt = nil
        updated.scheduledEndAt = nil
        updated.isAllDay = false
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .movedToInbox,
            candidate: candidate,
            reloadReason: .projectChanged
        )
    }

    public func checkOffCurrentReplanCandidate() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        var updated = candidate.task
        updated.isComplete = true
        updated.dateCompleted = Date()
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .completed,
            candidate: candidate,
            reloadReason: .completed
        )
    }

    public func deleteCurrentReplanCandidate() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        applyReplanCommand(
            .deleteTask(taskID: candidate.task.id),
            action: .deleted,
            candidate: candidate,
            reloadReason: .deleted
        )
    }

    public func beginCurrentReplanPlacement() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        replanErrorMessage = nil
        let defaultDay = defaultReplanPlacementDay()
        selectDate(defaultDay, source: .replan)
        updateReplanState(phase: .placement(candidate, defaultDay: defaultDay))
    }

    public func cancelCurrentReplanPlacement() {
        guard replanApplyingAction == nil else { return }
        guard case .placement = homeReplanState.phase else { return }
        replanErrorMessage = nil
        updateReplanState(phase: .card(candidateIndex: replanSessionProgress + 1))
    }

    public func placeReplanCandidate(taskID: UUID, at startDate: Date) {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first(where: { $0.task.id == taskID }) else { return }
        let roundedStart = roundedToNearestQuarterHour(startDate)
        var updated = candidate.task
        updated.dueDate = roundedStart
        updated.scheduledStartAt = roundedStart
        updated.scheduledEndAt = roundedStart.addingTimeInterval(candidate.rescheduleDuration)
        updated.isAllDay = false
        updated.replanCount = max(0, updated.replanCount) + 1
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .rescheduled,
            candidate: candidate,
            reloadReason: .rescheduled
        )
    }

    public func placeReplanCandidateAllDay(taskID: UUID, on day: Date) {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first(where: { $0.task.id == taskID }) else { return }
        let normalizedDay = Calendar.current.startOfDay(for: day)
        var updated = candidate.task
        updated.dueDate = normalizedDay
        updated.scheduledStartAt = nil
        updated.scheduledEndAt = nil
        updated.isAllDay = true
        updated.replanCount = max(0, updated.replanCount) + 1
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .rescheduled,
            candidate: candidate,
            reloadReason: .rescheduled
        )
    }

    public func undoLastReplanAction() {
        guard replanApplyingAction == nil else { return }
        guard let entry = replanUndoStack.last else { return }
        beginReplanApplying(.undo)
        useCaseCoordinator.assistantActionPipeline.undoAppliedRun(id: entry.runID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.replanUndoStack.removeLast()
                    self.decrementOutcome(for: entry.action)
                    if self.activeReplanCandidates.contains(where: { $0.id == entry.candidate.id }) == false {
                        self.activeReplanCandidates.insert(entry.candidate, at: 0)
                    }
                    self.replanSessionProgress = max(0, self.replanSessionProgress - 1)
                    self.enqueueReload(
                        source: "needs_replan_undo",
                        reason: .bulkChanged,
                        invalidateCaches: true,
                        includeAnalytics: false,
                        repostEvent: true
                    )
                    self.endReplanApplying()
                    self.updateReplanState(phase: .card(candidateIndex: self.replanSessionProgress + 1))
                case .failure(let error):
                    self.recordReplanFailure(error)
                }
            }
        }
    }

    public func clearReplanError() {
        replanErrorMessage = nil
        updateReplanState(phase: homeReplanState.phase)
    }

    private func beginReplanLauncher(with candidates: [HomeReplanCandidate], scopedTo date: Date?) {
        activeReplanCandidates = candidates
        skippedReplanCandidates = []
        replanUndoStack = []
        replanOutcomes = HomeReplanOutcomeSummary()
        replanSessionTotal = candidates.count
        replanSessionProgress = 0
        replanScopedDate = date
        replanApplyingAction = nil
        replanErrorMessage = nil
        let summary = makeNeedsReplanSummary(for: candidates)
        updateReplanState(phase: .launcher(summary))
    }

    private func refreshNeedsReplanCandidates() {
        guard let readModelRepository = useCaseCoordinator.taskReadModelRepository else {
            needsReplanCandidates = []
            cachedGlobalReplanRevision = dataRevision
            refreshPassiveNeedsReplanState()
            updateReplanState(phase: homeReplanState.phase)
            return
        }
        guard cachedGlobalReplanRevision != dataRevision else {
            refreshPassiveNeedsReplanState()
            updateReplanState(phase: homeReplanState.phase)
            return
        }
        if activeGlobalReplanFetchToken != nil {
            pendingGlobalReplanRefreshRevision = dataRevision
            return
        }

        let fetchToken = UUID()
        activeGlobalReplanFetchToken = fetchToken
        activeGlobalReplanFetchRevision = dataRevision
        fetchGlobalOpenTasks(
            readModelRepository: readModelRepository,
            limit: 400,
            offset: 0,
            accumulated: []
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.activeGlobalReplanFetchToken == fetchToken else { return }
                let completedRevision = self.activeGlobalReplanFetchRevision
                let shouldRefreshAgain = self.pendingGlobalReplanRefreshRevision != nil &&
                    self.pendingGlobalReplanRefreshRevision != completedRevision
                self.pendingGlobalReplanRefreshRevision = nil
                self.activeGlobalReplanFetchToken = nil
                self.activeGlobalReplanFetchRevision = nil
                if shouldRefreshAgain {
                    self.cachedGlobalReplanRevision = nil
                    self.refreshNeedsReplanCandidates()
                    return
                }
                switch result {
                case .success(let tasks):
                    self.needsReplanCandidates = self.deriveNeedsReplanCandidates(from: tasks, scopedTo: nil)
                    self.cachedGlobalReplanRevision = self.dataRevision
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.needsReplanCandidates = []
                    self.cachedGlobalReplanRevision = nil
                }
                self.refreshPassiveNeedsReplanState()
                self.updateReplanState(phase: self.homeReplanState.phase)
            }
        }
    }

    private func fetchGlobalOpenTasks(
        readModelRepository: TaskReadModelRepositoryProtocol,
        limit: Int,
        offset: Int,
        accumulated: [TaskDefinition],
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        readModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: false,
                sortBy: .updatedAtDescending,
                needsTotalCount: false,
                limit: limit,
                offset: offset
            )
        ) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let slice):
                let merged = accumulated + slice.tasks
                let nextOffset = offset + slice.tasks.count
                let loadedAllTasks = slice.tasks.count < limit || slice.tasks.isEmpty
                if loadedAllTasks {
                    completion(.success(merged))
                    return
                }
                self?.fetchGlobalOpenTasks(
                    readModelRepository: readModelRepository,
                    limit: limit,
                    offset: nextOffset,
                    accumulated: merged,
                    completion: completion
                )
            }
        }
    }

    private func refreshPassiveNeedsReplanState() {
        switch homeReplanState.phase {
        case .launcher, .card, .placement, .summary, .skippedReview:
            return
        case .trayHidden, .trayVisible:
            break
        }

        let calendar = Calendar.current
        let summary = makeNeedsReplanSummary(for: needsReplanCandidates)
        guard calendar.isDate(selectedDate, inSameDayAs: Date()),
              summary.count > 0,
              userDefaults.string(forKey: Self.needsReplanDismissedDayKey) != needsReplanDayKey(for: Date()) else {
            updateReplanState(phase: .trayHidden)
            return
        }
        updateReplanState(phase: .trayVisible(summary))
    }

    private func deriveNeedsReplanCandidates(
        from tasks: [TaskDefinition],
        scopedTo scopedDate: Date?
    ) -> [HomeReplanCandidate] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let scopedStart = scopedDate.map { calendar.startOfDay(for: $0) }
        var seen: Set<UUID> = []

        return tasks.compactMap { task -> HomeReplanCandidate? in
            guard seen.insert(task.id).inserted else { return nil }
            guard task.isComplete == false,
                  task.parentTaskID == nil,
                  task.repeatPattern == nil,
                  task.recurrenceSeriesID == nil,
                  task.habitDefinitionID == nil else {
                return nil
            }

            if let dueDate = task.dueDate,
               calendar.startOfDay(for: dueDate) < todayStart {
                if let scopedStart,
                   calendar.isDate(calendar.startOfDay(for: dueDate), inSameDayAs: scopedStart) == false {
                    return nil
                }
                return HomeReplanCandidate(
                    task: task,
                    kind: .pastDue,
                    anchorDate: dueDate,
                    anchorEndDate: task.scheduledEndAt,
                    projectName: task.projectName
                )
            }

            if let scheduledStartAt = task.scheduledStartAt,
               calendar.startOfDay(for: scheduledStartAt) < todayStart {
                if let scopedStart,
                   calendar.isDate(calendar.startOfDay(for: scheduledStartAt), inSameDayAs: scopedStart) == false {
                    return nil
                }
                return HomeReplanCandidate(
                    task: task,
                    kind: .scheduledCarryOver,
                    anchorDate: scheduledStartAt,
                    anchorEndDate: task.scheduledEndAt,
                    projectName: task.projectName
                )
            }

            guard scopedStart == nil,
                  task.dueDate == nil,
                  task.scheduledStartAt == nil,
                  task.scheduledEndAt == nil else {
                return nil
            }
            return HomeReplanCandidate(
                task: task,
                kind: .unscheduledBacklog,
                anchorDate: nil,
                anchorEndDate: nil,
                projectName: task.projectName
            )
        }
        .sorted { lhs, rhs in
            let lhsIsDated = lhs.anchorDate != nil
            let rhsIsDated = rhs.anchorDate != nil
            if lhsIsDated != rhsIsDated { return lhsIsDated }
            if let lhsDay = lhs.anchorDay, let rhsDay = rhs.anchorDay, lhsDay != rhsDay {
                return lhsDay > rhsDay
            }
            if let lhsAnchor = lhs.anchorDate, let rhsAnchor = rhs.anchorDate, lhsAnchor != rhsAnchor {
                return lhsAnchor > rhsAnchor
            }
            if lhs.task.priority.scorePoints != rhs.task.priority.scorePoints {
                return lhs.task.priority.scorePoints > rhs.task.priority.scorePoints
            }
            if lhs.anchorDate == nil, rhs.anchorDate == nil, lhs.task.updatedAt != rhs.task.updatedAt {
                return lhs.task.updatedAt < rhs.task.updatedAt
            }
            return lhs.task.title.localizedStandardCompare(rhs.task.title) == .orderedAscending
        }
    }

    private func makeNeedsReplanSummary(for candidates: [HomeReplanCandidate]) -> NeedsReplanSummary {
        let datedCandidates = candidates.filter { $0.anchorDate != nil }
        let dayKeys = Set(datedCandidates.compactMap { $0.anchorDate.map(needsReplanDayKey(for:)) })
        return NeedsReplanSummary(
            count: candidates.count,
            datedCount: datedCandidates.count,
            unscheduledCount: candidates.filter { $0.kind == .unscheduledBacklog }.count,
            dayCount: dayKeys.count,
            newestDate: datedCandidates.first?.anchorDate,
            oldestDate: datedCandidates.last?.anchorDate
        )
    }

    private func updateReplanState(phase: HomeReplanSessionPhase) {
        let currentCandidate = activeReplanCandidates.first
        let candidateIndex = currentCandidate == nil ? 0 : min(max(replanSessionProgress + 1, 1), max(replanSessionTotal, 1))
        let nextState = HomeReplanSessionState(
            phase: phase,
            summary: makeNeedsReplanSummary(for: activeReplanCandidates + skippedReplanCandidates),
            persistentSummary: makeNeedsReplanSummary(for: needsReplanCandidates),
            currentCandidate: currentCandidate,
            candidateIndex: candidateIndex,
            candidateTotal: max(replanSessionTotal, activeReplanCandidates.count + skippedReplanCandidates.count),
            canUndo: replanUndoStack.isEmpty == false,
            outcomes: replanOutcomes,
            skippedCount: skippedReplanCandidates.count,
            isApplying: replanApplyingAction != nil,
            applyingAction: replanApplyingAction,
            errorMessage: replanErrorMessage
        )
        guard homeReplanState != nextState else { return }
        homeReplanState = nextState
    }

    private func advanceReplanSession() {
        if let next = activeReplanCandidates.first {
            updateReplanState(phase: .card(candidateIndex: replanSessionProgress + 1))
            trackHomeInteraction(action: "needs_replan_next", metadata: [
                "task_id": next.task.id.uuidString
            ])
            return
        }

        updateReplanState(phase: .summary(replanOutcomes, skippedCount: skippedReplanCandidates.count))
    }

    private func resetReplanSession(keepPassiveCandidates: Bool) {
        activeReplanCandidates = []
        skippedReplanCandidates = []
        replanUndoStack = []
        replanOutcomes = HomeReplanOutcomeSummary()
        replanSessionTotal = 0
        replanSessionProgress = 0
        replanScopedDate = nil
        replanApplyingAction = nil
        replanErrorMessage = nil
        if keepPassiveCandidates == false {
            needsReplanCandidates = []
        }
        updateReplanState(phase: .trayHidden)
    }

    private func applyReplanCommand(
        _ command: AssistantCommand,
        action: HomeReplanResolutionKind,
        candidate: HomeReplanCandidate,
        reloadReason: HomeTaskMutationEvent
    ) {
        beginReplanApplying(applyingAction(for: action))
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [command],
            rationaleText: "Needs Replan"
        )
        let threadID = "home-needs-replan-\(UUID().uuidString)"
        useCaseCoordinator.assistantActionPipeline.propose(threadID: threadID, envelope: envelope) { [weak self] proposeResult in
            switch proposeResult {
            case .failure(let error):
                DispatchQueue.main.async { self?.recordReplanFailure(error) }
            case .success(let proposedRun):
                self?.useCaseCoordinator.assistantActionPipeline.confirm(runID: proposedRun.id) { confirmResult in
                    switch confirmResult {
                    case .failure(let error):
                        DispatchQueue.main.async { self?.recordReplanFailure(error) }
                    case .success:
                        self?.useCaseCoordinator.assistantActionPipeline.applyConfirmedRun(id: proposedRun.id) { applyResult in
                            DispatchQueue.main.async {
                                guard let self else { return }
                                switch applyResult {
                                case .failure(let error):
                                    self.recordReplanFailure(error)
                                case .success(let appliedRun):
                                    self.completeReplanResolution(
                                        action: action,
                                        candidate: candidate,
                                        runID: appliedRun.id,
                                        reloadReason: reloadReason
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func completeReplanResolution(
        action: HomeReplanResolutionKind,
        candidate: HomeReplanCandidate,
        runID: UUID,
        reloadReason: HomeTaskMutationEvent
    ) {
        activeReplanCandidates.removeAll { $0.id == candidate.id }
        needsReplanCandidates.removeAll { $0.id == candidate.id }
        replanSessionProgress += 1
        incrementOutcome(for: action)
        replanUndoStack.append(HomeReplanUndoEntry(runID: runID, action: action, candidate: candidate))
        enqueueReload(
            source: "needs_replan_resolution",
            reason: reloadReason,
            taskID: candidate.id,
            invalidateCaches: true,
            includeAnalytics: action == .completed,
            repostEvent: true
        )
        endReplanApplying()
        advanceReplanSession()
    }

    private func beginReplanApplying(_ action: HomeReplanApplyingAction) {
        replanApplyingAction = action
        replanErrorMessage = nil
        updateReplanState(phase: homeReplanState.phase)
    }

    private func endReplanApplying() {
        replanApplyingAction = nil
        replanErrorMessage = nil
    }

    private func recordReplanFailure(_ error: Error) {
        replanApplyingAction = nil
        replanErrorMessage = "Couldn't update this task. Try again."
        errorMessage = error.localizedDescription
        updateReplanState(phase: homeReplanState.phase)
    }

    private func applyingAction(for action: HomeReplanResolutionKind) -> HomeReplanApplyingAction {
        switch action {
        case .rescheduled:
            return .reschedule
        case .movedToInbox:
            return .moveToInbox
        case .completed:
            return .checkOff
        case .deleted:
            return .delete
        }
    }

    private func incrementOutcome(for action: HomeReplanResolutionKind) {
        switch action {
        case .rescheduled:
            replanOutcomes.rescheduled += 1
        case .movedToInbox:
            replanOutcomes.movedToInbox += 1
        case .completed:
            replanOutcomes.completed += 1
        case .deleted:
            replanOutcomes.deleted += 1
        }
    }

    private func decrementOutcome(for action: HomeReplanResolutionKind) {
        switch action {
        case .rescheduled:
            replanOutcomes.rescheduled = max(0, replanOutcomes.rescheduled - 1)
        case .movedToInbox:
            replanOutcomes.movedToInbox = max(0, replanOutcomes.movedToInbox - 1)
        case .completed:
            replanOutcomes.completed = max(0, replanOutcomes.completed - 1)
        case .deleted:
            replanOutcomes.deleted = max(0, replanOutcomes.deleted - 1)
        }
    }

    private func defaultReplanPlacementDay(now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let today = calendar.startOfDay(for: now)
        if hour < 17 { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    private func roundedToNearestQuarterHour(_ date: Date) -> Date {
        let interval = (date.timeIntervalSinceReferenceDate / 900).rounded() * 900
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    private func needsReplanDayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
        .prefix(Self.maxInlineCompletedRetention)

        var merged: [TaskDefinition] = []
        var seen = Set<UUID>()
        for task in incomingDoneTasks + retainedPriorDone where task.isComplete && isTaskCompletedOnActiveScopeDay(task) {
            if seen.insert(task.id).inserted {
                merged.append(task)
            }
            if merged.count >= Self.maxInlineCompletedRetention {
                break
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

    @discardableResult
    private func nextWeeklySummaryGeneration() -> Int {
        weeklySummaryGeneration += 1
        return weeklySummaryGeneration
    }

    /// Executes isCurrentReloadGeneration.
    private func isCurrentReloadGeneration(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }

    private func isCurrentAnalyticsGeneration(_ generation: Int) -> Bool {
        generation == analyticsGeneration
    }

    private func isCurrentWeeklySummaryGeneration(_ generation: Int) -> Bool {
        generation == weeklySummaryGeneration
    }

    private func assignIfChanged<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<HomeViewModel, Value>,
        _ newValue: Value
    ) {
        guard self[keyPath: keyPath] != newValue else { return }
        self[keyPath: keyPath] = newValue
        let erasedKeyPath = keyPath as AnyKeyPath
        invalidateDerivedRowCaches(for: erasedKeyPath)
        if !keyPathTriggersHomeRenderRefreshViaDidSet(erasedKeyPath) {
            scheduleHomeRenderStateRefresh(homeRenderInvalidation(forAssignedKeyPath: erasedKeyPath))
        }
    }

    private func assignForHabitMutation<Value>(
        _ keyPath: ReferenceWritableKeyPath<HomeViewModel, Value>,
        _ newValue: Value
    ) {
        self[keyPath: keyPath] = newValue
        let erasedKeyPath = keyPath as AnyKeyPath
        invalidateDerivedRowCaches(for: erasedKeyPath)
        if !keyPathTriggersHomeRenderRefreshViaDidSet(erasedKeyPath) {
            scheduleHomeRenderStateRefresh(homeRenderInvalidation(forAssignedKeyPath: erasedKeyPath))
        }
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

    private static var habitMutationFeedbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

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

    private static func buildHomeCalendarSnapshot(
        from snapshot: TaskerCalendarSnapshot,
        selectedDate: Date,
        accessAction: CalendarAccessAction
    ) -> HomeCalendarSnapshot {
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? selectedDayStart
        let selectedDayEvents = snapshot.eventsInRange
            .filter { event in
                event.endDate > selectedDayStart && event.startDate < selectedDayEnd
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
        let selectedDayTimelineEvents = selectedDayEvents.filter { event in
            event.isAllDay == false && event.isBusy
        }
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let todayCount = snapshot.eventsInRange.filter { event in
            event.endDate > startOfToday && event.startDate < endOfToday
        }.count

        let moduleState: HomeCalendarModuleState
        if snapshot.authorizationStatus.isAuthorizedForRead == false {
            moduleState = .permissionRequired
        } else if let error = snapshot.errorMessage, error.isEmpty == false {
            moduleState = .error(message: error)
        } else if snapshot.selectedCalendarIDs.isEmpty {
            moduleState = .noCalendarsSelected
        } else if selectedDayEvents.isEmpty == false && selectedDayTimelineEvents.isEmpty {
            moduleState = .allDayOnly
        } else if selectedDayTimelineEvents.isEmpty {
            moduleState = .empty
        } else {
            moduleState = .active
        }

        return HomeCalendarSnapshot(
            moduleState: moduleState,
            selectedDate: selectedDate,
            authorizationStatus: snapshot.authorizationStatus,
            accessAction: accessAction,
            selectedCalendarCount: snapshot.selectedCalendarIDs.count,
            availableCalendarCount: snapshot.availableCalendars.count,
            nextMeeting: snapshot.nextMeeting,
            busyBlocks: snapshot.busyBlocks,
            freeUntil: snapshot.freeUntil,
            selectedDayEvents: selectedDayEvents,
            selectedDayTimelineEvents: selectedDayTimelineEvents,
            eventsTodayCount: todayCount,
            isLoading: snapshot.isLoading,
            errorMessage: snapshot.errorMessage
        )
    }

    private static func isSameCalendarDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
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
            agendaTailItems: agendaTailItems,
            habitHomeSectionState: habitHomeSectionState,
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
    public let agendaTailItems: [HomeAgendaTailItem]
    public let habitHomeSectionState: HabitHomeSectionState
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

@MainActor
final class HomeTimelineViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published private(set) var foredropAnchor: ForedropAnchor
    @Published private(set) var dragTranslation: CGFloat

    init(
        selectedDate: Date = Date(),
        foredropAnchor: ForedropAnchor = .collapsed,
        dragTranslation: CGFloat = 0
    ) {
        self.selectedDate = selectedDate
        self.foredropAnchor = foredropAnchor
        self.dragTranslation = dragTranslation
    }

    func syncSelectedDate(_ date: Date) {
        guard Calendar.current.isDate(date, inSameDayAs: selectedDate) == false else { return }
        selectedDate = date
    }

    func snap(to anchor: ForedropAnchor) {
        foredropAnchor = anchor
        dragTranslation = 0
    }

    func updateDrag(_ translation: CGFloat, metrics: HomeForedropLayoutMetrics) {
        let baseOffset = metrics.offset(for: foredropAnchor)
        let proposed = baseOffset + translation
        let clamped = min(max(proposed, metrics.offset(for: .collapsed)), metrics.offset(for: .fullReveal))
        dragTranslation = clamped - baseOffset
    }

    func endDrag(predictedTranslation: CGFloat, metrics: HomeForedropLayoutMetrics) {
        let current = interactiveOffset(metrics: metrics)
        let projected = min(
            max(current + (predictedTranslation - dragTranslation), metrics.offset(for: .collapsed)),
            metrics.offset(for: .fullReveal)
        )
        let anchors: [ForedropAnchor] = [.collapsed, .midReveal, .fullReveal]
        let target = anchors.min { lhs, rhs in
            abs(metrics.offset(for: lhs) - projected) < abs(metrics.offset(for: rhs) - projected)
        } ?? .collapsed
        foredropAnchor = target
        dragTranslation = 0
    }

    func interactiveOffset(metrics: HomeForedropLayoutMetrics) -> CGFloat {
        let baseOffset = metrics.offset(for: foredropAnchor)
        let proposed = baseOffset + dragTranslation
        return min(max(proposed, metrics.offset(for: .collapsed)), metrics.offset(for: .fullReveal))
    }
}

extension HomeViewModel {
    func buildTimelineSnapshot(
        calendarSnapshot: HomeCalendarSnapshot,
        foredropAnchor: ForedropAnchor
    ) -> HomeTimelineSnapshot {
        let interval = TaskerPerformanceTrace.begin("HomeTimelineSnapshotBuild")
        defer { TaskerPerformanceTrace.end(interval) }
        let workspacePreferences = workspacePreferencesProvider()
        let showCalendarEventsInTimeline = workspacePreferences.showCalendarEventsInTimeline
        let selectedDay = Calendar.current.startOfDay(for: selectedDate)
        let now = Date()
        let currentMinuteStamp = Int(now.timeIntervalSinceReferenceDate / 60)
        let cacheKey = HomeTimelineSnapshotCacheKey(
            dataRevision: dataRevision,
            selectedDay: selectedDay,
            currentMinuteStamp: currentMinuteStamp,
            foredropAnchor: foredropAnchor,
            calendarSignature: HomeTimelineCalendarSignature(calendarSnapshot),
            workspacePreferences: HomeTimelineWorkspacePreferencesSignature(workspacePreferences),
            hiddenCalendarEvents: hiddenHomeTimelineCalendarEvents.sorted(),
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            needsReplanCandidates: needsReplanCandidates.map(HomeTimelineReplanCandidateSignature.init),
            replanState: HomeTimelineReplanStateSignature(homeReplanState)
        )
        if let cached = timelineSnapshotCache, cached.key == cacheKey {
            return cached.snapshot
        }

        let taskCandidates = timelineTaskCandidates()
        let anchorWindow = resolvedTimelineAnchorWindow(on: selectedDay, preferences: workspacePreferences)
        let wakeAnchor = TimelineAnchorItem(
            id: "wake",
            title: "Rise and shine",
            time: anchorWindow.wake,
            systemImageName: "alarm.fill",
            subtitle: "Start the day"
        )
        let sleepAnchor = TimelineAnchorItem(
            id: "sleep",
            title: "Wind down",
            time: anchorWindow.sleep,
            systemImageName: "moon.fill",
            subtitle: "Close the day"
        )
        let dayTasks = timelineTasksForSelectedDay(candidates: taskCandidates)
        let allDayTasks = dayTasks.filter { task in
            task.isAllDay || timelineIsDateOnlyDueDate(task.dueDate)
        }
        let inboxTasks = dayTasks.filter { task in
            task.isComplete == false
                && task.projectID == ProjectConstants.inboxProjectID
                && task.scheduledStartAt == nil
                && task.scheduledEndAt == nil
                && task.isAllDay == false
                && task.dueDate == nil
        }
        let taskIndexByID = timelineTaskUniverseByID()
        let timedTaskItems = dayTasks.compactMap { task -> TimelinePlanItem? in
            let item = timelinePlanItem(from: task, taskIndexByID: taskIndexByID)
            guard item.isAllDay == false, item.startDate != nil else { return nil }
            return item
        }
        let calendarAllDayItems = showCalendarEventsInTimeline
            ? calendarSnapshot.selectedDayEvents
                .filter(\.isAllDay)
                .filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: selectedDay) }
                .map(timelinePlanItem(from:))
            : []
        let calendarTimedItems = showCalendarEventsInTimeline
            ? calendarSnapshot.selectedDayTimelineEvents
                .filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: selectedDay) }
                .map(timelinePlanItem(from:))
                .sorted { lhs, rhs in
                    guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.title < rhs.title }
                    if lhsStart != rhsStart { return lhsStart < rhsStart }
                    return (lhs.endDate ?? lhsStart) < (rhs.endDate ?? rhsStart)
                }
            : []

        let allDayItems = (allDayTasks.map { timelinePlanItem(from: $0, taskIndexByID: taskIndexByID) } + calendarAllDayItems)
        let inboxItems = inboxTasks.map { timelinePlanItem(from: $0, taskIndexByID: taskIndexByID) }
        let baseTimedItems = (timedTaskItems + calendarTimedItems)
            .sorted { lhs, rhs in
                guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.title < rhs.title }
                if lhsStart != rhsStart { return lhsStart < rhsStart }
                return (lhs.endDate ?? lhsStart) < (rhs.endDate ?? rhsStart)
            }
        let timedBuckets = partitionTimelineItems(
            baseTimedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor
        )
        let allOperationalGaps = timelineOperationalGaps(
            between: timedBuckets.operationalItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxItems.count
        )
        let gaps = timelineGaps(
            between: timedBuckets.operationalItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxItems.count,
            selectedDate: selectedDay,
            now: now
        )
        let layoutMode = timelineDayLayoutMode(
            timedItems: timedBuckets.operationalItems,
            gaps: allOperationalGaps,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor
        )
        let currentItemID = timedBuckets.allItems.first(where: { $0.isActive(at: now) })?.id

        let snapshot = HomeTimelineSnapshot(
            selectedDate: selectedDay,
            foredropAnchor: foredropAnchor,
            day: TimelineDayProjection(
                date: selectedDay,
                allDayItems: allDayItems,
                inboxItems: inboxItems,
                timedItems: timedBuckets.operationalItems,
                gaps: gaps,
                operationalItems: timedBuckets.operationalItems,
                beforeWakeSummaryItems: timedBuckets.beforeWakeItems,
                afterSleepSummaryItems: timedBuckets.afterSleepItems,
                bridgeItems: timedBuckets.bridgeItems,
                actionableGaps: gaps,
                layoutMode: layoutMode,
                calendarPlottingEnabled: showCalendarEventsInTimeline,
                wakeAnchor: wakeAnchor,
                sleepAnchor: sleepAnchor,
                activeItemID: currentItemID,
                currentItemID: currentItemID,
                currentTime: now
            ),
            week: timelineWeekSummary(
                weekStartsOn: workspacePreferences.weekStartsOn,
                includeCalendarEvents: showCalendarEventsInTimeline,
                candidates: taskCandidates
            ),
            placementCandidate: homeReplanState.placementCandidate
        )
        timelineSnapshotCache = (cacheKey, snapshot)
        return snapshot
    }

    func timelineWeekStartsOn() -> Weekday {
        calendarIntegrationService.weekStartsOn
    }

    func showCalendarEventsInTimelineFromHome() {
        TaskerWorkspacePreferencesStore.shared.update { preferences in
            preferences.showCalendarEventsInTimeline = true
        }
        calendarIntegrationService.refreshContext(referenceDate: selectedDate, reason: "home_timeline_show_calendar")
    }

    func hideCalendarEventFromTimeline(eventID: String, on day: Date) {
        hiddenHomeTimelineCalendarEvents = hiddenCalendarEventStore.hide(eventID: eventID, on: day)
    }

    func isCalendarEventHiddenFromHomeTimeline(eventID: String, on day: Date) -> Bool {
        hiddenHomeTimelineCalendarEvents.contains(HomeTimelineHiddenCalendarEventKey(eventID: eventID, day: day))
    }
}

struct TimelineWindowBuckets {
    let allItems: [TimelinePlanItem]
    let beforeWakeItems: [TimelinePlanItem]
    let bridgeIntoWakeItems: [TimelinePlanItem]
    let operationalItems: [TimelinePlanItem]
    let bridgePastSleepItems: [TimelinePlanItem]
    let afterSleepItems: [TimelinePlanItem]

    var bridgeItems: [TimelinePlanItem] {
        bridgeIntoWakeItems + bridgePastSleepItems
    }
}

private func timelinePlanItemSort(lhs: TimelinePlanItem, rhs: TimelinePlanItem) -> Bool {
    guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.title < rhs.title }
    if lhsStart != rhsStart { return lhsStart < rhsStart }
    return (lhs.endDate ?? lhsStart) < (rhs.endDate ?? rhsStart)
}

extension HomeViewModel {
    func timelineTaskCandidates() -> [TaskDefinition] {
        var tasksByID: [UUID: TaskDefinition] = [:]

        func insert(_ task: TaskDefinition) {
            guard task.parentTaskID == nil else { return }
            let relevantDate = timelinePlacementDate(for: task)
            let isScheduled = relevantDate != nil
            let isAllDayTask = task.isAllDay || timelineIsDateOnlyDueDate(task.dueDate)
            let isUnscheduledInbox = task.scheduledStartAt == nil && task.dueDate == nil && task.isComplete == false
            guard isScheduled || isAllDayTask || isUnscheduledInbox else { return }
            tasksByID[task.id] = task
        }

        (morningTasks + eveningTasks + overdueTasks + dailyCompletedTasks + completedTasks + focusTasks)
            .forEach(insert)

        todaySections.forEach { section in
            section.rows.forEach { row in
                guard case .task(let task) = row else { return }
                insert(task)
            }
        }

        dueTodayRows.forEach { row in
            guard case .task(let task) = row else { return }
            insert(task)
        }

        return timelineSortedTasks(Array(tasksByID.values))
    }

    func timelineTasksForSelectedDay() -> [TaskDefinition] {
        timelineTasksForSelectedDay(candidates: timelineTaskCandidates())
    }

    func timelineTasksForSelectedDay(candidates: [TaskDefinition]) -> [TaskDefinition] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        let workspacePreferences = workspacePreferencesProvider()
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        let previousWindow = resolvedTimelineAnchorWindow(on: previousDay, preferences: workspacePreferences, calendar: calendar)

        let filtered = candidates.filter { task in
            let relevantDate = timelinePlacementDate(for: task)
            let isScheduledForDay = relevantDate.map { $0 < selectedDayEnd && $0 >= selectedDay } ?? false
            let isPreviousNightContext = relevantDate.map { date in
                date >= previousWindow.sleep && date < selectedDay
            } ?? false
            let isAllDayForDay = timelineAllDayDate(for: task).map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false
            let isUnscheduledInbox = task.scheduledStartAt == nil && task.dueDate == nil && task.isComplete == false
            return isScheduledForDay || isPreviousNightContext || isAllDayForDay || isUnscheduledInbox
        }

        return timelineSortedTasks(filtered)
    }

    func timelineTasksForWeek(weekStart: Date, weekEnd: Date) -> [TaskDefinition] {
        timelineTasksForWeek(weekStart: weekStart, weekEnd: weekEnd, candidates: timelineTaskCandidates())
    }

    func timelineTasksForWeek(weekStart: Date, weekEnd: Date, candidates: [TaskDefinition]) -> [TaskDefinition] {
        let filtered = candidates.filter { task in
            guard task.scheduledStartAt != nil || task.dueDate != nil else { return false }
            if let placementDate = timelinePlacementDate(for: task) {
                return placementDate >= weekStart && placementDate < weekEnd
            }
            if let allDayDate = timelineAllDayDate(for: task) {
                return allDayDate >= weekStart && allDayDate < weekEnd
            }
            return false
        }

        return timelineSortedTasks(filtered)
    }

    func timelineSortedTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        return tasks.sorted { lhs, rhs in
            let lhsDate = timelinePlacementDate(for: lhs) ?? timelineAllDayDate(for: lhs) ?? lhs.createdAt
            let rhsDate = timelinePlacementDate(for: rhs) ?? timelineAllDayDate(for: rhs) ?? rhs.createdAt
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func timelineWeekSummary(weekStartsOn: Weekday, includeCalendarEvents: Bool) -> TimelineWeekSummary {
        timelineWeekSummary(
            weekStartsOn: weekStartsOn,
            includeCalendarEvents: includeCalendarEvents,
            candidates: timelineTaskCandidates()
        )
    }

    func timelineWeekSummary(
        weekStartsOn: Weekday,
        includeCalendarEvents: Bool,
        candidates: [TaskDefinition]
    ) -> TimelineWeekSummary {
        let calendar = Calendar.current
        let weekStart = XPCalculationEngine.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let calendarAgenda = includeCalendarEvents
            ? calendarIntegrationService.weekAgenda(anchorDate: selectedDate, weekStartsOn: weekStartsOn)
            : []
        let agendaByDay = Dictionary(uniqueKeysWithValues: calendarAgenda.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
        let weekTasks = timelineTasksForWeek(weekStart: weekStart, weekEnd: weekEnd, candidates: candidates)
        let tasksByDay = Dictionary(grouping: weekTasks) { task -> Date in
            if let placementDate = timelinePlacementDate(for: task) {
                return calendar.startOfDay(for: placementDate)
            }
            if let allDayDate = timelineAllDayDate(for: task) {
                return calendar.startOfDay(for: allDayDate)
            }
            return weekStart
        }
        let replanCountsByDay = Dictionary(grouping: needsReplanCandidates.compactMap { candidate -> Date? in
            candidate.anchorDate.map { calendar.startOfDay(for: $0) }
        }) { $0 }
            .mapValues(\.count)

        let days = (0..<7).compactMap { offset -> TimelineWeekDaySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let normalizedDay = calendar.startOfDay(for: day)
            let agenda = agendaByDay[normalizedDay]
            let tasks = tasksByDay[normalizedDay] ?? []
            let taskMarkers = tasks.compactMap { timelinePlacementDate(for: $0) }
            let visibleEvents = includeCalendarEvents
                ? (agenda?.events.filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: normalizedDay) } ?? [])
                : []
            let eventMarkers = visibleEvents.filter { !$0.isAllDay }.map(\.startDate)
            let tints = tasks.compactMap { timelineTintHex(for: $0) } + visibleEvents.compactMap(\.calendarColorHex)
            let allDayCount = tasks.filter { timelineAllDayDate(for: $0) != nil }.count + visibleEvents.filter(\.isAllDay).count
            let timedCount = taskMarkers.count + eventMarkers.count
            let totalCount = allDayCount + timedCount
            let replanEligibleCount = replanCountsByDay[normalizedDay] ?? 0
            return TimelineWeekDaySummary(
                date: normalizedDay,
                dayKey: timelineDayKey(for: normalizedDay, calendar: calendar),
                allDayCount: allDayCount,
                replanEligibleCount: replanEligibleCount,
                timedMarkers: (taskMarkers + eventMarkers).sorted(),
                tintHexes: Array(tints.prefix(4)),
                summaryText: timelineWeekSummaryText(taskCount: taskMarkers.count, eventCount: eventMarkers.count, allDayCount: allDayCount),
                loadLevel: timelineLoadLevel(for: totalCount)
            )
        }

        return TimelineWeekSummary(
            weekStart: weekStart,
            weekStartsOn: weekStartsOn,
            days: days
        )
    }

    func timelineTaskUniverseByID() -> [UUID: TaskDefinition] {
        var universe = uniqueTasks(
            morningTasks
            + eveningTasks
            + overdueTasks
            + dailyCompletedTasks
            + upcomingTasks
            + completedTasks
            + doneTimelineTasks
            + focusTasks
        )
        universe.append(contentsOf: dueTodayRows.compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task
        })
        todaySections.forEach { section in
            universe.append(contentsOf: section.rows.compactMap { row in
                guard case .task(let task) = row else { return nil }
                return task
            })
        }
        return Dictionary(uniqueKeysWithValues: uniqueTasks(universe).map { ($0.id, $0) })
    }

    func timelinePlanItem(from task: TaskDefinition, taskIndexByID: [UUID: TaskDefinition]? = nil) -> TimelinePlanItem {
        // Prefer explicit schedule fields. The dueDate fallback is temporary legacy support.
        let startDate = timelinePlacementDate(for: task)
        let resolvedDuration = task.scheduledEndAt?.timeIntervalSince(startDate ?? task.createdAt)
            ?? task.estimatedDuration
            ?? (30 * 60)
        let endDate = startDate.map { start in
            task.scheduledEndAt ?? start.addingTimeInterval(max(resolvedDuration, 15 * 60))
        }
        let checklistSummary = timelineChecklistSummary(for: task, taskIndexByID: taskIndexByID)
        let hasProjectUtility = {
            guard let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return projectName.isEmpty == false && projectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) != .orderedSame
        }()
        return TimelinePlanItem(
            id: "task:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            eventID: nil,
            title: task.title,
            subtitle: task.projectName,
            startDate: startDate,
            endDate: endDate,
            isAllDay: timelineAllDayDate(for: task) != nil,
            isComplete: task.isComplete,
            tintHex: timelineTintHex(for: task),
            systemImageName: timelineSystemImageName(for: task),
            accessoryText: timelineAccessoryText(for: task),
            taskPriority: task.priority,
            isPinnedFocusTask: pinnedFocusTaskIDs.contains(task.id),
            hasNotes: task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isRecurring: task.repeatPattern != nil || task.recurrenceSeriesID != nil,
            checklistSummary: checklistSummary,
            showsProjectUtility: hasProjectUtility,
            isMeetingLike: task.context == .meeting
        )
    }

    func timelinePlanItem(from task: TaskDefinition, on selectedDay: Date, taskIndexByID: [UUID: TaskDefinition]? = nil) -> TimelinePlanItem? {
        let item = timelinePlanItem(from: task, taskIndexByID: taskIndexByID)
        if item.isAllDay {
            return nil
        }
        guard let startDate = item.startDate else { return nil }
        guard Calendar.current.isDate(startDate, inSameDayAs: selectedDay) else { return nil }
        return item
    }

    func timelinePlanItem(from event: TaskerCalendarEventSnapshot) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "event:\(event.id)",
            source: .calendarEvent,
            taskID: nil,
            eventID: event.id,
            title: event.title,
            subtitle: event.calendarTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isComplete: false,
            tintHex: event.calendarColorHex,
            systemImageName: "calendar",
            accessoryText: nil,
            taskPriority: nil,
            isPinnedFocusTask: false,
            hasNotes: event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isRecurring: false,
            checklistSummary: nil,
            showsProjectUtility: false,
            isMeetingLike: timelineIsMeetingLikeEvent(event)
        )
    }

    func resolvedTimelineAnchorWindow(
        on day: Date,
        preferences: TaskerWorkspacePreferences,
        calendar: Calendar = .current
    ) -> (wake: Date, sleep: Date) {
        let fallbackWake = timelineAnchorTime(on: day, hour: 5, minute: 0)
        let fallbackSleepBase = timelineAnchorTime(on: day, hour: 2, minute: 0)
        let fallbackSleep = calendar.date(byAdding: .day, value: 1, to: fallbackSleepBase) ?? fallbackSleepBase

        let wake = timelineAnchorTime(
            on: day,
            hour: preferences.timelineRiseAndShineHour,
            minute: preferences.timelineRiseAndShineMinute
        )
        var sleep = timelineAnchorTime(
            on: day,
            hour: preferences.timelineWindDownHour,
            minute: preferences.timelineWindDownMinute
        )
        if sleep <= wake {
            sleep = calendar.date(byAdding: .day, value: 1, to: sleep) ?? sleep
        }

        let span = sleep.timeIntervalSince(wake)
        guard span >= 60 * 60, span <= 22 * 60 * 60 else {
            return (fallbackWake, fallbackSleep)
        }
        return (wake, sleep)
    }

    func partitionTimelineItems(
        _ items: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelineWindowBuckets {
        let decoratedItems = items.map { item in
            decorateTimelineItem(item, wakeAnchor: wakeAnchor, sleepAnchor: sleepAnchor)
        }
        let beforeWakeItems = decoratedItems.filter { $0.windowRelation == .beforeWake }
        let afterSleepItems = decoratedItems.filter { $0.windowRelation == .afterSleep }
        let bridgeIntoWakeItems = decoratedItems.filter { $0.windowRelation == .bridgeIntoWake }
        let bridgePastSleepItems = decoratedItems.filter { $0.windowRelation == .bridgePastSleep }
        let operationalItems = (bridgeIntoWakeItems
            + decoratedItems.filter { $0.windowRelation == .operational }
            + bridgePastSleepItems)
            .sorted(by: timelinePlanItemSort)

        return TimelineWindowBuckets(
            allItems: decoratedItems.sorted(by: timelinePlanItemSort),
            beforeWakeItems: beforeWakeItems.sorted(by: timelinePlanItemSort),
            bridgeIntoWakeItems: bridgeIntoWakeItems.sorted(by: timelinePlanItemSort),
            operationalItems: operationalItems,
            bridgePastSleepItems: bridgePastSleepItems.sorted(by: timelinePlanItemSort),
            afterSleepItems: afterSleepItems.sorted(by: timelinePlanItemSort)
        )
    }

    func decorateTimelineItem(
        _ item: TimelinePlanItem,
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelinePlanItem {
        guard let start = item.startDate, let end = item.endDate, end > start else {
            return item
        }

        let overlapsWake = start < wakeAnchor.time && end > wakeAnchor.time
        let overlapsSleep = start < sleepAnchor.time && end > sleepAnchor.time
        let windowRelation: TimelineWindowRelation
        if end <= wakeAnchor.time {
            windowRelation = .beforeWake
        } else if start >= sleepAnchor.time {
            windowRelation = .afterSleep
        } else if overlapsWake {
            windowRelation = .bridgeIntoWake
        } else if overlapsSleep {
            windowRelation = .bridgePastSleep
        } else {
            windowRelation = .operational
        }

        return TimelinePlanItem(
            id: item.id,
            source: item.source,
            taskID: item.taskID,
            eventID: item.eventID,
            title: item.title,
            subtitle: item.subtitle,
            startDate: item.startDate,
            endDate: item.endDate,
            isAllDay: item.isAllDay,
            isComplete: item.isComplete,
            tintHex: item.tintHex,
            systemImageName: item.systemImageName,
            accessoryText: item.accessoryText,
            taskPriority: item.taskPriority,
            isPinnedFocusTask: item.isPinnedFocusTask,
            hasNotes: item.hasNotes,
            isRecurring: item.isRecurring,
            checklistSummary: item.checklistSummary,
            showsProjectUtility: item.showsProjectUtility,
            isMeetingLike: item.isMeetingLike,
            windowRelation: windowRelation,
            overlapsWake: overlapsWake,
            overlapsSleep: overlapsSleep
        )
    }

    func timelineGaps(
        between timedItems: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        inboxCount: Int,
        selectedDate: Date,
        now: Date,
        actionableHorizon: TimeInterval = 4 * 60 * 60,
        calendar: Calendar = .current
    ) -> [TimelineGap] {
        let gaps = timelineOperationalGaps(
            between: timedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxCount
        )

        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            return []
        }
        if selectedDay > today {
            return gaps
        }

        let horizonEnd = now.addingTimeInterval(actionableHorizon)
        return gaps.filter { gap in
            guard gap.endDate > now else { return false }
            if gap.startDate <= now && now < gap.endDate {
                return true
            }
            return gap.startDate <= horizonEnd
        }
    }

    func timelineOperationalGaps(
        between timedItems: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        inboxCount: Int
    ) -> [TimelineGap] {
        struct Boundary {
            let start: Date
            let end: Date
            let isSleepAnchor: Bool
        }

        let sortedIntervals: [(start: Date, end: Date)] = timedItems.compactMap { item in
            guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
            let clippedStart = max(start, wakeAnchor.time)
            let clippedEnd = min(end, sleepAnchor.time)
            guard clippedEnd > clippedStart else { return nil }
            return (start: clippedStart, end: clippedEnd)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end < rhs.end
        }

        var mergedIntervals: [(start: Date, end: Date)] = []
        for interval in sortedIntervals {
            if let last = mergedIntervals.last, interval.start <= last.end {
                mergedIntervals[mergedIntervals.count - 1] = (last.start, max(last.end, interval.end))
            } else {
                mergedIntervals.append(interval)
            }
        }

        var boundaries: [Boundary] = [.init(start: wakeAnchor.time, end: wakeAnchor.time, isSleepAnchor: false)]
        boundaries.append(contentsOf: mergedIntervals.map { interval in
            Boundary(start: interval.start, end: interval.end, isSleepAnchor: false)
        })
        boundaries.append(.init(start: sleepAnchor.time, end: sleepAnchor.time, isSleepAnchor: true))
        boundaries.sort { lhs, rhs in lhs.start < rhs.start }

        var gaps: [TimelineGap] = []
        for index in 0..<(boundaries.count - 1) {
            let currentEnd = boundaries[index].end
            let nextStart = boundaries[index + 1].start
            let gapDuration = nextStart.timeIntervalSince(currentEnd)
            guard gapDuration >= 20 * 60 else { continue }
            let isFinalGap = boundaries[index + 1].isSleepAnchor
            let emphasis: TimelineGapEmphasis
            if isFinalGap {
                emphasis = .quietWindow
            } else if gapDuration <= 45 * 60 {
                emphasis = .prepWindow
            } else {
                emphasis = .openTime
            }
            let primaryAction: TimelineGapAction = .addTask
            let secondaryAction: TimelineGapAction? = .planBlock
            let copy = timelineGapCopy(
                duration: gapDuration,
                inboxCount: inboxCount,
                isFinalGap: isFinalGap,
                emphasis: emphasis,
                primaryAction: primaryAction
            )
            gaps.append(TimelineGap(
                startDate: currentEnd,
                endDate: nextStart,
                suggestedTaskCount: inboxCount,
                headline: copy.headline,
                supportingText: copy.supportingText,
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                emphasis: emphasis
            ))
        }
        return gaps
    }

    func timelineDayLayoutMode(
        timedItems: [TimelinePlanItem],
        gaps: [TimelineGap],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelineDayLayoutMode {
        guard timedItems.isEmpty == false else { return .compact }

        let daySpan = max(sleepAnchor.time.timeIntervalSince(wakeAnchor.time), 1)
        let largestGap = gaps.map(\.duration).max() ?? 0
        guard largestGap >= 4 * 60 * 60 else { return .expanded }

        let timedCoverage = timelineCoveredDuration(for: timedItems)
        return (timedCoverage / daySpan) <= 0.22 ? .compact : .expanded
    }

    func timelineCoveredDuration(for timedItems: [TimelinePlanItem]) -> TimeInterval {
        let intervals = timedItems.compactMap { item -> (start: Date, end: Date)? in
            guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
            return (start, end)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }
            return lhs.end < rhs.end
        }

        guard let first = intervals.first else { return 0 }

        var mergedStart = first.start
        var mergedEnd = first.end
        var total: TimeInterval = 0

        for interval in intervals.dropFirst() {
            if interval.start <= mergedEnd {
                mergedEnd = max(mergedEnd, interval.end)
            } else {
                total += mergedEnd.timeIntervalSince(mergedStart)
                mergedStart = interval.start
                mergedEnd = interval.end
            }
        }

        total += mergedEnd.timeIntervalSince(mergedStart)
        return total
    }

    func timelineTintHex(for task: TaskDefinition) -> String? {
        let projectsByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let lifeAreasByID = Dictionary(lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let owningTint = HomeTaskTintResolver.owningSectionAccentHex(
            for: task,
            projectsByID: projectsByID,
            lifeAreasByID: lifeAreasByID
        ) {
            return owningTint
        }

        // Preserve historical timeline fallback when ownership tint cannot be resolved.
        return projectsByID[task.projectID]?.color.hexString ?? task.priority.colorHex
    }

    func timelineDayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func timelineLoadLevel(for totalCount: Int) -> TimelineDayLoadLevel {
        switch totalCount {
        case ..<2:
            return .light
        case 2...4:
            return .balanced
        default:
            return .busy
        }
    }

    func timelineWeekSummaryText(taskCount: Int, eventCount: Int, allDayCount: Int) -> String {
        let totalCount = taskCount + eventCount + allDayCount
        if totalCount == 0 {
            return "Open"
        }
        if totalCount >= 5 {
            return "Busy"
        }
        if eventCount > 0 && taskCount > 0 {
            let taskText = taskCount == 1 ? "1 task" : "\(taskCount) tasks"
            let eventText = eventCount == 1 ? "1 event" : "\(eventCount) events"
            return "\(taskText) · \(eventText)"
        }
        if taskCount > 0 {
            return taskCount == 1 ? "1 task" : "\(taskCount) tasks"
        }
        if eventCount > 0 {
            return eventCount == 1 ? "1 event" : "\(eventCount) events"
        }
        return allDayCount == 1 ? "1 all-day" : "\(allDayCount) all-day"
    }

    func timelineGapCopy(
        duration: TimeInterval,
        inboxCount: Int,
        isFinalGap: Bool,
        emphasis: TimelineGapEmphasis,
        primaryAction: TimelineGapAction
    ) -> (headline: String, supportingText: String) {
        let durationText = timelineDurationText(duration)
        switch emphasis {
        case .quietWindow:
            return (
                headline: "Evening buffer",
                supportingText: "Need a lighter close with \(durationText)?"
            )
        case .prepWindow:
            return (
                headline: "Short opening",
                supportingText: "Need a short block for \(durationText)?"
            )
        case .openTime:
            return (
                headline: "Open time",
                supportingText: isFinalGap ? "Keep \(durationText) open." : "Want to use \(durationText) well?"
            )
        }
    }

    func timelineChecklistSummary(
        for task: TaskDefinition,
        taskIndexByID: [UUID: TaskDefinition]?
    ) -> TimelineChecklistSummary? {
        guard task.subtasks.isEmpty == false, let taskIndexByID else { return nil }
        let childTasks = task.subtasks.compactMap { taskIndexByID[$0] }
        guard childTasks.count == task.subtasks.count else { return nil }
        return TimelineChecklistSummary(
            completedCount: childTasks.filter(\.isComplete).count,
            totalCount: childTasks.count
        )
    }

    func timelineIsMeetingLikeEvent(_ event: TaskerCalendarEventSnapshot) -> Bool {
        let normalized = "\(event.title) \(event.calendarTitle)".lowercased()
        return normalized.contains("meet")
            || normalized.contains("zoom")
            || normalized.contains("call")
            || normalized.contains("video")
    }

    func timelineDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    func timelineSystemImageName(for task: TaskDefinition) -> String {
        if let iconSymbolName = task.iconSymbolName, iconSymbolName.isEmpty == false {
            return iconSymbolName
        }
        if let project = projects.first(where: { $0.id == task.projectID }) {
            return project.icon.systemImageName
        }
        switch task.category {
        case .work:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .personal:
            return "person.fill"
        case .shopping:
            return "cart.fill"
        default:
            return "checklist"
        }
    }

    func timelineAccessoryText(for task: TaskDefinition) -> String? {
        if task.isComplete {
            return "Done"
        }
        let now = Date()
        guard let start = timelinePlacementDate(for: task) else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let end = task.scheduledEndAt ?? start.addingTimeInterval(max(task.estimatedDuration ?? 30 * 60, 15 * 60))
        guard start <= now, end > now else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let roundedMinutes = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
        return "\(roundedMinutes)m remaining"
    }

    func timelineAnchorTime(on day: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }

    func timelineIsDateOnlyDueDate(_ date: Date?) -> Bool {
        guard let date else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    func timelinePlacementDate(for task: TaskDefinition) -> Date? {
        task.scheduledStartAt ?? (timelineIsDateOnlyDueDate(task.dueDate) ? nil : task.dueDate)
    }

    func timelineAllDayDate(for task: TaskDefinition) -> Date? {
        if task.isAllDay {
            return task.dueDate ?? task.scheduledStartAt
        }
        if timelineIsDateOnlyDueDate(task.dueDate) {
            return task.dueDate
        }
        return nil
    }

    static func timelineDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }
}

enum TaskListWidgetCalendarProjection {
    static func make(
        from snapshot: TaskerCalendarSnapshot,
        weekStartsOn: Weekday,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskListWidgetCalendarSnapshot {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let todayEvents = events(
            from: snapshot.eventsInRange,
            start: startOfToday,
            end: endOfToday
        )
        let timedEvents = todayEvents
            .filter { $0.isAllDay == false && $0.isBusy }
            .map(calendarEvent(from:))
        let allDayEvents = todayEvents
            .filter(\.isAllDay)
            .map(calendarEvent(from:))

        return TaskListWidgetCalendarSnapshot(
            status: status(from: snapshot, todayEvents: todayEvents, timedEvents: timedEvents),
            date: startOfToday,
            updatedAt: now,
            selectedCalendarCount: snapshot.selectedCalendarIDs.count,
            availableCalendarCount: snapshot.availableCalendars.count,
            eventsTodayCount: todayEvents.count,
            nextMeeting: snapshot.nextMeeting.map(nextMeeting(from:)),
            freeUntil: snapshot.freeUntil,
            timedEvents: timedEvents,
            allDayEvents: allDayEvents,
            weekDays: weekDays(
                from: snapshot.eventsInRange,
                anchorDate: startOfToday,
                weekStartsOn: weekStartsOn,
                calendar: calendar
            ),
            isLoading: snapshot.isLoading,
            errorMessage: snapshot.errorMessage
        )
    }

    private static func status(
        from snapshot: TaskerCalendarSnapshot,
        todayEvents: [TaskerCalendarEventSnapshot],
        timedEvents: [TaskListWidgetCalendarEvent]
    ) -> TaskListWidgetCalendarStatus {
        if snapshot.authorizationStatus.isAuthorizedForRead == false {
            return .permissionRequired
        }
        if let error = snapshot.errorMessage, error.isEmpty == false {
            return .error
        }
        if snapshot.selectedCalendarIDs.isEmpty {
            return .noCalendarsSelected
        }
        if todayEvents.isEmpty == false && timedEvents.isEmpty {
            return .allDayOnly
        }
        if timedEvents.isEmpty {
            return .empty
        }
        return .active
    }

    private static func weekDays(
        from sourceEvents: [TaskerCalendarEventSnapshot],
        anchorDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar
    ) -> [TaskListWidgetCalendarDay] {
        let weekStart = XPCalculationEngine.startOfWeek(
            for: anchorDate,
            startingOn: weekStartsOn,
            calendar: calendar
        )

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayEvents = events(from: sourceEvents, start: dayStart, end: dayEnd)
            return TaskListWidgetCalendarDay(
                date: dayStart,
                eventCount: dayEvents.count,
                timedEvents: dayEvents
                    .filter { $0.isAllDay == false && $0.isBusy }
                    .prefix(3)
                    .map(calendarEvent(from:)),
                allDayEvents: dayEvents
                    .filter(\.isAllDay)
                    .prefix(2)
                    .map(calendarEvent(from:))
            )
        }
    }

    private static func events(
        from sourceEvents: [TaskerCalendarEventSnapshot],
        start: Date,
        end: Date
    ) -> [TaskerCalendarEventSnapshot] {
        sourceEvents
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }

    private static func nextMeeting(
        from summary: TaskerNextMeetingSummary
    ) -> TaskListWidgetCalendarNextMeeting {
        TaskListWidgetCalendarNextMeeting(
            event: calendarEvent(from: summary.event),
            isInProgress: summary.isInProgress,
            minutesUntilStart: summary.minutesUntilStart
        )
    }

    private static func calendarEvent(
        from event: TaskerCalendarEventSnapshot
    ) -> TaskListWidgetCalendarEvent {
        TaskListWidgetCalendarEvent(
            id: event.id,
            title: event.title,
            calendarTitle: event.calendarTitle,
            calendarColorHex: event.calendarColorHex,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isBusy: event.isBusy,
            isCanceled: event.isCanceled,
            isTentative: event.participationStatus == .tentative
        )
    }
}

enum TaskListWidgetTimelineProjection {
    static func make(
        tasks: [TaskDefinition],
        calendarSnapshot: TaskListWidgetCalendarSnapshot,
        preferences: TaskerWorkspacePreferences,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskListWidgetTimelineSnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let wakeAnchor = timelineAnchorTime(
            on: dayStart,
            hour: preferences.timelineRiseAndShineHour,
            minute: preferences.timelineRiseAndShineMinute,
            calendar: calendar
        )
        let sleepAnchor = resolvedSleepAnchor(
            on: dayStart,
            wakeAnchor: wakeAnchor,
            preferences: preferences,
            calendar: calendar
        )
        let calendarItems = preferences.showCalendarEventsInTimeline
            ? calendarSnapshot.timedEvents.map(timelineItem(from:))
            : []
        let allDayCalendarItems = preferences.showCalendarEventsInTimeline
            ? calendarSnapshot.allDayEvents.map(timelineItem(from:))
            : []

        let taskItems = tasks
            .filter { $0.parentTaskID == nil }
            .compactMap { timelineItem(from: $0, dayStart: dayStart, dayEnd: dayEnd, now: now, calendar: calendar) }
        let timedTaskItems = taskItems.filter { $0.isAllDay == false && $0.startDate != nil }
        let allDayTaskItems = taskItems.filter(\.isAllDay)
        let inboxItems = tasks
            .filter { isInboxCaptureTask($0) }
            .sorted(by: sortTasksForTimeline)
            .prefix(4)
            .map { inboxItem(from: $0) }

        let rawTimedItems = (timedTaskItems + calendarItems).sorted(by: sortItemsForTimeline)
        let currentItemID = currentTimelineItemID(in: rawTimedItems, now: now)
        let timedItems = rawTimedItems.map { item in
            var value = item
            value.isCurrent = value.id == currentItemID
            return value
        }
        let allDayItems = (allDayTaskItems + allDayCalendarItems).sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        let gaps = timelineGaps(
            timedItems: timedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxItems.count,
            now: now
        )
        let weekDays = weekDays(
            tasks: tasks,
            calendarSnapshot: calendarSnapshot,
            preferences: preferences,
            anchorDate: dayStart,
            calendar: calendar
        )

        return TaskListWidgetTimelineSnapshot(
            date: dayStart,
            updatedAt: now,
            day: TaskListWidgetTimelineDay(
                date: dayStart,
                wakeAnchor: wakeAnchor,
                sleepAnchor: sleepAnchor,
                currentTime: now,
                allDayItems: Array(allDayItems.prefix(6)),
                inboxItems: Array(inboxItems),
                timedItems: Array(timedItems.prefix(12)),
                gaps: Array(gaps.prefix(4)),
                currentItemID: currentItemID
            ),
            weekDays: weekDays,
            calendarPlottingEnabled: preferences.showCalendarEventsInTimeline
        )
    }

    private static func timelineItem(
        from task: TaskDefinition,
        dayStart: Date,
        dayEnd: Date,
        now: Date,
        calendar: Calendar
    ) -> TaskListWidgetTimelineItem? {
        if let allDayDate = allDayDate(for: task, calendar: calendar),
           calendar.isDate(allDayDate, inSameDayAs: dayStart) {
            return TaskListWidgetTimelineItem(
                id: "task:\(task.id.uuidString)",
                source: .task,
                taskID: task.id,
                title: task.title,
                subtitle: task.projectLabelForWidget,
                startDate: allDayDate,
                endDate: nil,
                isAllDay: true,
                isComplete: task.isComplete,
                tintHex: task.priority.colorHex,
                systemImageName: systemImageName(for: task),
                accessoryText: task.isComplete ? "Done" : nil
            )
        }

        guard let start = placementDate(for: task, calendar: calendar) else { return nil }
        let duration = max(task.scheduledEndAt?.timeIntervalSince(start) ?? task.estimatedDuration ?? 30 * 60, 15 * 60)
        let end = task.scheduledEndAt ?? start.addingTimeInterval(duration)
        guard end > dayStart, start < dayEnd else { return nil }

        return TaskListWidgetTimelineItem(
            id: "task:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            title: task.title,
            subtitle: task.projectLabelForWidget,
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: task.isComplete,
            tintHex: task.priority.colorHex,
            systemImageName: systemImageName(for: task),
            accessoryText: accessoryText(for: task, start: start, end: end, now: now)
        )
    }

    private static func timelineItem(from event: TaskListWidgetCalendarEvent) -> TaskListWidgetTimelineItem {
        TaskListWidgetTimelineItem(
            id: "event:\(event.id)",
            source: .calendarEvent,
            eventID: event.id,
            title: event.title,
            subtitle: event.calendarTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isComplete: false,
            tintHex: event.calendarColorHex,
            systemImageName: event.isAllDay ? "sun.max" : "calendar.badge.clock",
            accessoryText: event.isTentative ? "Tentative" : nil
        )
    }

    private static func inboxItem(from task: TaskDefinition) -> TaskListWidgetTimelineItem {
        TaskListWidgetTimelineItem(
            id: "inbox:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            title: task.title,
            subtitle: task.projectLabelForWidget,
            isAllDay: false,
            isComplete: false,
            tintHex: task.priority.colorHex,
            systemImageName: systemImageName(for: task),
            accessoryText: task.priority.code
        )
    }

    private static func weekDays(
        tasks: [TaskDefinition],
        calendarSnapshot: TaskListWidgetCalendarSnapshot,
        preferences: TaskerWorkspacePreferences,
        anchorDate: Date,
        calendar: Calendar
    ) -> [TaskListWidgetTimelineWeekDay] {
        let weekStart = XPCalculationEngine.startOfWeek(
            for: anchorDate,
            startingOn: preferences.weekStartsOn,
            calendar: calendar
        )
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayTasks = tasks.filter { task in
                if let allDayDate = allDayDate(for: task, calendar: calendar) {
                    return calendar.isDate(allDayDate, inSameDayAs: dayStart)
                }
                guard let start = placementDate(for: task, calendar: calendar) else { return false }
                let end = task.scheduledEndAt ?? start.addingTimeInterval(max(task.estimatedDuration ?? 30 * 60, 15 * 60))
                return end > dayStart && start < dayEnd
            }
            let taskAllDayCount = dayTasks.filter { allDayDate(for: $0, calendar: calendar) != nil }.count
            let taskTimedCount = dayTasks.count - taskAllDayCount
            let calendarDay = preferences.showCalendarEventsInTimeline
                ? calendarSnapshot.weekDays.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
                : nil
            let calendarAllDayCount = calendarDay?.allDayEvents.count ?? 0
            let calendarTimedCount = calendarDay.map { max(0, $0.eventCount - $0.allDayEvents.count) } ?? 0
            let allDayCount = taskAllDayCount + calendarAllDayCount
            let timedCount = taskTimedCount + calendarTimedCount
            let tints = dayTasks.map { $0.priority.colorHex } + (calendarDay?.timedEvents.compactMap(\.calendarColorHex) ?? [])

            return TaskListWidgetTimelineWeekDay(
                date: dayStart,
                dayKey: dayKey(for: dayStart, calendar: calendar),
                allDayCount: allDayCount,
                timedCount: timedCount,
                tintHexes: Array(tints.prefix(4)),
                loadLevel: loadLevel(for: allDayCount + timedCount)
            )
        }
    }

    private static func timelineGaps(
        timedItems: [TaskListWidgetTimelineItem],
        wakeAnchor: Date,
        sleepAnchor: Date,
        inboxCount: Int,
        now: Date
    ) -> [TaskListWidgetTimelineGap] {
        guard sleepAnchor > wakeAnchor else { return [] }
        let minimumGap: TimeInterval = 30 * 60
        let intervals = timedItems.compactMap { item -> (start: Date, end: Date)? in
            guard let start = item.startDate, let end = item.endDate else { return nil }
            let clippedStart = max(start, wakeAnchor)
            let clippedEnd = min(end, sleepAnchor)
            guard clippedEnd > clippedStart else { return nil }
            return (clippedStart, clippedEnd)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end < rhs.end
        }

        var merged: [(start: Date, end: Date)] = []
        for interval in intervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged[merged.count - 1] = (last.start, max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        var cursor = wakeAnchor
        var gaps: [TaskListWidgetTimelineGap] = []
        for interval in merged {
            appendGapIfNeeded(start: cursor, end: interval.start, inboxCount: inboxCount, now: now, into: &gaps)
            cursor = max(cursor, interval.end)
        }
        appendGapIfNeeded(start: cursor, end: sleepAnchor, inboxCount: inboxCount, now: now, into: &gaps)
        return gaps
    }

    private static func appendGapIfNeeded(
        start: Date,
        end: Date,
        inboxCount: Int,
        now: Date,
        into gaps: inout [TaskListWidgetTimelineGap]
    ) {
        guard end.timeIntervalSince(start) >= 30 * 60 else { return }
        let headline = start <= now && end > now ? "Open now" : "Open time"
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let supporting = inboxCount > 0
            ? "\(minutes)m available. Place an Inbox task here."
            : "\(minutes)m available. Add a task for this window."
        gaps.append(TaskListWidgetTimelineGap(
            startDate: start,
            endDate: end,
            suggestedTaskCount: inboxCount,
            headline: headline,
            supportingText: supporting
        ))
    }

    private static func currentTimelineItemID(in items: [TaskListWidgetTimelineItem], now: Date) -> String? {
        if let current = items.first(where: { item in
            guard item.isComplete == false, let start = item.startDate, let end = item.endDate else { return false }
            return start <= now && end > now
        }) {
            return current.id
        }
        return items.first { item in
            guard let start = item.startDate else { return false }
            return start >= now
        }?.id
    }

    private static func sortItemsForTimeline(_ lhs: TaskListWidgetTimelineItem, _ rhs: TaskListWidgetTimelineItem) -> Bool {
        let lhsStart = lhs.startDate ?? Date.distantFuture
        let rhsStart = rhs.startDate ?? Date.distantFuture
        if lhsStart != rhsStart { return lhsStart < rhsStart }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func sortTasksForTimeline(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func isInboxCaptureTask(_ task: TaskDefinition) -> Bool {
        guard task.isComplete == false, task.parentTaskID == nil else { return false }
        guard task.scheduledStartAt == nil, task.dueDate == nil else { return false }
        let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return task.projectID == ProjectConstants.inboxProjectID
            || projectName.isEmpty
            || projectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    private static func placementDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        task.scheduledStartAt ?? (isDateOnly(task.dueDate, calendar: calendar) ? nil : task.dueDate)
    }

    private static func allDayDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        if task.isAllDay {
            return task.dueDate ?? task.scheduledStartAt
        }
        if isDateOnly(task.dueDate, calendar: calendar) {
            return task.dueDate
        }
        return nil
    }

    private static func isDateOnly(_ date: Date?, calendar: Calendar) -> Bool {
        guard let date else { return false }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    private static func timelineAnchorTime(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }

    private static func resolvedSleepAnchor(
        on day: Date,
        wakeAnchor: Date,
        preferences: TaskerWorkspacePreferences,
        calendar: Calendar
    ) -> Date {
        var sleep = timelineAnchorTime(
            on: day,
            hour: preferences.timelineWindDownHour,
            minute: preferences.timelineWindDownMinute,
            calendar: calendar
        )
        if sleep <= wakeAnchor {
            sleep = calendar.date(byAdding: .day, value: 1, to: sleep) ?? sleep
        }
        return sleep
    }

    private static func accessoryText(for task: TaskDefinition, start: Date, end: Date, now: Date) -> String? {
        if task.isComplete {
            return "Done"
        }
        if start <= now, end > now {
            let roundedMinutes = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
            return "\(roundedMinutes)m left"
        }
        if let duration = task.estimatedDuration {
            return durationText(duration)
        }
        return task.priority.code
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private static func systemImageName(for task: TaskDefinition) -> String {
        if let iconSymbolName = task.iconSymbolName, iconSymbolName.isEmpty == false {
            return iconSymbolName
        }
        switch task.category {
        case .work:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .personal:
            return "person.fill"
        case .shopping:
            return "cart.fill"
        default:
            return "checklist"
        }
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func loadLevel(for count: Int) -> TaskListWidgetTimelineLoadLevel {
        if count >= 5 { return .busy }
        if count >= 2 { return .balanced }
        return .light
    }
}

private extension TaskDefinition {
    var projectLabelForWidget: String {
        let projectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return projectName?.isEmpty == false ? projectName! : ProjectConstants.inboxProjectName
    }
}

final class TaskListWidgetSnapshotService {
    static let shared = TaskListWidgetSnapshotService()

    private let queue = DispatchQueue(label: "tasker.tasklist.widget.snapshot", qos: .utility)
    private let debounceDelay: TimeInterval = 0.75
    private var pendingWorkItem: DispatchWorkItem?
    private var refreshInFlight = false
    private var queuedReasonAfterRefresh: String?

    private init() {}

    func scheduleRefresh(reason: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.refreshInFlight {
                self.queuedReasonAfterRefresh = reason
                return
            }
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
        if refreshInFlight {
            queuedReasonAfterRefresh = reason
            return
        }
        refreshInFlight = true
        pendingWorkItem = nil
        TaskerMemoryDiagnostics.checkpoint(
            event: "widget_snapshot_refresh_started",
            message: "Refreshing task list widget snapshot",
            fields: ["reason": reason]
        )

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
                self.finishRefresh()
            case .success(let tasks):
                TaskerMemoryDiagnostics.checkpoint(
                    event: "widget_snapshot_refresh_loaded",
                    message: "Loaded task list widget source data",
                    fields: ["reason": reason],
                    counts: ["task_count": tasks.count]
                )
                let calendarSnapshot = TaskListWidgetCalendarProjection.make(
                    from: coordinator.calendarIntegrationService.snapshot,
                    weekStartsOn: coordinator.calendarIntegrationService.weekStartsOn
                )
                let workspacePreferences = TaskerWorkspacePreferencesStore.shared.load()
                let snapshot = self.buildSnapshot(
                    tasks: tasks,
                    calendarSnapshot: calendarSnapshot,
                    workspacePreferences: workspacePreferences
                )
                self.persistIfChanged(snapshot: snapshot, reason: reason)
                self.finishRefresh()
            }
        }
    }

    private func finishRefresh() {
        queue.async { [weak self] in
            guard let self else { return }
            self.refreshInFlight = false
            guard let queuedReason = self.queuedReasonAfterRefresh else { return }
            self.queuedReasonAfterRefresh = nil
            self.scheduleRefresh(reason: queuedReason)
        }
    }

    private func currentCoordinator() -> UseCaseCoordinator? {
        let container = PresentationDependencyContainer.shared
        guard container.isConfiguredForRuntime else { return nil }
        return container.coordinator
    }

    private func buildSnapshot(
        tasks: [TaskDefinition],
        now: Date = Date(),
        calendarSnapshot: TaskListWidgetCalendarSnapshot = .empty,
        workspacePreferences: TaskerWorkspacePreferences = TaskerWorkspacePreferences()
    ) -> TaskListWidgetSnapshot {
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
        let timelineSnapshot = TaskListWidgetTimelineProjection.make(
            tasks: tasks,
            calendarSnapshot: calendarSnapshot,
            preferences: workspacePreferences,
            now: now,
            calendar: calendar
        )

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
            ),
            calendar: calendarSnapshot,
            timeline: timelineSnapshot
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
        if Self.normalizedForReloadComparison(snapshot) == Self.normalizedForReloadComparison(current) {
            return
        }
        snapshot.save()
        reloadTaskListTimelines()
        logDebug("TASK_WIDGET_SNAPSHOT refreshed reason=\(reason)")
    }

    static func normalizedForReloadComparison(_ snapshot: TaskListWidgetSnapshot) -> TaskListWidgetSnapshot {
        var value = snapshot
        value.updatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.generatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.hasCorruptionFallback = false
        value.calendar.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.day.currentTime = Date(timeIntervalSince1970: 0)
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
            "HomeCalendarWidget", "HomeTimelineWidget",
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
