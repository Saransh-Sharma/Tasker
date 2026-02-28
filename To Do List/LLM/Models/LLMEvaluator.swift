//
//  LLMEvaluator.swift
//  fullmoon
//
//

import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI
import Foundation

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
}

enum LLMChatRuntimePhase: String {
    case idle
    case preparing
    case thinking
    case answering
    case stopping
    case finished
    case failed
}

final class LLMGenerationCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

@Observable
@MainActor
class LLMEvaluator {
    struct PrepareResult {
        let wasAlreadyLoaded: Bool
    }

    var running = false
    var cancelled = false
    var output = ""
    var modelInfo = ""
    var stat = ""
    var progress = 0.0
    var thinkingTime: TimeInterval?
    var collapsed: Bool = false
    var isThinking: Bool = false
    var lastGenerationTimedOut: Bool = false
    var runtimePhase: LLMChatRuntimePhase = .idle
    var answerPhaseSignalCount: Int = 0

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?
    private var generationCancellationToken = LLMGenerationCancellationToken()
    private var didEmitAnswerPhaseSignalForRun = false

    var modelConfiguration = ModelConfiguration.defaultModel

    /// Executes switchModel.
    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0 // reset progress
        unload()
        modelConfiguration = model
        _ = try? await load(modelName: model.name)
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.5)
    let maxTokens = 4096

    enum LoadState {
        case idle
        case loaded(modelName: String, container: ModelContainer)
    }

    var loadState = LoadState.idle
    private var inFlightLoadTask: (modelName: String, task: Task<ModelContainer, Error>)?

    var loadedModelName: String? {
        switch loadState {
        case .idle:
            return nil
        case .loaded(let modelName, _):
            return modelName
        }
    }

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load(modelName: String) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }
        modelConfiguration = model

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

        // limit the buffer cache
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let task = Task<ModelContainer, Error> {
            try await LLMModelFactory.shared.loadContainer(configuration: model) { progress in
                _Concurrency.Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(model.name): \(Int(progress.fractionCompleted * 100))%"
                    self.progress = progress.fractionCompleted
                }
            }
        }

        inFlightLoadTask = (modelName, task)

        do {
            let modelContainer = try await task.value
            modelInfo =
                "Loaded \(model.id).  Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
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

    func prepare(modelName: String) async throws -> PrepareResult {
        let wasAlreadyLoaded = loadedModelName == modelName
        _ = try await load(modelName: modelName)
        return PrepareResult(wasAlreadyLoaded: wasAlreadyLoaded)
    }

    func unload() {
        inFlightLoadTask?.task.cancel()
        inFlightLoadTask = nil
        generationCancellationToken.cancel()
        loadState = .idle
        progress = 0
        isThinking = false
        running = false
        cancelled = false
        runtimePhase = .idle
        modelInfo = "Model unloaded"
    }

    func cancelGeneration(reason: String = "unknown") {
        cancelled = true
        isThinking = false
        if runtimePhase == .preparing {
            inFlightLoadTask?.task.cancel()
            inFlightLoadTask = nil
        }
        generationCancellationToken.cancel()
        guard running else {
            if runtimePhase == .preparing || runtimePhase == .thinking || runtimePhase == .answering {
                runtimePhase = .stopping
            }
            return
        }
        runtimePhase = .stopping
        logWarning(
            event: "chat_generation_cancel_requested",
            message: "Cancellation requested for active chat generation",
            fields: [
                "reason": reason,
                "phase": runtimePhase.rawValue
            ]
        )
    }

    /// Executes stop.
    func stop() {
        cancelGeneration(reason: "stop_button")
    }

    /// Executes generate.
    func generate(
        modelName: String,
        thread: Thread,
        systemPrompt: String,
        profile: LLMGenerationProfile = .chat,
        onFirstToken: (@MainActor () -> Void)? = nil
    ) async -> String {
        lastGenerationTimedOut = false
        let timeoutMs = UInt64(max(profile.timeoutSeconds, 0) * 1_000)
        guard timeoutMs > 0 else {
            return await runGeneration(
                modelName: modelName,
                thread: thread,
                systemPrompt: systemPrompt,
                onFirstToken: onFirstToken
            )
        }

        let (result, timedOut) = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) { [weak self] in
            guard let self else { return "{}" }
            return await self.runGeneration(
                modelName: modelName,
                thread: thread,
                systemPrompt: systemPrompt,
                onFirstToken: onFirstToken
            )
        }

        lastGenerationTimedOut = timedOut
        if timedOut {
            cancelGeneration(reason: "generation_timeout")
        }
        return result
    }

    /// Executes runGeneration.
    private func runGeneration(
        modelName: String,
        thread: Thread,
        systemPrompt: String,
        onFirstToken: (@MainActor () -> Void)?
    ) async -> String {
        guard !running else { return "" }

        let streamBudgets = LLMChatBudgets.active
        let outputTokenStride = max(1, streamBudgets.outputTokenStride)
        let outputMinUpdateNanoseconds = streamBudgets.outputMinUpdateIntervalMs * 1_000_000

        running = true
        cancelled = false
        output = ""
        stat = ""
        thinkingTime = nil
        startTime = Date()
        runtimePhase = .preparing
        didEmitAnswerPhaseSignalForRun = false
        let generationStartedAt = Date()
        let prewarmHit = loadedModelName == modelName

        let runCancellationToken = LLMGenerationCancellationToken()
        generationCancellationToken = runCancellationToken

        defer {
            runCancellationToken.cancel()
            running = false
            isThinking = false
            startTime = nil
            if runtimePhase != .failed {
                runtimePhase = .finished
            }
        }

        do {
            let modelContainer = try await load(modelName: modelName)
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }
            let isReasoningModel = await modelContainer.configuration.modelType == .reasoning
            if isReasoningModel {
                runtimePhase = .thinking
                isThinking = true
            } else {
                runtimePhase = .answering
                isThinking = false
            }

            var firstTokenLogged = false
            var lastOutputUpdateNanoseconds: UInt64 = 0
            var decodedTokenCount = 0
            var streamedOutputText = ""

            // augment the prompt as needed
            let promptBuildStartedAt = Date()
            let promptHistory = await modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }
            let promptBuildMs = Int(Date().timeIntervalSince(promptBuildStartedAt) * 1_000)
            let promptChars = promptHistory.reduce(0) { partial, item in
                partial + (item["content"]?.count ?? 0)
            }
            logWarning(
                event: "chat_prompt_build_ms",
                message: "Built prompt history for generation",
                fields: [
                    "model_name": modelName,
                    "duration_ms": String(promptBuildMs),
                    "message_count": String(promptHistory.count),
                    "prompt_chars": String(promptChars)
                ]
            )

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }

            // Streaming generation using latest MLX APIs
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
                        _Concurrency.Task { @MainActor in
                            onFirstToken?()
                            if isReasoningModel == false {
                                self.markAnswerPhaseStarted(modelName: modelName, trigger: "first_token")
                            }
                        }
                        let firstTokenLatencyMs = Int(Date().timeIntervalSince(generationStartedAt) * 1_000)
                        _Concurrency.Task { @MainActor in
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
                    }

                    let nowNanoseconds = DispatchTime.now().uptimeNanoseconds
                    let hasTokens = tokens.isEmpty == false
                    let shouldUpdateByStride = hasTokens && tokens.count % outputTokenStride == 0
                    let shouldUpdateByTime = hasTokens && outputMinUpdateNanoseconds > 0 && (
                        lastOutputUpdateNanoseconds == 0 ||
                        nowNanoseconds &- lastOutputUpdateNanoseconds >= outputMinUpdateNanoseconds
                    )
                    let shouldPublishUpdate = hasTokens && (shouldUpdateByStride || shouldUpdateByTime || tokens.count == 1)

                    if shouldPublishUpdate {
                        lastOutputUpdateNanoseconds = nowNanoseconds
                        if tokens.count < decodedTokenCount {
                            // Fallback for unexpected token stream resets.
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
                        let text = streamedOutputText
                        _Concurrency.Task { @MainActor in
                            self.handleStreamUpdate(
                                text: text,
                                isReasoningModel: isReasoningModel,
                                modelName: modelName
                            )
                        }
                    }

                    if tokens.count >= self.maxTokens || runCancellationToken.isCancelled {
                        return .stop
                    }
                    return .more
                }
            }

            // Ensure the final output is captured
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }
            if result.output != output {
                output = result.output
            }

            stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
            thinkingTime = elapsedTime
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

        } catch is CancellationError {
            logWarning(
                event: "chat_generation_cancelled",
                message: "Generation task cancelled before completion",
                fields: [
                    "model_name": modelName,
                    "phase": runtimePhase.rawValue,
                    "cancelled_flag": cancelled ? "true" : "false"
                ]
            )
        } catch {
            runtimePhase = .failed
            output = "Failed: \(error)"
            logError(
                event: "chat_generation_failed",
                message: "Generation failed before completion",
                fields: [
                    "model_name": modelName,
                    "phase": runtimePhase.rawValue,
                    "error": error.localizedDescription
                ]
            )
        }

        return output
    }

    private func handleStreamUpdate(
        text: String,
        isReasoningModel: Bool,
        modelName: String
    ) {
        output = text
        if isReasoningModel {
            if runtimePhase == .thinking {
                if text.contains("</think>") {
                    markAnswerPhaseStarted(modelName: modelName, trigger: "think_close")
                } else if text.contains("<think>") == false &&
                    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    markAnswerPhaseStarted(modelName: modelName, trigger: "reasoning_without_think_block")
                }
            }
        } else {
            markAnswerPhaseStarted(modelName: modelName, trigger: "non_reasoning_stream")
        }
    }

    private func markAnswerPhaseStarted(modelName: String, trigger: String) {
        guard didEmitAnswerPhaseSignalForRun == false else { return }
        didEmitAnswerPhaseSignalForRun = true
        runtimePhase = .answering
        isThinking = false
        answerPhaseSignalCount += 1
        logWarning(
            event: "chat_answer_phase_started",
            message: "Detected response answer phase during streaming",
            fields: [
                "model_name": modelName,
                "trigger": trigger,
                "signal_count": String(answerPhaseSignalCount)
            ]
        )
    }
}
