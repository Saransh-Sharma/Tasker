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

    var structuredComposer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.statusDanger))
                    .padding(.horizontal, Theme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                TextField("Tell me your plans...", text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .tint(Color.lifeboard(.accentPrimary))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .frame(minHeight: 52)
                    .disabled(isStructuredDictationActive)
                    .onSubmit(onSubmitPrompt)

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
                } else if V2FeatureFlags.evaVoiceDeferred {
                    structuredDeferredIcon(systemName: "mic.fill", label: "Voice planning")
                }
                if V2FeatureFlags.evaScanDeferred && isStructuredDictationActive == false {
                    structuredDeferredIcon(systemName: "viewfinder", label: "Scan planning")
                }

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

            if let structuredDeferredFeedback {
                Text(structuredDeferredFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(.horizontal, Theme.Spacing.md)
                    .accessibilityIdentifier("eva.structured.deferred.feedback")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .lifeBoardGlassSurface(cornerRadius: 28, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    isPromptFocused ? EvaChatSunriseGlass.primary.opacity(0.42) : EvaChatSunriseGlass.glassBorder,
                    lineWidth: isPromptFocused ? 1.5 : 1
                )
        }
        .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: isPromptFocused)
        .accessibilityIdentifier("eva.structured.composer")
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
                structuredDeferredFeedback = "Preparing on-device dictation…"
            case .recording:
                structuredDeferredFeedback = "Listening… Tap stop when you’re done."
            case .finalizing:
                structuredDeferredFeedback = "Finalizing transcript…"
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

    var isStructuredDictationActive: Bool {
        dictationController.phase == .preparing
            || dictationController.phase == .recording
            || dictationController.phase == .finalizing
    }

    func startStructuredDictation() {
        structuredDeferredFeedback = "Preparing on-device dictation…"
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.link, on: .dockChrome))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("eva.structured.dictation.\(systemName)")
    }

    func structuredDeferredIcon(systemName: String, label: String) -> some View {
        Button {
            structuredDeferredFeedback = "\(label) is coming later."
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.link, on: .dockChrome))
                .frame(width: 36, height: 44)
                .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) coming later")
        .accessibilityHint("No permission will be requested.")
        .accessibilityIdentifier("eva.structured.deferred.\(systemName)")
    }

    var composerSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                if isActivationPresentation {
                    ForEach(Array(activationStarterPrompts.enumerated()), id: \.element.id) { index, prompt in
                        Button {
                            onSelectStarterPrompt(prompt)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                                    .font(.lifeboard(.caption2))
                                Text(prompt.title)
                                    .font(.lifeboard(.caption1))
                            }
                            .foregroundStyle(prompt.isRecommended ? Color.lifeboard(.accentOnPrimary) : EvaChatSunriseGlass.primary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(prompt.isRecommended ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.assistantSurface)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send \(prompt.title)")
                        .accessibilityIdentifier("chat.activation.composer_starter.\(prompt.id)")
                        .overlay(
                            Capsule()
                                .stroke(prompt.isRecommended ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.assistantBorder, lineWidth: 1)
                        )
                        .lifeboardPressFeedback()
                        .enhancedStaggeredAppearance(index: index)
                    }
                } else {
                    Button {
                        onSelectStarterPrompt(dayOverviewStarterPrompt)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.lifeboard(.caption2))
                            Text(dayOverviewStarterPrompt.title)
                                .font(.lifeboard(.caption1))
                        }
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(EvaChatSunriseGlass.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send \(dayOverviewStarterPrompt.title)")
                    .accessibilityIdentifier("chat.command_composer_starter.\(dayOverviewStarterPrompt.id)")
                    .overlay(
                        Capsule()
                            .stroke(EvaChatSunriseGlass.primary, lineWidth: 1)
                    )
                    .lifeboardPressFeedback()

                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        Button {
                            onSelectSuggestion(descriptor)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: descriptor.id.icon)
                                    .font(.lifeboard(.caption2))
                                Text(descriptor.command)
                                    .font(.lifeboard(.caption1))
                            }
                            .foregroundStyle(EvaChatSunriseGlass.primary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(EvaChatSunriseGlass.assistantSurface)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Insert \(descriptor.command)")
                        .accessibilityIdentifier("chat.command_composer_suggestion.\(descriptor.id.rawValue)")
                        .lifeboardPressFeedback()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .transition(.opacity)
    }

    var composerPlaceholder: String {
        isActivationPresentation ? "\(identity.askAction) what to focus on..." : "\(identity.askAction) anything"
    }

    var activeAttachmentRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Using context")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .padding(.horizontal, Theme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(activeAttachments) { attachment in
                        HStack(spacing: 6) {
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
                            .accessibilityHint(Text("Removes this pinned context from the current chat."))
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

    var shouldShowComposerSuggestionStrip: Bool {
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
        .accessibilityHint("Open slash commands")
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
                }
                .buttonStyle(.plain)

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

    var generateButton: some View {
        Button {
            LifeBoardFeedback.light()
            onGenerate()
        } label: {
            Image(systemName: "arrow.up")
                .font(.lifeboard(.buttonSmall))
                .fontWeight(.semibold)
                .foregroundStyle(canSubmit ? Color.lifeboard(.accentOnPrimary) : Color.lifeboard(.textQuaternary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(canSubmit ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.glassFill.opacity(0.68))
                )
        }
        .disabled(!canSubmit)
        .accessibilityIdentifier("chat.send_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xs)
        #else
            .padding(.trailing, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)
        #endif
        .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.feedbackFast, value: canSubmit)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .lifeboardPressFeedback()
    }

    var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(Color.lifeboard(.statusDanger))
                )
        }
        .disabled(llmCancelled)
        .accessibilityIdentifier("chat.stop_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xs)
        #else
            .padding(.trailing, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .lifeboardPressFeedback()
    }
}
