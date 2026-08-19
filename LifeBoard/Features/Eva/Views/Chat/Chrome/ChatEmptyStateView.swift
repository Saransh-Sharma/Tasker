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

    var dayOverviewStarterPrompt: EvaStarterPrompt {
        EvaStarterPrompt.dayOverviewPrompt
    }

    var body: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            structuredPlanEmptyState
        } else if isActivationPresentation {
            activationEmptyState
        } else {
            legacyEmptyState
        }
    }

    /// The activation lockup.
    ///
    /// It scrolls rather than sitting between two `Spacer`s. The composer's
    /// bottom inset plus the keyboard can leave less height than this content
    /// needs, and a squeezed `VStack` compressed the lockup into the composer's
    /// top edge and re-centred itself on every keyboard frame. Scrolling also
    /// gives a threadless chat somewhere to attach interactive keyboard
    /// dismissal, which previously only existed on the transcript.
    ///
    /// The surrounding card is gone deliberately: `surfacePrimary` at `.e1` on
    /// Eva's cream canvas has almost no edge, so it read as a wide empty slab
    /// with the daypart celestial leaking around it rather than as a card.
    var activationEmptyState: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // The same mascot the structured empty state uses. The
                    // Lottie seat that was here renders a 16:9 animation inside
                    // a circle, so at this size the artwork collapsed to a
                    // sliver and the seat read as an empty disc.
                    EvaMascotView(placement: .chatEmptyHeader, size: .card)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("\(identity.askAction) anything")
                            .font(.lifeboard(.title2))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("chat.emptyState.title")
                        Text("Your plans, your priorities, and what today actually looks like.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
                .enhancedStaggeredAppearance(index: 0)
            }
            .scrollBounceBehavior(.basedOnSize)
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.emptyState.container")
    }

    var legacyEmptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(EvaChatSunriseGlass.assistantSurface)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1)
                    )
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(EvaChatSunriseGlass.primary)
                    .symbolEffect(
                        .wiggle.byLayer,
                        options: .repeat(.periodic(delay: 3.0)),
                        isActive: !reduceMotion
                    )
            }
            VStack(spacing: Theme.Spacing.xs) {
                Text("\(identity.askAction) anything")
                    .font(.lifeboard(.title2))
                    .foregroundStyle(EvaChatSunriseGlass.navy)
                    .accessibilityIdentifier("chat.emptyState.title")
                Text("Type / for commands")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .lifeboardPremiumSurface(
                cornerRadius: Theme.CornerRadius.xl,
                fillColor: EvaChatSunriseGlass.glassFill,
                strokeColor: EvaChatSunriseGlass.glassBorder,
                accentColor: EvaChatSunriseGlass.primary,
                level: .e2
            )
            .enhancedStaggeredAppearance(index: 0)

            promptCarousel
                .enhancedStaggeredAppearance(index: 2)

            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.emptyState.container")
    }

    var structuredPlanEmptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(alignment: .center, spacing: Theme.Spacing.sm) {
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
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(promptChips) { chip in
                        structuredExampleChip(chip)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.emptyState.container")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Openers handed over by onboarding lead, when there are any.
    ///
    /// `starterPrompts` is empty in normal presentation *unless* onboarding
    /// staged a set composed from the person's own Life Map answers. Those are
    /// far better first questions than the curated defaults — they name the
    /// user's areas, capacity, and calendar — so they go first, and the curated
    /// chips follow as alternatives rather than being replaced.
    var promptChips: [EvaHomePromptChip] {
        let curated = EvaChiefOfStaffGuideContent.homePromptChips(for: identity)
        guard starterPrompts.isEmpty == false else { return curated }
        let staged = starterPrompts.map {
            EvaHomePromptChip(id: $0.id, icon: $0.isRecommended ? "sparkles" : "arrow.turn.down.right", prompt: $0)
        }
        let stagedIDs = Set(staged.map(\.id))
        return staged + curated.filter { stagedIDs.contains($0.id) == false }
    }

    var guideButton: some View {
        Button(action: onOpenEvaGuide) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .lifeboardFont(.meta)
                Text("Guide")
                    .font(.lifeboard(.caption1))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(EvaChatSunriseGlass.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: 44)
            .background {
                Color.clear.lifeBoardSystemGlass(.regular, in: Capsule(style: .continuous), interactive: true)
            }
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
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
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
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .frame(width: 236, alignment: .leading)
            .frame(minHeight: 78, alignment: .leading)
            .lifeboardPremiumSurface(
                cornerRadius: Theme.CornerRadius.lg,
                fillColor: EvaChatSunriseGlass.glassFill,
                strokeColor: EvaChatSunriseGlass.assistantBorder.opacity(0.72),
                accentColor: EvaChatSunriseGlass.primary,
                level: .e1
            )
        }
        .buttonStyle(.plain)
        .lifeboardPressFeedback()
    }

    /// Only the legacy (pre-structured-composer) empty state renders this.
    /// During activation the starters live on the composer's own rail instead,
    /// so they ride the keyboard with the field they fill in.
    @ViewBuilder
    var promptCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(commandSuggestions, id: \.id) { descriptor in
                    commandSuggestionChip(for: descriptor)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
    }

    func commandSuggestionChip(for descriptor: SlashCommandDescriptor) -> some View {
        Button {
            onSelectSuggestion(descriptor)
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: descriptor.id.icon)
                    .font(.lifeboard(.caption1))
                Text(descriptor.command)
                    .font(.lifeboard(.callout))
            }
            .foregroundStyle(EvaChatSunriseGlass.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
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
