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

    var elapsedTime: TimeInterval? {
        if let startTime {
            return Date().timeIntervalSince(startTime)
        }

        return nil
    }

    private var startTime: Date?

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

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

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
        loadState = .idle
        progress = 0
        isThinking = false
        modelInfo = "Model unloaded"
    }

    /// Executes stop.
    func stop() {
        isThinking = false
        cancelled = true
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

        running = true
        cancelled = false
        output = ""
        startTime = Date()
        let generationStartedAt = Date()
        let prewarmHit = loadedModelName == modelName

        do {
            let modelContainer = try await load(modelName: modelName)
            var firstTokenLogged = false

            // augment the prompt as needed
            let promptHistory = await modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)

            if await modelContainer.configuration.modelType == .reasoning {
                isThinking = true
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            // Streaming generation using latest MLX APIs
            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: .init(messages: promptHistory))

                return try MLXLMCommon.generate(
                    input: input,
                    parameters: generateParameters,
                    context: context
                ) { tokens in
                    if !firstTokenLogged, !tokens.isEmpty {
                        firstTokenLogged = true
                        _Concurrency.Task { @MainActor in
                            onFirstToken?()
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

                    var shouldCancel = false
                    _Concurrency.Task { @MainActor in
                        shouldCancel = self.cancelled
                    }

                    // Throttle UI updates to every N tokens for performance
                    if tokens.count % self.displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        _Concurrency.Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= self.maxTokens || shouldCancel {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // Ensure the final output is captured
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

        } catch {
            output = "Failed: \(error)"
        }

        isThinking = false
        running = false
        return output
    }
}
