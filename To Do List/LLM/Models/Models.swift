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
    let executiveContextTokens: Int
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
        includeRecapMessage: false
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

    var executiveContextTokens: Int {
        model.tokenBudget.executiveContextTokens
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
        executiveContext: String? = nil,
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
            + model.tokenBudget.executiveContextTokens
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
                    (executiveContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.executiveContextTokens
                ),
                trimPriority: 2
            )
        )
        sections.append(
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    (slashContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.slashContextTokens
                ),
                trimPriority: 3
            )
        )
        sections.append(
            PromptSection(
                content: LLMTokenBudgetEstimator.trimPrefix(
                    (taskContext ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    toTokenBudget: model.tokenBudget.taskContextTokens
                ),
                trimPriority: 5
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

    enum ThinkingFormat {
        case none
        case taggedThinkBlocks
        case plainTextPreamble
    }

    enum ModelFamily {
        case qwen3
        case qwen3_5Text
        case bonsai
    }

    enum ModelDistribution {
        case mlx
        case transformers
    }

    enum ProductTier {
        case `default`
        case smarter
        case experimental
    }

    struct ChatTuningProfile {
        let answerOnlyMaxRawTokens: Int
        let thinkingMaxRawTokens: Int
        let minAnswerTokensAfterAnswerPhase: Int
        let maxVisibleCharacters: Int
        let temperature: Float
        let topP: Float
        let repetitionPenalty: Float?
        let outputTokenStride: Int
    }

    struct ProductMetadata {
        let modelType: ModelType
        let displayName: String
        let shortDescription: String
        let onboardingBadgeTitle: String
        let onboardingSubtitle: String
        let tier: ProductTier
        let approximateSizeGB: Decimal
        let tokenBudget: LLMTokenBudget
        let family: ModelFamily
        let distribution: ModelDistribution
        let sourceModelID: String?
        let supportsVisibleThinking: Bool
        let supportsThinkingToggleInTemplateContext: Bool
        let thinkingFormat: ThinkingFormat
        let chatTuningProfile: ChatTuningProfile
    }

    var modelType: ModelType {
        metadata.modelType
    }

    var metadata: ProductMetadata {
        switch self {
        case .qwen_3_0_6b_4bit:
            return ProductMetadata(
                modelType: .reasoning,
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
                    executiveContextTokens: 160,
                    taskContextTokens: 360,
                    slashContextTokens: 180,
                    historyMessageLimit: 8
                ),
                family: .qwen3,
                distribution: .mlx,
                sourceModelID: nil,
                supportsVisibleThinking: true,
                supportsThinkingToggleInTemplateContext: true,
                thinkingFormat: .taggedThinkBlocks,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 384,
                    thinkingMaxRawTokens: 768,
                    minAnswerTokensAfterAnswerPhase: 160,
                    maxVisibleCharacters: 3_200,
                    temperature: 0.5,
                    topP: 0.95,
                    repetitionPenalty: 1.02,
                    outputTokenStride: 16
                )
            )
        case .qwen_3_5_0_8b_optiq_4bit:
            return ProductMetadata(
                modelType: .reasoning,
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
                    executiveContextTokens: 180,
                    taskContextTokens: 520,
                    slashContextTokens: 220,
                    historyMessageLimit: 8
                ),
                family: .qwen3_5Text,
                distribution: .mlx,
                sourceModelID: nil,
                supportsVisibleThinking: true,
                supportsThinkingToggleInTemplateContext: true,
                thinkingFormat: .taggedThinkBlocks,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 512,
                    thinkingMaxRawTokens: 1_024,
                    minAnswerTokensAfterAnswerPhase: 224,
                    maxVisibleCharacters: 4_800,
                    temperature: 0.5,
                    topP: 0.95,
                    repetitionPenalty: 1.02,
                    outputTokenStride: 16
                )
            )
        case .qwen_3_5_0_8b_nexveridian_4bit:
            return ProductMetadata(
                modelType: .reasoning,
                displayName: "Qwen3.5 0.8B NexVeridian 4bit",
                shortDescription: "Alternative Qwen 3.5 text model with the same lightweight footprint.",
                onboardingBadgeTitle: "Experimental",
                onboardingSubtitle: "Text-first Qwen 3.5 option for comparing quality and style.",
                tier: .experimental,
                approximateSizeGB: Decimal(string: "0.6") ?? 0.6,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 1_920,
                    reservedOutputTokens: 512,
                    systemPromptTokens: 240,
                    personalMemoryTokens: 140,
                    executiveContextTokens: 180,
                    taskContextTokens: 520,
                    slashContextTokens: 220,
                    historyMessageLimit: 8
                ),
                family: .qwen3_5Text,
                distribution: .mlx,
                sourceModelID: nil,
                supportsVisibleThinking: true,
                supportsThinkingToggleInTemplateContext: true,
                thinkingFormat: .taggedThinkBlocks,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 512,
                    thinkingMaxRawTokens: 1_024,
                    minAnswerTokensAfterAnswerPhase: 224,
                    maxVisibleCharacters: 4_800,
                    temperature: 0.5,
                    topP: 0.95,
                    repetitionPenalty: 1.02,
                    outputTokenStride: 16
                )
            )
        case .qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit:
            return ProductMetadata(
                modelType: .reasoning,
                displayName: "Qwen3.5 0.8B Claude 4.6 Distilled 4bit",
                shortDescription: "Reasoning-distilled MLX equivalent of the requested Claude-style fine-tune.",
                onboardingBadgeTitle: "Experimental",
                onboardingSubtitle: "Heavier reasoning style tuned from the requested distilled source model.",
                tier: .experimental,
                approximateSizeGB: Decimal(string: "0.6") ?? 0.6,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 1_920,
                    reservedOutputTokens: 512,
                    systemPromptTokens: 240,
                    personalMemoryTokens: 140,
                    executiveContextTokens: 180,
                    taskContextTokens: 520,
                    slashContextTokens: 220,
                    historyMessageLimit: 8
                ),
                family: .qwen3_5Text,
                distribution: .mlx,
                sourceModelID: "Ishant06/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled",
                supportsVisibleThinking: true,
                supportsThinkingToggleInTemplateContext: true,
                thinkingFormat: .plainTextPreamble,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 640,
                    thinkingMaxRawTokens: 1_536,
                    minAnswerTokensAfterAnswerPhase: 320,
                    maxVisibleCharacters: 6_400,
                    temperature: 0.5,
                    topP: 0.95,
                    repetitionPenalty: 1.02,
                    outputTokenStride: 16
                )
            )
        case .bonsai_1_7b_mlx_1bit:
            return ProductMetadata(
                modelType: .reasoning,
                displayName: "Bonsai 1.7B 1-bit",
                shortDescription: "Experimental 1-bit reasoning model with a very small local footprint.",
                onboardingBadgeTitle: "Experimental",
                onboardingSubtitle: "Tiny 1-bit MLX model for experimenting with Bonsai's local reasoning behavior.",
                tier: .experimental,
                approximateSizeGB: Decimal(string: "0.27") ?? 0.27,
                tokenBudget: LLMTokenBudget(
                    inputTokens: 2_048,
                    reservedOutputTokens: 512,
                    systemPromptTokens: 256,
                    personalMemoryTokens: 128,
                    executiveContextTokens: 192,
                    taskContextTokens: 704,
                    slashContextTokens: 192,
                    historyMessageLimit: 8
                ),
                family: .bonsai,
                distribution: .mlx,
                sourceModelID: nil,
                supportsVisibleThinking: true,
                supportsThinkingToggleInTemplateContext: true,
                thinkingFormat: .taggedThinkBlocks,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 448,
                    thinkingMaxRawTokens: 896,
                    minAnswerTokensAfterAnswerPhase: 192,
                    maxVisibleCharacters: 4_000,
                    temperature: 0.5,
                    topP: 0.85,
                    repetitionPenalty: nil,
                    outputTokenStride: 16
                )
            )
        default:
            return ProductMetadata(
                modelType: .regular,
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
                    executiveContextTokens: 160,
                    taskContextTokens: 360,
                    slashContextTokens: 180,
                    historyMessageLimit: 8
                ),
                family: .qwen3,
                distribution: .mlx,
                sourceModelID: nil,
                supportsVisibleThinking: false,
                supportsThinkingToggleInTemplateContext: false,
                thinkingFormat: .none,
                chatTuningProfile: ChatTuningProfile(
                    answerOnlyMaxRawTokens: 384,
                    thinkingMaxRawTokens: 768,
                    minAnswerTokensAfterAnswerPhase: 160,
                    maxVisibleCharacters: 3_200,
                    temperature: 0.2,
                    topP: 0.9,
                    repetitionPenalty: 1.1,
                    outputTokenStride: 32
                )
            )
        }
    }

    var displayName: String { metadata.displayName }
    var onboardingBadgeTitle: String { metadata.onboardingBadgeTitle }
    var shortDescription: String { metadata.shortDescription }
    var onboardingSubtitle: String { metadata.onboardingSubtitle }
    internal var tokenBudget: LLMTokenBudget { metadata.tokenBudget }
    var family: ModelFamily { metadata.family }
    var distribution: ModelDistribution { metadata.distribution }
    var sourceModelID: String? { metadata.sourceModelID }
    var supportsVisibleThinking: Bool { metadata.supportsVisibleThinking }
    var supportsThinkingToggleInTemplateContext: Bool { metadata.supportsThinkingToggleInTemplateContext }
    var thinkingFormat: ThinkingFormat { metadata.thinkingFormat }
    var chatTuningProfile: ChatTuningProfile { metadata.chatTuningProfile }
}

enum LLMModelAvailability: Equatable {
    case supported
    case temporarilyUnavailable
}

struct LLMModelCompatibilityResult: Equatable {
    let modelName: String
    let availability: LLMModelAvailability
    let statusReason: String?

    var canInstall: Bool {
        availability == .supported
    }

    var canActivate: Bool {
        availability == .supported
    }

    var statusBadgeTitle: String? {
        switch availability {
        case .supported:
            return nil
        case .temporarilyUnavailable:
            return "Unsupported"
        }
    }

    var prepareFailureMessage: String {
        switch availability {
        case .supported:
            return "Model failed to prepare. Please switch models or retry."
        case .temporarilyUnavailable:
            return statusReason ?? "This model is temporarily unavailable in the local AI runtime."
        }
    }
}

enum LLMRuntimeSupportMatrix {
    static func compatibility(for model: ModelConfiguration) -> LLMModelCompatibilityResult {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            return LLMModelCompatibilityResult(
                modelName: model.name,
                availability: .temporarilyUnavailable,
                statusReason: "Local EVA models are not available in the iOS Simulator."
            )
        }
        #endif
        if model == .bonsai_1_7b_mlx_1bit {
            return LLMModelCompatibilityResult(
                modelName: model.name,
                availability: .temporarilyUnavailable,
                statusReason: "Bonsai 1-bit requires Prism-specific MLX kernels and is disabled while EVA uses the stable upstream Qwen runtime."
            )
        }
        return LLMModelCompatibilityResult(
            modelName: model.name,
            availability: .supported,
            statusReason: nil
        )
    }

    static func compatibility(for modelName: String) -> LLMModelCompatibilityResult? {
        guard let model = ModelConfiguration.getModelByName(modelName) else { return nil }
        return compatibility(for: model)
    }
}

enum LLMRuntimeSmokeStatus: Equatable {
    case supported
    case failed
}

struct LLMRuntimeSmokeTestResult: Equatable {
    let modelName: String
    let status: LLMRuntimeSmokeStatus
    let prepareDurationMs: Int?
    let firstTokenLatencyMs: Int?
    let peakMemoryMB: Int?
    let terminationReason: String?
    let rawOutputPreview: String?
    let sanitizedOutputPreview: String?
    let sanitizationEmptiedNonEmptyRaw: Bool?
    let fallbackShown: Bool?
    let errorDescription: String?
}

enum LLMRuntimeSmokeTester {
    static func classify(model: ModelConfiguration) -> LLMRuntimeSmokeTestResult {
        let compatibility = LLMRuntimeSupportMatrix.compatibility(for: model)
        guard compatibility.canActivate else {
            return LLMRuntimeSmokeTestResult(
                modelName: model.name,
                status: .failed,
                prepareDurationMs: nil,
                firstTokenLatencyMs: nil,
                peakMemoryMB: nil,
                terminationReason: nil,
                rawOutputPreview: nil,
                sanitizedOutputPreview: nil,
                sanitizationEmptiedNonEmptyRaw: nil,
                fallbackShown: nil,
                errorDescription: compatibility.prepareFailureMessage
            )
        }
        return LLMRuntimeSmokeTestResult(
            modelName: model.name,
            status: .supported,
            prepareDurationMs: nil,
            firstTokenLatencyMs: nil,
            peakMemoryMB: nil,
            terminationReason: nil,
            rawOutputPreview: nil,
            sanitizedOutputPreview: nil,
            sanitizationEmptiedNonEmptyRaw: nil,
            fallbackShown: nil,
            errorDescription: nil
        )
    }

    static func run(
        model: ModelConfiguration,
        probe: (String) async throws -> LLMRuntimeSmokeMetrics
    ) async -> LLMRuntimeSmokeTestResult {
        let startedAt = Date()
        do {
            let metrics = try await probe(model.name)
            return LLMRuntimeSmokeTestResult(
                modelName: model.name,
                status: .supported,
                prepareDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
                firstTokenLatencyMs: metrics.firstTokenLatencyMs,
                peakMemoryMB: metrics.peakMemoryMB,
                terminationReason: metrics.terminationReason,
                rawOutputPreview: metrics.rawOutputPreview,
                sanitizedOutputPreview: metrics.sanitizedOutputPreview,
                sanitizationEmptiedNonEmptyRaw: metrics.sanitizationEmptiedNonEmptyRaw,
                fallbackShown: metrics.fallbackShown,
                errorDescription: nil
            )
        } catch {
            return LLMRuntimeSmokeTestResult(
                modelName: model.name,
                status: .failed,
                prepareDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
                firstTokenLatencyMs: nil,
                peakMemoryMB: nil,
                terminationReason: nil,
                rawOutputPreview: nil,
                sanitizedOutputPreview: nil,
                sanitizationEmptiedNonEmptyRaw: nil,
                fallbackShown: nil,
                errorDescription: error.localizedDescription
            )
        }
    }
}

struct LLMRuntimeSmokeMetrics: Equatable {
    let firstTokenLatencyMs: Int?
    let peakMemoryMB: Int?
    let terminationReason: String?
    let rawOutputPreview: String?
    let sanitizedOutputPreview: String?
    let sanitizationEmptiedNonEmptyRaw: Bool?
    let fallbackShown: Bool?

    init(
        firstTokenLatencyMs: Int? = nil,
        peakMemoryMB: Int? = nil,
        terminationReason: String? = nil,
        rawOutputPreview: String? = nil,
        sanitizedOutputPreview: String? = nil,
        sanitizationEmptiedNonEmptyRaw: Bool? = nil,
        fallbackShown: Bool? = nil
    ) {
        self.firstTokenLatencyMs = firstTokenLatencyMs
        self.peakMemoryMB = peakMemoryMB
        self.terminationReason = terminationReason
        self.rawOutputPreview = rawOutputPreview
        self.sanitizedOutputPreview = sanitizedOutputPreview
        self.sanitizationEmptiedNonEmptyRaw = sanitizationEmptiedNonEmptyRaw
        self.fallbackShown = fallbackShown
    }
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

    static let qwen_3_5_0_8b_nexveridian_4bit = ModelConfiguration(
        id: "NexVeridian/Qwen3.5-0.8B-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    static let qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit = ModelConfiguration(
        id: "Jackrong/MLX-Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-4bit",
        extraEOSTokens: LLMModelStopTokenRegistry.qwenStyle
    )

    // Bonsai 1-bit requires Prism's MLX Swift fork with 1-bit quantization kernels.
    static let bonsai_1_7b_mlx_1bit = ModelConfiguration(
        id: "prism-ml/Bonsai-1.7B-mlx-1bit"
    )

    static var availableModels: [ModelConfiguration] = [
        qwen_3_0_6b_4bit,
        qwen_3_5_0_8b_optiq_4bit,
        qwen_3_5_0_8b_nexveridian_4bit,
        qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit,
        bonsai_1_7b_mlx_1bit,
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

    internal func getChatMessages(thread: Thread, systemPrompt: String) -> [Chat.Message] {
        let resolvedBudget = LLMChatBudgets.active.resolved(for: self)
        var chatMessages: [Chat.Message] = [.system(systemPrompt)]

        let normalizedMessages = normalizedThreadMessages(from: thread.sortedMessages)
        if normalizedMessages.isEmpty {
            return chatMessages
        }

        let clippedByCount = Array(normalizedMessages.suffix(resolvedBudget.maxThreadMessages))
        let droppedPrefix = Array(normalizedMessages.prefix(max(0, normalizedMessages.count - clippedByCount.count)))
        if resolvedBudget.strategy.includeRecapMessage && droppedPrefix.isEmpty == false {
            chatMessages.append(.system(buildRecapMessage(from: droppedPrefix)))
        }
        chatMessages.append(contentsOf: clippedByCount)
        enforcePromptBudget(&chatMessages, maxTokens: resolvedBudget.maxPromptTokens)

        return chatMessages
    }

    /// Executes getPromptHistory.
    internal func getPromptHistory(thread: Thread, systemPrompt: String) -> [[String: String]] {
        getChatMessages(thread: thread, systemPrompt: systemPrompt).map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
    }

    private func normalizedThreadMessages(from messages: [Message]) -> [Chat.Message] {
        messages.compactMap { message in
            if AssistantCardCodec.isCard(message.content) {
                guard let payload = AssistantCardCodec.decode(from: message.content) else { return nil }
                guard let summarized = summarizedAssistantCardContent(from: payload) else { return nil }
                return chatMessage(role: message.role, content: summarized)
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
            return chatMessage(role: message.role, content: sanitized)
        }
    }

    private func chatMessage(role: Role, content: String) -> Chat.Message {
        switch role {
        case .assistant:
            return .assistant(content)
        case .user:
            return .user(content)
        case .system:
            return .system(content)
        }
    }

    private func buildRecapMessage(from droppedMessages: [Chat.Message]) -> String {
        let mergedPreview: [[String: String]]
        if droppedMessages.count > 4 {
            mergedPreview = (Array(droppedMessages.prefix(2)) + Array(droppedMessages.suffix(2))).map {
                ["role": $0.role.rawValue, "content": $0.content]
            }
        } else {
            mergedPreview = droppedMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
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

    private func totalPromptTokens(_ history: [Chat.Message]) -> Int {
        history.reduce(0) { partial, item in
            partial + LLMTokenBudgetEstimator.estimatedTokenCount(for: item.content)
        }
    }

    private func enforcePromptBudget(_ promptHistory: inout [Chat.Message], maxTokens: Int) {
        guard maxTokens > 0 else {
            promptHistory = []
            return
        }

        let hasRecapEntry = promptHistory.count > 1 && promptHistory[1].role == .system
        let firstRemovableIndex = hasRecapEntry ? 2 : 1
        let minimumRetainedCount = hasRecapEntry ? 3 : 2
        while totalPromptTokens(promptHistory) > maxTokens && promptHistory.count > minimumRetainedCount {
            // Preserve the system prompt (+ recap when present), then trim the oldest conversation turn first.
            promptHistory.remove(at: firstRemovableIndex)
        }

        if totalPromptTokens(promptHistory) <= maxTokens { return }

        if promptHistory.count > 1,
           promptHistory[1].role == .system {
            var recapContent = promptHistory[1].content
            let recapBudgetTokens = min(
                LLMTokenBudgetEstimator.estimatedTokenCount(for: recapContent),
                max(24, maxTokens / 6)
            )
            if LLMTokenBudgetEstimator.estimatedTokenCount(for: recapContent) > recapBudgetTokens {
                recapContent = LLMTokenBudgetEstimator.trimPrefix(recapContent, toTokenBudget: recapBudgetTokens)
                promptHistory[1].content = recapContent
            }
        }

        if totalPromptTokens(promptHistory) <= maxTokens { return }

        guard promptHistory.count >= 2 else {
            if var systemEntry = promptHistory.first,
               LLMTokenBudgetEstimator.estimatedTokenCount(for: systemEntry.content) > maxTokens {
                systemEntry.content = LLMTokenBudgetEstimator.trimPrefix(systemEntry.content, toTokenBudget: maxTokens)
                promptHistory[0] = systemEntry
            }
            return
        }

        let fixedTokens = totalPromptTokens(Array(promptHistory.dropLast()))
        let lastEntryBudget = max(24, maxTokens - fixedTokens)
        if var lastEntry = promptHistory.last,
           LLMTokenBudgetEstimator.estimatedTokenCount(for: lastEntry.content) > lastEntryBudget {
            // Keep the most recent tail of the newest turn for deterministic truncation.
            lastEntry.content = LLMTokenBudgetEstimator.trimSuffix(lastEntry.content, toTokenBudget: lastEntryBudget)
            promptHistory[promptHistory.count - 1] = lastEntry
        }

        if totalPromptTokens(promptHistory) > maxTokens,
           var systemEntry = promptHistory.first {
            let systemContent = systemEntry.content
            let remainingBudget = max(0, maxTokens - totalPromptTokens(Array(promptHistory.dropFirst())))
            if LLMTokenBudgetEstimator.estimatedTokenCount(for: systemContent) > remainingBudget {
                systemEntry.content = LLMTokenBudgetEstimator.trimPrefix(systemContent, toTokenBudget: remainingBudget)
                promptHistory[0] = systemEntry
            }
        }
    }

    /// Executes formatForTokenizer.
    func formatForTokenizer(_ message: String) -> String? {
        let sanitized = LLMChatTextSanitizer.sanitizeForPromptHistory(
            message,
            stripReasoningBlocks: modelType == .reasoning,
            modelName: name
        )
        guard let sanitized else { return nil }
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
        case .qwen_3_5_0_8b_nexveridian_4bit: return metadata.approximateSizeGB
        case .qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit: return metadata.approximateSizeGB
        case .bonsai_1_7b_mlx_1bit: return metadata.approximateSizeGB
        default: return nil
        }
    }
}
