//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension SunriseAppShellView {
    func pinFocusTask(_ task: TaskDefinition) {
        let result = viewModel.pinTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "focus_strip_pin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .pinned:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_pin", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
        case .capacityReached(let limit):
            LifeBoardFeedback.light()
            metadata["limit"] = limit
            viewModel.trackHomeInteraction(action: "home_focus_pin_rejected_capacity", metadata: metadata)
        case .taskIneligible:
            LifeBoardFeedback.selection()
        }
    }

    func promoteAgendaTaskToFocus(_ task: TaskDefinition) {
        let result = viewModel.promoteTaskToFocus(task.id)
        var metadata = focusScopeMetadata(source: "today_agenda_promote", taskID: task.id)
        metadata["visible_count"] = viewModel.focusNowSectionState.visibleCount
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

        switch result {
        case .promoted:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_promote", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_pinned", metadata: metadata)
        case .alreadyVisible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_already_visible", metadata: metadata)
        case .replacementRequired(let currentFocusTaskIDs):
            pendingFocusPromotionTask = task
            focusReplacementOptions = currentFocusTaskIDs.compactMap(viewModel.taskSnapshot(for:))
            LifeBoardFeedback.light()
            metadata["replacement_count"] = focusReplacementOptions.count
            viewModel.trackHomeInteraction(action: "home_focus_promote_replace_prompt", metadata: metadata)
        case .taskIneligible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_promote_rejected_ineligible", metadata: metadata)
        }
    }

    func replaceFocusTask(
        _ promotedTask: TaskDefinition,
        replacing focusTask: TaskDefinition,
        source: String
    ) {
        let result = viewModel.replaceFocusTask(with: promotedTask.id, replacing: focusTask.id)
        var metadata = focusScopeMetadata(source: source, taskID: promotedTask.id)
        metadata["replaced_task_id"] = focusTask.id.uuidString

        switch result {
        case .promoted:
            LifeBoardFeedback.success()
            viewModel.trackHomeInteraction(action: "home_focus_replace", metadata: metadata)
        case .alreadyVisible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_visible", metadata: metadata)
        case .alreadyPinned:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_already_pinned", metadata: metadata)
        case .replacementRequired:
            LifeBoardFeedback.light()
        case .taskIneligible:
            LifeBoardFeedback.selection()
            viewModel.trackHomeInteraction(action: "home_focus_replace_rejected_ineligible", metadata: metadata)
        }

        clearPendingFocusReplacement()
    }

    func clearPendingFocusReplacement() {
        pendingFocusPromotionTask = nil
        focusReplacementOptions = []
    }

    func refreshFocusWhyShuffleCandidates() {
        _ = viewModel.refreshFocusWhyShuffleCandidates()
        LifeBoardFeedback.selection()
    }

    func replaceFocusTaskFromWhySheet(_ candidate: TaskDefinition, replacing focusTask: TaskDefinition) {
        replaceFocusTask(candidate, replacing: focusTask, source: "focus_why_replace")
        _ = viewModel.refreshFocusWhyShuffleCandidates()
    }

    /// Executes unpinFocusTask.

    func unpinFocusTask(_ task: TaskDefinition) {
        guard viewModel.pinnedFocusTaskIDs.contains(task.id) else { return }
        viewModel.unpinTaskFromFocus(task.id)
        LifeBoardFeedback.selection()

        var metadata = focusScopeMetadata(source: "focus_strip_unpin", taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(action: "home_focus_unpin", metadata: metadata)
    }

    /// Executes handleFocusDrop.

    func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                LifeBoardFeedback.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                LifeBoardFeedback.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                LifeBoardFeedback.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                LifeBoardFeedback.selection()
            }
        }
    }

    /// Executes handleListDrop.

    func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            LifeBoardFeedback.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

    /// Executes loadTaskIDFromDrop.

    func focusScopeMetadata(source: String, taskID: UUID) -> [String: Any] {
        [
            "source": source,
            "task_id": taskID.uuidString,
            "quick_view": viewModel.activeScope.quickView.analyticsAction,
            "scope": scopeAnalyticsName
        ]
    }

    var scopeAnalyticsName: String {
        switch viewModel.activeScope {
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

    var momentumGuidanceText: String {
        chromeSnapshot.momentumGuidanceText
    }

    func handleXPResult(_ result: XPEventResult?) {
        guard let result else { return }

        if result.awardedXP >= 7 {
            LifeBoardFeedback.success()
        } else if result.awardedXP >= 4 {
            LifeBoardFeedback.medium()
        } else {
            LifeBoardFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_progress_feedback",
            metadata: ["delta": result.awardedXP, "new_score": viewModel.dailyScore]
        )
    }

    func toggleInsights(source: String) {
        let shouldOpenInsights = activeFace != .analytics
        if shouldOpenInsights {
            openAnalytics(source: source, launchDefaultInsights: true)
        } else {
            closeAnalytics(source: source)
        }
    }

    func setActiveFace(_ face: HomeSunriseFace, animated: Bool) {
        if animated {
            withAnimation(sunriseFlipAnimation) {
                faceCoordinator.setActiveFace(face)
            }
        } else {
            faceCoordinator.setActiveFace(face)
        }
    }

    func openAnalytics(source: String, launchDefaultInsights: Bool) {
        onOpenAnalytics(source, launchDefaultInsights)
    }

    func closeAnalytics(source: String) {
        onCloseAnalytics(source)
    }

    func toggleSearch(source: String) {
        let shouldOpenSearch = activeFace != .search
        if shouldOpenSearch {
            openSearch(source: source)
        } else {
            closeSearch(source: source)
        }
    }

    func openSearch(source: String) {
        onOpenSearch(source)
    }

    var taskListScrollResetKey: String {
        switch chromeSnapshot.activeScope {
        case .today:
            return "today"
        case .customDate(let date):
            return "customDate-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
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

    func closeSearch(source: String) {
        onCloseSearch(source)
    }

    func returnToTasks(source: String) {
        onReturnToTasks(source)
    }

    func performInsightAction(_ intent: InsightsActionIntent) {
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "insights_cta_tap",
            metadata: ["intent": intent.telemetryName]
        )

        switch intent {
        case .addTask:
            onAddTask(nil)

        case .openToday:
            viewModel.setQuickView(.today)
            returnToTasks(source: "insights_open_today")

        case .startNextDecision:
            viewModel.setQuickView(.today)
            returnToTasks(source: "insights_next_decision")
            DispatchQueue.main.async {
                viewModel.startNextDecision(scope: .visible)
            }

        case .protectFocus:
            performInsightsFocusAction()

        case .openYesterdayReview:
            openDailyReflectPlan(preferredReflectionDate: yesterdayDate())

        case .openHabitCheck:
            showHabitBoardPresented = true
            LifeBoardFeedback.success()

        case .openBacklogRecovery:
            viewModel.setQuickView(.overdue)
            returnToTasks(source: "insights_backlog_recovery")
            DispatchQueue.main.async {
                viewModel.openRescue()
            }

        case .openProjectMix:
            onOpenProjectCreator()

        case .openWeeklyReview:
            onOpenWeeklyReview()

        case .openWeeklyPlanner:
            onOpenWeeklyPlanner()

        case .openReminderSettings:
            snackbar = SnackbarData(
                message: "Opening Notifications & Focus settings.",
                autoDismissSeconds: 2
            )
            returnToTasks(source: "insights_reminder_settings")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onOpenSettings()
            }

        case .expandDetails:
            break
        }
    }

    func performInsightsFocusAction() {
        let hasFocusCandidates = tasksSnapshot.focusNowSectionState.rows.isEmpty == false
            || viewModel.focusTasks.isEmpty == false
        if V2FeatureFlags.evaFocusEnabled, hasFocusCandidates {
            viewModel.openFocusWhy()
            LifeBoardFeedback.success()
            return
        }

        snackbar = SnackbarData(
            message: "Starting a short protected focus block.",
            autoDismissSeconds: 2
        )
        startNextActionFocusTimer()
    }

    func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: chromeSnapshot.selectedDate) ?? Date().addingTimeInterval(-86_400)
    }

    func trackSearchFlipOpen(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_open",
            metadata: ["source": source]
        )
    }

    func trackSearchFlipClose(source: String) {
        viewModel.trackHomeInteraction(
            action: "home_search_flip_close",
            metadata: ["source": source]
        )
    }

    func playHabitMutationFeedbackHaptic(_ haptic: HomeHabitMutationFeedbackHaptic) {
        switch haptic {
        case .selection:
            LifeBoardFeedback.selection()
        case .success:
            LifeBoardFeedback.success()
        case .warning:
            LifeBoardFeedback.warning()
        }
    }
}
