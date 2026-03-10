import Foundation
import Combine
import CoreGraphics
import UIKit

extension XPCalculationEngine.Milestone: Equatable {
    public static func == (lhs: XPCalculationEngine.Milestone, rhs: XPCalculationEngine.Milestone) -> Bool {
        lhs.xpThreshold == rhs.xpThreshold
            && lhs.name == rhs.name
            && lhs.sfSymbol == rhs.sfSymbol
    }
}

public enum InsightsMutation: Equatable {
    case taskCompleted
    case taskReopened
    case focusSessionEnded
    case reflectionCompleted
    case xpRecorded
    case cloudReconciled
    case dayBoundaryChanged
}

public enum InsightsWeekScaleMode: String, CaseIterable {
    case goal
    case personalMax

    public var displayName: String {
        switch self {
        case .goal:
            return "Goal scale"
        case .personalMax:
            return "Personal max"
        }
    }
}

public enum InsightsMetricTone: String, Equatable {
    case accent
    case success
    case warning
    case neutral
}

public struct InsightsMetricTile: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let value: String
    public let detail: String
    public let tone: InsightsMetricTone

    public init(
        id: String,
        title: String,
        value: String,
        detail: String,
        tone: InsightsMetricTone = .neutral
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.tone = tone
    }
}

public struct InsightsDistributionItem: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let value: Int
    public let valueText: String
    public let share: Double
    public let tone: InsightsMetricTone

    public init(
        id: String,
        label: String,
        value: Int,
        valueText: String,
        share: Double,
        tone: InsightsMetricTone = .neutral
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.valueText = valueText
        self.share = share
        self.tone = tone
    }
}

public struct InsightsDistributionSection: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let items: [InsightsDistributionItem]
    public let footer: String?

    public init(id: String, title: String, items: [InsightsDistributionItem], footer: String? = nil) {
        self.id = id
        self.title = title
        self.items = items
        self.footer = footer
    }
}

public struct InsightsLeaderboardRow: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let value: String
    public let detail: String
    public let tone: InsightsMetricTone

    public init(
        id: String,
        title: String,
        subtitle: String,
        value: String,
        detail: String,
        tone: InsightsMetricTone = .accent
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.detail = detail
        self.tone = tone
    }
}

public struct InsightsReminderResponseState: Equatable {
    public var totalDeliveries: Int
    public var acknowledgedDeliveries: Int
    public var snoozedDeliveries: Int
    public var pendingDeliveries: Int
    public var responseRate: Double
    public var statusItems: [InsightsDistributionItem]
    public var headline: String
    public var detail: String

    public init(
        totalDeliveries: Int = 0,
        acknowledgedDeliveries: Int = 0,
        snoozedDeliveries: Int = 0,
        pendingDeliveries: Int = 0,
        responseRate: Double = 0,
        statusItems: [InsightsDistributionItem] = [],
        headline: String = "No reminder response data yet.",
        detail: String = "Responses will appear once reminders start getting acknowledged or snoozed."
    ) {
        self.totalDeliveries = totalDeliveries
        self.acknowledgedDeliveries = acknowledgedDeliveries
        self.snoozedDeliveries = snoozedDeliveries
        self.pendingDeliveries = pendingDeliveries
        self.responseRate = responseRate
        self.statusItems = statusItems
        self.headline = headline
        self.detail = detail
    }
}

public struct InsightsTodayState: Equatable {
    public var dailyXP: Int
    public var dailyCap: Int
    public var level: Int
    public var tasksCompletedToday: Int
    public var totalTasksToday: Int
    public var xpBreakdown: [XPBreakdownItem]
    public var recoveryXP: Int
    public var recoveryCount: Int
    public var heroTitle: String
    public var heroSummary: String
    public var coachingPrompt: String
    public var momentumMetrics: [InsightsMetricTile]
    public var paceMetrics: [InsightsMetricTile]
    public var duePressureMetrics: [InsightsMetricTile]
    public var focusMetrics: [InsightsMetricTile]
    public var completionMixSections: [InsightsDistributionSection]
    public var recoveryMetrics: [InsightsMetricTile]

    public init(
        dailyXP: Int = 0,
        dailyCap: Int = GamificationTokens.dailyXPCap,
        level: Int = 1,
        tasksCompletedToday: Int = 0,
        totalTasksToday: Int = 0,
        xpBreakdown: [XPBreakdownItem] = [],
        recoveryXP: Int = 0,
        recoveryCount: Int = 0,
        heroTitle: String = "Build today’s momentum",
        heroSummary: String = "Today turns into signal once you close the first meaningful task.",
        coachingPrompt: String = "Start with one task that clears pressure or unlocks motion.",
        momentumMetrics: [InsightsMetricTile] = [],
        paceMetrics: [InsightsMetricTile] = [],
        duePressureMetrics: [InsightsMetricTile] = [],
        focusMetrics: [InsightsMetricTile] = [],
        completionMixSections: [InsightsDistributionSection] = [],
        recoveryMetrics: [InsightsMetricTile] = []
    ) {
        self.dailyXP = dailyXP
        self.dailyCap = dailyCap
        self.level = level
        self.tasksCompletedToday = tasksCompletedToday
        self.totalTasksToday = totalTasksToday
        self.xpBreakdown = xpBreakdown
        self.recoveryXP = recoveryXP
        self.recoveryCount = recoveryCount
        self.heroTitle = heroTitle
        self.heroSummary = heroSummary
        self.coachingPrompt = coachingPrompt
        self.momentumMetrics = momentumMetrics
        self.paceMetrics = paceMetrics
        self.duePressureMetrics = duePressureMetrics
        self.focusMetrics = focusMetrics
        self.completionMixSections = completionMixSections
        self.recoveryMetrics = recoveryMetrics
    }
}

public struct InsightsWeekState: Equatable {
    public var weeklyBars: [WeeklyBarData]
    public var weeklyTotalXP: Int
    public var previousWeekTotalXP: Int
    public var goalHitDays: Int
    public var bestDayLabel: String
    public var averageDailyXP: Int
    public var heroTitle: String
    public var heroSummary: String
    public var weeklySummaryMetrics: [InsightsMetricTile]
    public var projectLeaderboard: [InsightsLeaderboardRow]
    public var priorityMix: [InsightsDistributionItem]
    public var taskTypeMix: [InsightsDistributionItem]
    public var patternSummary: String
    public var deltaSummary: String

    public init(
        weeklyBars: [WeeklyBarData] = [],
        weeklyTotalXP: Int = 0,
        previousWeekTotalXP: Int = 0,
        goalHitDays: Int = 0,
        bestDayLabel: String = "",
        averageDailyXP: Int = 0,
        heroTitle: String = "Your weekly rhythm",
        heroSummary: String = "Consistency looks better when the week is visible at a glance.",
        weeklySummaryMetrics: [InsightsMetricTile] = [],
        projectLeaderboard: [InsightsLeaderboardRow] = [],
        priorityMix: [InsightsDistributionItem] = [],
        taskTypeMix: [InsightsDistributionItem] = [],
        patternSummary: String = "",
        deltaSummary: String = ""
    ) {
        self.weeklyBars = weeklyBars
        self.weeklyTotalXP = weeklyTotalXP
        self.previousWeekTotalXP = previousWeekTotalXP
        self.goalHitDays = goalHitDays
        self.bestDayLabel = bestDayLabel
        self.averageDailyXP = averageDailyXP
        self.heroTitle = heroTitle
        self.heroSummary = heroSummary
        self.weeklySummaryMetrics = weeklySummaryMetrics
        self.projectLeaderboard = projectLeaderboard
        self.priorityMix = priorityMix
        self.taskTypeMix = taskTypeMix
        self.patternSummary = patternSummary
        self.deltaSummary = deltaSummary
    }
}

public struct InsightsSystemsState: Equatable {
    public var level: Int
    public var totalXP: Int64
    public var nextLevelXP: Int64
    public var currentLevelThreshold: Int64
    public var streakDays: Int
    public var bestStreak: Int
    public var returnStreak: Int
    public var bestReturnStreak: Int
    public var unlockedAchievements: Set<String>
    public var achievementProgress: [AchievementProgressState]
    public var nextMilestone: XPCalculationEngine.Milestone?
    public var milestoneProgress: CGFloat
    public var heroSummary: String
    public var streakMetrics: [InsightsMetricTile]
    public var achievementVelocityMetrics: [InsightsMetricTile]
    public var reminderResponse: InsightsReminderResponseState
    public var focusHealthMetrics: [InsightsMetricTile]
    public var recoveryHealthMetrics: [InsightsMetricTile]

    public init(
        level: Int = 1,
        totalXP: Int64 = 0,
        nextLevelXP: Int64 = 0,
        currentLevelThreshold: Int64 = 0,
        streakDays: Int = 0,
        bestStreak: Int = 0,
        returnStreak: Int = 0,
        bestReturnStreak: Int = 0,
        unlockedAchievements: Set<String> = [],
        achievementProgress: [AchievementProgressState] = [],
        nextMilestone: XPCalculationEngine.Milestone? = nil,
        milestoneProgress: CGFloat = 0,
        heroSummary: String = "Long-term systems become visible once reminders, focus, and recovery are in the same place.",
        streakMetrics: [InsightsMetricTile] = [],
        achievementVelocityMetrics: [InsightsMetricTile] = [],
        reminderResponse: InsightsReminderResponseState = InsightsReminderResponseState(),
        focusHealthMetrics: [InsightsMetricTile] = [],
        recoveryHealthMetrics: [InsightsMetricTile] = []
    ) {
        self.level = level
        self.totalXP = totalXP
        self.nextLevelXP = nextLevelXP
        self.currentLevelThreshold = currentLevelThreshold
        self.streakDays = streakDays
        self.bestStreak = bestStreak
        self.returnStreak = returnStreak
        self.bestReturnStreak = bestReturnStreak
        self.unlockedAchievements = unlockedAchievements
        self.achievementProgress = achievementProgress
        self.nextMilestone = nextMilestone
        self.milestoneProgress = milestoneProgress
        self.heroSummary = heroSummary
        self.streakMetrics = streakMetrics
        self.achievementVelocityMetrics = achievementVelocityMetrics
        self.reminderResponse = reminderResponse
        self.focusHealthMetrics = focusHealthMetrics
        self.recoveryHealthMetrics = recoveryHealthMetrics
    }
}

public struct InsightsTabRefreshState: Equatable {
    public var isLoaded: Bool
    public var inFlight: Bool
    public var requestedVersion: UInt64
    public var loadedVersion: UInt64
    public var needsReplay: Bool
    public var dirtyReason: String?

    public init(
        isLoaded: Bool = false,
        inFlight: Bool = false,
        requestedVersion: UInt64 = 0,
        loadedVersion: UInt64 = 0,
        needsReplay: Bool = false,
        dirtyReason: String? = nil
    ) {
        self.isLoaded = isLoaded
        self.inFlight = inFlight
        self.requestedVersion = requestedVersion
        self.loadedVersion = loadedVersion
        self.needsReplay = needsReplay
        self.dirtyReason = dirtyReason
    }
}

/// ViewModel for the Insights screen.
/// Uses per-tab event-driven invalidation and targeted recompute.
public final class InsightsViewModel: ObservableObject {

    public enum InsightsTab: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case systems = "Systems"
    }

    @Published public private(set) var selectedTab: InsightsTab = .today
    @Published public private(set) var weekScaleMode: InsightsWeekScaleMode = .personalMax
    @Published public private(set) var highlightedAchievementKey: String?
    @Published public private(set) var todayState: InsightsTodayState = InsightsTodayState()
    @Published public private(set) var weekState: InsightsWeekState = InsightsWeekState()
    @Published public private(set) var systemsState: InsightsSystemsState = InsightsSystemsState()

    public var dailyXP: Int { todayState.dailyXP }
    public var dailyCap: Int { todayState.dailyCap }
    public var level: Int { systemsState.level }
    public var tasksCompletedToday: Int { todayState.tasksCompletedToday }
    public var totalTasksToday: Int { todayState.totalTasksToday }
    public var xpBreakdown: [XPBreakdownItem] { todayState.xpBreakdown }
    public var recoveryXP: Int { todayState.recoveryXP }
    public var recoveryCount: Int { todayState.recoveryCount }

    public var weeklyBars: [WeeklyBarData] { weekState.weeklyBars }
    public var weeklyTotalXP: Int { weekState.weeklyTotalXP }
    public var goalHitDays: Int { weekState.goalHitDays }
    public var bestDayLabel: String { weekState.bestDayLabel }
    public var averageDailyXP: Int { weekState.averageDailyXP }

    public var totalXP: Int64 { systemsState.totalXP }
    public var nextLevelXP: Int64 { systemsState.nextLevelXP }
    public var currentLevelThreshold: Int64 { systemsState.currentLevelThreshold }
    public var streakDays: Int { systemsState.streakDays }
    public var bestStreak: Int { systemsState.bestStreak }
    public var unlockedAchievements: Set<String> { systemsState.unlockedAchievements }
    public var achievementProgress: [AchievementProgressState] { systemsState.achievementProgress }
    public var nextMilestone: XPCalculationEngine.Milestone? { systemsState.nextMilestone }
    public var milestoneProgress: CGFloat { systemsState.milestoneProgress }

    private let engine: GamificationEngine
    private let repository: GamificationRepositoryProtocol
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let reminderRepository: ReminderRepositoryProtocol?
    private let analyticsUseCase: CalculateAnalyticsUseCase?
    private let notificationCenter: NotificationCenter
    private let userDefaults: UserDefaults

    private var tabRefreshState: [InsightsTab: InsightsTabRefreshState] = [:]
    private var versionCounter: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()
    private var pendingMutationWorkItem: DispatchWorkItem?
    private var sessionDayKey: String

    private static let dayLetters = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private static let orderedBreakdownCategories = ["complete", "start", "focus", "reflection", "recoverReschedule", "decompose"]
    private static let completionReasons = Set(["task_completion", "complete", "complete_on_time"])
    private static let mutationDebounceInterval: TimeInterval = 0.22
    private static let cloudSyncNotification = Notification.Name("DataDidChangeFromCloudSync")
    private static let weekScaleModeDefaultsKey = "insights.week.scale.mode.v1"
    private static let staleDayThreshold = 14
    private static let duePressureLongTaskThreshold: TimeInterval = 60 * 60
    private static let projectionTaskLimit = 4_000

    public init(
        engine: GamificationEngine,
        repository: GamificationRepositoryProtocol,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        reminderRepository: ReminderRepositoryProtocol? = nil,
        analyticsUseCase: CalculateAnalyticsUseCase? = nil,
        notificationCenter: NotificationCenter = .default,
        userDefaults: UserDefaults = .standard
    ) {
        self.engine = engine
        self.repository = repository
        self.taskReadModelRepository = taskReadModelRepository
        self.reminderRepository = reminderRepository
        self.analyticsUseCase = analyticsUseCase
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.sessionDayKey = Self.dateKey(for: Date(), calendar: XPCalculationEngine.mondayCalendar())
        let persistedScaleMode = userDefaults.string(forKey: Self.weekScaleModeDefaultsKey)
            .flatMap(InsightsWeekScaleMode.init(rawValue:))
        self.weekScaleMode = persistedScaleMode ?? .personalMax

        for tab in InsightsTab.allCases {
            tabRefreshState[tab] = InsightsTabRefreshState()
        }

        bindMutations()
    }

    deinit {
        pendingMutationWorkItem?.cancel()
    }

    public func onAppear() {
        noteDayBoundaryChangeIfNeeded()
        refreshSelectedTabIfNeeded(force: false)
    }

    public func selectTab(_ tab: InsightsTab) {
        if selectedTab != tab {
            selectedTab = tab
        }
        refreshSelectedTabIfNeeded(force: false)
    }

    public func refreshSelectedTabIfNeeded(force: Bool = false) {
        noteDayBoundaryChangeIfNeeded()
        refresh(tab: selectedTab, force: force)
    }

    public func setWeekScaleMode(_ mode: InsightsWeekScaleMode) {
        guard weekScaleMode != mode else { return }
        weekScaleMode = mode
        userDefaults.set(mode.rawValue, forKey: Self.weekScaleModeDefaultsKey)
    }

    public func highlightAchievement(_ key: String?) {
        highlightedAchievementKey = key
    }

    public func consumeHighlightedAchievementKey() -> String? {
        defer { highlightedAchievementKey = nil }
        return highlightedAchievementKey
    }

    public func noteXPMutation() {
        noteMutation(.xpRecorded)
    }

    public func noteMutation(_ mutation: InsightsMutation) {
        let affectedTabs = tabsAffected(by: mutation)
        guard !affectedTabs.isEmpty else { return }

        markDirty(tabs: affectedTabs, reason: reasonLabel(for: mutation))
        if mutation.shouldDebounce {
            scheduleDebouncedSelectedTabRefresh()
        } else if affectedTabs.contains(selectedTab) {
            refreshSelectedTabIfNeeded(force: false)
        }
    }

    public func refresh() {
        markDirty(tabs: Set(InsightsTab.allCases), reason: "manual_refresh")
        refreshSelectedTabIfNeeded(force: true)
    }

    public func refreshState(for tab: InsightsTab) -> InsightsTabRefreshState {
        tabRefreshState[tab] ?? InsightsTabRefreshState()
    }

    private func refresh(tab: InsightsTab, force: Bool) {
        guard var tabState = tabRefreshState[tab] else { return }

        let shouldRefresh = force
            || !tabState.isLoaded
            || tabState.loadedVersion < tabState.requestedVersion
            || tabState.dirtyReason != nil

        guard shouldRefresh else { return }

        if tabState.inFlight {
            tabState.needsReplay = true
            tabRefreshState[tab] = tabState
            return
        }

        tabState.inFlight = true
        let requestedVersion = tabState.requestedVersion
        tabRefreshState[tab] = tabState

        switch tab {
        case .today:
            refreshToday(version: requestedVersion)
        case .week:
            refreshWeek(version: requestedVersion)
        case .systems:
            refreshSystems(version: requestedVersion)
        }
    }

    private func completeRefresh(for tab: InsightsTab, version: UInt64) {
        guard var tabState = tabRefreshState[tab] else { return }
        tabState.inFlight = false
        tabState.isLoaded = true
        tabState.loadedVersion = max(tabState.loadedVersion, version)

        if tabState.loadedVersion >= tabState.requestedVersion {
            tabState.dirtyReason = nil
        }

        let shouldReplay = tabState.needsReplay || tabState.loadedVersion < tabState.requestedVersion
        tabState.needsReplay = false
        tabRefreshState[tab] = tabState

        if shouldReplay {
            refresh(tab: tab, force: true)
        }
    }

    private func markDirty(tabs: Set<InsightsTab>, reason: String) {
        versionCounter += 1
        for tab in tabs {
            guard var tabState = tabRefreshState[tab] else { continue }
            tabState.requestedVersion = versionCounter
            tabState.dirtyReason = reason
            if tabState.inFlight {
                tabState.needsReplay = true
            }
            tabRefreshState[tab] = tabState
        }
    }

    private func bindMutations() {
        notificationCenter.publisher(for: .homeTaskMutation)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let reasonRaw = notification.userInfo?["reason"] as? String
                let reason = reasonRaw.flatMap(HomeTaskMutationEvent.init(rawValue:))
                switch reason {
                case .reopened:
                    self.noteMutation(.taskReopened)
                default:
                    break
                }
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: .gamificationLedgerDidMutate)
            .receive(on: RunLoop.main)
            .compactMap(\.gamificationLedgerMutation)
            .sink { [weak self] mutation in
                self?.handleLedgerMutation(mutation)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: Self.cloudSyncNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.noteMutation(.cloudReconciled)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIApplication.significantTimeChangeNotification)
            .merge(with: notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.noteDayBoundaryChangeIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func scheduleDebouncedSelectedTabRefresh() {
        pendingMutationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshSelectedTabIfNeeded(force: false)
        }
        pendingMutationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.mutationDebounceInterval,
            execute: workItem
        )
    }

    private func noteDayBoundaryChangeIfNeeded() {
        let calendar = XPCalculationEngine.mondayCalendar()
        let newDayKey = Self.dateKey(for: Date(), calendar: calendar)
        guard newDayKey != sessionDayKey else { return }
        sessionDayKey = newDayKey
        noteMutation(.dayBoundaryChanged)
    }

    private func tabsAffected(by mutation: InsightsMutation) -> Set<InsightsTab> {
        switch mutation {
        case .taskCompleted, .taskReopened, .focusSessionEnded, .reflectionCompleted, .xpRecorded, .cloudReconciled:
            return Set(InsightsTab.allCases)
        case .dayBoundaryChanged:
            return [.today, .week]
        }
    }

    private func reasonLabel(for mutation: InsightsMutation) -> String {
        switch mutation {
        case .taskCompleted:
            return "mutation_task_completed"
        case .taskReopened:
            return "mutation_task_reopened"
        case .focusSessionEnded:
            return "mutation_focus_session_ended"
        case .reflectionCompleted:
            return "mutation_reflection_completed"
        case .xpRecorded:
            return "mutation_xp_recorded"
        case .cloudReconciled:
            return "mutation_cloud_reconciled"
        case .dayBoundaryChanged:
            return "mutation_day_boundary"
        }
    }

    private func handleLedgerMutation(_ mutation: GamificationLedgerMutation) {
        noteDayBoundaryChangeIfNeeded()
        guard mutation.didChange else { return }

        applyTodayProjectionDelta(mutation)
        applyWeekProjectionDelta(mutation)
        applySystemsProjectionDelta(mutation)

        let followUpTabs = Set(InsightsTab.allCases.filter { $0 != selectedTab })
        if !followUpTabs.isEmpty {
            markDirty(tabs: followUpTabs, reason: "ledger_mutation_follow_up")
        }

        if selectedTab == .systems {
            markDirty(tabs: [.systems], reason: "ledger_mutation_systems")
        }
        if selectedTab == .systems {
            refresh(tab: .systems, force: false)
        }
    }

    private func applyTodayProjectionDelta(_ mutation: GamificationLedgerMutation) {
        guard tabRefreshState[.today]?.isLoaded == true else { return }

        var next = todayState
        next.dailyXP = max(0, mutation.dailyXPSoFar)
        next.level = max(1, mutation.level)

        if mutation.category == .complete {
            next.tasksCompletedToday += 1
            next.totalTasksToday = max(next.totalTasksToday, next.tasksCompletedToday)
        }
        if mutation.category == .recoverReschedule {
            next.recoveryXP += max(0, mutation.awardedXP)
            next.recoveryCount += 1
        }
        next.xpBreakdown = Self.applyingBreakdownDelta(
            existing: next.xpBreakdown,
            category: mutation.category.rawValue,
            xpDelta: mutation.awardedXP
        )
        next.momentumMetrics = Self.rebuiltTodayMomentumMetrics(from: next)
        next.paceMetrics = Self.rebuiltTodayPaceMetrics(from: next)
        next.recoveryMetrics = Self.rebuiltTodayRecoveryMetrics(from: next, mutation: mutation)
        next.heroSummary = Self.todayHeroSummary(
            completed: next.tasksCompletedToday,
            scheduled: next.totalTasksToday,
            dailyXP: next.dailyXP,
            dailyCap: next.dailyCap,
            duePressure: next.duePressureMetrics
        )

        if todayState != next {
            todayState = next
        }
    }

    private func applyWeekProjectionDelta(_ mutation: GamificationLedgerMutation) {
        guard tabRefreshState[.week]?.isLoaded == true else { return }
        guard !weekState.weeklyBars.isEmpty else { return }

        var bars = weekState.weeklyBars
        guard let index = bars.firstIndex(where: { $0.dateKey == mutation.dateKey }) else { return }

        let existing = bars[index]
        let nextXP = max(0, mutation.dailyXPSoFar)
        let nextCompletionCount = mutation.category == .complete ? existing.completionCount + 1 : existing.completionCount
        guard existing.xp != nextXP || existing.completionCount != nextCompletionCount else { return }

        bars[index] = WeeklyBarData(
            dateKey: existing.dateKey,
            dayIndex: existing.dayIndex,
            label: existing.label,
            xp: nextXP,
            completionCount: nextCompletionCount,
            intensity: existing.intensity,
            isToday: existing.isToday,
            isFuture: existing.isFuture
        )

        let next = Self.recomputeWeekState(
            from: bars,
            previousTotalXP: weekState.previousWeekTotalXP,
            projectLeaderboard: weekState.projectLeaderboard,
            priorityMix: weekState.priorityMix,
            taskTypeMix: weekState.taskTypeMix,
            patternSummary: weekState.patternSummary,
            deltaSummary: weekState.deltaSummary,
            weeklySummaryMetrics: Self.rebuiltWeeklySummaryMetrics(
                existing: weekState.weeklySummaryMetrics,
                bars: bars
            )
        )
        if weekState != next {
            weekState = next
        }
    }

    private func applySystemsProjectionDelta(_ mutation: GamificationLedgerMutation) {
        guard tabRefreshState[.systems]?.isLoaded == true else { return }

        var next = systemsState
        next.totalXP = mutation.totalXP
        next.level = max(1, mutation.level)
        next.streakDays = max(0, mutation.streakDays)
        if !mutation.unlockedAchievementKeys.isEmpty {
            next.unlockedAchievements.formUnion(mutation.unlockedAchievementKeys)
        }

        let levelInfo = XPCalculationEngine.levelForXP(mutation.totalXP)
        next.currentLevelThreshold = levelInfo.currentThreshold
        next.nextLevelXP = levelInfo.nextThreshold

        if let milestone = XPCalculationEngine.nextMilestone(for: mutation.totalXP) {
            next.nextMilestone = milestone
            let previousThreshold = XPCalculationEngine.milestones
                .last(where: { $0.xpThreshold <= mutation.totalXP })?.xpThreshold ?? 0
            let range = milestone.xpThreshold - previousThreshold
            let progress = mutation.totalXP - previousThreshold
            next.milestoneProgress = range > 0 ? CGFloat(progress) / CGFloat(range) : 0
        } else {
            next.nextMilestone = nil
            next.milestoneProgress = 0
        }

        if systemsState != next {
            systemsState = next
        }
        if todayState.level != next.level {
            var today = todayState
            today.level = next.level
            todayState = today
        }
    }

    private func refreshToday(version: UInt64) {
        let calendar = XPCalculationEngine.mondayCalendar()
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let lock = NSLock()
        let group = DispatchGroup()

        var dailyXP = todayState.dailyXP
        var level = todayState.level
        var xpEvents: [XPEventDefinition] = []
        var todayFocusSessions: [FocusSessionDefinition] = []
        var dueWindowTasks: [TaskDefinition] = []
        var recentTasks: [TaskDefinition] = []
        var dailyAnalytics: DailyAnalytics?

        group.enter()
        engine.fetchTodayXP { result in
            lock.lock()
            if case .success(let xp) = result {
                dailyXP = xp
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchXPEvents(from: startOfToday, to: startOfTomorrow) { result in
            lock.lock()
            if case .success(let events) = result {
                xpEvents = events
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchFocusSessions(from: startOfToday, to: startOfTomorrow) { result in
            lock.lock()
            if case .success(let sessions) = result {
                todayFocusSessions = sessions
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        engine.fetchCurrentProfile { result in
            lock.lock()
            if case .success(let profile) = result {
                level = XPCalculationEngine.levelForXP(profile.xpTotal).level
            }
            lock.unlock()
            group.leave()
        }

        if let taskReadModelRepository {
            group.enter()
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    dueDateEnd: startOfTomorrow,
                    sortBy: .dueDateAscending,
                    limit: Self.projectionTaskLimit,
                    offset: 0
                )
            ) { result in
                lock.lock()
                if case .success(let slice) = result {
                    dueWindowTasks = slice.tasks
                }
                lock.unlock()
                group.leave()
            }

            group.enter()
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    sortBy: .updatedAtDescending,
                    limit: Self.projectionTaskLimit,
                    offset: 0
                )
            ) { result in
                lock.lock()
                if case .success(let slice) = result {
                    recentTasks = slice.tasks
                }
                lock.unlock()
                group.leave()
            }
        }

        if let analyticsUseCase {
            group.enter()
            analyticsUseCase.calculateDailyAnalytics(for: startOfToday) { result in
                lock.lock()
                if case .success(let analytics) = result {
                    dailyAnalytics = analytics
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let nextState = Self.buildTodayState(
                dailyXP: dailyXP,
                level: level,
                dailyAnalytics: dailyAnalytics,
                xpEvents: xpEvents,
                recentTasks: recentTasks,
                dueWindowTasks: dueWindowTasks,
                focusSessions: todayFocusSessions,
                dayStart: startOfToday,
                calendar: calendar
            )
            if self.todayState != nextState {
                self.todayState = nextState
            }
            self.completeRefresh(for: .today, version: version)
        }
    }

    private func refreshWeek(version: UInt64) {
        let calendar = XPCalculationEngine.mondayCalendar()
        let today = calendar.startOfDay(for: Date())
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: today, calendar: calendar)
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? previousWeekStart
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let dateFormatter = Self.makeDateFormatter(calendar: calendar)
        let currentWeekStartKey = dateFormatter.string(from: weekStart)
        let currentWeekEndKey = dateFormatter.string(from: weekEndDate)
        let previousWeekStartKey = dateFormatter.string(from: previousWeekStart)
        let previousWeekEndKey = dateFormatter.string(from: previousWeekEnd)

        let lock = NSLock()
        let group = DispatchGroup()

        var currentAggregates: [DailyXPAggregateDefinition] = []
        var previousAggregates: [DailyXPAggregateDefinition] = []
        var currentWeekEvents: [XPEventDefinition] = []
        var previousWeekEvents: [XPEventDefinition] = []
        var recentTasks: [TaskDefinition] = []
        var dueWindowTasks: [TaskDefinition] = []
        var projectScores: [UUID: Int] = [:]

        group.enter()
        repository.fetchDailyAggregates(from: currentWeekStartKey, to: currentWeekEndKey) { result in
            lock.lock()
            if case .success(let aggregates) = result {
                currentAggregates = aggregates
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchDailyAggregates(from: previousWeekStartKey, to: previousWeekEndKey) { result in
            lock.lock()
            if case .success(let aggregates) = result {
                previousAggregates = aggregates
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchXPEvents(from: weekStart, to: startOfTomorrow) { result in
            lock.lock()
            if case .success(let events) = result {
                currentWeekEvents = events
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchXPEvents(from: previousWeekStart, to: weekStart) { result in
            lock.lock()
            if case .success(let events) = result {
                previousWeekEvents = events
            }
            lock.unlock()
            group.leave()
        }

        if let taskReadModelRepository {
            group.enter()
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    sortBy: .updatedAtDescending,
                    limit: Self.projectionTaskLimit,
                    offset: 0
                )
            ) { result in
                lock.lock()
                if case .success(let slice) = result {
                    recentTasks = slice.tasks
                }
                lock.unlock()
                group.leave()
            }

            group.enter()
            taskReadModelRepository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    dueDateEnd: startOfTomorrow,
                    sortBy: .dueDateAscending,
                    limit: Self.projectionTaskLimit,
                    offset: 0
                )
            ) { result in
                lock.lock()
                if case .success(let slice) = result {
                    dueWindowTasks = slice.tasks
                }
                lock.unlock()
                group.leave()
            }

            group.enter()
            taskReadModelRepository.fetchProjectCompletionScoreTotals(from: weekStart, to: weekEndDate) { result in
                lock.lock()
                if case .success(let scores) = result {
                    projectScores = scores
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let nextState = Self.buildWeekState(
                currentAggregates: currentAggregates,
                previousAggregates: previousAggregates,
                currentWeekEvents: currentWeekEvents,
                previousWeekEvents: previousWeekEvents,
                recentTasks: recentTasks,
                dueWindowTasks: dueWindowTasks,
                projectScores: projectScores,
                weekStart: weekStart,
                today: today,
                calendar: calendar
            )
            if self.weekState != nextState {
                self.weekState = nextState
            }
            self.completeRefresh(for: .week, version: version)
        }
    }

    private func refreshSystems(version: UInt64) {
        let lock = NSLock()
        let group = DispatchGroup()
        let now = Date()
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now

        var state = systemsState
        var latestProfile: GamificationSnapshot?
        var unlocks: [AchievementUnlockDefinition] = []
        var events: [XPEventDefinition] = []
        var focusSessions: [FocusSessionDefinition] = []
        var reminders: [ReminderDefinition] = []
        var deliveriesByReminderID: [UUID: [ReminderDeliveryDefinition]] = [:]

        group.enter()
        engine.fetchCurrentProfile { result in
            lock.lock()
            if case .success(let profile) = result {
                latestProfile = profile
                let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                state.level = levelInfo.level
                state.totalXP = profile.xpTotal
                state.currentLevelThreshold = levelInfo.currentThreshold
                state.nextLevelXP = levelInfo.nextThreshold
                state.streakDays = profile.currentStreak
                state.bestStreak = max(profile.bestStreak, profile.bestReturnStreak)
                state.returnStreak = profile.returnStreak
                state.bestReturnStreak = profile.bestReturnStreak

                if let milestone = XPCalculationEngine.nextMilestone(for: profile.xpTotal) {
                    state.nextMilestone = milestone
                    let previousThreshold = XPCalculationEngine.milestones
                        .last(where: { $0.xpThreshold <= profile.xpTotal })?.xpThreshold ?? 0
                    let range = milestone.xpThreshold - previousThreshold
                    let progress = profile.xpTotal - previousThreshold
                    state.milestoneProgress = range > 0 ? CGFloat(progress) / CGFloat(range) : 0
                } else {
                    state.nextMilestone = nil
                    state.milestoneProgress = 0
                }
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchAchievementUnlocks { result in
            lock.lock()
            if case .success(let fetchedUnlocks) = result {
                unlocks = fetchedUnlocks
                state.unlockedAchievements = Set(fetchedUnlocks.map(\.achievementKey))
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchXPEvents { result in
            lock.lock()
            if case .success(let fetchedEvents) = result {
                events = fetchedEvents
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        repository.fetchFocusSessions(from: lookbackStart, to: now) { result in
            lock.lock()
            if case .success(let fetchedSessions) = result {
                focusSessions = fetchedSessions
            }
            lock.unlock()
            group.leave()
        }

        if let reminderRepository {
            group.enter()
            reminderRepository.fetchReminders { result in
                switch result {
                case .failure:
                    group.leave()
                case .success(let fetchedReminders):
                    lock.lock()
                    reminders = fetchedReminders
                    lock.unlock()

                    if fetchedReminders.isEmpty {
                        group.leave()
                        return
                    }

                    let nestedGroup = DispatchGroup()
                    for reminder in fetchedReminders {
                        nestedGroup.enter()
                        reminderRepository.fetchDeliveries(reminderID: reminder.id) { deliveryResult in
                            lock.lock()
                            if case .success(let deliveries) = deliveryResult {
                                deliveriesByReminderID[reminder.id] = deliveries
                            }
                            lock.unlock()
                            nestedGroup.leave()
                        }
                    }

                    nestedGroup.notify(queue: .global()) {
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            state.achievementProgress = Self.buildAchievementProgress(
                profile: latestProfile,
                unlocks: unlocks,
                events: events
            )

            let responseState = Self.buildReminderResponseState(
                reminders: reminders,
                deliveriesByReminderID: deliveriesByReminderID
            )
            state.reminderResponse = responseState
            state.streakMetrics = Self.buildStreakMetrics(
                profile: latestProfile ?? GamificationSnapshot(),
                reminderResponse: responseState
            )
            state.achievementVelocityMetrics = Self.buildAchievementVelocityMetrics(unlocks: unlocks)
            state.focusHealthMetrics = Self.buildFocusHealthMetrics(sessions: focusSessions)
            state.recoveryHealthMetrics = Self.buildRecoveryHealthMetrics(events: events, now: now)
            state.heroSummary = Self.buildSystemsHeroSummary(
                profile: latestProfile ?? GamificationSnapshot(),
                reminderResponse: responseState,
                focusSessions: focusSessions
            )

            if self.systemsState != state {
                self.systemsState = state
            }
            if self.todayState.level != state.level {
                var today = self.todayState
                today.level = state.level
                self.todayState = today
            }
            self.completeRefresh(for: .systems, version: version)
        }
    }

    private static func buildTodayState(
        dailyXP: Int,
        level: Int,
        dailyAnalytics: DailyAnalytics?,
        xpEvents: [XPEventDefinition],
        recentTasks: [TaskDefinition],
        dueWindowTasks: [TaskDefinition],
        focusSessions: [FocusSessionDefinition],
        dayStart: Date,
        calendar: Calendar
    ) -> InsightsTodayState {
        let summary = summarize(events: xpEvents)
        let completedTodayTasks = recentTasks.filter {
            guard $0.isComplete, let completedAt = $0.dateCompleted else { return false }
            return completedAt >= dayStart && completedAt < calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        }
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let openDuePressureTasks = dueWindowTasks.filter { task in
            guard !task.isComplete, let dueDate = task.dueDate else { return false }
            return dueDate < startOfTomorrow
        }
        let overdueOpen = openDuePressureTasks.filter {
            guard let dueDate = $0.dueDate else { return false }
            return dueDate < dayStart
        }
        let dueTodayOpen = openDuePressureTasks.filter {
            guard let dueDate = $0.dueDate else { return false }
            return dueDate >= dayStart && dueDate < startOfTomorrow
        }
        let scheduledCount = max(
            dailyAnalytics?.totalTasks ?? 0,
            completedTodayTasks.count + dueTodayOpen.count,
            summary.tasksCompleted
        )
        let staleOverdueCount = overdueOpen.filter {
            guard let dueDate = $0.dueDate else { return false }
            let overdueDay = calendar.startOfDay(for: dueDate)
            return (calendar.dateComponents([.day], from: overdueDay, to: dayStart).day ?? 0) >= staleDayThreshold
        }.count
        let blockedCount = openDuePressureTasks.filter { !$0.dependencies.isEmpty }.count
        let longTaskCount = openDuePressureTasks.filter { ($0.estimatedDuration ?? 0) >= duePressureLongTaskThreshold }.count
        let completedHighPriorityCount = completedTodayTasks.filter { $0.priority.isHighPriority }.count
        let morningCompletedCount = completedTodayTasks.filter { !$0.isEveningTask && $0.type != .evening }.count
        let eveningCompletedCount = completedTodayTasks.filter { $0.isEveningTask || $0.type == .evening }.count

        let totalFocusMinutes = focusSessions.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }
        let completedFocusSessions = focusSessions.filter(\.wasCompleted)
        let averageFocusMinutes = focusSessions.isEmpty ? 0 : Int((focusSessions.reduce(0) { $0 + $1.durationSeconds } / focusSessions.count) / 60)
        let targetHitRate = focusSessions.isEmpty
            ? 0
            : Double(completedFocusSessions.count) / Double(focusSessions.count)

        let topXPSource = summary.breakdown.max(by: { $0.xp < $1.xp })?.displayName ?? "No XP source yet"
        let streakSafe = dailyXP > 0
        let remaining = max(0, GamificationTokens.dailyXPCap - dailyXP)

        let momentumMetrics = [
            InsightsMetricTile(
                id: "completed",
                title: "Completed",
                value: "\(summary.tasksCompleted)/\(max(scheduledCount, summary.tasksCompleted))",
                detail: "Scheduled for today",
                tone: summary.tasksCompleted > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "xp",
                title: "Daily XP",
                value: "\(dailyXP)",
                detail: remaining > 0 ? "\(remaining) XP to cap" : "Daily cap reached",
                tone: remaining > 0 ? .accent : .success
            ),
            InsightsMetricTile(
                id: "streak_safe",
                title: "Streak",
                value: streakSafe ? "Safe" : "At risk",
                detail: streakSafe ? "Momentum is already banked" : "One meaningful action protects the day",
                tone: streakSafe ? .success : .warning
            ),
            InsightsMetricTile(
                id: "top_source",
                title: "Top source",
                value: topXPSource,
                detail: "Largest XP driver today",
                tone: .accent
            )
        ]

        let paceMetrics = [
            InsightsMetricTile(
                id: "goal_progress",
                title: "Goal progress",
                value: "\(min(100, Int((Double(dailyXP) / Double(max(GamificationTokens.dailyXPCap, 1))) * 100)))%",
                detail: "Daily cap coverage",
                tone: dailyXP >= GamificationTokens.dailyXPCap ? .success : .accent
            ),
            InsightsMetricTile(
                id: "morning_evening",
                title: "Pace split",
                value: "\(morningCompletedCount)M / \(eveningCompletedCount)E",
                detail: "Morning vs evening clears",
                tone: .neutral
            ),
            InsightsMetricTile(
                id: "high_priority",
                title: "High priority",
                value: "\(completedHighPriorityCount)",
                detail: "High or max tasks cleared",
                tone: completedHighPriorityCount > 0 ? .success : .warning
            )
        ]

        let duePressureMetrics = [
            InsightsMetricTile(
                id: "due_today",
                title: "Due today",
                value: "\(dueTodayOpen.count)",
                detail: "Open tasks still on today’s board",
                tone: dueTodayOpen.isEmpty ? .success : .accent
            ),
            InsightsMetricTile(
                id: "overdue",
                title: "Overdue",
                value: "\(overdueOpen.count)",
                detail: staleOverdueCount > 0 ? "\(staleOverdueCount) stale for 14d+" : "Fresh overdue pressure",
                tone: overdueOpen.isEmpty ? .success : .warning
            ),
            InsightsMetricTile(
                id: "blocked",
                title: "Blocked",
                value: "\(blockedCount)",
                detail: "Tasks waiting on another dependency",
                tone: blockedCount == 0 ? .success : .warning
            ),
            InsightsMetricTile(
                id: "long_tasks",
                title: "Long tasks",
                value: "\(longTaskCount)",
                detail: "Over one hour on the pressure board",
                tone: longTaskCount == 0 ? .neutral : .warning
            )
        ]

        let focusMetrics = [
            InsightsMetricTile(
                id: "focus_minutes",
                title: "Focus minutes",
                value: "\(totalFocusMinutes)",
                detail: focusSessions.isEmpty ? "No sessions logged yet" : "Across \(focusSessions.count) sessions",
                tone: totalFocusMinutes > 0 ? .accent : .neutral
            ),
            InsightsMetricTile(
                id: "avg_session",
                title: "Avg session",
                value: "\(averageFocusMinutes)m",
                detail: "Average focus length",
                tone: averageFocusMinutes >= 25 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "hit_rate",
                title: "Target hit",
                value: "\(Int((targetHitRate * 100).rounded()))%",
                detail: "\(completedFocusSessions.count) sessions completed as planned",
                tone: targetHitRate >= 0.6 ? .success : .warning
            )
        ]

        let completionMixSections = [
            buildDistributionSection(
                id: "priority",
                title: "By priority",
                values: Dictionary(grouping: completedTodayTasks, by: \.priority).mapValues(\.count),
                orderedKeys: TaskPriority.uiOrder.reversed(),
                label: { $0.displayName },
                tone: { $0.isHighPriority ? .warning : .neutral },
                valueSuffix: "tasks"
            ),
            buildDistributionSection(
                id: "type",
                title: "By day part",
                values: Dictionary(grouping: completedTodayTasks, by: \.type).mapValues(\.count),
                orderedKeys: TaskType.allCases,
                label: { $0.displayName },
                tone: { $0 == .morning ? .accent : .neutral },
                valueSuffix: "tasks"
            ),
            buildDistributionSection(
                id: "energy",
                title: "By energy",
                values: Dictionary(grouping: completedTodayTasks, by: \.energy).mapValues(\.count),
                orderedKeys: TaskEnergy.allCases,
                label: { $0.displayName },
                tone: { $0 == .high ? .warning : .neutral },
                valueSuffix: "tasks"
            ),
            buildDistributionSection(
                id: "context",
                title: "By context",
                values: Dictionary(grouping: completedTodayTasks, by: \.context).mapValues(\.count),
                orderedKeys: TaskContext.allCases,
                label: { $0.displayName },
                tone: { $0 == .computer ? .accent : .neutral },
                valueSuffix: "tasks"
            )
        ].filter { !$0.items.isEmpty }

        let reflectionEarned = summary.breakdown.first(where: { $0.category == XPActionCategory.reflection.rawValue })?.xp ?? 0
        let decomposeEarned = summary.breakdown.first(where: { $0.category == XPActionCategory.decompose.rawValue })?.xp ?? 0
        let recoveryMetrics = [
            InsightsMetricTile(
                id: "recovered",
                title: "Recovery wins",
                value: "\(summary.recoveryCount)",
                detail: summary.recoveryCount > 0 ? "Overdue tasks pulled back into motion" : "No rescue actions yet",
                tone: summary.recoveryCount > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "decompose",
                title: "Decomposed",
                value: "\(decomposeEarned > 0 ? 1 : 0)",
                detail: decomposeEarned > 0 ? "+\(decomposeEarned) XP from breaking work down" : "Break a task down when it feels sticky",
                tone: decomposeEarned > 0 ? .accent : .neutral
            ),
            InsightsMetricTile(
                id: "reflection",
                title: "Reflection",
                value: reflectionEarned > 0 ? "Claimed" : "Open",
                detail: reflectionEarned > 0 ? "Reflection loop is closed for today" : "A one-minute reflection keeps the streak resilient",
                tone: reflectionEarned > 0 ? .success : .warning
            )
        ]

        let heroTitle: String
        if overdueOpen.count > 0 {
            heroTitle = "Pressure is visible. Keep the board small."
        } else if summary.tasksCompleted > 0 {
            heroTitle = "Today has traction."
        } else {
            heroTitle = "Build today’s momentum."
        }

        return InsightsTodayState(
            dailyXP: dailyXP,
            dailyCap: GamificationTokens.dailyXPCap,
            level: level,
            tasksCompletedToday: summary.tasksCompleted,
            totalTasksToday: max(scheduledCount, summary.tasksCompleted),
            xpBreakdown: summary.breakdown,
            recoveryXP: summary.recoveryXP,
            recoveryCount: summary.recoveryCount,
            heroTitle: heroTitle,
            heroSummary: todayHeroSummary(
                completed: summary.tasksCompleted,
                scheduled: max(scheduledCount, summary.tasksCompleted),
                dailyXP: dailyXP,
                dailyCap: GamificationTokens.dailyXPCap,
                duePressure: duePressureMetrics
            ),
            coachingPrompt: todayCoachingPrompt(
                dueTodayOpen: dueTodayOpen.count,
                overdueOpen: overdueOpen.count,
                blockedCount: blockedCount,
                focusMinutes: totalFocusMinutes
            ),
            momentumMetrics: momentumMetrics,
            paceMetrics: paceMetrics,
            duePressureMetrics: duePressureMetrics,
            focusMetrics: focusMetrics,
            completionMixSections: completionMixSections,
            recoveryMetrics: recoveryMetrics
        )
    }

    private static func buildWeekState(
        currentAggregates: [DailyXPAggregateDefinition],
        previousAggregates: [DailyXPAggregateDefinition],
        currentWeekEvents: [XPEventDefinition],
        previousWeekEvents: [XPEventDefinition],
        recentTasks: [TaskDefinition],
        dueWindowTasks: [TaskDefinition],
        projectScores: [UUID: Int],
        weekStart: Date,
        today: Date,
        calendar: Calendar
    ) -> InsightsWeekState {
        let formatter = makeDateFormatter(calendar: calendar)
        let aggregateByDate = Dictionary(uniqueKeysWithValues: currentAggregates.map { ($0.dateKey, $0) })
        let completionCountsByDate = completionCountsByDateKey(events: currentWeekEvents, calendar: calendar)
        var bars: [WeeklyBarData] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let dateKey = formatter.string(from: day)
            let xp = aggregateByDate[dateKey]?.totalXP ?? 0
            let completionCount = completionCountsByDate[dateKey, default: 0]
            let isToday = calendar.isDate(day, inSameDayAs: today)
            let isFuture = day > today
            bars.append(
                WeeklyBarData(
                    dateKey: dateKey,
                    dayIndex: dayOffset,
                    label: dayLetters[dayOffset],
                    xp: xp,
                    completionCount: completionCount,
                    intensity: 0,
                    isToday: isToday,
                    isFuture: isFuture
                )
            )
        }

        let currentWeekCompletedTasks = recentTasks.filter {
            guard $0.isComplete, let completedAt = $0.dateCompleted else { return false }
            return completedAt >= weekStart && completedAt < calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        }
        let previousWeekCompletedTasks = recentTasks.filter {
            guard $0.isComplete, let completedAt = $0.dateCompleted else { return false }
            let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            return completedAt >= previousWeekStart && completedAt < weekStart
        }

        let previousTotalXP = previousAggregates.reduce(0) { $0 + $1.totalXP }
        let previousCompletions = completionCountsByDateKey(events: previousWeekEvents, calendar: calendar)
            .values.reduce(0, +)
        let openCarryOverCount = dueWindowTasks.filter {
            guard !$0.isComplete, let dueDate = $0.dueDate else { return false }
            return dueDate < today
        }.count
        let staleCarryOverCount = dueWindowTasks.filter {
            guard !$0.isComplete, let dueDate = $0.dueDate else { return false }
            return (calendar.dateComponents([.day], from: calendar.startOfDay(for: dueDate), to: today).day ?? 0) >= staleDayThreshold
        }.count

        let projectNameByID = recentTasks.reduce(into: [UUID: String]()) { partialResult, task in
            guard partialResult[task.projectID] == nil, let projectName = task.projectName else { return }
            partialResult[task.projectID] = projectName
        }
        let projectCompletionCounts = Dictionary(grouping: currentWeekCompletedTasks, by: \.projectID).mapValues(\.count)
        let leaderboard = projectScores
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return projectNameByID[lhs.key, default: "Inbox"] < projectNameByID[rhs.key, default: "Inbox"]
                }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map { entry in
                InsightsLeaderboardRow(
                    id: entry.key.uuidString,
                    title: projectNameByID[entry.key, default: "Inbox"],
                    subtitle: "\(projectCompletionCounts[entry.key, default: 0]) completions this week",
                    value: "\(entry.value) XP",
                    detail: entry.value >= 30 ? "Strong contributor" : "Still building signal",
                    tone: entry.value >= 30 ? .accent : .neutral
                )
            }

        let priorityMix = buildDistributionItems(
            values: Dictionary(grouping: currentWeekCompletedTasks, by: \.priority).mapValues(\.count),
            orderedKeys: TaskPriority.uiOrder.reversed(),
            label: { $0.displayName },
            tone: { $0.isHighPriority ? .warning : .neutral },
            valueSuffix: "tasks"
        )
        let taskTypeMix = buildDistributionItems(
            values: Dictionary(grouping: currentWeekCompletedTasks, by: \.type).mapValues(\.count),
            orderedKeys: TaskType.allCases,
            label: { $0.displayName },
            tone: { $0 == .morning ? .accent : .neutral },
            valueSuffix: "tasks"
        )
        let highPriorityMixCount = currentWeekCompletedTasks.filter { $0.priority.isHighPriority }.count

        let currentWeekCompletions = currentWeekCompletedTasks.count
        let currentGoalHitDays = bars.filter { $0.xp >= GamificationTokens.dailyXPCap }.count
        let previousGoalHitDays = previousAggregates.filter { $0.totalXP >= GamificationTokens.dailyXPCap }.count
        let deltaSummary = weekDeltaSummary(
            currentXP: bars.reduce(0) { $0 + $1.xp },
            previousXP: previousTotalXP,
            currentCompletions: currentWeekCompletions,
            previousCompletions: previousCompletions,
            currentGoalHitDays: currentGoalHitDays,
            previousGoalHitDays: previousGoalHitDays
        )
        let patternSummary = weekPatternSummary(
            bars: bars,
            staleCarryOverCount: staleCarryOverCount,
            highPriorityMix: highPriorityMixCount
        )

        let summaryMetrics = [
            InsightsMetricTile(
                id: "goal_hits",
                title: "Goal-hit days",
                value: "\(currentGoalHitDays)/7",
                detail: previousGoalHitDays == currentGoalHitDays ? "Steady versus last week" : "\(signedDeltaLabel(currentGoalHitDays - previousGoalHitDays)) vs last week",
                tone: currentGoalHitDays >= previousGoalHitDays ? .success : .warning
            ),
            InsightsMetricTile(
                id: "avg_day",
                title: "Avg/day",
                value: "\(bars.filter { !$0.isFuture }.isEmpty ? 0 : bars.filter { !$0.isFuture }.reduce(0) { $0 + $1.xp } / bars.filter { !$0.isFuture }.count) XP",
                detail: "Across elapsed days this week",
                tone: .accent
            ),
            InsightsMetricTile(
                id: "best_day",
                title: "Best day",
                value: bestLabel(for: bars, calendar: calendar),
                detail: "Highest XP output day",
                tone: .success
            ),
            InsightsMetricTile(
                id: "carry_over",
                title: "Carry-over",
                value: "\(openCarryOverCount)",
                detail: staleCarryOverCount > 0 ? "\(staleCarryOverCount) stale overdue" : "No stale drag building",
                tone: openCarryOverCount == 0 ? .success : .warning
            )
        ]

        return recomputeWeekState(
            from: bars,
            previousTotalXP: previousTotalXP,
            projectLeaderboard: leaderboard,
            priorityMix: priorityMix,
            taskTypeMix: taskTypeMix,
            patternSummary: patternSummary,
            deltaSummary: deltaSummary,
            weeklySummaryMetrics: summaryMetrics
        )
    }

    private static func buildReminderResponseState(
        reminders: [ReminderDefinition],
        deliveriesByReminderID: [UUID: [ReminderDeliveryDefinition]]
    ) -> InsightsReminderResponseState {
        let deliveries = reminders.flatMap { deliveriesByReminderID[$0.id] ?? [] }
        guard !deliveries.isEmpty else {
            return InsightsReminderResponseState(
                headline: reminders.isEmpty
                    ? "Reminders are not producing response data yet."
                    : "Deliveries are scheduled, but no responses have landed yet.",
                detail: reminders.isEmpty
                    ? "Once reminders are scheduled and acted on, this card will show acknowledgement and snooze behavior."
                    : "Response quality uses current delivery status, acknowledgements, and snoozes."
            )
        }

        let normalizedStates = deliveries.map { delivery -> String in
            let normalizedStatus = delivery.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if delivery.ackAt != nil || normalizedStatus == "acked" || normalizedStatus == "acknowledged" {
                return "acked"
            }
            if delivery.snoozedUntil != nil || normalizedStatus == "snoozed" {
                return "snoozed"
            }
            return "pending"
        }

        let acked = normalizedStates.filter { $0 == "acked" }.count
        let snoozed = normalizedStates.filter { $0 == "snoozed" }.count
        let pending = normalizedStates.filter { $0 == "pending" }.count
        let responseRate = deliveries.isEmpty ? 0 : Double(acked + snoozed) / Double(deliveries.count)
        let statusItems = [
            InsightsDistributionItem(
                id: "acked",
                label: "Acknowledged",
                value: acked,
                valueText: "\(acked)",
                share: deliveries.isEmpty ? 0 : Double(acked) / Double(deliveries.count),
                tone: .success
            ),
            InsightsDistributionItem(
                id: "snoozed",
                label: "Snoozed",
                value: snoozed,
                valueText: "\(snoozed)",
                share: deliveries.isEmpty ? 0 : Double(snoozed) / Double(deliveries.count),
                tone: .warning
            ),
            InsightsDistributionItem(
                id: "pending",
                label: "Pending",
                value: pending,
                valueText: "\(pending)",
                share: deliveries.isEmpty ? 0 : Double(pending) / Double(deliveries.count),
                tone: .neutral
            )
        ]

        let headline: String
        if responseRate >= 0.75 {
            headline = "Reminder response is strong."
        } else if responseRate >= 0.45 {
            headline = "Reminder response is usable, but can tighten."
        } else {
            headline = "Reminder response is weak."
        }

        return InsightsReminderResponseState(
            totalDeliveries: deliveries.count,
            acknowledgedDeliveries: acked,
            snoozedDeliveries: snoozed,
            pendingDeliveries: pending,
            responseRate: responseRate,
            statusItems: statusItems,
            headline: headline,
            detail: "\(Int((responseRate * 100).rounded()))% of tracked deliveries were acknowledged or snoozed."
        )
    }

    private static func buildStreakMetrics(
        profile: GamificationSnapshot,
        reminderResponse: InsightsReminderResponseState
    ) -> [InsightsMetricTile] {
        [
            InsightsMetricTile(
                id: "current_streak",
                title: "Current streak",
                value: "\(profile.currentStreak)d",
                detail: profile.currentStreak > 0 ? "The chain is alive" : "Ready for a fresh restart",
                tone: profile.currentStreak > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "best_streak",
                title: "Best streak",
                value: "\(max(profile.bestStreak, profile.bestReturnStreak))d",
                detail: "Best sustained stretch so far",
                tone: .accent
            ),
            InsightsMetricTile(
                id: "return_streak",
                title: "Return streak",
                value: "\(profile.returnStreak)d",
                detail: "Recovery after missing days",
                tone: profile.returnStreak > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "reminder_support",
                title: "Reminder support",
                value: "\(Int((reminderResponse.responseRate * 100).rounded()))%",
                detail: "How often reminders earn a response",
                tone: reminderResponse.responseRate >= 0.5 ? .success : .warning
            )
        ]
    }

    private static func buildAchievementVelocityMetrics(unlocks: [AchievementUnlockDefinition]) -> [InsightsMetricTile] {
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let lastMonth = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let unlockedLastWeek = unlocks.filter { $0.unlockedAt >= lastWeek }.count
        let unlockedLastMonth = unlocks.filter { $0.unlockedAt >= lastMonth }.count

        return [
            InsightsMetricTile(
                id: "achievement_total",
                title: "Unlocked",
                value: "\(unlocks.count)",
                detail: "Lifetime achievements",
                tone: unlocks.isEmpty ? .neutral : .accent
            ),
            InsightsMetricTile(
                id: "achievement_week",
                title: "Last 7 days",
                value: "\(unlockedLastWeek)",
                detail: "Recent unlock velocity",
                tone: unlockedLastWeek > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "achievement_month",
                title: "Last 30 days",
                value: "\(unlockedLastMonth)",
                detail: "Longer-term unlock pace",
                tone: unlockedLastMonth > 0 ? .accent : .neutral
            )
        ]
    }

    private static func buildFocusHealthMetrics(sessions: [FocusSessionDefinition]) -> [InsightsMetricTile] {
        let sessionCount = sessions.count
        let completedCount = sessions.filter(\.wasCompleted).count
        let totalMinutes = sessions.reduce(0) { $0 + max(0, $1.durationSeconds / 60) }
        let averageMinutes = sessionCount == 0 ? 0 : totalMinutes / sessionCount
        let completionRate = sessionCount == 0 ? 0 : Double(completedCount) / Double(sessionCount)

        return [
            InsightsMetricTile(
                id: "focus_sessions",
                title: "Sessions",
                value: "\(sessionCount)",
                detail: "Last 28 days",
                tone: sessionCount > 0 ? .accent : .neutral
            ),
            InsightsMetricTile(
                id: "focus_complete_rate",
                title: "Completion",
                value: "\(Int((completionRate * 100).rounded()))%",
                detail: "\(completedCount) finished as planned",
                tone: completionRate >= 0.6 ? .success : .warning
            ),
            InsightsMetricTile(
                id: "focus_minutes",
                title: "Total minutes",
                value: "\(totalMinutes)",
                detail: "Focused time in the last month",
                tone: totalMinutes >= 300 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "focus_average",
                title: "Avg length",
                value: "\(averageMinutes)m",
                detail: "Typical focus session",
                tone: averageMinutes >= 25 ? .success : .neutral
            )
        ]
    }

    private static func buildRecoveryHealthMetrics(events: [XPEventDefinition], now: Date) -> [InsightsMetricTile] {
        let lookback = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let recentEvents = events.filter { $0.createdAt >= lookback }
        let recoveryCount = recentEvents.filter { $0.category == .recoverReschedule }.count
        let decomposeCount = recentEvents.filter { $0.category == .decompose }.count
        let reflectionCount = recentEvents.filter { $0.category == .reflection }.count
        let completionCount = recentEvents.filter {
            $0.category == .complete || completionReasons.contains($0.reason) || $0.reason.contains("on_time")
        }.count

        return [
            InsightsMetricTile(
                id: "recovery_reschedules",
                title: "Recovery",
                value: "\(recoveryCount)",
                detail: "Rescued tasks in the last 14 days",
                tone: recoveryCount > 0 ? .success : .neutral
            ),
            InsightsMetricTile(
                id: "decompose_actions",
                title: "Break-downs",
                value: "\(decomposeCount)",
                detail: "Times work was made smaller",
                tone: decomposeCount > 0 ? .accent : .neutral
            ),
            InsightsMetricTile(
                id: "reflections",
                title: "Reflections",
                value: "\(reflectionCount)",
                detail: "Closed-loop reflection check-ins",
                tone: reflectionCount > 0 ? .success : .warning
            ),
            InsightsMetricTile(
                id: "recovery_ratio",
                title: "Recovery ratio",
                value: completionCount == 0 ? "0%" : "\(Int((Double(recoveryCount + decomposeCount + reflectionCount) / Double(completionCount) * 100).rounded()))%",
                detail: "Support actions relative to completions",
                tone: (recoveryCount + decomposeCount + reflectionCount) > 0 ? .accent : .neutral
            )
        ]
    }

    private static func buildSystemsHeroSummary(
        profile: GamificationSnapshot,
        reminderResponse: InsightsReminderResponseState,
        focusSessions: [FocusSessionDefinition]
    ) -> String {
        if profile.currentStreak > 0 && reminderResponse.responseRate >= 0.5 {
            return "Your long-term systems are supporting follow-through instead of just tracking it."
        }
        if focusSessions.isEmpty {
            return "Progression is active, but focus rituals are still light."
        }
        return "The system is running, but the weak link is still visible in response or recovery."
    }

    private static func summarize(events: [XPEventDefinition]) -> (
        tasksCompleted: Int,
        breakdown: [XPBreakdownItem],
        recoveryXP: Int,
        recoveryCount: Int
    ) {
        var byCategory: [String: Int] = [:]
        var recoveryXP = 0
        var recoveryCount = 0
        var tasksCompleted = 0

        for event in events {
            let categoryKey = event.category?.rawValue ?? event.reason
            byCategory[categoryKey, default: 0] += event.delta

            if event.category == .recoverReschedule {
                recoveryXP += event.delta
                recoveryCount += 1
            }

            if event.category == .complete
                || completionReasons.contains(event.reason)
                || event.reason.contains("on_time") {
                tasksCompleted += 1
            }
        }

        var items: [XPBreakdownItem] = []
        for category in orderedBreakdownCategories {
            if let xp = byCategory[category], xp > 0 {
                items.append(XPBreakdownItem(category: category, xp: xp))
            }
        }
        for (category, xp) in byCategory where !orderedBreakdownCategories.contains(category) && xp > 0 {
            items.append(XPBreakdownItem(category: category, xp: xp))
        }

        return (
            tasksCompleted: tasksCompleted,
            breakdown: items,
            recoveryXP: recoveryXP,
            recoveryCount: recoveryCount
        )
    }

    private static func buildAchievementProgress(
        profile: GamificationSnapshot?,
        unlocks: [AchievementUnlockDefinition],
        events: [XPEventDefinition]
    ) -> [AchievementProgressState] {
        let profile = profile ?? GamificationSnapshot()
        let unlockByKey = Dictionary(
            grouping: unlocks,
            by: \.achievementKey
        ).compactMapValues { entries in
            entries.map(\.unlockedAt).max()
        }

        let completionEvents = events.filter {
            $0.category == .complete
                || completionReasons.contains($0.reason)
                || $0.reason.contains("on_time")
        }
        let reflectionEvents = events.filter {
            $0.category == .reflection || $0.reason == "reflection"
        }
        let decomposeEvents = events.filter {
            $0.category == .decompose || $0.reason == "decompose"
        }

        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let onTimeWeekCount = completionEvents.filter {
            $0.createdAt >= oneWeekAgo
                && ($0.reason.contains("on_time") || $0.reason.contains("onTime"))
        }.count

        return AchievementCatalog.all.map { definition in
            let unlockDate = unlockByKey[definition.key]
            let isUnlocked = unlockDate != nil

            let current: Int
            let target: Int
            switch definition.key {
            case "first_step":
                current = completionEvents.count
                target = 1
            case "xp_100":
                current = Int(profile.xpTotal)
                target = 100
            case "week_warrior":
                current = max(profile.currentStreak, profile.bestStreak)
                target = 7
            case "seven_day_return":
                current = max(profile.returnStreak, profile.bestReturnStreak)
                target = 7
            case "on_time_10_week":
                current = onTimeWeekCount
                target = 10
            case "decomposer_20":
                current = decomposeEvents.count
                target = 20
            case "reflection_7":
                current = reflectionEvents.count
                target = 7
            case "comeback_after_7_idle":
                current = isUnlocked ? 1 : 0
                target = 1
            default:
                current = isUnlocked ? 1 : 0
                target = 1
            }

            return AchievementProgressState(
                key: definition.key,
                name: definition.name,
                description: definition.description,
                unlocked: isUnlocked,
                progressCurrent: isUnlocked ? max(current, target) : current,
                progressTarget: target,
                unlockDate: unlockDate
            )
        }
    }

    private static func makeDateFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let formatter = makeDateFormatter(calendar: calendar)
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private static func dateFromKey(_ dateKey: String, calendar: Calendar) -> Date? {
        let formatter = makeDateFormatter(calendar: calendar)
        return formatter.date(from: dateKey)
    }

    private static func completionCountsByDateKey(
        events: [XPEventDefinition],
        calendar: Calendar
    ) -> [String: Int] {
        let formatter = makeDateFormatter(calendar: calendar)
        var counts: [String: Int] = [:]
        for event in events where event.category == .complete || completionReasons.contains(event.reason) || event.reason.contains("on_time") {
            let key = formatter.string(from: calendar.startOfDay(for: event.createdAt))
            counts[key, default: 0] += 1
        }
        return counts
    }

    private static func applyingBreakdownDelta(
        existing: [XPBreakdownItem],
        category: String,
        xpDelta: Int
    ) -> [XPBreakdownItem] {
        guard xpDelta != 0 else { return existing }
        var byCategory = Dictionary(uniqueKeysWithValues: existing.map { ($0.category, $0.xp) })
        byCategory[category, default: 0] += xpDelta
        if byCategory[category, default: 0] <= 0 {
            byCategory.removeValue(forKey: category)
        }

        var items: [XPBreakdownItem] = []
        for key in orderedBreakdownCategories {
            if let xp = byCategory[key], xp > 0 {
                items.append(XPBreakdownItem(category: key, xp: xp))
            }
        }
        for (key, xp) in byCategory where !orderedBreakdownCategories.contains(key) && xp > 0 {
            items.append(XPBreakdownItem(category: key, xp: xp))
        }
        return items
    }

    private static func buildDistributionSection<T: Hashable>(
        id: String,
        title: String,
        values: [T: Int],
        orderedKeys: [T],
        label: (T) -> String,
        tone: (T) -> InsightsMetricTone,
        valueSuffix: String
    ) -> InsightsDistributionSection {
        InsightsDistributionSection(
            id: id,
            title: title,
            items: buildDistributionItems(
                values: values,
                orderedKeys: orderedKeys,
                label: label,
                tone: tone,
                valueSuffix: valueSuffix
            )
        )
    }

    private static func buildDistributionItems<T: Hashable>(
        values: [T: Int],
        orderedKeys: [T],
        label: (T) -> String,
        tone: (T) -> InsightsMetricTone,
        valueSuffix: String
    ) -> [InsightsDistributionItem] {
        let total = max(1, values.values.reduce(0, +))
        return orderedKeys.compactMap { key in
            let count = values[key, default: 0]
            guard count > 0 else { return nil }
            return InsightsDistributionItem(
                id: "\(key)",
                label: label(key),
                value: count,
                valueText: "\(count) \(valueSuffix)",
                share: Double(count) / Double(total),
                tone: tone(key)
            )
        }
    }

    private static func todayHeroSummary(
        completed: Int,
        scheduled: Int,
        dailyXP: Int,
        dailyCap: Int,
        duePressure: [InsightsMetricTile]
    ) -> String {
        let overdueCount = Int(duePressure.first(where: { $0.id == "overdue" })?.value ?? "0") ?? 0
        if completed == 0 {
            return overdueCount > 0
                ? "There’s pressure on the board. Clear one overdue task to calm the day."
                : "No completions yet. One solid task is enough to change the day’s shape."
        }
        if dailyXP >= dailyCap {
            return "You’ve already banked the daily cap. Use the rest of the day to reduce pressure, not chase points."
        }
        return "Completed \(completed) of \(max(scheduled, completed)) planned tasks. The board is moving in the right direction."
    }

    private static func todayCoachingPrompt(
        dueTodayOpen: Int,
        overdueOpen: Int,
        blockedCount: Int,
        focusMinutes: Int
    ) -> String {
        if overdueOpen > 0 {
            return "Next move: rescue the oldest overdue task or explicitly reschedule it."
        }
        if blockedCount > 0 {
            return "Next move: unblock one waiting task so tomorrow’s board is lighter."
        }
        if dueTodayOpen > 0 {
            return "Next move: close one remaining due-today task before switching context."
        }
        if focusMinutes == 0 {
            return "Next move: run one focused session to turn clean momentum into depth."
        }
        return "Next move: use the remaining space for a high-value task, not more backlog shuffling."
    }

    private static func weekDeltaSummary(
        currentXP: Int,
        previousXP: Int,
        currentCompletions: Int,
        previousCompletions: Int,
        currentGoalHitDays: Int,
        previousGoalHitDays: Int
    ) -> String {
        let xpDelta = currentXP - previousXP
        let completionDelta = currentCompletions - previousCompletions
        let goalHitDelta = currentGoalHitDays - previousGoalHitDays

        if xpDelta == 0 && completionDelta == 0 && goalHitDelta == 0 {
            return "The shape of the week is steady versus last week."
        }

        return "\(signedDeltaLabel(xpDelta)) XP, \(signedDeltaLabel(completionDelta)) completions, \(signedDeltaLabel(goalHitDelta)) goal-hit days versus last week."
    }

    private static func weekPatternSummary(
        bars: [WeeklyBarData],
        staleCarryOverCount: Int,
        highPriorityMix: Int
    ) -> String {
        if staleCarryOverCount > 0 {
            return "Backlog drag is still visible. Reflection is strongest when it turns into a smaller pressure board."
        }
        if let strongest = bars.max(by: { $0.xp < $1.xp }), strongest.xp > 0 {
            return "The week peaks on \(strongest.label). \(highPriorityMix > 0 ? "High-priority work is showing up in the mix." : "Priority mix is still skewing light.")"
        }
        return "The week is quiet so far. One strong day can still reset the pattern."
    }

    private static func signedDeltaLabel(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private static func bestLabel(for bars: [WeeklyBarData], calendar: Calendar) -> String {
        guard let best = bars.max(by: { $0.xp < $1.xp }), best.xp > 0 else {
            return "No standout yet"
        }
        if let date = dateFromKey(best.dateKey, calendar: calendar) {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
            weekdayFormatter.timeZone = calendar.timeZone
            return "\(weekdayFormatter.string(from: date))"
        }
        return best.label
    }

    private static func recomputeWeekState(
        from bars: [WeeklyBarData],
        previousTotalXP: Int,
        projectLeaderboard: [InsightsLeaderboardRow],
        priorityMix: [InsightsDistributionItem],
        taskTypeMix: [InsightsDistributionItem],
        patternSummary: String,
        deltaSummary: String,
        weeklySummaryMetrics: [InsightsMetricTile] = []
    ) -> InsightsWeekState {
        let total = bars.reduce(0) { $0 + $1.xp }
        let goalHit = bars.filter { $0.xp >= GamificationTokens.dailyXPCap }.count
        let activeDays = max(1, bars.filter { !$0.isFuture }.count)
        let maxXP = max(bars.map(\.xp).max() ?? 0, GamificationTokens.dailyXPCap)
        let normalizedBars = bars.map { bar in
            WeeklyBarData(
                dateKey: bar.dateKey,
                dayIndex: bar.dayIndex,
                label: bar.label,
                xp: bar.xp,
                completionCount: bar.completionCount,
                intensity: maxXP > 0 ? Double(bar.xp) / Double(maxXP) : 0,
                isToday: bar.isToday,
                isFuture: bar.isFuture
            )
        }

        let calendar = XPCalculationEngine.mondayCalendar()
        let bestDay = bestLabel(for: normalizedBars, calendar: calendar)
        let heroTitle = total >= previousTotalXP ? "Your weekly rhythm is building." : "Your weekly rhythm is softer than last week."
        let heroSummary = total == 0
            ? "No weekly XP signal yet. The first decisive day will set the pattern."
            : "\(signedDeltaLabel(total - previousTotalXP)) XP versus last week with \(goalHit) goal-hit days."

        return InsightsWeekState(
            weeklyBars: normalizedBars,
            weeklyTotalXP: total,
            previousWeekTotalXP: previousTotalXP,
            goalHitDays: goalHit,
            bestDayLabel: bestDay.isEmpty ? "" : "\(bestDay) (\(normalizedBars.max(by: { $0.xp < $1.xp })?.xp ?? 0) XP)",
            averageDailyXP: total / activeDays,
            heroTitle: heroTitle,
            heroSummary: heroSummary,
            weeklySummaryMetrics: weeklySummaryMetrics,
            projectLeaderboard: projectLeaderboard,
            priorityMix: priorityMix,
            taskTypeMix: taskTypeMix,
            patternSummary: patternSummary,
            deltaSummary: deltaSummary
        )
    }

    private static func rebuiltWeeklySummaryMetrics(
        existing: [InsightsMetricTile],
        bars: [WeeklyBarData]
    ) -> [InsightsMetricTile] {
        guard !existing.isEmpty else { return existing }

        let goalHitCount = bars.filter { $0.xp >= GamificationTokens.dailyXPCap }.count
        let activeDays = max(1, bars.filter { !$0.isFuture }.count)
        let averageXP = bars.filter { !$0.isFuture }.reduce(0) { $0 + $1.xp } / activeDays
        let bestDay = bestLabel(for: bars, calendar: XPCalculationEngine.mondayCalendar())

        return existing.map { metric in
            switch metric.id {
            case "goal_hits":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(goalHitCount)/7",
                    detail: metric.detail,
                    tone: metric.tone
                )
            case "avg_day":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(averageXP) XP",
                    detail: metric.detail,
                    tone: metric.tone
                )
            case "best_day":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: bestDay,
                    detail: metric.detail,
                    tone: metric.tone
                )
            default:
                return metric
            }
        }
    }

    private static func rebuiltTodayMomentumMetrics(from state: InsightsTodayState) -> [InsightsMetricTile] {
        let topSource = state.xpBreakdown.max(by: { $0.xp < $1.xp })?.displayName ?? "No XP source yet"
        let remaining = max(0, state.dailyCap - state.dailyXP)

        return state.momentumMetrics.map { metric in
            switch metric.id {
            case "completed":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(state.tasksCompletedToday)/\(max(state.totalTasksToday, state.tasksCompletedToday))",
                    detail: metric.detail,
                    tone: state.tasksCompletedToday > 0 ? .success : .neutral
                )
            case "xp":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(state.dailyXP)",
                    detail: remaining > 0 ? "\(remaining) XP to cap" : "Daily cap reached",
                    tone: remaining > 0 ? .accent : .success
                )
            case "streak_safe":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: state.dailyXP > 0 ? "Safe" : "At risk",
                    detail: state.dailyXP > 0 ? "Momentum is already banked" : "One meaningful action protects the day",
                    tone: state.dailyXP > 0 ? .success : .warning
                )
            case "top_source":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: topSource,
                    detail: metric.detail,
                    tone: .accent
                )
            default:
                return metric
            }
        }
    }

    private static func rebuiltTodayPaceMetrics(from state: InsightsTodayState) -> [InsightsMetricTile] {
        let progressPercent = min(100, Int((Double(state.dailyXP) / Double(max(state.dailyCap, 1))) * 100))

        return state.paceMetrics.map { metric in
            switch metric.id {
            case "goal_progress":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(progressPercent)%",
                    detail: metric.detail,
                    tone: state.dailyXP >= state.dailyCap ? .success : .accent
                )
            default:
                return metric
            }
        }
    }

    private static func rebuiltTodayRecoveryMetrics(
        from state: InsightsTodayState,
        mutation: GamificationLedgerMutation
    ) -> [InsightsMetricTile] {
        state.recoveryMetrics.map { metric in
            switch metric.id {
            case "recovered":
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(state.recoveryCount)",
                    detail: state.recoveryCount > 0 ? "Overdue tasks pulled back into motion" : "No rescue actions yet",
                    tone: state.recoveryCount > 0 ? .success : .neutral
                )
            case "decompose" where mutation.category == .decompose:
                let totalDecomposeXP = state.xpBreakdown.first(where: { $0.category == XPActionCategory.decompose.rawValue })?.xp ?? 0
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: "\(totalDecomposeXP > 0 ? 1 : 0)",
                    detail: totalDecomposeXP > 0 ? "+\(totalDecomposeXP) XP from breaking work down" : "Break a task down when it feels sticky",
                    tone: totalDecomposeXP > 0 ? .accent : .neutral
                )
            case "reflection" where mutation.category == .reflection:
                let reflectionXP = state.xpBreakdown.first(where: { $0.category == XPActionCategory.reflection.rawValue })?.xp ?? 0
                return InsightsMetricTile(
                    id: metric.id,
                    title: metric.title,
                    value: reflectionXP > 0 ? "Claimed" : "Open",
                    detail: reflectionXP > 0 ? "Reflection loop is closed for today" : "A one-minute reflection keeps the streak resilient",
                    tone: reflectionXP > 0 ? .success : .warning
                )
            default:
                return metric
            }
        }
    }
}

private extension InsightsMutation {
    var shouldDebounce: Bool {
        switch self {
        case .taskCompleted, .taskReopened, .focusSessionEnded, .reflectionCompleted, .xpRecorded:
            return true
        case .cloudReconciled, .dayBoundaryChanged:
            return false
        }
    }
}

public struct XPBreakdownItem: Identifiable, Equatable {
    public var id: String { category }
    public let category: String
    public let xp: Int

    public var displayName: String {
        switch category {
        case "complete": return "Completions"
        case "start": return "Start tasks"
        case "focus": return "Focus sessions"
        case "reflection": return "Reflection"
        case "recoverReschedule": return "Recovery"
        case "decompose": return "Decompose"
        default: return category.capitalized
        }
    }
}

public struct WeeklyBarData: Identifiable, Equatable {
    public var id: String { dateKey }
    public let dateKey: String
    public let dayIndex: Int
    public let label: String
    public let xp: Int
    public let completionCount: Int
    public let intensity: Double
    public let isToday: Bool
    public let isFuture: Bool

    public init(
        dateKey: String,
        dayIndex: Int,
        label: String,
        xp: Int,
        completionCount: Int = 0,
        intensity: Double = 0,
        isToday: Bool,
        isFuture: Bool
    ) {
        self.dateKey = dateKey
        self.dayIndex = dayIndex
        self.label = label
        self.xp = xp
        self.completionCount = completionCount
        self.intensity = intensity
        self.isToday = isToday
        self.isFuture = isFuture
    }
}
