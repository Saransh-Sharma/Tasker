//
//  ChatGenerationCancellationPolicy.swift
//

import Foundation

enum ChatGenerationCancellationReason: String, Sendable {
    case stopButton = "stop_button"
    case chatViewDisappear = "chat_view_disappear"
    case threadChanged = "thread_changed"
    case clearThread = "clear_thread"
    case startNewChat = "start_new_chat"
    case supersededByNewGeneration = "superseded_by_new_generation"
}

struct ChatGenerationCancellationSnapshot: Equatable, Sendable {
    let generationRunID: UUID?
    let generatingThreadID: UUID?
    let currentThreadID: UUID?
    let hasGenerationTask: Bool
    let hasSlashCommandTask: Bool
    let evaluatorIsRunning: Bool
    let evaluatorRuntimePhaseRequiresCancellation: Bool
}

struct ChatGenerationCancellationDecision: Equatable, Sendable {
    let reason: ChatGenerationCancellationReason
    let shouldLog: Bool
    let shouldCancelEvaluator: Bool
    let shouldRestoreSubmittedDraft: Bool
    let cancelledRunID: UUID?
    let logThreadID: UUID?
    let hadGenerationTask: Bool
    let hadSlashCommandTask: Bool
}

enum ChatGenerationCancellationPolicy {
    enum ThreadChangeDecision: Equatable, Sendable {
        case ignore
        case preserveFirstGeneratedThreadAttach
        case cancel
    }

    static func decision(
        oldThreadID: UUID?,
        newThreadID: UUID?,
        generatingThreadID: UUID?,
        hasActiveGeneration: Bool
    ) -> ThreadChangeDecision {
        guard hasActiveGeneration else { return .ignore }
        guard oldThreadID != newThreadID else { return .ignore }
        if oldThreadID == nil, newThreadID == generatingThreadID {
            return .preserveFirstGeneratedThreadAttach
        }
        return .cancel
    }

    static func shouldCancelActiveGeneration(
        oldThreadID: UUID?,
        newThreadID: UUID?,
        generatingThreadID: UUID?,
        hasActiveGeneration: Bool
    ) -> Bool {
        decision(
            oldThreadID: oldThreadID,
            newThreadID: newThreadID,
            generatingThreadID: generatingThreadID,
            hasActiveGeneration: hasActiveGeneration
        ) == .cancel
    }

    static func generationDecision(
        reason: ChatGenerationCancellationReason,
        snapshot: ChatGenerationCancellationSnapshot
    ) -> ChatGenerationCancellationDecision {
        let shouldCancelEvaluator = snapshot.evaluatorIsRunning ||
            snapshot.evaluatorRuntimePhaseRequiresCancellation
        let shouldLog = snapshot.hasGenerationTask ||
            snapshot.hasSlashCommandTask ||
            shouldCancelEvaluator

        return ChatGenerationCancellationDecision(
            reason: reason,
            shouldLog: shouldLog,
            shouldCancelEvaluator: shouldCancelEvaluator,
            shouldRestoreSubmittedDraft: reason == .stopButton || reason == .chatViewDisappear,
            cancelledRunID: snapshot.generationRunID,
            logThreadID: snapshot.generatingThreadID ?? snapshot.currentThreadID,
            hadGenerationTask: snapshot.hasGenerationTask,
            hadSlashCommandTask: snapshot.hasSlashCommandTask
        )
    }
}
