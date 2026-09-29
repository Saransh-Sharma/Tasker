import Foundation
import MLXLMCommon

struct LLMGenerationRequestOptions: Sendable {
    enum ChatMode: Sendable {
        case answerOnly
        case thinkingThenAnswer
    }

    let allowThinking: Bool
    let templateContext: [String: any Sendable]
    let effectiveModelType: ModelConfiguration.ModelType
    let chatMode: ChatMode
    let thinkingFormat: ModelConfiguration.ThinkingFormat

    var isReasoningEnabled: Bool {
        effectiveModelType == .reasoning && allowThinking
    }

    var showsVisibleThinking: Bool {
        chatMode == .thinkingThenAnswer
    }

    static func structuredOutput(for model: ModelConfiguration) -> Self {
        Self(
            allowThinking: false,
            templateContext: model.supportsThinkingToggleInTemplateContext
                ? ["enable_thinking": false]
                : [:],
            effectiveModelType: .regular,
            chatMode: .answerOnly,
            thinkingFormat: .none
        )
    }

    static func reasoningEnabled(for model: ModelConfiguration) -> Self {
        Self(
            allowThinking: model.modelType == .reasoning,
            templateContext: [:],
            effectiveModelType: model.modelType,
            chatMode: model.supportsVisibleThinking ? .thinkingThenAnswer : .answerOnly,
            thinkingFormat: model.thinkingFormat
        )
    }

    static func interactiveChat(for model: ModelConfiguration) -> Self {
        let shouldShowThinking = model.supportsVisibleThinking
        let shouldDisableThinking = shouldShowThinking == false && model.supportsThinkingToggleInTemplateContext
        return Self(
            allowThinking: shouldShowThinking,
            templateContext: shouldDisableThinking ? ["enable_thinking": false] : [:],
            effectiveModelType: shouldShowThinking ? model.modelType : .regular,
            chatMode: shouldShowThinking ? .thinkingThenAnswer : .answerOnly,
            thinkingFormat: shouldShowThinking ? model.thinkingFormat : .none
        )
    }

    static func answerCompletionRetry(for model: ModelConfiguration) -> Self {
        Self(
            allowThinking: false,
            templateContext: model.supportsThinkingToggleInTemplateContext
                ? ["enable_thinking": false]
                : [:],
            effectiveModelType: .regular,
            chatMode: .answerOnly,
            thinkingFormat: .none
        )
    }
}
