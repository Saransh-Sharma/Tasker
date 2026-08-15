import Foundation
import MLXLMCommon

struct EvaChatRetryPrompt {
    let snapshot: LLMChatPromptSnapshot
    let profile: LLMGenerationProfile
    let requestOptions: LLMGenerationRequestOptions
}

enum EvaChatRetryPromptFactory {
    static func make(
        userMessage: String,
        seedContent: String,
        sourceModelName: String,
        model: ModelConfiguration,
        systemPrompt: String
    ) -> EvaChatRetryPrompt {
        let thread = Thread()
        thread.messages = [
            Message(role: .user, content: userMessage, thread: thread),
            Message(
                role: .assistant,
                content: seedContent,
                thread: thread,
                sourceModelName: sourceModelName
            ),
            Message(
                role: .user,
                content: "Continue with only the final answer. Do not repeat the prior analysis, thinking, or bullets.",
                thread: thread
            )
        ]
        let options = LLMGenerationRequestOptions.answerCompletionRetry(for: model)
        let profile = LLMGenerationProfile.chatProfile(for: model, requestOptions: options)
        let startedAt = Date()
        let snapshot = LLMChatPromptSnapshot(
            messages: model.getChatMessages(thread: thread, systemPrompt: systemPrompt),
            systemPromptCharacterCount: systemPrompt.count,
            buildDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000)
        )
        return EvaChatRetryPrompt(snapshot: snapshot, profile: profile, requestOptions: options)
    }
}
