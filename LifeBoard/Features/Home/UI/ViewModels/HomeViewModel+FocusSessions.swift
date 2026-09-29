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

/// The canonical focus command state machine is the only writer. The legacy
/// `FocusSessionUseCase` (UserDefaults-backed timer, gamification writes on
/// end) was deleted once `phase1ExecutionFlagshipEnabled` was promoted; these
/// wrappers keep the presentation model Home's older callers still read.
public struct FocusSessionResult: Sendable {
    public let session: FocusSessionDefinition
    public let xpResult: XPEventResult?
}

public enum FocusSessionError: Error, Sendable {
    case sessionNotFound
    case alreadyActive
    /// The composition root has not installed `FocusSessionCommands` yet.
    case commandsUnavailable
}

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
        Task {
            do {
                guard let canonicalFocusCommands else { throw FocusSessionError.commandsUnavailable }
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
    }

    /// Starts focus in any mode — a Pomodoro preset, not only a countdown —
    /// and returns the canonical session id. Presets from Siri and Control
    /// Center arrive here.
    public func startFocusSession(mode: FocusMode, taskID: UUID? = nil) async throws -> UUID {
        HomeSessionContextStore.recordFocusStart(taskID: taskID)
        guard let canonicalFocusCommands else { throw FocusSessionError.commandsUnavailable }
        do {
            let recovery = try await canonicalFocusCommands.start(.init(taskID: taskID, mode: mode))
            return recovery.session.id
        } catch FocusSessionCommandError.alreadyActive {
            throw FocusSessionError.alreadyActive
        }
    }

    public func endFocusSession(
        sessionID: UUID,
        completion: @escaping @Sendable (Result<FocusSessionResult, Error>) -> Void
    ) {
        Task {
            do {
                guard let canonicalFocusCommands else { throw FocusSessionError.commandsUnavailable }
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
    }

    public func fetchActiveFocusSession(
        completion: @escaping @Sendable (Result<FocusSessionDefinition?, Error>) -> Void
    ) {
        Task {
            do {
                guard let canonicalFocusCommands else { throw FocusSessionError.commandsUnavailable }
                let recovery = try await canonicalFocusCommands.activeRecovery()
                completion(.success(recovery.map { Self.legacyFocusSession(from: $0.session) }))
            } catch {
                completion(.failure(error))
            }
        }
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
