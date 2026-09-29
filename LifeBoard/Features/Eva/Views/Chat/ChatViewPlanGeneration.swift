import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    func runEvaPlanGeneration(message: String, threadID: UUID, traceContext: EvaTurnTraceContext) async {
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
                reportGenerationFailure(
                    String(localized: "Couldn’t load your plan. Try again."),
                    prompt: message,
                    threadID: threadID,
                    runID: runID
                )
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
        let planUsesCloud = await MainActor.run { EvaCloudAccountState.shared.canUseCloud }
        let planResult = await service.generatePlan(
            userPrompt: message,
            thread: Thread(),
            contextPayload: planUsesCloud
                ? contextPayload.payload
                : authorizedLifeEvidence.injecting(into: contextPayload.payload),
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            route: route,
            traceContext: traceContext
        )

        switch planResult {
        case .failure(let error):
            await MainActor.run {
                let hint: String
                switch error {
                case .noModelConfigured:
                    hint = String(localized: "Pick a model in Settings.")
                case .generationFailed, .parseFailed, .pipelineUnavailable:
                    hint = String(localized: "Try again.")
                }
                reportGenerationFailure(
                    String(localized: "Couldn’t finish the plan. \(hint)"),
                    prompt: message,
                    threadID: threadID,
                    runID: runID
                )
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
                    reportGenerationFailure(
                        String(localized: "Couldn’t prepare changes. Try again."),
                        prompt: message,
                        threadID: threadID,
                        runID: runID
                    )
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
                case .failure:
                    reportGenerationFailure(
                        String(localized: "Couldn’t save the plan. Try again."),
                        prompt: message,
                        threadID: threadID,
                        runID: runID
                    )
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
                        summary: plan.rationale.isEmpty ? String(localized: "Today’s plan") : plan.rationale,
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
