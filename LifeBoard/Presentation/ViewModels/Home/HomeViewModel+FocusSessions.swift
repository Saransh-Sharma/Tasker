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
    public func configureCanonicalFocusCommands(_ commands: FocusSessionCommands) {
        canonicalFocusCommands = commands
    }

    public func startFocusSession(
        taskID: UUID?,
        targetDurationSeconds: Int = 25 * 60,
        completion: @escaping @Sendable (Result<FocusSessionDefinition, Error>) -> Void
    ) {
        HomeSessionContextStore.recordFocusStart(taskID: taskID)
        if V2FeatureFlags.phase1ExecutionFlagshipEnabled, let canonicalFocusCommands {
            Task {
                do {
                    let recovery = try await canonicalFocusCommands.start(.init(
                        taskID: taskID,
                        mode: .countdown(duration: TimeInterval(targetDurationSeconds))
                    ))
                    completion(.success(Self.legacyFocusSession(from: recovery.session)))
                } catch FocusSessionCommandError.alreadyActive {
                    completion(.failure(FocusSessionError.alreadyActive))
                } catch {
                    completion(.failure(error))
                }
            }
            return
        }
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
        if V2FeatureFlags.phase1ExecutionFlagshipEnabled, let canonicalFocusCommands {
            Task {
                do {
                    let receipt = try await canonicalFocusCommands.end(
                        sessionID: sessionID,
                        outcome: .completed
                    )
                    let session = FocusSessionDefinition(
                        id: receipt.sessionID,
                        taskID: receipt.taskID,
                        startedAt: receipt.startedAt,
                        endedAt: receipt.endedAt,
                        durationSeconds: Int(receipt.actualFocusedDuration.rounded()),
                        targetDurationSeconds: Int(receipt.targetDuration.rounded()),
                        wasCompleted: receipt.outcome == .completed,
                        xpAwarded: 0
                    )
                    loadDailyAnalytics(includeGamificationRefresh: false)
                    completion(.success(.init(session: session, xpResult: nil)))
                } catch {
                    completion(.failure(error))
                }
            }
            return
        }
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
        if V2FeatureFlags.phase1ExecutionFlagshipEnabled, let canonicalFocusCommands {
            Task {
                do {
                    let recovery = try await canonicalFocusCommands.activeRecovery()
                    completion(.success(recovery.map { Self.legacyFocusSession(from: $0.session) }))
                } catch {
                    completion(.failure(error))
                }
            }
            return
        }
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
        invalidateDayCompassReflectionTargetCache()
        refreshWeeklySummary()
        loadDailyAnalytics(includeGamificationRefresh: false)
        selectDate(planningDate, source: .dailyReflection)
    }

    private static func legacyFocusSession(from session: FocusSessionV2) -> FocusSessionDefinition {
        let duration = Int(session.focusedDuration(at: session.endedAt ?? Date()).rounded())
        return FocusSessionDefinition(
            id: session.id,
            taskID: session.taskID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: duration,
            targetDurationSeconds: Int(session.targetDuration.rounded()),
            wasCompleted: session.outcome == .completed,
            xpAwarded: 0
        )
    }

}
