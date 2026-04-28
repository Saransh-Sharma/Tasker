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

private actor LLMGenerationSlot {
    private var isOccupied = false
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

    func acquire() async throws -> LLMGenerationSlotLease {
        if _Concurrency.Task.isCancelled {
            throw CancellationError()
        }
        if isOccupied == false {
            isOccupied = true
            return LLMGenerationSlotLease(slot: self)
        }
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append((waiterID, continuation))
            }
        } onCancel: {
            _Concurrency.Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
        if _Concurrency.Task.isCancelled {
            release()
            throw CancellationError()
        }
        return LLMGenerationSlotLease(slot: self)
    }

    fileprivate func release() {
        if waiters.isEmpty {
            isOccupied = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

private struct LLMGenerationSlotLease: Sendable {
    fileprivate let slot: LLMGenerationSlot

    func release() async {
        await slot.release()
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
    var lastRawOutput: String = ""
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
    private var pendingVisibleOutput = ""
    private var hasPendingVisibleOutput = false
    private var lastVisibleOutputPublishAt = Date.distantPast
    private let inferenceEngine: LLMInferenceEngine
    private let generationSlot = LLMGenerationSlot()
    private let streamPublishThrottleInterval: TimeInterval = 1.0 / 24.0

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
        TaskerMemoryDiagnostics.checkpoint(
            event: "llm_prepare_started",
            message: "Preparing LLM model",
            fields: ["model_name": modelName]
        )
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
        TaskerMemoryDiagnostics.checkpoint(
            event: "llm_prepare_finished",
            message: "Prepared LLM model",
            fields: ["model_name": modelName]
        )
        return PrepareResult(wasAlreadyLoaded: prepareResult.wasAlreadyLoaded)
    }

    func unload() {
        Task {
            await unloadNow()
        }
    }

    func unloadNow() async {
        let previousModelName = loadedModelName
        await inferenceEngine.unload()
        resetRuntimeStateForUnload()
        TaskerMemoryDiagnostics.checkpoint(
            event: "llm_unload_finished",
            message: "Released evaluator model state",
            fields: ["model_name": previousModelName ?? "none"]
        )
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

    func beginUserTurn(runID: UUID) {
        cancelled = false
        output = ""
        pendingVisibleOutput = ""
        hasPendingVisibleOutput = false
        lastVisibleOutputPublishAt = .distantPast
        stat = ""
        thinkingTime = nil
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastRawOutput = ""
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false
        didEmitAnswerPhaseSignalForRun = false
        logWarning(
            event: "chat_user_turn_started",
            message: "Cleared stale evaluator output state for accepted chat turn",
            fields: ["run_id": runID.uuidString]
        )
    }

    /// Executes generate.
    func generate(
        modelName: String,
        thread: Thread,
        systemPrompt: String,
        profile: LLMGenerationProfile = .chat,
        requestOptions: LLMGenerationRequestOptions? = nil,
        onFirstToken: (@MainActor () -> Void)? = nil
    ) async -> String {
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastRawOutput = ""
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false

        let timeoutMs = UInt64(max(profile.timeoutSeconds, 0) * 1_000)
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            runtimePhase = .failed
            output = "Failed: model not found"
            return output
        }

        let promptBuildStartedAt = Date()
        let chatMessages = model.getChatMessages(thread: thread, systemPrompt: systemPrompt)
        let promptBuildMs = Int(Date().timeIntervalSince(promptBuildStartedAt) * 1_000)
        let promptChars = chatMessages.reduce(0) { partial, item in
            partial + item.content.count
        }
        let promptHistoryChars = chatMessages.dropFirst().reduce(0) { partial, item in
            partial + item.content.count
        }
        logWarning(
            event: "chat_prompt_build_ms",
            message: "Built prompt history for generation",
            fields: [
                "model_name": modelName,
                "duration_ms": String(promptBuildMs),
                "message_count": String(chatMessages.count),
                "system_prompt_chars": String(systemPrompt.count),
                "prompt_history_chars": String(promptHistoryChars),
                "final_prompt_chars": String(promptChars)
            ]
        )

        guard timeoutMs > 0 else {
            return await runGeneration(
                modelName: modelName,
                chatMessages: chatMessages,
                profile: profile,
                requestOptions: requestOptions,
                onFirstToken: onFirstToken
            )
        }

        let (result, timedOut) = await LLMProjectionTimeout.execute(timeoutMs: timeoutMs) { [weak self] in
            guard let self else { return "{}" }
            return await self.runGeneration(
                modelName: modelName,
                chatMessages: chatMessages,
                profile: profile,
                requestOptions: requestOptions,
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
        chatMessages: [Chat.Message],
        profile: LLMGenerationProfile,
        requestOptions: LLMGenerationRequestOptions?,
        onFirstToken: (@MainActor () -> Void)?
    ) async -> String {
        let waitStartedAt = Date()
        let wasQueued = running
        if wasQueued {
            logWarning(
                event: "chat_generation_queue_waiting",
                message: "Generation requested while evaluator is busy; waiting for active generation to finish",
                fields: ["model_name": modelName]
            )
        }
        let slotLease: LLMGenerationSlotLease
        do {
            slotLease = try await generationSlot.acquire()
        } catch {
            lastTerminationReason = "cancelled_while_waiting_for_generation_slot"
            return ""
        }
        if wasQueued {
            logWarning(
                event: "chat_generation_queue_acquired",
                message: "Queued generation acquired evaluator slot",
                fields: [
                    "model_name": modelName,
                    "wait_ms": String(Int(Date().timeIntervalSince(waitStartedAt) * 1_000))
                ]
            )
        }
        guard let model = ModelConfiguration.getModelByName(modelName) else {
            await slotLease.release()
            runtimePhase = .failed
            output = "Failed: model not found"
            return output
        }

        running = true
        cancelled = false
        output = ""
        pendingVisibleOutput = ""
        hasPendingVisibleOutput = false
        lastVisibleOutputPublishAt = .distantPast
        stat = ""
        progress = 0.0
        thinkingTime = nil
        startTime = Date()
        runtimePhase = .preparing
        didEmitAnswerPhaseSignalForRun = false

        let runCancellationToken = LLMGenerationCancellationToken()
        generationCancellationToken = runCancellationToken
        var lastAnswerPhaseStartToken: Int?
        var lastRawCapHitStage: String?

        defer {
            _Concurrency.Task {
                await slotLease.release()
            }
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
            if Task.isCancelled || runCancellationToken.isCancelled {
                throw CancellationError()
            }

            let resolvedRequestOptions = requestOptions ?? .structuredOutput(for: model)
            let isReasoningModel = resolvedRequestOptions.isReasoningEnabled
            if isReasoningModel {
                runtimePhase = .thinking
                isThinking = true
            } else {
                runtimePhase = .answering
                isThinking = false
            }

            let generationResult = try await inferenceEngine.generate(
                modelName: modelName,
                chatMessages: chatMessages,
                profile: profile,
                requestOptions: resolvedRequestOptions,
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
                            tokenCount: update.tokenCount,
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
            lastRawOutput = generationResult.rawOutput
            flushPendingVisibleOutput(force: true)
            if generationResult.visibleOutput != output {
                output = generationResult.visibleOutput
            }
            stat = " Tokens/second: \(String(format: "%.3f", generationResult.tokensPerSecond))"
            thinkingTime = elapsedTime
            lastTerminationReason = generationResult.terminationReason
            lastGeneratedTokenCount = generationResult.generationTokenCount
            lastVisibleCharacterCount = generationResult.visibleOutput.count
            lastSanitizedTemplateArtifacts = generationResult.removedTemplateArtifacts
            lastAnswerPhaseStartToken = generationResult.answerPhaseStartTokenCount
            lastRawCapHitStage = generationResult.rawCapHitStage
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

        if output.hasPrefix("Failed: ") == false {
            logWarning(
                event: "chat_generation_success_returned_to_view",
                message: "Generation succeeded and is returning output to chat view",
                fields: [
                    "model_name": modelName,
                    "generation_model": modelName,
                    "raw_output_length": String(lastRawOutput.count),
                    "output_length": String(lastVisibleCharacterCount),
                    "termination_reason": lastTerminationReason ?? "unknown",
                    "visible_generation_time_ms": String(Int((thinkingTime ?? 0) * 1_000)),
                    "token_count": String(lastGeneratedTokenCount),
                    "answer_phase_start_token": lastAnswerPhaseStartToken.map(String.init) ?? "nil",
                    "raw_cap_hit_stage": lastRawCapHitStage ?? "nil"
                ]
            )
        }

        if output.hasPrefix("Failed: ") {
            return output
        }
        // Return raw output for downstream assessment; display sanitization happens later in ChatView.
        return lastRawOutput.isEmpty ? output : lastRawOutput
    }

    private func handleStreamUpdate(
        rawText: String,
        visibleText: String,
        phaseTrigger: String?,
        tokenCount: Int,
        isReasoningModel: Bool,
        modelName: String
    ) {
        enqueueVisibleOutput(visibleText)
        if isReasoningModel, runtimePhase == .thinking, let phaseTrigger {
            markAnswerPhaseStarted(modelName: modelName, trigger: phaseTrigger, tokenCount: tokenCount)
        }
    }

    private func enqueueVisibleOutput(_ text: String) {
        guard output != text else { return }
        pendingVisibleOutput = text
        hasPendingVisibleOutput = true
        flushPendingVisibleOutput(force: false)
    }

    private func flushPendingVisibleOutput(force: Bool) {
        guard hasPendingVisibleOutput else { return }
        let now = Date()
        if force || now.timeIntervalSince(lastVisibleOutputPublishAt) >= streamPublishThrottleInterval {
            hasPendingVisibleOutput = false
            lastVisibleOutputPublishAt = now
            if output != pendingVisibleOutput {
                output = pendingVisibleOutput
            }
        }
    }

    private func markAnswerPhaseStarted(modelName: String, trigger: String, tokenCount: Int) {
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
                "signal_count": String(answerPhaseSignalCount),
                "token_count": String(tokenCount)
            ]
        )
    }

    private func resetRuntimeStateForUnload() {
        loadedModelName = nil
        progress = 0
        output = ""
        pendingVisibleOutput = ""
        hasPendingVisibleOutput = false
        lastVisibleOutputPublishAt = .distantPast
        stat = ""
        thinkingTime = nil
        isThinking = false
        running = false
        cancelled = false
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastRawOutput = ""
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false
        answerPhaseSignalCount = 0
        runtimePhase = .idle
        startTime = nil
        modelInfo = "Model unloaded"
    }
}
