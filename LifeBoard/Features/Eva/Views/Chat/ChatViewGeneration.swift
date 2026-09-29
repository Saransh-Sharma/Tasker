import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

// MARK: - Generation entry point
extension ChatView {
    /// Executes generate.
    @MainActor
    func generate(bypassingCloudReadiness: Bool = false) {
        // Sending settles any receipt still open: an edit-and-resend is final
        // once the edited message goes out.
        EvaChatReceiptCenter.shared.dismiss()
        guard canSubmit else { return }
        // A new send replaces any failed turn still on screen.
        generationFailure = nil

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        commandFeedback = nil

        // E4: a ritual asked for by phrase or slash opens over the chat instead
        // of being answered as prose. Gated rituals fall through (phrase) or
        // say so (slash), so the turn is never swallowed silently.
        if slashDraft == nil, let ritual = EvaRitualPhraseRouter.match(trimmed) {
            let available = evaRitualPresenter?.isAvailable(ritual.kind) ?? false
            if available {
                prompt = ""
                presentedRitual = ritual
                return
            } else if trimmed.hasPrefix("/") {
                commandFeedback = String(localized: "\(ritual.kind.title) isn’t available yet.")
                return
            }
        }

        if let invocation = slashDraft {
            projectLookupTask?.cancel()
            if invocation.id.requiresArgument {
                guard invocation.isReady else {
                    commandFeedback = String(localized: "Pick a value for \(invocation.id.canonicalCommand).")
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
                    commandFeedback = String(localized: "Couldn’t find that. Pick one from the list.")
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
            commandFeedback = String(localized: "\(commandID.canonicalCommand) needs a name.")
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
            commandFeedback = String(localized: "Unknown command \(command). Type / for commands.")
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

        let message = prompt
        let evaRoute = V2FeatureFlags.evaPlanWithText ? EvaTurnRouter.route(for: message) : nil
        if bypassingCloudReadiness == false,
           requiresCloudReadiness(for: evaRoute),
           gateCloudSendUntilReady(message: message) {
            return
        }
        pendingCloudSend = nil
        let activationDraftThreadID = currentThread?.id
        guard let thread = ensureCurrentThread() else { return }
        EvaPendingActivationDraftStore.clear(threadID: activationDraftThreadID)
        let threadID = thread.id
        generatingThreadID = threadID

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
                case .capture:
                    await runLocalCapture(message: message, threadID: threadID, runID: runID)
                case .navigation:
                    await runLocalNavigation(message: message, threadID: threadID, runID: runID)
                case .readOnlyReview, .taskMutation, .habitMutation, .dayPlanning, .weeklyPlanning, .clarification:
                    await runEvaPlanGeneration(message: message, threadID: threadID, traceContext: traceContext)
                }
            } else {
                await runStandardGeneration(message: message, threadID: threadID, runID: runID)
            }
        }
    }

    func requiresCloudReadiness(for route: EvaTurnRoute?) -> Bool {
        EvaChatCloudReadinessPolicy.requiresCloud(
            preference: providerPreference,
            route: route
        )
    }

    @MainActor
    func gateCloudSendUntilReady(message: String) -> Bool {
        guard cloudAccess.state != .ready else { return false }
        let pending = PendingCloudSend(id: UUID(), text: message)
        pendingCloudSend = pending
        EvaPendingActivationDraftStore.save(message, threadID: currentThread?.id)
        cloudReadinessTask?.cancel()
        cloudReadinessTask = _Concurrency.Task { @MainActor in
            let ready = await cloudAccess.ensureReadyForSend(promptID: pending.id)
            guard Task.isCancelled == false, ready else { return }
            resumePendingCloudSend(pending)
        }
        return true
    }

    @MainActor
    func confirmCloudAccessAndResume() {
        let pending = pendingCloudSend
        cloudReadinessTask?.cancel()
        cloudReadinessTask = _Concurrency.Task { @MainActor in
            let ready = await cloudAccess.ensureActivated(source: .chatInlineAction)
            guard Task.isCancelled == false, ready, let pending else { return }
            resumePendingCloudSend(pending)
        }
    }

    @MainActor
    func retryCloudAccessAndResume() {
        cloudAccess.selectCloud()
        let pending = pendingCloudSend
        cloudReadinessTask?.cancel()
        cloudReadinessTask = _Concurrency.Task { @MainActor in
            let ready = await cloudAccess.ensureActivated(source: .chatInlineAction)
            guard Task.isCancelled == false, ready, let pending else { return }
            resumePendingCloudSend(pending)
        }
    }

    @MainActor
    func reconnectAppleAndResume() {
        let pending = pendingCloudSend
        cloudReadinessTask?.cancel()
        cloudReadinessTask = _Concurrency.Task { @MainActor in
            let ready = await cloudAccess.reconnectApple()
            guard Task.isCancelled == false, ready, let pending else { return }
            resumePendingCloudSend(pending)
        }
    }

    @MainActor
    func useOfflineEvaForPendingSend() {
        guard let selected = appManager.currentModelName, appManager.installedModels.contains(selected) else {
            showSettings = true
            return
        }
        providerPreference = .offline
        cloudAccess.selectOffline()
        guard let pending = pendingCloudSend else { return }
        resumePendingCloudSend(pending)
    }

    @MainActor
    func resumePendingCloudSend(_ pending: PendingCloudSend) {
        guard cloudInteractionIsActive, pendingCloudSend == pending else { return }
        pendingCloudSend = nil
        cloudReadinessTask = nil
        // If the person edited while activation was running, preserve the new
        // draft and wait for another explicit send instead of submitting stale text.
        guard prompt == pending.text else { return }
        EvaPendingActivationDraftStore.clear(threadID: currentThread?.id)
        Task {
            await ProductTelemetry.shared.record(
                .evaActivationAndSendCompleted,
                outcome: providerPreference.rawValue
            )
        }
        generate(bypassingCloudReadiness: true)
    }
}

// MARK: - Transient generation failures

/// A failed turn. It lives in view state only: the thread never stores it, so
/// failure text is never replayed to the model as conversation history.
struct ChatGenerationFailure: Equatable, Identifiable {
    let id = UUID()
    let threadID: UUID
    let prompt: String
    let userMessageID: UUID?
    let message: String
}

extension ChatView {
    var canUseOfflineForFailedGeneration: Bool {
        guard providerPreference != .offline,
              let selected = appManager.currentModelName else { return false }
        return appManager.installedModels.contains(selected)
    }

    /// Records a failed turn for `runID` without writing it into the thread.
    @MainActor
    func reportGenerationFailure(_ text: String, prompt: String, threadID: UUID, runID: UUID) {
        guard generationRunID == nil || generationRunID == runID else { return }
        guard llm.cancelled == false else { return }
        let userMessageID = thread(matching: threadID)?
            .sortedMessagesSnapshot()
            .last(where: { $0.role == .user && $0.content == prompt })?
            .id
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        generationFailure = ChatGenerationFailure(
            threadID: threadID,
            prompt: prompt,
            userMessageID: userMessageID,
            message: trimmed.isEmpty ? String(localized: "Something went wrong. Try again.") : trimmed
        )
        llm.isThinking = false
        // Retry is offered, so the draft does not also need to come back.
        clearEvaSubmittedDraft(runID: runID, reason: "generation_failure_reported")
        Haptic.fail.play()
    }

    /// Sends the failed message again. The earlier copy of the message is
    /// removed first so the retry doesn't leave it in the thread twice.
    @MainActor
    func retryFailedGeneration(preferOffline: Bool) {
        guard let failure = generationFailure, failure.threadID == currentThread?.id else {
            generationFailure = nil
            return
        }
        if preferOffline {
            providerPreference = .offline
            cloudAccess.selectOffline()
        }
        if let messageID = failure.userMessageID,
           let thread = thread(matching: failure.threadID),
           let message = thread.messages.first(where: { $0.id == messageID }) {
            modelContext.delete(message)
            do {
                try modelContext.save()
            } catch {
                logError(
                    event: "chat_generation_retry_cleanup_failed",
                    message: "Could not remove the failed turn's message before retrying",
                    fields: ["error": error.localizedDescription]
                )
            }
            refreshTranscriptSnapshot(for: thread)
        }
        generationFailure = nil
        slashDraft = nil
        prompt = failure.prompt
        generate()
    }
}
