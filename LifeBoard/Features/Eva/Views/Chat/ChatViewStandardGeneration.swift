import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    func runStandardGeneration(message: String, threadID: UUID, runID: UUID) async {
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
        guard let turnRuntime = EvaTurnRuntime.resolveChat(
            localModelName: appManager.currentModelName,
            offlineModel: activeModelConfiguration,
            reportFailure: { failureText in
                reportGenerationFailure(failureText, prompt: message, threadID: threadID, runID: runID)
            }
        ) else { return }
        let contextBudget = turnRuntime.contextBudget
        let contextTrace = PerformanceTrace.begin("ChatContextBuild")
        let contextStartedAt = Date()
        let contextPayload = await ChatContextAssembly.buildContextPayloadForCurrentTurn(
            threadID: tID,
            timeoutMs: contextFetchTimeoutMs,
            userPrompt: message,
            budgets: chatBudgets,
            model: activeModelConfiguration,
            injectionPolicy: contextInjectionPolicy,
            contextCharBudgetOverride: contextBudget.taskContextCharacters
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
        let memoryBlock = EvaMemoryDefaultsStoreV3.promptBlock(for: activeModelConfiguration)
        let executiveContext = await ChatContextAssembly.buildExecutiveContextPrompt(
            tokenBudget: contextBudget.executiveContextTokens
        )
        let activeAttachments = await ChatContextAssembly.loadSlashAttachments(for: tID)
        let slashCommandContext = ChatContextAssembly.slashCommandContextPrompt(
            attachments: activeAttachments,
            tokenBudget: contextBudget.slashContextTokens
        )
        let runtimeTaskContext = authorizedLifeEvidence.injecting(into: contextPayload.payload)
        let dynamicSystemPrompt = LLMSystemPromptComposer.compose(
            basePrompt: appManager.systemPrompt,
            budget: contextBudget,
            personalMemory: memoryBlock,
            executiveContext: executiveContext,
            slashContext: slashCommandContext,
            taskContext: runtimeTaskContext
        )
        let cloudContext = await turnRuntime.contextSections(
            compactProjection: contextPayload.payload,
            executiveState: executiveContext,
            slashCommandState: slashCommandContext,
            personalMemory: memoryBlock,
            evidence: authorizedLifeEvidence,
            userQuery: message
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
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_prepare")
            }
            return
        }
        await MainActor.run {
            updatePendingResponsePhase(.preparingModel, for: runID)
        }
        let timedPreparation = await EvaRuntimePreparation.prepare(runtime: turnRuntime)
        let prepareResult = timedPreparation.readiness
        ChatGenerationLog.modelPrepare(
            modelName: turnRuntime.modelName,
            durationMs: timedPreparation.durationMs,
            prepareResult: prepareResult
        )
        guard prepareResult.ready else {
            await MainActor.run {
                reportGenerationFailure(
                    prepareResult.failureMessage ?? String(localized: "Couldn’t start \(AssistantIdentityText.currentSnapshot().displayName). Try again."),
                    prompt: message,
                    threadID: threadID,
                    runID: runID
                )
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
                EvaChatPromptSnapshotFactory.make(
                    threadID: threadID,
                    resolveThread: { self.thread(matching: $0) },
                    model: runtimeModelConfiguration,
                    systemPrompt: dynamicSystemPrompt,
                    cloudContext: cloudContext,
                    userInstructions: EvaUserInstructions.customized(
                        storedPrompt: appManager.systemPrompt,
                        builtInPrompts: AppManager.legacyBuiltInSystemPrompts.union([AppManager.defaultSystemPrompt])
                    ),
                    budget: contextBudget
                )
            }
        ) else {
            await MainActor.run {
                reportGenerationFailure(
                    String(localized: "Couldn’t read this chat. Try again."),
                    prompt: message,
                    threadID: threadID,
                    runID: runID
                )
            }
            return
        }
        let output = await llm.generate(
            modelName: prepareResult.resolvedModelName,
            promptSnapshot: promptSnapshot,
            profile: chatProfile,
            requestOptions: chatRequestOptions,
            turnRuntime: turnRuntime
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
        if turnRuntime.usesCloud {
            guard await MainActor.run(body: { generationRunID == runID && llm.cancelled == false }) else { return }
            // A cloud failure comes back as "Failed: …". It is shown once, with
            // Retry, and never stored as something Eva said.
            let normalizedOutput = EvaCloudOutputNormalizer.normalize(output)
            guard normalizedOutput.hasPrefix("Failed:") == false,
                  let deliveredText = turnRuntime.cloudDisplayText(from: output),
                  deliveredText.isEmpty == false else {
                let failureText = turnRuntime.cloudDisplayText(from: output)
                    .flatMap { $0.isEmpty ? nil : $0 }
                    ?? String(localized: "No answer came back. Try again.")
                await MainActor.run {
                    reportGenerationFailure(failureText, prompt: message, threadID: threadID, runID: runID)
                }
                return
            }
            let receipt = EvaContextReceiptSnapshot.make(runtime: turnRuntime, sections: cloudContext)?.encodedData
            let outcome = await MainActor.run { sendMessage(
                role: .assistant, content: deliveredText, threadID: threadID,
                generatingTime: llm.thinkingTime, sourceModelName: turnRuntime.modelName,
                contextReceiptData: receipt
            ) }
            if outcome.status == .persisted {
                await attachMemoryCandidate(proposedFrom: message, to: outcome.messageID, threadID: threadID)
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
                personalMemory: EvaMemoryDefaultsStoreV3.promptBlock(for: runtimeModelConfiguration),
                executiveContext: retryExecutiveContext,
                slashContext: ChatContextAssembly.slashCommandContextPrompt(
                    attachments: retryAttachments,
                    tokenBudget: resolvedChatBudget.slashContextTokens
                ),
                taskContext: retryTaskContext,
                additionalInstruction: "Return only the final answer. Do not repeat the previous analysis, thinking, or intro. Keep it short and directly useful."
            )
            let retrySeedContent = primaryOutputAssessment.finalOutput.isEmpty == false
                ? primaryOutputAssessment.finalOutput
                : output
            let retryPrompt = EvaChatRetryPromptFactory.make(
                userMessage: message,
                seedContent: retrySeedContent,
                sourceModelName: prepareResult.resolvedModelName,
                model: runtimeModelConfiguration,
                systemPrompt: retrySystemPrompt
            )
            let retryOutput = await llm.generate(
                modelName: prepareResult.resolvedModelName,
                promptSnapshot: retryPrompt.snapshot,
                profile: retryPrompt.profile,
                requestOptions: retryPrompt.requestOptions
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
                reportGenerationFailure(
                    String(localized: "Try again, or ask more briefly."),
                    prompt: message,
                    threadID: threadID,
                    runID: runID
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
