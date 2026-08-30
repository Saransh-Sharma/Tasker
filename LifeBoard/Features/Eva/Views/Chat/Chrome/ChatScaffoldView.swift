import SwiftUI
import LifeBoardDomain

private struct EvaComposerBottomClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var evaComposerBottomClearance: CGFloat {
        get { self[EvaComposerBottomClearanceKey.self] }
        set { self[EvaComposerBottomClearanceKey.self] = newValue }
    }
}

struct ChatScaffoldView: View {


    @EnvironmentObject var appManager: AppManager

    @Environment(LLMEvaluator.self) var llm

    @ObservedObject var cloudAccess: EvaCloudAccessCoordinator

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.evaComposerBottomClearance) var composerBottomClearance


    @State var showEvaGuide = false

    @State private var showsCloudContextReview = false

    @StateObject var assistantIdentity = AssistantIdentityModel()

    let showsCloudAccessCard: Bool

    let hasPendingCloudSend: Bool

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

    let onOpenRecordFromCard: ((EvaRecordReference) -> Void)?

    let onOpenNavigationTargetFromCard: ((EvaNavigationTarget) -> Void)?

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

    let onActivateCloud: () -> Void

    let onRetryCloud: () -> Void

    let onReconnectApple: () -> Void

    let onUseOffline: () -> Void

    let onGenerate: () -> Void

    let onStop: () -> Void

    let onSubmitPrompt: () -> Void

    let onClearCurrentThread: () -> Void

    let onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)?

    var body: some View {
        ZStack {
            EvaChatSunriseBackground(isStreaming: isGenerationInFlight || liveOutput.shouldRender)

            if transcriptSnapshot.threadID != nil {
                ConversationView(
                    snapshot: transcriptSnapshot,
                    liveOutput: liveOutput,
                    onOpenTaskFromCard: { task in
                        onOpenTaskDetail?(task)
                    },
                    onOpenHabitFromCard: onOpenHabitDetail,
                    onOpenRecordFromCard: onOpenRecordFromCard,
                    onOpenNavigationTargetFromCard: onOpenNavigationTargetFromCard,
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

            // The shell hides the compact dock while this composer is focused,
            // and Eva is a stack root, so with the keyboard up the canvas is the
            // largest thing left that can take a dismissing tap. It has to sit
            // *above* the content: the transcript and the empty state are both
            // scroll views, and a scroll view consumes touches across its whole
            // area, so a layer underneath them never saw the tap. Gated on
            // focus, so it costs nothing when the keyboard is down — and while
            // the keyboard is up, spending the first tap on dismissing it is
            // what Messages and Mail do too.
            if isPromptFocused.wrappedValue {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isPromptFocused.wrappedValue = false }
                    .accessibilityHidden(true)
            }
        }
        // Empty-state content can be taller than the device at accessibility
        // sizes. Keep that intrinsic height from enlarging the scaffold itself;
        // the composer inset must be anchored to the offered viewport.
        // The composer inset below is lifted by the dock's measured clearance,
        // which takes it *out of* the band the inset reserved — so content laid
        // out above the inset (the empty state's example rail) ended up
        // underneath the composer instead of above it. Shortening the content
        // by the same amount the composer is lifted gives that space back
        // without moving the composer, whose resting position is pinned by
        // `assertRequiredEvaDockSpacing`. It has to precede the frame below:
        // after it, the padding inflates the scaffold past the height it was
        // offered and the composer inset drifts down with it.
        .padding(.bottom, composerBottomClearance > 0 ? composerBottomClearance + Theme.Spacing.md : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: Theme.Spacing.xs) {
                    if showsCloudAccessCard {
                        EvaCloudAccessCard(
                            state: cloudAccess.state,
                            errorMessage: cloudAccess.errorMessage,
                            hasPendingSend: hasPendingCloudSend,
                            selectedGrantCount: cloudAccess.selectedGrants.count,
                            onActivate: onActivateCloud,
                            onRetry: onRetryCloud,
                            onReconnectApple: onReconnectApple,
                            onReviewContext: { showsCloudContextReview = true },
                            onUseOffline: onUseOffline
                        )
                    }
                    if let storageDegradedReason {
                        ChatStorageDegradedBanner(reason: storageDegradedReason)
                    }
                    HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
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
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, isActivationPresentation ? Theme.Spacing.xs : Theme.Spacing.sm)

                // The single separation between composer and dock. Sized to the
                // md token because `assertRequiredEvaDockSpacing` requires every
                // interactive part of the composer to clear the dock by it.
                Color.clear
                    .frame(height: Theme.Spacing.md)
                    // Padding is compressible. An explicit ideal-size spacer
                    // keeps local composer spacing intact at Dynamic Type sizes
                    // where its controls consume the remaining proposal.
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(.clear)
            // Foundation's dock is an overlay outside Eva's nested navigation
            // stack. Its measured clearance reserves transcript space at the
            // destination boundary; this offset places the inset composer in
            // that same visible region without relying on keyboard estimates.
            // The matching `.padding(.bottom:)` above keeps content out from
            // under it.
            // Exactly the dock's clearance. The separation between composer and
            // dock is the spacer below the composer and nothing else: adding a
            // gap here as well counted it twice, and the reader saw the sum.
            .offset(y: composerBottomClearance > 0 ? -composerBottomClearance : 0)
        }
        // Deliberately opaque, and deliberately not the shell's daypart scene.
        // Letting the atmosphere through here looks better in the abstract, but
        // the shared root header sits *above* this view and is drawn straight
        // onto the artwork, so any transparency leaves a hard seam across the
        // screen at the header's edge — and at the night daypart it puts cocoa
        // ink on a dark scene. The celestial that used to show through the chat
        // body is handled at its source instead, in `AtmospherePlacement.eva`.
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
            .presentationCornerRadius(Theme.CornerRadius.xl)
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
            .presentationCornerRadius(Theme.CornerRadius.xl)
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
            #endif
        }
        .sheet(isPresented: $showsCloudContextReview) {
            EvaCloudContextReviewSheet(
                grants: $cloudAccess.selectedGrants,
                isWorking: cloudAccess.isWorking,
                onConfirm: {
                    showsCloudContextReview = false
                    onActivateCloud()
                }
            )
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

private struct EvaCloudAccessCard: View {
    let state: EvaCloudAccessState
    let errorMessage: String?
    let hasPendingSend: Bool
    let selectedGrantCount: Int
    let onActivate: () -> Void
    let onRetry: () -> Void
    let onReconnectApple: () -> Void
    let onReviewContext: () -> Void
    let onUseOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(detail)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if state == .hydrating || state == .activating {
                    ProgressView()
                        .tint(Color.lifeboard(.accentPrimary))
                        .accessibilityLabel(title)
                }
            }

            if showsActions {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.sm) { actions }
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) { actions }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.cloudAccess.card")
    }

    @ViewBuilder
    private var actions: some View {
        switch state {
        case .needsDisclosure:
            Button(hasPendingSend ? "Activate & send" : "Activate Cloud EVA", action: onActivate)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.activate")
            Button("Review context", action: onReviewContext)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("chat.cloudAccess.review")
            Button("Use Offline EVA", action: onUseOffline)
                .buttonStyle(.plain)
        case .temporarilyUnavailable:
            Button("Retry", action: onRetry)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.retry")
            Button("Use Offline EVA", action: onUseOffline)
                .buttonStyle(.bordered)
        case .appleReauthenticationRequired:
            Button("Reconnect with Apple", action: onReconnectApple)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.reconnectApple")
            Button("Use Offline EVA", action: onUseOffline)
                .buttonStyle(.bordered)
        case .quotaExhausted, .ageBlocked:
            Button("Use Offline EVA", action: onUseOffline)
                .buttonStyle(.bordered)
        case .hydrating, .ready, .activating:
            EmptyView()
        }
    }

    private var showsActions: Bool {
        switch state {
        case .needsDisclosure, .temporarilyUnavailable, .quotaExhausted,
             .ageBlocked, .appleReauthenticationRequired:
            true
        case .hydrating, .ready, .activating:
            false
        }
    }

    private var title: String {
        switch state {
        case .hydrating: "Checking Cloud EVA…"
        case .ready: "Cloud EVA is ready"
        case .needsDisclosure: "Activate Cloud EVA"
        case .activating: "Activating Cloud EVA…"
        case .temporarilyUnavailable: "Cloud EVA needs attention"
        case .quotaExhausted: "Cloud EVA limit reached"
        case .ageBlocked: "Cloud EVA isn't available"
        case .appleReauthenticationRequired: "Reconnect protected EVA"
        }
    }

    private var detail: String {
        switch state {
        case .hydrating:
            "Restoring the protected session on this device."
        case .ready:
            "Luna is ready."
        case .needsDisclosure:
            "Prompts and the context you confirm pass through LifeBoard's Cloudflare service to OpenAI. \(selectedGrantCount) sensitive context categories are selected."
        case .activating:
            "Your draft is safe. It will send once the guest session is ready."
        case .temporarilyUnavailable(let message):
            errorMessage ?? message
        case .quotaExhausted(let nextAvailableAt):
            nextAvailableAt.map { "Your rolling allowance begins returning \($0.formatted(date: .omitted, time: .shortened))." }
                ?? "Your rolling answer allowance is currently used."
        case .ageBlocked(let message):
            message
        case .appleReauthenticationRequired:
            "Apple confirmation restores this linked account. LifeBoard won't replace it with a new guest."
        }
    }

    private var symbolName: String {
        switch state {
        case .hydrating, .activating: "cloud"
        case .ready: "checkmark.circle.fill"
        case .needsDisclosure: "cloud.sun.fill"
        case .temporarilyUnavailable: "exclamationmark.triangle.fill"
        case .quotaExhausted: "clock.arrow.circlepath"
        case .ageBlocked: "hand.raised.fill"
        case .appleReauthenticationRequired: "apple.logo"
        }
    }
}

private struct EvaCloudContextReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var grants: Set<EvaConsentPolicy.Grant>
    let isWorking: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Prompts and the context you confirm pass through LifeBoard's Cloudflare service to OpenAI. No LifeBoard content leaves this device until you activate Cloud EVA.")
                } header: {
                    Text("Cloud processing")
                }
                Section("Sensitive context") {
                    ForEach(EvaConsentPolicy.Grant.allCases, id: \.self) { grant in
                        Toggle(grant.onboardingTitle, isOn: binding(for: grant))
                            .accessibilityIdentifier("chat.cloudAccess.grant.\(grant.rawValue)")
                    }
                }
                Section {
                    Text("You can change these choices later in EVA settings. Server consent is checked before every request.")
                }
            }
            .navigationTitle("Review Cloud EVA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Activate", action: onConfirm)
                        .disabled(isWorking)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("chat.cloudAccess.reviewSheet")
    }

    private func binding(for grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { grants.contains(grant) },
            set: { enabled in
                if enabled { grants.insert(grant) }
                else { grants.remove(grant) }
            }
        )
    }
}
