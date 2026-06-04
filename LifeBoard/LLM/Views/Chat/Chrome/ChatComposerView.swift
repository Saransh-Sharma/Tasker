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

    var body: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                if shouldShowComposerSuggestionStrip {
                    composerSuggestionStrip
                }
                structuredComposer
            }
        } else {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
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
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            if isActivationPresentation {
                Text(activationConfiguration?.helperCopy ?? "Type / for structured help like today, week, or project.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
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
                #if os(iOS) || os(visionOS)
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                #elseif os(macOS)
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .onSubmit(onSubmitPrompt)
                    .submitLabel(.send)
                #endif
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                #if os(iOS) || os(visionOS)
                    .frame(minHeight: 48)
                    .onSubmit(onSubmitPrompt)
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
        .padding(.vertical, LifeBoardTheme.Spacing.sm)
        .padding(.horizontal, 2)
        .lifeboardPremiumSurface(
            cornerRadius: 28,
            fillColor: EvaChatSunriseGlass.glassFill,
            strokeColor: EvaChatSunriseGlass.glassBorder,
            accentColor: EvaChatSunriseGlass.primary,
            level: .e3
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lifeboard(.surfaceSecondary))
        )
        #endif
        .accessibilityIdentifier("chat.composer.container")
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
        }
    }
}
