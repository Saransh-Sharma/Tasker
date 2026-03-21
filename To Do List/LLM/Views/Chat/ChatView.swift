//
//  ChatView.swift
//

import MarkdownUI
import MLXLMCommon
import SwiftData
import SwiftUI
import os

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    @Environment(\.dismiss) var dismissView

    var presentationMode: ChatPresentationMode = .normal
    var onActivationChatEvent: ((EvaActivationChatEvent) -> Void)? = nil
    var onOpenTaskDetail: ((TaskDefinition) -> Void)? = nil

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
    @State private var generationRunID: UUID?
    @State private var transcriptSnapshot: ChatTranscriptSnapshot = .empty
    @State private var pendingResponsePhase: ChatPendingResponsePhase = .idle
    @StateObject private var contextCoordinator = ChatContextCoordinator()
    @FocusState private var isProjectFieldFocused: Bool

    static private let contextInjectionTracker = ChatContextInjectionTracker()

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

    private var contextInjectionPolicy: ChatContextInjectionPolicy {
        .perTurn(throttleMs: chatBudgets.contextCacheTTLms)
    }

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        var suggestions: [SlashCommandDescriptor] = []
        var seen = Set<SlashCommandID>()

        for commandID in contextualCommandIDs {
            guard seen.insert(commandID).inserted else { continue }
            suggestions.append(SlashCommandCatalog.descriptor(for: commandID))
            if suggestions.count >= 3 {
                return suggestions
            }
        }

        for commandID in recentSlashCommands {
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

    private var contextualCommandIDs: [SlashCommandID] {
        let hintText = contextualHintText
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

    private var contextualHintText: String {
        var fragments: [String] = []
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPrompt.isEmpty == false {
            fragments.append(trimmedPrompt.lowercased())
        }
        fragments.append(contentsOf: transcriptSnapshot.recentUserMessageFragments)
        return fragments.joined(separator: " ")
    }

    private var recentPickerCommands: [SlashCommandDescriptor] {
        var unique = Set<SlashCommandID>()
        return recentSlashCommands.prefix(3).compactMap { commandID in
            guard unique.insert(commandID).inserted else { return nil }
            return SlashCommandCatalog.descriptor(for: commandID)
        }
    }

    private var popularPickerCommands: [SlashCommandDescriptor] {
        let recentSet = Set(recentSlashCommands)
        return SlashCommandCatalog.descriptors
            .filter { recentSet.contains($0.id) == false }
            .sorted { $0.id.popularityRank < $1.id.popularityRank }
            .prefix(5)
            .map { $0 }
    }

    private var allPickerCommands: [SlashCommandDescriptor] {
        SlashCommandCatalog.filteredDescriptors(query: slashPickerQuery, recents: recentSlashCommands, limit: 8)
    }

    var chatTitle: String {
        transcriptSnapshot.title
    }

    private var liveOutputState: ChatLiveOutputState {
        ChatLiveOutputState(
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
            showModelPicker: $showModelPicker,
            showSlashPicker: $showSlashPicker,
            showClearConfirmation: $showClearConfirmation,
            slashDraft: $slashDraft,
            slashPickerQuery: $slashPickerQuery,
            commandFeedback: commandFeedback,
            projectQuery: projectQueryBinding,
            commandSuggestions: commandSuggestions,
            recentCommands: recentPickerCommands,
            popularCommands: popularPickerCommands,
            allCommands: allPickerCommands,
            isGenerationInFlight: isGenerationInFlight,
            canSubmit: canSubmit,
            llmCancelled: llm.cancelled,
            chatTitle: chatTitle,
            onOpenTaskDetail: onOpenTaskDetail,
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
                generate()
            },
            onStop: {
                cancelActiveGeneration(reason: "stop_button")
            },
            onSubmitPrompt: {
                submitPromptFromComposer()
            },
            onClearCurrentThread: {
                clearCurrentThread()
            }
        )
        .onAppear {
            contextCoordinator.loadAttachments(for: currentThread?.id)
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
        .onChange(of: currentThread?.id) { _, _ in
            refreshTranscriptSnapshot()
            contextCoordinator.loadAttachments(for: currentThread?.id)
        }
        .onChange(of: isPromptFocused) { _, focused in
            if focused {
                Task { @MainActor in
                    LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_prompt_focus")
                    LLMRuntimeCoordinator.shared.requestChatEntryPrewarm(
                        trigger: "prompt_focus",
                        delaySeconds: 0.5
                    )
                }
            } else {
                Task { @MainActor in
                    LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_prompt_blur")
                    LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_prompt_focus")
                }
            }
        }
        .onAppear {
            refreshTranscriptSnapshot()
            consumePendingChatLaunchRequest()
            Task { @MainActor in
                LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_view")
                if isActivationPresentation {
                    LLMRuntimeCoordinator.shared.requestChatEntryPrewarm(
                        trigger: "activation_first_chat",
                        delaySeconds: 0
                    )
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard generationTask == nil else { return }
                    isPromptFocused = true
                }
            }
        }
        .onDisappear {
            Task { @MainActor in
                LLMRuntimeCoordinator.shared.cancelDeferredPrewarm(reason: "chat_view_disappear")
                cancelActiveGeneration(reason: "chat_view_disappear")
                LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_prompt_focus")
                LLMRuntimeCoordinator.shared.releaseSession(reason: "chat_view")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskCreated"))) { _ in
            invalidateContextCacheForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskUpdated"))) { _ in
            invalidateContextCacheForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskDeleted"))) { _ in
            invalidateContextCacheForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))) { _ in
            invalidateContextCacheForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeTaskMutationEvent"))) { _ in
            invalidateContextCacheForCurrentThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskerEvaChatLaunchRequestDidChange)) { _ in
            consumePendingChatLaunchRequest()
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

    private func submitPromptFromComposer() {
        #if os(macOS)
        handleShiftReturn()
        #else
        isPromptFocused = true
        generate()
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

    private func handlePromptChanged(_ newValue: String) {
        guard slashDraft == nil else { return }
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return }

        slashPickerQuery = pickerQuery(fromPrompt: trimmed)
        if showSlashPicker == false {
            openSlashPicker(trigger: "typed")
        }
    }

    private func openSlashPicker(trigger: String) {
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            slashPickerQuery = pickerQuery(fromPrompt: trimmed)
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
        cancelActiveGeneration(reason: "clear_thread")
        if let thread = currentThread {
            modelContext.delete(thread)
            try? modelContext.save()
            _Concurrency.Task {
                await ChatView.contextInjectionTracker.clear(threadID: thread.id)
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

    private func pickerQuery(fromPrompt promptText: String) -> String {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return "" }
        let raw = String(trimmed.dropFirst())
        return raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
    }

    /// Executes generate.
    @MainActor
    private func generate() {
        guard canSubmit else { return }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        commandFeedback = nil

        if var invocation = slashDraft {
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
                slashDraft = invocation
            }

            if invocation.id == .clear {
                showClearConfirmation = true
                return
            }

            _Concurrency.Task {
                await executeSlashCommand(invocation)
            }
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

            _Concurrency.Task {
                await executeSlashCommand(invocation)
            }
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
        generatingThreadID = thread.id

        let message = prompt
        if generationTask != nil {
            cancelActiveGeneration(reason: "superseded_by_new_generation")
        }
        let runID = UUID()
        generationRunID = runID
        generationTask = _Concurrency.Task {
            await runStandardGeneration(message: message, thread: thread, runID: runID)
        }
    }

    private func executeSlashCommand(_ invocation: SlashCommandInvocation) async {
        guard let thread = await MainActor.run(body: { ensureCurrentThread() }) else { return }

        let commandLabel = invocation.commandLabel
        await MainActor.run {
            projectLookupTask?.cancel()
            prompt = ""
            slashDraft = nil
            isProjectFieldFocused = false
            appManager.playHaptic()
            sendMessage(Message(role: .user, content: commandLabel, thread: thread))
        }

        guard let service = SlashCommandExecutionService.makeDefault() else {
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: "Task context is unavailable. Please try again.", thread: thread))
            }
            return
        }

        var resolvedInvocation = invocation
        if invocation.id.requiresArgument {
            let query = invocation.resolvedArgument
                ?? invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            if let resolvedName = await service.resolveArgumentName(for: invocation.id, matching: query) {
                resolvedInvocation.resolvedArgument = resolvedName
            }
        }

        do {
            let result = try await service.execute(invocation: resolvedInvocation)
            let cardPayload = AssistantCardPayload(
                cardType: .commandResult,
                threadID: thread.id.uuidString,
                status: .applied,
                message: result.summary,
                commandResult: result
            )
            let cardMessage = AssistantCardCodec.encode(cardPayload)

            await MainActor.run {
                sendMessage(Message(role: .assistant, content: cardMessage, thread: thread))
                recordRecentCommand(resolvedInvocation.id)
                contextCoordinator.upsert(commandResult: result, threadID: thread.id)
            }

            logWarning(
                event: "chat_slash_command_sent",
                message: "Executed slash command",
                fields: [
                    "command_id": resolvedInvocation.id.rawValue,
                    "result_count": String(result.totalTaskCount)
                ]
            )
        } catch {
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

            await MainActor.run {
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

    private func runStandardGeneration(message: String, thread: Thread, runID: UUID) async {
        let threadID = thread.id
        await MainActor.run {
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
            pendingResponsePhase = .buildingContext
            prompt = ""
            appManager.playHaptic()
            sendMessage(Message(role: .user, content: message, thread: thread))
            llm.isThinking = true
        }

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_context")
            }
            return
        }

        let tID = threadID
        let contextStartedAt = Date()
        let contextPayload = await buildContextPayloadForCurrentTurn(
            threadID: tID,
            timeoutMs: contextFetchTimeoutMs,
            userPrompt: message,
            contextCharBudgetOverride: LLMTokenBudgetEstimator.estimatedCharacterBudget(
                for: resolvedChatBudget.maxContextTokens
            )
        )
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_context")
            }
            return
        }
        let contextBuildMs = Int(Date().timeIntervalSince(contextStartedAt) * 1_000)
        if contextPayload.fromCache {
            logWarning(
                event: "chat_context_cache_hit",
                message: "Reused cached chat context payload for current turn",
                fields: [
                    "thread_id": tID.uuidString,
                    "duration_ms": String(contextBuildMs),
                    "timeout_fallback_used": contextPayload.usedTimeoutFallback ? "true" : "false"
                ]
            )
        } else {
            logWarning(
                event: "chat_context_build_ms",
                message: "Built chat context payload for current turn",
                fields: [
                    "thread_id": tID.uuidString,
                    "duration_ms": String(contextBuildMs),
                    "timeout_fallback_used": contextPayload.usedTimeoutFallback ? "true" : "false"
                ]
            )
        }
        await MainActor.run {
            updatePendingResponsePhase(.assemblingPrompt, for: runID)
        }
        let memoryBlock = LLMPersonalMemoryDefaultsStore.promptBlock(for: activeModelConfiguration)
        let executiveContext = await buildExecutiveContextPrompt(
            tokenBudget: resolvedChatBudget.executiveContextTokens
        )
        let activeAttachments = await loadSlashAttachments(for: tID)
        let slashCommandContext = slashCommandContextPrompt(
            attachments: activeAttachments,
            tokenBudget: resolvedChatBudget.slashContextTokens
        )
        let dynamicSystemPrompt = composeChatSystemPrompt(
            basePrompt: appManager.systemPrompt,
            model: activeModelConfiguration,
            personalMemory: memoryBlock,
            executiveContext: executiveContext,
            slashContext: slashCommandContext,
            taskContext: contextPayload.payload
        )
        logWarning(
            event: "chat_prompt_component_sizes",
            message: "Computed runtime prompt component sizes for current turn",
            fields: [
                "thread_id": tID.uuidString,
                "stored_system_prompt_chars": String(appManager.systemPrompt.count),
                "personal_memory_chars": String(memoryBlock?.count ?? 0),
                "executive_context_chars": String(executiveContext?.count ?? 0),
                "runtime_context_chars": String(contextPayload.payload.count),
                "slash_context_chars": String(slashCommandContext?.count ?? 0),
                "final_prompt_chars": String(dynamicSystemPrompt.count),
                "estimated_final_prompt_tokens": String(
                    LLMTokenBudgetEstimator.estimatedTokenCount(for: dynamicSystemPrompt)
                )
            ]
        )

        guard let modelName = appManager.currentModelName else {
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: "No model selected", thread: thread))
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
        logWarning(
            event: "chat_model_prepare_ms",
            message: "Prepared selected model prior to chat generation",
            fields: [
                "model_name": modelName,
                "resolved_model_name": prepareResult.resolvedModelName,
                "duration_ms": String(prepareMs),
                "prewarm_eligible": prepareResult.prewarmEligible ? "true" : "false",
                "prewarm_hit": prepareResult.prewarmHit ? "true" : "false",
                "ready": prepareResult.ready ? "true" : "false"
            ]
        )

        guard prepareResult.ready else {
            await MainActor.run {
                sendMessage(
                    Message(
                        role: .assistant,
                        content: prepareResult.failureMessage ?? "Model failed to prepare. Please switch models or retry.",
                        thread: thread
                    )
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
        let output = await llm.generate(
            modelName: prepareResult.resolvedModelName,
            thread: thread,
            systemPrompt: dynamicSystemPrompt,
            profile: chatProfile,
            requestOptions: chatRequestOptions
        )
        let primaryTerminationReason = await MainActor.run { llm.lastTerminationReason }
        logWarning(
            event: "chat_primary_generation_result",
            message: "Primary chat generation completed",
            fields: [
                "model_name": prepareResult.resolvedModelName,
                "run_id": runID.uuidString,
                "raw_length": String(output.count),
                "raw_is_empty": (output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "true" : "false"),
                "raw_preview_128": LoggingService.previewText(output, maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                "raw_tail_preview_128": LoggingService.previewText(String(output.suffix(128)), maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                "termination_reason": primaryTerminationReason ?? "unknown"
            ]
        )
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_generate")
            }
            return
        }

        let primaryOutputAssessment = assessChatOutput(
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

            let retryContextPayload = await buildContextPayloadForCurrentTurn(
                threadID: tID,
                timeoutMs: contextFetchTimeoutMs,
                userPrompt: message,
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

            let retryExecutiveContext = await buildExecutiveContextPrompt(
                tokenBudget: resolvedChatBudget.executiveContextTokens
            )
            let retryAttachments = await loadSlashAttachments(for: tID)
            let retrySystemPrompt = composeChatSystemPrompt(
                basePrompt: appManager.systemPrompt,
                model: runtimeModelConfiguration,
                personalMemory: LLMPersonalMemoryDefaultsStore.promptBlock(for: runtimeModelConfiguration),
                executiveContext: retryExecutiveContext,
                slashContext: slashCommandContextPrompt(
                    attachments: retryAttachments,
                    tokenBudget: resolvedChatBudget.slashContextTokens
                ),
                taskContext: retryContextPayload.payload,
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
            let retryOutput = await llm.generate(
                modelName: prepareResult.resolvedModelName,
                thread: retryThread,
                systemPrompt: retrySystemPrompt,
                profile: retryProfile,
                requestOptions: retryRequestOptions
            )
            let retryTerminationReason = await MainActor.run { llm.lastTerminationReason }
            logWarning(
                event: "chat_retry_generation_result",
                message: "Retry chat generation completed",
                fields: [
                    "model_name": prepareResult.resolvedModelName,
                    "run_id": runID.uuidString,
                    "raw_length": String(retryOutput.count),
                    "raw_is_empty": (retryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "true" : "false"),
                    "raw_preview_128": LoggingService.previewText(retryOutput, maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                    "raw_tail_preview_128": LoggingService.previewText(String(retryOutput.suffix(128)), maxLength: 128).replacingOccurrences(of: "\n", with: "\\n"),
                    "termination_reason": retryTerminationReason ?? "unknown"
                ]
            )
            guard !Task.isCancelled else {
                await MainActor.run {
                    llm.cancelGeneration(reason: "run_cancelled_after_retry_generate")
                }
                return
            }

            let retryOutputAssessment = assessChatOutput(
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
                        Message(
                            role: .assistant,
                            content: """
                            [template_mismatch]
                            Model: \(prepareResult.resolvedModelName)
                            Raw preview: \(LoggingService.previewText(finalRawOutput, maxLength: 128))
                            """,
                            thread: thread
                        )
                    )
                }
                return
            }

            if salvageOutput.isEmpty == false {
                await MainActor.run {
                    guard generationRunID == runID else { return }
                    guard llm.cancelled == false else { return }
                    sendMessage(
                        Message(
                            role: .assistant,
                            content: salvageOutput,
                            thread: thread,
                            generatingTime: llm.thinkingTime,
                            sourceModelName: prepareResult.resolvedModelName
                        )
                    )
                }
                return
            }
        }

        guard qualityAssessment.isAcceptable, finalOutput.isEmpty == false else {
            logWarning(
                event: "chat_fallback_to_static_message",
                message: "Chat quality gate failed after primary/retry, sending static fallback message",
                fields: [
                    "model_name": prepareResult.resolvedModelName,
                    "run_id": runID.uuidString,
                    "is_acceptable": qualityAssessment.isAcceptable ? "true" : "false",
                    "should_retry": qualityAssessment.shouldRetry ? "true" : "false",
                    "reasons_csv": qualityAssessment.reasons.joined(separator: ","),
                    "hard_reasons_csv": qualityAssessment.hardFailureReasons.joined(separator: ","),
                    "soft_warnings_csv": qualityAssessment.softWarningReasons.joined(separator: ","),
                    "final_length": String(finalOutput.count)
                ]
            )
            await MainActor.run {
                guard generationRunID == runID else { return }
                guard llm.cancelled == false else { return }
                sendMessage(
                    Message(
                        role: .assistant,
                        content: "I couldn't turn that into a clear answer yet. Try `/today` for structured help or ask in a shorter, more specific way.",
                        thread: thread
                    )
                )
            }
            return
        }

        await MainActor.run {
            guard generationRunID == runID else { return }
            guard llm.cancelled == false else { return }
            sendMessage(
                Message(
                    role: .assistant,
                    content: finalOutput,
                    thread: thread,
                    generatingTime: llm.thinkingTime,
                    sourceModelName: prepareResult.resolvedModelName
                )
            )
        }
    }

    private struct ChatOutputAssessment {
        let finalOutput: String
        let salvageOutput: String
        let qualityAssessment: LLMChatQualityAssessment
        let templateMismatch: Bool
        let hasVisibleThinking: Bool
        let hasAnswer: Bool
    }

    private func assessChatOutput(
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

    @MainActor
    private func cancelActiveGeneration(reason: String) {
        generationTask?.cancel()
        generationTask = nil
        generationRunID = nil
        generatingThreadID = nil
        pendingResponsePhase = .idle
        llm.isThinking = false
        llm.cancelGeneration(reason: reason)
        LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: reason)
    }

    @MainActor
    private func updatePendingResponsePhase(_ phase: ChatPendingResponsePhase, for runID: UUID) {
        guard generationRunID == runID else { return }
        pendingResponsePhase = phase
    }

    /// Executes sendMessage.
    @MainActor
    private func sendMessage(_ message: Message) {
        if message.role == .assistant && AssistantCardCodec.isCard(message.content) == false {
            let preSanitizeLength = message.content.count
            let sanitizedText = LLMChatTextSanitizer.sanitizeForDisplay(
                message.content,
                modelName: message.sourceModelName ?? appManager.currentModelName
            )
            let sanitizedResult = LLMChatTextSanitizer.Result(
                text: sanitizedText,
                removedReasoningBlocks: false,
                removedTemplateArtifacts: sanitizedText != message.content
            )
            let postSanitizeLength = sanitizedResult.text.count
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
                logWarning(
                    event: "chat_sendMessage_display_dropped",
                    message: "Assistant message was dropped after display sanitization",
                    fields: [
                        "pre_sanitize_length": String(preSanitizeLength),
                        "post_sanitize_length": String(postSanitizeLength)
                    ]
                )
                return
            }
            message.content = sanitizedResult.text
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
        } catch {
            logError(
                event: "chat_message_save_failed",
                message: "Failed to save chat message",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    private func assistantMessageCountsForActivationCompletion(_ message: Message) -> Bool {
        guard message.role == .assistant else { return false }
        guard let payload = AssistantCardCodec.decode(from: message.content) else {
            return true
        }
        return payload.cardType == .commandResult
    }

    /// Executes buildLLMContextPayloadAsync.
    private func buildLLMContextPayloadAsync(timeoutMs: UInt64) async -> (payload: String, usedTimeoutFallback: Bool) {
        let result = await LLMChatPlanningContextBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryProvider.makeService(
                maxTasksPerSlice: chatBudgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            query: prompt,
            budgets: chatBudgets,
            model: activeModelConfiguration
        )
        return (result.payload, result.usedTimeoutFallback)
    }

    /// Executes buildContextPayloadForCurrentTurn.
    private func buildContextPayloadForCurrentTurn(
        threadID: UUID,
        timeoutMs: UInt64,
        userPrompt: String,
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
            if let cached = await ChatView.contextInjectionTracker.cachedContext(
                for: threadID,
                querySignature: cacheSignature,
                now: now,
                throttleMs: contextInjectionPolicy.throttleMs
            ) {
                return (cached.payload, cached.usedTimeoutFallback, true)
            }
        }

        let built = await LLMChatPlanningContextBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryProvider.makeService(
                maxTasksPerSlice: chatBudgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            query: userPrompt,
            budgets: chatBudgets,
            model: activeModelConfiguration,
            contextCharBudgetOverride: contextCharBudgetOverride
        )
        if allowCacheReuse {
            await ChatView.contextInjectionTracker.store(
                threadID: threadID,
                querySignature: cacheSignature,
                payload: built.payload,
                usedTimeoutFallback: built.usedTimeoutFallback,
                generatedAt: now
            )
        }
        return (built.payload, built.usedTimeoutFallback, false)
    }

    private func invalidateContextCacheForCurrentThread() {
        guard let threadID = currentThread?.id else { return }
        Task {
            await ChatView.contextInjectionTracker.clear(threadID: threadID)
            await EvaExecutiveContextService.invalidateCache()
        }
    }

    @MainActor
    private func refreshTranscriptSnapshot(for thread: Thread? = nil) {
        transcriptSnapshot = ChatTranscriptSnapshot(thread: thread ?? currentThread)
    }

    private func composeChatSystemPrompt(
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

    private func buildExecutiveContextPrompt(tokenBudget: Int) async -> String? {
        guard let service = EvaExecutiveContextService.makeDefault() else { return nil }
        let maxChars = LLMTokenBudgetEstimator.estimatedCharacterBudget(for: tokenBudget)
        let snapshot = await service.buildSnapshot(maxChars: maxChars)
        let trimmed = snapshot.promptBlock.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadSlashAttachments(for threadID: UUID) async -> [ThreadContextAttachmentRecord] {
        await ThreadContextAttachmentStore.shared.attachments(for: threadID)
    }

    private func slashCommandContextPrompt(
        attachments: [ThreadContextAttachmentRecord],
        tokenBudget: Int
    ) -> String? {
        ThreadContextAttachmentResolver.promptBlock(
            for: attachments,
            tokenBudget: tokenBudget
        )
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
