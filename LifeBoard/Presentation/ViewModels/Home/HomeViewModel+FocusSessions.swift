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
    public func startFocusSession(
        taskID: UUID?,
        targetDurationSeconds: Int = 25 * 60,
        completion: @escaping @Sendable (Result<FocusSessionDefinition, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.startSession(
            taskID: taskID,
            targetDurationSeconds: targetDurationSeconds,
            completion: { result in
                Task { @MainActor in
                    completion(result)
                }
            }
        )
    }

    public func endFocusSession(
        sessionID: UUID,
        completion: @escaping @Sendable (Result<FocusSessionResult, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.endSession(sessionID: sessionID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let focusResult):
                    if focusResult.xpResult?.awardedXP ?? 0 > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "focus_session_end")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(focusResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func fetchActiveFocusSession(
        completion: @escaping @Sendable (Result<FocusSessionDefinition?, Error>) -> Void
    ) {
        useCaseCoordinator.focusSession.fetchActiveSession { result in
            Task { @MainActor in
                completion(result)
            }
        }
    }

    public func completeDailyReflection(
        completion: @escaping @Sendable (Result<XPEventResult, Error>) -> Void
    ) {
        useCaseCoordinator.markDailyReflection.execute { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let xpResult):
                    if xpResult.awardedXP > 0 {
                        self?.scheduleLedgerMutationWatchdog(trigger: "daily_reflection_complete")
                    }
                    self?.loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(xpResult))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    public func isDailyReflectionCompletedToday() -> Bool {
        useCaseCoordinator.markDailyReflection.isCompletedToday()
    }

    public func refreshAfterDailyReflectPlanSave(planningDate: Date) {
        refreshWeeklySummary()
        loadDailyAnalytics(includeGamificationRefresh: false)
        selectDate(planningDate, source: .dailyReflection)
    }

}
