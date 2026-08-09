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
    func performDailyAnalyticsRefresh(
        includeGamificationRefresh: Bool,
        completions: [@Sendable () -> Void]
    ) {
        let generation = nextAnalyticsGeneration()
        let completionGroup = DispatchGroup()
        if V2FeatureFlags.gamificationV2Enabled {
            guard includeGamificationRefresh else {
                completionGroup.enter()
                useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
                    for: Date(),
                    habitSignals: self.currentHabitSignals
                ) { [weak self] _ in
                    Task { @MainActor in
                        defer { completionGroup.leave() }
                        guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    }
                }
                completionGroup.notify(queue: .main) {
                    completions.forEach { $0() }
                }
                return
            }
            let engine = useCaseCoordinator.gamificationEngine

            completionGroup.enter()
            engine.fetchTodayXP { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let todayXP) = result {
                        self.dailyScore = todayXP
                        self.refreshProgressState()
                    }
                }
            }

            completionGroup.enter()
            engine.fetchCurrentProfile { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let profile) = result {
                        self.currentLevel = profile.level
                        self.totalXP = profile.xpTotal
                        self.nextLevelXP = profile.nextLevelXP
                        self.streak = profile.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        } else {
            completionGroup.enter()
            refreshDailyScoreFromCompletedTasksToday(generation: generation) {
                completionGroup.leave()
            }
        }

        completionGroup.enter()
        useCaseCoordinator.calculateAnalytics.calculateDailyAnalytics(
            for: Date(),
            habitSignals: currentHabitSignals
        ) { [weak self] _ in
            Task { @MainActor in
                defer { completionGroup.leave() }
                guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
            }
        }

        if !V2FeatureFlags.gamificationV2Enabled {
            completionGroup.enter()
            useCaseCoordinator.calculateAnalytics.calculateStreak { [weak self] result in
                Task { @MainActor in
                    defer { completionGroup.leave() }
                    guard let self, self.isCurrentAnalyticsGeneration(generation) else { return }
                    if case .success(let streakInfo) = result {
                        self.streak = streakInfo.currentStreak
                        self.refreshProgressState()
                    }
                }
            }
        }

        completionGroup.notify(queue: .main) {
            completions.forEach { $0() }
        }
    }

    struct CanonicalHabitMutationState {
        let row: HomeHabitRow?
        let libraryRow: HabitLibraryRow?
    }

}
