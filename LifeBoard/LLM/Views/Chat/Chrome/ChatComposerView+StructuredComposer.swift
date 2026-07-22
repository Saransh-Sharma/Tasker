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
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.statusDanger))
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: LifeBoardTheme.Spacing.xs) {
                TextField("Tell me your plans...", text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .tint(Color.lifeboard(.accentPrimary))
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                    .frame(minHeight: 52)
                    .onSubmit(onSubmitPrompt)

                if V2FeatureFlags.evaVoiceDeferred {
                    structuredDeferredIcon(systemName: "mic.fill", label: "Voice planning")
                }
                if V2FeatureFlags.evaScanDeferred {
                    structuredDeferredIcon(systemName: "viewfinder", label: "Scan planning")
                }

                if isGenerationInFlight {
                    stopButton
                        .padding(.leading, 0)
                } else {
                    generateButton
                        .padding(.leading, 0)
                }
            }

            if let structuredDeferredFeedback {
                Text(structuredDeferredFeedback)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .accessibilityIdentifier("eva.structured.deferred.feedback")
            }
        }
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
        .lifeBoardGlassSurface(cornerRadius: 28, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    isPromptFocused ? EvaChatSunriseGlass.primary.opacity(0.42) : EvaChatSunriseGlass.glassBorder,
                    lineWidth: isPromptFocused ? 1.5 : 1
                )
        }
        .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: isPromptFocused)
        .accessibilityIdentifier("eva.structured.composer")
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
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
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
                            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                            .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
                        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                        .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
                            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                            .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        }
        .transition(.opacity)
    }

    var composerPlaceholder: String {
        isActivationPresentation ? "\(identity.askAction) what to focus on..." : "\(identity.askAction) anything"
    }

    var activeAttachmentRow: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            Text("Using context")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .padding(.horizontal, LifeBoardTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
                        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                        .padding(.vertical, LifeBoardTheme.Spacing.xs)
                        .background(Color.lifeboard(.accentWash))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.lifeboard(.accentMuted), lineWidth: 1))
                        .accessibilityIdentifier("chat.attachment_chip.\(attachment.id.uuidString)")
                    }
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.sm)
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
        .padding(.leading, LifeBoardTheme.Spacing.sm)
        .padding(.bottom, LifeBoardTheme.Spacing.xs)
        .accessibilityLabel("Commands")
        .accessibilityHint("Open slash commands")
        .accessibilityIdentifier("chat.slash_button")
        .lifeboardPressFeedback()
    }

    @ViewBuilder
    func commandDraftRow(_ invocation: SlashCommandInvocation) -> some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
                Label(invocation.id.canonicalCommand, systemImage: invocation.id.icon)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(EvaChatSunriseGlass.primary)
                    .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                    .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
                HStack(spacing: LifeBoardTheme.Spacing.xs) {
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
                .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                .padding(.vertical, LifeBoardTheme.Spacing.sm)
                .background(EvaChatSunriseGlass.glassFill.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                        .stroke(EvaChatSunriseGlass.glassBorder, lineWidth: 1)
                )
                .padding(.horizontal, LifeBoardTheme.Spacing.sm)
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
            .padding(.trailing, LifeBoardTheme.Spacing.md)
            .padding(.bottom, LifeBoardTheme.Spacing.xs)
        #else
            .padding(.trailing, LifeBoardTheme.Spacing.sm)
            .padding(.bottom, LifeBoardTheme.Spacing.sm)
        #endif
        .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.quick, value: canSubmit)
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
            .padding(.trailing, LifeBoardTheme.Spacing.md)
            .padding(.bottom, LifeBoardTheme.Spacing.xs)
        #else
            .padding(.trailing, LifeBoardTheme.Spacing.sm)
            .padding(.bottom, LifeBoardTheme.Spacing.sm)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .lifeboardPressFeedback()
    }
}
