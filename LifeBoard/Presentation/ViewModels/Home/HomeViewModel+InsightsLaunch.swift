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
    public func launchInsights(_ request: InsightsLaunchRequest = .default) {
        let resolved = InsightsLaunchRequest(
            targetTab: request.targetTab,
            highlightedAchievementKey: request.highlightedAchievementKey
        )
        insightsLaunchRequest = resolved
        insightsLaunchToken = resolved.token
        trackHomeInteraction(
            action: "insights_launch_requested",
            metadata: [
                "target_tab": resolved.targetTab.rawValue.lowercased(),
                "has_highlighted_achievement": resolved.highlightedAchievementKey == nil ? "false" : "true"
            ]
        )
    }

    public func dispatchCelebration(_ result: XPEventResult?) {
        guard let result else { return }
        lastXPResult = result
    }

    public func makeInsightsViewModel() -> InsightsViewModel {
        if let retainedInsightsViewModel {
            return retainedInsightsViewModel
        }

        let resolvedViewModel = InsightsViewModel(
            engine: useCaseCoordinator.gamificationEngine,
            repository: useCaseCoordinator.gamificationRepository,
            taskReadModelRepository: useCaseCoordinator.taskReadModelRepository,
            reminderRepository: useCaseCoordinator.reminderRepository,
            analyticsUseCase: useCaseCoordinator.calculateAnalytics,
            buildWeeklyPlanSnapshotUseCase: useCaseCoordinator.buildWeeklyPlanSnapshot,
            calculateWeeklyMomentumUseCase: useCaseCoordinator.calculateWeeklyMomentum,
            buildRecoveryInsightsUseCase: useCaseCoordinator.buildRecoveryInsights,
            weeklyReviewDraftStore: useCaseCoordinator.weeklyReviewDraftStore
        )
        retainedInsightsViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func makeHomeSearchViewModel() -> HomeSearchViewModel {
        if let retainedHomeSearchViewModel {
            return retainedHomeSearchViewModel
        }

        let resolvedViewModel = HomeSearchViewModel(useCaseCoordinator: useCaseCoordinator)
        retainedHomeSearchViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func releaseInsightsViewModel() {
        retainedInsightsViewModel = nil
    }

    func releaseHomeSearchViewModel() {
        retainedHomeSearchViewModel?.purgeCaches()
        retainedHomeSearchViewModel = nil
    }

}
