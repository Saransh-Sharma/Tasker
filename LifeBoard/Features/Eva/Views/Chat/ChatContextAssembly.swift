import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

/// Context-payload and system-prompt assembly for a chat turn.
///
/// These were `ChatView` methods that only ever read budgets and the active
/// model, so they move out wholesale; the per-thread injection cache moves with
/// them (it was a `static let` on the view and stays a single shared instance).
enum ChatContextAssembly {
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
