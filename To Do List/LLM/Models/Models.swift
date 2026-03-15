//
//  Models.swift
//
//

import Foundation
import MLXLMCommon

private enum LLMModelStopTokenRegistry {
    static let llama: Set<String> = [
        "<|eot_id|>"
    ]

    static let qwenStyle: Set<String> = [
        "<｜end▁of▁sentence｜>",
        "<|im_end|>"
    ]

}

struct LLMChatBudgets {
    let maxThreadMessages: Int
    let maxPromptChars: Int
    let maxContextChars: Int
    let maxProjectionTasksPerSlice: Int
    let projectionTimeoutMs: UInt64
    let contextCacheTTLms: UInt64
    let outputMinUpdateIntervalMs: UInt64
    let outputTokenStride: Int
    let includeRecapMessage: Bool

    static let bounded = LLMChatBudgets(
        maxThreadMessages: 6,
        maxPromptChars: 2_400,
        maxContextChars: 900,
        maxProjectionTasksPerSlice: 32,
        projectionTimeoutMs: 450,
        contextCacheTTLms: 2_000,
        outputMinUpdateIntervalMs: 100,
        outputTokenStride: 32,
        includeRecapMessage: false
    )

    static let full = LLMChatBudgets(
        maxThreadMessages: 500,
        maxPromptChars: 120_000,
        maxContextChars: 9_000,
        maxProjectionTasksPerSlice: 1_000,
        projectionTimeoutMs: 800,
        contextCacheTTLms: 0,
        outputMinUpdateIntervalMs: 100,
        outputTokenStride: 32,
        includeRecapMessage: true
    )

    static var active: LLMChatBudgets {
        switch V2FeatureFlags.llmChatContextStrategy {
        case .bounded:
            return .bounded
        case .full:
            return .full
        }
    }
}

public extension ModelConfiguration {
    enum ModelType {
        case regular, reasoning
    }

    var modelType: ModelType {
        switch self {
        case .deepseek_r1_distill_qwen_1_5b_4bit: .reasoning
        case .deepseek_r1_distill_qwen_1_5b_8bit: .reasoning
        case .qwen_3_0_6b_4bit: .reasoning
        case .qwen_3_4b_4bit: .reasoning
        case .qwen_3_8b_4bit: .reasoning
        default: .regular
        }
    }
}

public extension ModelConfiguration {
    static let llama_3_2_1b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.llama
    )

    static let llama_3_2_3b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.llama
    )

    static let deepseek_r1_distill_qwen_1_5b_4bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let deepseek_r1_distill_qwen_1_5b_8bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let qwen_3_0_6b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-0.6B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let qwen_3_4b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let qwen_3_8b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-8B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static var availableModels: [ModelConfiguration] = [
        llama_3_2_1b_4bit,
        llama_3_2_3b_4bit,
        deepseek_r1_distill_qwen_1_5b_4bit,
        deepseek_r1_distill_qwen_1_5b_8bit,
        qwen_3_0_6b_4bit,
        qwen_3_4b_4bit,
        qwen_3_8b_4bit,
    ]

    static var defaultModel: ModelConfiguration {
        qwen_3_0_6b_4bit
    }

    /// Executes getModelByName.
    static func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }

    /// Executes getPromptHistory.
    internal func getPromptHistory(thread: Thread, systemPrompt: String) -> [[String: String]] {
        let budgets = LLMChatBudgets.active
        var promptHistory: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]

        let normalizedMessages = normalizedThreadMessages(from: thread.sortedMessages)
        if normalizedMessages.isEmpty {
            return promptHistory
        }

        let clippedByCount = Array(normalizedMessages.suffix(budgets.maxThreadMessages))
        let droppedPrefix = Array(normalizedMessages.prefix(max(0, normalizedMessages.count - clippedByCount.count)))
        if budgets.includeRecapMessage && droppedPrefix.isEmpty == false {
            promptHistory.append([
                "role": "system",
                "content": buildRecapMessage(from: droppedPrefix)
            ])
        }
        promptHistory.append(contentsOf: clippedByCount)
        enforcePromptBudget(&promptHistory, maxChars: budgets.maxPromptChars)

        return promptHistory
    }

    private func normalizedThreadMessages(from messages: [Message]) -> [[String: String]] {
        messages.compactMap { message in
            let role = message.role.rawValue
            if AssistantCardCodec.isCard(message.content) {
                guard let payload = AssistantCardCodec.decode(from: message.content) else { return nil }
                guard let summarized = summarizedAssistantCardContent(from: payload) else { return nil }
                return [
                    "role": role,
                    "content": summarized
                ]
            }
            guard let sanitized = formatForTokenizer(message.content) else { return nil }
            if message.role == .assistant,
               LLMChatQualityGate.assess(
                sanitized,
                userPrompt: nil,
                terminationReason: nil
               ).isAcceptable == false {
                return nil
            }
            return [
                "role": role,
                "content": sanitized
            ]
        }
    }

    private func buildRecapMessage(from droppedMessages: [[String: String]]) -> String {
        let mergedPreview: [[String: String]]
        if droppedMessages.count > 4 {
            mergedPreview = Array(droppedMessages.prefix(2)) + Array(droppedMessages.suffix(2))
        } else {
            mergedPreview = droppedMessages
        }
        let lines = mergedPreview.enumerated().compactMap { _, item -> String? in
            guard let role = item["role"], let content = item["content"] else { return nil }
            let singleLine = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard singleLine.isEmpty == false else { return nil }
            return "\(role): \(singleLine.prefix(120))"
        }
        let lineBlock = lines.isEmpty ? "No recap lines available." : lines.joined(separator: "\n- ")
        return """
        Earlier context recap (\(droppedMessages.count) messages omitted for brevity):
        - \(lineBlock)
        """
    }

    private func totalPromptCharacters(_ history: [[String: String]]) -> Int {
        history.reduce(0) { partial, item in
            partial + (item["content"]?.count ?? 0)
        }
    }

    private func enforcePromptBudget(_ promptHistory: inout [[String: String]], maxChars: Int) {
        guard maxChars > 0 else {
            promptHistory = []
            return
        }

        while totalPromptCharacters(promptHistory) > maxChars && promptHistory.count > 2 {
            // Preserve system prompt + recap entry, and trim oldest user/assistant turns first.
            promptHistory.remove(at: 2)
        }

        if totalPromptCharacters(promptHistory) <= maxChars { return }

        if promptHistory.count > 1,
           promptHistory[1]["role"] == "system",
           var recapContent = promptHistory[1]["content"] {
            let recapBudget = min(recapContent.count, max(64, maxChars / 6))
            if recapContent.count > recapBudget {
                recapContent = String(recapContent.prefix(recapBudget))
                promptHistory[1]["content"] = recapContent
            }
        }

        if totalPromptCharacters(promptHistory) <= maxChars { return }

        if var systemEntry = promptHistory.first,
           let systemContent = systemEntry["content"] {
            let maxSystemChars = min(systemContent.count, max(128, maxChars / 3))
            if systemContent.count > maxSystemChars {
                systemEntry["content"] = String(systemContent.prefix(maxSystemChars))
                promptHistory[0] = systemEntry
            }
        }

        if totalPromptCharacters(promptHistory) <= maxChars { return }

        guard promptHistory.count >= 2 else {
            if var systemEntry = promptHistory.first,
               let systemContent = systemEntry["content"],
               systemContent.count > maxChars {
                systemEntry["content"] = String(systemContent.prefix(maxChars))
                promptHistory[0] = systemEntry
            }
            return
        }

        let fixedChars = totalPromptCharacters(Array(promptHistory.dropLast()))
        let lastEntryBudget = max(64, maxChars - fixedChars)
        if var lastEntry = promptHistory.last,
           let content = lastEntry["content"],
           content.count > lastEntryBudget {
            // Keep the most recent tail of the newest turn for deterministic truncation.
            lastEntry["content"] = String(content.suffix(lastEntryBudget))
            promptHistory[promptHistory.count - 1] = lastEntry
        }

        if totalPromptCharacters(promptHistory) > maxChars,
           var systemEntry = promptHistory.first,
           let systemContent = systemEntry["content"] {
            let remainingBudget = max(0, maxChars - totalPromptCharacters(Array(promptHistory.dropFirst())))
            if systemContent.count > remainingBudget {
                systemEntry["content"] = String(systemContent.prefix(remainingBudget))
                promptHistory[0] = systemEntry
            }
        }
    }

    // TODO: Remove this function when Jinja gets updated
    /// Executes formatForTokenizer.
    func formatForTokenizer(_ message: String) -> String? {
        let sanitized = LLMChatTextSanitizer.sanitizeForPromptHistory(
            message,
            stripReasoningBlocks: modelType == .reasoning
        )
        guard let sanitized else { return nil }
        if modelType == .reasoning {
            return " " + sanitized
        }
        return sanitized
    }

    private func summarizedAssistantCardContent(from payload: AssistantCardPayload) -> String? {
        if let commandResult = payload.commandResult,
           let summary = summarizedSlashCommandResult(commandResult),
           let sanitized = formatForTokenizer(summary) {
            return sanitized
        }

        if let message = payload.message,
           let sanitized = formatForTokenizer(message) {
            return sanitized
        }

        if let rationale = payload.rationale,
           let sanitized = formatForTokenizer(rationale) {
            return sanitized
        }

        return nil
    }

    private func summarizedSlashCommandResult(_ result: SlashCommandExecutionResult) -> String? {
        var lines: [String] = []
        lines.append("Slash command: \(result.commandLabel)")
        lines.append("Summary: \(result.summary)")

        for section in result.sections.prefix(3) {
            lines.append("\(section.title):")
            for item in section.tasks.prefix(4) {
                var parts = [item.title]
                if let dueLabel = item.dueLabel, dueLabel.isEmpty == false {
                    parts.append(dueLabel)
                }
                if item.projectName.isEmpty == false {
                    parts.append(item.projectName)
                }
                lines.append("- " + parts.joined(separator: " | "))
            }
        }

        let summary = lines.joined(separator: "\n")
        return summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : summary
    }

    /// Returns the model's approximate size, in GB.
    var modelSize: Decimal? {
        switch self {
        case .llama_3_2_1b_4bit: return 0.7
        case .llama_3_2_3b_4bit: return 1.8
        case .deepseek_r1_distill_qwen_1_5b_4bit: return 1.0
        case .deepseek_r1_distill_qwen_1_5b_8bit: return 1.9
        case .qwen_3_0_6b_4bit: return 0.3
        case .qwen_3_4b_4bit: return 2.3
        case .qwen_3_8b_4bit: return 4.7
        default: return nil
        }
    }

    func isPrewarmEligible(maxSizeGB: Decimal = 0.5) -> Bool {
        guard let modelSize else { return false }
        return modelSize <= maxSizeGB
    }
}
