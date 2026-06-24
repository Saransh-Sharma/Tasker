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
    public func rescheduleOverdueTasks(completion: (@Sendable (Result<RescheduleAllResult, Error>) -> Void)? = nil) {
        useCaseCoordinator.rescheduleAllOverdueTasks { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let rescheduleResult):
                    self?.loadTodayTasks()
                    completion?(.success(rescheduleResult))

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion?(.failure(error))
                }
            }
        }
    }

    public func evaFocusInsight(for taskID: UUID) -> EvaFocusTaskInsight? {
        evaHomeInsights?.focus.taskInsights.first(where: { $0.taskID == taskID })
    }

    public func setEvaFocusWhyPresented(_ value: Bool) {
        evaFocusWhySheetPresented = value
        if value == false {
            assignIfChanged(\.focusWhyShuffleCandidates, [])
        }
    }

    public func setEvaRescuePresented(_ value: Bool) {
        evaRescueSheetPresented = value
        if value == false, evaRescueLauncherState != .loading {
            evaRescueLauncherState = .idle
            evaRescueReferenceDate = nil
        }
    }

    public func openFocusWhy() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        refreshFocusWhyShuffleCandidates()
        evaFocusWhySheetPresented = true
        trackHomeInteraction(action: "focus_now_why_open", metadata: [:])
    }

    @discardableResult
    public func refreshFocusWhyShuffleCandidates() -> [TaskDefinition] {
        let candidates = computeFocusWhyShuffleCandidates()
        assignIfChanged(\.focusWhyShuffleCandidates, candidates)
        return candidates
    }

    func refreshFocusWhyCandidatesIfPresented() {
        guard evaFocusWhySheetPresented else { return }
        assignIfChanged(\.focusWhyShuffleCandidates, computeFocusWhyShuffleCandidates())
    }

    public func shuffleFocusNow() {
        guard V2FeatureFlags.evaFocusEnabled else { return }
        guard activeScope.quickView == .today else { return }
        guard activeScope.quickView != .done else { return }

        let openTasks = focusOpenTasksForCurrentState()
        guard openTasks.count > 1 else { return }
        let pinnedSet = Set(pinnedFocusTaskIDs)
        let candidates = openTasks.filter { !pinnedSet.contains($0.id) }
        guard candidates.isEmpty == false else { return }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        let autoFill = Array(ranked.prefix(max(0, Self.maxPinnedFocusTasks - pinnedFocusTaskIDs.count)))
        let pinned = pinnedFocusTaskIDs.compactMap { id in openTasks.first(where: { $0.id == id }) }
        let newSelection = Array((pinned + autoFill).prefix(Self.maxPinnedFocusTasks))
        guard newSelection.isEmpty == false else { return }

        updateFocusSelection(newSelection)
        for task in newSelection {
            recentShuffledFocusTaskIDs.append(task.id)
        }
        recentShuffledFocusTaskIDs = Array(recentShuffledFocusTaskIDs.suffix(Self.maxShuffleHistorySize))
        persistRecentShuffleTaskIDs()
        refreshEvaInsights()
        trackHomeInteraction(action: "focus_now_shuffle_tap", metadata: [
            "result_count": newSelection.count
        ])
    }

}
