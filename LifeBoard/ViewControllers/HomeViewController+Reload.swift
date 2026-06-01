//
//  HomeViewController+Reload.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController: HomeReloadCoordinatorDelegate, HomeReloadEventAdapterDelegate {
    func homeReloadEventAdapter(
        _ adapter: HomeReloadEventAdapter,
        didReceive event: HomeReloadEvent
    ) {
        if case .appDidBecomeActive = event {
            onboardingEvaluationSceneToken &+= 1
            navigationCoordinator.handle(.pendingShortcutHandoff)
            scheduleOnboardingEvaluationIfNeeded()
        }
        reloadCoordinator.handle(event)
    }

    func homeReloadCoordinatorDidReceiveTaskMutation(_ mutation: HomeTaskMutationReloadEvent) {
        LifeBoardPerformanceTrace.event("HomeTaskMutationReloadEvent")
        if let reason = mutation.reason {
            logDebug("HOME_RELOAD_COORDINATOR mutation reason=\(reason.rawValue) source=\(mutation.source ?? "unknown")")
        }
    }

    func homeReloadCoordinatorRecordSearchMutation() {
        faceCoordinator.recordSearchMutation()
    }

    func homeReloadCoordinatorRefreshInsights(reason: HomeTaskMutationEvent?) {
        refreshInsightsAfterTaskMutation(reason: reason)
    }

    func homeReloadCoordinatorRefreshPersistentSyncMode() {
        refreshPersistentSyncOutageBanner()
    }

    func homeReloadCoordinatorRefreshWeeklySummary() {
        viewModel?.refreshWeeklySummaryNow()
    }

    func homeReloadCoordinatorRefreshCalendarContext(reason: String) {
        presentationDependencyContainer?.coordinator.calendarIntegrationService.refreshContext(reason: reason)
    }
}
