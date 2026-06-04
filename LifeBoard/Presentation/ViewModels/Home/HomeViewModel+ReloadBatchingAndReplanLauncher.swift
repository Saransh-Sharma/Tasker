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
    func cancelPendingReloadDebounce() {
        pendingReloadDebounceID += 1
        pendingReloadTask?.cancel()
        pendingReloadTask = nil
    }

    func flushQueuedReloads() {
        if isApplyingReloadBatch {
            queuedReloadAfterCurrentBatch = true
            return
        }
        isApplyingReloadBatch = true
        cancelPendingReloadDebounce()

        let reasons = pendingReloadReasons
        let sources = pendingReloadSources
        let scopes = pendingReloadScopes
        let shouldInvalidate = pendingReloadInvalidateCaches
        let shouldIncludeAnalytics = pendingReloadIncludeAnalytics
        let shouldRepostEvent = pendingReloadRepostEvent

        pendingReloadReasons = []
        pendingReloadSources = []
        pendingReloadScopes = []
        pendingReloadTaskIDs = []
        pendingReloadInvalidateCaches = false
        pendingReloadIncludeAnalytics = false
        pendingReloadRepostEvent = false

        let reloadStartedAt = Date()
        logDebug(
            "HOME_RELOAD flush sources=\(sources.sorted().joined(separator: ",")) " +
            "reasons=\(reasons.map(\.rawValue).sorted().joined(separator: ",")) " +
            "scopes=\(scopes.map(\.rawValue).sorted().joined(separator: ",")) " +
            "invalidate=\(shouldInvalidate)"
        )
        if shouldInvalidate {
            invalidateTaskCaches()
        }
        let interval = LifeBoardPerformanceTrace.begin("HomeReloadBatch")
        let generation = nextReloadGeneration()
        let tracker = HomeReloadBatchTracker { [weak self] in
            LifeBoardPerformanceTrace.end(interval)
            logWarning(
                event: "home_reload_batch_applied",
                message: "Applied coalesced Home reload batch",
                fields: [
                    "source_count": String(sources.count),
                    "reason_count": String(reasons.count),
                    "scope_count": String(scopes.count),
                    "invalidate_caches": shouldInvalidate ? "true" : "false",
                    "include_analytics": shouldIncludeAnalytics ? "true" : "false",
                    "repost_event": shouldRepostEvent ? "true" : "false",
                    "duration_ms": String(Int(Date().timeIntervalSince(reloadStartedAt) * 1_000))
                ]
            )
            self?.completeReloadBatchLifecycle()
        }

        let visibleTasksOperationID = scopes.contains(.visibleTasks) ? tracker.registerOperation() : nil
        let habitsOperationID = scopes.contains(.habits) ? tracker.registerOperation() : nil
        let facetsOperationID = scopes.contains(.facets) ? tracker.registerOperation() : nil
        let savedViewsOperationID = scopes.contains(.savedViews) ? tracker.registerOperation() : nil

        let visibleTasksCompletion: (@Sendable () -> Void)?
        if let visibleTasksOperationID {
            visibleTasksCompletion = {
                Task { @MainActor in tracker.completeOperation(visibleTasksOperationID) }
            }
        } else {
            visibleTasksCompletion = nil
        }
        let habitsCompletion: (@Sendable () -> Void)?
        if let habitsOperationID {
            habitsCompletion = {
                Task { @MainActor in tracker.completeOperation(habitsOperationID) }
            }
        } else {
            habitsCompletion = nil
        }
        let facetsCompletion: (@Sendable () -> Void)?
        if let facetsOperationID {
            facetsCompletion = {
                Task { @MainActor in tracker.completeOperation(facetsOperationID) }
            }
        } else {
            facetsCompletion = nil
        }
        let savedViewsCompletion: (@Sendable () -> Void)?
        if let savedViewsOperationID {
            savedViewsCompletion = {
                Task { @MainActor in tracker.completeOperation(savedViewsOperationID) }
            }
        } else {
            savedViewsCompletion = nil
        }

        applyReloadScopes(
            scopes,
            generation: generation,
            visibleTasksCompletion: visibleTasksCompletion,
            habitsCompletion: habitsCompletion,
            facetsCompletion: facetsCompletion,
            savedViewsCompletion: savedViewsCompletion
        )

        if scopes.contains(.habits),
           !scopes.contains(.analytics),
           Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
            scheduleDeferredAnalyticsRefresh(
                reason: "habit_reload_scope",
                includeGamificationRefresh: false
            )
        }

        if shouldIncludeAnalytics || scopes.contains(.analytics) {
            let analyticsOperationID = tracker.registerOperation()
            loadDailyAnalytics(includeGamificationRefresh: false) {
                Task { @MainActor in tracker.completeOperation(analyticsOperationID) }
            }
        }
        tracker.finishSchedulingOperations()
    }

    func completeReloadBatchLifecycle() {
        logDebug(
            "HOME_RELOAD complete morning=\(morningTasks.count) evening=\(eveningTasks.count) " +
            "overdue=\(overdueTasks.count) due_today_rows=\(dueTodayRows.count) " +
            "today_sections=\(todaySections.count) data_revision=\(dataRevision.rawValue)"
        )
        isApplyingReloadBatch = false
        if queuedReloadAfterCurrentBatch {
            queuedReloadAfterCurrentBatch = false
            if pendingReloadSources.isEmpty == false {
                flushQueuedReloads()
            }
        }
    }

    func reloadScopes(
        for reason: HomeTaskMutationEvent?,
        includeAnalytics: Bool,
        repostEvent: Bool
    ) -> Set<HomeReloadScope> {
        var scopes: Set<HomeReloadScope> = [.visibleTasks]
        if includeAnalytics {
            scopes.insert(.analytics)
        }
        return scopes
    }

    func prioritizedReloadReason(from reasons: Set<HomeTaskMutationEvent>) -> HomeTaskMutationEvent? {
        let priorityOrder: [HomeTaskMutationEvent] = [
            .completed,
            .reopened,
            .created,
            .deleted,
            .rescheduled,
            .projectChanged,
            .priorityChanged,
            .typeChanged,
            .dueDateChanged,
            .updated,
            .bulkChanged
        ]
        return priorityOrder.first(where: { reasons.contains($0) }) ?? reasons.first
    }

    func prioritizedTaskID(from taskIDs: Set<UUID>, for reason: HomeTaskMutationEvent) -> UUID? {
        guard taskIDs.isEmpty == false else { return nil }

        switch reason {
        case .completed, .reopened, .created, .deleted, .rescheduled, .projectChanged, .priorityChanged, .typeChanged, .dueDateChanged, .updated:
            return taskIDs.first
        case .bulkChanged:
            return nil
        }
    }

    func handleGamificationLedgerMutation(_ mutation: GamificationLedgerMutation) {
        lastLedgerMutationObservedAt = Date()
        pendingLedgerMutationWatchdogID += 1
        pendingLedgerMutationWatchdogTask?.cancel()
        pendingLedgerMutationWatchdogTask = nil

        dailyScore = max(0, mutation.dailyXPSoFar)
        totalXP = mutation.totalXP
        currentLevel = max(1, mutation.level)
        streak = max(0, mutation.streakDays)
        let levelInfo = XPCalculationEngine.levelForXP(mutation.totalXP)
        nextLevelXP = levelInfo.nextThreshold
        refreshProgressState()

        let celebrationEligibleCategories: Set<XPActionCategory> = [.complete, .focus, .reflection]
        guard celebrationEligibleCategories.contains(mutation.category), mutation.awardedXP > 0 else { return }

        let milestone = XPCalculationEngine.milestoneCrossed(
            previousXP: max(0, mutation.totalXP - Int64(mutation.awardedXP)),
            newXP: mutation.totalXP
        )
        let celebration = XPCelebrationPayload(
            awardedXP: mutation.awardedXP,
            level: mutation.level,
            didLevelUp: mutation.level > mutation.previousLevel,
            crossedMilestone: milestone,
            cooldownSeconds: GamificationEngine.celebrationCooldownSeconds,
            occurredAt: mutation.occurredAt
        )
        let unlockedAchievements = mutation.unlockedAchievementKeys.map { key in
            AchievementUnlockDefinition(
                id: UUID(),
                achievementKey: key,
                unlockedAt: mutation.occurredAt,
                sourceEventID: mutation.originatingEventID
            )
        }

        dispatchCelebration(XPEventResult(
            awardedXP: mutation.awardedXP,
            totalXP: mutation.totalXP,
            level: mutation.level,
            previousLevel: mutation.previousLevel,
            currentStreak: mutation.streakDays,
            didLevelUp: mutation.level > mutation.previousLevel,
            dailyXPSoFar: mutation.dailyXPSoFar,
            unlockedAchievements: unlockedAchievements,
            crossedMilestone: milestone,
            celebration: celebration
        ))
    }

    func scheduleLedgerMutationWatchdog(trigger: String) {
        guard V2FeatureFlags.gamificationV2Enabled else { return }

        pendingLedgerMutationWatchdogTask?.cancel()
        pendingLedgerMutationWatchdogID += 1
        let watchdogID = pendingLedgerMutationWatchdogID
        let observedAtScheduleTime = lastLedgerMutationObservedAt
        let delay = Duration.milliseconds(Int(ledgerMutationWatchdogDelaySeconds * 1_000))
        pendingLedgerMutationWatchdogTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self else { return }
            guard self.pendingLedgerMutationWatchdogID == watchdogID else { return }
            self.pendingLedgerMutationWatchdogTask = nil
            guard self.lastLedgerMutationObservedAt <= observedAtScheduleTime else { return }

            logWarning(
                event: "gamification_ledger_watchdog_refresh",
                message: "Ledger mutation signal not observed in time; forcing one-shot XP state refresh",
                fields: ["trigger": trigger]
            )
            self.refreshGamificationV2State()
            NotificationCenter.default.post(
                name: Notification.Name("DataDidChangeFromCloudSync"),
                object: nil
            )
        }
    }

    /// Executes requestInsightsRefresh.

    public func requestInsightsRefresh(reason: HomeTaskMutationEvent, taskID: UUID? = nil) {
        let userInfo = HomeTaskMutationPayload(
            reason: reason,
            source: Self.mutationNotificationSource,
            taskID: taskID
        ).userInfo
        NotificationCenter.default.post(
            name: .homeTaskMutation,
            object: nil,
            userInfo: userInfo
        )
    }

    /// Executes scopeAnalyticsAction.

    func scopeAnalyticsAction(_ scope: HomeListScope) -> String {
        switch scope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .overdue:
            return "overdue"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }
    // MARK: - Needs Replan

    public func openNeedsReplanLauncher() {
        beginReplanLauncher(with: needsReplanCandidates, scopedTo: nil)
    }

    func needsReplanCandidatesForTesting(
        from tasks: [TaskDefinition],
        scopedTo date: Date? = nil
    ) -> [HomeReplanCandidate] {
        deriveNeedsReplanCandidates(from: tasks, scopedTo: date)
    }

    func defaultReplanPlacementDayForTesting(now: Date) -> Date {
        defaultReplanPlacementDay(now: now)
    }

    func beginReplanPlacementForTesting(candidate: HomeReplanCandidate) {
        needsReplanViewModel.beginSession(with: [candidate], scopedTo: nil)
        updateReplanState(phase: .placement(candidate, defaultDay: Date()))
    }

    func setReplanApplyingForTesting(_ action: HomeReplanApplyingAction?) {
        replanApplyingAction = action
        updateReplanState(phase: homeReplanState.phase)
    }

    public func openNeedsReplanLauncher(for date: Date) {
        let calendar = Calendar.current
        guard calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()) else { return }
        let scopedCandidates = needsReplanCandidates.filter {
            guard let anchorDate = $0.anchorDate else { return false }
            return calendar.isDate(anchorDate, inSameDayAs: date)
        }
        beginReplanLauncher(with: scopedCandidates, scopedTo: date)
    }

    public func startNeedsReplanSession() {
        guard let phase = needsReplanViewModel.phaseForStartingSession() else { return }
        updateReplanState(phase: phase)
    }

    public func dismissNeedsReplanLater() {
        guard needsReplanViewModel.dismissLater() else { return }
        updateReplanState(phase: .trayHidden)
        refreshPassiveNeedsReplanState()
    }

    public func finishNeedsReplanSession() {
        guard needsReplanViewModel.finishSession() else { return }
        updateReplanState(phase: .trayHidden)
        refreshPassiveNeedsReplanState()
    }

    public func dismissNeedsReplanSessionUI() {
        guard needsReplanViewModel.dismissSessionUI() else { return }
        updateReplanState(phase: .trayHidden)
        refreshPassiveNeedsReplanState()
    }

    public func reviewSkippedReplanCandidates() {
        guard let phase = needsReplanViewModel.phaseForReviewingSkippedCandidates() else {
            finishNeedsReplanSession()
            return
        }
        updateReplanState(phase: .skippedReview)
        updateReplanState(phase: phase)
    }

    public func skipCurrentReplanCandidate() {
        guard let phase = needsReplanViewModel.skipCurrentCandidate() else { return }
        advanceReplanSession(to: phase)
    }

    public func moveCurrentReplanCandidateToInbox() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        var updated = candidate.task
        updated.projectID = ProjectConstants.inboxProjectID
        updated.projectName = ProjectConstants.inboxProjectName
        updated.type = .inbox
        updated.dueDate = nil
        updated.scheduledStartAt = nil
        updated.scheduledEndAt = nil
        updated.isAllDay = false
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .movedToInbox,
            candidate: candidate,
            reloadReason: .projectChanged
        )
    }

    public func checkOffCurrentReplanCandidate() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        var updated = candidate.task
        updated.isComplete = true
        updated.dateCompleted = Date()
        updated.updatedAt = Date()
        applyReplanCommand(
            .restoreTaskSnapshot(snapshot: AssistantTaskSnapshot(task: updated)),
            action: .completed,
            candidate: candidate,
            reloadReason: .completed
        )
    }

    public func deleteCurrentReplanCandidate() {
        guard replanApplyingAction == nil else { return }
        guard let candidate = activeReplanCandidates.first else { return }
        applyReplanCommand(
            .deleteTask(taskID: candidate.task.id),
            action: .deleted,
            candidate: candidate,
            reloadReason: .deleted
        )
    }

    public func beginCurrentReplanPlacement() {
        let defaultDay = defaultReplanPlacementDay()
        guard let phase = needsReplanViewModel.phaseForBeginningPlacement(defaultDay: defaultDay) else { return }
        selectDate(defaultDay, source: .replan)
        updateReplanState(phase: phase)
    }

    public func cancelCurrentReplanPlacement() {
        guard let phase = needsReplanViewModel.phaseForCancellingPlacement(currentPhase: homeReplanState.phase) else { return }
        updateReplanState(phase: phase)
    }
}
