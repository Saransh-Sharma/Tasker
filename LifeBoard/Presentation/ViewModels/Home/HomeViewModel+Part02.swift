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

extension HomeViewModel {
    public func clearHabitMutationErrorMessage() {
        habitMutationErrorMessage = nil
    }

    func buildHomeCalendarState() -> HomeCalendarSnapshot {
        homeCalendarSnapshot
    }

    func buildHomeOverlayState() -> HomeOverlayState {
        HomeOverlayState(
            guidanceState: nil,
            focusWhyPresented: evaFocusWhySheetPresented,
            rescueLauncherState: evaRescueLauncherState,
            rescuePresented: evaRescueSheetPresented,
            rescuePlan: evaRescuePlan,
            lastBatchRunID: evaLastBatchRunID,
            lastXPResult: lastXPResult,
            replanState: homeReplanState
        )
    }

    func makeMomentumGuidanceText() -> String {
        if progressState.earnedXP > 0 {
            return "Momentum secured. Protect the streak with one clean finish."
        }
        if todayOpenTaskCount > 0 {
            return "Pick one visible task and finish it before switching surfaces."
        }
        return "Your surface is clear. Add one intentional task for today."
    }

    func makeDailyReflectionEntryState() -> DailyReflectionEntryState? {
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

    func refreshDailyReflectionEntryPreviewIfNeeded() {
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

        catchUpReflectionPreviewTask = Task { @MainActor [weak self] in
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

    func clearCatchUpReflectionPreview() {
        catchUpReflectionPreviewTask?.cancel()
        catchUpReflectionPreviewTask = nil
        catchUpReflectionPreviewKey = nil
        if catchUpDailyReflectionEntryPreview != nil {
            catchUpDailyReflectionEntryPreview = nil
        }
    }

    func clearReflectionContextPrefetch() {
        reflectionContextPrefetchTask?.cancel()
        reflectionContextPrefetchTask = nil
        reflectionContextPrefetchKey = nil
    }

    func scheduleReflectionContextPrefetchIfNeeded(target: DailyReflectionTarget) {
        let prefetchKey = "\(target.mode.rawValue):\(target.planningDate.timeIntervalSince1970)"
        guard reflectionContextPrefetchKey != prefetchKey else { return }
        reflectionContextPrefetchTask?.cancel()
        reflectionContextPrefetchKey = prefetchKey

        reflectionContextPrefetchTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            try? await _Concurrency.Task.sleep(for: Self.reflectionContextPrefetchDelay)
            guard Task.isCancelled == false else { return }
            guard self.activeScope == .today else { return }

            await self.useCaseCoordinator.dailyReflectionLoadCoordinator.prefetchContext(
                for: target,
                timeoutSeconds: Self.reflectionContextPrefetchTimeoutSeconds
            )
        }
    }

    func makeSameDayReflectionEntryState(target: DailyReflectionTarget) -> DailyReflectionEntryState {
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

    func makeLoadedReflectionEntryState(
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

    func makeBaseDailyReflectionEntryState(target: DailyReflectionTarget) -> DailyReflectionEntryState {
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

    func reflectionClosedTasks(from tasks: [TaskDefinition]) -> [ReflectionTaskMiniRow] {
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

    func reflectionHabitGrid(from rows: [HomeHabitRow]) -> [ReflectionHabitMiniRow] {
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

    func reflectionHabitRiskRank(_ risk: HabitRiskState) -> Int {
        switch risk {
        case .broken:
            return 2
        case .atRisk:
            return 1
        case .stable:
            return 0
        }
    }

    func dailyPlanDraftForSelectedDate() -> DailyPlanDraft? {
        useCaseCoordinator.dailyReflectionStore.fetchPlanDraft(on: selectedDate)
    }

    func bumpTaskRowsDerivationRevision() {
        taskRowsDerivationRevision &+= 1
        cachedOpenTaskRowsForHabitMutation = nil
    }

    func bumpHabitRowsDerivationRevision() {
        habitRowsDerivationRevision &+= 1
        cachedMergedHabitRows = nil
    }

    func invalidateDerivedRowCaches(for keyPath: AnyKeyPath) {
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

    func keyPathTriggersHomeRenderRefreshViaDidSet(_ keyPath: AnyKeyPath) -> Bool {
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
             \HomeViewModel.evaRescueSheetPresented,
             \HomeViewModel.evaRescuePlan,
             \HomeViewModel.evaLastBatchRunID,
             \HomeViewModel.homeReplanState,
             \HomeViewModel.homeCalendarSnapshot:
            return true
        default:
            return false
        }
    }

    func homeRenderInvalidation(forAssignedKeyPath keyPath: AnyKeyPath) -> HomeRenderInvalidation {
        switch keyPath {
        case \HomeViewModel.projects,
             \HomeViewModel.lifeAreas:
            return [.chrome, .tasks, .timeline]
        case \HomeViewModel.tags,
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
             \HomeViewModel.completionRate:
            return .chrome
        case \HomeViewModel.progressState:
            return [.chrome, .tasks]
        case \HomeViewModel.focusWhyShuffleCandidates:
            return .overlay
        default:
            return .all
        }
    }
    // MARK: - Initialization

    /// Initializes a new instance.

    public func loadTasksForSelectedDate() {
        applySelectedDay(selectedDate, source: .datePicker, trackAnalytics: false, forceReload: true)
    }

    /// Executes loadTasksForSelectedDate.

    func loadTasksForSelectedDate(generation: Int) {
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
}
