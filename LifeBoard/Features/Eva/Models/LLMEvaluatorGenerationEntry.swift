import Foundation
import MLXLMCommon

extension LLMEvaluator {
    func generate(
        modelName: String,
        promptSnapshot: LLMChatPromptSnapshot,
        profile: LLMGenerationProfile = .chat,
        requestOptions: LLMGenerationRequestOptions? = nil,
        turnRuntime: EvaTurnRuntime? = nil,
        onFirstToken: (@MainActor @Sendable () -> Void)? = nil
    ) async -> String {
        lastGenerationTimedOut = false
        lastTerminationReason = nil
        lastRawOutput = ""
        lastGeneratedTokenCount = 0
        lastVisibleCharacterCount = 0
        lastSanitizedTemplateArtifacts = false
        let runtime: EvaTurnRuntime
        do {
            runtime = try turnRuntime ?? EvaTurnRuntime.resolve(
                localModelName: modelName,
                offlineModel: ModelConfiguration.getModelByName(modelName) ?? .defaultModel,
                route: profile.cloudRoute
            )
            try runtime.validateCurrentAuthority()
        } catch {
            runtimePhase = .failed
            lastTerminationReason = "runtime_resolution_failed"
            output = "Failed: \(error.localizedDescription)"
            return output
        }
        if runtime.usesCloud {
            return await runCloudGeneration(
                promptSnapshot: promptSnapshot,
                runtime: runtime,
                onFirstToken: onFirstToken
            )
        }
        guard ModelConfiguration.getModelByName(runtime.modelName) != nil else {
            runtimePhase = .failed
            output = "Failed: model not found"
            return output
        }
        logWarning(
            event: "chat_prompt_build_ms",
            message: "Built prompt history for generation",
            fields: [
                "model_name": modelName,
                "duration_ms": String(promptSnapshot.buildDurationMs),
                "message_count": String(promptSnapshot.messageCount),
                "system_prompt_chars": String(promptSnapshot.systemPromptCharacterCount),
                "prompt_history_chars": String(promptSnapshot.promptHistoryCharacterCount),
                "final_prompt_chars": String(promptSnapshot.promptCharacterCount),
            ]
        )
        let timeoutMs = UInt64(max(profile.timeoutSeconds, 0) * 1_000)
        guard timeoutMs > 0 else {
            return await runGeneration(
                modelName: runtime.modelName,
                chatMessages: promptSnapshot.messages,
                profile: profile,
                requestOptions: requestOptions,
                onFirstToken: onFirstToken
            )
        }
        let (result, timedOut) = await LLMProjectionTimeout.execute(
            timeoutMs: timeoutMs,
            onTimeout: { [weak self] in
                await self?.cancelGeneration(reason: "generation_timeout")
            }
        ) { [weak self] in
            guard let self else { return "{}" }
            return await self.runGeneration(
                modelName: runtime.modelName,
                chatMessages: promptSnapshot.messages,
                profile: profile,
                requestOptions: requestOptions,
                onFirstToken: onFirstToken
            )
        }
        lastGenerationTimedOut = timedOut
        return result
    }
}
