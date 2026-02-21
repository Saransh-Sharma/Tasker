//
//  LLMEvaluator.swift
//
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
}

struct LLMGenerationProfile: Sendable {
    let name: String
    let maxTokens: Int
    let timeoutSeconds: TimeInterval
    let temperature: Double
    let displayEveryNTokens: Int

    static let chatAsk = LLMGenerationProfile(
        name: "chat_ask",
        maxTokens: 1_024,
        timeoutSeconds: 12,
        temperature: 0.5,
        displayEveryNTokens: 4
    )

    static let chatPlanJSON = LLMGenerationProfile(
        name: "chat_plan_json",
        maxTokens: 900,
        timeoutSeconds: 10,
        temperature: 0.15,
        displayEveryNTokens: 2
    )

    static let addTaskSuggestion = LLMGenerationProfile(
        name: "add_task_suggestion",
        maxTokens: 220,
        timeoutSeconds: 4,
        temperature: 0.25,
        displayEveryNTokens: 2
    )

    static let topThree = LLMGenerationProfile(
        name: "home_top_three",
        maxTokens: 260,
        timeoutSeconds: 5,
        temperature: 0.25,
        displayEveryNTokens: 2
    )

    static let breakdown = LLMGenerationProfile(
        name: "task_breakdown",
        maxTokens: 320,
        timeoutSeconds: 6,
        temperature: 0.3,
        displayEveryNTokens: 2
    )

    static let dailyBrief = LLMGenerationProfile(
        name: "daily_brief",
        maxTokens: 220,
        timeoutSeconds: 4,
        temperature: 0.35,
        displayEveryNTokens: 2
    )

    static let dynamicChips = LLMGenerationProfile(
        name: "dynamic_chips",
        maxTokens: 120,
        timeoutSeconds: 2.5,
        temperature: 0.3,
        displayEveryNTokens: 2
    )
}

@Observable
@MainActor
class LLMEvaluator {
    private final class CancellationToken: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        func set(_ newValue: Bool) {
            lock.lock()
            value = newValue
            lock.unlock()
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
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
    var lastGenerationTimedOut = false
    var lastGenerationFirstTokenLatencyMS: Int?
    var lastGenerationProfileName: String?
    private let cancellationToken = CancellationToken()

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
        loadState = .idle
        modelConfiguration = model
        _ = await warmup(modelName: model.name)
    }

    enum LoadState {
        case idle
        case loaded(modelName: String, container: ModelContainer)
    }

    var loadState = LoadState.idle

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model unless modelName changes.
    func load(modelName: String) async throws -> ModelContainer {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }

        switch loadState {
        case let .loaded(loadedModelName, container) where loadedModelName == modelName:
            return container
        case .loaded:
            loadState = .idle
        case .idle:
            break
        }

        // limit the buffer cache
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

        let modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: model) { progress in
            _Concurrency.Task { @MainActor in
                self.modelInfo = "Downloading \(model.name): \(Int(progress.fractionCompleted * 100))%"
                self.progress = progress.fractionCompleted
            }
        }
        modelInfo = "Loaded \(model.id). Weights: \(MLX.GPU.activeMemory / 1024 / 1024)M"
        loadState = .loaded(modelName: modelName, container: modelContainer)
        return modelContainer
    }

    /// Executes warmup.
    @discardableResult
    func warmup(modelName: String) async -> Bool {
        do {
            _ = try await load(modelName: modelName)
            return true
        } catch {
            modelInfo = "Warmup failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Executes isWarm.
    func isWarm(modelName: String) -> Bool {
        if case let .loaded(loadedModelName, _) = loadState {
            return loadedModelName == modelName
        }
        return false
    }

    /// Executes stop.
    func stop() {
        isThinking = false
        cancelled = true
        cancellationToken.set(true)
    }

    /// Executes generate.
    func generate(
        modelName: String,
        thread: Thread,
        systemPrompt: String,
        profile: LLMGenerationProfile = .chatAsk,
        onFirstToken: (@MainActor () -> Void)? = nil
    ) async -> String {
        guard !running else { return "" }

        running = true
        cancelled = false
        cancellationToken.set(false)
        output = ""
        startTime = Date()
        lastGenerationTimedOut = false
        lastGenerationFirstTokenLatencyMS = nil
        lastGenerationProfileName = profile.name
        let generationStartedAt = Date()

        let timeoutTask = _Concurrency.Task { [weak self] in
            let nanos = UInt64((profile.timeoutSeconds * 1_000_000_000).rounded())
            try? await _Concurrency.Task.sleep(nanoseconds: nanos)
            await MainActor.run {
                guard let self, self.running else { return }
                self.lastGenerationTimedOut = true
                self.cancelled = true
                self.cancellationToken.set(true)
            }
        }

        defer {
            timeoutTask.cancel()
            running = false
        }

        do {
            let modelContainer = try await load(modelName: modelName)

            // augment the prompt as needed
            let promptHistory = await modelContainer.configuration.getPromptHistory(thread: thread, systemPrompt: systemPrompt)

            if await modelContainer.configuration.modelType == .reasoning {
                isThinking = true
            }

            // each time you generate you will get something new
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

            let generateParameters = GenerateParameters(temperature: Float(profile.temperature))
            var emittedFirstToken = false

            // Streaming generation using latest MLX APIs
            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(input: .init(messages: promptHistory))

                return try MLXLMCommon.generate(
                    input: input,
                    parameters: generateParameters,
                    context: context
                ) { tokens in
                    let shouldCancel = self.cancellationToken.isCancelled

                    if !emittedFirstToken, tokens.isEmpty == false {
                        emittedFirstToken = true
                        let latencyMS = Int(Date().timeIntervalSince(generationStartedAt) * 1_000)
                        _Concurrency.Task { @MainActor in
                            self.lastGenerationFirstTokenLatencyMS = latencyMS
                            onFirstToken?()
                        }
                    }

                    // Throttle UI updates for performance.
                    let cadence = max(1, profile.displayEveryNTokens)
                    if tokens.count % cadence == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        _Concurrency.Task { @MainActor in
                            self.output = text
                        }
                    }

                    if tokens.count >= profile.maxTokens || shouldCancel || _Concurrency.Task.isCancelled {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // Ensure the final output is captured.
            if result.output != output {
                output = result.output
            }

            if lastGenerationTimedOut,
               output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output = "Timed out while generating. Please try again."
            }

            stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"
            thinkingTime = elapsedTime

        } catch {
            output = "Failed: \(error)"
        }

        return output
    }
}

@MainActor
final class LLMPrewarmCoordinator {
    static let shared = LLMPrewarmCoordinator()

    private let evaluator = LLMEvaluator()
    private var inFlightModels = Set<String>()
    private var lastWarmupAtByModel: [String: Date] = [:]
    private let throttleSeconds: TimeInterval = 120

    /// Executes prewarmCurrentModelIfNeeded.
    func prewarmCurrentModelIfNeeded(reason: String) {
        guard V2FeatureFlags.assistantCopilotEnabled else { return }
        let snapshot = AIRuntimeSnapshot.current()
        guard let modelName = snapshot.selectedModelName else { return }
        prewarm(modelName: modelName, reason: reason)
    }

    /// Executes prewarm.
    func prewarm(modelName: String, reason: String) {
        guard inFlightModels.contains(modelName) == false else { return }
        if evaluator.isWarm(modelName: modelName) { return }
        if let lastWarmupAt = lastWarmupAtByModel[modelName],
           Date().timeIntervalSince(lastWarmupAt) < throttleSeconds {
            return
        }

        inFlightModels.insert(modelName)
        let startedAt = Date()
        logWarning(
            event: "assistant_model_warmup_started",
            message: "Started model warmup",
            fields: [
                "model": modelName,
                "reason": reason
            ]
        )

        Task { [weak self] in
            guard let self else { return }
            let succeeded = await evaluator.warmup(modelName: modelName)
            let durationMS = Int(Date().timeIntervalSince(startedAt) * 1_000)
            await MainActor.run {
                self.inFlightModels.remove(modelName)
                self.lastWarmupAtByModel[modelName] = Date()
                if succeeded {
                    logWarning(
                        event: "assistant_model_warmup_completed",
                        message: "Model warmup completed",
                        fields: [
                            "model": modelName,
                            "reason": reason,
                            "duration_ms": String(durationMS)
                        ]
                    )
                } else {
                    logError(
                        event: "assistant_model_warmup_failed",
                        message: "Model warmup failed",
                        fields: [
                            "model": modelName,
                            "reason": reason,
                            "duration_ms": String(durationMS)
                        ]
                    )
                }
            }
        }
    }
}
