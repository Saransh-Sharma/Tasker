import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

private struct EvaAuthorizedEvidenceContextEnvironmentKey: EnvironmentKey {
    static let defaultValue = EvaAuthorizedEvidenceContext.notProvided
}

enum EvaChatCloudReadinessPolicy {
    static func requiresCloud(
        preference: EvaProviderRouter.Preference,
        route: EvaTurnRoute?
    ) -> Bool {
        guard preference != .offline else { return false }
        switch route {
        case .capture, .navigation:
            return false
        case .chatAnswer, .readOnlyReview, .taskMutation, .habitMutation,
             .dayPlanning, .weeklyPlanning, .clarification, .none:
            return true
        }
    }
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

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.evaAuthorizedEvidenceContext) var authorizedLifeEvidence
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
    var onOpenRecordFromCard: ((EvaRecordReference) -> Void)? = nil
    var onOpenNavigationTargetFromCard: ((EvaNavigationTarget) -> Void)? = nil
    var onPerformDayTaskAction: EvaDayTaskActionHandler? = nil
    var onPerformDayHabitAction: EvaDayHabitActionHandler? = nil
    var showsHistoryAction: Bool = true
    var promptFocusRequestID: UInt64 = 0
    var storageDegradedReason: String? = nil
    var onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)? = nil
    var onComposerFocusChange: ((Bool) -> Void)? = nil

    @State var thinkingTime: TimeInterval?

    @State var generatingThreadID: UUID?
    @State var showSlashPicker = false
    @State var slashPickerQuery = ""
    @State var slashDraft: SlashCommandInvocation?
    @State var recentSlashCommands: [SlashCommandID] = []
    @State var commandFeedback: String?
    @State var showClearConfirmation = false
    @State var projectLookupTask: _Concurrency.Task<Void, Never>?
    @State var generationTask: _Concurrency.Task<Void, Never>?
    @State var activationFocusTask: _Concurrency.Task<Void, Never>?
    @State var contextInvalidationTask: _Concurrency.Task<Void, Never>?
    @State var slashCommandTask: _Concurrency.Task<Void, Never>?
    @State var generationRunID: UUID?
    @State var transcriptSnapshot: ChatTranscriptSnapshot = .empty
    @State var pendingResponsePhase: ChatPendingResponsePhase = .idle
    @State var chatOpenTraceInterval: PerformanceInterval?
    @State var promptSubmitTraceInterval: PerformanceInterval?
    /// Openers handed over by onboarding. Drained on the first send.
    @State var stagedOpeningPrompts: [EvaStarterPrompt] = []
    @State var evaSubmittedDraft: EvaSubmittedDraft?
    @State var hasCompletedInitialTranscriptRender = false
    @State var consumedPromptFocusRequestID: UInt64 = 0
    @StateObject var contextCoordinator = ChatContextCoordinator()
    @StateObject var cloudAccess = EvaCloudAccessCoordinator.shared
    @State var providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
    @State var pendingCloudSend: PendingCloudSend?
    @State var cloudInteractionIsActive = false
    @State var cloudReadinessTask: _Concurrency.Task<Void, Never>?
    /// E3: the user message whose "Edit and resend" is awaiting confirmation.
    @State var pendingEditResendMessageID: UUID?
    /// E4: the ritual a turn asked for, shown over the chat until it closes.
    @State var presentedRitual: EvaRitualRequest?
    /// A turn that failed. Shown as a transient row above the composer with
    /// Retry; never written into the thread, so it never feeds later context.
    @State var generationFailure: ChatGenerationFailure?
    @Environment(\.evaRitualPresenter) var evaRitualPresenter
    @FocusState var isProjectFieldFocused: Bool

    struct EvaSubmittedDraft: Equatable {
        let runID: UUID
        let text: String
    }

    struct PendingCloudSend: Equatable {
        let id: UUID
        let text: String
    }

    var body: some View {
        ChatScaffoldView(
            cloudAccess: cloudAccess,
            showsCloudAccessCard: showsCloudAccessCard,
            hasPendingCloudSend: pendingCloudSend != nil,
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
            onOpenRecordFromCard: onOpenRecordFromCard,
            onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
            onPerformDayTaskAction: onPerformDayTaskAction,
            onPerformDayHabitAction: onPerformDayHabitAction,
            onEditResend: { pendingEditResendMessageID = $0 },
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
            onActivateCloud: {
                confirmCloudAccessAndResume()
            },
            onRetryCloud: {
                retryCloudAccessAndResume()
            },
            onReconnectApple: {
                reconnectAppleAndResume()
            },
            onUseOffline: {
                useOfflineEvaForPendingSend()
            },
            onGenerate: {
                clearStagedOpeningPromptsIfNeeded()
                submitPromptFromSendButton()
            },
            onStop: {
                cancelActiveGeneration(reason: .stopButton)
            },
            onSubmitPrompt: {
                clearStagedOpeningPromptsIfNeeded()
                submitPromptFromComposer()
            },
            onClearCurrentThread: {
                clearCurrentThread()
            },
            generationFailure: generationFailure.flatMap { $0.threadID == currentThread?.id ? $0 : nil },
            canUseOfflineForFailure: canUseOfflineForFailedGeneration,
            onRetryFailedGeneration: {
                retryFailedGeneration(preferOffline: false)
            },
            onUseOfflineForFailedGeneration: {
                retryFailedGeneration(preferOffline: true)
            },
            onDiscardFailedGeneration: {
                generationFailure = nil
            },
            onNavigationChromeChange: onNavigationChromeChange
        )
        .onAppear {
            handleChatViewAppear()
            providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
            handlePromptFocusRequestIfNeeded()
            if activationConfiguration == nil, stagedOpeningPrompts.isEmpty {
                stagedOpeningPrompts = EvaOpeningPromptStore.load()
            }
        }
        .onChange(of: prompt) { _, newValue in
            handlePromptChanged(newValue)
        }
        .confirmationDialog(
            "Edit and resend?",
            isPresented: Binding(
                get: { pendingEditResendMessageID != nil },
                set: { if $0 == false { pendingEditResendMessageID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Edit and resend", role: .destructive) {
                if let id = pendingEditResendMessageID {
                    applyEditResend(messageID: id)
                }
                pendingEditResendMessageID = nil
            }
            Button("Not now", role: .cancel) { pendingEditResendMessageID = nil }
        } message: {
            Text("Later messages in this chat will be removed.")
        }
        .lifeboardCover(item: $presentedRitual) { request in
            if let presenter = evaRitualPresenter,
               let view = presenter.makeView(request, { presentedRitual = nil }) {
                view
            } else {
                StatusSurface(
                    state: .noRecord,
                    title: String(localized: "\(request.kind.title) isn’t available yet"),
                    message: String(localized: "Coming in a later update.")
                )
                .padding(20)
                .overlay(alignment: .topTrailing) {
                    Button("Close") { presentedRitual = nil }.padding(16)
                }
            }
        }
        .onChange(of: slashDraft?.id) { _, newValue in
            guard newValue?.requiresArgument == true else {
                isProjectFieldFocused = false
                return
            }
            isProjectFieldFocused = true
        }
        .onChange(of: currentThread?.id) { oldThreadID, newThreadID in
            pendingCloudSend = nil
            cloudReadinessTask?.cancel()
            handleCurrentThreadChanged(from: oldThreadID, to: newThreadID)
        }
        .onChange(of: prompt) { _, text in
            if pendingCloudSend != nil { EvaPendingActivationDraftStore.save(text, threadID: currentThread?.id) }
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
            cloudInteractionIsActive = false
            pendingCloudSend = nil
            cloudReadinessTask?.cancel()
            cloudReadinessTask = nil
            handleChatViewDisappear()
        }
        .task {
            cloudInteractionIsActive = true
            if prompt.isEmpty, let saved = EvaPendingActivationDraftStore.load(threadID: currentThread?.id) { prompt = saved }
            _ = await cloudAccess.ensureActivated(source: .evaEntry)
        }
        .onChange(of: cloudAccess.state) { _, state in
            if state == .ready, let pending = pendingCloudSend { resumePendingCloudSend(pending) }
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
                    Label("Settings", systemImage: "gear")
                }
            }
            #endif
        }
    }

}

extension ChatView {
    var chatBudgets: LLMChatBudgets {
        LLMChatBudgets.active
    }

    var resolvedChatBudget: LLMResolvedChatBudget {
        chatBudgets.resolved(for: activeModelConfiguration)
    }

    var activeModelConfiguration: MLXLMCommon.ModelConfiguration {
        guard let modelName = appManager.currentModelName,
              let model = MLXLMCommon.ModelConfiguration.getModelByName(modelName) else {
            return MLXLMCommon.ModelConfiguration.defaultModel
        }
        return model
    }

    var contextFetchTimeoutMs: UInt64 {
        chatBudgets.projectionTimeoutMs
    }

    var evaPlanContextFetchTimeoutMs: UInt64 {
        max(contextFetchTimeoutMs, 2_500)
    }

    var contextInjectionPolicy: ChatContextInjectionPolicy {
        .perTurn(throttleMs: chatBudgets.contextCacheTTLms)
    }

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isComposerFocused: Bool {
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

    var projectQueryBinding: Binding<String> {
        Binding(
            get: { slashDraft?.projectQuery ?? "" },
            set: { updateProjectDraftQuery($0) }
        )
    }

    var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    var isActivationPresentation: Bool {
        activationConfiguration != nil
    }

    var showsCloudAccessCard: Bool {
        providerPreference != .offline && cloudAccess.state != .ready
    }

    /// Starter prompts for the empty state.
    ///
    /// In activation presentation these come from the stage's configuration. In
    /// normal presentation they used to be empty — which was fine while EVA had
    /// its own activation flow to greet a new user, and is not now that
    /// onboarding hands straight to `.normal`. `EvaOpeningPromptStore` carries
    /// the openers composed from the user's Life Map across that hand-off; they
    /// are cleared the moment the person says anything, since an opener is only
    /// an opener until the conversation exists.
    func clearStagedOpeningPromptsIfNeeded() {
        guard stagedOpeningPrompts.isEmpty == false else { return }
        stagedOpeningPrompts = []
        EvaOpeningPromptStore.clear()
    }

    var activationStarterPrompts: [EvaStarterPrompt] {
        if let configured = activationConfiguration?.starterPrompts { return configured }
        return stagedOpeningPrompts
    }

    var commandSuggestions: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.commandSuggestions(
            prompt: prompt,
            transcriptSnapshot: transcriptSnapshot,
            recents: recentSlashCommands
        )
    }

    var recentPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.recentPickerCommands(recents: recentSlashCommands)
    }

    var popularPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.popularPickerCommands(recents: recentSlashCommands)
    }

    var allPickerCommands: [SlashCommandDescriptor] {
        ChatSlashSuggestionCatalog.allPickerCommands(
            query: slashPickerQuery,
            recents: recentSlashCommands
        )
    }

    var chatTitle: String {
        transcriptSnapshot.title
    }

    var liveOutputState: ChatLiveOutputState {
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

    var contextInvalidationPublisher: AnyPublisher<Notification, Never> {
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
}

// MARK: - Composer, focus and lifecycle
