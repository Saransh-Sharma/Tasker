import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

/// Structured-log emitters for the standard chat generation run.
///
/// These were inline `logWarning` blocks inside `runStandardGeneration`; the
/// event names, field keys and values are unchanged, and `LoggingService`
/// derives `cmp=` from `#file`, which is still this file.
enum ChatGenerationLog {
    static func contextBuild(
        threadID: UUID,
        durationMs: Int,
        fromCache: Bool,
        usedTimeoutFallback: Bool
    ) {
        let fields = [
            "thread_id": threadID.uuidString,
            "duration_ms": String(durationMs),
            "timeout_fallback_used": usedTimeoutFallback ? "true" : "false"
        ]
        if fromCache {
            logWarning(
                event: "chat_context_cache_hit",
                message: "Reused cached chat context payload for current turn",
                fields: fields
            )
        } else {
            logWarning(
                event: "chat_context_build_ms",
                message: "Built chat context payload for current turn",
                fields: fields
            )
        }
    }

    static func promptComponentSizes(
        threadID: UUID,
        storedSystemPrompt: String,
        personalMemory: String?,
        executiveContext: String?,
        runtimeTaskContext: String,
        slashContext: String?,
        finalPrompt: String
    ) {
        logWarning(
            event: "chat_prompt_component_sizes",
            message: "Computed runtime prompt component sizes for current turn",
            fields: [
                "thread_id": threadID.uuidString,
                "stored_system_prompt_chars": String(storedSystemPrompt.count),
                "personal_memory_chars": String(personalMemory?.count ?? 0),
                "executive_context_chars": String(executiveContext?.count ?? 0),
                "runtime_context_chars": String(runtimeTaskContext.count),
                "slash_context_chars": String(slashContext?.count ?? 0),
                "final_prompt_chars": String(finalPrompt.count),
                "estimated_final_prompt_tokens": String(
                    LLMTokenBudgetEstimator.estimatedTokenCount(for: finalPrompt)
                )
            ]
        )
    }

    static func modelPrepare(
        modelName: String,
        durationMs: Int,
        prepareResult: LLMRuntimeCoordinator.EnsureReadyResult
    ) {
        logWarning(
            event: "chat_model_prepare_ms",
            message: "Prepared selected model prior to chat generation",
            fields: [
                "model_name": modelName,
                "resolved_model_name": prepareResult.resolvedModelName,
                "duration_ms": String(durationMs),
                "prewarm_eligible": prepareResult.prewarmEligible ? "true" : "false",
                "prewarm_hit": prepareResult.prewarmHit ? "true" : "false",
                "ready": prepareResult.ready ? "true" : "false"
            ]
        )
    }

    static func generationResult(
        event: String,
        message: String,
        modelName: String,
        runID: UUID,
        rawOutput: String,
        terminationReason: String?
    ) {
        logWarning(
            event: event,
            message: message,
            fields: [
                "model_name": modelName,
                "run_id": runID.uuidString,
                "raw_length": String(rawOutput.count),
                "raw_is_empty": (rawOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "true" : "false"),
                "raw_preview_128": LoggingService.previewText(rawOutput, maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                "raw_tail_preview_128": LoggingService.previewText(String(rawOutput.suffix(128)), maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                "termination_reason": terminationReason ?? "unknown"
            ]
        )
    }

    static func staticFallback(
        modelName: String,
        runID: UUID,
        qualityAssessment: LLMChatQualityAssessment,
        finalOutput: String
    ) {
        logWarning(
            event: "chat_fallback_to_static_message",
            message: "Chat quality gate failed after primary/retry, sending static fallback message",
            fields: [
                "model_name": modelName,
                "run_id": runID.uuidString,
                "is_acceptable": qualityAssessment.isAcceptable ? "true" : "false",
                "should_retry": qualityAssessment.shouldRetry ? "true" : "false",
                "reasons_csv": qualityAssessment.reasons.joined(separator: ","),
                "hard_reasons_csv": qualityAssessment.hardFailureReasons.joined(separator: ","),
                "soft_warnings_csv": qualityAssessment.softWarningReasons.joined(separator: ","),
                "final_length": String(finalOutput.count)
            ]
        )
    }
}
