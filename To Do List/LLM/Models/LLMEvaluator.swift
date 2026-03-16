//
//  LLMEvaluator.swift
//  fullmoon
//
//

import Foundation
import MLXLMCommon
import SwiftUI

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
    case unsupportedRuntime(String, String)
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
    var lastTerminationReason: String?
    var lastGeneratedTokenCount: Int = 0
    var lastVisibleCharacterCount: Int = 0
    var lastSanitizedTemplateArtifacts: Bool = false
    var runtimePhase: LLMChatRuntimePhase = .idle
    var answerPhaseSignalCount: Int = 0
    var loadedModelName: String?

    var elapsedTime: TimeInterval? {
        guard let startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    var generationStartedAt: Date? {
        startTime
    }

    private var startTime: Date?
    private var generationCancellationToken = LLMGenerationCancellationToken()
    private var didEmitAnswerPhaseSignalForRun = false
    private let inferenceEngine: LLMInferenceEngine

    var modelConfiguration = ModelConfiguration.defaultModel

    init(inferenceEngine: LLMInferenceEngine = LLMInferenceEngine()) {
        self.inferenceEngine = inferenceEngine
    }

    /// Executes switchModel.
    func switchModel(_ model: ModelConfiguration) async {
        progress = 0.0
        modelConfiguration = model
        _ = try? await prepare(modelName: model.name)
    }

    func prepare(modelName: String) async throws -> PrepareResult {
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            throw LLMEvaluatorError.modelNotFound(modelName)
        }
        let compatibility = LLMRuntimeSupportMatrix.compatibility(for: model)
        guard compatibility.canActivate else {
            throw LLMEvaluatorError.unsupportedRuntime(modelName, compatibility.prepareFailureMessage)
        }

        modelConfiguration = model
        let prepareResult = try await inferenceEngine.prepare(modelName: modelName) { [weak self] fractionCompleted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.modelInfo = "Downloading \(model.name): \(Int(fractionCompleted * 100))%"
                self.progress = fractionCompleted
            }
        }
        loadedModelName = modelName
        modelInfo = prepareResult.modelInfo
        progress = 1.0
        return PrepareResult(wasAlreadyLoaded: prepareResult.wasAlreadyLoaded)
    }

    func unload() {
        Task {
            await unloadNow()
        }
    }

    func unloadNow() async {
        await inferenceEngine.unload()
        resetRuntimeStateForUnload()
    }

    func cancelGeneration(reason: String = "unknown") {
        cancelled = true
        isThinking = false
        let shouldCancelLoad = runtimePhase == .preparing
        generationCancellationToken.cancel()
        Task {
            await inferenceEngine.cancelGeneration(cancelLoad: shouldCancelLoad)
        }
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
        lastTerminationReason = nil
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false

        let timeoutMs = UInt64(max(profile.timeoutSeconds, 0) * 1_000)
        guard timeoutMs > 0 else {
            return await runGeneration(
                modelName: modelName,
                thread: thread,
                systemPrompt: systemPrompt,
                profile: profile,
                onFirstToken: onFirstToken
            )
        }

        let (result, timedOut) = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) { [weak self] in
            guard let self else { return "{}" }
            return await self.runGeneration(
                modelName: modelName,
                thread: thread,
                systemPrompt: systemPrompt,
                profile: profile,
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
        profile: LLMGenerationProfile,
        onFirstToken: (@MainActor () -> Void)?
    ) async -> String {
        guard !running else { return "" }
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            runtimePhase = .failed
            output = "Failed: model not found"
            return output
        }

        running = true
        cancelled = false
        output = ""
        stat = ""
        progress = 0.0
        thinkingTime = nil
        startTime = Date()
        runtimePhase = .preparing
        didEmitAnswerPhaseSignalForRun = false

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
            modelConfiguration = model

            let promptBuildStartedAt = Date()
            let promptHistory = model.getPromptHistory(thread: thread, systemPrompt: systemPrompt)
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }
            let promptBuildMs = Int(Date().timeIntervalSince(promptBuildStartedAt) * 1_000)
            let promptChars = promptHistory.reduce(0) { partial, item in
                partial + (item["content"]?.count ?? 0)
            }
            let promptHistoryChars = promptHistory.dropFirst().reduce(0) { partial, item in
                partial + (item["content"]?.count ?? 0)
            }
            logWarning(
                event: "chat_prompt_build_ms",
                message: "Built prompt history for generation",
                fields: [
                    "model_name": modelName,
                    "duration_ms": String(promptBuildMs),
                    "message_count": String(promptHistory.count),
                    "system_prompt_chars": String(systemPrompt.count),
                    "prompt_history_chars": String(promptHistoryChars),
                    "final_prompt_chars": String(promptChars)
                ]
            )

            let isReasoningModel = model.modelType == .reasoning
            if isReasoningModel {
                runtimePhase = .thinking
                isThinking = true
            } else {
                runtimePhase = .answering
                isThinking = false
            }

            let generationResult = try await inferenceEngine.generate(
                modelName: modelName,
                promptHistory: promptHistory,
                profile: profile,
                onFirstToken: {
                    Task { @MainActor in
                        onFirstToken?()
                    }
                },
                onStreamUpdate: { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.handleStreamUpdate(
                            rawText: update.rawText,
                            visibleText: update.visibleText,
                            phaseTrigger: update.phaseTrigger,
                            isReasoningModel: isReasoningModel,
                            modelName: modelName
                        )
                    }
                }
            )

            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }

            loadedModelName = modelName
            progress = 1.0
            if generationResult.output != output {
                output = generationResult.output
            }
            stat = " Tokens/second: \(String(format: "%.3f", generationResult.tokensPerSecond))"
            thinkingTime = elapsedTime
            lastTerminationReason = generationResult.terminationReason
            lastGeneratedTokenCount = generationResult.generationTokenCount
            lastVisibleCharacterCount = generationResult.output.count
            lastSanitizedTemplateArtifacts = generationResult.removedTemplateArtifacts
        } catch is CancellationError {
            let cancellationReason = cancelled ? "user_cancel" : "timeout"
            lastTerminationReason = cancellationReason
            logWarning(
                event: "chat_generation_cancelled",
                message: "Generation task cancelled before completion",
                fields: [
                    "model_name": modelName,
                    "phase": runtimePhase.rawValue,
                    "cancelled_flag": cancelled ? "true" : "false",
                    "termination_reason": cancellationReason
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
        rawText: String,
        visibleText: String,
        phaseTrigger: String?,
        isReasoningModel: Bool,
        modelName: String
    ) {
        output = visibleText
        if isReasoningModel, runtimePhase == .thinking, let phaseTrigger {
            markAnswerPhaseStarted(modelName: modelName, trigger: phaseTrigger)
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

    private func resetRuntimeStateForUnload() {
        loadedModelName = nil
        progress = 0
        output = ""
        stat = ""
        thinkingTime = nil
        isThinking = false
        running = false
        cancelled = false
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false
        answerPhaseSignalCount = 0
        runtimePhase = .idle
        startTime = nil
        modelInfo = "Model unloaded"
    }
}
