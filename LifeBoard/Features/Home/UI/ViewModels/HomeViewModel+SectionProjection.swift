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
    func applyResultToSections(
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
            latestFocusOpenTasks = openTasks
        } else if activeScope.quickView == .done {
            latestFocusOpenTasks = []
        }

        // Refresh the lens auto-fill signal whenever we have the unfiltered forward backlog
        // (the Upcoming lens: streaming forward with no project filter selected).
        if activeFilterState.streamsAllForward, activeFilterState.selectedLifeAreaIDs.isEmpty {
            cachedLifeAreaLensActivity = Self.computeLifeAreaLensActivity(
                from: result.matchingOpenTasks,
                projects: projects
            )
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
        let dueTodayAgendaInputTasks: [TaskDefinition]
        if scope.quickView == .today {
            let rescueEligibleOverdue = result.matchingOpenTasks.filter {
                isTaskOverdue($0, relativeTo: scope) && isRescueEligibleTask($0, on: targetDay)
            }
            dueTodayAgendaInputTasks = uniqueTasks(openTasks + rescueEligibleOverdue)
        } else {
            dueTodayAgendaInputTasks = openTasks
        }
        refreshDueTodayAgenda(
            openTaskRows: dueTodayAgendaInputTasks,
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
            if activeFilterState.streamsAllForward {
                assignIfChanged(
                    \.emptyStateMessage,
                    activeFilterState.selectedProjectIDs.isEmpty
                        ? "Nothing coming up. Your slate is clear."
                        : "No open tasks in this project."
                )
            } else {
                assignIfChanged(\.emptyStateMessage, "No upcoming tasks in 14 days")
            }
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

    func updateCompletionRateFromFocusResult(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let total = openTasks.count + doneTasks.count
        assignIfChanged(\.completionRate, total > 0 ? Double(doneTasks.count) / Double(total) : 0)
    }

    /// Executes refreshProgressState.

    func refreshProgressState() {
        let earnedXP = max(0, dailyScore)
        let remainingPotentialXP: Int
        let targetXP: Int

        remainingPotentialXP = max(0, pointsPotential)
        targetXP = earnedXP + remainingPotentialXP

        let streakDays = max(0, streak)

        assignIfChanged(\.progressState, HomeProgressState(
            earnedXP: earnedXP,
            remainingPotentialXP: remainingPotentialXP,
            todayTargetXP: targetXP,
            streakDays: streakDays,
            isStreakSafeToday: earnedXP > 0
        ))
    }

    func refreshWeeklySummary() {
        let generation = nextWeeklySummaryGeneration()
        assignIfChanged(\.weeklySummaryIsLoading, true)
        assignIfChanged(\.weeklySummaryErrorMessage, nil)
        useCaseCoordinator.getWeeklySummary.execute(referenceDate: Date()) { [weak self] result in
            Task { @MainActor in
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

    func persistLastFilterState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(activeFilterState) {
            userDefaults.set(data, forKey: Self.lastFilterStateKey)
        }
    }

    /// Executes restorePinnedFocusTaskIDs.

    func persistPinnedFocusTaskIDs() {
        let normalized = normalizedPinnedFocusTaskIDs(pinnedFocusTaskIDs)
        if normalized != pinnedFocusTaskIDs {
            pinnedFocusTaskIDs = normalized
        }
        userDefaults.set(normalized.map(\.uuidString), forKey: Self.pinnedFocusTaskIDsKey)
    }

    /// Executes restoreRecentShuffleTaskIDs.

    func persistRecentShuffleTaskIDs() {
        userDefaults.set(recentShuffledFocusTaskIDs.map(\.uuidString), forKey: Self.recentShuffleTaskIDsKey)
    }

    var shuffleExclusionWindow: Int {
        #if DEBUG
        if userDefaults.object(forKey: "debug.eva.focus.shuffleExclusionWindow") != nil {
            let configured = userDefaults.integer(forKey: "debug.eva.focus.shuffleExclusionWindow")
            return max(1, min(8, configured))
        }
        #endif
        return Self.defaultShuffleExclusionWindow
    }

    /// Executes seedPinnedProjectsIfNeeded.

    func seedPinnedLifeAreasIfNeeded(from lifeAreas: [LifeArea]) {
        guard activeFilterState.pinnedLifeAreaIDs.isEmpty else { return }
        let seeded = Array(lifeAreas.prefix(5).map(\.id))
        guard !seeded.isEmpty else { return }
        activeFilterState.pinnedLifeAreaIDs = seeded
        persistLastFilterState()
    }

    /// Executes normalizeCustomProjectOrderIfNeeded.

    func normalizeCustomProjectOrderIfNeeded(from projects: [Project]) {
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

    func bumpPinnedLifeArea(_ id: UUID) {
        var pinned = activeFilterState.pinnedLifeAreaIDs
        pinned.removeAll { $0 == id }
        pinned.insert(id, at: 0)

        if pinned.count > 5 {
            pinned = Array(pinned.prefix(5))
        }

        activeFilterState.pinnedLifeAreaIDs = pinned
    }

    /// Executes refreshEvaInsights.

    func refreshEvaInsights(openTasks: [TaskDefinition]? = nil) {
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
            Task { @MainActor in
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

    func uniqueTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
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

    func sanitizeFilterState(_ state: HomeFilterState, availableProjects: [Project]) -> HomeFilterState {
        var sanitized = state
        sanitized.customProjectOrderIDs = normalizedCustomProjectOrder(
            from: state.customProjectOrderIDs,
            currentOrder: [],
            availableProjects: availableProjects
        )
        return sanitized
    }

    /// Executes normalizedCustomProjectOrder.

    func normalizedCustomProjectOrder(
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

    func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    /// Executes isEveningTaskHybrid.

    func isEveningTaskHybrid(_ task: TaskDefinition) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    /// Buckets open tasks by owning project into a lens-row auto-fill signal: open count plus the
    /// soonest due date among that project's open tasks.
    nonisolated static func computeLifeAreaLensActivity(
        from openTasks: [TaskDefinition],
        projects: [Project]
    ) -> [UUID: HomeLensLifeAreaActivity] {
        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        var openCounts: [UUID: Int] = [:]
        var nearestDue: [UUID: Date] = [:]

        for task in openTasks where task.isComplete == false {
            guard let lifeAreaID = resolvedLifeAreaID(for: task, projectsByID: projectsByID) else { continue }
            openCounts[lifeAreaID, default: 0] += 1
            if let due = task.dueDate {
                if let existing = nearestDue[lifeAreaID] {
                    nearestDue[lifeAreaID] = min(existing, due)
                } else {
                    nearestDue[lifeAreaID] = due
                }
            }
        }

        return openCounts.reduce(into: [:]) { result, entry in
            result[entry.key] = HomeLensLifeAreaActivity(
                openCount: entry.value,
                nearestDue: nearestDue[entry.key]
            )
        }
    }

    nonisolated static func resolvedLifeAreaID(
        for task: TaskDefinition,
        projectsByID: [UUID: Project]
    ) -> UUID? {
        if let direct = task.lifeAreaID {
            return direct
        }
        return projectsByID[task.projectID]?.lifeAreaID
    }

    /// Executes rankedFocusTasks.
}
