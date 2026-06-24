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
    func setTaskCompletion(
        taskID: UUID,
        to requestedCompletion: Bool,
        taskSnapshot: TaskDefinition?,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        logDebug(
            "HOME_ROW_STATE vm.toggle_input id=\(taskID.uuidString) " +
            "isComplete=\(String(describing: taskSnapshot?.isComplete)) requested=\(requestedCompletion)"
        )
        useCaseCoordinator.completeTaskDefinition.setCompletion(
            taskID: taskID,
            to: requestedCompletion
        ) { [weak self] result in
            Task { @MainActor in
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

    func currentTaskSnapshot(for id: UUID) -> TaskDefinition? {
        if let task = timelineProjectionTasks.first(where: { $0.id == id }) { return task }
        if let task = morningTasks.first(where: { $0.id == id }) { return task }
        if let task = eveningTasks.first(where: { $0.id == id }) { return task }
        if let task = overdueTasks.first(where: { $0.id == id }) { return task }
        if let task = dailyCompletedTasks.first(where: { $0.id == id }) { return task }
        if let task = upcomingTasks.first(where: { $0.id == id }) { return task }
        if let task = completedTasks.first(where: { $0.id == id }) { return task }
        return doneTimelineTasks.first(where: { $0.id == id })
    }

    /// Executes mutationReason.

    func mutationReason(for request: UpdateTaskDefinitionRequest) -> HomeTaskMutationEvent {
        HomeTaskMutationReasonResolver.reason(for: request)
    }

    /// Executes loadInitialData.

    func loadInitialData() {
        let interval = LifeBoardPerformanceTrace.begin("HomeInitialLoad")
        defer { LifeBoardPerformanceTrace.end(interval) }

        homeOpenedAt = Date()
        didTrackFirstCompletionLatency = false

        restoreLastFilterState()
        restorePinnedFocusTaskIDs()
        restoreRecentShuffleTaskIDs()
        activeScope = .fromQuickView(activeFilterState.quickView)
        if case .today = activeScope {
            selectedDate = Date()
        }
        LifeBoardMemoryDiagnostics.checkpoint(
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
            Task { @MainActor in
                LifeBoardMemoryDiagnostics.checkpoint(
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
    }

}
