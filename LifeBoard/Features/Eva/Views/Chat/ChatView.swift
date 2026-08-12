//
//  ChatView.swift
//

import Combine
import MarkdownUI
import MLXLMCommon
import SwiftData
import SwiftUI
import os

private struct EvaAuthorizedEvidenceContextEnvironmentKey: EnvironmentKey {
    static let defaultValue = EvaAuthorizedEvidenceContext.notProvided
}

struct EvaEvidenceOpenAction {
    var open: @MainActor (EvidenceReference) -> Void

    static let disabled = Self(open: { _ in })
}

private struct EvaEvidenceOpenActionEnvironmentKey: EnvironmentKey {
    static let defaultValue = EvaEvidenceOpenAction.disabled
}

extension EnvironmentValues {
    var evaAuthorizedEvidenceContext: EvaAuthorizedEvidenceContext {
        get { self[EvaAuthorizedEvidenceContextEnvironmentKey.self] }
        set { self[EvaAuthorizedEvidenceContextEnvironmentKey.self] = newValue }
    }

    var evaEvidenceOpenAction: EvaEvidenceOpenAction {
        get { self[EvaEvidenceOpenActionEnvironmentKey.self] }
        set { self[EvaEvidenceOpenActionEnvironmentKey.self] = newValue }
    }
}

/// Pure derivations backing the chat slash-command pickers.
///
/// Lifted out of `ChatView` so the view type stays small — same pattern as
/// `TrackSectionCopy` in `LifeBoardTrackFoundationViews.swift`. Every entry point
/// is a `static func` over explicit inputs, so nothing here reads view state.
private enum ChatSlashSuggestionCatalog {
    static func commandSuggestions(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot,
        recents: [SlashCommandID]
    ) -> [SlashCommandDescriptor] {
        var suggestions: [SlashCommandDescriptor] = []
        var seen = Set<SlashCommandID>()

        let contextual = contextualCommandIDs(
            prompt: prompt,
            transcriptSnapshot: transcriptSnapshot
        )
        for commandID in contextual {
            guard seen.insert(commandID).inserted else { continue }
            suggestions.append(SlashCommandCatalog.descriptor(for: commandID))
            if suggestions.count >= 3 {
                return suggestions
            }
        }

        for commandID in recents {
            guard seen.insert(commandID).inserted else { continue }
            suggestions.append(SlashCommandCatalog.descriptor(for: commandID))
            if suggestions.count >= 3 {
                return suggestions
            }
        }

        for descriptor in SlashCommandCatalog.descriptors.sorted(by: { $0.id.popularityRank < $1.id.popularityRank }) {
            guard seen.insert(descriptor.id).inserted else { continue }
            suggestions.append(descriptor)
            if suggestions.count >= 3 {
                break
            }
        }

        return suggestions
    }

    static func contextualCommandIDs(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot
    ) -> [SlashCommandID] {
        let hintText = contextualHintText(prompt: prompt, transcriptSnapshot: transcriptSnapshot)
        guard hintText.isEmpty == false else { return [] }

        var ordered: [SlashCommandID] = []
        func append(_ commandID: SlashCommandID, when condition: Bool) {
            guard condition else { return }
            guard ordered.contains(commandID) == false else { return }
            ordered.append(commandID)
        }

        append(.overdue, when: hintText.contains("overdue") || hintText.contains("late"))
        append(.today, when: hintText.contains("today"))
        append(.tomorrow, when: hintText.contains("tomorrow"))
        append(.week, when: hintText.contains("week"))
        append(.month, when: hintText.contains("month"))
        append(.project, when: hintText.contains("project") || hintText.contains("inbox"))
        append(.area, when: hintText.contains("life area") || hintText.contains("area"))
        append(.recent, when: hintText.contains("recent") || hintText.contains("last 2 weeks") || hintText.contains("last two weeks"))
        append(.clear, when: hintText.contains("clear chat") || hintText.contains("reset chat"))

        return ordered
    }

    static func contextualHintText(
        prompt: String,
        transcriptSnapshot: ChatTranscriptSnapshot
    ) -> String {
        var fragments: [String] = []
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty == false {
            fragments.append(trimmedPrompt.lowercased())
        }
        fragments.append(contentsOf: transcriptSnapshot.recentUserMessageFragments)
        return fragments.joined(separator: " ")
    }

    static func recentPickerCommands(recents: [SlashCommandID]) -> [SlashCommandDescriptor] {
        var unique = Set<SlashCommandID>()
        return recents.prefix(3).compactMap { commandID in
            guard unique.insert(commandID).inserted else { return nil }
            return SlashCommandCatalog.descriptor(for: commandID)
        }
    }

    static func popularPickerCommands(recents: [SlashCommandID]) -> [SlashCommandDescriptor] {
        let recentSet = Set(recents)
        return SlashCommandCatalog.descriptors
            .filter { recentSet.contains($0.id) == false }
            .sorted { $0.id.popularityRank < $1.id.popularityRank }
            .prefix(5)
            .map { $0 }
    }

    static func allPickerCommands(
        query: String,
        recents: [SlashCommandID]
    ) -> [SlashCommandDescriptor] {
        SlashCommandCatalog.filteredDescriptors(query: query, recents: recents, limit: 8)
    }

    static func pickerQuery(fromPrompt promptText: String) -> String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return "" }
        let raw = String(trimmed.dropFirst())
        return raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
    }
}

/// Classification + diagnostic logging for a single raw model output.
///
/// Nothing here touches view state, so it lives outside `ChatView`.
private enum ChatOutputAssessor {
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

/// Context-payload and system-prompt assembly for a chat turn.
///
/// These were `ChatView` methods that only ever read budgets and the active
/// model, so they move out wholesale; the per-thread injection cache moves with
/// them (it was a `static let` on the view and stays a single shared instance).
private enum ChatContextAssembly {
    static let contextInjectionTracker = ChatContextInjectionTracker()

    /// Executes buildLLMContextPayloadAsync.
    static func buildLLMContextPayloadAsync(
        timeoutMs: UInt64,
        query: String,
        budgets: LLMChatBudgets,
        model: MLXLMCommon.ModelConfiguration
    ) async -> (payload: String, usedTimeoutFallback: Bool) {
        let result = await LLMChatPlanningContextBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryFactory.makeService(
                maxTasksPerSlice: budgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            query: query,
            budgets: budgets,
            model: model
        )
        return (result.payload, result.usedTimeoutFallback)
    }

    static func buildEvaPlanContextPayloadForCurrentTurn(
        threadID: UUID,
        timeoutMs: UInt64,
        traceContext: EvaTurnTraceContext,
        budgets: LLMChatBudgets
    ) async -> (payload: String, usedTimeoutFallback: Bool, fromCache: Bool) {
        let built = await LLMChatContextEnvelopeBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryFactory.makeService(
                maxTasksPerSlice: budgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            injectionPolicy: "eva_plan",
            budgets: budgets,
            contextStrategy: V2FeatureFlags.llmChatContextStrategy
        )
        logWarning(
            event: "eva_plan_context_build_ms",
            message: "Built EVA plan context payload for current turn",
            fields: traceContext.logFields.merging([
                "timeout_fallback_used": built.usedTimeoutFallback ? "true" : "false",
                "context_partial": built.envelope.metadata.contextPartial ? "true" : "false",
                "partial_reasons": built.envelope.metadata.partialReasons.joined(separator: ",")
            ]) { _, new in new }
        )
        return (built.payload, built.usedTimeoutFallback, false)
    }

    /// Executes buildContextPayloadForCurrentTurn.
    static func buildContextPayloadForCurrentTurn(
        threadID: UUID,
        timeoutMs: UInt64,
        userPrompt: String,
        budgets: LLMChatBudgets,
        model: MLXLMCommon.ModelConfiguration,
        injectionPolicy: ChatContextInjectionPolicy,
        contextCharBudgetOverride: Int? = nil,
        allowCacheReuse: Bool = true
    ) async -> (payload: String, usedTimeoutFallback: Bool, fromCache: Bool) {
        let now = Date()
        let querySignature = userPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let budgetSignature = contextCharBudgetOverride.map(String.init) ?? "default"
        let cacheSignature = "\(querySignature)|\(budgetSignature)"
        if allowCacheReuse {
            if let cached = await contextInjectionTracker.cachedContext(
                for: threadID,
                querySignature: cacheSignature,
                now: now,
                throttleMs: injectionPolicy.throttleMs
            ) {
                return (cached.payload, cached.usedTimeoutFallback, true)
            }
        }

        let built = await LLMChatPlanningContextBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryFactory.makeService(
                maxTasksPerSlice: budgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            query: userPrompt,
            budgets: budgets,
            model: model,
            contextCharBudgetOverride: contextCharBudgetOverride
        )
        if allowCacheReuse {
            await contextInjectionTracker.store(
                threadID: threadID,
                querySignature: cacheSignature,
                payload: built.payload,
                usedTimeoutFallback: built.usedTimeoutFallback,
                generatedAt: now
            )
        }
        return (built.payload, built.usedTimeoutFallback, false)
    }

    static func composeChatSystemPrompt(
        basePrompt: String,
        model: MLXLMCommon.ModelConfiguration,
        personalMemory: String? = nil,
        executiveContext: String? = nil,
        slashContext: String? = nil,
        taskContext: String? = nil,
        additionalInstruction: String? = nil
    ) -> String {
        return LLMSystemPromptComposer.compose(
            basePrompt: basePrompt,
            model: model,
            additionalInstruction: additionalInstruction,
            personalMemory: personalMemory,
            executiveContext: executiveContext,
            slashContext: slashContext,
            taskContext: taskContext
        )
    }

    static func buildExecutiveContextPrompt(tokenBudget: Int) async -> String? {
        guard let service = EvaExecutiveContextService.makeDefault() else { return nil }
        let maxChars = LLMTokenBudgetEstimator.estimatedCharacterBudget(for: tokenBudget)
        let snapshot = await service.buildSnapshot(maxChars: maxChars)
        let trimmed = snapshot.promptBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func loadSlashAttachments(for threadID: UUID) async -> [ThreadContextAttachmentRecord] {
        await ThreadContextAttachmentStore.shared.attachments(for: threadID)
    }

    static func slashCommandContextPrompt(
        attachments: [ThreadContextAttachmentRecord],
        tokenBudget: Int
    ) -> String? {
        ThreadContextAttachmentResolver.promptBlock(
            for: attachments,
            tokenBudget: tokenBudget
        )
    }
}

/// Structured-log emitters for the standard chat generation run.
///
/// These were inline `logWarning` blocks inside `runStandardGeneration`; the
/// event names, field keys and values are unchanged, and `LoggingService`
/// derives `cmp=` from `#file`, which is still this file.
private enum ChatGenerationLog {
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

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.evaAuthorizedEvidenceContext) private var authorizedLifeEvidence
    @Namespace var bottomID
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    @Environment(\.dismiss) var dismissView

    var presentationMode: ChatPresentationMode = .normal
    var onActivationChatEvent: ((EvaActivationChatEvent) -> Void)? = nil
    var onOpenTaskDetail: ((TaskDefinition) -> Void)? = nil
    var onOpenHabitDetail: ((UUID) -> Void)? = nil
    var onPerformDayTaskAction: EvaDayTaskActionHandler? = nil
    var onPerformDayHabitAction: EvaDayHabitActionHandler? = nil
    var showsHistoryAction: Bool = true
    var promptFocusRequestID: UInt64 = 0
    var storageDegradedReason: String? = nil
    var onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)? = nil
    var onComposerFocusChange: ((Bool) -> Void)? = nil

    @State var thinkingTime: TimeInterval?

    @State private var generatingThreadID: UUID?
    @State private var showSlashPicker = false
    @State private var slashPickerQuery = ""
    @State private var slashDraft: SlashCommandInvocation?
    @State private var recentSlashCommands: [SlashCommandID] = []
    @State private var commandFeedback: String?
    @State private var showClearConfirmation = false
    @State private var projectLookupTask: _Concurrency.Task<Void, Never>?
    @State private var generationTask: _Concurrency.Task<Void, Never>?
    @State private var activationFocusTask: _Concurrency.Task<Void, Never>?
    @State private var contextInvalidationTask: _Concurrency.Task<Void, Never>?
    @State private var slashCommandTask: _Concurrency.Task<Void, Never>?
    @State private var generationRunID: UUID?
    @State private var transcriptSnapshot: ChatTranscriptSnapshot = .empty
    @State private var pendingResponsePhase: ChatPendingResponsePhase = .idle
    @State private var chatOpenTraceInterval: PerformanceInterval?
    @State private var promptSubmitTraceInterval: PerformanceInterval?
    @State private var evaSubmittedDraft: EvaSubmittedDraft?
    @State private var hasCompletedInitialTranscriptRender = false
    @State private var consumedPromptFocusRequestID: UInt64 = 0
    @StateObject private var contextCoordinator = ChatContextCoordinator()
    @FocusState private var isProjectFieldFocused: Bool

    private struct EvaSubmittedDraft: Equatable {
        let runID: UUID
        let text: String
    }

    private var chatBudgets: LLMChatBudgets {
        LLMChatBudgets.active
    }

    private var resolvedChatBudget: LLMResolvedChatBudget {
        chatBudgets.resolved(for: activeModelConfiguration)
    }

    private var activeModelConfiguration: MLXLMCommon.ModelConfiguration {
        guard let modelName = appManager.currentModelName,
              let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName) else {
            return MLXLMCommon.ModelConfiguration.defaultModel
        }
        return model
    }

    private var contextFetchTimeoutMs: UInt64 {
        chatBudgets.projectionTimeoutMs
    }

    private var evaPlanContextFetchTimeoutMs: UInt64 {
        max(contextFetchTimeoutMs, 2_500)
    }

    private var contextInjectionPolicy: ChatContextInjectionPolicy {
        .perTurn(throttleMs: chatBudgets.contextCacheTTLms)
    }

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isComposerFocused: Bool {
        isPromptFocused || isProjectFieldFocused
    }

    var canSubmit: Bool {
        if let slashDraft {
            return slashDraft.isReady
        }
        return !isPromptEmpty
    }

    var isGenerationInFlight: Bool {
        generationTask != nil || llm.running || (generatingThreadID != nil && llm.isThinking)
    }

    private var projectQueryBinding: Binding<String> {
        Binding(
            get: { slashDraft?.projectQuery ?? "" },
            set: { updateProjectDraftQuery($0) }
        )
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var isActivationPresentation: Bool {
        activationConfiguration != nil
    }

    private var activationStarterPrompts: [EvaStarterPrompt] {
        activationConfiguration?.starterPrompts ?? []
    }

    private var commandSuggestions: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.commandSuggestions(
            prompt: prompt,
            transcriptSnapshot: transcriptSnapshot,
            recents: recentSlashCommands
        )
    }

    private var recentPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.recentPickerCommands(recents: recentSlashCommands)
    }

    private var popularPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.popularPickerCommands(recents: recentSlashCommands)
    }

    private var allPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.allPickerCommands(
            query: slashPickerQuery,
            recents: recentSlashCommands
        )
    }

    var chatTitle: String {
        transcriptSnapshot.title
    }

    private var liveOutputState: ChatLiveOutputState {
        ChatLiveOutputState(
            responseID: generationRunID,
            threadID: generatingThreadID,
            text: llm.output,
            sourceModelName: llm.loadedModelName ?? appManager.currentModelName,
            runtimePhase: llm.runtimePhase,
            isRunning: llm.running,
            pendingPhase: pendingResponsePhase,
            pendingStatusText: ChatPendingResponseStatusText.status(
                for: pendingResponsePhase,
                isActivationPresentation: isActivationPresentation
            )
        )
    }

    private var contextInvalidationPublisher: AnyPublisher<Notification, Never> {
        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated")).eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated")).eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted")).eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged")).eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: Notification.Name("HomeTaskMutationEvent")).eraseToAnyPublisher()
        )
        // Legacy task notifications are still emitted alongside HomeTaskMutationEvent.
        // Debounce the merged bridge until all producers emit only the structured event.
        .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }

    var body: some View {
        ChatScaffoldView(
            currentThread: $currentThread,
            transcriptSnapshot: transcriptSnapshot,
            liveOutput: liveOutputState,
            presentationMode: presentationMode,
            prompt: $prompt,
            isPromptFocused: $isPromptFocused,
            isProjectFieldFocused: $isProjectFieldFocused,
            showChats: $showChats,
            showSettings: $showSettings,
            showSlashPicker: $showSlashPicker,
            showClearConfirmation: $showClearConfirmation,
            slashDraft: $slashDraft,
            slashPickerQuery: $slashPickerQuery,
            commandFeedback: commandFeedback,
            storageDegradedReason: storageDegradedReason,
            projectQuery: projectQueryBinding,
            commandSuggestions: commandSuggestions,
            recentCommands: recentPickerCommands,
            popularCommands: popularPickerCommands,
            allCommands: allPickerCommands,
            isGenerationInFlight: isGenerationInFlight,
            canSubmit: canSubmit,
            llmCancelled: llm.cancelled,
            chatTitle: chatTitle,
            showsHistoryAction: showsHistoryAction,
            onOpenTaskDetail: onOpenTaskDetail,
            onOpenHabitDetail: onOpenHabitDetail,
            onPerformDayTaskAction: onPerformDayTaskAction,
            onPerformDayHabitAction: onPerformDayHabitAction,
            starterPrompts: activationStarterPrompts,
            activeAttachments: contextCoordinator.activeAttachments,
            onOpenSlashPicker: {
                appManager.playHaptic()
                openSlashPicker(trigger: "button")
            },
            onSelectStarterPrompt: { starter in
                submitStarterPrompt(starter)
            },
            onSelectSuggestion: { descriptor in
                selectSlashCommand(descriptor)
            },
            onStartNewChat: {
                startNewChat()
            },
            onCancelDraft: {
                projectLookupTask?.cancel()
                slashDraft = nil
                commandFeedback = nil
                isProjectFieldFocused = false
                appManager.playHaptic()
            },
            onRemoveAttachment: { attachment in
                contextCoordinator.remove(attachment)
            },
            onGenerate: {
                submitPromptFromSendButton()
            },
            onStop: {
                cancelActiveGeneration(reason: .stopButton)
            },
            onSubmitPrompt: {
                submitPromptFromComposer()
            },
            onClearCurrentThread: {
                clearCurrentThread()
            },
            onNavigationChromeChange: onNavigationChromeChange
        )
        .onAppear {
            handleChatViewAppear()
            handlePromptFocusRequestIfNeeded()
        }
        .onChange(of: prompt) { _, newValue in
            handlePromptChanged(newValue)
        }
        .onChange(of: slashDraft?.id) { _, newValue in
            guard newValue?.requiresArgument == true else {
                isProjectFieldFocused = false
                return
            }
            isProjectFieldFocused = true
        }
        .onChange(of: currentThread?.id) { oldThreadID, newThreadID in
            handleCurrentThreadChanged(from: oldThreadID, to: newThreadID)
        }
        .onChange(of: isPromptFocused) { _, focused in
            handlePromptFocusChanged(focused)
        }
        .onChange(of: isComposerFocused, initial: true) { _, focused in
            onComposerFocusChange?(focused)
        }
        .onChange(of: promptFocusRequestID) { _, _ in
            handlePromptFocusRequestIfNeeded()
        }
        .onDisappear {
            handleChatViewDisappear()
        }
        .onReceive(contextInvalidationPublisher) { _ in
            scheduleContextInvalidationForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardEvaChatLaunchRequestDidChange)) { _ in
            consumePendingChatLaunchRequest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestEvaChatSettings)) { _ in
            guard activationConfiguration?.hideUtilityActions != true else { return }
            appManager.playHaptic()
            showSettings.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestEvaChatNewThread)) { _ in
            guard isActivationPresentation == false, currentThread != nil else { return }
            startNewChat()
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appManager.playHaptic()
                    showSettings.toggle()
                }) {
                    Label("settings", systemImage: "gear")
                }
            }
            #endif
        }
    }

}

// MARK: - Composer, focus and lifecycle

extension ChatView {
    private func submitPromptFromComposer() {
        #if os(macOS)
        handleShiftReturn()
        #else
        isPromptFocused = true
        generate()
        #endif
    }

    @MainActor
    private func submitPromptFromSendButton() {
        #if os(macOS)
        generate()
        #else
        // Force a focus commit before generation so the first tap reliably submits current composer text.
        let wasPromptFocused = isPromptFocused
        isProjectFieldFocused = false
        if wasPromptFocused {
            isPromptFocused = false
            _Concurrency.Task { @MainActor in
                await _Concurrency.Task.yield()
                generate()
            }
        } else {
            generate()
        }
        #endif
    }

    @MainActor
    private func consumePendingChatLaunchRequest() {
        guard let request = EvaChatLaunchRequestStore.shared.consumePendingRequest() else { return }
        slashDraft = nil
        commandFeedback = nil
        showSlashPicker = false
        prompt = request.prompt ?? ""
        isProjectFieldFocused = false
        isPromptFocused = true
    }

    @MainActor
    private func submitStarterPrompt(_ starter: EvaStarterPrompt) {
        projectLookupTask?.cancel()
        slashDraft = nil
        commandFeedback = nil
        prompt = starter.submissionText
        isPromptFocused = true
        generate()
    }

    @MainActor
    private func handleChatViewAppear() {
        hasCompletedInitialTranscriptRender = false
        chatOpenTraceInterval = PerformanceTrace.begin("ChatOpenToFirstTranscriptRender")
        refreshTranscriptSnapshot()
        contextCoordinator.loadAttachments(for: currentThread?.id)
        consumePendingChatLaunchRequest()
        LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_view")

        guard isActivationPresentation else { return }
        LLMRuntimeCoordinator.shared.requestChatEntryPrewarm(
            trigger: "activation_first_chat",
            delaySeconds: 0
        )
        activationFocusTask?.cancel()
        activationFocusTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            guard generationTask == nil else { return }
            isPromptFocused = true
        }
    }

    @MainActor
    private func handlePromptFocusRequestIfNeeded() {
        guard promptFocusRequestID != 0 else { return }
        guard consumedPromptFocusRequestID != promptFocusRequestID else { return }
        consumedPromptFocusRequestID = promptFocusRequestID

        _Concurrency.Task { @MainActor in
            await _Concurrency.Task.yield()
            await _Concurrency.Task.yield()
            guard consumedPromptFocusRequestID == promptFocusRequestID else { return }
            guard generationTask == nil else { return }
            isProjectFieldFocused = false
            isPromptFocused = true
        }
    }

    @MainActor
    private func handleChatViewDisappear() {
        onComposerFocusChange?(false)
        activationFocusTask?.cancel()
        activationFocusTask = nil
        projectLookupTask?.cancel()
        slashCommandTask?.cancel()
        slashCommandTask = nil
        contextInvalidationTask?.cancel()
        contextInvalidationTask = nil
        if let chatOpenTraceInterval {
            PerformanceTrace.end(chatOpenTraceInterval)
            self.chatOpenTraceInterval = nil
        }
        LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_view_disappear")
        cancelActiveGeneration(reason: .chatViewDisappear)
        LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_prompt_focus")
        LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_view")
    }

    @MainActor
    private func handleCurrentThreadChanged(from oldThreadID: UUID?, to newThreadID: UUID?) {
        activationFocusTask?.cancel()
        activationFocusTask = nil
        projectLookupTask?.cancel()
        slashCommandTask?.cancel()
        slashCommandTask = nil
        contextInvalidationTask?.cancel()
        contextInvalidationTask = nil
        let threadChangeDecision = ChatGenerationCancellationPolicy.decision(
            oldThreadID: oldThreadID,
            newThreadID: newThreadID,
            generatingThreadID: generatingThreadID,
            hasActiveGeneration: generationTask != nil || llm.running
        )
        switch threadChangeDecision {
        case .cancel:
            cancelActiveGeneration(reason: .threadChanged)
        case .preserveFirstGeneratedThreadAttach:
            logWarning(
                event: "chat_thread_change_generation_preserved",
                message: "Preserved active generation after first chat thread attach",
                fields: [
                    "thread_id": newThreadID?.uuidString ?? "nil"
                ]
            )
        case .ignore:
            break
        }
        refreshTranscriptSnapshot()
        contextCoordinator.loadAttachments(for: currentThread?.id)
    }

    @MainActor
    private func handlePromptFocusChanged(_ focused: Bool) {
        if focused {
            guard generationTask == nil else { return }
            LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_prompt_focus")
            LLMRuntimeCoordinator.shared.requestChatEntryPrewarm(
                trigger: "prompt_focus",
                delaySeconds: 0.5
            )
        } else {
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_prompt_blur")
            LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_prompt_focus")
        }
    }

    private func handlePromptChanged(_ newValue: String) {
        guard slashDraft == nil else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return }

        slashPickerQuery = ChatSlashSuggestionCatalog.pickerQuery(fromPrompt: trimmed)
        if showSlashPicker == false {
            openSlashPicker(trigger: "typed")
        }
    }

    private func openSlashPicker(trigger: String) {
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            slashPickerQuery = ChatSlashSuggestionCatalog.pickerQuery(fromPrompt: trimmed)
        } else {
            slashPickerQuery = ""
        }
        showSlashPicker = true
        logWarning(
            event: "chat_slash_picker_opened",
            message: "Opened slash command picker",
            fields: ["trigger": trigger]
        )
    }

    private func selectSlashCommand(_ descriptor: SlashCommandDescriptor) {
        appManager.playHaptic()
        projectLookupTask?.cancel()
        var invocation = SlashCommandInvocation(id: descriptor.id, argumentQuery: nil, resolvedArgument: nil)
        if descriptor.id.requiresArgument {
            invocation.argumentQuery = ""
            invocation.resolvedArgument = nil
        }
        slashDraft = invocation
        showSlashPicker = false
        prompt = ""
        commandFeedback = nil
        isProjectFieldFocused = descriptor.id.requiresArgument

        logWarning(
            event: "chat_slash_command_selected",
            message: "Selected slash command from picker",
            fields: ["command_id": descriptor.id.rawValue]
        )
    }

    private func updateProjectDraftQuery(_ rawQuery: String) {
        guard var invocation = slashDraft, invocation.id.requiresArgument else { return }

        projectLookupTask?.cancel()
        invocation.argumentQuery = rawQuery
        invocation.resolvedArgument = nil
        slashDraft = invocation
        commandFeedback = nil

        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return }

        projectLookupTask = _Concurrency.Task {
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 180_000_000)
            } catch {
                return
            }

            let resolvedName = await SlashCommandExecutionService.makeDefault()?
                .resolveArgumentName(for: invocation.id, matching: query)
            await MainActor.run {
                guard var current = slashDraft, current.id.requiresArgument else { return }
                let currentQuery = current.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard currentQuery.caseInsensitiveCompare(query) == .orderedSame else { return }
                current.resolvedArgument = resolvedName
                slashDraft = current
            }
        }
    }

    private func recordRecentCommand(_ commandID: SlashCommandID) {
        recentSlashCommands.removeAll { $0 == commandID }
        recentSlashCommands.insert(commandID, at: 0)
        if recentSlashCommands.count > 6 {
            recentSlashCommands = Array(recentSlashCommands.prefix(6))
        }
    }

    @MainActor
    private func clearCurrentThread() {
        projectLookupTask?.cancel()
        cancelActiveGeneration(reason: .clearThread)
        if let thread = currentThread {
            modelContext.delete(thread)
            try? modelContext.save()
            _Concurrency.Task {
                await ChatContextAssembly.contextInjectionTracker.clear(threadID: thread.id)
            }
            contextCoordinator.clear(threadID: thread.id)
        }
        currentThread = nil
        transcriptSnapshot = .empty
        prompt = ""
        slashDraft = nil
        commandFeedback = nil
        showSlashPicker = false
        generatingThreadID = nil
        llm.isThinking = false
        isProjectFieldFocused = false

        recordRecentCommand(.clear)
        logWarning(
            event: "chat_slash_command_sent",
            message: "Executed slash command",
            fields: ["command_id": SlashCommandID.clear.rawValue]
        )
    }

    @MainActor
    private func startNewChat() {
        projectLookupTask?.cancel()
        if isGenerationInFlight {
            cancelActiveGeneration(reason: .startNewChat)
        }

        currentThread = nil
        transcriptSnapshot = .empty
        prompt = ""
        slashDraft = nil
        commandFeedback = nil
        showSlashPicker = false
        slashPickerQuery = ""
        generatingThreadID = nil
        pendingResponsePhase = .idle
        evaSubmittedDraft = nil
        generationRunID = nil
        llm.isThinking = false
        isProjectFieldFocused = false
        contextCoordinator.clear(threadID: nil)

        _Concurrency.Task { @MainActor in
            isPromptFocused = true
        }
    }

}

// MARK: - Thread resolution and prompt snapshot

extension ChatView {
    @MainActor
    private func ensureCurrentThread() -> Thread? {
        if currentThread == nil {
            let newThread = Thread()
            currentThread = newThread
            modelContext.insert(newThread)
            do {
                try modelContext.save()
                refreshTranscriptSnapshot(for: newThread)
                if isActivationPresentation {
                    onActivationChatEvent?(.threadAttached(newThread.id))
                }
            } catch {
                logError(
                    event: "chat_thread_save_failed",
                    message: "Failed to save chat thread",
                    fields: ["error": error.localizedDescription]
                )
                return nil
            }
        }
        return currentThread
    }

    @MainActor
    private func thread(matching threadID: UUID) -> Thread? {
        if currentThread?.id == threadID {
            return currentThread
        }
        var descriptor = FetchDescriptor<Thread>(
            predicate: #Predicate<Thread> { thread in
                thread.id == threadID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    private func sendMessage(
        role: Role,
        content: String,
        threadID: UUID,
        generatingTime: TimeInterval? = nil,
        sourceModelName: String? = nil
    ) -> ChatMessageSendOutcome {
        guard let thread = thread(matching: threadID) else {
            logWarning(
                event: "chat_thread_resolve_failed",
                message: "Could not resolve chat thread for message persistence",
                fields: ["thread_id": threadID.uuidString]
            )
            return ChatMessageSendOutcome(
                status: .saveFailed,
                messageID: UUID(),
                role: String(describing: role),
                contentType: AssistantCardCodec.isCard(content) ? "card" : "text",
                preSanitizeLength: content.count,
                postSanitizeLength: content.count,
                threadID: threadID,
                errorDescription: "Could not resolve chat thread"
            )
        }
        return sendMessage(
            Message(
                role: role,
                content: content,
                thread: thread,
                generatingTime: generatingTime,
                sourceModelName: sourceModelName
            )
        )
    }

    @MainActor
    private func promptSnapshot(
        threadID: UUID,
        model: MLXLMCommon.ModelConfiguration,
        systemPrompt: String
    ) -> LLMChatPromptSnapshot? {
        guard let thread = thread(matching: threadID) else {
            logWarning(
                event: "chat_thread_resolve_failed",
                message: "Could not resolve chat thread for prompt snapshot",
                fields: ["thread_id": threadID.uuidString]
            )
            return nil
        }
        let startedAt = Date()
        return LLMChatPromptSnapshot(
            messages: model.getChatMessages(thread: thread, systemPrompt: systemPrompt),
            systemPromptCharacterCount: systemPrompt.count,
            buildDurationMs: Int(Date().timeIntervalSince(startedAt) * 1_000)
        )
    }

}

// MARK: - Generation entry point

extension ChatView {
    /// Executes generate.
    @MainActor
    private func generate() {
        guard canSubmit else { return }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        commandFeedback = nil

        if let invocation = slashDraft {
            projectLookupTask?.cancel()
            if invocation.id.requiresArgument {
                guard invocation.isReady else {
                    commandFeedback = "Pick a valid value before sending \(invocation.id.canonicalCommand)."
                    logWarning(
                        event: "chat_slash_command_validation_error",
                        message: "Slash command missing valid argument",
                        fields: ["command_id": invocation.id.rawValue]
                    )
                    return
                }
            }

            if invocation.id == .clear {
                showClearConfirmation = true
                return
            }

            startSlashCommandTask(invocation)
            return
        }

        switch SlashCommandCatalog.parse(trimmed) {
        case .invocation(var invocation):
            if invocation.id.requiresArgument {
                let query = invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard query.isEmpty == false else {
                    commandFeedback = "Could not resolve that value. Use \(invocation.id.canonicalCommand) and pick one from commands."
                    slashDraft = SlashCommandInvocation(id: invocation.id, argumentQuery: query, resolvedArgument: nil)
                    prompt = ""
                    openSlashPicker(trigger: "validation")
                    return
                }
                invocation.resolvedArgument = query
            }

            if invocation.id == .clear {
                prompt = ""
                showClearConfirmation = true
                return
            }

            startSlashCommandTask(invocation)
            return

        case .missingRequiredArgument(let commandID, _):
            commandFeedback = "\(commandID.canonicalCommand) needs a name."
            slashDraft = SlashCommandInvocation(id: commandID, argumentQuery: nil, resolvedArgument: nil)
            prompt = ""
            openSlashPicker(trigger: "validation")
            logWarning(
                event: "chat_slash_command_validation_error",
                message: "Slash command missing required argument",
                fields: ["command_id": commandID.rawValue]
            )
            return

        case .unknown(let command):
            commandFeedback = "Unknown command \(command). Type / to browse commands."
            openSlashPicker(trigger: "unknown")
            logWarning(
                event: "chat_slash_command_validation_error",
                message: "Unknown slash command",
                fields: ["command": command]
            )
            return

        case .notCommand:
            break
        }

        guard let thread = ensureCurrentThread() else { return }
        let threadID = thread.id
        generatingThreadID = threadID

        let message = prompt
        activationFocusTask?.cancel()
        activationFocusTask = nil
        projectLookupTask?.cancel()
        if generationTask != nil {
            cancelActiveGeneration(reason: .supersededByNewGeneration)
        }
        let runID = UUID()
        generationRunID = runID
        llm.beginUserTurn(runID: runID)
        promptSubmitTraceInterval = PerformanceTrace.begin("ChatPromptSubmitToFirstStateChange")
        let evaRoute = V2FeatureFlags.evaPlanWithText ? EvaTurnRouter.route(for: message) : nil
        if let evaRoute, evaRoute != .chatAnswer {
            rememberEvaSubmittedDraft(message, runID: runID)
        }
        generationTask = _Concurrency.Task {
            if let route = evaRoute {
                let traceContext = EvaTurnTraceContext(runID: runID, threadID: threadID, route: route)
                logWarning(
                    event: "eva_turn_routed",
                    message: "Routed EVA chat turn",
                    fields: traceContext.logFields.merging([
                        "prompt_chars": String(message.count)
                    ]) { _, new in new }
                )
                switch route {
                case .chatAnswer:
                    await runStandardGeneration(message: message, threadID: threadID, runID: runID)
                case .readOnlyReview, .taskMutation, .habitMutation, .dayPlanning, .weeklyPlanning, .clarification:
                    await runEvaPlanGeneration(message: message, threadID: threadID, traceContext: traceContext)
                }
            } else {
                await runStandardGeneration(message: message, threadID: threadID, runID: runID)
            }
        }
    }

}

// MARK: - EVA plan generation

extension ChatView {
    private func runEvaPlanGeneration(message: String, threadID: UUID, traceContext: EvaTurnTraceContext) async {
        let runID = traceContext.runID
        let route = traceContext.route
        await MainActor.run {
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "eva_plan_generation_started")
            LLMRuntimeCoordinator.shared.acquireSession(reason: "eva_plan_generation")
        }
        defer {
            Task { @MainActor in
                LLMRuntimeCoordinator.shared.releaseSession(reason: "eva_plan_generation")
                if generationRunID == runID {
                    generationTask = nil
                    generationRunID = nil
                    if generatingThreadID == threadID {
                        generatingThreadID = nil
                    }
                    llm.isThinking = false
                    pendingResponsePhase = .idle
                }
            }
        }

        await MainActor.run {
            updatePendingResponsePhase(.buildingContext, for: runID)
            prompt = ""
            appManager.playHaptic()
            _ = sendMessage(role: .user, content: message, threadID: threadID)
            llm.isThinking = true
        }

        let contextPayload = await ChatContextAssembly.buildEvaPlanContextPayloadForCurrentTurn(
            threadID: threadID,
            timeoutMs: evaPlanContextFetchTimeoutMs,
            traceContext: traceContext,
            budgets: chatBudgets
        )
        let contextPolicy = EvaContextPolicy.evaluate(route: route, contextPayload: contextPayload.payload)
        logWarning(
            event: "eva_plan_context_policy",
            message: "Evaluated route-specific EVA context readiness",
            fields: traceContext.logFields.merging([
                "required_context_ready": contextPolicy.requiredContextReady ? "true" : "false",
                "optional_context_partial": contextPolicy.optionalContextPartial ? "true" : "false",
                "fallback_used": contextPayload.usedTimeoutFallback ? "true" : "false"
            ]) { _, new in new }
        )
        guard !Task.isCancelled else {
            logWarning(
                event: "eva_plan_after_context_cancelled",
                message: "EVA plan task cancelled after context build",
                fields: traceContext.logFields
            )
            return
        }
        if contextPolicy.requiredContextReady == false {
            await MainActor.run {
                let result = deliverEvaPlanPayload(
                    .text(
                        content: "I couldn't load enough planning context right now, so I won't invent a plan. Try again once your task context finishes loading.",
                        sourceModelName: nil
                    ),
                    threadID: threadID,
                    traceContext: traceContext,
                    usesModelGenerationForDeliveryGate: false
                )
                if case .persisted = result {
                    restoreEvaSubmittedDraftIfNeeded(runID: runID, reason: "required_context_unavailable")
                }
            }
            return
        }

        await MainActor.run {
            updatePendingResponsePhase(.generating, for: runID)
        }

        let service = AssistantPlannerService(
            llm: llm,
            taskReadModelRepository: LLMContextRepositoryFactory.taskReadModelRepository
        )
        let planResult = await service.generatePlan(
            userPrompt: message,
            thread: Thread(),
            contextPayload: authorizedLifeEvidence.injecting(into: contextPayload.payload),
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            route: route,
            traceContext: traceContext
        )

        switch planResult {
        case .failure(let error):
            await MainActor.run {
                _ = deliverEvaPlanPayload(
                        .text(
                                content: "\(AssistantIdentityText.currentSnapshot().displayName) could not finish this plan. Your prompt is saved; try again or create tasks manually. \(error.localizedDescription)",
                            sourceModelName: nil
                        ),
                    threadID: threadID,
                    traceContext: traceContext,
                    usesModelGenerationForDeliveryGate: true
                )
                restoreEvaSubmittedDraftIfNeeded(runID: runID, reason: "plan_generation_failed")
            }
        case .success(let plan):
            if plan.envelope.commands.isEmpty {
                await MainActor.run {
                    let payload = EvaPlanResponseDelivery.dayOverviewPayload(
                        for: plan,
                        threadID: threadID.uuidString
                    ) ?? EvaPlanResponseDelivery.textPayload(for: plan)
                    let result = deliverEvaPlanPayload(
                        payload,
                        threadID: threadID,
                        traceContext: traceContext,
                        usesModelGenerationForDeliveryGate: plan.usesModelGenerationForDeliveryGate
                    )
                    if case .persisted = result {
                        clearEvaSubmittedDraft(runID: runID, reason: "zero_command_response_persisted")
                    } else {
                        restoreEvaSubmittedDraftIfNeeded(runID: runID, reason: "zero_command_response_not_persisted")
                    }
                }
                return
            }

            let pipeline = await MainActor.run {
                LLMAssistantPipelineFactory.pipeline
            }
            guard let pipeline else {
                await MainActor.run {
                    _ = deliverEvaPlanPayload(
                        .text(
                            content: "\(AssistantIdentityText.currentSnapshot().displayName) can preview this plan, but the apply pipeline is unavailable.",
                            sourceModelName: plan.modelName
                        ),
                        threadID: threadID,
                        traceContext: traceContext,
                        usesModelGenerationForDeliveryGate: plan.usesModelGenerationForDeliveryGate
                    )
                    restoreEvaSubmittedDraftIfNeeded(runID: runID, reason: "apply_pipeline_unavailable")
                }
                return
            }

            logWarning(
                event: "eva_plan_proposal_save_started",
                message: "Saving EVA proposal run before rendering proposal card",
                fields: traceContext.logFields.merging([
                    "command_count": String(plan.envelope.commands.count)
                ]) { _, new in new }
            )
            let proposalThreadID = threadID.uuidString
            let proposalResult = await EvaPlanProposalPersistence.awaitResult { completion in
                pipeline.propose(threadID: proposalThreadID, envelope: plan.envelope) { result in
                    completion(result)
                }
            }
            let proposalSaveResultLabel: String
            switch proposalResult {
            case .success:
                proposalSaveResultLabel = "success"
            case .failure:
                proposalSaveResultLabel = "failure"
            }
            logWarning(
                event: "eva_plan_proposal_save_completed",
                message: "Completed EVA proposal run save before rendering proposal card",
                fields: traceContext.logFields.merging([
                    "result": proposalSaveResultLabel
                ]) { _, new in new }
            )

            await MainActor.run {
                switch proposalResult {
                case .failure(let error):
                    _ = deliverEvaPlanPayload(
                        .text(
                            content: "\(AssistantIdentityText.currentSnapshot().displayName) could not save this plan for review. \(error.localizedDescription)",
                            sourceModelName: plan.modelName
                        ),
                        threadID: threadID,
                        traceContext: traceContext,
                        usesModelGenerationForDeliveryGate: plan.usesModelGenerationForDeliveryGate
                    )
                    restoreEvaSubmittedDraftIfNeeded(runID: runID, reason: "proposal_save_failed")
                case .success(let run):
                    let cards = plan.proposalCards.isEmpty
                        ? EvaProposalCardBuilder.build(commands: plan.envelope.commands, runID: run.id)
                        : plan.proposalCards.map { card in
                            var updated = card
                            updated.runID = run.id
                            return updated
                        }
                    let review = EvaProposalReviewPayload(
                        prompt: message,
                        summary: plan.rationale.isEmpty ? "Here's how your day is planned:" : plan.rationale,
                        contextReceipt: plan.contextReceipt,
                        cards: cards
                    )
                        let cardPayload = AssistantCardPayload(
                            cardType: .proposal,
                            runID: run.id,
                            threadID: threadID.uuidString,
                            status: .pending,
                        rationale: plan.rationale,
                        diffLines: plan.diffLines,
                        destructiveCount: AssistantDiffPreviewBuilder.destructiveCount(for: plan.envelope.commands),
                        affectedTaskCount: AssistantDiffPreviewBuilder.affectedTaskCount(for: plan.envelope.commands),
                        evaProposal: review
                    )
                        let result = deliverEvaPlanPayload(
                            .proposalCard(
                                content: AssistantCardCodec.encode(cardPayload),
                                sourceModelName: plan.modelName
                            ),
                            threadID: threadID,
                            traceContext: traceContext,
                            usesModelGenerationForDeliveryGate: plan.usesModelGenerationForDeliveryGate
                        )
                    if case .persisted = result {
                        clearEvaSubmittedDraft(runID: runID, reason: "proposal_card_persisted")
                    }
                }
            }
        }
    }

}

// MARK: - Slash command execution

extension ChatView {
    @MainActor
    private func executeSlashCommand(_ invocation: SlashCommandInvocation) async {
        guard !Task.isCancelled else { return }
        guard let thread = ensureCurrentThread() else { return }

        let commandLabel = invocation.commandLabel
        projectLookupTask?.cancel()
        prompt = ""
        slashDraft = nil
        isProjectFieldFocused = false
        appManager.playHaptic()
        sendMessage(Message(role: .user, content: commandLabel, thread: thread))

        guard let service = SlashCommandExecutionService.makeDefault() else {
            sendMessage(Message(role: .assistant, content: "Task context is unavailable. Please try again.", thread: thread))
            return
        }

        var resolvedInvocation = invocation
        if invocation.id.requiresArgument {
            let query = invocation.resolvedArgument
                ?? invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            if let resolvedName = await service.resolveArgumentName(for: invocation.id, matching: query) {
                guard !Task.isCancelled else { return }
                resolvedInvocation.resolvedArgument = resolvedName
            }
        }

        do {
            let result = try await service.execute(invocation: resolvedInvocation)
            guard !Task.isCancelled else { return }
            let cardPayload = AssistantCardPayload(
                cardType: .commandResult,
                threadID: thread.id.uuidString,
                status: .applied,
                message: result.summary,
                commandResult: result
            )
            let cardMessage = AssistantCardCodec.encode(cardPayload)

            sendMessage(Message(role: .assistant, content: cardMessage, thread: thread))
            recordRecentCommand(resolvedInvocation.id)
            contextCoordinator.upsert(commandResult: result, threadID: thread.id)

            logWarning(
                event: "chat_slash_command_sent",
                message: "Executed slash command",
                fields: [
                    "command_id": resolvedInvocation.id.rawValue,
                    "result_count": String(result.totalTaskCount)
                ]
            )
        } catch {
            guard !Task.isCancelled else { return }
            let failureMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to run command right now."
            let recoveryQuery: String?
            if let slashError = error as? SlashCommandExecutionError {
                switch slashError {
                case .entityNotFound(_, let query), .ambiguousArgument(_, let query, _):
                    recoveryQuery = query
                case .missingArgument:
                    recoveryQuery = resolvedInvocation.argumentQuery
                case .repositoriesUnavailable:
                    recoveryQuery = nil
                }
            } else {
                recoveryQuery = nil
            }

            sendMessage(Message(role: .assistant, content: failureMessage, thread: thread))
            if resolvedInvocation.id.requiresArgument, let recoveryQuery {
                slashDraft = SlashCommandInvocation(
                    id: resolvedInvocation.id,
                    argumentQuery: recoveryQuery,
                    resolvedArgument: nil
                )
                commandFeedback = failureMessage
                slashPickerQuery = resolvedInvocation.id == .area ? "area" : "project"
                showSlashPicker = true
                isProjectFieldFocused = true
            }
            logWarning(
                event: "chat_slash_command_validation_error",
                message: "Slash command execution failed",
                fields: [
                    "command_id": resolvedInvocation.id.rawValue,
                    "error": failureMessage
                ]
            )
        }
    }

    @MainActor
    private func startSlashCommandTask(_ invocation: SlashCommandInvocation) {
        slashCommandTask?.cancel()
        slashCommandTask = _Concurrency.Task { @MainActor in
            defer {
                slashCommandTask = nil
            }
            await executeSlashCommand(invocation)
        }
    }

}

// MARK: - Standard chat generation

extension ChatView {
    private func runStandardGeneration(message: String, threadID: UUID, runID: UUID) async {
        await MainActor.run {
            LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_generation_started")
            LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_generation")
        }
        defer {
            Task { @MainActor in
                LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_generation")
                if generationRunID == runID {
                    generationTask = nil
                    generationRunID = nil
                    if generatingThreadID == threadID {
                        generatingThreadID = nil
                    }
                    llm.isThinking = false
                    pendingResponsePhase = .idle
                }
            }
        }

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_start")
            }
            return
        }

        await MainActor.run {
            updatePendingResponsePhase(.buildingContext, for: runID)
            prompt = ""
            appManager.playHaptic()
            _ = sendMessage(role: .user, content: message, threadID: threadID)
            llm.isThinking = true
        }

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_context")
            }
            return
        }

        let tID = threadID
        let contextTrace = PerformanceTrace.begin("ChatContextBuild")
        let contextStartedAt = Date()
        let contextPayload = await ChatContextAssembly.buildContextPayloadForCurrentTurn(
            threadID: tID,
            timeoutMs: contextFetchTimeoutMs,
            userPrompt: message,
            budgets: chatBudgets,
            model: activeModelConfiguration,
            injectionPolicy: contextInjectionPolicy,
            contextCharBudgetOverride: LLMTokenBudgetEstimator.estimatedCharacterBudget(
                for: resolvedChatBudget.maxContextTokens
            )
        )
        PerformanceTrace.end(contextTrace)
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_context")
            }
            return
        }
        let contextBuildMs = Int(Date().timeIntervalSince(contextStartedAt) * 1_000)
        ChatGenerationLog.contextBuild(
            threadID: tID,
            durationMs: contextBuildMs,
            fromCache: contextPayload.fromCache,
            usedTimeoutFallback: contextPayload.usedTimeoutFallback
        )
        await MainActor.run {
            updatePendingResponsePhase(.assemblingPrompt, for: runID)
        }
        let promptAssemblyTrace = PerformanceTrace.begin("ChatPromptAssembly")
        let memoryBlock = LLMPersonalMemoryDefaultsStore.promptBlock(for: activeModelConfiguration)
        let executiveContext = await ChatContextAssembly.buildExecutiveContextPrompt(
            tokenBudget: resolvedChatBudget.executiveContextTokens
        )
        let activeAttachments = await ChatContextAssembly.loadSlashAttachments(for: tID)
        let slashCommandContext = ChatContextAssembly.slashCommandContextPrompt(
            attachments: activeAttachments,
            tokenBudget: resolvedChatBudget.slashContextTokens
        )
        let runtimeTaskContext = authorizedLifeEvidence.injecting(into: contextPayload.payload)
        let dynamicSystemPrompt = ChatContextAssembly.composeChatSystemPrompt(
            basePrompt: appManager.systemPrompt,
            model: activeModelConfiguration,
            personalMemory: memoryBlock,
            executiveContext: executiveContext,
            slashContext: slashCommandContext,
            taskContext: runtimeTaskContext
        )
        PerformanceTrace.end(promptAssemblyTrace)
        ChatGenerationLog.promptComponentSizes(
            threadID: tID,
            storedSystemPrompt: appManager.systemPrompt,
            personalMemory: memoryBlock,
            executiveContext: executiveContext,
            runtimeTaskContext: runtimeTaskContext,
            slashContext: slashCommandContext,
            finalPrompt: dynamicSystemPrompt
        )

        guard let modelName = appManager.currentModelName else {
            await MainActor.run {
                _ = sendMessage(role: .assistant, content: "No model selected", threadID: threadID)
                llm.isThinking = false
            }
            return
        }

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_prepare")
            }
            return
        }

        let prepareStartedAt = Date()
        await MainActor.run {
            updatePendingResponsePhase(.preparingModel, for: runID)
        }
        let prepareResult = await LLMRuntimeCoordinator.shared.ensureReady(modelName: modelName)
        let prepareMs = Int(Date().timeIntervalSince(prepareStartedAt) * 1_000)
        ChatGenerationLog.modelPrepare(
            modelName: modelName,
            durationMs: prepareMs,
            prepareResult: prepareResult
        )

        guard prepareResult.ready else {
            await MainActor.run {
                sendMessage(
                    role: .assistant,
                    content: prepareResult.failureMessage ?? "Model failed to prepare. Please switch models or retry.",
                    threadID: threadID
                )
                llm.isThinking = false
            }
            return
        }
        let runtimeModelConfiguration = ModelConfiguration.getModelByName(prepareResult.resolvedModelName)
            ?? activeModelConfiguration
        let chatRequestOptions = LLMGenerationRequestOptions.interactiveChat(for: runtimeModelConfiguration)
        let chatProfile = LLMGenerationProfile.chatProfile(
            for: runtimeModelConfiguration,
            requestOptions: chatRequestOptions
        )

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_generate")
            }
            return
        }

        await MainActor.run {
            updatePendingResponsePhase(.generating, for: runID)
        }
        guard let promptSnapshot = await MainActor.run(
            body: {
                self.promptSnapshot(
                    threadID: threadID,
                    model: runtimeModelConfiguration,
                    systemPrompt: dynamicSystemPrompt
                )
            }
        ) else {
            await MainActor.run {
                _ = sendMessage(
                    role: .assistant,
                    content: "I couldn't prepare this chat thread for generation. Please try again.",
                    threadID: threadID
                )
                llm.isThinking = false
            }
            return
        }
        let output = await llm.generate(
            modelName: prepareResult.resolvedModelName,
            promptSnapshot: promptSnapshot,
            profile: chatProfile,
            requestOptions: chatRequestOptions
        )
        let primaryTerminationReason = await MainActor.run { llm.lastTerminationReason }
        ChatGenerationLog.generationResult(
            event: "chat_primary_generation_result",
            message: "Primary chat generation completed",
            modelName: prepareResult.resolvedModelName,
            runID: runID,
            rawOutput: output,
            terminationReason: primaryTerminationReason
        )
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_generate")
            }
            return
        }

        let primaryOutputAssessment = ChatOutputAssessor.assessChatOutput(
            rawOutput: output,
            modelName: prepareResult.resolvedModelName,
            userPrompt: message,
            terminationReason: primaryTerminationReason,
            runID: runID,
            stage: "primary"
        )

        var finalRawOutput = output
        var finalOutput = primaryOutputAssessment.finalOutput
        var salvageOutput = primaryOutputAssessment.salvageOutput
        var qualityAssessment = primaryOutputAssessment.qualityAssessment
        var templateMismatchDetected = primaryOutputAssessment.templateMismatch
        let primaryUsableOutput = primaryOutputAssessment.finalOutput.isEmpty == false &&
            primaryOutputAssessment.qualityAssessment.hardFailureReasons.isEmpty

        if qualityAssessment.shouldRetry {
            logWarning(
                event: "chat_quality_retry_triggered",
                message: "Retrying chat generation in answer-completion mode",
                fields: [
                    "model_name": prepareResult.resolvedModelName,
                    "termination_reason": primaryTerminationReason ?? "unknown",
                    "reasons": qualityAssessment.reasons.joined(separator: ","),
                    "retry_mode": "answer_completion"
                ]
            )

            let retryContextPayload = await ChatContextAssembly.buildContextPayloadForCurrentTurn(
                threadID: tID,
                timeoutMs: contextFetchTimeoutMs,
                userPrompt: message,
                budgets: chatBudgets,
                model: activeModelConfiguration,
                injectionPolicy: contextInjectionPolicy,
                contextCharBudgetOverride: LLMTokenBudgetEstimator.estimatedCharacterBudget(
                    for: max(160, resolvedChatBudget.maxContextTokens / 2)
                ),
                allowCacheReuse: false
            )
            guard !Task.isCancelled else {
                await MainActor.run {
                    llm.cancelGeneration(reason: "run_cancelled_after_retry_context")
                }
                return
            }

            let retryExecutiveContext = await ChatContextAssembly.buildExecutiveContextPrompt(
                tokenBudget: resolvedChatBudget.executiveContextTokens
            )
            let retryAttachments = await ChatContextAssembly.loadSlashAttachments(for: tID)
            let retryTaskContext = authorizedLifeEvidence.injecting(into: retryContextPayload.payload)
            let retrySystemPrompt = ChatContextAssembly.composeChatSystemPrompt(
                basePrompt: appManager.systemPrompt,
                model: runtimeModelConfiguration,
                personalMemory: LLMPersonalMemoryDefaultsStore.promptBlock(for: runtimeModelConfiguration),
                executiveContext: retryExecutiveContext,
                slashContext: ChatContextAssembly.slashCommandContextPrompt(
                    attachments: retryAttachments,
                    tokenBudget: resolvedChatBudget.slashContextTokens
                ),
                taskContext: retryTaskContext,
                additionalInstruction: "Return only the final answer. Do not repeat the previous analysis, thinking, or intro. Keep it short and directly useful."
            )
            let retryThread = Thread()
            let retrySeedContent = primaryOutputAssessment.finalOutput.isEmpty == false
                ? primaryOutputAssessment.finalOutput
                : output
            retryThread.messages = [
                Message(role: .user, content: message, thread: retryThread),
                Message(
                    role: .assistant,
                    content: retrySeedContent,
                    thread: retryThread,
                    sourceModelName: prepareResult.resolvedModelName
                ),
                Message(
                    role: .user,
                    content: "Continue with only the final answer. Do not repeat the prior analysis, thinking, or bullets.",
                    thread: retryThread
                )
            ]
            let retryRequestOptions = LLMGenerationRequestOptions.answerCompletionRetry(
                for: runtimeModelConfiguration
            )
            let retryProfile = LLMGenerationProfile.chatProfile(
                for: runtimeModelConfiguration,
                requestOptions: retryRequestOptions
            )
            let retryPromptStartedAt = Date()
            let retryPromptSnapshot = LLMChatPromptSnapshot(
                messages: runtimeModelConfiguration.getChatMessages(
                    thread: retryThread,
                    systemPrompt: retrySystemPrompt
                ),
                systemPromptCharacterCount: retrySystemPrompt.count,
                buildDurationMs: Int(Date().timeIntervalSince(retryPromptStartedAt) * 1_000)
            )
            let retryOutput = await llm.generate(
                modelName: prepareResult.resolvedModelName,
                promptSnapshot: retryPromptSnapshot,
                profile: retryProfile,
                requestOptions: retryRequestOptions
            )
            let retryTerminationReason = await MainActor.run { llm.lastTerminationReason }
            ChatGenerationLog.generationResult(
                event: "chat_retry_generation_result",
                message: "Retry chat generation completed",
                modelName: prepareResult.resolvedModelName,
                runID: runID,
                rawOutput: retryOutput,
                terminationReason: retryTerminationReason
            )
            guard !Task.isCancelled else {
                await MainActor.run {
                    llm.cancelGeneration(reason: "run_cancelled_after_retry_generate")
                }
                return
            }

            let retryOutputAssessment = ChatOutputAssessor.assessChatOutput(
                rawOutput: retryOutput,
                modelName: prepareResult.resolvedModelName,
                userPrompt: message,
                terminationReason: retryTerminationReason,
                runID: runID,
                stage: "retry"
            )

            finalRawOutput = retryOutput
            finalOutput = retryOutputAssessment.finalOutput
            salvageOutput = retryOutputAssessment.salvageOutput
            qualityAssessment = retryOutputAssessment.qualityAssessment
            templateMismatchDetected = retryOutputAssessment.templateMismatch

            if qualityAssessment.hardFailureReasons.isEmpty == false && primaryUsableOutput {
                logWarning(
                    event: "chat_retry_preserving_primary_output",
                    message: "Retry produced a worse result; preserving usable primary chat output",
                    fields: [
                        "model_name": prepareResult.resolvedModelName,
                        "run_id": runID.uuidString,
                        "retry_reasons_csv": qualityAssessment.reasons.joined(separator: ","),
                        "primary_length": String(primaryOutputAssessment.finalOutput.count),
                        "retry_length": String(retryOutputAssessment.finalOutput.count)
                    ]
                )
                finalRawOutput = output
                finalOutput = primaryOutputAssessment.finalOutput
                salvageOutput = primaryOutputAssessment.salvageOutput
                qualityAssessment = primaryOutputAssessment.qualityAssessment
                templateMismatchDetected = primaryOutputAssessment.templateMismatch
            }
        }

        if templateMismatchDetected {
            if V2FeatureFlags.llmChatTemplateDiagnosticsEnabled {
                await MainActor.run {
                    guard generationRunID == runID else { return }
                    guard llm.cancelled == false else { return }
                    sendMessage(
                        role: .assistant,
                        content: """
                        [template_mismatch]
                        Model: \(prepareResult.resolvedModelName)
                        Raw preview: \(LoggingService.previewText(finalRawOutput, maxLength: 128))
                        """,
                        threadID: threadID
                    )
                }
                return
            }

            if salvageOutput.isEmpty == false {
                await MainActor.run {
                    guard generationRunID == runID else { return }
                    guard llm.cancelled == false else { return }
                    sendMessage(
                        role: .assistant,
                        content: salvageOutput,
                        threadID: threadID,
                        generatingTime: llm.thinkingTime,
                        sourceModelName: prepareResult.resolvedModelName
                    )
                }
                return
            }
        }

        guard qualityAssessment.isAcceptable, finalOutput.isEmpty == false else {
            ChatGenerationLog.staticFallback(
                modelName: prepareResult.resolvedModelName,
                runID: runID,
                qualityAssessment: qualityAssessment,
                finalOutput: finalOutput
            )
            await MainActor.run {
                guard generationRunID == runID else { return }
                guard llm.cancelled == false else { return }
                sendMessage(
                    role: .assistant,
                    content: "I couldn't turn that into a clear answer yet. Try `/today` for structured help or ask in a shorter, more specific way.",
                    threadID: threadID
                )
            }
            return
        }

        await MainActor.run {
            guard generationRunID == runID else { return }
            guard llm.cancelled == false else { return }
            sendMessage(
                role: .assistant,
                content: finalOutput,
                threadID: threadID,
                generatingTime: llm.thinkingTime,
                sourceModelName: prepareResult.resolvedModelName
            )
        }
    }

}

// MARK: - Draft preservation and cancellation

extension ChatView {
    @MainActor
    private func rememberEvaSubmittedDraft(_ text: String, runID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        evaSubmittedDraft = EvaSubmittedDraft(runID: runID, text: text)
        logWarning(
            event: "eva_draft_preserved",
            message: "Preserved EVA prompt draft for active planner turn",
            fields: [
                "run_id": runID.uuidString,
                "draft_chars": String(text.count)
            ]
        )
    }

    @MainActor
    private func restoreEvaSubmittedDraftIfNeeded(runID: UUID?, reason: String) {
        guard let draft = evaSubmittedDraft else { return }
        if let runID, draft.runID != runID { return }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        prompt = draft.text
        logWarning(
            event: "eva_draft_restored",
            message: "Restored EVA prompt draft after interrupted planner turn",
            fields: [
                "run_id": draft.runID.uuidString,
                "reason": reason,
                "draft_chars": String(draft.text.count)
            ]
        )
    }

    @MainActor
    private func clearEvaSubmittedDraft(runID: UUID?, reason: String) {
        guard let draft = evaSubmittedDraft else { return }
        if let runID, draft.runID != runID { return }
        evaSubmittedDraft = nil
        logWarning(
            event: "eva_draft_cleared",
            message: "Cleared EVA prompt draft after terminal planner outcome",
            fields: [
                "run_id": draft.runID.uuidString,
                "reason": reason
            ]
        )
    }

    @MainActor
    private var evaluatorRuntimePhaseRequiresCancellation: Bool {
        llm.runtimePhase == .preparing ||
            llm.runtimePhase == .thinking ||
            llm.runtimePhase == .answering ||
            llm.runtimePhase == .stopping
    }

    @MainActor
    private func cancellationSnapshot() -> ChatGenerationCancellationSnapshot {
        ChatGenerationCancellationSnapshot(
            generationRunID: generationRunID,
            generatingThreadID: generatingThreadID,
            currentThreadID: currentThread?.id,
            hasGenerationTask: generationTask != nil,
            hasSlashCommandTask: slashCommandTask != nil,
            evaluatorIsRunning: llm.running,
            evaluatorRuntimePhaseRequiresCancellation: evaluatorRuntimePhaseRequiresCancellation
        )
    }

    @MainActor
    private func cancelActiveGeneration(reason: ChatGenerationCancellationReason) {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: reason,
            snapshot: cancellationSnapshot()
        )
        if decision.shouldLog {
            PerformanceTrace.event("ChatGenerationCancelled")
            logWarning(
                event: "chat_generation_cancelled",
                message: "Cancelled active chat generation or slash-command work",
                component: "ChatView",
                fields: [
                    "reason": decision.reason.rawValue,
                    "had_generation_task": decision.hadGenerationTask ? "true" : "false",
                    "had_slash_command_task": decision.hadSlashCommandTask ? "true" : "false",
                    "cancelled_evaluator": decision.shouldCancelEvaluator ? "true" : "false",
                    "run_id": decision.cancelledRunID?.uuidString ?? "none",
                    "thread_id": decision.logThreadID?.uuidString ?? "none"
                ]
            )
        }
        generationTask?.cancel()
        generationTask = nil
        slashCommandTask?.cancel()
        slashCommandTask = nil
        generationRunID = nil
        generatingThreadID = nil
        if let promptSubmitTraceInterval {
            PerformanceTrace.end(promptSubmitTraceInterval)
            self.promptSubmitTraceInterval = nil
        }
        pendingResponsePhase = .idle
        llm.isThinking = false
        if decision.shouldCancelEvaluator {
            llm.cancelGeneration(reason: decision.reason.rawValue)
            LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: decision.reason.rawValue)
        }
        if decision.shouldRestoreSubmittedDraft {
            restoreEvaSubmittedDraftIfNeeded(runID: decision.cancelledRunID, reason: decision.reason.rawValue)
        }
    }

    @MainActor
    private func updatePendingResponsePhase(_ phase: ChatPendingResponsePhase, for runID: UUID) {
        guard generationRunID == runID else { return }
        if phase.isActive, let promptSubmitTraceInterval {
            PerformanceTrace.end(promptSubmitTraceInterval)
            self.promptSubmitTraceInterval = nil
            PerformanceTrace.event("ChatPromptStateTransition")
        }
        pendingResponsePhase = phase
    }

    @MainActor
    @discardableResult
    private func deliverEvaPlanPayload(
        _ payload: EvaPlanResponsePayload,
        threadID: UUID,
        traceContext: EvaTurnTraceContext,
        usesModelGenerationForDeliveryGate: Bool
    ) -> EvaPlanResponseDeliveryResult {
        EvaPlanResponseDelivery.deliver(
            payload: payload,
            traceContext: traceContext,
            gateState: EvaPlanResponseDelivery.GateState(
                taskCancelled: Task.isCancelled,
                runIDMatches: generationRunID == traceContext.runID,
                evaluatorCancelled: llm.cancelled
            ),
            usesModelGenerationForDeliveryGate: usesModelGenerationForDeliveryGate,
            send: { payload in
                sendMessage(
                    role: .assistant,
                    content: payload.content,
                    threadID: threadID,
                    generatingTime: llm.thinkingTime,
                    sourceModelName: payload.sourceModelName
                )
            }
        )
    }

}

// MARK: - Message persistence

extension ChatView {
    /// Executes sendMessage.
    @MainActor
    @discardableResult
    private func sendMessage(_ message: Message) -> ChatMessageSendOutcome {
        let contentType = AssistantCardCodec.isCard(message.content) ? "card" : "text"
        var preSanitizeLength = message.content.count
        var postSanitizeLength = message.content.count
        let threadID = message.thread?.id ?? currentThread?.id
        if message.role == .assistant && AssistantCardCodec.isCard(message.content) == false {
            preSanitizeLength = message.content.count
            let sanitizedText = LLMChatTextSanitizer.sanitizeForDisplay(
                message.content,
                modelName: message.sourceModelName ?? appManager.currentModelName
            )
            let sanitizedResult = LLMChatTextSanitizer.Result(
                text: sanitizedText,
                removedReasoningBlocks: false,
                removedTemplateArtifacts: sanitizedText != message.content
            )
            postSanitizeLength = sanitizedResult.text.count
            logWarning(
                event: "chat_sendMessage_display_sanitize",
                message: "Sanitized assistant message for display persistence",
                fields: [
                    "role": "assistant",
                    "pre_sanitize_length": String(preSanitizeLength),
                    "post_sanitize_length": String(postSanitizeLength),
                    "removed_reasoning_blocks": sanitizedResult.removedReasoningBlocks ? "true" : "false",
                    "removed_template_artifacts": sanitizedResult.removedTemplateArtifacts ? "true" : "false"
                ]
            )
            guard sanitizedResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                let outcome = ChatMessageSendOutcome(
                    status: .emptySanitizedText,
                    messageID: message.id,
                    role: String(describing: message.role),
                    contentType: contentType,
                    preSanitizeLength: preSanitizeLength,
                    postSanitizeLength: postSanitizeLength,
                    threadID: threadID,
                    errorDescription: nil
                )
                logWarning(
                    event: "chat_sendMessage_display_dropped",
                    message: "Assistant message was dropped after display sanitization",
                    fields: [
                        "role": outcome.role,
                        "content_type": outcome.contentType,
                        "message_id": outcome.messageID.uuidString,
                        "thread_id": outcome.threadID?.uuidString ?? "nil",
                        "pre_sanitize_length": String(preSanitizeLength),
                        "post_sanitize_length": String(postSanitizeLength),
                        "save_result": outcome.status.rawValue
                    ]
                )
                return outcome
            }
            message.content = sanitizedResult.text
            postSanitizeLength = sanitizedResult.text.count
        }
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
            refreshTranscriptSnapshot(for: message.thread ?? currentThread)
            if isActivationPresentation,
               activationConfiguration?.showsCompletionObserver == true,
               let threadID = message.thread?.id ?? currentThread?.id {
                switch message.role {
                case .user:
                    onActivationChatEvent?(.userMessagePersisted(threadID: threadID))
                case .assistant:
                    onActivationChatEvent?(
                        .assistantReplyPersisted(
                            threadID: threadID,
                            countsForCompletion: assistantMessageCountsForActivationCompletion(message)
                        )
                    )
                case .system:
                    break
                }
            }
            let outcome = ChatMessageSendOutcome(
                status: .persisted,
                messageID: message.id,
                role: String(describing: message.role),
                contentType: contentType,
                preSanitizeLength: preSanitizeLength,
                postSanitizeLength: postSanitizeLength,
                threadID: threadID,
                errorDescription: nil
            )
            logWarning(
                event: "chat_sendMessage_completed",
                message: "Chat message persistence completed",
                fields: [
                    "role": outcome.role,
                    "content_type": outcome.contentType,
                    "message_id": outcome.messageID.uuidString,
                    "thread_id": outcome.threadID?.uuidString ?? "nil",
                    "pre_sanitize_length": String(outcome.preSanitizeLength),
                    "post_sanitize_length": String(outcome.postSanitizeLength),
                    "save_result": outcome.status.rawValue
                ]
            )
            return outcome
        } catch {
            let outcome = ChatMessageSendOutcome(
                status: .saveFailed,
                messageID: message.id,
                role: String(describing: message.role),
                contentType: contentType,
                preSanitizeLength: preSanitizeLength,
                postSanitizeLength: postSanitizeLength,
                threadID: threadID,
                errorDescription: error.localizedDescription
            )
            logError(
                event: "chat_message_save_failed",
                message: "Failed to save chat message",
                fields: [
                    "role": outcome.role,
                    "content_type": outcome.contentType,
                    "message_id": outcome.messageID.uuidString,
                    "thread_id": outcome.threadID?.uuidString ?? "nil",
                    "pre_sanitize_length": String(outcome.preSanitizeLength),
                    "post_sanitize_length": String(outcome.postSanitizeLength),
                    "save_result": outcome.status.rawValue,
                    "error": error.localizedDescription
                ]
            )
            return outcome
        }
    }

    private func assistantMessageCountsForActivationCompletion(_ message: Message) -> Bool {
        guard message.role == .assistant else { return false }
        guard let payload = AssistantCardCodec.decode(from: message.content) else {
            return true
        }
        return payload.cardType == .commandResult
    }

}

// MARK: - Context invalidation and transcript snapshot

extension ChatView {
    @MainActor
    private func scheduleContextInvalidationForCurrentThread() {
        guard let threadID = currentThread?.id else { return }
        contextInvalidationTask?.cancel()
        contextInvalidationTask = Task {
            let interval = PerformanceTrace.begin("ChatContextInvalidation")
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 150_000_000)
            } catch {
                PerformanceTrace.end(interval)
                return
            }
            await ChatContextAssembly.contextInjectionTracker.clear(threadID: threadID)
            await EvaExecutiveContextService.invalidateCache()
            PerformanceTrace.end(interval)
        }
    }

    @MainActor
    private func refreshTranscriptSnapshot(for thread: Thread? = nil) {
        let snapshot = ChatTranscriptSnapshot(thread: thread ?? currentThread)
        guard transcriptSnapshot != snapshot else {
            if hasCompletedInitialTranscriptRender == false {
                hasCompletedInitialTranscriptRender = true
                if let chatOpenTraceInterval {
                    PerformanceTrace.end(chatOpenTraceInterval)
                    self.chatOpenTraceInterval = nil
                    PerformanceTrace.event("ChatTranscriptFirstRender")
                }
                EvaNavigationPerformanceTrace.markInteractive()
            }
            return
        }

        transcriptSnapshot = snapshot
        if hasCompletedInitialTranscriptRender == false {
            hasCompletedInitialTranscriptRender = true
            if let chatOpenTraceInterval {
                PerformanceTrace.end(chatOpenTraceInterval)
                self.chatOpenTraceInterval = nil
                PerformanceTrace.event("ChatTranscriptFirstRender")
            }
            EvaNavigationPerformanceTrace.markInteractive()
        }
    }

    #if os(macOS)
    /// Executes handleShiftReturn.
    private func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
    #endif
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(
        currentThread: .constant(nil),
        isPromptFocused: $isPromptFocused,
        showChats: .constant(false),
        showSettings: .constant(false)
    )
}
