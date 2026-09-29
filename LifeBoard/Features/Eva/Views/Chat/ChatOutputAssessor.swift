import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

/// Classification + diagnostic logging for a single raw model output.
///
/// Nothing here touches view state, so it lives outside `ChatView`.
enum ChatOutputAssessor {
    struct ChatOutputAssessment {
        let finalOutput: String
        let salvageOutput: String
        let qualityAssessment: LLMChatQualityAssessment
        let templateMismatch: Bool
        let hasVisibleThinking: Bool
        let hasAnswer: Bool
    }

    static func assessChatOutput(
        rawOutput: String,
        modelName: String,
        userPrompt: String,
        terminationReason: String?,
        runID: UUID,
        stage: String
    ) -> ChatOutputAssessment {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: rawOutput,
            modelName: modelName,
            userPrompt: userPrompt,
            terminationReason: terminationReason
        )
        logWarning(
            event: "chat_\(stage)_sanitization_result",
            message: "\(stage.capitalized) chat output sanitization completed",
            fields: [
                "model_name": modelName,
                "run_id": runID.uuidString,
                "has_visible_thinking": assessment.hasVisibleThinking ? "true" : "false",
                "has_answer": assessment.hasAnswer ? "true" : "false",
                "raw_cap_hit_stage": assessment.rawCapHitStage ?? "nil"
            ]
        )
        logDebug(
            event: "chat_\(stage)_sanitization_result_details",
            message: "\(stage.capitalized) chat output sanitization diagnostics",
            fields: [
                "model_name": modelName,
                "run_id": runID.uuidString,
                "raw_length": String(rawOutput.count),
                "sanitized_length": String(assessment.finalOutput.count),
                "removed_reasoning_blocks": assessment.removedReasoningBlocks ? "true" : "false",
                "removed_template_artifacts": assessment.removedTemplateArtifacts ? "true" : "false",
                "thinking_length": String(assessment.thinkingLength),
                "answer_length": String(assessment.answerLength),
                "extraction_mode": assessment.extractionMode,
                "quality_text_source": assessment.qualityAssessment.qualityTextSource,
                "repetition_confidence": assessment.qualityAssessment.repetitionDiagnostics?.confidence ?? "none",
                "repetition_detector": assessment.qualityAssessment.repetitionDiagnostics?.detector ?? "none",
                "repeated_line_count": assessment.qualityAssessment.repetitionDiagnostics.map { String($0.repeatedLineCount) } ?? "0",
                "repeated_sentence_count": assessment.qualityAssessment.repetitionDiagnostics.map { String($0.repeatedSentenceCount) } ?? "0",
                "tail_loop_detected": assessment.qualityAssessment.repetitionDiagnostics?.tailLoopDetected == true ? "true" : "false",
                "repeated_tail_preview": assessment.qualityAssessment.repetitionDiagnostics?.repeatedTailPreview ?? "nil"
            ]
        )

        if assessment.templateMismatch {
            logWarning(
                event: "chat_template_mismatch_detected",
                message: "Recoverable chat output was removed by sanitization; classifying as template mismatch",
                fields: [
                    "model_name": modelName,
                    "run_id": runID.uuidString,
                    "stage": stage,
                    "raw_length": String(rawOutput.count),
                    "salvage_length": String(assessment.salvageOutput.count),
                    "raw_preview_128": LoggingService.previewText(rawOutput, maxLength: 128)
                        .replacingOccurrences(of: "\n", with: "\\n")
                ]
            )
        }
        if assessment.thinkingOnlyOutput {
            logWarning(
                event: "chat_thinking_only_output_detected",
                message: "Raw output contained reasoning only and no visible answer",
                fields: [
                    "model_name": modelName,
                    "run_id": runID.uuidString,
                    "stage": stage,
                    "raw_length": String(rawOutput.count),
                    "raw_preview_128": LoggingService.previewText(rawOutput, maxLength: 128)
                        .replacingOccurrences(of: "\n", with: "\\n")
                ]
            )
        }

        logWarning(
            event: "chat_quality_assessment_\(stage)",
            message: "\(stage.capitalized) chat output quality assessment completed",
            fields: [
                "model_name": modelName,
                "run_id": runID.uuidString,
                "is_acceptable": assessment.qualityAssessment.isAcceptable ? "true" : "false",
                "should_retry": assessment.qualityAssessment.shouldRetry ? "true" : "false",
                "reasons_csv": assessment.qualityAssessment.reasons.joined(separator: ","),
                "hard_reasons_csv": assessment.qualityAssessment.hardFailureReasons.joined(separator: ","),
                "soft_warnings_csv": assessment.qualityAssessment.softWarningReasons.joined(separator: ","),
                "final_length": String(assessment.finalOutput.count),
                "termination_reason": terminationReason ?? "unknown",
                "thinking_length": String(assessment.thinkingLength),
                "answer_length": String(assessment.answerLength),
                "has_visible_thinking": assessment.hasVisibleThinking ? "true" : "false",
                "has_answer": assessment.hasAnswer ? "true" : "false",
                "extraction_mode": assessment.extractionMode,
                "raw_cap_hit_stage": assessment.rawCapHitStage ?? "nil",
                "quality_text_source": assessment.qualityAssessment.qualityTextSource,
                "repetition_confidence": assessment.qualityAssessment.repetitionDiagnostics?.confidence ?? "none",
                "repetition_detector": assessment.qualityAssessment.repetitionDiagnostics?.detector ?? "none",
                "repeated_line_count": assessment.qualityAssessment.repetitionDiagnostics.map { String($0.repeatedLineCount) } ?? "0",
                "repeated_sentence_count": assessment.qualityAssessment.repetitionDiagnostics.map { String($0.repeatedSentenceCount) } ?? "0",
                "tail_loop_detected": assessment.qualityAssessment.repetitionDiagnostics?.tailLoopDetected == true ? "true" : "false",
                "repeated_tail_preview": assessment.qualityAssessment.repetitionDiagnostics?.repeatedTailPreview ?? "nil"
            ]
        )

        return ChatOutputAssessment(
            finalOutput: assessment.finalOutput,
            salvageOutput: assessment.salvageOutput,
            qualityAssessment: assessment.qualityAssessment,
            templateMismatch: assessment.templateMismatch,
            hasVisibleThinking: assessment.hasVisibleThinking,
            hasAnswer: assessment.hasAnswer
        )
    }
}
