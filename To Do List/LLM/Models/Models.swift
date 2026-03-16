//
//  Models.swift
//
//

import Foundation
import MLXLMCommon

private enum LLMModelStopTokenRegistry {
    static let qwenStyle: Set<String> = [
        "<｜end▁of▁sentence｜>",
        "<|im_end|>"
    ]
}

struct LLMTokenBudget {
    let inputTokens: Int
    let reservedOutputTokens: Int
    let systemPromptTokens: Int
    let personalMemoryTokens: Int
    let taskContextTokens: Int
    let slashContextTokens: Int
    let historyMessageLimit: Int
}

enum LLMTokenBudgetEstimator {
    private static let estimatedCharactersPerToken = 4

    static func estimatedTokenCount(for text: String) -> Int {
        guard text.isEmpty == false else { return 0 }
        return max(1, Int(ceil(Double(text.count) / Double(estimatedCharactersPerToken))))
    }

    static func estimatedCharacterBudget(for tokenBudget: Int) -> Int {
        max(0, tokenBudget * estimatedCharactersPerToken)
    }

    static func trimPrefix(_ text: String, toTokenBudget tokenBudget: Int) -> String {
        let characterBudget = estimatedCharacterBudget(for: tokenBudget)
        guard characterBudget > 0 else { return "" }
        guard text.count > characterBudget else { return text }
        return String(text.prefix(characterBudget))
    }

    static func trimSuffix(_ text: String, toTokenBudget tokenBudget: Int) -> String {
        let characterBudget = estimatedCharacterBudget(for: tokenBudget)
        guard characterBudget > 0 else { return "" }
        guard text.count > characterBudget else { return text }
        return String(text.suffix(characterBudget))
    }
}

struct LLMChatBudgets {
    let maxProjectionTasksPerSlice: Int
    let projectionTimeoutMs: UInt64
    let contextCacheTTLms: UInt64
    let outputMinUpdateIntervalMs: UInt64
    let outputTokenStride: Int
    let includeRecapMessage: Bool

    static let bounded = LLMChatBudgets(
        maxProjectionTasksPerSlice: 32,
        projectionTimeoutMs: 450,
        contextCacheTTLms: 2_000,
        outputMinUpdateIntervalMs: 100,
        outputTokenStride: 32,
        includeRecapMessage: false
    )

    static let full = LLMChatBudgets(
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

struct LLMResolvedChatBudget {
    let strategy: LLMChatBudgets
    let model: ModelConfiguration

    var maxThreadMessages: Int {
        model.tokenBudget.historyMessageLimit
    }

    var maxPromptTokens: Int {
        model.tokenBudget.inputTokens
    }

    var maxPromptChars: Int {
        LLMTokenBudgetEstimator.estimatedCharacterBudget(for: maxPromptTokens)
    }

    var maxContextTokens: Int {
        model.tokenBudget.taskContextTokens
    }

    var maxContextChars: Int {
        LLMTokenBudgetEstimator.estimatedCharacterBudget(for: maxContextTokens)
    }

    var systemPromptTokens: Int {
        model.tokenBudget.systemPromptTokens
    }

    var personalMemoryTokens: Int {
        model.tokenBudget.personalMemoryTokens
    }

    var slashContextTokens: Int {
        model.tokenBudget.slashContextTokens
    }

    var reservedOutputTokens: Int {
        model.tokenBudget.reservedOutputTokens
    }
}

extension LLMChatBudgets {
    func resolved(for model: ModelConfiguration) -> LLMResolvedChatBudget {
        LLMResolvedChatBudget(strategy: self, model: model)
    }
}

enum LLMSystemPromptComposer {
    static func compose(
        basePrompt: String,
        model: ModelConfiguration,
        additionalInstruction: String? = nil,
        personalMemory: String? = nil,
        slashContext: String? = nil,
        taskContext: String? = nil
    ) -> String {
        var sections = [
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    basePrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.systemPromptTokens
                ),
                trimPriority: 4
            )
        ]

        let reservedTailTokens = model.tokenBudget.personalMemoryTokens
            + model.tokenBudget.slashContextTokens
            + model.tokenBudget.taskContextTokens
        let remainingForAdditional = max(
            0,
            model.tokenBudget.inputTokens
                - estimatedTotalTokens(for: sections)
                - reservedTailTokens
        )
        if let additionalInstruction {
            sections.append(
                PromptSection(
                    content: LLMTokenBudgetEstimator.trimPrefix(
                        additionalInstruction.trimmingCharacters(in: .whitespacesAndNewlines),
                        toTokenBudget: remainingForAdditional
                    ),
                    trimPriority: 0
                )
            )
        }

        sections.append(
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    (personalMemory ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.personalMemoryTokens
                ),
                trimPriority: 1
            )
        )
        sections.append(
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    (slashContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.slashContextTokens
                ),
                trimPriority: 2
            )
        )
        sections.append(
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    (taskContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.taskContextTokens
                ),
                trimPriority: 3
            )
        )

        sections = sections.filter { $0.content.isEmpty == false }
        trimOverflowIfNeeded(&sections, maxTokens: model.tokenBudget.inputTokens)

        return sections
            .map(\.content)
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }

    private struct PromptSection {
        var content: String
        let trimPriority: Int
    }

    private static func trimOverflowIfNeeded(_ sections: inout [PromptSection], maxTokens: Int) {
        guard maxTokens > 0 else {
            sections.removeAll()
            return
        }

        let orderedIndices = sections.indices.sorted { lhs, rhs in
            sections[lhs].trimPriority < sections[rhs].trimPriority
        }

        for index in orderedIndices {
            let overflow = estimatedTotalTokens(for: sections) - maxTokens
            guard overflow > 0 else { break }
            let currentTokens = LLMTokenBudgetEstimator.estimatedTokenCount(for: sections[index].content)
            let targetTokens = max(0, currentTokens - overflow)
            sections[index].content = LLMTokenBudgetEstimator.trimPrefix(
                sections[index].content,
                toTokenBudget: targetTokens
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        sections.removeAll { $0.content.isEmpty }
    }

    private static func estimatedTotalTokens(for sections: [PromptSection]) -> Int {
        let contentTokens = sections.reduce(0) { partialResult, section in
            partialResult + LLMTokenBudgetEstimator.estimatedTokenCount(for: section.content)
        }
        let separatorTokens = max(0, sections.count - 1)
        return contentTokens + separatorTokens
    }
}

public extension ModelConfiguration {
    enum ModelType {
        case regular, reasoning
    }

    enum ProductTier {
        case `default`
        case smarter
    }

    struct ProductMetadata {
        let displayName: String
        let shortDescription: String
        let onboardingBadgeTitle: String
        let onboardingSubtitle: String
        let tier: ProductTier
        let approximateSizeGB: Decimal
        let tokenBudget: LLMTokenBudget
    }

    var modelType: ModelType {
        switch self {
        case .qwen_3_0_6b_4bit: .reasoning
        case .qwen_3_5_0_8b_optiq_4bit: .reasoning
        default: .regular
        }
    }

    var metadata: ProductMetadata {
        switch self {
        case .qwen_3_0_6b_4bit:
            return ProductMetadata(
                displayName: "Qwen3 0.6B 4bit",
                shortDescription: "Faster, lighter, default for all devices.",
                onboardingBadgeTitle: "Default",
                onboardingSubtitle: "Fastest local model with the safest memory footprint.",
                tier: .default,
                approximateSizeGB: Decimal(string: "0.4") ?? 0.4,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 1_536,
                    reservedOutputTokens: 448,
                    systemPromptTokens: 220,
                    personalMemoryTokens: 120,
                    taskContextTokens: 520,
                    slashContextTokens: 180,
                    historyMessageLimit: 8
                )
            )
        case .qwen_3_5_0_8b_optiq_4bit:
            return ProductMetadata(
                displayName: "Qwen3.5 0.8B OptiQ 4bit",
                shortDescription: "Smarter, slightly heavier, better answers with more RAM cost.",
                onboardingBadgeTitle: "Smarter",
                onboardingSubtitle: "Higher quality responses with a modest local memory tradeoff.",
                tier: .smarter,
                approximateSizeGB: Decimal(string: "0.6") ?? 0.6,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 1_920,
                    reservedOutputTokens: 512,
                    systemPromptTokens: 240,
                    personalMemoryTokens: 140,
                    taskContextTokens: 700,
                    slashContextTokens: 220,
                    historyMessageLimit: 8
                )
            )
        default:
            return ProductMetadata(
                displayName: name,
                shortDescription: "",
                onboardingBadgeTitle: "",
                onboardingSubtitle: "",
                tier: .default,
                approximateSizeGB: 0,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 1_536,
                    reservedOutputTokens: 448,
                    systemPromptTokens: 220,
                    personalMemoryTokens: 120,
                    taskContextTokens: 520,
                    slashContextTokens: 180,
                    historyMessageLimit: 8
                )
            )
        }
    }

    var displayName: String { metadata.displayName }
    var onboardingBadgeTitle: String { metadata.onboardingBadgeTitle }
    var shortDescription: String { metadata.shortDescription }
    var onboardingSubtitle: String { metadata.onboardingSubtitle }
    internal var tokenBudget: LLMTokenBudget { metadata.tokenBudget }
}

public extension ModelConfiguration {
    static let qwen_3_0_6b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-0.6B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let qwen_3_5_0_8b_optiq_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static var availableModels: [ModelConfiguration] = [
        qwen_3_0_6b_4bit,
        qwen_3_5_0_8b_optiq_4bit,
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
        let resolvedBudget = LLMChatBudgets.active.resolved(for: self)
        var promptHistory: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]

        let normalizedMessages = normalizedThreadMessages(from: thread.sortedMessages)
        if normalizedMessages.isEmpty {
            return promptHistory
        }

        let clippedByCount = Array(normalizedMessages.suffix(resolvedBudget.maxThreadMessages))
        let droppedPrefix = Array(normalizedMessages.prefix(max(0, normalizedMessages.count - clippedByCount.count)))
        if resolvedBudget.strategy.includeRecapMessage && droppedPrefix.isEmpty == false {
            promptHistory.append([
                "role": "system",
                "content": buildRecapMessage(from: droppedPrefix)
            ])
        }
        promptHistory.append(contentsOf: clippedByCount)
        enforcePromptBudget(&promptHistory, maxTokens: resolvedBudget.maxPromptTokens)

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

    private func totalPromptTokens(_ history: [[String: String]]) -> Int {
        history.reduce(0) { partial, item in
            partial + LLMTokenBudgetEstimator.estimatedTokenCount(for: item["content"] ?? "")
        }
    }

    private func enforcePromptBudget(_ promptHistory: inout [[String: String]], maxTokens: Int) {
        guard maxTokens > 0 else {
            promptHistory = []
            return
        }

        while totalPromptTokens(promptHistory) > maxTokens && promptHistory.count > 2 {
            // Preserve system prompt + recap entry, and trim oldest user/assistant turns first.
            promptHistory.remove(at: 2)
        }

        if totalPromptTokens(promptHistory) <= maxTokens { return }

        if promptHistory.count > 1,
           promptHistory[1]["role"] == "system",
           var recapContent = promptHistory[1]["content"] {
            let recapBudgetTokens = min(
                LLMTokenBudgetEstimator.estimatedTokenCount(for: recapContent),
                max(24, maxTokens / 6)
            )
            if LLMTokenBudgetEstimator.estimatedTokenCount(for: recapContent) > recapBudgetTokens {
                recapContent = LLMTokenBudgetEstimator.trimPrefix(recapContent, toTokenBudget: recapBudgetTokens)
                promptHistory[1]["content"] = recapContent
            }
        }

        if totalPromptTokens(promptHistory) <= maxTokens { return }

        if var systemEntry = promptHistory.first,
           let systemContent = systemEntry["content"] {
            let maxSystemTokens = min(
                LLMTokenBudgetEstimator.estimatedTokenCount(for: systemContent),
                max(48, tokenBudget.systemPromptTokens)
            )
            if LLMTokenBudgetEstimator.estimatedTokenCount(for: systemContent) > maxSystemTokens {
                systemEntry["content"] = LLMTokenBudgetEstimator.trimPrefix(systemContent, toTokenBudget: maxSystemTokens)
                promptHistory[0] = systemEntry
            }
        }

        if totalPromptTokens(promptHistory) <= maxTokens { return }

        guard promptHistory.count >= 2 else {
            if var systemEntry = promptHistory.first,
               let systemContent = systemEntry["content"],
               LLMTokenBudgetEstimator.estimatedTokenCount(for: systemContent) > maxTokens {
                systemEntry["content"] = LLMTokenBudgetEstimator.trimPrefix(systemContent, toTokenBudget: maxTokens)
                promptHistory[0] = systemEntry
            }
            return
        }

        let fixedTokens = totalPromptTokens(Array(promptHistory.dropLast()))
        let lastEntryBudget = max(24, maxTokens - fixedTokens)
        if var lastEntry = promptHistory.last,
           let content = lastEntry["content"],
           LLMTokenBudgetEstimator.estimatedTokenCount(for: content) > lastEntryBudget {
            // Keep the most recent tail of the newest turn for deterministic truncation.
            lastEntry["content"] = LLMTokenBudgetEstimator.trimSuffix(content, toTokenBudget: lastEntryBudget)
            promptHistory[promptHistory.count - 1] = lastEntry
        }

        if totalPromptTokens(promptHistory) > maxTokens,
           var systemEntry = promptHistory.first,
           let systemContent = systemEntry["content"] {
            let remainingBudget = max(0, maxTokens - totalPromptTokens(Array(promptHistory.dropFirst())))
            if LLMTokenBudgetEstimator.estimatedTokenCount(for: systemContent) > remainingBudget {
                systemEntry["content"] = LLMTokenBudgetEstimator.trimPrefix(systemContent, toTokenBudget: remainingBudget)
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
        case .qwen_3_0_6b_4bit: return metadata.approximateSizeGB
        case .qwen_3_5_0_8b_optiq_4bit: return metadata.approximateSizeGB
        default: return nil
        }
    }
}
