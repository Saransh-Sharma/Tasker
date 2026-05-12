import Foundation
import MLX
import MLXLMCommon

#if DEBUG
@MainActor
enum LLMDebugSmokeRunner {
    private static let smokeSystemPrompt = "Answer in one short sentence. No intro. No markdown."
    private static let smokeUserPrompt = "What can you help me with today?"

    private(set) static var lastResults: [LLMRuntimeSmokeTestResult] = []
    private static var inFlightTask: Task<Void, Never>?

    static func scheduleIfEnabled() {
        guard V2FeatureFlags.llmRuntimeSmokeEnabled else { return }
        guard inFlightTask == nil else { return }

        inFlightTask = Task { @MainActor in
            defer { inFlightTask = nil }
            await runInstalledModelsSmoke()
        }
    }

    static func runInstalledModelsSmoke(defaults: UserDefaults = .standard) async {
        let installedModelNames = LLMPersistedModelSelection.normalize(defaults: defaults).installedModels
        let models = installedModelNames.compactMap(ModelConfiguration.getModelByName)

        guard models.isEmpty == false else {
            logWarning(
                event: "llm_runtime_smoke_skipped",
                message: "Skipped runtime smoke because no installed supported models were found",
                fields: [:]
            )
            lastResults = []
            return
        }

        let runtimeCoordinator = LLMRuntimeCoordinator.shared
        let evaluator = runtimeCoordinator.evaluator
        var results: [LLMRuntimeSmokeTestResult] = []

        for model in models {
            let result = await LLMRuntimeSmokeTester.run(model: model) { _ in
                try await probe(model: model, evaluator: evaluator, runtimeCoordinator: runtimeCoordinator)
            }
            results.append(result)
            logWarning(
                event: "llm_runtime_smoke_result",
                message: "Completed debug runtime smoke check for installed model",
                fields: smokeLogFields(for: result)
            )
            await runtimeCoordinator.unload(reason: "debug_smoke_model_complete")
        }

        lastResults = results
        logWarning(
            event: "llm_runtime_smoke_summary",
            message: "Completed debug runtime smoke pass across installed models",
            fields: [
                "model_count": String(results.count),
                "failed_count": String(results.filter { $0.status == .failed }.count),
                "fallback_count": String(results.filter { $0.fallbackShown == true }.count)
            ]
        )
    }

    private static func probe(
        model: ModelConfiguration,
        evaluator: LLMEvaluator,
        runtimeCoordinator: LLMRuntimeCoordinator
    ) async throws -> LLMRuntimeSmokeMetrics {
        let sessionReason = "debug_smoke"
        runtimeCoordinator.acquireSession(reason: sessionReason)
        defer {
            runtimeCoordinator.releaseSession(reason: sessionReason)
        }

        let ready = await runtimeCoordinator.ensureReady(modelName: model.name)
        guard ready.ready else {
            throw NSError(
                domain: "LLMDebugSmokeRunner",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: ready.failureMessage ?? "Model prepare failed"]
            )
        }
        let resolvedModel = ModelConfiguration.getModelByName(ready.resolvedModelName) ?? model

        let thread = Thread()
        thread.messages = [
            Message(role: .user, content: smokeUserPrompt, thread: thread)
        ]
        let requestOptions = LLMGenerationRequestOptions.interactiveChat(for: resolvedModel)

        let visibleOutput = await evaluator.generate(
            modelName: ready.resolvedModelName,
            thread: thread,
            systemPrompt: smokeSystemPrompt,
            profile: .chatProfile(for: resolvedModel, requestOptions: requestOptions),
            requestOptions: requestOptions
        )
        let rawOutput = evaluator.lastRawOutput.isEmpty ? visibleOutput : evaluator.lastRawOutput

        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: rawOutput,
            modelName: ready.resolvedModelName,
            userPrompt: smokeUserPrompt,
            terminationReason: evaluator.lastTerminationReason
        )
        let rawTrimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackShown = !(assessment.templateMismatch && assessment.salvageOutput.isEmpty == false) &&
            (!assessment.qualityAssessment.isAcceptable || assessment.finalOutput.isEmpty)

        return LLMRuntimeSmokeMetrics(
            firstTokenLatencyMs: nil,
            peakMemoryMB: Int(MLX.Memory.activeMemory / 1024 / 1024),
            terminationReason: evaluator.lastTerminationReason,
            rawOutputPreview: LoggingService.previewText(rawTrimmed, maxLength: 128),
            sanitizedOutputPreview: LoggingService.previewText(
                assessment.templateMismatch ? assessment.salvageOutput : assessment.finalOutput,
                maxLength: 128
            ),
            sanitizationEmptiedNonEmptyRaw: rawTrimmed.isEmpty == false && assessment.finalOutput.isEmpty,
            fallbackShown: fallbackShown
        )
    }

    private static func smokeLogFields(for result: LLMRuntimeSmokeTestResult) -> [String: String] {
        var fields: [String: String] = [
            "model_name": result.modelName,
            "status": result.status == .supported ? "supported" : "failed",
            "prepare_duration_ms": result.prepareDurationMs.map(String.init) ?? "nil",
            "termination_reason": result.terminationReason ?? "nil",
            "fallback_shown": result.fallbackShown == true ? "true" : "false"
        ]
        if let rawOutputPreview = result.rawOutputPreview {
            fields["raw_output_preview"] = rawOutputPreview.replacingOccurrences(of: "\n", with: "\\n")
        }
        if let sanitizedOutputPreview = result.sanitizedOutputPreview {
            fields["sanitized_output_preview"] = sanitizedOutputPreview.replacingOccurrences(of: "\n", with: "\\n")
        }
        if let errorDescription = result.errorDescription {
            fields["error"] = errorDescription
        }
        return fields
    }
}
#endif
