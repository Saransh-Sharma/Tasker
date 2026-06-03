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
    public func undoRescueRun(
        completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void
    ) {
        trackHomeInteraction(action: "rescue_undo_tap", metadata: [:])
        undoEvaBatchPlan { [weak self] result in
            Task { @MainActor [weak self] in
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
    }

    public func createSplitChildren(
        parentTaskID: UUID,
        draft: EvaSplitDraft,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
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
        let accumulator = LockedResultAccumulator([TaskDefinition]())

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
                switch result {
                case .success(let task):
                    accumulator.update { $0.append(task) }
                case .failure(let error):
                    accumulator.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            switch accumulator.result() {
            case .failure(let firstError):
                self.trackHomeInteraction(action: "rescue_apply_error", metadata: [
                    "split_parent_task_id": parentTaskID.uuidString,
                    "error": firstError.localizedDescription
                ])
                completion(.failure(firstError))
                return
            case .success(let created):
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
    }

    public func undoCreatedSplitChildren(
        childTaskIDs: [UUID],
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard childTaskIDs.isEmpty == false else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let accumulator = LockedResultAccumulator(())

        for taskID in childTaskIDs {
            group.enter()
            useCaseCoordinator.deleteTaskDefinition.execute(taskID: taskID, scope: .single) { result in
                if case .failure(let error) = result {
                    accumulator.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if case .failure(let firstError) = accumulator.result() {
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

    func scheduleInitialDeferredAnalyticsRefreshIfNeeded() {
        guard activeScope.quickView == .today else { return }
        scheduleDeferredAnalyticsRefresh(
            reason: "initial_load",
            includeGamificationRefresh: true,
            delayMilliseconds: 1_500
        )
    }

    /// Executes loadDailyAnalytics.

    func loadDailyAnalytics(
        includeGamificationRefresh: Bool = true,
        completion: (@Sendable () -> Void)? = nil
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

    func scheduleDeferredAnalyticsRefresh(
        reason: String,
        includeGamificationRefresh: Bool,
        delayMilliseconds: Int = 450
    ) {
        pendingDeferredAnalyticsRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let interval = LifeBoardPerformanceTrace.begin("HomeDeferredAnalyticsRefresh")
            self.loadDailyAnalytics(includeGamificationRefresh: includeGamificationRefresh) {
                LifeBoardPerformanceTrace.end(interval)
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
}
