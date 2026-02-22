//
//  ChatView.swift
//
//

import MarkdownUI
import SwiftUI
import Combine
import SwiftData
import os
#if os(iOS)
import UIKit
#endif

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

    @State var thinkingTime: TimeInterval?

    @State private var generatingThreadID: UUID?
    @State private var isPreparingResponse = false
    @State private var isGeneratingProposal = false
    @State private var pendingDestructiveMessageID: UUID?
    @State private var pendingDestructivePayload: AssistantCardPayload?
    @State private var showDestructiveApplyConfirmation = false
    @State private var shouldShowPlanHint = false
    @State private var planModeRouteBanner: String?
    @State private var planModeShouldPromptDownload = false
    @State private var consecutiveApplyFailures = 0
    @State private var sessionPlanApplyDisabled = false
    @State private var taskSignal: (openCount: Int, overdueCount: Int) = (0, 0)
    @State private var dynamicSuggestionChips: [String] = []
    @State private var chipRefreshToken = UUID()
    @AppStorage("assistantPlanModeHintShown") private var assistantPlanModeHintShown = false
    private static let pendingPromptKey = "assistant.pending_prompt"
    private static let pendingAssistantMessageKey = "assistant.pending_assistant_message"
    private static let pendingModeKey = "assistant.pending_chat_mode"

    private var resolvedChatMode: AssistantChatMode {
        guard V2FeatureFlags.assistantPlanModeEnabled else {
            return .ask
        }
        return AssistantChatMode(rawValue: appManager.assistantChatMode) ?? .ask
    }

    private var isPlanMode: Bool {
        resolvedChatMode == .plan
    }

    private var promptPlaceholder: String {
        isPlanMode ? "Describe what you want to plan..." : "Ask Eva anything..."
    }

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Chat Input Bar

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField(promptPlaceholder, text: $prompt, axis: .vertical)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker(.textPrimary))
            #if os(iOS) || os(visionOS)
                .padding(.horizontal, TaskerTheme.Spacing.lg)
            #elseif os(macOS)
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .onSubmit {
                    handleShiftReturn()
                }
                .submitLabel(.send)
            #endif
                .padding(.vertical, TaskerTheme.Spacing.sm)
            #if os(iOS) || os(visionOS)
                .frame(minHeight: 48)
            #elseif os(macOS)
                .frame(minHeight: 32)
            #endif
            #if os(iOS)
            .onSubmit {
                isPromptFocused = true
                generate()
            }
            #endif

            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        #if os(iOS) || os(visionOS)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .fill(Color.tasker(.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .stroke(isPlanMode ? Color.tasker(.statusWarning).opacity(0.7) : Color.tasker(.strokeHairline), lineWidth: 1)
        )
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.xl)
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker(.surfaceSecondary))
        )
        #endif
    }

    // MARK: - Model Picker Button

    var modelPickerButton: some View {
        Button {
            appManager.playHaptic()
            showModelPicker.toggle()
        } label: {
            Group {
                Image(systemName: "chevron.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #if os(iOS) || os(visionOS)
                    .frame(width: 16)
                #elseif os(macOS)
                    .frame(width: 12)
                #endif
                    .fontWeight(.semibold)
                    .foregroundColor(Color.tasker(.accentPrimary))
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            #endif
            .background(
                Circle()
                    .fill(Color.tasker(.accentWash))
            )
            .overlay(
                Circle()
                    .stroke(Color.tasker(.accentMuted), lineWidth: 1)
            )
        }
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .scaleOnPress()
    }

    // MARK: - Send Button

    var generateButton: some View {
        Button {
            generate()
        } label: {
            Image(systemName: "arrow.up")
                .font(.tasker(.buttonSmall))
                .fontWeight(.semibold)
                .foregroundColor(isPromptEmpty ? Color.tasker(.textQuaternary) : Color.tasker(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(isPromptEmpty ? Color.tasker(.surfaceTertiary) : Color.tasker(.accentPrimary))
                )
        }
        .disabled(isPromptEmpty)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.md)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .animation(TaskerAnimation.quick, value: isPromptEmpty)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Stop Button

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.caption)
                .foregroundColor(Color.tasker(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(Color.tasker(.statusDanger))
                )
        }
        .disabled(llm.cancelled)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.md)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .scaleOnPress()
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "Chat"
    }

    // MARK: - Empty State

    private var ruleBasedSuggestionChips: [String] {
        buildRuleBasedSuggestionChips(for: taskSignal)
    }

    private func buildRuleBasedSuggestionChips(for signal: (openCount: Int, overdueCount: Int)) -> [String] {
        let calendar = Calendar.current
        var chips: [String] = []

        if taskSignal.overdueCount > 0 {
            chips.append("I have \(taskSignal.overdueCount) overdue tasks — help me triage")
        }
        if calendar.component(.weekday, from: Date()) == 2 {
            chips.append("plan my week")
        }
        if calendar.component(.weekday, from: Date()) == 6 {
            chips.append("what did I accomplish this week?")
        }
        if taskSignal.openCount == 0 {
            chips.append("what should I do first?")
        }

        chips.append("summarize my week")
        chips.append("break down a big task")
        return Array(NSOrderedSet(array: chips).compactMap { $0 as? String }.prefix(6))
    }

    private var contextualSuggestionChips: [String] {
        dynamicSuggestionChips.isEmpty ? ruleBasedSuggestionChips : dynamicSuggestionChips
    }

    private var modeToggle: some View {
        HStack(spacing: TaskerTheme.Spacing.xs) {
            modeButton(title: "Ask", mode: .ask)
            modeButton(title: "Plan", mode: .plan)
            Spacer(minLength: 0)
            if isPlanMode {
                Text("Plan mode")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker(.statusWarning))
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.lg)
    }

    private func modeButton(title: String, mode: AssistantChatMode) -> some View {
        let selected = resolvedChatMode == mode
        return Button {
            setChatMode(mode)
        } label: {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(selected ? Color.tasker(.accentOnPrimary) : Color.tasker(.textSecondary))
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.xs)
                .background(
                    Capsule()
                        .fill(selected ? Color.tasker(.accentPrimary) : Color.tasker(.surfaceSecondary))
                )
        }
        .buttonStyle(.plain)
    }

    var emptyState: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            Spacer()

            // Eva avatar circle
            ZStack {
                Circle()
                    .fill(Color.tasker(.accentWash))
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.tasker(.accentPrimary))
                    .symbolEffect(.wiggle.byLayer, options: .repeat(.periodic(delay: 3.0)))
            }

            VStack(spacing: TaskerTheme.Spacing.xs) {
                Text("ask Eva anything")
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker(.textPrimary))
                Text("your AI assistant knows your tasks and projects")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textTertiary))
                    .multilineTextAlignment(.center)
            }

            // Suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    ForEach(contextualSuggestionChips, id: \.self) { suggestion in
                        Button {
                            prompt = suggestion
                            generate()
                        } label: {
                            Text(suggestion)
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker(.accentPrimary))
                                .padding(.horizontal, TaskerTheme.Spacing.md)
                                .padding(.vertical, TaskerTheme.Spacing.sm)
                                .background(Color.tasker(.accentWash))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                        }
                        .scaleOnPress()
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
            }

            Spacer()
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentThread = currentThread {
                    ConversationView(
                        thread: currentThread,
                        generatingThreadID: generatingThreadID,
                        isPreparingResponse: isPreparingResponse,
                        onApplyProposal: { message, payload in
                            handleApplyProposal(message: message, payload: payload)
                        },
                        onRejectProposal: { message, payload in
                            handleRejectProposal(message: message, payload: payload)
                        },
                        onUndoRun: { message, payload in
                            handleUndoRun(message: message, payload: payload)
                        },
                        onRefreshContext: { message, payload in
                            handleRefreshContext(message: message, payload: payload)
                        }
                    )
                } else {
                    emptyState
                }

                // Bottom input area
                VStack(spacing: TaskerTheme.Spacing.xs) {
                    if currentThread != nil && V2FeatureFlags.assistantPlanModeEnabled {
                        modeToggle
                            .padding(.top, TaskerTheme.Spacing.xs)
                    }
                    if shouldShowPlanHint && isPlanMode {
                        Text("Eva will show changes before applying them. You always confirm.")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker(.textSecondary))
                            .padding(.horizontal, TaskerTheme.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isPlanMode, let planModeRouteBanner, planModeRouteBanner.isEmpty == false {
                        HStack(alignment: .top, spacing: TaskerTheme.Spacing.xs) {
                            Image(systemName: "cpu")
                                .foregroundColor(Color.tasker(.accentPrimary))
                            Text(planModeRouteBanner)
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker(.textSecondary))
                            if planModeShouldPromptDownload {
                                Button("Models") {
                                    showModelPicker = true
                                }
                                .font(.tasker(.caption2))
                                .buttonStyle(.plain)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, TaskerTheme.Spacing.lg)
                    }

                    HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.md) {
                        modelPickerButton
                        chatInput
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .padding(.top, TaskerTheme.Spacing.sm)
                .background(
                    Color.tasker(.bgCanvas)
                        .shadow(color: Color.tasker(.textPrimary).opacity(0.04), radius: 8, y: -4)
                )
            }
            .background(Color.tasker(.bgCanvas))
            .navigationTitle(chatTitle)
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(true)
            #endif
                .sheet(isPresented: $showModelPicker) {
                    NavigationStack {
                        ModelsSettingsView()
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showModelPicker.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showModelPicker.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        LLMSettingsView(currentThread: $currentThread)
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showSettings.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.large] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showSettings.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .onAppear {
                    applyPendingChatSeedIfNeeded()
                    refreshTaskSignalAndSuggestionChips()
                    TaskSemanticIndexRefreshCoordinator.shared.requestRefreshIfStaleSoon(reason: "assistant_chat_open")
                }
                .onReceive(NotificationCenter.default.publisher(for: .homeTaskMutation)) { _ in
                    refreshTaskSignalAndSuggestionChips()
                }
                // MARK: - Main Toolbar
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
                .confirmationDialog(
                    "Apply destructive changes?",
                    isPresented: $showDestructiveApplyConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Apply", role: .destructive) {
                        if let messageID = pendingDestructiveMessageID, let payload = pendingDestructivePayload {
                            applyConfirmedProposal(messageID: messageID, payload: payload)
                        }
                        pendingDestructiveMessageID = nil
                        pendingDestructivePayload = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingDestructiveMessageID = nil
                        pendingDestructivePayload = nil
                    }
                } message: {
                    if let payload = pendingDestructivePayload {
                        Text("This plan contains \(payload.destructiveCount) potentially destructive change(s). Undo is available for 30 minutes after apply.")
                    } else {
                        Text("This plan contains destructive actions.")
                    }
                }
        }
    }

    private enum SlashAction {
        case summary(TaskRange, String?)
        case clear
        case none
    }

    /// Executes generate.
    private func generate() {
        guard !isPromptEmpty else { return }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = parseSlashCommand(trimmed)

        if case .clear = action {
            if let thread = currentThread {
                modelContext.delete(thread)
                try? modelContext.save()
            }
            currentThread = nil
            prompt = ""
            return
        }

        if currentThread == nil {
            let newThread = Thread()
            currentThread = newThread
            modelContext.insert(newThread)
            do {
                try modelContext.save()
                logDebug("[DEBUG] saved new thread OK")
            } catch {
                logError(
                    event: "chat_thread_save_failed",
                    message: "Failed to save chat thread",
                    fields: ["error": error.localizedDescription]
                )
            }
        }

        guard let currentThread else { return }
        generatingThreadID = currentThread.id
        _Concurrency.Task {
            let message = prompt
            prompt = ""
            appManager.playHaptic()
            let resolvedAction = await resolveSlashAction(action)

            var dynamicSystemPrompt = "You are Eva, the user's personal task assistant. Use the provided tasks and project details to answer questions and help manage their work." + "\n\n" + appManager.systemPrompt

            switch resolvedAction {
            case let .summary(range, projectName):
                let summary = PromptMiddleware.buildTasksSummary(range: range, projectName: projectName)
                dynamicSystemPrompt += "\n\nTasks (\(range.description)):\n" + summary
            default:
                break
            }

            await MainActor.run {
                sendMessage(Message(role: .user, content: message, thread: currentThread))
                llm.isThinking = true
                llm.output = "Building context..."
                isPreparingResponse = true
            }

            let selectedModelName = AIRuntimeSnapshot.current().selectedModelName
            let isColdStart = selectedModelName.map { !llm.isWarm(modelName: $0) } ?? false
            let warmupTask: _Concurrency.Task<Void, Never>? = {
                guard let selectedModelName, isColdStart else { return nil }
                let warmupStartedAt = Date()
                logWarning(
                    event: "assistant_model_warmup_started",
                    message: "Started chat-path model warmup",
                    fields: [
                        "model": selectedModelName,
                        "reason": "chat_generate"
                    ]
                )
                return _Concurrency.Task {
                    await MainActor.run {
                        llm.output = "Preparing local model..."
                    }
                    let warmed = await llm.warmup(modelName: selectedModelName)
                    let durationMS = Int(Date().timeIntervalSince(warmupStartedAt) * 1_000)
                    if warmed {
                        logWarning(
                            event: "assistant_model_warmup_completed",
                            message: "Completed chat-path model warmup",
                            fields: [
                                "model": selectedModelName,
                                "reason": "chat_generate",
                                "duration_ms": String(durationMS)
                            ]
                        )
                    } else {
                        logError(
                            event: "assistant_model_warmup_failed",
                            message: "Chat-path model warmup failed",
                            fields: [
                                "model": selectedModelName,
                                "reason": "chat_generate",
                                "duration_ms": String(durationMS)
                            ]
                        )
                    }
                }
            }()

            let injectedContext = await buildLLMContextPayload(for: message)
            dynamicSystemPrompt += "\n\n" + injectedContext
            await warmupTask?.value

            if isPlanMode {
                await MainActor.run {
                    isPreparingResponse = false
                    llm.output = ""
                }
                await generateProposal(
                    message: message,
                    thread: currentThread,
                    contextPrompt: dynamicSystemPrompt
                )
                return
            }

            guard let modelName = selectedModelName else {
                await MainActor.run {
                    sendMessage(Message(role: .assistant, content: "No model selected", thread: currentThread))
                    generatingThreadID = nil
                    isPreparingResponse = false
                    llm.output = ""
                }
                return
            }
            await MainActor.run {
                llm.output = "Generating response..."
            }
            let surfaceStartedAt = Date()
            os_log("SystemPrompt length %d", dynamicSystemPrompt.count)
            logDebug("SYSTEM PROMPT ->\n\(dynamicSystemPrompt)")
            logDebug("USER MESSAGE ->\n\(message)")
            let output = await llm.generate(
                modelName: modelName,
                thread: currentThread,
                systemPrompt: dynamicSystemPrompt,
                profile: .chatAsk,
                onFirstToken: {
                    let latencyMS = llm.lastGenerationFirstTokenLatencyMS ?? 0
                    logWarning(
                        event: "assistant_first_token_latency",
                        message: "Captured chat first-token latency",
                        fields: [
                            "surface": "chat_ask",
                            "model": modelName,
                            "is_cold_start": isColdStart ? "true" : "false",
                            "duration_ms": String(latencyMS),
                            "used_fallback": "false",
                            "timeout_ms": String(Int(LLMGenerationProfile.chatAsk.timeoutSeconds * 1_000))
                        ]
                    )
                }
            )
            let durationMS = Int(Date().timeIntervalSince(surfaceStartedAt) * 1_000)
            logWarning(
                event: "assistant_surface_latency",
                message: "Chat ask generation completed",
                fields: [
                    "surface": "chat_ask",
                    "model": modelName,
                    "is_cold_start": isColdStart ? "true" : "false",
                    "duration_ms": String(durationMS),
                    "used_fallback": "false",
                    "timeout_ms": String(Int(LLMGenerationProfile.chatAsk.timeoutSeconds * 1_000))
                ]
            )
            if llm.lastGenerationTimedOut {
                logWarning(
                    event: "assistant_surface_timeout",
                    message: "Chat ask hit timeout budget",
                    fields: [
                        "surface": "chat_ask",
                        "model": modelName,
                        "is_cold_start": isColdStart ? "true" : "false",
                        "duration_ms": String(durationMS),
                        "used_fallback": "false",
                        "timeout_ms": String(Int(LLMGenerationProfile.chatAsk.timeoutSeconds * 1_000))
                    ]
                )
            }
            logDebug("LLM RESPONSE ->\n\(output)")
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                generatingThreadID = nil
                isPreparingResponse = false
                llm.output = ""
            }
        }
    }

    /// Executes sendMessage.
    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
            logDebug("[DEBUG] saved message OK")
        } catch {
            logError(
                event: "chat_message_save_failed",
                message: "Failed to save chat message",
                fields: ["error": error.localizedDescription]
            )
        }
        do {
            let all = try modelContext.fetch(FetchDescriptor<Message>())
            logDebug("[DEBUG] after inserting message, total messages: \(all.count)")
        } catch {
            logError(
                event: "chat_message_fetch_failed",
                message: "Failed to fetch chat messages",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes applyPendingChatSeedIfNeeded.
    private func applyPendingChatSeedIfNeeded() {
        let defaults = UserDefaults.standard

        if let modeRaw = defaults.string(forKey: Self.pendingModeKey),
           AssistantChatMode(rawValue: modeRaw) != nil {
            appManager.assistantChatMode = modeRaw
            defaults.removeObject(forKey: Self.pendingModeKey)
        }

        let pendingPrompt = defaults.string(forKey: Self.pendingPromptKey)
        let pendingAssistantMessage = defaults.string(forKey: Self.pendingAssistantMessageKey)
        guard pendingPrompt != nil || pendingAssistantMessage != nil else { return }

        if currentThread == nil {
            let newThread = Thread()
            currentThread = newThread
            modelContext.insert(newThread)
            try? modelContext.save()
        }

        guard let thread = currentThread else { return }
        if let pendingAssistantMessage,
           pendingAssistantMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let assistantMessage = Message(role: .assistant, content: pendingAssistantMessage, thread: thread)
            sendMessage(assistantMessage)
        }
        if let pendingPrompt,
           pendingPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            prompt = pendingPrompt
        }

        defaults.removeObject(forKey: Self.pendingPromptKey)
        defaults.removeObject(forKey: Self.pendingAssistantMessageKey)
    }

    // MARK: - Slash command parsing
    /// Executes parseSlashCommand.
    private func parseSlashCommand(_ text: String) -> SlashAction {
        guard text.hasPrefix("/") else { return .none }
        let components = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let command = components.first?.lowercased() else { return .none }

        switch command {
        case "/todo", "/today":
            return .summary(.today, nil)
        case "/tomorrow":
            return .summary(.tomorrow, nil)
        case "/week":
            return .summary(.week, nil)
        case "/month":
            return .summary(.month, nil)
        case "/project":
            if components.count == 2 {
                let query = components[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return .summary(.all, query)
            }
            return .summary(.all, nil)
        case "/clear":
            return .clear
        default:
            return .none
        }
    }

    /// Executes resolveSlashAction.
    private func resolveSlashAction(_ action: SlashAction) async -> SlashAction {
        guard case let .summary(range, projectQuery) = action else { return action }
        guard range == .all, let projectQuery else { return action }
        let match = await LLMContextRepositoryProvider.findProjectName(matching: projectQuery)
        return .summary(.all, match)
    }

    /// Executes buildLLMContextPayload.
    private func buildLLMContextPayload(for query: String) async -> String {
        let startedAt = Date()
        guard let service = LLMContextRepositoryProvider.makeService() else {
            return """
            Context JSON:
            today={}
            upcoming={}
            semantic={}
            """
        }
        async let todayJSONTask = service.buildTodayJSON()
        async let upcomingJSONTask = service.buildUpcomingJSON()
        let todayJSON = await todayJSONTask
        let upcomingJSON = await upcomingJSONTask
        let taskCount = extractTaskCount(from: todayJSON) + extractTaskCount(from: upcomingJSON)
        let hasTags = todayJSON.contains("\"tag_names\"") || upcomingJSON.contains("\"tag_names\"")
        let elapsedMS = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let semanticJSON = await buildSemanticContextJSON(for: query)
        logWarning(
            event: "assistant_context_built",
            message: "Built fresh assistant context payload",
            fields: [
                "task_count": String(taskCount),
                "has_tags": hasTags ? "true" : "false",
                "build_ms": String(elapsedMS),
                "timezone": TimeZone.current.identifier
            ]
        )
        return """
        Context JSON:
        today=\(todayJSON)
        upcoming=\(upcomingJSON)
        semantic=\(semanticJSON)
        """
    }

    /// Executes buildSemanticContextJSON.
    private func buildSemanticContextJSON(for query: String) async -> String {
        guard V2FeatureFlags.assistantSemanticRetrievalEnabled else {
            return "{}"
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "{}" }

        let tasks = await fetchTaskDefinitions()
        let shouldUseSemanticIndex = await TaskSemanticIndexRefreshCoordinator.shared.shouldUseSemanticIndex(
            reason: "assistant_semantic_query"
        )
        let hitsResult = shouldUseSemanticIndex
            ? TaskSemanticRetrievalService.shared.searchDetailed(query: trimmed, topK: 6)
            : TaskSemanticSearchResult(hits: [], fallbackReason: "index_stale")
        let titleLookup = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })

        let payload: [String: Any] = [
            "query": trimmed,
            "fallback_reason": hitsResult.fallbackReason ?? "",
            "top_k": hitsResult.hits.compactMap { hit -> [String: Any]? in
                guard let title = titleLookup[hit.taskID] else { return nil }
                return [
                    "task_id": hit.taskID.uuidString,
                    "title": title,
                    "score": hit.score
                ]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    /// Executes extractTaskCount.
    private func extractTaskCount(from json: String) -> Int {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data, options: []),
            let payload = object as? [String: Any]
        else {
            return 0
        }

        if let tasks = payload["tasks"] as? [[String: Any]] {
            return tasks.count
        }
        if let count = payload["count"] as? Int {
            return count
        }
        return 0
    }

    /// Executes fetchTaskDefinitions.
    private func fetchTaskDefinitions() async -> [TaskDefinition] {
        guard let repository = LLMContextRepositoryProvider.taskReadModelRepository else { return [] }
        return await withCheckedContinuation { continuation in
            repository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    sortBy: .updatedAtDescending,
                    limit: 5_000,
                    offset: 0
                )
            ) { result in
                if case .success(let slice) = result {
                    continuation.resume(returning: slice.tasks)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Executes fetchTaskSignal.
    private func fetchTaskSignal() async -> (openCount: Int, overdueCount: Int) {
        let tasks = await fetchTaskDefinitions()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let open = tasks.filter { !$0.isComplete }
        let overdue = open.filter { ($0.dueDate ?? Date.distantFuture) < startOfToday }
        return (open.count, overdue.count)
    }

    /// Executes refreshTaskSignalAndSuggestionChips.
    private func refreshTaskSignalAndSuggestionChips() {
        let token = UUID()
        chipRefreshToken = token

        Task {
            let signal = await fetchTaskSignal()
            let base = buildRuleBasedSuggestionChips(for: signal)
            await MainActor.run {
                guard chipRefreshToken == token else { return }
                taskSignal = signal
                dynamicSuggestionChips = base
            }

            let refined = await AISuggestionService.shared.refineDynamicChips(
                baseChips: base,
                openTaskCount: signal.openCount,
                overdueCount: signal.overdueCount
            )
            await MainActor.run {
                guard chipRefreshToken == token else { return }
                dynamicSuggestionChips = refined
            }
        }
    }

    /// Executes setChatMode.
    private func setChatMode(_ mode: AssistantChatMode) {
        if mode == .plan, V2FeatureFlags.assistantPlanModeEnabled == false {
            return
        }
        appManager.assistantChatMode = mode.rawValue
        guard mode == .plan else {
            planModeRouteBanner = nil
            planModeShouldPromptDownload = false
            return
        }

        let route = AIChatModeRouter.route(for: .planMode)
        planModeRouteBanner = route.bannerMessage
        planModeShouldPromptDownload = route.shouldPromptDownload

        logWarning(
            event: "assistant_plan_mode_activated",
            message: "Plan mode activated from chat",
            fields: [:]
        )
        if !assistantPlanModeHintShown {
            assistantPlanModeHintShown = true
            shouldShowPlanHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                shouldShowPlanHint = false
            }
        }
    }

    /// Executes generateProposal.
    private func generateProposal(
        message: String,
        thread: Thread,
        contextPrompt: String
    ) async {
        guard sessionPlanApplyDisabled == false else {
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: "Plan/apply is disabled for this session due to repeated apply failures.", thread: thread))
                generatingThreadID = nil
            }
            return
        }

        guard let pipeline = LLMAssistantPipelineProvider.pipeline else {
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: "Assistant pipeline unavailable.", thread: thread))
                generatingThreadID = nil
            }
            return
        }

        await MainActor.run {
            isGeneratingProposal = true
            generatingThreadID = nil
        }
        let tasks = await fetchTaskDefinitions()
        let taskTitleByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })
        var projectNameByID = await LLMContextRepositoryProvider.projectNameLookup()
        for task in tasks {
            if let projectName = task.projectName, projectName.isEmpty == false {
                projectNameByID[task.projectID] = projectName
            }
        }
        let knownTaskIDs = Set(tasks.map(\.id))

        let planner = AssistantPlannerService(llm: llm)
        let result = await planner.generatePlan(
            userPrompt: message,
            thread: thread,
            contextPayload: contextPrompt,
            taskTitleByID: taskTitleByID,
            projectNameByID: projectNameByID,
            knownTaskIDs: knownTaskIDs
        )

        switch result {
        case .failure(let error):
            await MainActor.run {
                sendMessage(Message(role: .assistant, content: error.localizedDescription, thread: thread))
            }
        case .success(let planResult):
            await MainActor.run {
                planModeRouteBanner = planResult.routeBanner
                planModeShouldPromptDownload = planResult.shouldPromptDownload
            }
            let runResult = await proposeRunAsync(
                pipeline: pipeline,
                threadID: thread.id.uuidString,
                envelope: planResult.envelope
            )
            switch runResult {
            case .failure(let error):
                await MainActor.run {
                    sendMessage(Message(role: .assistant, content: "Failed to save proposal: \(error.localizedDescription)", thread: thread))
                }
            case .success(let run):
                let destructiveCount = AssistantDiffPreviewBuilder.destructiveCount(for: planResult.envelope.commands)
                let affectedCount = AssistantDiffPreviewBuilder.affectedTaskCount(for: planResult.envelope.commands)
                let payload = AssistantCardPayload(
                    cardType: .proposal,
                    runID: run.id,
                    threadID: thread.id.uuidString,
                    status: .pending,
                    rationale: planResult.rationale,
                    diffLines: planResult.diffLines,
                    destructiveCount: destructiveCount,
                    affectedTaskCount: affectedCount
                )

                await MainActor.run {
                    sendMessage(
                        Message(
                            role: .assistant,
                            content: AssistantCardCodec.encode(payload),
                            thread: thread,
                            generatingTime: llm.thinkingTime
                        )
                    )
                    logWarning(
                        event: "assistant_proposal_generated",
                        message: "Generated assistant proposal card",
                        fields: [
                            "run_id": run.id.uuidString,
                            "command_count": String(planResult.envelope.commands.count),
                            "destructive_count": String(destructiveCount)
                        ]
                    )
                }
            }
        }

        await MainActor.run {
            isGeneratingProposal = false
            generatingThreadID = nil
        }
    }

    /// Executes handleApplyProposal.
    private func handleApplyProposal(message: Message, payload: AssistantCardPayload) {
        guard let currentThread else { return }
        guard payload.threadID == currentThread.id.uuidString else {
            sendMessage(Message(role: .assistant, content: "This proposal belongs to a different thread.", thread: currentThread))
            return
        }
        if payload.destructiveCount > 0 {
            pendingDestructiveMessageID = message.id
            pendingDestructivePayload = payload
            showDestructiveApplyConfirmation = true
            return
        }
        applyConfirmedProposal(messageID: message.id, payload: payload)
    }

    /// Executes applyConfirmedProposal.
    private func applyConfirmedProposal(messageID: UUID, payload: AssistantCardPayload) {
        guard let runID = payload.runID, let currentThread else { return }
        guard let pipeline = LLMAssistantPipelineProvider.pipeline else { return }
        guard sessionPlanApplyDisabled == false else { return }

        updateCardMessage(messageID: messageID) { proposal in
            proposal.status = .confirmed
            proposal.message = "Confirmed. Applying..."
        }

#if os(iOS)
        var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "assistant_apply") {
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
#endif

        _Concurrency.Task {
#if os(iOS)
            defer {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
#endif
            let runLookup = await fetchRunAsync(pipeline: pipeline, runID: runID)
            switch runLookup {
            case .failure(let error):
                await MainActor.run {
                    updateCardMessage(messageID: messageID) { proposal in
                        proposal.status = .failed
                        proposal.message = "Run lookup failed: \(error.localizedDescription)"
                    }
                }
                return
            case .success(let run):
                guard let run else {
                    await MainActor.run {
                        updateCardMessage(messageID: messageID) { proposal in
                            proposal.status = .failed
                            proposal.message = "Proposal run no longer exists."
                        }
                    }
                    return
                }
                guard run.threadID == currentThread.id.uuidString else {
                    await MainActor.run {
                        updateCardMessage(messageID: messageID) { proposal in
                            proposal.status = .failed
                            proposal.message = "Proposal run belongs to a different thread."
                        }
                    }
                    return
                }
            }

            let confirmed = await confirmRunAsync(pipeline: pipeline, runID: runID)
            switch confirmed {
            case .failure(let error):
                await MainActor.run {
                    updateCardMessage(messageID: messageID) { proposal in
                        proposal.status = .failed
                        proposal.message = "Confirm failed: \(error.localizedDescription)"
                    }
                    consecutiveApplyFailures += 1
                    if consecutiveApplyFailures >= 3 {
                        sessionPlanApplyDisabled = true
                    }
                }
            case .success:
                let applyResult = await applyRunAsync(pipeline: pipeline, runID: runID)
                switch applyResult {
                case .failure(let error):
                    let staleContext = isStaleContextError(error)
                    let failurePresentation = await rollbackFailurePresentation(
                        pipeline: pipeline,
                        runID: runID,
                        error: error,
                        staleContext: staleContext
                    )
                    await MainActor.run {
                        updateCardMessage(messageID: messageID) { proposal in
                            proposal.status = failurePresentation.status
                            proposal.message = failurePresentation.message
                        }
                        consecutiveApplyFailures += 1
                        logError(
                            event: "assistant_apply_failed",
                            message: "Assistant apply failed from chat card",
                            fields: [
                                "run_id": runID.uuidString,
                                "error": error.localizedDescription
                            ]
                        )
                        if consecutiveApplyFailures >= 3 {
                            sessionPlanApplyDisabled = true
                            sendMessage(Message(role: .assistant, content: "Plan/apply is disabled for this session after repeated apply failures.", thread: currentThread))
                        }
                    }
                case .success(let run):
                    await MainActor.run {
                        consecutiveApplyFailures = 0
                        updateCardMessage(messageID: messageID) { proposal in
                            proposal.status = .applied
                            proposal.message = "Applied successfully."
                        }

                        let undoPayload = AssistantCardPayload(
                            cardType: .undo,
                            runID: run.id,
                            threadID: currentThread.id.uuidString,
                            status: .undoAvailable,
                            rationale: nil,
                            diffLines: [],
                            destructiveCount: 0,
                            affectedTaskCount: 0,
                            expiresAt: (run.appliedAt ?? Date()).addingTimeInterval(30 * 60),
                            message: "Changes applied."
                        )
                        sendMessage(
                            Message(
                                role: .assistant,
                                content: AssistantCardCodec.encode(undoPayload),
                                thread: currentThread
                            )
                        )
                        logWarning(
                            event: "assistant_apply_success",
                            message: "Assistant apply succeeded from chat card",
                            fields: ["run_id": runID.uuidString]
                        )
                    }
                }
            }
        }
    }

    /// Executes handleRefreshContext.
    private func handleRefreshContext(message: Message, payload: AssistantCardPayload) {
        guard let currentThread else { return }
        updateCardMessage(messageID: message.id) { card in
            card.message = "Context refreshed. Re-run your plan request."
        }
        _Concurrency.Task {
            _ = await buildLLMContextPayload(for: "")
            await MainActor.run {
                sendMessage(
                    Message(
                        role: .assistant,
                        content: "Context refreshed. Please submit the plan request again.",
                        thread: currentThread
                    )
                )
                logWarning(
                    event: "assistant_context_refresh_triggered",
                    message: "User triggered context refresh from failed proposal",
                    fields: ["run_id": payload.runID?.uuidString ?? "unknown"]
                )
            }
        }
    }

    /// Executes handleRejectProposal.
    private func handleRejectProposal(message: Message, payload: AssistantCardPayload) {
        guard let runID = payload.runID, let currentThread else { return }
        guard let pipeline = LLMAssistantPipelineProvider.pipeline else { return }
        _Concurrency.Task {
            let runLookup = await fetchRunAsync(pipeline: pipeline, runID: runID)
            switch runLookup {
            case .failure(let error):
                await MainActor.run {
                    updateCardMessage(messageID: message.id) { proposal in
                        proposal.status = .failed
                        proposal.message = "Run lookup failed: \(error.localizedDescription)"
                    }
                }
                return
            case .success(let run):
                guard let run else {
                    await MainActor.run {
                        updateCardMessage(messageID: message.id) { proposal in
                            proposal.status = .failed
                            proposal.message = "Proposal run no longer exists."
                        }
                    }
                    return
                }
                guard run.threadID == currentThread.id.uuidString else {
                    await MainActor.run {
                        updateCardMessage(messageID: message.id) { proposal in
                            proposal.status = .failed
                            proposal.message = "Proposal run belongs to a different thread."
                        }
                    }
                    return
                }
            }

            let result = await rejectRunAsync(pipeline: pipeline, runID: runID)
            await MainActor.run {
                switch result {
                case .failure(let error):
                    updateCardMessage(messageID: message.id) { proposal in
                        proposal.status = .failed
                        proposal.message = "Reject failed: \(error.localizedDescription)"
                    }
                case .success:
                    updateCardMessage(messageID: message.id) { proposal in
                        proposal.status = .rejected
                        proposal.message = "Rejected."
                    }
                    logWarning(
                        event: "assistant_proposal_rejected",
                        message: "Proposal rejected from card",
                        fields: ["run_id": runID.uuidString]
                    )
                }
            }
        }
    }

    /// Executes handleUndoRun.
    private func handleUndoRun(message: Message, payload: AssistantCardPayload) {
        guard let runID = payload.runID, let currentThread else { return }
        guard let pipeline = LLMAssistantPipelineProvider.pipeline else { return }

        _Concurrency.Task {
            let runLookup = await fetchRunAsync(pipeline: pipeline, runID: runID)
            switch runLookup {
            case .failure(let error):
                await MainActor.run {
                    updateCardMessage(messageID: message.id) { undoCard in
                        undoCard.status = .failed
                        undoCard.message = "Run lookup failed: \(error.localizedDescription)"
                    }
                }
                return
            case .success(let run):
                guard let run else {
                    await MainActor.run {
                        updateCardMessage(messageID: message.id) { undoCard in
                            undoCard.status = .failed
                            undoCard.message = "Undo run no longer exists."
                        }
                    }
                    return
                }
                guard run.threadID == currentThread.id.uuidString else {
                    await MainActor.run {
                        updateCardMessage(messageID: message.id) { undoCard in
                            undoCard.status = .failed
                            undoCard.message = "Undo run belongs to a different thread."
                        }
                    }
                    return
                }
            }

            let result = await undoRunAsync(pipeline: pipeline, runID: runID)
            await MainActor.run {
                switch result {
                case .failure(let error):
                    updateCardMessage(messageID: message.id) { undoCard in
                        undoCard.status = .failed
                        undoCard.message = "Undo failed: \(error.localizedDescription)"
                    }
                case .success:
                    updateCardMessage(messageID: message.id) { undoCard in
                        undoCard.status = .undone
                        undoCard.message = "Changes reverted."
                        undoCard.expiresAt = Date()
                    }
                    logWarning(
                        event: "assistant_undo_invoked",
                        message: "Undo invoked from card",
                        fields: ["run_id": runID.uuidString]
                    )
                }
            }
        }
    }

    /// Executes updateCardMessage.
    private func updateCardMessage(messageID: UUID, mutate: (inout AssistantCardPayload) -> Void) {
        guard let currentThread else { return }
        guard let target = currentThread.messages.first(where: { $0.id == messageID }) else { return }
        guard var payload = AssistantCardCodec.decode(from: target.content) else { return }
        mutate(&payload)
        target.content = AssistantCardCodec.encode(payload)
        try? modelContext.save()
    }

    /// Executes proposeRunAsync.
    private func proposeRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        threadID: String,
        envelope: AssistantCommandEnvelope
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            pipeline.propose(threadID: threadID, envelope: envelope) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes confirmRunAsync.
    private func confirmRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            pipeline.confirm(runID: runID) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes fetchRunAsync.
    private func fetchRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID
    ) async -> Result<AssistantActionRunDefinition?, Error> {
        await withCheckedContinuation { continuation in
            pipeline.fetchRun(id: runID) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes applyRunAsync.
    private func applyRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            pipeline.applyConfirmedRun(id: runID) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes rejectRunAsync.
    private func rejectRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            pipeline.reject(runID: runID) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes undoRunAsync.
    private func undoRunAsync(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            pipeline.undoAppliedRun(id: runID) { result in
                continuation.resume(returning: result)
            }
        }
    }

    /// Executes rollbackFailurePresentation.
    private func rollbackFailurePresentation(
        pipeline: AssistantActionPipelineUseCase,
        runID: UUID,
        error: Error,
        staleContext: Bool
    ) async -> (status: AssistantCardStatus, message: String) {
        if staleContext {
            return (.failed, "Apply failed: task state changed. Refresh context and re-plan.")
        }

        let runLookup = await fetchRunAsync(pipeline: pipeline, runID: runID)
        if case .success(let run?) = runLookup {
            switch run.rollbackStatus {
            case .verified:
                let commandCount = commandCountFromProposalData(run.proposalData)
                let countText = commandCount > 0 ? "\(commandCount)" : "All"
                return (
                    .rollbackComplete,
                    "\(countText) change(s) failed to apply. All changes were rolled back. Your tasks are unchanged."
                )
            case .failed:
                return (
                    .rollbackFailed,
                    "Apply failed and rollback could not be fully verified. Review tasks before retrying."
                )
            default:
                break
            }
        }

        return (.failed, "Apply failed: \(error.localizedDescription)")
    }

    /// Executes commandCountFromProposalData.
    private func commandCountFromProposalData(_ data: Data?) -> Int {
        guard
            let data,
            let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data)
        else {
            return 0
        }
        return envelope.commands.count
    }

    /// Executes isStaleContextError.
    private func isStaleContextError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("404")
            || message.contains("not found")
            || message.contains("missing task")
            || message.contains("stale")
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
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}
