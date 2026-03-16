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

        append(.today, when: hintText.contains("overdue") || hintText.contains("late") || hintText.contains("today"))
        append(.tomorrow, when: hintText.contains("tomorrow"))
        append(.week, when: hintText.contains("week"))
        append(.month, when: hintText.contains("month"))
        append(.project, when: hintText.contains("project") || hintText.contains("inbox"))
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
            runtimePhase: llm.runtimePhase,
            isRunning: llm.running,
            isPreparingResponse: llm.isThinking
        )
    }

    var body: some View {
        ChatScaffoldView(
            currentThread: $currentThread,
            transcriptSnapshot: transcriptSnapshot,
            liveOutput: liveOutputState,
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
            onOpenSlashPicker: {
                appManager.playHaptic()
                openSlashPicker(trigger: "button")
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
        .onChange(of: prompt) { _, newValue in
            handlePromptChanged(newValue)
        }
        .onChange(of: slashDraft?.id) { _, newValue in
            guard newValue == .project else {
                isProjectFieldFocused = false
                return
            }
            isProjectFieldFocused = true
        }
        .onChange(of: currentThread?.id) { _, _ in
            refreshTranscriptSnapshot()
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
            Task { @MainActor in
                LLMRuntimeCoordinator.shared.acquireSession(reason: "chat_view")
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
        var invocation = SlashCommandInvocation(id: descriptor.id, projectQuery: nil, projectName: nil)
        if descriptor.id == .project {
            invocation.projectQuery = ""
            invocation.projectName = nil
        }
        slashDraft = invocation
        showSlashPicker = false
        prompt = ""
        commandFeedback = nil
        isProjectFieldFocused = descriptor.id == .project

        logWarning(
            event: "chat_slash_command_selected",
            message: "Selected slash command from picker",
            fields: ["command_id": descriptor.id.rawValue]
        )
    }

    private func updateProjectDraftQuery(_ rawQuery: String) {
        guard var invocation = slashDraft, invocation.id == .project else { return }

        projectLookupTask?.cancel()
        invocation.projectQuery = rawQuery
        invocation.projectName = nil
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

            let resolvedName = await LLMContextRepositoryProvider.findProjectName(matching: query)
            await MainActor.run {
                guard var current = slashDraft, current.id == .project else { return }
                let currentQuery = current.projectQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard currentQuery.caseInsensitiveCompare(query) == .orderedSame else { return }
                current.projectName = resolvedName
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
            if invocation.id == .project {
                guard invocation.isReady else {
                    commandFeedback = "Pick a valid project before sending /project."
                    logWarning(
                        event: "chat_slash_command_validation_error",
                        message: "Project slash command missing valid project",
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
            if invocation.id == .project {
                let query = invocation.projectQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard query.isEmpty == false else {
                    commandFeedback = "Could not resolve that project. Use /project and pick one from commands."
                    slashDraft = SlashCommandInvocation(id: .project, projectQuery: query, projectName: nil)
                    prompt = ""
                    openSlashPicker(trigger: "validation")
                    return
                }
                // Use query as an execution hint; deterministic resolver handles ambiguity/not-found.
                invocation.projectName = query
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
            commandFeedback = "\(commandID.canonicalCommand) needs a project name."
            slashDraft = SlashCommandInvocation(id: commandID, projectQuery: nil, projectName: nil)
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
        if invocation.id == .project {
            let query = invocation.projectName
                ?? invocation.projectQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            if let resolvedName = await service.resolveProjectName(matching: query) {
                resolvedInvocation.projectName = resolvedName
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
                case .projectNotFound(let query), .ambiguousProjectName(let query, _):
                    recoveryQuery = query
                case .missingProjectName:
                    recoveryQuery = resolvedInvocation.projectQuery
                case .repositoriesUnavailable:
                    recoveryQuery = nil
                }
            } else {
                recoveryQuery = nil
            }

            await MainActor.run {
                sendMessage(Message(role: .assistant, content: failureMessage, thread: thread))
                if resolvedInvocation.id == .project, let recoveryQuery {
                    slashDraft = SlashCommandInvocation(
                        id: .project,
                        projectQuery: recoveryQuery,
                        projectName: nil
                    )
                    commandFeedback = failureMessage
                    slashPickerQuery = "project"
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
        let memoryBlock = LLMPersonalMemoryDefaultsStore.promptBlock(for: activeModelConfiguration)
        let slashCommandContext = slashCommandContextPrompt(
            for: thread,
            tokenBudget: resolvedChatBudget.slashContextTokens
        )
        let dynamicSystemPrompt = composeChatSystemPrompt(
            basePrompt: appManager.systemPrompt,
            model: activeModelConfiguration,
            personalMemory: memoryBlock,
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

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_generate")
            }
            return
        }

        let output = await llm.generate(
            modelName: prepareResult.resolvedModelName,
            thread: thread,
            systemPrompt: dynamicSystemPrompt
        )
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_generate")
            }
            return
        }

        let sanitizedOutput = LLMChatTextSanitizer.sanitize(
            output,
            stripReasoningBlocks: true,
            stripTemplateArtifacts: true
        ).text
        var finalOutput = sanitizedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryTerminationReason = await MainActor.run { llm.lastTerminationReason }
        var qualityAssessment = LLMChatQualityGate.assess(
            finalOutput,
            userPrompt: message,
            terminationReason: primaryTerminationReason
        )

        if qualityAssessment.shouldRetry {
            logWarning(
                event: "chat_quality_retry_triggered",
                message: "Retrying low-quality chat generation with compact fallback prompt",
                fields: [
                    "model_name": prepareResult.resolvedModelName,
                    "termination_reason": primaryTerminationReason ?? "unknown",
                    "reasons": qualityAssessment.reasons.joined(separator: ",")
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

            let retrySystemPrompt = composeChatSystemPrompt(
                basePrompt: appManager.systemPrompt,
                model: runtimeModelConfiguration,
                taskContext: retryContextPayload.payload,
                additionalInstruction: "Do not introduce yourself. Answer directly in 3 short bullets max."
            )
            let retryThread = Thread()
            retryThread.messages = [Message(role: .user, content: message, thread: retryThread)]
            let retryOutput = await llm.generate(
                modelName: prepareResult.resolvedModelName,
                thread: retryThread,
                systemPrompt: retrySystemPrompt
            )
            guard !Task.isCancelled else {
                await MainActor.run {
                    llm.cancelGeneration(reason: "run_cancelled_after_retry_generate")
                }
                return
            }

            finalOutput = LLMChatTextSanitizer.sanitize(
                retryOutput,
                stripReasoningBlocks: true,
                stripTemplateArtifacts: true
            ).text.trimmingCharacters(in: .whitespacesAndNewlines)
            let retryTerminationReason = await MainActor.run { llm.lastTerminationReason }
            qualityAssessment = LLMChatQualityGate.assess(
                finalOutput,
                userPrompt: message,
                terminationReason: retryTerminationReason
            )
        }

        guard qualityAssessment.isAcceptable, finalOutput.isEmpty == false else {
            await MainActor.run {
                guard generationRunID == runID else { return }
                guard llm.cancelled == false else { return }
                sendMessage(
                    Message(
                        role: .assistant,
                        content: "I couldn't produce a reliable answer with this model. Try `/today` for structured help or switch to a stronger chat model.",
                        thread: thread
                    )
                )
            }
            return
        }

        await MainActor.run {
            guard generationRunID == runID else { return }
            guard llm.cancelled == false else { return }
            sendMessage(Message(role: .assistant, content: finalOutput, thread: thread, generatingTime: llm.thinkingTime))
        }
    }

    @MainActor
    private func cancelActiveGeneration(reason: String) {
        generationTask?.cancel()
        generationTask = nil
        generationRunID = nil
        generatingThreadID = nil
        llm.isThinking = false
        llm.cancelGeneration(reason: reason)
        LLMRuntimeCoordinator.shared.cancelGenerationIfActive(reason: reason)
    }

    /// Executes sendMessage.
    @MainActor
    private func sendMessage(_ message: Message) {
        if message.role == .assistant && AssistantCardCodec.isCard(message.content) == false {
            let sanitized = LLMChatTextSanitizer.sanitize(
                message.content,
                stripReasoningBlocks: true,
                stripTemplateArtifacts: true
            ).text
            guard sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
            message.content = sanitized
        }
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
            refreshTranscriptSnapshot(for: message.thread ?? currentThread)
        } catch {
            logError(
                event: "chat_message_save_failed",
                message: "Failed to save chat message",
                fields: ["error": error.localizedDescription]
            )
        }
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
        slashContext: String? = nil,
        taskContext: String? = nil,
        additionalInstruction: String? = nil
    ) -> String {
        return LLMSystemPromptComposer.compose(
            basePrompt: basePrompt,
            model: model,
            additionalInstruction: additionalInstruction,
            personalMemory: personalMemory,
            slashContext: slashContext,
            taskContext: taskContext
        )
    }

    private func slashCommandContextPrompt(for thread: Thread, tokenBudget: Int) -> String? {
        let recentCards = thread.sortedMessages
            .reversed()
            .compactMap { message -> SlashCommandExecutionResult? in
                guard let payload = AssistantCardCodec.decode(from: message.content) else { return nil }
                return payload.commandResult
            }

        guard let commandResult = recentCards.first else { return nil }

        var lines: [String] = []
        lines.append("Recent slash command context:")
        lines.append("- Command: \(commandResult.commandLabel)")
        lines.append("- Summary: \(commandResult.summary)")

        for section in commandResult.sections.prefix(3) {
            lines.append("\(section.title):")
            for task in section.tasks.prefix(5) {
                var parts = [task.title]
                if let dueLabel = task.dueLabel, dueLabel.isEmpty == false {
                    parts.append(dueLabel)
                }
                if task.projectName.isEmpty == false {
                    parts.append(task.projectName)
                }
                lines.append("- " + parts.joined(separator: " | "))
            }
        }

        let block = lines.joined(separator: "\n")
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return LLMTokenBudgetEstimator.trimPrefix(trimmed, toTokenBudget: tokenBudget)
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
