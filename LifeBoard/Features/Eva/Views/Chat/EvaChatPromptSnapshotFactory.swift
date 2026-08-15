import Foundation
import MLXLMCommon

enum EvaChatPromptSnapshotFactory {
    @MainActor
    static func make(
        threadID: UUID,
        resolveThread: (UUID) -> Thread?,
        model: ModelConfiguration,
        systemPrompt: String,
        cloudContext: [EvaCloudContextSection]
    ) -> LLMChatPromptSnapshot? {
        guard let thread = resolveThread(threadID) else {
            logWarning(
                event: "chat_thread_resolve_failed",
                message: "Could not resolve chat thread for prompt snapshot",
                fields: ["thread_id": threadID.uuidString]
            )
            return nil
        }
        let startedAt = Date()
        return LLMChatPromptSnapshot(
            messages: model.getChatMessages(thread: thread, systemPrompt: systemPrompt),
            systemPromptCharacterCount: systemPrompt.count,
            buildDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            cloudContext: cloudContext
        )
    }
}
