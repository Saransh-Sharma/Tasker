import Foundation
import MLXLMCommon

enum EvaChatPromptSnapshotFactory {
    @MainActor
    static func make(
        threadID: UUID,
        resolveThread: (UUID) -> Thread?,
        model: ModelConfiguration,
        systemPrompt: String,
        cloudContext: [EvaCloudContextSection],
        userInstructions: EvaUserInstructions? = nil,
        budget: EvaContextBudget? = nil
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
        let messages: [Chat.Message]
        let systemPromptCharacterCount: Int
        if let budget, budget.isCloud {
            // Cloud owns its developer prompt. Counting the large local system
            // prompt here used to evict useful conversation history and the
            // request builder then discarded that prompt before transmission.
            let contextTokens = cloudContext.reduce(0) { partial, section in
                partial + ((try? JSONEncoder.evaCloud.encode(section).count) ?? 0) / 4
            }
            let instructionTokens = userInstructions.map {
                LLMTokenBudgetEstimator.estimatedTokenCount(for: $0.persona + " " + ($0.tone ?? ""))
            } ?? 0
            let historyTokens = max(
                0,
                budget.inputTokens - budget.systemPromptTokens - contextTokens - instructionTokens - 256
            )
            messages = EvaCloudHistoryClipper.clip(
                thread.sortedMessages,
                maxMessages: budget.historyMessageLimit,
                maxTokens: historyTokens
            )
            systemPromptCharacterCount = 0
        } else {
            messages = model.getChatMessages(thread: thread, systemPrompt: systemPrompt)
            systemPromptCharacterCount = systemPrompt.count
        }
        return LLMChatPromptSnapshot(
            messages: messages,
            systemPromptCharacterCount: systemPromptCharacterCount,
            buildDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            cloudContext: cloudContext,
            userInstructions: userInstructions
        )
    }
}
