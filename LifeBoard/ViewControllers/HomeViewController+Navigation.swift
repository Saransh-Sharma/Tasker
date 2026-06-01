//
//  HomeViewController+Navigation.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController: HomeNavigationCoordinatorDelegate {
    func homeNavigationShowTasksDestination() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
    }

    func homeNavigationSetQuickView(_ quickView: HomeQuickView) {
        viewModel?.setQuickView(quickView)
    }

    func homeNavigationSetPendingNotificationFocusTaskID(_ taskID: UUID?) {
        pendingNotificationFocusTaskID = taskID
    }

    func homeNavigationResolveAndPresentTaskDetail(taskID: UUID) {
        guard viewModel != nil else { return }
        resolveAndPresentTaskDetail(taskID: taskID)
    }

    func homeNavigationOpenFocus() {
        guard viewModel != nil else { return }
        handleFocusDeepLink()
    }

    func homeNavigationOpenChat(prompt: String?) {
        guard viewModel != nil else { return }
        handleChatDeepLink(prompt: prompt)
    }

    func homeNavigationOpenHome(notice: String?) {
        guard viewModel != nil else { return }
        handleHomeDeepLink(notice: notice)
    }

    func homeNavigationOpenInsights() {
        guard viewModel != nil else { return }
        handleInsightsDeepLink()
    }

    func homeNavigationOpenTaskScope(scope: String, projectID: UUID?) {
        guard viewModel != nil else { return }
        handleTaskScopeDeepLink(scope: scope, projectID: projectID)
    }

    func homeNavigationOpenHabitBoard() {
        guard viewModel != nil else { return }
        handleHabitBoardDeepLink()
    }

    func homeNavigationOpenHabitLibrary() {
        guard viewModel != nil else { return }
        handleHabitLibraryDeepLink()
    }

    func homeNavigationOpenHabitDetail(habitID: UUID) {
        guard viewModel != nil else { return }
        handleHabitDetailDeepLink(habitID: habitID)
    }

    func homeNavigationOpenQuickAdd() {
        guard viewModel != nil else { return }
        handleQuickAddDeepLink()
    }

    func homeNavigationOpenCalendarSchedule() {
        guard viewModel != nil else { return }
        handleCalendarScheduleDeepLink()
    }

    func homeNavigationOpenCalendarChooser() {
        guard viewModel != nil else { return }
        handleCalendarChooserDeepLink()
    }

    func homeNavigationOpenWeeklyPlanner() {
        guard viewModel != nil else { return }
        handleWeeklyPlannerDeepLink()
    }

    func homeNavigationOpenWeeklyReview() {
        guard viewModel != nil else { return }
        handleWeeklyReviewDeepLink()
    }

    func homeNavigationProcessWidgetActionCommand() {
        guard viewModel != nil else { return }
        processPendingWidgetActionCommand()
    }

    func homeNavigationConsumePendingShortcutHandoff() {
        guard viewModel != nil else { return }
        consumePendingShortcutHandoffIfNeeded()
    }

    func homeNavigationConsumeUITestInjectedRoute() {
        guard viewModel != nil else { return }
        consumeUITestInjectedRouteIfNeeded()
    }

    func homeNavigationConsumeUITestOpenSettings() {
        consumeUITestOpenSettingsIfNeeded()
    }

    func homeNavigationProcessPendingIPadModalRequest() {
        guard viewModel != nil else { return }
        processPendingIPadModalRequest()
    }

    func homeNavigationPresentDailySummary(kind: LifeBoardDailySummaryKind, dateStamp: String?) {
        guard viewModel != nil else { return }
        presentDailySummaryModal(kind: kind, dateStamp: dateStamp)
    }

    func homeNavigationPresentReflectPlan(preferredReflectionDate: Date?) {
        guard viewModel != nil else { return }
        presentReflectPlanFlow(preferredReflectionDate: preferredReflectionDate)
    }

    func homeNavigationDate(from stamp: String?) -> Date? {
        dateFromStamp(stamp)
    }
}

extension HomeViewController: HomeNavigationEventAdapterDelegate {
    func homeNavigationEventAdapter(
        _ adapter: HomeNavigationEventAdapter,
        didReceive intent: HomeNavigationIntent
    ) {
        navigationCoordinator.handle(intent)
    }
}
