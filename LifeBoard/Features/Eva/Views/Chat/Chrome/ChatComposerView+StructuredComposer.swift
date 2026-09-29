import SwiftUI

extension ChatComposerView {
    var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    var activationStarterPrompts: [EvaStarterPrompt] {
        let prompts = starterPrompts
        guard let activationConfiguration else { return prompts }
        return Array(prompts.prefix(activationConfiguration.visibleStarterLimit))
    }

    var dayOverviewStarterPrompt: EvaStarterPrompt {
        EvaStarterPrompt.dayOverviewPrompt
    }

    var structuredComposerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: Theme.Spacing.xs))
    }

    var structuredComposer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            // Picking /project or /area creates a draft whose argument field
            // and cancel live in this row. The structured composer — Eva's
            // default — never drew it: the draft was invisible, Send stayed
            // disabled, and `/` could not be typed again.
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

            // At accessibility sizes the field and its controls no longer fit
            // side by side; stacking keeps every control 44 pt and above the dock.
            structuredComposerLayout {
                structuredPromptField
                if dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: Theme.Spacing.xs) {
                        structuredComposerActions
                    }
                } else {
                    structuredComposerActions
                }
            }

            if let structuredDeferredFeedback {
                Text(structuredDeferredFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(.horizontal, Theme.Spacing.md)
                    .accessibilityIdentifier("eva.structured.deferred.feedback")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .lifeBoardGlassSurface(cornerRadius: Theme.CornerRadius.bottomBar, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.bottomBar, style: .continuous)
                .stroke(
                    isPromptFocused ? EvaChatSunriseGlass.primary.opacity(0.42) : EvaChatSunriseGlass.glassBorder,
                    lineWidth: isPromptFocused ? 1.5 : 1
                )
        }
        .lifeBoardMotion(.controlMorph, value: isPromptFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
        .onChange(of: dictationController.draftText) { _, newValue in
            guard isStructuredDictationActive else { return }
            if prompt != newValue {
                prompt = newValue
            }
        }
        .onChange(of: dictationController.recovery) { _, recovery in
            guard let recovery else { return }
            structuredDeferredFeedback = recovery.message
        }
        .onChange(of: dictationController.phase) { _, phase in
            switch phase {
            case .preparing:
                structuredDeferredFeedback = String(localized: "Starting dictation…")
            case .recording:
                structuredDeferredFeedback = String(localized: "Listening…")
            case .finalizing:
                structuredDeferredFeedback = String(localized: "Transcribing…")
            case .idle:
                if dictationController.recovery == nil {
                    structuredDeferredFeedback = nil
                }
            case .denied, .unsupportedLocale, .assetInstallFailed, .failed:
                break
            }
        }
        .onDisappear {
            guard isStructuredDictationActive else { return }
            Task { await dictationController.cancel() }
        }
    }

    private var structuredPromptField: some View {
        TextField(composerPlaceholder, text: $prompt, prompt: Text(composerPlaceholder).foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
            .focused($isPromptFocused)
            .accessibilityIdentifier("eva.structured.composer")
            .textFieldStyle(.plain)
            .lifeboardFont(.body)
            .foregroundStyle(Color.lifeboard(.textPrimary))
            .tint(Color.lifeboard(.accentPrimary))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(minHeight: 52)
            .lineLimit(1...4)
            .disabled(isStructuredDictationActive)
            .onSubmit(onSubmitPrompt)
            // Eva is prose: Return breaks the line on the software keyboard,
            // so the key must not say "send". Send, or ⌘Return, sends.
            .submitLabel(.return)
            .evaComposerKeyboardDismissal(isFocused: $isPromptFocused)
    }

    @ViewBuilder
    private var structuredComposerActions: some View {
        if isStructuredDictationActive {
            structuredDictationButton(
                systemName: "xmark",
                label: "Cancel dictation",
                action: cancelStructuredDictation
            )
            structuredDictationButton(
                systemName: "stop.fill",
                label: "Stop dictation",
                action: stopStructuredDictation
            )
        } else if V2FeatureFlags.universalInputDictationEnabled {
            structuredDictationButton(
                systemName: "mic.fill",
                label: "Start dictation",
                action: startStructuredDictation
            )
        }
        #if DEBUG
        // Placeholders for features that aren't built yet. Debug builds only,
        // behind flags that default off: a shipped control that says "coming
        // later" is a dead end.
        if V2FeatureFlags.evaVoiceDeferred && isStructuredDictationActive == false
            && V2FeatureFlags.universalInputDictationEnabled == false {
            structuredDeferredIcon(systemName: "mic.fill", label: "Voice planning")
        }

        if V2FeatureFlags.evaScanDeferred && isStructuredDictationActive == false {
            structuredDeferredIcon(systemName: "viewfinder", label: "Scan planning")
        }
        #endif

        if isStructuredDictationActive == false {
            if isGenerationInFlight {
                stopButton
                    .padding(.leading, 0)
            } else {
                generateButton
                    .padding(.leading, 0)
            }
        }
    }

    var isStructuredDictationActive: Bool {
        dictationController.phase == .preparing
            || dictationController.phase == .recording
            || dictationController.phase == .finalizing
    }

    func startStructuredDictation() {
        structuredDeferredFeedback = String(localized: "Starting dictation…")
        dictationController.start(existingDraft: prompt)
        isPromptFocused = false
    }

    func stopStructuredDictation() {
        Task { @MainActor in
            await dictationController.stop()
            prompt = dictationController.draftText
            structuredDeferredFeedback = dictationController.recovery?.message
        }
    }

    func cancelStructuredDictation() {
        Task { @MainActor in
            await dictationController.cancel()
            prompt = dictationController.draftText
            structuredDeferredFeedback = nil
            isPromptFocused = true
        }
    }

    func structuredDictationButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.link, on: .dockChrome))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("eva.structured.dictation.\(systemName)")
    }

    #if DEBUG
    func structuredDeferredIcon(systemName: String, label: String) -> some View {
        Button {
            structuredDeferredFeedback = "\(label) is coming later."
        } label: {
            Image(systemName: systemName)
                .lifeboardFont(.title1)
                .foregroundStyle(Color.lifeboard(.link, on: .dockChrome))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) coming later")
        .accessibilityHint("No permission will be requested.")
        .accessibilityIdentifier("eva.structured.deferred.\(systemName)")
    }
    #endif

    var composerPlaceholder: String {
        identity.askAction
    }

    var activeAttachmentRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Pinned")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .padding(.horizontal, Theme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(activeAttachments) { attachment in
                        HStack(spacing: 8) {
                            Image(systemName: attachment.commandID.icon)
                                .font(.lifeboard(.caption2))
                            Text(attachment.commandLabel)
                                .font(.lifeboard(.caption1))
                                .lineLimit(1)
                            Button {
                                onRemoveAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.lifeboard(.caption2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove \(attachment.commandLabel)"))
                        }
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Color.lifeboard(.accentWash))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.lifeboard(.accentMuted), lineWidth: 1))
                        .accessibilityIdentifier("chat.attachment_chip.\(attachment.id.uuidString)")
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
        .transition(.opacity)
    }

    var slashButton: some View {
        Button(action: onOpenSlashPicker) {
            Text("/")
                .font(.lifeboard(.callout))
                .fontWeight(.semibold)
                .foregroundStyle(EvaChatSunriseGlass.primary)
                .frame(width: 40, height: 40)
                .lifeboardPremiumSurface(
                    cornerRadius: 20,
                    fillColor: EvaChatSunriseGlass.assistantSurface,
                    strokeColor: EvaChatSunriseGlass.assistantBorder,
                    accentColor: EvaChatSunriseGlass.primary,
                    level: .e1
                )
        }
        .padding(.leading, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .accessibilityLabel("Commands")
        .accessibilityIdentifier("chat.slash_button")
        .lifeboardPressFeedback()
    }

    @ViewBuilder
    func commandDraftRow(_ invocation: SlashCommandInvocation) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Label(invocation.id.canonicalCommand, systemImage: invocation.id.icon)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(EvaChatSunriseGlass.primary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(EvaChatSunriseGlass.assistantSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.74), lineWidth: 1))
                    .accessibilityIdentifier("chat.command_chip.\(invocation.id.rawValue)")

                Button(action: onCancelDraft) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        // The glyph is small; the target is not.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel command")
                .accessibilityIdentifier("chat.command_chip.cancel")

                Spacer()
            }

            if invocation.id.requiresArgument {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: invocation.id.icon)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))

                    TextField(invocation.id.argumentPlaceholder ?? "Pick value", text: projectQuery)
                        .font(.lifeboard(.caption1))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isProjectFieldFocused)
                        // Picking the command asks for this field before it
                        // exists, and SwiftUI drops that write; ask again once
                        // it is on screen.
                        .onAppear { DispatchQueue.main.async { isProjectFieldFocused = true } }
                        .accessibilityIdentifier("chat.command_argument_field")

                    if let resolvedArgument = invocation.resolvedArgument, !resolvedArgument.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.lifeboard(.statusSuccess))
                            Text(resolvedArgument)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.statusSuccess))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.sm)
                .background(EvaChatSunriseGlass.glassFill.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                        .stroke(EvaChatSunriseGlass.glassBorder, lineWidth: 1)
                )
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
        .transition(.opacity)
    }
}
