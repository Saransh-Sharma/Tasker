import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    @MainActor
    func rememberEvaSubmittedDraft(_ text: String, runID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        evaSubmittedDraft = EvaSubmittedDraft(runID: runID, text: text)
        logWarning(
            event: "eva_draft_preserved",
            message: "Preserved EVA prompt draft for active planner turn",
            fields: [
                "run_id": runID.uuidString,
                "draft_chars": String(text.count)
            ]
        )
    }

    @MainActor
    func restoreEvaSubmittedDraftIfNeeded(runID: UUID?, reason: String) {
        guard let draft = evaSubmittedDraft else { return }
        if let runID, draft.runID != runID { return }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        prompt = draft.text
        logWarning(
            event: "eva_draft_restored",
            message: "Restored EVA prompt draft after interrupted planner turn",
            fields: [
                "run_id": draft.runID.uuidString,
                "reason": reason,
                "draft_chars": String(draft.text.count)
            ]
        )
    }

    @MainActor
    func clearEvaSubmittedDraft(runID: UUID?, reason: String) {
        guard let draft = evaSubmittedDraft else { return }
        if let runID, draft.runID != runID { return }
        evaSubmittedDraft = nil
        logWarning(
            event: "eva_draft_cleared",
            message: "Cleared EVA prompt draft after terminal planner outcome",
            fields: [
                "run_id": draft.runID.uuidString,
                "reason": reason
            ]
        )
    }

    @MainActor
    var evaluatorRuntimePhaseRequiresCancellation: Bool {
        llm.runtimePhase == .preparing ||
            llm.runtimePhase == .thinking ||
            llm.runtimePhase == .answering ||
            llm.runtimePhase == .stopping
    }

    @MainActor
    func cancellationSnapshot() -> ChatGenerationCancellationSnapshot {
        ChatGenerationCancellationSnapshot(
            generationRunID: generationRunID,
            generatingThreadID: generatingThreadID,
            currentThreadID: currentThread?.id,
            hasGenerationTask: generationTask != nil,
            hasSlashCommandTask: slashCommandTask != nil,
            evaluatorIsRunning: llm.running,
            evaluatorRuntimePhaseRequiresCancellation: evaluatorRuntimePhaseRequiresCancellation
        )
    }

    @MainActor
    func cancelActiveGeneration(reason: ChatGenerationCancellationReason) {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: reason,
            snapshot: cancellationSnapshot()
        )
        if decision.shouldLog {
            PerformanceTrace.event("ChatGenerationCancelled")
            logWarning(
                event: "chat_generation_cancelled",
                message: "Cancelled active chat generation or slash-command work",
                component: "ChatView",
                fields: [
                    "reason": decision.reason.rawValue,
                    "had_generation_task": decision.hadGenerationTask ? "true" : "false",
                    "had_slash_command_task": decision.hadSlashCommandTask ? "true" : "false",
                    "cancelled_evaluator": decision.shouldCancelEvaluator ? "true" : "false",
                    "run_id": decision.cancelledRunID?.uuidString ?? "none",
                    "thread_id": decision.logThreadID?.uuidString ?? "none"
                ]
            )
        }
        generationTask?.cancel()
        generationTask = nil
        slashCommandTask?.cancel()
        slashCommandTask = nil
        generationRunID = nil
        generatingThreadID = nil
        if let promptSubmitTraceInterval {
            PerformanceTrace.end(promptSubmitTraceInterval)
            self.promptSubmitTraceInterval = nil
        }
        pendingResponsePhase = .idle
        llm.isThinking = false
        if decision.shouldCancelEvaluator {
            llm.cancelGeneration(reason: decision.reason.rawValue)
            LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: decision.reason.rawValue)
        }
        if decision.shouldRestoreSubmittedDraft {
            restoreEvaSubmittedDraftIfNeeded(runID: decision.cancelledRunID, reason: decision.reason.rawValue)
        }
    }

    @MainActor
    func updatePendingResponsePhase(_ phase: ChatPendingResponsePhase, for runID: UUID) {
        guard generationRunID == runID else { return }
        if phase.isActive, let promptSubmitTraceInterval {
            PerformanceTrace.end(promptSubmitTraceInterval)
            self.promptSubmitTraceInterval = nil
            PerformanceTrace.event("ChatPromptStateTransition")
        }
        pendingResponsePhase = phase
    }

    @MainActor
    @discardableResult
    func deliverEvaPlanPayload(
        _ payload: EvaPlanResponsePayload,
        threadID: UUID,
        traceContext: EvaTurnTraceContext,
        usesModelGenerationForDeliveryGate: Bool
    ) -> EvaPlanResponseDeliveryResult {
        EvaPlanResponseDelivery.deliver(
            payload: payload,
            traceContext: traceContext,
            gateState: EvaPlanResponseDelivery.GateState(
                taskCancelled: Task.isCancelled,
                runIDMatches: generationRunID == traceContext.runID,
                evaluatorCancelled: llm.cancelled
            ),
            usesModelGenerationForDeliveryGate: usesModelGenerationForDeliveryGate,
            send: { payload in
                sendMessage(
                    role: .assistant,
                    content: payload.content,
                    threadID: threadID,
                    generatingTime: llm.thinkingTime,
                    sourceModelName: payload.sourceModelName
                )
            }
        )
    }

}

// MARK: - Message persistence

// MARK: - Edit and resend (E3)
extension ChatView {
    /// Puts the chosen user message back into the composer and removes it and
    /// everything after it, per `ChatEditResendPolicy`. The removed messages
    /// are kept as values until the receipt settles, so "Earlier replies
    /// removed · Undo" puts the thread back exactly as it was.
    @MainActor
    func applyEditResend(messageID: UUID) {
        guard let thread = currentThread else { return }
        let ordered = thread.sortedMessagesSnapshot()
        let snapshots = ordered.map { message in
            ChatMessageSnapshot(
                id: message.id,
                threadID: thread.id,
                role: ChatMessageSnapshot.Role(rawValue: message.role.rawValue) ?? .user,
                content: message.content,
                timestamp: message.timestamp
            )
        }
        guard let plan = ChatEditResendPolicy.plan(thread: snapshots, editedID: messageID),
              let edited = ordered.first(where: { $0.id == messageID }) else { return }
        let text = edited.content
        let removedIDs = Set(plan.removed.map(\.id))
        let removed = ordered.filter { removedIDs.contains($0.id) }.map(RemovedChatMessage.init)
        for message in ordered where removedIDs.contains(message.id) {
            modelContext.delete(message)
        }
        do {
            try modelContext.save()
        } catch {
            logError(
                event: "chat_edit_resend_save_failed",
                message: "Failed to save edit-and-resend rewrite",
                fields: ["error": error.localizedDescription]
            )
            commandFeedback = String(localized: "Couldn’t edit that message.")
            return
        }
        slashDraft = nil
        commandFeedback = nil
        prompt = text
        refreshTranscriptSnapshot(for: thread)
        isPromptFocused = true
        Haptic.pick.play()
        let context = modelContext
        EvaChatReceiptCenter.shared.show(.init(
            message: removed.count == 1 ? String(localized: "Message removed to edit") : String(localized: "Later messages removed"),
            detail: String(localized: "Final once you send."),
            undo: {
                for value in removed {
                    context.insert(value.restored(into: thread))
                }
                do {
                    try context.save()
                } catch {
                    return false
                }
                if prompt == text { prompt = "" }
                refreshTranscriptSnapshot(for: thread)
                return true
            }
        ))
    }
}

/// A message removed by edit-and-resend, held as a value so Undo can put it
/// back with the same identity and timestamps.
struct RemovedChatMessage {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    let generatingTime: TimeInterval?
    let sourceModelName: String?
    let contextReceiptData: Data?
    let memoryCandidateData: Data?

    init(_ message: Message) {
        id = message.id
        role = message.role
        content = message.content
        timestamp = message.timestamp
        generatingTime = message.generatingTime
        sourceModelName = message.sourceModelName
        contextReceiptData = message.contextReceiptData
        memoryCandidateData = message.memoryCandidateData
    }

    func restored(into thread: Thread) -> Message {
        let message = Message(
            role: role,
            content: content,
            thread: thread,
            generatingTime: generatingTime,
            sourceModelName: sourceModelName,
            contextReceiptData: contextReceiptData,
            memoryCandidateData: memoryCandidateData
        )
        message.id = id
        message.timestamp = timestamp
        return message
    }
}
