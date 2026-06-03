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
    func rankedFocusTasks(from tasks: [TaskDefinition], relativeTo scope: HomeListScope) -> [TaskDefinition] {
        guard !tasks.isEmpty else { return [] }

        let calendar = Calendar.current
        let anchorStart = calendar.startOfDay(for: scope.referenceDate)
        let anchorEnd = calendar.date(byAdding: .day, value: 1, to: anchorStart) ?? anchorStart

        /// Executes isOverdue.
        func isOverdue(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate < anchorStart
        }

        /// Executes isDueToday.
        func isDueToday(_ task: TaskDefinition) -> Bool {
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= anchorStart && dueDate < anchorEnd
        }

        if V2FeatureFlags.evaFocusEnabled {
            let scored = tasks.map { task in
                let overdueDays = task.dueDate.map { max(0, calendar.dateComponents([.day], from: $0, to: anchorStart).day ?? 0) } ?? 0
                let urgency = Double(overdueDays) * 1.4 + (isDueToday(task) ? 2.0 : 0)
                let quickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800 ? 1.0 : 0
                let unblocked = task.dependencies.isEmpty ? 1.0 : -1.2
                let importance = Double(task.priority.scorePoints) * 0.6
                let staleDays = max(0, calendar.dateComponents([.day], from: task.updatedAt, to: Date()).day ?? 0)
                let freshness = staleDays >= 14 ? -0.8 : 0.3
                let score = urgency + quickWin + unblocked + importance + freshness
                return (task: task, score: score)
            }
            let sortedScored = scored.sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                let lhsDue = lhs.task.dueDate ?? Date.distantFuture
                let rhsDue = rhs.task.dueDate ?? Date.distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.task.id.uuidString < rhs.task.id.uuidString
            }
            return Array(sortedScored.map(\.task).prefix(Self.maxPinnedFocusTasks))
        }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsOverdue = isOverdue(lhs)
            let rhsOverdue = isOverdue(rhs)
            if lhsOverdue != rhsOverdue {
                return lhsOverdue
            }

            let lhsDueToday = isDueToday(lhs)
            let rhsDueToday = isDueToday(rhs)
            if lhsDueToday != rhsDueToday {
                return lhsDueToday
            }

            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }

            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }

        return Array(sorted.prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes composedFocusTasks.

    func composedFocusTasks(from openTasks: [TaskDefinition]) -> [TaskDefinition] {
        guard !openTasks.isEmpty else { return [] }
        guard activeScope.quickView == .today else {
            return rankedFocusTasks(from: openTasks, relativeTo: activeScope)
        }

        let openByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        let pinnedOpen = pinnedFocusTaskIDs.compactMap { openByID[$0] }
        let pinnedSet = Set(pinnedOpen.map(\.id))
        let rankedAutoFill = rankedFocusTasks(
            from: openTasks.filter { !pinnedSet.contains($0.id) },
            relativeTo: activeScope
        )

        return Array((pinnedOpen + rankedAutoFill).prefix(Self.maxPinnedFocusTasks))
    }

    /// Executes prunePinnedFocusTaskIDs.

    func prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set<UUID>) {
        let filtered = pinnedFocusTaskIDs.filter { keepingOpenTaskIDs.contains($0) }
        guard filtered != pinnedFocusTaskIDs else { return }
        pinnedFocusTaskIDs = filtered
        persistPinnedFocusTaskIDs()
    }

    /// Executes removePinnedFocusTaskID.

    func removePinnedFocusTaskID(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
    }

    /// Executes normalizedPinnedFocusTaskIDs.

    func normalizedPinnedFocusTaskIDs(_ ids: [UUID]) -> [UUID] {
        var deduped: [UUID] = []
        deduped.reserveCapacity(min(ids.count, Self.maxPinnedFocusTasks))

        for id in ids where !deduped.contains(id) {
            deduped.append(id)
            if deduped.count == Self.maxPinnedFocusTasks {
                break
            }
        }

        return deduped
    }

    /// Executes focusOpenTasksForCurrentState.

    func focusOpenTasksForCurrentState() -> [TaskDefinition] {
        switch activeScope.quickView {
        case .done:
            return []
        case .upcoming:
            return upcomingTasks.filter { !$0.isComplete }
        case .overdue:
            return overdueTasks.filter { !$0.isComplete }
        case .today, .morning, .evening:
            return (morningTasks + eveningTasks + overdueTasks).filter { !$0.isComplete }
        }
    }

    /// Executes refreshFocusTasksFromCurrentState.

    func refreshFocusTasksFromCurrentState() {
        if activeScope.quickView == .done {
            updateFocusSelection([])
            refreshEvaInsights(openTasks: [])
            return
        }

        let openTasks = focusOpenTasksForCurrentState()
        if activeScope.quickView == .today {
            prunePinnedFocusTaskIDs(keepingOpenTaskIDs: Set(openTasks.map(\.id)))
        }
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshEvaInsights(openTasks: openTasks)
    }

    func writeTaskListWidgetSnapshot(reason: String = "home_event") {
        guard V2FeatureFlags.taskListWidgetsEnabled else { return }
        if reason.hasPrefix("apply_result_"), lastTaskListSnapshotRevision == dataRevision {
            return
        }
        lastTaskListSnapshotRevision = dataRevision
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "widget_snapshot_scheduled",
            message: "Scheduling task list widget snapshot refresh",
            fields: ["reason": reason],
            counts: [
                "morning_count": morningTasks.count,
                "evening_count": eveningTasks.count,
                "overdue_count": overdueTasks.count,
                "focus_count": focusTasks.count
            ]
        )
        TaskListWidgetSnapshotService.shared.scheduleRefresh(reason: reason)
    }

    func buildTaskListWidgetSnapshot() -> TaskListWidgetSnapshot {
        let openUnion = uniqueTasks(
            morningTasks.filter { !$0.isComplete } +
            eveningTasks.filter { !$0.isComplete } +
            overdueTasks.filter { !$0.isComplete } +
            upcomingTasks.filter { !$0.isComplete } +
            focusTasks.filter { !$0.isComplete }
        )
        let sortedOpen = sortTasksByPriorityThenDue(openUnion)
        let topTasks = Array((focusTasks.filter { !$0.isComplete }.isEmpty ? sortedOpen : focusTasks.filter { !$0.isComplete }).prefix(3))
        let overdueTop = Array(sortTasksByPriorityThenDue(overdueTasks.filter { !$0.isComplete }).prefix(3))

        let now = Date()
        let fortyEightHours = now.addingTimeInterval(48 * 60 * 60)
        let dueSoon = sortTasksByPriorityThenDue(
            openUnion.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= fortyEightHours
            }
        )

        let quickWinCandidates = sortTasksByPriorityThenDue(
            openUnion.filter { task in
                guard let minutes = task.estimatedDuration.map({ Int($0 / 60) }) else { return false }
                return minutes > 0 && minutes <= 15
            }
        )

        let waiting = Array(
            sortTasksByPriorityThenDue(openUnion.filter { !$0.dependencies.isEmpty })
                .prefix(3)
        )

        let completedToday = dailyCompletedTasks.filter { task in
            guard let completedAt = task.dateCompleted else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }

        let projectSlices: [TaskListWidgetProjectSlice] = Dictionary(
            grouping: openUnion,
            by: { task in
                task.projectID
            }
        )
        .map { projectID, tasks in
            let projectName = tasks.first?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = (projectName?.isEmpty == false ? projectName : nil) ?? "Inbox"
            return TaskListWidgetProjectSlice(
                projectID: projectID,
                projectName: normalizedName,
                openCount: tasks.count,
                overdueCount: tasks.filter(\.isOverdue).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.openCount != rhs.openCount {
                return lhs.openCount > rhs.openCount
            }
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        let energyBuckets: [TaskListWidgetEnergyBucket] = TaskEnergy.allCases.map { energy in
            TaskListWidgetEnergyBucket(
                energy: energy.rawValue,
                count: openUnion.filter { $0.energy == energy }.count
            )
        }

        return TaskListWidgetSnapshot(
            updatedAt: Date(),
            todayTopTasks: topTasks.map(widgetTask(from:)),
            upcomingTasks: Array(dueSoon.prefix(3)).map(widgetTask(from:)),
            overdueTasks: overdueTop.map(widgetTask(from:)),
            quickWins: Array(quickWinCandidates.prefix(3)).map(widgetTask(from:)),
            projectSlices: Array(projectSlices.prefix(4)),
            doneTodayCount: completedToday.count,
            focusNow: Array(focusTasks.filter { !$0.isComplete }.prefix(3)).map(widgetTask(from:)),
            waitingOn: waiting.map(widgetTask(from:)),
            energyBuckets: energyBuckets
        )
    }

    func widgetTask(from task: TaskDefinition) -> TaskListWidgetTask {
        let minutes = task.estimatedDuration.map { duration in
            max(1, Int(duration / 60))
        }
        return TaskListWidgetTask(
            id: task.id,
            title: task.title,
            projectID: task.projectID,
            projectName: task.projectName,
            priorityCode: task.priority.code,
            dueDate: task.dueDate,
            isOverdue: task.isOverdue,
            estimatedDurationMinutes: minutes,
            energy: task.energy.rawValue,
            context: task.context.rawValue,
            isComplete: task.isComplete,
            hasDependencies: !task.dependencies.isEmpty
        )
    }

    func reloadTaskListWidgetTimelines() {
        #if canImport(WidgetKit)
        Task { @MainActor in
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    /// Executes trackFeatureUsage.

    func trackFeatureUsage(action: String, metadata: [String: Any]? = nil) {
        analyticsService?.trackFeatureUsage(feature: "home_filter", action: action, metadata: metadata)
    }

    /// Executes handleExternalMutation.

    public func handleExternalMutation(reason: HomeTaskMutationEvent, repostEvent: Bool = true) {
        enqueueReload(
            source: "external_mutation_\(reason.rawValue)",
            reason: reason,
            taskID: nil,
            invalidateCaches: true,
            includeAnalytics: true,
            repostEvent: repostEvent
        )
    }

    public func enqueueReload(
        source: String,
        reason: HomeTaskMutationEvent? = nil,
        taskID: UUID? = nil,
        invalidateCaches: Bool,
        includeAnalytics: Bool,
        repostEvent: Bool,
        overrideScopes: Set<HomeReloadScope>? = nil
    ) {
        logDebug(
            "HOME_RELOAD enqueue source=\(source) reason=\(reason?.rawValue ?? "nil") " +
            "invalidate=\(invalidateCaches) include_analytics=\(includeAnalytics) repost=\(repostEvent)"
        )
        pendingReloadSources.insert(source)
        if let reason {
            pendingReloadReasons.insert(reason)
        }
        let scopes = overrideScopes ?? reloadScopes(for: reason, includeAnalytics: includeAnalytics, repostEvent: repostEvent)
        pendingReloadScopes.formUnion(scopes)
        if let taskID {
            pendingReloadTaskIDs.insert(taskID)
        }
        pendingReloadInvalidateCaches = pendingReloadInvalidateCaches || invalidateCaches
        pendingReloadIncludeAnalytics = pendingReloadIncludeAnalytics || includeAnalytics
        pendingReloadRepostEvent = pendingReloadRepostEvent || repostEvent

        pendingReloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushQueuedReloads()
        }
        pendingReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(reloadDebounceMS),
            execute: workItem
        )
    }
}
