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
}

struct LLMInferenceGenerationResult {
    let output: String
    let tokensPerSecond: Double
    let generationTokenCount: Int
    let removedTemplateArtifacts: Bool
    let terminationReason: String
    let firstResponseLatencyMs: Int
    let prewarmHit: Bool
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
        promptHistory: [[String: String]],
        profile: LLMGenerationProfile,
        onFirstToken: (@Sendable () -> Void)? = nil,
        onStreamUpdate: (@Sendable (LLMInferenceStreamUpdate) -> Void)? = nil
    ) async throws -> LLMInferenceGenerationResult {
        let streamBudgets = LLMChatBudgets.active
        let outputTokenStride = max(1, streamBudgets.outputTokenStride)
        let outputMinUpdateNanoseconds = streamBudgets.outputMinUpdateIntervalMs * 1_000_000
        let generationStartedAt = Date()
        let prewarmHit = loadedModelName == modelName

        let runCancellationToken = LLMGenerationCancellationToken()
        generationCancellationToken = runCancellationToken

        let modelContainer = try await load(modelName: modelName)
        if Task.isCancelled || runCancellationToken.isCancelled {
            throw CancellationError()
        }

        let isReasoningModel = await modelContainer.configuration.modelType == .reasoning
        let generateParameters = GenerateParameters(
            maxTokens: profile.maxRawTokens(isReasoningModel: isReasoningModel),
            temperature: profile.temperature,
            topP: profile.topP,
            repetitionPenalty: profile.repetitionPenalty,
            repetitionContextSize: profile.repetitionContextSize
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
            maxRawTokens: profile.maxRawTokens(isReasoningModel: isReasoningModel),
            minAnswerTokensAfterAnswerPhase: profile.minAnswerTokensAfterAnswerPhase(
                isReasoningModel: isReasoningModel
            )
        )
        var terminationReason = "eos"
        var removedTemplateArtifacts = false

        let result = try await modelContainer.perform { context in
            let input = try await context.processor.prepare(input: .init(messages: promptHistory))
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
                        profile: profile
                    )
                    removedTemplateArtifacts = removedTemplateArtifacts || visibleTextResult.removedTemplateArtifacts
                    let phaseTrigger = Self.answerPhaseTrigger(
                        rawText: rawText,
                        visibleText: visibleTextResult.text,
                        isReasoningModel: isReasoningModel
                    )
                    if phaseTrigger != nil {
                        limiter.markAnswerPhaseStarted(currentTokenCount: tokens.count)
                    }
                    onStreamUpdate?(
                        LLMInferenceStreamUpdate(
                            rawText: rawText,
                            visibleText: visibleTextResult.text,
                            phaseTrigger: phaseTrigger
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
            profile: profile
        )
        removedTemplateArtifacts = removedTemplateArtifacts || finalVisibleOutputResult.removedTemplateArtifacts
        let finalVisibleOutput = finalVisibleOutputResult.text
        let firstResponseLatencyMs = Int(Date().timeIntervalSince(generationStartedAt) * 1_000)

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
                "visible_characters": String(finalVisibleOutput.count),
                "sanitized_template_artifacts": removedTemplateArtifacts ? "true" : "false"
            ]
        )

        return LLMInferenceGenerationResult(
            output: finalVisibleOutput,
            tokensPerSecond: result.tokensPerSecond,
            generationTokenCount: result.generationTokenCount,
            removedTemplateArtifacts: removedTemplateArtifacts,
            terminationReason: terminationReason,
            firstResponseLatencyMs: firstResponseLatencyMs,
            prewarmHit: prewarmHit
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
        isReasoningModel: Bool
    ) -> String? {
        if isReasoningModel == false {
            return "non_reasoning_stream"
        }

        if rawText.contains("</think>") {
            return "think_close"
        }

        if rawText.contains("<think>") == false &&
            visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "reasoning_without_think_block"
        }

        return nil
    }
}
