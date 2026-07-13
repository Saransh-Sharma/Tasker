import SwiftUI

struct ChatScaffoldView: View {


    @EnvironmentObject var appManager: AppManager

    @Environment(LLMEvaluator.self) var llm

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @State var showEvaGuide = false

    @StateObject var assistantIdentity = AssistantIdentityModel()

    @Binding var currentThread: Thread?

    let transcriptSnapshot: ChatTranscriptSnapshot

    let liveOutput: ChatLiveOutputState

    let presentationMode: ChatPresentationMode

    let prompt: Binding<String>

    let isPromptFocused: FocusState<Bool>.Binding

    let isProjectFieldFocused: FocusState<Bool>.Binding

    let showChats: Binding<Bool>

    let showSettings: Binding<Bool>

    let showSlashPicker: Binding<Bool>

    let showClearConfirmation: Binding<Bool>

    let slashDraft: Binding<SlashCommandInvocation?>

    let slashPickerQuery: Binding<String>

    let commandFeedback: String?

    let storageDegradedReason: String?

    let projectQuery: Binding<String>

    let commandSuggestions: [SlashCommandDescriptor]

    let recentCommands: [SlashCommandDescriptor]

    let popularCommands: [SlashCommandDescriptor]

    let allCommands: [SlashCommandDescriptor]

    let isGenerationInFlight: Bool

    let canSubmit: Bool

    let llmCancelled: Bool

    let chatTitle: String

    let showsHistoryAction: Bool

    let onOpenTaskDetail: ((TaskDefinition) -> Void)?

    let onOpenHabitDetail: ((UUID) -> Void)?

    let onPerformDayTaskAction: EvaDayTaskActionHandler?

    let onPerformDayHabitAction: EvaDayHabitActionHandler?

    let starterPrompts: [EvaStarterPrompt]

    let activeAttachments: [ThreadContextAttachmentRecord]

    let onOpenSlashPicker: () -> Void

    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void

    let onSelectSuggestion: (SlashCommandDescriptor) -> Void

    let onStartNewChat: () -> Void

    let onCancelDraft: () -> Void

    let onRemoveAttachment: (ThreadContextAttachmentRecord) -> Void

    let onGenerate: () -> Void

    let onStop: () -> Void

    let onSubmitPrompt: () -> Void

    let onClearCurrentThread: () -> Void

    let onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)?

    var body: some View {
        ZStack {
            EvaChatSunriseBackground(isStreaming: isGenerationInFlight || liveOutput.shouldRender)

            VStack(spacing: 0) {
                if transcriptSnapshot.threadID != nil {
                    ConversationView(
                        snapshot: transcriptSnapshot,
                        liveOutput: liveOutput,
                        onOpenTaskFromCard: { task in
                            onOpenTaskDetail?(task)
                        },
                        onOpenHabitFromCard: onOpenHabitDetail,
                        onPerformDayTaskAction: onPerformDayTaskAction,
                        onPerformDayHabitAction: onPerformDayHabitAction
                    )
                } else {
                    ChatEmptyStateView(
                        identity: assistantIdentity.snapshot,
                        presentationMode: presentationMode,
                        starterPrompts: starterPrompts,
                        commandSuggestions: commandSuggestions,
                        onSelectStarterPrompt: onSelectStarterPrompt,
                        onSelectSuggestion: onSelectSuggestion,
                        onOpenEvaGuide: {
                            appManager.playHaptic()
                            showEvaGuide = true
                        }
                    )
                }

                VStack(spacing: LifeBoardTheme.Spacing.xs) {
                    if let storageDegradedReason {
                        ChatStorageDegradedBanner(reason: storageDegradedReason)
                    }
                    HStack(alignment: .bottom, spacing: LifeBoardTheme.Spacing.md) {
                        ChatComposerView(
                            identity: assistantIdentity.snapshot,
                            presentationMode: presentationMode,
                            slashDraft: slashDraft.wrappedValue,
                            activeAttachments: activeAttachments,
                            commandFeedback: commandFeedback,
                            hasCurrentThread: currentThread != nil,
                            prompt: prompt,
                            isPromptFocused: isPromptFocused,
                            isProjectFieldFocused: isProjectFieldFocused,
                            projectQuery: projectQuery,
                            commandSuggestions: commandSuggestions,
                            starterPrompts: starterPrompts,
                            isGenerationInFlight: isGenerationInFlight,
                            canSubmit: canSubmit,
                            llmCancelled: llmCancelled,
                            hasActivationAssistantReply: hasActivationAssistantReply,
                            onOpenSlashPicker: onOpenSlashPicker,
                            onSelectStarterPrompt: onSelectStarterPrompt,
                            onSelectSuggestion: onSelectSuggestion,
                            onCancelDraft: onCancelDraft,
                            onRemoveAttachment: onRemoveAttachment,
                            onGenerate: onGenerate,
                            onStop: onStop,
                            onSubmitPrompt: onSubmitPrompt
                        )
                    }
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                .padding(.bottom, LifeBoardTheme.Spacing.md)
                .padding(.top, isActivationPresentation ? LifeBoardTheme.Spacing.xs : LifeBoardTheme.Spacing.sm)
                .background(.clear)
            }
        }
            .background(EvaChatSunriseGlass.canvasMid)
                .onAppear {
                    publishNavigationChromeState()
                }
                .onChange(of: currentThread?.id) {
                    publishNavigationChromeState()
                }
                .onChange(of: chatTitle) {
                    publishNavigationChromeState()
                }
                .onChange(of: showsHistoryAction) {
                    publishNavigationChromeState()
                }
                .onChange(of: presentationMode) {
                    publishNavigationChromeState()
                }
                .onChange(of: assistantIdentity.snapshot) {
                    publishNavigationChromeState()
                }
                .sheet(isPresented: showSettings) {
                    NavigationStack {
                        LLMSettingsView(currentThread: $currentThread, showsCloseButton: true)
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showSettings.wrappedValue.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationBackground(EvaChatSunriseGlass.canvasMid)
                    .presentationCornerRadius(LifeBoardTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(layoutClass == .phone ? [.large] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showSettings.wrappedValue.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .sheet(isPresented: showSlashPicker) {
                    SlashCommandPickerView(
                        query: slashPickerQuery,
                        recentCommands: recentCommands,
                        popularCommands: popularCommands,
                        allCommands: allCommands,
                        onSelect: onSelectSuggestion
                    )
                    .presentationBackground(EvaChatSunriseGlass.canvasMid)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(layoutClass == .phone ? [.medium, .large] : [.large])
                }
                .sheet(isPresented: $showEvaGuide) {
                    EvaChiefOfStaffGuideView { prompt in
                        onSelectStarterPrompt(prompt)
                    }
                    #if os(iOS)
                    .presentationBackground(EvaChatSunriseGlass.canvasMid)
                    .presentationCornerRadius(LifeBoardTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
                    #endif
                }
                .alert("Clear this chat?", isPresented: showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        onClearCurrentThread()
                    }
                } message: {
                    Text("This deletes all messages in the current thread.")
                }
                .toolbar {
                    #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.wrappedValue.toggle()
                        }) {
                            Label("settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
    }
}
