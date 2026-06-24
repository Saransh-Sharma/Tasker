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
    var currentDataRevision: HomeDataRevision {
        dataRevision
    }

    public func habitLibraryRow(for habitID: UUID) -> HabitLibraryRow? {
        habitLibraryRowsByID[habitID]
    }

    func habitMutationKey(for row: HomeHabitRow, on date: Date) -> HomeHabitMutationKey {
        HomeHabitMutationKey(
            habitID: row.habitID,
            day: normalizedDay(date)
        )
    }

    func normalizedDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    func selectedDayMatches(_ targetDay: Date, scope: HomeListScope) -> Bool {
        guard scope.quickView == .today else { return true }
        return Calendar.current.isDate(selectedDate, inSameDayAs: targetDay)
    }

    func captureHabitMutationSnapshot() -> HomeHabitMutationSnapshot {
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

    func restoreHabitMutationSnapshot(_ snapshot: HomeHabitMutationSnapshot) {
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

    func isHabitMutationPending(for key: HomeHabitMutationKey) -> Bool {
        pendingHabitMutationKeys.contains(key)
    }

    func registerSelfOriginatedHabitMutationContext(_ context: HabitMutationContext) {
        selfOriginatedHabitMutationContextIDs.insert(context.mutationID)
    }

    func removeSelfOriginatedHabitMutationContext(_ context: HabitMutationContext) {
        selfOriginatedHabitMutationContextIDs.remove(context.mutationID)
    }

    func consumeSelfOriginatedHabitMutationContext(_ context: HabitMutationContext?) -> Bool {
        guard let context else {
            return false
        }
        if selfOriginatedHabitMutationContextIDs.remove(context.mutationID) != nil {
            let interval = LifeBoardPerformanceTrace.begin("HomeHabitNotificationSuppressed")
            LifeBoardPerformanceTrace.end(interval)
            return true
        }
        return false
    }

    func habitMutationNotification(from notificationObject: Any?) -> HomeHabitMutationNotification? {
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

    func scheduleHomeRenderStateRefresh(_ invalidation: HomeRenderInvalidation = .all) {
        if Foundation.Thread.isMainThread == false {
            Task { @MainActor [weak self] in
                self?.scheduleHomeRenderStateRefresh(invalidation)
            }
            return
        }
        pendingHomeRenderInvalidation.formUnion(invalidation)
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

    func performHomeRenderStateBatch(_ work: () -> Void) {
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

    func refreshHomeRenderStates() {
        let interval = LifeBoardPerformanceTrace.begin("HomeRenderStateBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let invalidation = pendingHomeRenderInvalidation.isEmpty ? .all : pendingHomeRenderInvalidation
        pendingHomeRenderInvalidation = []
        if invalidation.includes(.chrome) {
            refreshDailyReflectionEntryPreviewIfNeeded()
        }
        let previousTransaction = homeRenderTransaction
        let transaction = HomeRenderTransaction(
            chrome: invalidation.includes(.chrome) ? buildHomeChromeState() : previousTransaction.chrome,
            tasks: invalidation.includes(.tasks) ? buildHomeTasksState() : previousTransaction.tasks,
            habits: invalidation.includes(.habits) ? buildHomeHabitsState() : previousTransaction.habits,
            calendar: invalidation.includes(.calendar) ? buildHomeCalendarState() : previousTransaction.calendar,
            timeline: invalidation.includes(.timeline) ? previousTransaction.timeline.advanced() : previousTransaction.timeline,
            overlay: invalidation.includes(.overlay) ? buildHomeOverlayState() : previousTransaction.overlay
        )
        guard homeRenderTransaction != transaction else { return }

        homeRenderTransaction = transaction
    }

    func buildHomeChromeState() -> HomeChromeState {
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
            momentumGuidanceText: makeMomentumGuidanceText(),
            lifeAreaLensHeader: makeLifeAreaLensHeader(),
            resumeContext: resolveResumeContext()
        )
    }

    /// Builds the project-lens header (identity + open count + next due) when a per-project lens is
    /// active. Returns nil for the Today and Upcoming lenses so their headers stay unchanged.
    func makeLifeAreaLensHeader() -> LifeAreaLensHeader? {
        guard activeFilterState.streamsAllForward,
              let lifeAreaID = activeFilterState.selectedLifeAreaIDs.first,
              let lifeArea = lifeAreas.first(where: { $0.id == lifeAreaID })
        else {
            return nil
        }

        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let openForArea = upcomingTasks.filter { task in
            guard task.isComplete == false else { return false }
            return HomeViewModel.resolvedLifeAreaID(for: task, projectsByID: projectsByID) == lifeAreaID
        }
        return LifeAreaLensHeader(
            lifeAreaName: lifeArea.name,
            openCount: openForArea.count,
            nextDueDate: openForArea.compactMap(\.dueDate).min()
        )
    }

    func buildHomeTasksState() -> HomeTasksState {
        let projectByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let tagNameByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        let todayXPSoFar: Int? = progressState.earnedXP

        let lifeAreasByID = Dictionary(uniqueKeysWithValues: lifeAreas.map { ($0.id, $0) })

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
            lifeAreas: lifeAreas,
            lifeAreasByID: lifeAreasByID,
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
            todayOpenTaskCount: todayOpenTaskCount,
            lifeAreaLensActivity: cachedLifeAreaLensActivity
        )
    }

    func buildHomeHabitsState() -> HomeHabitsSnapshot {
        HomeHabitsSnapshot(
            habitHomeSectionState: habitHomeSectionState,
            quietTrackingSummaryState: quietTrackingSummaryState,
            errorMessage: habitMutationErrorMessage
        )
    }
}
