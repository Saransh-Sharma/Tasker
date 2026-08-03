import SwiftUI

struct ChatEmptyStateView: View {
    let identity: AssistantIdentitySnapshot
    let presentationMode: ChatPresentationMode
    let starterPrompts: [EvaStarterPrompt]
    let commandSuggestions: [SlashCommandDescriptor]
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void
    let onOpenEvaGuide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    var body: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            structuredPlanEmptyState
        } else {
            VStack(spacing: LifeBoardTheme.Spacing.lg) {
            Spacer()

            if isActivationPresentation {
                VStack(spacing: LifeBoardTheme.Spacing.sm) {
                    EvaLoopingLottieContainer(size: 64)
                    VStack(spacing: LifeBoardTheme.Spacing.xs) {
                        Text("\(identity.askAction) anything")
                            .font(.lifeboard(.title2))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .accessibilityIdentifier("chat.emptyState.title")
                        Text("Start with a focused prompt, or use a command for structured help.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                .padding(.vertical, LifeBoardTheme.Spacing.lg)
                .lifeboardPremiumSurface(
                    cornerRadius: LifeBoardTheme.CornerRadius.xl,
                    fillColor: Color.lifeboard(.surfacePrimary),
                    strokeColor: Color.lifeboard(.strokeHairline),
                    accentColor: Color.lifeboard(.accentSecondary),
                    level: .e1,
                    useNativeGlass: false
                )
                .enhancedStaggeredAppearance(index: 0)
            } else {
                ZStack {
                    Circle()
                        .fill(EvaChatSunriseGlass.assistantSurface)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1)
                        )
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(EvaChatSunriseGlass.primary)
                        .symbolEffect(
                            .wiggle.byLayer,
                            options: .repeat(.periodic(delay: 3.0)),
                            isActive: !reduceMotion
                        )
                }
                VStack(spacing: LifeBoardTheme.Spacing.xs) {
                    Text("\(identity.askAction) anything")
                        .font(.lifeboard(.title2))
                        .foregroundStyle(EvaChatSunriseGlass.navy)
                        .accessibilityIdentifier("chat.emptyState.title")
                    Text("Type / for commands")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.xl)
                .padding(.vertical, LifeBoardTheme.Spacing.lg)
                .lifeboardPremiumSurface(
                    cornerRadius: LifeBoardTheme.CornerRadius.xl,
                    fillColor: EvaChatSunriseGlass.glassFill,
                    strokeColor: EvaChatSunriseGlass.glassBorder,
                    accentColor: EvaChatSunriseGlass.primary,
                    level: .e2
                )
                .enhancedStaggeredAppearance(index: 0)
            }

            promptCarousel
                .enhancedStaggeredAppearance(index: 2)

            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.emptyState.container")
        }
    }

    var structuredPlanEmptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                    HStack(alignment: .center, spacing: LifeBoardTheme.Spacing.sm) {
                        EvaMascotView(placement: .chatEmptyHeader, size: .avatar)
                        Text("Hi there!")
                            .lifeboardFont(.screenTitle)
                            .foregroundStyle(EvaChatSunriseGlass.primary)
                    }

                    Text("What do you need to plan?")
                        .lifeboardFont(.title1)
                        .foregroundStyle(EvaChatSunriseGlass.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    guideButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LifeBoardTheme.Spacing.xl)
            .padding(.top, LifeBoardTheme.Spacing.xl)

            Spacer(minLength: LifeBoardTheme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LifeBoardTheme.Spacing.md) {
                    ForEach(EvaChiefOfStaffGuideContent.homePromptChips(for: identity)) { chip in
                        structuredExampleChip(chip)
                    }
                }
                .padding(.horizontal, LifeBoardTheme.Spacing.xl)
                .padding(.bottom, LifeBoardTheme.Spacing.sm)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.emptyState.container")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var guideButton: some View {
        Button(action: onOpenEvaGuide) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("Guide")
                    .font(.lifeboard(.caption1))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(EvaChatSunriseGlass.primary)
            .padding(.horizontal, LifeBoardTheme.Spacing.md)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                Capsule()
                    .fill(EvaChatSunriseGlass.assistantSurface.opacity(0.54))
            }
            .overlay {
                Capsule()
                    .stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1)
            }
            .shadow(color: EvaChatSunriseGlass.navy.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(identity.displayName) help")
        .accessibilityHint("Shows ways to use \(identity.displayName) as your chief of staff.")
        .accessibilityIdentifier("eva.structured.help")
        .lifeboardPressFeedback()
    }

    func structuredExampleChip(_ chip: EvaHomePromptChip) -> some View {
        Button {
            onSelectStarterPrompt(chip.prompt)
        } label: {
            HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.sm) {
                Image(systemName: chip.icon)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(EvaChatSunriseGlass.primary)
                    .frame(width: 32, height: 32)
                    .background(EvaChatSunriseGlass.assistantSurface, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(chip.prompt.title)
                        .lifeboardFont(.callout)
                        .foregroundStyle(EvaChatSunriseGlass.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(chip.prompt.submissionText)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, LifeBoardTheme.Spacing.md)
            .padding(.vertical, LifeBoardTheme.Spacing.md)
            .frame(width: 236, alignment: .leading)
            .frame(minHeight: 78, alignment: .leading)
            .lifeboardPremiumSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.lg,
                fillColor: EvaChatSunriseGlass.glassFill,
                strokeColor: EvaChatSunriseGlass.assistantBorder.opacity(0.72),
                accentColor: EvaChatSunriseGlass.primary,
                level: .e1
            )
        }
        .buttonStyle(.plain)
        .lifeboardPressFeedback()
    }

    @ViewBuilder
    var promptCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LifeBoardTheme.Spacing.sm) {
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
            .padding(.horizontal, LifeBoardTheme.Spacing.xl)
        }
    }

    func starterPromptChip(_ prompt: EvaStarterPrompt) -> some View {
        Button {
            onSelectStarterPrompt(prompt)
        } label: {
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                    .font(.lifeboard(.caption1))
                Text(prompt.title)
                    .font(.lifeboard(.callout))
            }
            .foregroundStyle(prompt.isRecommended ? Color.lifeboard(.accentOnPrimary) : EvaChatSunriseGlass.primary)
            .padding(.horizontal, LifeBoardTheme.Spacing.md)
            .padding(.vertical, LifeBoardTheme.Spacing.sm)
            .background(prompt.isRecommended ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.assistantSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(prompt.isRecommended ? EvaChatSunriseGlass.primary : EvaChatSunriseGlass.assistantBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send \(prompt.title)")
        .accessibilityIdentifier("chat.activation_starter.\(prompt.id)")
        .lifeboardPressFeedback()
    }

    func commandSuggestionChip(for descriptor: SlashCommandDescriptor) -> some View {
        Button {
            onSelectSuggestion(descriptor)
        } label: {
            HStack(spacing: LifeBoardTheme.Spacing.xs) {
                Image(systemName: descriptor.id.icon)
                    .font(.lifeboard(.caption1))
                Text(descriptor.command)
                    .font(.lifeboard(.callout))
            }
            .foregroundStyle(EvaChatSunriseGlass.primary)
            .padding(.horizontal, LifeBoardTheme.Spacing.md)
            .padding(.vertical, LifeBoardTheme.Spacing.sm)
            .background(EvaChatSunriseGlass.assistantSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(EvaChatSunriseGlass.assistantBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run command \(descriptor.command)")
        .accessibilityIdentifier("chat.command_suggestion.\(descriptor.id.rawValue)")
        .lifeboardPressFeedback()
    }
}
