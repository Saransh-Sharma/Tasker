//
//  HomeViewController+Testing.swift
//  LifeBoard
//
//  Move-only HomeViewController DEBUG support.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData

#if DEBUG
extension HomeViewController {
    func testingSetAnalyticsVisible(with insightsViewModel: InsightsViewModel?) {
        self.insightsViewModel = insightsViewModel
        faceCoordinator.insightsViewModel = insightsViewModel
        faceCoordinator.setActiveFace(.analytics)
        faceCoordinator.setAnalyticsSurfaceState(insightsViewModel == nil ? .placeholder : .ready)
    }

    func testingHandleInsightsLaunchRequest(_ request: InsightsLaunchRequest?) {
        handleInsightsLaunchRequest(request)
    }

    var testingPendingInsightsLaunchRequest: InsightsLaunchRequest? {
        pendingInsightsLaunchRequest
    }

    func testingSetPendingOnboardingEvaluationTask() {
        pendingOnboardingEvaluationTask = Task {}
    }

    var testingHasPendingOnboardingEvaluationTask: Bool {
        pendingOnboardingEvaluationTask != nil
    }

    func testingSetOnboardingEvaluationSceneToken(_ token: Int) {
        onboardingEvaluationSceneToken = token
    }
}
#endif
