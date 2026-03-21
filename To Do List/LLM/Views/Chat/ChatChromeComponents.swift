import SwiftUI

struct ChatHeaderView: View {
    let title: String
    let subtitle: String
    let showsUtilityActions: Bool
    let onShowChats: () -> Void
    let onShowSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Eva")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textTertiary))

                Text(title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .lineLimit(2)
            }

            Spacer(minLength: TaskerTheme.Spacing.sm)

            if showsUtilityActions {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    iconButton(
                        systemName: "text.bubble",
                        identifier: "chat.header.chats",
                        label: "Chats",
                        action: onShowChats
                    )
                    iconButton(
                        systemName: "gearshape",
                        identifier: "chat.header.settings",
                        label: "Settings",
                        action: onShowSettings
                    )
                }
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.lg)
        .padding(.top, TaskerTheme.Spacing.sm)
        .padding(.bottom, TaskerTheme.Spacing.sm)
    }

    private func iconButton(
        systemName: String,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tasker(.textSecondary))
                .frame(width: 44, height: 44)
                .taskerChromeSurface(
                    cornerRadius: 22,
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatModelPickerButton: View {
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isPresented.toggle()
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
                    .foregroundStyle(Color.tasker(.accentPrimary))
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            #endif
            .taskerChromeSurface(
                cornerRadius: 24,
                accentColor: Color.tasker(.accentSecondary),
                level: .e1
            )
        }
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("Models")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatEmptyStateView: View {
    let presentationMode: ChatPresentationMode
    let starterPrompts: [EvaStarterPrompt]
    let commandSuggestions: [SlashCommandDescriptor]
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var activationStarterPrompts: [EvaStarterPrompt] {
        let prompts = starterPrompts
        guard let activationConfiguration else { return prompts }
        return Array(prompts.prefix(activationConfiguration.visibleStarterLimit))
    }

    var body: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            Spacer()

            if isActivationPresentation {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    EvaLoopingLottieContainer(size: 64)
                    VStack(spacing: TaskerTheme.Spacing.xs) {
                        Text("Ask Eva anything")
                            .font(.tasker(.title2))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .accessibilityIdentifier("chat.emptyState.title")
                        Text("Start with a focused prompt, or use a command for structured help.")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .taskerPremiumSurface(
                    cornerRadius: TaskerTheme.CornerRadius.xl,
                    fillColor: Color.tasker(.surfacePrimary),
                    strokeColor: Color.tasker(.strokeHairline),
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1,
                    useNativeGlass: false
                )
                .enhancedStaggeredAppearance(index: 0)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.tasker(.accentWash))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .symbolEffect(
                            .wiggle.byLayer,
                            options: .repeat(.periodic(delay: 3.0)),
                            isActive: !reduceMotion
                        )
                }
                VStack(spacing: TaskerTheme.Spacing.xs) {
                    Text("ask Eva anything")
                    .font(.tasker(.title2))
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .accessibilityIdentifier("chat.emptyState.title")
                    Text("Type / for commands")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textTertiary))
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .taskerPremiumSurface(
                    cornerRadius: TaskerTheme.CornerRadius.xl,
                    fillColor: Color.tasker(.surfacePrimary),
                    strokeColor: Color.tasker(.strokeHairline),
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1
                )
                .enhancedStaggeredAppearance(index: 0)
            }

            promptCarousel
                .enhancedStaggeredAppearance(index: 2)

            Spacer()
        }
        .accessibilityIdentifier("chat.emptyState.container")
    }

    @ViewBuilder
    private var promptCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                if isActivationPresentation {
                    ForEach(activationStarterPrompts) { prompt in
                        starterPromptChip(prompt)
                    }
                } else {
                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        commandSuggestionChip(for: descriptor)
                    }
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.xl)
        }
    }

    private func starterPromptChip(_ prompt: EvaStarterPrompt) -> some View {
        Button {
            onSelectStarterPrompt(prompt)
        } label: {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                    .font(.tasker(.caption1))
                Text(prompt.title)
                    .font(.tasker(.callout))
            }
            .foregroundStyle(prompt.isRecommended ? Color.tasker(.accentOnPrimary) : Color.tasker(.accentPrimary))
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentWash))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentMuted), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send \(prompt.title)")
        .accessibilityIdentifier("chat.activation_starter.\(prompt.id)")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    private func commandSuggestionChip(for descriptor: SlashCommandDescriptor) -> some View {
        Button {
            onSelectSuggestion(descriptor)
        } label: {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: descriptor.id.icon)
                    .font(.tasker(.caption1))
                Text(descriptor.command)
                    .font(.tasker(.callout))
            }
            .foregroundStyle(Color.tasker(.accentPrimary))
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(Color.tasker(.accentWash))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run command \(descriptor.command)")
        .accessibilityIdentifier("chat.command_suggestion.\(descriptor.id.rawValue)")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatComposerView: View {
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var activationStarterPrompts: [EvaStarterPrompt] {
        let prompts = starterPrompts
        guard let activationConfiguration else { return prompts }
        return Array(prompts.prefix(activationConfiguration.visibleStarterLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let slashDraft {
                commandDraftRow(slashDraft)
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.statusDanger))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            if isActivationPresentation {
                Text(activationConfiguration?.helperCopy ?? "Type / for structured help like today, week, or project.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
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
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker(.textPrimary))
                #if os(iOS) || os(visionOS)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                #elseif os(macOS)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .onSubmit(onSubmitPrompt)
                    .submitLabel(.send)
                #endif
                    .padding(.vertical, TaskerTheme.Spacing.sm)
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
        .padding(.vertical, TaskerTheme.Spacing.sm)
        .padding(.horizontal, 2)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.xl,
            fillColor: Color.tasker(.surfaceSecondary),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary),
            level: .e2
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker(.surfaceSecondary))
        )
        #endif
        .accessibilityIdentifier("chat.composer.container")
    }

    private var composerSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                if isActivationPresentation {
                    ForEach(Array(activationStarterPrompts.enumerated()), id: \.element.id) { index, prompt in
                        Button {
                            onSelectStarterPrompt(prompt)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                                    .font(.tasker(.caption2))
                                Text(prompt.title)
                                    .font(.tasker(.caption1))
                            }
                            .foregroundStyle(prompt.isRecommended ? Color.tasker(.accentOnPrimary) : Color.tasker(.accentPrimary))
                            .padding(.horizontal, TaskerTheme.Spacing.sm)
                            .padding(.vertical, TaskerTheme.Spacing.xs)
                            .background(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentWash))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send \(prompt.title)")
                        .accessibilityIdentifier("chat.activation.composer_starter.\(prompt.id)")
                        .overlay(
                            Capsule()
                                .stroke(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentMuted), lineWidth: 1)
                        )
                        .taskerPressFeedback(reduceMotion: reduceMotion)
                        .enhancedStaggeredAppearance(index: index)
                    }
                } else {
                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        Button {
                            onSelectSuggestion(descriptor)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: descriptor.id.icon)
                                    .font(.tasker(.caption2))
                                Text(descriptor.command)
                                    .font(.tasker(.caption1))
                            }
                            .foregroundStyle(Color.tasker(.accentPrimary))
                            .padding(.horizontal, TaskerTheme.Spacing.sm)
                            .padding(.vertical, TaskerTheme.Spacing.xs)
                            .background(Color.tasker(.accentWash))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Insert \(descriptor.command)")
                        .accessibilityIdentifier("chat.command_composer_suggestion.\(descriptor.id.rawValue)")
                        .taskerPressFeedback(reduceMotion: reduceMotion)
                    }
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.sm)
        }
        .transition(.opacity)
    }

    private var composerPlaceholder: String {
        isActivationPresentation ? "Ask Eva what to focus on..." : "ask Eva anything..."
    }

    private var activeAttachmentRow: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Using context")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .padding(.horizontal, TaskerTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    ForEach(activeAttachments) { attachment in
                        HStack(spacing: 6) {
                            Image(systemName: attachment.commandID.icon)
                                .font(.tasker(.caption2))
                            Text(attachment.commandLabel)
                                .font(.tasker(.caption1))
                                .lineLimit(1)
                            Button {
                                onRemoveAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.tasker(.caption2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove \(attachment.commandLabel)"))
                            .accessibilityHint(Text("Removes this pinned context from the current chat."))
                        }
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                        .accessibilityIdentifier("chat.attachment_chip.\(attachment.id.uuidString)")
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.sm)
            }
        }
        .transition(.opacity)
    }

    private var shouldShowComposerSuggestionStrip: Bool {
        guard slashDraft == nil else { return false }
        guard hasCurrentThread else { return false }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if isActivationPresentation,
           activationConfiguration?.collapsesCoachingAfterFirstAssistantReply == true,
           hasActivationAssistantReply {
            return false
        }

        return true
    }

    private var slashButton: some View {
        Button(action: onOpenSlashPicker) {
            Text("/")
                .font(.tasker(.callout))
                .fontWeight(.semibold)
                .foregroundStyle(Color.tasker(.accentPrimary))
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
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private func commandDraftRow(_ invocation: SlashCommandInvocation) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Label(invocation.id.canonicalCommand, systemImage: invocation.id.icon)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
                    .background(Color.tasker(.accentWash))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("chat.command_chip.\(invocation.id.rawValue)")

                Button(action: onCancelDraft) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if invocation.id.requiresArgument {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    Image(systemName: invocation.id.icon)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))

                    TextField(invocation.id.argumentPlaceholder ?? "Pick value", text: projectQuery)
                        .font(.tasker(.caption1))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isProjectFieldFocused)
                        .accessibilityIdentifier("chat.command_argument_field")

                    if let resolvedArgument = invocation.resolvedArgument, !resolvedArgument.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tasker(.statusSuccess))
                            Text(resolvedArgument)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.statusSuccess))
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

    private var generateButton: some View {
        Button(action: onGenerate) {
            Image(systemName: "arrow.up")
                .font(.tasker(.buttonSmall))
                .fontWeight(.semibold)
                .foregroundStyle(canSubmit ? Color.tasker(.accentOnPrimary) : Color.tasker(.textQuaternary))
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
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: canSubmit)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.caption)
                .foregroundStyle(Color.tasker(.accentOnPrimary))
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
        .disabled(llmCancelled)
        .accessibilityIdentifier("chat.stop_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.xs)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatScaffoldView: View {
    @EnvironmentObject private var appManager: AppManager
    @Environment(LLMEvaluator.self) private var llm

    @Binding var currentThread: Thread?
    let transcriptSnapshot: ChatTranscriptSnapshot
    let liveOutput: ChatLiveOutputState
    let presentationMode: ChatPresentationMode
    let prompt: Binding<String>
    let isPromptFocused: FocusState<Bool>.Binding
    let isProjectFieldFocused: FocusState<Bool>.Binding
    let showChats: Binding<Bool>
    let showSettings: Binding<Bool>
    let showModelPicker: Binding<Bool>
    let showSlashPicker: Binding<Bool>
    let showClearConfirmation: Binding<Bool>
    let slashDraft: Binding<SlashCommandInvocation?>
    let slashPickerQuery: Binding<String>
    let commandFeedback: String?
    let projectQuery: Binding<String>
    let commandSuggestions: [SlashCommandDescriptor]
    let recentCommands: [SlashCommandDescriptor]
    let popularCommands: [SlashCommandDescriptor]
    let allCommands: [SlashCommandDescriptor]
    let isGenerationInFlight: Bool
    let canSubmit: Bool
    let llmCancelled: Bool
    let chatTitle: String
    let onOpenTaskDetail: ((TaskDefinition) -> Void)?
    let starterPrompts: [EvaStarterPrompt]
    let activeAttachments: [ThreadContextAttachmentRecord]
    let onOpenSlashPicker: () -> Void
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void
    let onCancelDraft: () -> Void
    let onRemoveAttachment: (ThreadContextAttachmentRecord) -> Void
    let onGenerate: () -> Void
    let onStop: () -> Void
    let onSubmitPrompt: () -> Void
    let onClearCurrentThread: () -> Void

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var hasActivationAssistantReply: Bool {
        transcriptSnapshot.messages.contains { $0.role == .assistant }
    }

    private var headerTitle: String {
        if currentThread == nil {
            return isActivationPresentation ? "First win" : "Planning workspace"
        }
        return chatTitle
    }

    private var headerSubtitle: String {
        if currentThread == nil {
            return isActivationPresentation
                ? "Start with something useful. Ask Eva to prioritize, plan, or break work down."
                : "Ask, plan, then apply with confirmation."
        }
        return isActivationPresentation
            ? "Private on-device planning assistant."
            : "Keep context tight, use commands when you want structured help."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isActivationPresentation == false {
                    ChatHeaderView(
                        title: headerTitle,
                        subtitle: headerSubtitle,
                        showsUtilityActions: activationConfiguration?.hideUtilityActions != true,
                        onShowChats: {
                            appManager.playHaptic()
                            showChats.wrappedValue.toggle()
                        },
                        onShowSettings: {
                            appManager.playHaptic()
                            showSettings.wrappedValue.toggle()
                        }
                    )
                }

                if transcriptSnapshot.threadID != nil {
                    ConversationView(
                        snapshot: transcriptSnapshot,
                        liveOutput: liveOutput,
                        onOpenTaskFromCard: { task in
                            onOpenTaskDetail?(task)
                        }
                    )
                } else {
                    ChatEmptyStateView(
                        presentationMode: presentationMode,
                        starterPrompts: starterPrompts,
                        commandSuggestions: commandSuggestions,
                        onSelectStarterPrompt: onSelectStarterPrompt,
                        onSelectSuggestion: onSelectSuggestion
                    )
                }

                HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.md) {
                    if activationConfiguration?.hideUtilityActions != true {
                        ChatModelPickerButton(isPresented: showModelPicker)
                    }
                    ChatComposerView(
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
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .padding(.top, isActivationPresentation ? TaskerTheme.Spacing.xs : TaskerTheme.Spacing.sm)
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
                .sheet(isPresented: showModelPicker) {
                    NavigationStack {
                        ModelsSettingsView()
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showModelPicker.wrappedValue.toggle() }) {
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
                            Button(action: { showModelPicker.wrappedValue.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
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
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.large] : [.large])
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
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium, .large] : [.large])
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
}
