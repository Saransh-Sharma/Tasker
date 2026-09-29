import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    @MainActor
    func ensureCurrentThread() -> Thread? {
        if currentThread == nil {
            let newThread = Thread()
            currentThread = newThread
            modelContext.insert(newThread)
            do {
                try modelContext.save()
                refreshTranscriptSnapshot(for: newThread)
                if isActivationPresentation {
                    onActivationChatEvent?(.threadAttached(newThread.id))
                }
            } catch {
                logError(
                    event: "chat_thread_save_failed",
                    message: "Failed to save chat thread",
                    fields: ["error": error.localizedDescription]
                )
                return nil
            }
        }
        return currentThread
    }

    @MainActor
    func thread(matching threadID: UUID) -> Thread? {
        if currentThread?.id == threadID {
            return currentThread
        }
        var descriptor = FetchDescriptor<Thread>(
            predicate: #Predicate<Thread> { thread in
                thread.id == threadID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    func sendMessage(
        role: Role,
        content: String,
        threadID: UUID,
        generatingTime: TimeInterval? = nil,
        sourceModelName: String? = nil,
        contextReceiptData: Data? = nil
    ) -> ChatMessageSendOutcome {
        guard let thread = thread(matching: threadID) else {
            logWarning(
                event: "chat_thread_resolve_failed",
                message: "Could not resolve chat thread for message persistence",
                fields: ["thread_id": threadID.uuidString]
            )
            return ChatMessageSendOutcome(
                status: .saveFailed,
                messageID: UUID(),
                role: String(describing: role),
                contentType: AssistantCardCodec.isCard(content) ? "card" : "text",
                preSanitizeLength: content.count,
                postSanitizeLength: content.count,
                threadID: threadID,
                errorDescription: "Could not resolve chat thread"
            )
        }
        return sendMessage(
            Message(
                role: role,
                content: content,
                thread: thread,
                generatingTime: generatingTime,
                sourceModelName: sourceModelName,
                contextReceiptData: contextReceiptData
            )
        )
    }
}
