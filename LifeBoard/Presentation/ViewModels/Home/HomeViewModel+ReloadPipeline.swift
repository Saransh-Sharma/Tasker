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
    func optimisticNearestDoneState(in cells: [HabitBoardCell], after index: Int) -> Bool {
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

    func refreshGamificationV2State(generation: Int? = nil) {
        let engine = useCaseCoordinator.gamificationEngine

        engine.fetchTodayXP { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if let generation, !self.isCurrentAnalyticsGeneration(generation) { return }
                if case .success(let todayXP) = result {
                    self.dailyScore = todayXP
                    self.refreshProgressState()
                }
            }
        }

        engine.fetchCurrentProfile { [weak self] result in
            Task { @MainActor in
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

    func refreshDailyScoreFromCompletedTasksToday(
        referenceDate: Date = Date(),
        generation: Int? = nil,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion?()
            return
        }

        useCaseCoordinator.getTasks.searchTasks(query: "", in: .all) { [weak self] result in
            Task { @MainActor in
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

    func loadProjectTasks(_ projectID: UUID) {
        loadProjectTasks(projectID, generation: nextReloadGeneration())
    }

    /// Executes loadProjectTasks.

    func loadProjectTasks(_ projectID: UUID, generation: Int) {
        isLoading = true

        useCaseCoordinator.getTasks.getTasksForProject(projectID) { [weak self] result in
            Task { @MainActor in
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

    func reloadCurrentModeTasks() {
        let generation = nextReloadGeneration()
        applyReloadScopes([.visibleTasks], generation: generation)
    }

    func applyReloadScopes(
        _ scopes: Set<HomeReloadScope>,
        generation: Int,
        visibleTasksCompletion: (@Sendable () -> Void)? = nil,
        habitsCompletion: (@Sendable () -> Void)? = nil,
        facetsCompletion: (@Sendable () -> Void)? = nil,
        savedViewsCompletion: (@Sendable () -> Void)? = nil
    ) {
        if scopes.contains(.savedViews) {
            loadSavedViews(completion: savedViewsCompletion)
        }
        if scopes.contains(.facets) {
            let tracker = HomeReloadBatchTracker {
                facetsCompletion?()
            }
            tracker.registerOperation()
            tracker.registerOperation()
            loadProjects(generation: generation) {
                Task { @MainActor in tracker.completeOperation() }
            }
            loadTags(generation: generation) {
                Task { @MainActor in tracker.completeOperation() }
            }
            tracker.finishSchedulingOperations()
        }
        if scopes.contains(.visibleTasks) {
            applyFocusFilters(
                trackAnalytics: false,
                generation: generation,
                completion: visibleTasksCompletion
            )
        }
        if scopes.contains(.habits) {
            let interval = LifeBoardPerformanceTrace.begin("HomeHabitScopedReload")
            let targetDay = normalizedDay(activeScope.referenceDate)
            let scope = activeScope
            refreshDueTodayAgenda(
                openTaskRows: openTaskRowsForHabitReconciliation(),
                generation: generation,
                targetDay: targetDay,
                scope: scope,
                includeAnalyticsRefresh: false,
                completion: {
                    LifeBoardPerformanceTrace.end(interval)
                    habitsCompletion?()
                }
            )
        }
    }

    /// Executes upsertTag.

    func upsertTag(_ tag: TagDefinition) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
        } else {
            tags.append(tag)
        }
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Executes applyFocusFilters.

    func applyFocusFilters(trackAnalytics: Bool) {
        applyFocusFilters(trackAnalytics: trackAnalytics, generation: nextReloadGeneration())
    }

    /// Executes applyFocusFilters.

    func applyFocusFilters(
        trackAnalytics: Bool,
        generation: Int,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let interval = LifeBoardPerformanceTrace.begin("HomeApplyFilters")
        let filterState = activeFilterState
        let scope = activeScope
        let revision = dataRevision
        let targetDay = normalizedDay(scope.referenceDate)
        if scope.quickView == .today {
            LifeBoardPerformanceTrace.event(
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
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                defer { completion?() }
                guard let self else { return }
                guard self.isCurrentReloadGeneration(generation) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_reload source=focus generation=\(generation)")
                    LifeBoardPerformanceTrace.event("HomeDaySwipeStaleDrop")
                    return
                }
                guard self.selectedDayMatches(targetDay, scope: scope) else {
                    logDebug("HOME_ROW_STATE vm.drop_stale_day source=focus generation=\(generation)")
                    LifeBoardPerformanceTrace.event("HomeDaySwipeStaleDrop")
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
                    }
                    if scope.quickView == .today {
                        self.scheduleAdjacentDayPrefetch(around: targetDay, generation: generation)
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func scheduleAdjacentDayPrefetch(around targetDay: Date, generation: Int) {
        pendingAdjacentDayPrefetchTask?.cancel()
        let baseDay = normalizedDay(targetDay)
        pendingAdjacentDayPrefetchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard self.isCurrentReloadGeneration(generation) else { return }
            guard self.activeScope.quickView == .today else { return }
            guard self.selectedDayMatches(baseDay, scope: self.activeScope) else { return }
            if let suppressUntil = self.suppressTaskReloadsForHabitMutationUntil,
               Date() <= suppressUntil {
                logDebug("HOME_DAY_PREFETCH skipped reason=habit_mutation")
                self.pendingAdjacentDayPrefetchTask = nil
                return
            }
            self.prefetchAdjacentDays(around: baseDay)
            self.pendingAdjacentDayPrefetchTask = nil
        }
    }

    func prefetchAdjacentDays(around targetDay: Date) {
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
                    LifeBoardPerformanceTrace.event("HomeDaySwipePrefetchReady")
                }
            }
        }
    }

    /// Executes applyResultToSections.
}
