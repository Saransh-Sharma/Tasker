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
            rescueReferenceDate: evaRescueReferenceDate,
            lastBatchRunID: evaLastBatchRunID,
            lastXPResult: lastXPResult,
            replanState: homeReplanState
        )
    }

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
