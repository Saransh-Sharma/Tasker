import Foundation

extension LLMEvaluator {
    func runCloudGeneration(
        promptSnapshot: LLMChatPromptSnapshot,
        route: EvaCloudRoute,
        onFirstToken: (@MainActor @Sendable () -> Void)?
    ) async -> String {
        let slotLease: LLMGenerationSlotLease
        do {
            slotLease = try await generationSlot.acquire()
        } catch {
            lastTerminationReason = "cancelled_while_waiting_for_cloud_slot"
            return ""
        }

        running = true
        cancelled = false
        output = ""
        pendingVisibleOutput = ""
        cumulativePhraseSettler = CumulativePhraseSettler()
        lastSettledPhraseCharacterCount = 0
        phraseSettlementSequence = 0
        stat = ""
        progress = 0
        thinkingTime = nil
        startTime = Date()
        runtimePhase = .answering
        isThinking = false
        modelInfo = "Cloud EVA · Luna"
        let cancellationToken = LLMGenerationCancellationToken()
        generationCancellationToken = cancellationToken
        let consentRevision = EvaCloudAccountState.shared.consent?.revision ?? 0
        let request = EvaInferenceRequest.make(
            route: route,
            promptSnapshot: promptSnapshot,
            consentRevision: consentRevision
        )
        var emittedFirstToken = false

        defer {
            Task { await slotLease.release() }
            cancellationToken.cancel()
            running = false
            isThinking = false
            startTime = nil
            if runtimePhase != .failed { runtimePhase = .finished }
        }

        do {
            let provider = await providerRouter.cloudProvider()
            let result = try await provider.generate(request: request) { [weak self] cumulativeText in
                guard let self else { return }
                if !emittedFirstToken {
                    emittedFirstToken = true
                    onFirstToken?()
                }
                self.enqueueVisibleOutput(cumulativeText)
            }
            if cancellationToken.isCancelled || Task.isCancelled { throw CancellationError() }
            lastRawOutput = result
            pendingVisibleOutput = result
            flushPendingVisibleOutput(force: true)
            progress = 1
            thinkingTime = elapsedTime
            lastTerminationReason = "cloud_completed"
            lastVisibleCharacterCount = result.count
            return result
        } catch is CancellationError {
            lastTerminationReason = "cloud_cancelled"
            return ""
        } catch {
            runtimePhase = .failed
            lastTerminationReason = "cloud_failed"
            output = "Failed: \(error.localizedDescription)"
            return output
        }
    }
}
