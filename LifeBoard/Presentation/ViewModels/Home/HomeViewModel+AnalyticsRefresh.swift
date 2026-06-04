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
    func scheduleInitialDeferredAnalyticsRefreshIfNeeded() {
        guard activeScope.quickView == .today else { return }
        scheduleDeferredAnalyticsRefresh(
            reason: "initial_load",
            includeGamificationRefresh: true,
            delayMilliseconds: 1_500
        )
    }

    /// Executes loadDailyAnalytics.

    func loadDailyAnalytics(
        includeGamificationRefresh: Bool = true,
        completion: (@Sendable () -> Void)? = nil
    ) {
        pendingAnalyticsIncludeGamificationRefresh = pendingAnalyticsIncludeGamificationRefresh || includeGamificationRefresh
        if let completion {
            pendingAnalyticsCompletions.append(completion)
        }
        pendingAnalyticsTask?.cancel()

        let delay = Duration.milliseconds(analyticsDebounceMS)
        pendingAnalyticsTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self else { return }
            let shouldIncludeGamificationRefresh = self.pendingAnalyticsIncludeGamificationRefresh
            let completions = self.pendingAnalyticsCompletions
            self.pendingAnalyticsIncludeGamificationRefresh = false
            self.pendingAnalyticsCompletions = []
            self.pendingAnalyticsTask = nil
            self.performDailyAnalyticsRefresh(
                includeGamificationRefresh: shouldIncludeGamificationRefresh,
                completions: completions
            )
        }
    }

    func scheduleDeferredAnalyticsRefresh(
        reason: String,
        includeGamificationRefresh: Bool,
        delayMilliseconds: Int = 450
    ) {
        pendingDeferredAnalyticsRefreshTask?.cancel()
        let delay = Duration.milliseconds(delayMilliseconds)
        pendingDeferredAnalyticsRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self else { return }
            self.pendingDeferredAnalyticsRefreshTask = nil
            let interval = LifeBoardPerformanceTrace.begin("HomeDeferredAnalyticsRefresh")
            self.loadDailyAnalytics(includeGamificationRefresh: includeGamificationRefresh) {
                LifeBoardPerformanceTrace.end(interval)
                logWarning(
                    event: "home_deferred_analytics_refresh",
                    message: "Deferred analytics refresh completed",
                    fields: [
                        "reason": reason,
                        "include_gamification_refresh": includeGamificationRefresh ? "true" : "false"
                    ]
                )
            }
        }
    }
}
