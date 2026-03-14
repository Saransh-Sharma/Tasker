//
//  ChatView.swift
//

import MarkdownUI
import SwiftData
import SwiftUI
import os

private actor ChatContextInjectionTracker {
    struct CachedContext {
        let payload: String
        let generatedAt: Date
        let usedTimeoutFallback: Bool
    }

    private var cacheByThreadID: [UUID: CachedContext] = [:]

    /// Executes cachedContext.
    func cachedContext(
        for threadID: UUID,
        now: Date,
        throttleMs: UInt64
    ) -> CachedContext? {
        guard throttleMs > 0, let cached = cacheByThreadID[threadID] else {
            return nil
        }
        let ageMs = now.timeIntervalSince(cached.generatedAt) * 1_000
        return ageMs < Double(throttleMs) ? cached : nil
    }

    /// Executes store.
    func store(threadID: UUID, payload: String, usedTimeoutFallback: Bool, generatedAt: Date) {
        cacheByThreadID[threadID] = CachedContext(
            payload: payload,
            generatedAt: generatedAt,
            usedTimeoutFallback: usedTimeoutFallback
        )
    }

    /// Executes clear.
    func clear(threadID: UUID) {
        cacheByThreadID.removeValue(forKey: threadID)
    }
}

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
    @FocusState private var isProjectFieldFocused: Bool

    static private let contextInjectionTracker = ChatContextInjectionTracker()

    private var chatBudgets: LLMChatBudgets {
        LLMChatBudgets.active
    }

    private var contextFetchTimeoutMs: UInt64 {
        chatBudgets.projectionTimeoutMs
    }

    private var contextInjectionPolicy: ContextInjectionPolicy {
        .perTurn(throttleMs: chatBudgets.contextCacheTTLms)
    }

    private enum ContextInjectionPolicy {
        case perTurn(throttleMs: UInt64)

        var throttleMs: UInt64 {
            switch self {
            case .perTurn(let throttleMs):
                return throttleMs
            }
        }

        var rawValue: String {
            switch self {
            case .perTurn:
                return "per_turn"
            }
        }
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
        if let currentThread {
            let recentUserMessages = currentThread.sortedMessages
                .filter { $0.role == .user }
                .suffix(2)
                .map { $0.content.lowercased() }
            fragments.append(contentsOf: recentUserMessages)
        }
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

    // MARK: - Chat Input Bar

    var chatInput: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if let slashDraft {
                commandDraftRow(slashDraft)
            }

            if let commandFeedback, commandFeedback.isEmpty == false {
                Text(commandFeedback)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.statusDanger))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            if slashDraft == nil,
               currentThread != nil,
               prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                composerSuggestionStrip
            }

            HStack(alignment: .bottom, spacing: 0) {
                slashButton

                TextField("ask Eva anything...", text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker(.textPrimary))
                #if os(iOS) || os(visionOS)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
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

                if isGenerationInFlight {
                    stopButton
                } else {
                    generateButton
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .fill(Color.tasker(.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.xl)
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker(.surfaceSecondary))
        )
        #endif
    }

    private var composerSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                ForEach(commandSuggestions, id: \.id) { descriptor in
                    Button {
                        selectSlashCommand(descriptor)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: descriptor.id.icon)
                                .font(.tasker(.caption2))
                            Text(descriptor.command)
                                .font(.tasker(.caption1))
                        }
                        .foregroundColor(Color.tasker(.accentPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insert \(descriptor.command)")
                    .accessibilityIdentifier("chat.command_composer_suggestion.\(descriptor.id.rawValue)")
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.sm)
        }
        .transition(.opacity)
    }

    private var slashButton: some View {
        Button {
            appManager.playHaptic()
            openSlashPicker(trigger: "button")
        } label: {
            Text("/")
                .font(.tasker(.callout))
                .fontWeight(.semibold)
                .foregroundColor(Color.tasker(.accentPrimary))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.tasker(.accentWash))
                )
                .overlay(
                    Circle()
                        .stroke(Color.tasker(.accentMuted), lineWidth: 1)
                )
        }
        .padding(.leading, TaskerTheme.Spacing.sm)
        .padding(.bottom, TaskerTheme.Spacing.xs)
        .accessibilityLabel("Commands")
        .accessibilityHint("Open slash commands")
        .accessibilityIdentifier("chat.slash_button")
        .scaleOnPress()
    }

    @ViewBuilder
    private func commandDraftRow(_ invocation: SlashCommandInvocation) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Label(invocation.id.canonicalCommand, systemImage: invocation.id.icon)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker(.accentPrimary))
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
                    .background(Color.tasker(.accentWash))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("chat.command_chip.\(invocation.id.rawValue)")

                Button {
                    projectLookupTask?.cancel()
                    slashDraft = nil
                    commandFeedback = nil
                    isProjectFieldFocused = false
                    appManager.playHaptic()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if invocation.id == .project {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    Image(systemName: "folder")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker(.textTertiary))

                    TextField("Pick project", text: projectQueryBinding)
                        .font(.tasker(.caption1))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isProjectFieldFocused)
                        .accessibilityIdentifier("chat.command_project_field")

                    if let projectName = invocation.projectName, projectName.isEmpty == false {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.tasker(.statusSuccess))
                            Text(projectName)
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker(.statusSuccess))
                        }
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.sm)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .background(Color.tasker(.surfaceTertiary))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                        .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                )
                .padding(.horizontal, TaskerTheme.Spacing.sm)
            }
        }
        .transition(.opacity)
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
                .foregroundColor(canSubmit ? Color.tasker(.accentOnPrimary) : Color.tasker(.textQuaternary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(canSubmit ? Color.tasker(.accentPrimary) : Color.tasker(.surfaceTertiary))
                )
        }
        .disabled(!canSubmit)
        .accessibilityIdentifier("chat.send_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.xs)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .animation(TaskerAnimation.quick, value: canSubmit)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Stop Button

    var stopButton: some View {
        Button {
            cancelActiveGeneration(reason: "stop_button")
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
        .accessibilityIdentifier("chat.stop_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.xs)
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
        if let currentThread = currentThread,
           let firstMessage = currentThread.sortedMessages.first {
            return firstMessage.content
        }

        return "chat"
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            Spacer()

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
                Text("Type / for commands")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textTertiary))
                    .multilineTextAlignment(.center)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        Button {
                            selectSlashCommand(descriptor)
                        } label: {
                            HStack(spacing: TaskerTheme.Spacing.xs) {
                                Image(systemName: descriptor.id.icon)
                                    .font(.tasker(.caption1))
                                Text(descriptor.command)
                                    .font(.tasker(.callout))
                            }
                            .foregroundColor(Color.tasker(.accentPrimary))
                            .padding(.horizontal, TaskerTheme.Spacing.md)
                            .padding(.vertical, TaskerTheme.Spacing.sm)
                            .background(Color.tasker(.accentWash))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                        }
                        .scaleOnPress()
                        .accessibilityLabel("Run command \(descriptor.command)")
                        .accessibilityIdentifier("chat.command_suggestion.\(descriptor.id.rawValue)")
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
                        isPreparingResponse: llm.isThinking,
                        onOpenTaskFromCard: { task in
                            onOpenTaskDetail?(task)
                        }
                    )
                } else {
                    emptyState
                }

                HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.md) {
                    modelPickerButton
                    chatInput
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
                .sheet(isPresented: $showSlashPicker) {
                    SlashCommandPickerView(
                        query: $slashPickerQuery,
                        recentCommands: recentPickerCommands,
                        popularCommands: popularPickerCommands,
                        allCommands: allPickerCommands,
                        onSelect: { descriptor in
                            selectSlashCommand(descriptor)
                        }
                    )
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium, .large] : [.large])
                }
                .alert("Clear this chat?", isPresented: $showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        clearCurrentThread()
                    }
                } message: {
                    Text("This deletes all messages in the current thread.")
                }
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

        var dynamicSystemPrompt = "You are Eva, the user's personal task assistant. Use the provided tasks and project details to answer questions and help manage their work." + "\n\n" + appManager.systemPrompt
        dynamicSystemPrompt += "\n\n" + contextPromptContract()

        let tID = threadID
        let contextStartedAt = Date()
        let contextPayload = await buildContextPayloadForCurrentTurn(
            threadID: tID,
            timeoutMs: contextFetchTimeoutMs
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
        dynamicSystemPrompt += "\n\n" + contextPayload.payload

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
                        content: "Model failed to prepare. Please switch models or retry.",
                        thread: thread
                    )
                )
                llm.isThinking = false
            }
            return
        }

        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_before_generate")
            }
            return
        }

        os_log("SystemPrompt length %d", dynamicSystemPrompt.count)
        logDebug("SYSTEM PROMPT ->\n\(dynamicSystemPrompt)")
        logDebug("USER MESSAGE ->\n\(message)")
        let output = await llm.generate(modelName: modelName, thread: thread, systemPrompt: dynamicSystemPrompt)
        guard !Task.isCancelled else {
            await MainActor.run {
                llm.cancelGeneration(reason: "run_cancelled_after_generate")
            }
            return
        }
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOutput.isEmpty == false else {
            await MainActor.run {
                llm.isThinking = false
            }
            return
        }
        logDebug("LLM RESPONSE ->\n\(output)")

        await MainActor.run {
            guard generationRunID == runID else { return }
            guard llm.cancelled == false else { return }
            sendMessage(Message(role: .assistant, content: output, thread: thread, generatingTime: llm.thinkingTime))
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
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
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
        let result = await LLMChatContextEnvelopeBuilder.build(
            timeoutMs: timeoutMs,
            service: LLMContextRepositoryProvider.makeService(
                maxTasksPerSlice: chatBudgets.maxProjectionTasksPerSlice,
                compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
            ),
            injectionPolicy: contextInjectionPolicy.rawValue,
            budgets: chatBudgets,
            contextStrategy: V2FeatureFlags.llmChatContextStrategy
        )
        return (result.payload, result.usedTimeoutFallback)
    }

    /// Executes buildContextPayloadForCurrentTurn.
    private func buildContextPayloadForCurrentTurn(
        threadID: UUID,
        timeoutMs: UInt64
    ) async -> (payload: String, usedTimeoutFallback: Bool, fromCache: Bool) {
        let now = Date()
        if let cached = await ChatView.contextInjectionTracker.cachedContext(
            for: threadID,
            now: now,
            throttleMs: contextInjectionPolicy.throttleMs
        ) {
            return (cached.payload, cached.usedTimeoutFallback, true)
        }

        let built = await buildLLMContextPayloadAsync(timeoutMs: timeoutMs)
        await ChatView.contextInjectionTracker.store(
            threadID: threadID,
            payload: built.payload,
            usedTimeoutFallback: built.usedTimeoutFallback,
            generatedAt: now
        )
        return (built.payload, built.usedTimeoutFallback, false)
    }

    private func invalidateContextCacheForCurrentThread() {
        guard let threadID = currentThread?.id else { return }
        Task {
            await ChatView.contextInjectionTracker.clear(threadID: threadID)
        }
    }

    /// Executes contextPromptContract.
    private func contextPromptContract() -> String {
        """
        Context contract:
        - Use the Context JSON envelope injected for this turn as the source of truth.
        - Check `metadata.context_partial` and `partial_flags`.
        - If context is partial, say data may be incomplete and avoid definitive zero/none claims for overdue or due counts.
        """
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
