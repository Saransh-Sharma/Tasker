//
//  LLMEvaluator.swift
//  fullmoon
//
//

import Foundation
import MLXLMCommon
import Synchronization
import SwiftUI

// MLX chat messages are immutable prompt values crossing task boundaries here.
extension Chat.Message: @unchecked @retroactive Sendable {}

enum LLMEvaluatorError: Error {
    case modelNotFound(String)
    case unsupportedRuntime(String, String)
}

struct LLMChatPromptSnapshot: Sendable {
    let messages: [Chat.Message]
    let systemPromptCharacterCount: Int
    let buildDurationMs: Int
    let cloudContext: [EvaCloudContextSection]
    let userInstructions: EvaUserInstructions?

    init(
        messages: [Chat.Message],
        systemPromptCharacterCount: Int,
        buildDurationMs: Int,
        cloudContext: [EvaCloudContextSection] = [],
        userInstructions: EvaUserInstructions? = nil
    ) {
        self.messages = messages
        self.systemPromptCharacterCount = systemPromptCharacterCount
        self.buildDurationMs = buildDurationMs
        self.cloudContext = cloudContext
        self.userInstructions = userInstructions
    }

    var messageCount: Int {
        messages.count
    }

    var promptCharacterCount: Int {
        messages.reduce(0) { partial, item in
            partial + item.content.count
        }
    }

    var promptHistoryCharacterCount: Int {
        messages.dropFirst().reduce(0) { partial, item in
            partial + item.content.count
        }
    }
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

final class LLMGenerationCancellationToken: Sendable {
    private let cancelled = Mutex(false)

    var isCancelled: Bool {
        cancelled.withLock { $0 }
    }

    func cancel() {
        cancelled.withLock { $0 = true }
    }
}

actor LLMGenerationSlot {
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

struct LLMGenerationSlotLease: Sendable {
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
    var lastSettledPhraseCharacterCount = 0
    var phraseSettlementSequence = 0

    var elapsedTime: TimeInterval? {
        guard let startTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    var generationStartedAt: Date? {
        startTime
    }

    var startTime: Date?
    var generationCancellationToken = LLMGenerationCancellationToken()
    private var didEmitAnswerPhaseSignalForRun = false
    var pendingVisibleOutput = ""
    var cumulativePhraseSettler = CumulativePhraseSettler()
    private let inferenceEngine: LLMInferenceService
    let providerRouter: EvaProviderRouter
    let generationSlot = LLMGenerationSlot()

    var modelConfiguration = ModelConfiguration.defaultModel

    init(
        inferenceEngine: LLMInferenceService = LLMInferenceService(),
        providerRouter: EvaProviderRouter = .shared
    ) {
        self.inferenceEngine = inferenceEngine
        self.providerRouter = providerRouter
    }

    /// Shapes a thread into a prompt snapshot and delegates to the routing entry
    /// point.
    ///
    /// `modelName` may be the cloud routing sentinel rather than an installed MLX
    /// model, so this must not require a local `ModelConfiguration`. It previously
    /// did, and every caller on this overload — daily brief, top three, task
    /// breakdown, field suggestion, planner, plan repair, Shortcuts — returned
    /// "Failed: model not found" the moment Cloud EVA was selected, silently
    /// falling back to heuristics without ever reaching the network. The default
    /// configuration stands in only to shape messages; whether any of that reaches
    /// a local runtime is decided by the provider branch in the snapshot overload,
    /// which still refuses an unknown model on the offline path.
    func generate(
        modelName: String,
        thread: Thread,
        systemPrompt: String,
        profile: LLMGenerationProfile = .chat,
        requestOptions: LLMGenerationRequestOptions? = nil,
        cloudContext: [EvaCloudContextSection] = [],
        turnRuntime: EvaTurnRuntime? = nil,
        onFirstToken: (@MainActor @Sendable () -> Void)? = nil
    ) async -> String {
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastRawOutput = ""
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false
        let model = ModelConfiguration.getModelByName(modelName) ?? .defaultModel
        let startedAt = Date()
        let snapshot = LLMChatPromptSnapshot(
            messages: model.getChatMessages(thread: thread, systemPrompt: systemPrompt),
            systemPromptCharacterCount: systemPrompt.count,
            buildDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000),
            cloudContext: cloudContext
        )
        return await generate(
            modelName: modelName,
            promptSnapshot: snapshot,
            profile: profile,
            requestOptions: requestOptions,
            turnRuntime: turnRuntime,
            onFirstToken: onFirstToken
        )
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
        MemoryDiagnostics.checkpoint(
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
        MemoryDiagnostics.checkpoint(
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
        MemoryDiagnostics.checkpoint(
            event: "llm_unload_finished",
            message: "Released evaluator model state",
            fields: ["model_name": previousModelName ?? "none"]
        )
    }

    func cancelGeneration(reason: String = "unknown") {
        cancelled = true
        isThinking = false
        output = cumulativePhraseSettler.stopDiscardingUncommitted()
        pendingVisibleOutput = output
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
        cumulativePhraseSettler = CumulativePhraseSettler()
        lastSettledPhraseCharacterCount = 0
        phraseSettlementSequence = 0
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

    /// Executes runGeneration.
    func runGeneration(
        modelName: String,
        chatMessages: [Chat.Message],
        profile: LLMGenerationProfile,
        requestOptions: LLMGenerationRequestOptions?,
        onFirstToken: (@MainActor @Sendable () -> Void)?
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
        cumulativePhraseSettler = CumulativePhraseSettler()
        lastSettledPhraseCharacterCount = 0
        phraseSettlementSequence = 0
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
            pendingVisibleOutput = generationResult.visibleOutput
            flushPendingVisibleOutput(force: true)
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

    func enqueueVisibleOutput(_ text: String) {
        pendingVisibleOutput = text
        let update = cumulativePhraseSettler.ingest(cumulativeText: text)
        publishSettlement(update)
    }

    func flushPendingVisibleOutput(force: Bool) {
        guard force else { return }
        let update = cumulativePhraseSettler.complete(cumulativeText: pendingVisibleOutput)
        publishSettlement(update)
    }

    private func publishSettlement(_ update: PhraseSettlementUpdate) {
        guard update.newlySettledText.isEmpty == false else { return }
        output = update.displayText
        lastSettledPhraseCharacterCount = update.newlySettledText.count
        phraseSettlementSequence &+= 1
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
        cumulativePhraseSettler = CumulativePhraseSettler()
        lastSettledPhraseCharacterCount = 0
        phraseSettlementSequence = 0
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
