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

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @Environment(\.evaComposerBottomClearance) var composerBottomClearance


    @State var showEvaGuide = false

    @State private var showsCloudContextReview = false

    @State private var showsContextSettings = false

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

    let onEditResend: ((UUID) -> Void)?

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

    let generationFailure: ChatGenerationFailure?

    let canUseOfflineForFailure: Bool

    let onRetryFailedGeneration: () -> Void

    let onUseOfflineForFailedGeneration: () -> Void

    let onDiscardFailedGeneration: () -> Void

    let onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)?

    var body: some View {
        // A `maxHeight: .infinity` frame still grows with a child that wants
        // more than the proposal, and at accessibility sizes the empty state
        // and the composer together do. The scaffold then overflowed the
        // viewport and its bottom inset (the composer) drifted under the dock.
        // A GeometryReader is exactly the proposed size no matter what it
        // holds, so the inset stays anchored to the visible bottom edge.
        GeometryReader { viewport in
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
                    onPerformDayHabitAction: onPerformDayHabitAction,
                    onEditResend: onEditResend
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
                        Haptic.pick.play()
                        showEvaGuide = true
                    },
                    onReviewContext: {
                        showsContextSettings = true
                    }
                )
            }
        }
        // The shell hides the compact dock while this composer is focused, and
        // Eva is a stack root, so with the keyboard up the conversation is the
        // largest thing left that can take a dismissing tap. A layer over it
        // took that tap but also every scroll and every card tap, so nobody
        // could scroll back to reread a message while writing a reply, and the
        // transcript's own drag-to-dismiss never ran. A simultaneous tap
        // dismisses and still reaches the content; scrolling keeps working.
        .dismissesKeyboardOnTap(isPromptFocused)
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
        .frame(width: viewport.size.width, height: viewport.size.height)
        // A frame sizes but does not clip. At accessibility sizes the empty
        // state is taller than the viewport, overflowed symmetrically, and its
        // top half ("Hi there!") printed over the root header's subtitle and
        // controls. Clip to the viewport; the content scrolls within it.
        .clipped()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: Theme.Spacing.xs) {
                    // Bounded clay above the composer: `DESIGN.md`'s Eva
                    // composition gives receipts and Undo clay, never prose.
                    EvaChatReceiptSlot()
                    if showsCloudAccessCard {
                        let cloudCard = EvaCloudAccessCard(
                            state: cloudAccess.state,
                            errorMessage: cloudAccess.errorMessage,
                            hasPendingSend: hasPendingCloudSend,
                            selectedGrants: $cloudAccess.selectedGrants,
                            offlineModelReady: appManager.currentModelName.map { appManager.installedModels.contains($0) } ?? false,
                            onActivate: onActivateCloud,
                            onRetry: onRetryCloud,
                            onReconnectApple: onReconnectApple,
                            onReviewContext: { showsCloudContextReview = true },
                            onUseOffline: onUseOffline
                        )
                        // At accessibility sizes the card alone is half the
                        // screen; it and the composer share one inset, so the
                        // composer slid under the dock. The card scrolls
                        // inside a bounded height instead.
                        if dynamicTypeSize.isAccessibilitySize {
                            ScrollView { cloudCard }
                                .frame(maxHeight: 200)
                        } else {
                            cloudCard
                        }
                    }
                    if let storageDegradedReason {
                        ChatStorageDegradedBanner(reason: storageDegradedReason)
                    }
                    if let generationFailure, isGenerationInFlight == false {
                        ChatGenerationFailureRow(
                            failure: generationFailure,
                            canUseOffline: canUseOfflineForFailure,
                            onRetry: onRetryFailedGeneration,
                            onUseOffline: onUseOfflineForFailedGeneration,
                            onDiscard: onDiscardFailedGeneration
                        )
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
                // The transcript is capped at the readable width at iPad and Mac
                // widths; the composer ran edge to edge beneath it.
                .frame(maxWidth: layoutClass.isPad ? 760 : .infinity)
                .frame(maxWidth: .infinity)
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
            .presentationDetents([.large])
            #elseif os(macOS)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button(action: { showSettings.wrappedValue.toggle() }) {
                        Text("Close")
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
            // The consent step itself; a draft waiting on Cloud EVA resumes
            // when the coordinator reports `.ready`.
            EvaCloudConsentSheet(
                access: cloudAccess,
                source: .chatInlineAction,
                identifierPrefix: "chat.cloudAccess"
            )
        }
        .sheet(isPresented: $showsContextSettings) {
            NavigationStack {
                EvaCloudSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showsContextSettings = false }
                                .keyboardShortcut(.cancelAction)
                                .accessibilityIdentifier("chat.contextSettings.close")
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Clear this chat?", isPresented: showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                onClearCurrentThread()
            }
        } message: {
            Text("Deletes all messages in this chat.")
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appManager.playHaptic()
                    showSettings.wrappedValue.toggle()
                }) {
                    Label("Settings", systemImage: "gear")
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
    @Binding var selectedGrants: Set<EvaConsentPolicy.Grant>
    let offlineModelReady: Bool
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
                    if detail.isEmpty == false {
                        Text(detail)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
        case .needsActivation:
            // Nothing has failed yet: the only step is the person's consent.
            Button("Turn on cloud", action: onReviewContext)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.activate")
            Button(offlineModelReady ? String(localized: "Use offline") : String(localized: "Set up offline"), action: onUseOffline)
                .buttonStyle(.lifeBoardChip)
        case .temporarilyUnavailable:
            Button("Retry", action: onRetry)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.retry")
            Button(offlineModelReady ? String(localized: "Use offline") : String(localized: "Set up offline"), action: onUseOffline)
                .buttonStyle(.lifeBoardChip)
        case .appleReauthenticationRequired:
            Button("Reconnect with Apple", action: onReconnectApple)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("chat.cloudAccess.reconnectApple")
            Button(offlineModelReady ? String(localized: "Use offline") : String(localized: "Set up offline"), action: onUseOffline)
                .buttonStyle(.lifeBoardChip)
        case .quotaExhausted:
            Button(offlineModelReady ? String(localized: "Use offline") : String(localized: "Set up offline"), action: onUseOffline)
                .buttonStyle(.lifeBoardChip)
        case .hydrating, .ready, .activating:
            EmptyView()
        }
    }

    private var showsActions: Bool {
        switch state {
        case .needsActivation, .temporarilyUnavailable, .quotaExhausted,
             .appleReauthenticationRequired:
            true
        case .hydrating, .ready, .activating:
            false
        }
    }

    private var title: String {
        switch state {
        case .hydrating: String(localized: "Connecting…")
        case .ready: AssistantIdentitySnapshot.current.readyStatus
        case .needsActivation: String(localized: "Use \(AssistantIdentitySnapshot.current.displayName) in the cloud")
        case .activating: String(localized: "Connecting…")
        case .temporarilyUnavailable: String(localized: "Couldn’t reach \(AssistantIdentitySnapshot.current.displayName)")
        case .quotaExhausted: String(localized: "Limit reached")
        case .appleReauthenticationRequired: String(localized: "Sign in again")
        }
    }

    private var detail: String {
        switch state {
        case .hydrating:
            ""
        case .ready:
            ""
        case .needsActivation:
            String(localized: "\(AssistantIdentitySnapshot.current.displayName) uses OpenAI through LifeBoard’s cloud. Review access first.")
        case .activating:
            String(localized: "Your draft is saved.")
        case .temporarilyUnavailable(let message):
            errorMessage ?? message
        case .quotaExhausted(let nextAvailableAt):
            nextAvailableAt.map { String(localized: "More answers at \($0.formatted(date: .omitted, time: .shortened)).") }
                ?? String(localized: "More answers become available soon.")
        case .appleReauthenticationRequired:
            String(localized: "Sign in with Apple to reconnect.")
        }
    }

    private var symbolName: String {
        switch state {
        case .hydrating, .activating: "cloud"
        case .ready: "checkmark.circle.fill"
        case .needsActivation: "cloud.sun.fill"
        case .temporarilyUnavailable: "exclamationmark.triangle.fill"
        case .quotaExhausted: "clock.arrow.circlepath"
        case .appleReauthenticationRequired: "apple.logo"
        }
    }
}


/// A turn that failed, shown above the composer instead of being written into
/// the thread. Retry sends the same message again; Discard just closes it.
struct ChatGenerationFailureRow: View {
    let failure: ChatGenerationFailure
    let canUseOffline: Bool
    let onRetry: () -> Void
    let onUseOffline: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.bubble")
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Couldn’t get a reply")
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(failure.message)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) { actions }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) { actions }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.generationFailure")
    }

    @ViewBuilder
    private var actions: some View {
        Button("Retry", action: onRetry)
            .buttonStyle(.lifeBoardPrimaryCompact)
            .accessibilityIdentifier("chat.generationFailure.retry")
        if canUseOffline {
            Button("Use offline", action: onUseOffline)
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("chat.generationFailure.useOffline")
        }
        Button("Discard", action: onDiscard)
            .buttonStyle(.lifeBoardChip)
            .accessibilityIdentifier("chat.generationFailure.discard")
    }
}
