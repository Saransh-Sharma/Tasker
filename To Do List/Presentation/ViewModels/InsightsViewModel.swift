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

public struct InsightsTodayState: Equatable {
    public var dailyXP: Int
    public var dailyCap: Int
    public var level: Int
    public var tasksCompletedToday: Int
    public var totalTasksToday: Int
    public var xpBreakdown: [XPBreakdownItem]
    public var recoveryXP: Int
    public var recoveryCount: Int

    public init(
        dailyXP: Int = 0,
        dailyCap: Int = GamificationTokens.dailyXPCap,
        level: Int = 1,
        tasksCompletedToday: Int = 0,
        totalTasksToday: Int = 0,
        xpBreakdown: [XPBreakdownItem] = [],
        recoveryXP: Int = 0,
        recoveryCount: Int = 0
    ) {
        self.dailyXP = dailyXP
        self.dailyCap = dailyCap
        self.level = level
        self.tasksCompletedToday = tasksCompletedToday
        self.totalTasksToday = totalTasksToday
        self.xpBreakdown = xpBreakdown
        self.recoveryXP = recoveryXP
        self.recoveryCount = recoveryCount
    }
}

public struct InsightsWeekState: Equatable {
    public var weeklyBars: [WeeklyBarData]
    public var weeklyTotalXP: Int
    public var goalHitDays: Int
    public var bestDayLabel: String
    public var averageDailyXP: Int

    public init(
        weeklyBars: [WeeklyBarData] = [],
        weeklyTotalXP: Int = 0,
        goalHitDays: Int = 0,
        bestDayLabel: String = "",
        averageDailyXP: Int = 0
    ) {
        self.weeklyBars = weeklyBars
        self.weeklyTotalXP = weeklyTotalXP
        self.goalHitDays = goalHitDays
        self.bestDayLabel = bestDayLabel
        self.averageDailyXP = averageDailyXP
    }
}

public struct InsightsSystemsState: Equatable {
    public var level: Int
    public var totalXP: Int64
    public var nextLevelXP: Int64
    public var currentLevelThreshold: Int64
    public var streakDays: Int
    public var bestStreak: Int
    public var unlockedAchievements: Set<String>
    public var nextMilestone: XPCalculationEngine.Milestone?
    public var milestoneProgress: CGFloat

    public init(
        level: Int = 1,
        totalXP: Int64 = 0,
        nextLevelXP: Int64 = 0,
        currentLevelThreshold: Int64 = 0,
        streakDays: Int = 0,
        bestStreak: Int = 0,
        unlockedAchievements: Set<String> = [],
        nextMilestone: XPCalculationEngine.Milestone? = nil,
        milestoneProgress: CGFloat = 0
    ) {
        self.level = level
        self.totalXP = totalXP
        self.nextLevelXP = nextLevelXP
        self.currentLevelThreshold = currentLevelThreshold
        self.streakDays = streakDays
        self.bestStreak = bestStreak
        self.unlockedAchievements = unlockedAchievements
        self.nextMilestone = nextMilestone
        self.milestoneProgress = milestoneProgress
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

    // MARK: - Published State

    @Published public private(set) var selectedTab: InsightsTab = .today
    @Published public private(set) var todayState: InsightsTodayState = InsightsTodayState()
    @Published public private(set) var weekState: InsightsWeekState = InsightsWeekState()
    @Published public private(set) var systemsState: InsightsSystemsState = InsightsSystemsState()

    // MARK: - Legacy Compatibility Accessors

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
    public var nextMilestone: XPCalculationEngine.Milestone? { systemsState.nextMilestone }
    public var milestoneProgress: CGFloat { systemsState.milestoneProgress }

    // MARK: - Dependencies

    private let engine: GamificationEngine
    private let repository: GamificationRepositoryProtocol
    private let notificationCenter: NotificationCenter

    // MARK: - Session Projection State

    private var tabRefreshState: [InsightsTab: InsightsTabRefreshState] = [:]
    private var versionCounter: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()
    private var pendingMutationWorkItem: DispatchWorkItem?
    private var sessionDayKey: String

    private static let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private static let orderedBreakdownCategories = ["complete", "start", "focus", "reflection", "recoverReschedule", "decompose"]
    private static let completionReasons = Set(["task_completion", "complete", "complete_on_time"])
    private static let mutationDebounceInterval: TimeInterval = 0.22
    private static let cloudSyncNotification = Notification.Name("DataDidChangeFromCloudSync")

    // MARK: - Init

    public init(
        engine: GamificationEngine,
        repository: GamificationRepositoryProtocol,
        notificationCenter: NotificationCenter = .default
    ) {
        self.engine = engine
        self.repository = repository
        self.notificationCenter = notificationCenter
        self.sessionDayKey = Self.dateKey(for: Date(), calendar: XPCalculationEngine.mondayCalendar())

        for tab in InsightsTab.allCases {
            tabRefreshState[tab] = InsightsTabRefreshState()
        }

        bindMutations()
    }

    deinit {
        pendingMutationWorkItem?.cancel()
    }

    // MARK: - Public API

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

    public func noteXPMutation() {
        noteMutation(.xpRecorded)
    }

    public func noteMutation(_ mutation: InsightsMutation) {
        let affectedTabs = tabsAffected(by: mutation)
        guard affectedTabs.isEmpty == false else { return }

        markDirty(tabs: affectedTabs, reason: reasonLabel(for: mutation))
        if mutation.shouldDebounce {
            scheduleDebouncedSelectedTabRefresh()
        } else if affectedTabs.contains(selectedTab) {
            refreshSelectedTabIfNeeded(force: false)
        }
    }

    /// Compatibility API retained for existing call sites.
    /// Marks all tabs dirty and refreshes selected tab only.
    public func refresh() {
        markDirty(tabs: Set(InsightsTab.allCases), reason: "manual_refresh")
        refreshSelectedTabIfNeeded(force: true)
    }

    public func refreshState(for tab: InsightsTab) -> InsightsTabRefreshState {
        tabRefreshState[tab] ?? InsightsTabRefreshState()
    }

    // MARK: - Refresh Lifecycle

    private func refresh(tab: InsightsTab, force: Bool) {
        guard var tabState = tabRefreshState[tab] else { return }

        let shouldRefresh = force
            || tabState.isLoaded == false
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

    // MARK: - Mutation Binding

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
        case .taskCompleted, .taskReopened, .focusSessionEnded, .reflectionCompleted, .xpRecorded:
            return Set(InsightsTab.allCases)
        case .cloudReconciled:
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

        // Achievement unlocks remain repository-authoritative; refresh systems lazily.
        markDirty(tabs: [.systems], reason: "ledger_mutation_systems")
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

        if todayState != next {
            todayState = next
        }
    }

    private func applyWeekProjectionDelta(_ mutation: GamificationLedgerMutation) {
        guard tabRefreshState[.week]?.isLoaded == true else { return }
        guard weekState.weeklyBars.isEmpty == false else { return }

        var bars = weekState.weeklyBars
        guard let index = bars.firstIndex(where: { $0.dateKey == mutation.dateKey }) else { return }

        let existing = bars[index]
        let nextXP = max(0, mutation.dailyXPSoFar)
        guard existing.xp != nextXP else { return }

        bars[index] = WeeklyBarData(
            dateKey: existing.dateKey,
            dayIndex: existing.dayIndex,
            label: existing.label,
            xp: nextXP,
            isToday: existing.isToday,
            isFuture: existing.isFuture
        )

        let next = Self.recomputeWeekState(from: bars)
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

    // MARK: - Targeted Recomputation

    private func refreshToday(version: UInt64) {
        let calendar = XPCalculationEngine.mondayCalendar()
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let lock = NSLock()
        let group = DispatchGroup()

        var dailyXP = todayState.dailyXP
        var level = todayState.level
        var tasksCompletedToday = todayState.tasksCompletedToday
        var totalTasksToday = todayState.totalTasksToday
        var xpBreakdown = todayState.xpBreakdown
        var recoveryXP = todayState.recoveryXP
        var recoveryCount = todayState.recoveryCount

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
        repository.fetchXPEvents(from: today, to: tomorrow) { result in
            lock.lock()
            if case .success(let events) = result {
                let summary = Self.summarize(events: events)
                tasksCompletedToday = summary.tasksCompleted
                totalTasksToday = max(totalTasksToday, summary.tasksCompleted)
                xpBreakdown = summary.breakdown
                recoveryXP = summary.recoveryXP
                recoveryCount = summary.recoveryCount
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

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let nextState = InsightsTodayState(
                dailyXP: dailyXP,
                dailyCap: GamificationTokens.dailyXPCap,
                level: level,
                tasksCompletedToday: tasksCompletedToday,
                totalTasksToday: totalTasksToday,
                xpBreakdown: xpBreakdown,
                recoveryXP: recoveryXP,
                recoveryCount: recoveryCount
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

        let dateFormatter = Self.makeDateFormatter(calendar: calendar)
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.timeZone = calendar.timeZone

        let weekStartKey = dateFormatter.string(from: weekStart)
        let weekEndKey = dateFormatter.string(from: weekEndDate)

        repository.fetchDailyAggregates(from: weekStartKey, to: weekEndKey) { [weak self] result in
            guard let self else { return }
            if case .success(let aggregates) = result {
                let aggregateByDate = Dictionary(uniqueKeysWithValues: aggregates.map { ($0.dateKey, $0) })
                var bars: [WeeklyBarData] = []
                var total = 0
                var goalHit = 0
                var bestXP = 0
                var bestLabel = ""

                for dayOffset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                    let dateKey = dateFormatter.string(from: day)
                    let xp = aggregateByDate[dateKey]?.totalXP ?? 0
                    let isToday = calendar.isDate(day, inSameDayAs: today)
                    let isFuture = day > today

                    bars.append(WeeklyBarData(
                        dateKey: dateKey,
                        dayIndex: dayOffset,
                        label: Self.dayLetters[dayOffset],
                        xp: xp,
                        isToday: isToday,
                        isFuture: isFuture
                    ))

                    total += xp
                    if xp >= GamificationTokens.dailyXPCap {
                        goalHit += 1
                    }
                    if xp > bestXP {
                        bestXP = xp
                        bestLabel = "\(weekdayFormatter.string(from: day)) (\(xp) XP)"
                    }
                }

                let activeDays = bars.filter { !$0.isFuture }.count
                let nextState = InsightsWeekState(
                    weeklyBars: bars,
                    weeklyTotalXP: total,
                    goalHitDays: goalHit,
                    bestDayLabel: bestLabel,
                    averageDailyXP: activeDays > 0 ? total / activeDays : 0
                )

                DispatchQueue.main.async {
                    if self.weekState != nextState {
                        self.weekState = nextState
                    }
                    self.completeRefresh(for: .week, version: version)
                }
                return
            }

            DispatchQueue.main.async {
                self.completeRefresh(for: .week, version: version)
            }
        }
    }

    private func refreshSystems(version: UInt64) {
        let lock = NSLock()
        let group = DispatchGroup()

        var state = systemsState

        group.enter()
        engine.fetchCurrentProfile { result in
            lock.lock()
            if case .success(let profile) = result {
                let levelInfo = XPCalculationEngine.levelForXP(profile.xpTotal)
                state.level = levelInfo.level
                state.totalXP = profile.xpTotal
                state.currentLevelThreshold = levelInfo.currentThreshold
                state.nextLevelXP = levelInfo.nextThreshold
                state.streakDays = profile.currentStreak
                state.bestStreak = max(profile.bestStreak, profile.bestReturnStreak)

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
            if case .success(let unlocks) = result {
                state.unlockedAchievements = Set(unlocks.map(\.achievementKey))
            }
            lock.unlock()
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
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

    // MARK: - Helpers

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
        for (category, xp) in byCategory where orderedBreakdownCategories.contains(category) == false && xp > 0 {
            items.append(XPBreakdownItem(category: category, xp: xp))
        }

        return (
            tasksCompleted: tasksCompleted,
            breakdown: items,
            recoveryXP: recoveryXP,
            recoveryCount: recoveryCount
        )
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
        for (key, xp) in byCategory where orderedBreakdownCategories.contains(key) == false && xp > 0 {
            items.append(XPBreakdownItem(category: key, xp: xp))
        }
        return items
    }

    private static func recomputeWeekState(from bars: [WeeklyBarData]) -> InsightsWeekState {
        let total = bars.reduce(0) { $0 + $1.xp }
        let goalHit = bars.filter { $0.xp >= GamificationTokens.dailyXPCap }.count
        let activeDays = bars.filter { !$0.isFuture }.count

        let calendar = XPCalculationEngine.mondayCalendar()
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.timeZone = calendar.timeZone

        var bestDayLabel = ""
        if let best = bars.max(by: { $0.xp < $1.xp }), best.xp > 0 {
            if let date = dateFromKey(best.dateKey, calendar: calendar) {
                bestDayLabel = "\(weekdayFormatter.string(from: date)) (\(best.xp) XP)"
            } else {
                bestDayLabel = "\(best.label) (\(best.xp) XP)"
            }
        }

        return InsightsWeekState(
            weeklyBars: bars,
            weeklyTotalXP: total,
            goalHitDays: goalHit,
            bestDayLabel: bestDayLabel,
            averageDailyXP: activeDays > 0 ? total / activeDays : 0
        )
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

// MARK: - Supporting Types

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
    public let isToday: Bool
    public let isFuture: Bool
}
