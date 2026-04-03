import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

struct LLMInferencePrepareResult {
    let wasAlreadyLoaded: Bool
    let modelInfo: String
}

struct LLMInferenceStreamUpdate {
    let rawText: String
    let visibleText: String
    let phaseTrigger: String?
    let tokenCount: Int
}

struct LLMInferenceGenerationResult {
    let rawOutput: String
    let visibleOutput: String
    let tokensPerSecond: Double
    let generationTokenCount: Int
    let removedTemplateArtifacts: Bool
    let terminationReason: String
    let firstResponseLatencyMs: Int
    let prewarmHit: Bool
    let answerPhaseStartTokenCount: Int?
    let rawCapHitStage: String?
}

struct LLMGenerationRequestOptions {
    enum ChatMode {
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

actor LLMInferenceEngine {
    enum LoadState {
        case idle
        case loaded(modelName: String, container: ModelContainer)
    }

    private var loadState = LoadState.idle
    private var inFlightLoadTask: (modelName: String, task: Task<ModelContainer, Error>)?
    private var generationCancellationToken = LLMGenerationCancellationToken()

    var loadedModelName: String? {
        switch loadState {
        case .idle:
            return nil
        case .loaded(let modelName, _):
            return modelName
        }
    }

    func prepare(
        modelName: String,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> LLMInferencePrepareResult {
        let wasAlreadyLoaded = loadedModelName == modelName
        _ = try await load(modelName: modelName, onProgress: onProgress)
        let modelInfo = "Loaded \(modelName). Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
        return LLMInferencePrepareResult(
            wasAlreadyLoaded: wasAlreadyLoaded,
            modelInfo: modelInfo
        )
    }

    func cancelGeneration(cancelLoad: Bool = false) {
        generationCancellationToken.cancel()
        if cancelLoad {
            inFlightLoadTask?.task.cancel()
            inFlightLoadTask = nil
        }
    }

    func unload() {
        inFlightLoadTask?.task.cancel()
        inFlightLoadTask = nil
        generationCancellationToken.cancel()
        loadState = .idle
    }

    func generate(
        modelName: String,
        chatMessages: [Chat.Message],
        profile: LLMGenerationProfile,
        requestOptions: LLMGenerationRequestOptions,
        onFirstToken: (@Sendable () -> Void)? = nil,
        onStreamUpdate: (@Sendable (LLMInferenceStreamUpdate) -> Void)? = nil
    ) async throws -> LLMInferenceGenerationResult {
        let streamBudgets = LLMChatBudgets.active
        let outputTokenStride = requestOptions.showsVisibleThinking
            ? max(1, min(streamBudgets.outputTokenStride, 16))
            : max(1, streamBudgets.outputTokenStride)
        let outputMinUpdateNanoseconds = streamBudgets.outputMinUpdateIntervalMs * 1_000_000
        let generationStartedAt = Date()
        let prewarmHit = loadedModelName == modelName

        let runCancellationToken = LLMGenerationCancellationToken()
        generationCancellationToken = runCancellationToken

        let modelContainer = try await load(modelName: modelName)
        if Task.isCancelled || runCancellationToken.isCancelled {
            throw CancellationError()
        }

        let isReasoningModel = requestOptions.isReasoningEnabled
        let maxRawTokens = profile.maxRawTokens(isReasoningModel: isReasoningModel)
        let minAnswerTokens = profile.minAnswerTokensAfterAnswerPhase(
            isReasoningModel: isReasoningModel
        )
        let generateParameters = GenerateParameters(
            maxTokens: maxRawTokens,
            temperature: profile.temperature,
            topP: profile.topP,
            repetitionPenalty: profile.repetitionPenalty,
            repetitionContextSize: profile.repetitionContextSize
        )

        logWarning(
            event: "chat_generation_parameters",
            message: "Resolved chat generation parameters for current request",
            fields: [
                "model_name": modelName,
                "chat_mode": requestOptions.chatMode == .thinkingThenAnswer ? "thinking_then_answer" : "answer_only",
                "supports_visible_thinking": requestOptions.showsVisibleThinking ? "true" : "false",
                "thinking_format": String(describing: requestOptions.thinkingFormat),
                "allow_thinking": requestOptions.allowThinking ? "true" : "false",
                "max_raw_tokens": String(maxRawTokens),
                "min_answer_tokens_after_answer_phase": String(minAnswerTokens),
                "temperature": String(format: "%.2f", profile.temperature),
                "top_p": String(format: "%.2f", profile.topP),
                "repetition_penalty": profile.repetitionPenalty.map { String(format: "%.2f", $0) } ?? "nil",
                "output_token_stride": String(outputTokenStride)
            ]
        )

        MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
        if Task.isCancelled || runCancellationToken.isCancelled {
            throw CancellationError()
        }

        var firstTokenLogged = false
        var lastOutputUpdateNanoseconds: UInt64 = 0
        var decodedTokenCount = 0
        var streamedOutputText = ""
        var limiter = LLMChatGenerationLimiter(
            maxRawTokens: maxRawTokens,
            minAnswerTokensAfterAnswerPhase: minAnswerTokens
        )
        var terminationReason = "eos"
        var removedTemplateArtifacts = false

        let result = try await modelContainer.perform { context in
            let userInput = UserInput(
                chat: chatMessages,
                additionalContext: requestOptions.templateContext.isEmpty ? nil : requestOptions.templateContext
            )
            let input = try await context.processor.prepare(input: userInput)
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }

            return try MLXLMCommon.generate(
                input: input,
                parameters: generateParameters,
                context: context
            ) { tokens in
                if Task.isCancelled || runCancellationToken.isCancelled {
                    return .stop
                }

                if !firstTokenLogged, !tokens.isEmpty {
                    firstTokenLogged = true
                    onFirstToken?()
                    let firstTokenLatencyMs = Int(Date().timeIntervalSince(generationStartedAt) * 1_000)
                    logWarning(
                        event: "chat_first_token_latency_ms",
                        message: "First token latency measured for chat generation",
                        fields: [
                            "model_name": modelName,
                            "latency_ms": String(firstTokenLatencyMs),
                            "prewarm_hit": prewarmHit ? "true" : "false"
                        ]
                    )
                }

                let nowNanoseconds = DispatchTime.now().uptimeNanoseconds
                let shouldUpdateByStride = tokens.count % outputTokenStride == 0
                let shouldUpdateByTime = outputMinUpdateNanoseconds > 0 && (
                    lastOutputUpdateNanoseconds == 0 ||
                    nowNanoseconds &- lastOutputUpdateNanoseconds >= outputMinUpdateNanoseconds
                )
                let shouldPublishUpdate = shouldUpdateByStride || shouldUpdateByTime || tokens.count == 1

                if shouldPublishUpdate {
                    lastOutputUpdateNanoseconds = nowNanoseconds
                    if tokens.count < decodedTokenCount {
                        decodedTokenCount = tokens.count
                        streamedOutputText = context.tokenizer.decode(tokens: tokens)
                    } else if tokens.count == decodedTokenCount {
                        if streamedOutputText.isEmpty, !tokens.isEmpty {
                            streamedOutputText = context.tokenizer.decode(tokens: tokens)
                        }
                    } else {
                        let deltaTokens = Array(tokens.dropFirst(decodedTokenCount))
                        let deltaText = context.tokenizer.decode(tokens: deltaTokens)
                        streamedOutputText.append(deltaText)
                        decodedTokenCount = tokens.count
                    }

                    let rawText = streamedOutputText
                    let visibleTextResult = LLMVisibleOutputFormatter.formatVisibleTextResult(
                        rawText,
                        profile: profile,
                        modelName: modelName,
                        closeOpenThinkingBlock: false
                    )
                    removedTemplateArtifacts = removedTemplateArtifacts || visibleTextResult.removedTemplateArtifacts
                    let phaseTrigger = Self.answerPhaseTrigger(
                        rawText: rawText,
                        visibleText: visibleTextResult.text,
                        isReasoningModel: isReasoningModel,
                        requestOptions: requestOptions,
                        modelName: modelName
                    )
                    if phaseTrigger != nil {
                        limiter.markAnswerPhaseStarted(currentTokenCount: tokens.count)
                    }
                    onStreamUpdate?(
                        LLMInferenceStreamUpdate(
                            rawText: rawText,
                            visibleText: visibleTextResult.text,
                            phaseTrigger: phaseTrigger,
                            tokenCount: tokens.count
                        )
                    )
                }

                if runCancellationToken.isCancelled {
                    terminationReason = "user_cancel"
                    return .stop
                }
                if let stopReason = limiter.stopReason(currentTokenCount: tokens.count) {
                    terminationReason = stopReason
                    return .stop
                }
                return .more
            }
        }

        if Task.isCancelled || runCancellationToken.isCancelled {
            throw CancellationError()
        }

        let finalVisibleOutputResult = LLMVisibleOutputFormatter.formatVisibleTextResult(
            result.output,
            profile: profile,
            modelName: modelName,
            closeOpenThinkingBlock: true
        )
        removedTemplateArtifacts = removedTemplateArtifacts || finalVisibleOutputResult.removedTemplateArtifacts
        let finalVisibleOutput = finalVisibleOutputResult.text
        let firstResponseLatencyMs = Int(Date().timeIntervalSince(generationStartedAt) * 1_000)
        let thinkingExtraction = LLMVisibleThinkingExtractor.extract(
            from: finalVisibleOutput,
            modelName: modelName,
            closeOpenThinkingBlock: true
        )
        let rawTailPreview = LoggingService.previewText(String(result.output.suffix(128)), maxLength: 128)
            .replacingOccurrences(of: "\n", with: "\\n")
        let rawCapHitStage: String? = {
            guard terminationReason == "raw_cap" || terminationReason == "answer_floor_reached" else { return nil }
            if limiter.lastStopStage == "post_answer" {
                return "post_answer"
            }
            if thinkingExtraction.hasVisibleThinking && thinkingExtraction.hasAnswer == false {
                return "thinking_only"
            }
            return limiter.lastStopStage ?? "pre_answer"
        }()

        logWarning(
            event: "chat_first_response_latency_ms",
            message: "First response latency measured for chat generation",
            fields: [
                "model_name": modelName,
                "latency_ms": String(firstResponseLatencyMs),
                "tokens_per_second": String(format: "%.3f", result.tokensPerSecond),
                "prewarm_hit": prewarmHit ? "true" : "false"
            ]
        )
        logWarning(
            event: "chat_generation_completed",
            message: "Chat generation completed",
            fields: [
                "model_name": modelName,
                "termination_reason": terminationReason,
                "generated_tokens": String(result.generationTokenCount),
                "raw_characters": String(result.output.count),
                "visible_characters": String(finalVisibleOutput.count),
                "sanitized_template_artifacts": removedTemplateArtifacts ? "true" : "false",
                "answer_phase_start_token": limiter.answerPhaseStartTokenCount.map(String.init) ?? "nil",
                "thinking_detected": thinkingExtraction.hasVisibleThinking ? "true" : "false",
                "thinking_format_detected": thinkingExtraction.mode,
                "raw_cap_threshold": String(maxRawTokens),
                "raw_cap_hit_stage": rawCapHitStage ?? "nil",
                "raw_tail_preview_128": rawTailPreview
            ]
        )

        return LLMInferenceGenerationResult(
            rawOutput: result.output,
            visibleOutput: finalVisibleOutput,
            tokensPerSecond: result.tokensPerSecond,
            generationTokenCount: result.generationTokenCount,
            removedTemplateArtifacts: removedTemplateArtifacts,
            terminationReason: terminationReason,
            firstResponseLatencyMs: firstResponseLatencyMs,
            prewarmHit: prewarmHit,
            answerPhaseStartTokenCount: limiter.answerPhaseStartTokenCount,
            rawCapHitStage: rawCapHitStage
        )
    }

    private func load(
        modelName: String,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }

        switch loadState {
        case let .loaded(loadedModelName, modelContainer):
            if loadedModelName == modelName {
                return modelContainer
            }
            unload()
        case .idle:
            break
        }

        if let inFlightLoadTask {
            if inFlightLoadTask.modelName == modelName {
                return try await inFlightLoadTask.task.value
            }
            inFlightLoadTask.task.cancel()
            self.inFlightLoadTask = nil
        }

        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let task = Task.detached(priority: .utility) { () async throws -> ModelContainer in
            try Task.checkCancellation()
            return try await LLMModelFactory.shared.loadContainer(configuration: model) { progress in
                onProgress?(progress.fractionCompleted)
            }
        }

        inFlightLoadTask = (modelName, task)

        do {
            let modelContainer = try await task.value
            loadState = .loaded(modelName: modelName, container: modelContainer)
            if inFlightLoadTask?.modelName == modelName {
                inFlightLoadTask = nil
            }
            return modelContainer
        } catch {
            if inFlightLoadTask?.modelName == modelName {
                inFlightLoadTask = nil
            }
            throw error
        }
    }

    private nonisolated static func answerPhaseTrigger(
        rawText: String,
        visibleText: String,
        isReasoningModel: Bool,
        requestOptions: LLMGenerationRequestOptions,
        modelName: String
    ) -> String? {
        if isReasoningModel == false {
            return "non_reasoning_stream"
        }

        if requestOptions.thinkingFormat == .taggedThinkBlocks, rawText.contains("</think>") {
            return "think_close"
        }

        let extraction = LLMVisibleThinkingExtractor.extract(
            from: visibleText,
            modelName: modelName,
            closeOpenThinkingBlock: false
        )
        if extraction.hasVisibleThinking && extraction.hasAnswer {
            return requestOptions.thinkingFormat == .plainTextPreamble
                ? "plain_text_thinking_answer"
                : "visible_answer_after_thinking"
        }

        if extraction.hasVisibleThinking == false &&
            visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "reasoning_without_visible_thinking"
        }

        return nil
    }
}
