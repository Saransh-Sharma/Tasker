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
    func computeFocusWhyShuffleCandidates() -> [TaskDefinition] {
        guard V2FeatureFlags.evaFocusEnabled else { return [] }
        guard activeScope.quickView == .today else { return [] }

        let openTasks = uniqueTasks(focusOpenTasksForCurrentState() + latestFocusOpenTasks)
            .filter { task in
                task.isComplete == false && completionOverrides[task.id] != true
            }
        let visibleFocusTasks = focusTasks
            .filter { task in
                task.isComplete == false && completionOverrides[task.id] != true
            }
        let effectiveFocusTasks = visibleFocusTasks.isEmpty
            ? composedFocusTasks(from: openTasks)
            : visibleFocusTasks
        let currentFocusIDs = Set(effectiveFocusTasks.prefix(Self.maxPinnedFocusTasks).map(\.id))
        guard currentFocusIDs.isEmpty == false else { return [] }

        let candidates = openTasks.filter { !currentFocusIDs.contains($0.id) }
        guard candidates.isEmpty == false else { return [] }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        return Array(ranked.prefix(Self.maxPinnedFocusTasks))
    }

    func focusPriority(for row: HomeTodayRow) -> Int {
        switch row {
        case .task(let task):
            if task.isOverdue { return 0 }
            if task.priority.isHighPriority, task.dueDate != nil { return 3 }
            return 5

        case .habit(let habit):
            if habit.state == .overdue { return 1 }
            if habit.kind == .negative, habit.riskState == .atRisk { return 2 }
            return 4
        }
    }

}
