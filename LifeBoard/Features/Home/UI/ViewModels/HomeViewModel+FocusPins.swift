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
    /// Track Home interactions from view-layer events (animations, collapse toggles, etc.).
    public func trackHomeInteraction(action: String, metadata: [String: Any] = [:]) {
        trackFeatureUsage(action: action, metadata: metadata)
    }

    public var canUseManualFocusDrag: Bool {
        false
    }

    /// Executes pinTaskToFocus.

    public func pinTaskToFocus(_ taskID: UUID) -> FocusPinResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
            return .capacityReached(limit: Self.maxPinnedFocusTasks)
        }

        pinnedFocusTaskIDs.append(taskID)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        return .pinned
    }

    /// Executes unpinTaskFromFocus.

    public func unpinTaskFromFocus(_ taskID: UUID) {
        guard pinnedFocusTaskIDs.contains(taskID) else { return }
        pinnedFocusTaskIDs.removeAll { $0 == taskID }
        persistPinnedFocusTaskIDs()
        let openTasks = focusOpenTasksForCurrentState()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
    }

    public func promoteTaskToFocus(_ taskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        if pinnedFocusTaskIDs.contains(taskID) {
            return .alreadyPinned
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        if currentFocus.contains(where: { $0.id == taskID }) {
            if pinnedFocusTaskIDs.count >= Self.maxPinnedFocusTasks {
                return .alreadyVisible
            }

            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshTodayAgendaForCurrentFocusSelection()
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        if pinnedFocusTaskIDs.count < Self.maxPinnedFocusTasks {
            pinnedFocusTaskIDs.append(taskID)
            persistPinnedFocusTaskIDs()
            updateFocusSelection(composedFocusTasks(from: openTasks))
            refreshTodayAgendaForCurrentFocusSelection()
            refreshEvaInsights(openTasks: openTasks)
            return .promoted
        }

        return .replacementRequired(currentFocusTaskIDs: Array(currentFocus.prefix(Self.maxPinnedFocusTasks).map(\.id)))
    }

    public func replaceFocusTask(with taskID: UUID, replacing replacedTaskID: UUID) -> FocusPromotionResult {
        guard activeScope.quickView == .today else {
            return .taskIneligible
        }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.contains(where: { $0.id == taskID }) else {
            return .taskIneligible
        }

        let currentFocus = composedFocusTasks(from: openTasks)
        guard currentFocus.contains(where: { $0.id == replacedTaskID }) else {
            return .taskIneligible
        }

        if taskID == replacedTaskID {
            return .alreadyVisible
        }

        let curatedFocusIDs = [taskID] + currentFocus
            .map(\.id)
            .filter { $0 != taskID && $0 != replacedTaskID }
        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(curatedFocusIDs)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        return .promoted
    }

    public func commitFocusNowSet(taskIDs: [UUID], source: String) -> Bool {
        guard activeScope.quickView == .today else { return false }

        let openTasks = focusOpenTasksForCurrentState()
        let openByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        var seen = Set<UUID>()
        let committedIDs = Array(taskIDs.filter { id in
            openByID[id] != nil && seen.insert(id).inserted
        }.prefix(Self.maxPinnedFocusTasks))
        guard committedIDs.isEmpty == false else { return false }

        pinnedFocusTaskIDs = normalizedPinnedFocusTaskIDs(committedIDs)
        persistPinnedFocusTaskIDs()
        updateFocusSelection(composedFocusTasks(from: openTasks))
        refreshTodayAgendaForCurrentFocusSelection()
        refreshEvaInsights(openTasks: openTasks)
        reloadTaskListWidgetTimelines()
        trackHomeInteraction(action: "focus_now_set_committed", metadata: [
            "source": source,
            "focus_count": committedIDs.count
        ])
        return true
    }

}
