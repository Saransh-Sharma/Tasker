import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    @MainActor
    func attachMemoryCandidate(proposedFrom userTurn: String, to messageID: UUID, threadID: UUID) async {
        guard let thread = thread(matching: threadID),
              let message = thread.messages.first(where: { $0.id == messageID }) else { return }
        if await EvaMemoryProposalService.attach(proposedFrom: userTurn, to: message, in: modelContext) {
            refreshTranscriptSnapshot(for: thread)
        }
    }

    /// Executes sendMessage.
    @MainActor
    @discardableResult
    func sendMessage(_ message: Message) -> ChatMessageSendOutcome {
        let contentType = AssistantCardCodec.isCard(message.content) ? "card" : "text"
        var preSanitizeLength = message.content.count
        var postSanitizeLength = message.content.count
        let threadID = message.thread?.id ?? currentThread?.id
        if message.role == .assistant && AssistantCardCodec.isCard(message.content) == false {
            preSanitizeLength = message.content.count
            let sanitizedText = EvaModelSelection.isCloud(message.sourceModelName)
                ? EvaCloudOutputNormalizer.normalize(message.content)
                : LLMChatTextSanitizer.sanitizeForDisplay(
                    message.content,
                    modelName: message.sourceModelName ?? appManager.currentModelName
                )
            let sanitizedResult = LLMChatTextSanitizer.Result(
                text: sanitizedText,
                removedReasoningBlocks: false,
                removedTemplateArtifacts: sanitizedText != message.content
            )
            postSanitizeLength = sanitizedResult.text.count
            logWarning(
                event: "chat_sendMessage_display_sanitize",
                message: "Sanitized assistant message for display persistence",
                fields: [
                    "role": "assistant",
                    "pre_sanitize_length": String(preSanitizeLength),
                    "post_sanitize_length": String(postSanitizeLength),
                    "removed_reasoning_blocks": sanitizedResult.removedReasoningBlocks ? "true" : "false",
                    "removed_template_artifacts": sanitizedResult.removedTemplateArtifacts ? "true" : "false"
                ]
            )
            guard sanitizedResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                let outcome = ChatMessageSendOutcome(
                    status: .emptySanitizedText,
                    messageID: message.id,
                    role: String(describing: message.role),
                    contentType: contentType,
                    preSanitizeLength: preSanitizeLength,
                    postSanitizeLength: postSanitizeLength,
                    threadID: threadID,
                    errorDescription: nil
                )
                logWarning(
                    event: "chat_sendMessage_display_dropped",
                    message: "Assistant message was dropped after display sanitization",
                    fields: [
                        "role": outcome.role,
                        "content_type": outcome.contentType,
                        "message_id": outcome.messageID.uuidString,
                        "thread_id": outcome.threadID?.uuidString ?? "nil",
                        "pre_sanitize_length": String(preSanitizeLength),
                        "post_sanitize_length": String(postSanitizeLength),
                        "save_result": outcome.status.rawValue
                    ]
                )
                return outcome
            }
            message.content = sanitizedResult.text
            postSanitizeLength = sanitizedResult.text.count
        }
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
            refreshTranscriptSnapshot(for: message.thread ?? currentThread)
            if isActivationPresentation,
               activationConfiguration?.showsCompletionObserver == true,
               let threadID = message.thread?.id ?? currentThread?.id {
                switch message.role {
                case .user:
                    onActivationChatEvent?(.userMessagePersisted(threadID: threadID))
                case .assistant:
                    onActivationChatEvent?(
                        .assistantReplyPersisted(
                            threadID: threadID,
                            countsForCompletion: assistantMessageCountsForActivationCompletion(message)
                        )
                    )
                case .system:
                    break
                }
            }
            let outcome = ChatMessageSendOutcome(
                status: .persisted,
                messageID: message.id,
                role: String(describing: message.role),
                contentType: contentType,
                preSanitizeLength: preSanitizeLength,
                postSanitizeLength: postSanitizeLength,
                threadID: threadID,
                errorDescription: nil
            )
            logWarning(
                event: "chat_sendMessage_completed",
                message: "Chat message persistence completed",
                fields: [
                    "role": outcome.role,
                    "content_type": outcome.contentType,
                    "message_id": outcome.messageID.uuidString,
                    "thread_id": outcome.threadID?.uuidString ?? "nil",
                    "pre_sanitize_length": String(outcome.preSanitizeLength),
                    "post_sanitize_length": String(outcome.postSanitizeLength),
                    "save_result": outcome.status.rawValue
                ]
            )
            return outcome
        } catch {
            let outcome = ChatMessageSendOutcome(
                status: .saveFailed,
                messageID: message.id,
                role: String(describing: message.role),
                contentType: contentType,
                preSanitizeLength: preSanitizeLength,
                postSanitizeLength: postSanitizeLength,
                threadID: threadID,
                errorDescription: error.localizedDescription
            )
            logError(
                event: "chat_message_save_failed",
                message: "Failed to save chat message",
                fields: [
                    "role": outcome.role,
                    "content_type": outcome.contentType,
                    "message_id": outcome.messageID.uuidString,
                    "thread_id": outcome.threadID?.uuidString ?? "nil",
                    "pre_sanitize_length": String(outcome.preSanitizeLength),
                    "post_sanitize_length": String(outcome.postSanitizeLength),
                    "save_result": outcome.status.rawValue,
                    "error": error.localizedDescription
                ]
            )
            return outcome
        }
    }

    func assistantMessageCountsForActivationCompletion(_ message: Message) -> Bool {
        guard message.role == .assistant else { return false }
        guard let payload = AssistantCardCodec.decode(from: message.content) else {
            return true
        }
        return payload.cardType == .commandResult
    }

}

// MARK: - Context invalidation and transcript snapshot
