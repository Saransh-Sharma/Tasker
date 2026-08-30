import SwiftUI

struct ChatComposerView: View {


    let identity: AssistantIdentitySnapshot

    let presentationMode: ChatPresentationMode

    let slashDraft: SlashCommandInvocation?

    let activeAttachments: [ThreadContextAttachmentRecord]

    let commandFeedback: String?

    let hasCurrentThread: Bool

    @Binding var prompt: String

    @FocusState.Binding var isPromptFocused: Bool

    @FocusState.Binding var isProjectFieldFocused: Bool

    let projectQuery: Binding<String>

    let commandSuggestions: [SlashCommandDescriptor]

    let starterPrompts: [EvaStarterPrompt]

    let isGenerationInFlight: Bool

    let canSubmit: Bool

    let llmCancelled: Bool

    let hasActivationAssistantReply: Bool

    let onOpenSlashPicker: () -> Void

    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void

    let onSelectSuggestion: (SlashCommandDescriptor) -> Void

    let onCancelDraft: () -> Void

    let onRemoveAttachment: (ThreadContextAttachmentRecord) -> Void

    let onGenerate: () -> Void

    let onStop: () -> Void

    let onSubmitPrompt: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var structuredDeferredFeedback: String?
    @State var dictationController = UniversalDictationController()

    var body: some View {
        // Was gated on `#available(iOS 26.0, *)`; the deployment target is
        // 26.0, so the ungrouped fallback was unreachable.
        GlassEffectContainer(spacing: Theme.Spacing.xs) {
            composerContent
        }
    }

    @ViewBuilder
    private var composerContent: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if shouldShowComposerSuggestionStrip {
                    composerSuggestionStrip
                }
                structuredComposer
                    .lifeBoardGlassIdentity(.evaComposer)
            }
        } else {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let slashDraft {
                commandDraftRow(slashDraft)
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.statusDanger))
                    .padding(.horizontal, Theme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            if isActivationPresentation {
                Text(activationConfiguration?.helperCopy ?? "Type / for structured help like today, week, or project.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(.horizontal, Theme.Spacing.md)
                    .accessibilityIdentifier("chat.activation.slash_helper")
            }

            if shouldShowComposerSuggestionStrip {
                composerSuggestionStrip
            }

            HStack(alignment: .bottom, spacing: 0) {
                slashButton

                TextField(composerPlaceholder, text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .tint(EvaChatSunriseGlass.primary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    // `.submitLabel` was macOS-only, which left the iOS return
                    // key doing nothing but inserting a newline into a
                    // vertical-axis field. A send key is the fastest exit a
                    // hardware keyboard has.
                    .onSubmit(onSubmitPrompt)
                    .submitLabel(.send)
                #if os(iOS) || os(visionOS)
                    .frame(minHeight: 48)
                    .evaComposerKeyboardDismissal(isFocused: $isPromptFocused)
                #elseif os(macOS)
                    .frame(minHeight: 32)
                #endif

                if isGenerationInFlight {
                    stopButton
                } else {
                    generateButton
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, 2)
        .lifeBoardGlassSurface(cornerRadius: Theme.CornerRadius.bottomBar, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.bottomBar, style: .continuous)
                .stroke(EvaChatSunriseGlass.glassBorder, lineWidth: 1)
        }
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lifeboard(.surfaceSecondary))
        )
        #endif
        .accessibilityIdentifier("chat.composer.container")
        .lifeBoardGlassIdentity(.evaComposer)
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
        }
    }
}

/// The keyboard's own way out of Eva.
///
/// Eva's composer is the one field in the app that can strand a user. The shell
/// hides the compact dock while it is focused
/// (`FoundationCompactChromeVisibilityPolicy`), Eva is a stack root so there is
/// no back chevron behind it, and a vertical-axis `TextField` spends its return
/// key on a newline — so with the keyboard up there was no control left on
/// screen that could put it away.
///
/// Modelled on `ComposerNumberField`'s accessory in `LifeBoardComposerFields`,
/// which added the same affordance to `.decimalPad` for the same reason: an
/// accessory belongs to the control, not to each call site that remembers it.
struct EvaComposerKeyboardDismissal: ViewModifier {
    @FocusState.Binding var isFocused: Bool

    func body(content: Content) -> some View {
        content
        #if os(iOS) || os(visionOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                        .font(.lifeboard(.callout))
                        .accessibilityLabel("Close keyboard")
                        .accessibilityIdentifier("chat.composer.dismiss_keyboard")
                }
            }
        #endif
    }
}

extension View {
    func evaComposerKeyboardDismissal(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(EvaComposerKeyboardDismissal(isFocused: isFocused))
    }
}

// MARK: - Suggestion rail

/// The starter prompts, as a rail that belongs to the composer.
///
/// They used to be the third element of the empty state's centred
/// `Spacer / card / chips / Spacer` stack, which meant the keyboard squeezed
/// them into the composer's top edge and they animated on their own timing —
/// they read as debris floating above the input rather than as part of it.
/// Hosting them inside the composer container makes them ride the keyboard with
/// the field they fill in, which is what every other chat surface does.
extension ChatComposerView {
    var shouldShowComposerSuggestionStrip: Bool {
        guard slashDraft == nil else { return false }
        // The empty state no longer carries its own carousel during activation,
        // so this rail is the only place the starters exist. Requiring a thread
        // would have hidden them exactly when they are most useful.
        guard hasCurrentThread || isActivationPresentation else { return false }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if isActivationPresentation,
           activationConfiguration?.collapsesCoachingAfterFirstAssistantReply == true,
           hasActivationAssistantReply {
            return false
        }

        return true
    }

    var composerSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                if isActivationPresentation {
                    ForEach(Array(activationStarterPrompts.enumerated()), id: \.element.id) { index, prompt in
                        suggestionChip(
                            icon: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"),
                            title: prompt.title,
                            isEmphasized: prompt.isRecommended,
                            accessibilityLabel: "Send \(prompt.title)",
                            action: { onSelectStarterPrompt(prompt) }
                        )
                        // Applied here rather than inside `suggestionChip`: the
                        // identifier gate inventories the literal argument of
                        // `.accessibilityIdentifier`, so threading it through a
                        // parameter would drop these from the pinned contract.
                        .accessibilityIdentifier("chat.activation.composer_starter.\(prompt.id)")
                        .enhancedStaggeredAppearance(index: index)
                    }
                } else {
                    suggestionChip(
                        icon: "sparkle",
                        title: dayOverviewStarterPrompt.title,
                        isEmphasized: true,
                        accessibilityLabel: "Send \(dayOverviewStarterPrompt.title)",
                        action: { onSelectStarterPrompt(dayOverviewStarterPrompt) }
                    )
                    .accessibilityIdentifier("chat.command_composer_starter.\(dayOverviewStarterPrompt.id)")

                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        suggestionChip(
                            icon: descriptor.id.icon,
                            title: descriptor.command,
                            isEmphasized: false,
                            accessibilityLabel: "Insert \(descriptor.command)",
                            action: { onSelectSuggestion(descriptor) }
                        )
                        .accessibilityIdentifier("chat.command_composer_suggestion.\(descriptor.id.rawValue)")
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
        // A chip clipped flush against the container edge reads as broken text
        // rather than as more content. Fading the trailing edge says "scroll".
        // Only the gradient's alpha is used here; the colour is arbitrary.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: Color.lifeboard(.bgCanvas), location: 0),
                    .init(color: Color.lifeboard(.bgCanvas), location: 0.9),
                    .init(color: Color.lifeboard(.bgCanvas).opacity(0), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .transition(.opacity)
    }

    /// One capsule, two emphases.
    ///
    /// The recommended starter used to be a filled dark capsule, which read as
    /// the screen's primary action and competed with the send button beside it.
    /// Emphasis is carried by the stroke now, so the send button stays the only
    /// filled control in the composer.
    @ViewBuilder
    func suggestionChip(
        icon: String,
        title: String,
        isEmphasized: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.lifeboard(.caption2))
                Text(title)
                    .font(.lifeboard(.caption1))
                    .lineLimit(1)
            }
            .foregroundStyle(EvaChatSunriseGlass.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 44)
            .background(EvaChatSunriseGlass.assistantSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isEmphasized ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.assistantBorder,
                        lineWidth: isEmphasized ? 1.5 : 1
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .lifeboardPressFeedback()
    }
}
