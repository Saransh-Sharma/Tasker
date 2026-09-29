import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    func submitPromptFromComposer() {
        #if os(macOS)
        handleShiftReturn()
        #else
        isPromptFocused = true
        generate()
        #endif
    }

    @MainActor
    func submitPromptFromSendButton() {
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
    func consumePendingChatLaunchRequest() {
        guard let request = EvaChatLaunchRequestStore.shared.consumePendingRequest() else { return }
        slashDraft = nil
        commandFeedback = nil
        showSlashPicker = false
        prompt = request.prompt ?? ""
        isProjectFieldFocused = false
        isPromptFocused = true
        if let context = request.context, let invocation = EvaLaunchContextMapping.invocation(for: context) {
            // Records, not prose: the context becomes the same attachment a
            // typed slash command would produce, through the same gates.
            startSlashCommandTask(invocation)
        }
    }

    @MainActor
    func submitStarterPrompt(_ starter: EvaStarterPrompt) {
        projectLookupTask?.cancel()
        slashDraft = nil
        commandFeedback = nil
        prompt = starter.submissionText
        isPromptFocused = true
        generate()
    }

    @MainActor
    func handleChatViewAppear() {
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
    func handlePromptFocusRequestIfNeeded() {
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
    func handleChatViewDisappear() {
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
    func handleCurrentThreadChanged(from oldThreadID: UUID?, to newThreadID: UUID?) {
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
    func handlePromptFocusChanged(_ focused: Bool) {
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

    func handlePromptChanged(_ newValue: String) {
        guard slashDraft == nil else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return }

        slashPickerQuery = ChatSlashSuggestionCatalog.pickerQuery(fromPrompt: trimmed)
        if showSlashPicker == false {
            openSlashPicker(trigger: "typed")
        }
    }

    func openSlashPicker(trigger: String) {
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

    func selectSlashCommand(_ descriptor: SlashCommandDescriptor) {
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

    func updateProjectDraftQuery(_ rawQuery: String) {
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

    func recordRecentCommand(_ commandID: SlashCommandID) {
        recentSlashCommands.removeAll { $0 == commandID }
        recentSlashCommands.insert(commandID, at: 0)
        if recentSlashCommands.count > 6 {
            recentSlashCommands = Array(recentSlashCommands.prefix(6))
        }
    }

    @MainActor
    func clearCurrentThread() {
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
    func startNewChat() {
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
