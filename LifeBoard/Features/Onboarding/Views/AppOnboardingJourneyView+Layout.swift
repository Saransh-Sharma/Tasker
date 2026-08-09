import SwiftUI

extension AppOnboardingJourneyView {
    var spacing: SemanticSpacingTokens {
        ThemeStore.shared.tokens(for: layoutClass).spacing
    }

    var horizontalPadding: CGFloat {
        layoutClass.isPad ? 32 : spacing.screenHorizontal
    }

    var contentWidth: CGFloat {
        layoutClass.isPad ? 1120 : .infinity
    }

    var shouldShowWelcomeExperience: Bool {
        viewModel.step == .welcome
    }

    var isWelcomeIntroActive: Bool {
        shouldShowWelcomeExperience && welcomeIntroPhase.showsIntroOverlay
    }

    var shouldShowBottomDock: Bool {
        guard viewModel.step != .welcome else { return false }
        guard isWelcomeIntroActive == false else { return false }
        return true
    }

    var shouldShowGlobalSkipButton: Bool {
        viewModel.step != .success && shouldShowWelcomeExperience == false
    }

    var skipTopPadding: CGFloat {
        layoutClass.isPad ? 28 : 18
    }

    var currentVisualTheme: OnboardingStepVisualTheme {
        OnboardingStepVisualTheme.theme(for: viewModel.step)
    }

    var isKeyboardEditing: Bool {
        focusedInputField != nil
    }

    var pageMotionIsReduced: Bool {
        reduceMotion || isKeyboardEditing
    }

    var backgroundLayer: some View {
        AppOnboardingBackground()
    }

    @ViewBuilder
    var contentLayer: some View {
        if viewModel.step == .success, let summary = viewModel.successSummary {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    successView(summary: summary)
                }
                .frame(maxWidth: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s16)
                .padding(.bottom, 120)
            }
            .onboardingConcentricPageMotion(step: viewModel.step, reduceMotion: pageMotionIsReduced)
        } else if shouldShowWelcomeExperience {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: spacing.sectionGap) {
                        stepHeader
                        downloadChrome
                        stepBody
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, spacing.s16)
                    .padding(.bottom, 120)
                }
                .onChange(of: focusedInputField) { _, field in
                    guard let field else { return }
                    withAnimation(LifeBoardAnimation.feedbackFast) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .onboardingConcentricPageMotion(step: viewModel.step, reduceMotion: pageMotionIsReduced)
        }
    }

    var globalSkipButton: some View {
        Button("Skip") {
            feedbackController.light()
            Task { await viewModel.skipToEnd() }
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.skipButton)
    }

    // MARK: - Welcome

    func scheduleWelcomeIntroIfNeeded() {
        guard shouldShowWelcomeExperience else {
            welcomeIntroPhase = .introCTAReady
            hasSkippedWelcomeIntroDelay = false
            return
        }

        if hasCompletedWelcomeIntro {
            welcomeIntroPhase = .introCTAReady
            hasSkippedWelcomeIntroDelay = false
        } else {
            welcomeIntroRunID = UUID()
        }
    }

    /// Two beats, about 1.4 seconds.
    ///
    /// The previous sequence ran five phases over roughly 6.4 seconds before the
    /// user could do anything — a long time to hold someone who has just opened
    /// an app for the first time. The reveal now lands quickly and still reads as
    /// deliberate; tapping anywhere skips straight to the CTA.
    func runWelcomeIntroSequenceIfNeeded() async {
        guard shouldShowWelcomeExperience,
              hasCompletedWelcomeIntro == false,
              hasSkippedWelcomeIntroDelay == false
        else { return }

        await MainActor.run { welcomeIntroPhase = .introVideoOnly }

        guard await sleepIfNeeded(milliseconds: 480) else { return }

        await MainActor.run {
            withAnimation(reduceMotion ? LifeBoardAnimation.stateChange : LifeBoardAnimation.gatewayReveal) {
                welcomeIntroPhase = .introCardHold
            }
        }

        guard await sleepIfNeeded(milliseconds: 900) else { return }

        await MainActor.run {
            withAnimation(reduceMotion ? LifeBoardAnimation.stateChange : LifeBoardAnimation.heroEmphasis) {
                welcomeIntroPhase = .introCTAReady
            }
        }
    }

    @MainActor
    func skipWelcomeIntroDelay() {
        guard shouldShowWelcomeExperience,
              hasCompletedWelcomeIntro == false,
              welcomeIntroPhase.rawValue < WelcomeIntroPhase.introCTAReady.rawValue
        else { return }

        hasSkippedWelcomeIntroDelay = true
        welcomeIntroRunID = UUID()

        if reduceMotion {
            welcomeIntroPhase = .introCTAReady
        } else {
            withAnimation(LifeBoardAnimation.heroEmphasis) {
                welcomeIntroPhase = .introCTAReady
            }
        }
    }

    func continueFromWelcomeIntro() {
        guard shouldShowWelcomeExperience,
              hasCompletedWelcomeIntro == false,
              welcomeIntroPhase == .introCTAReady
        else { return }

        feedbackController.medium()
        hasCompletedWelcomeIntro = true
        hasSkippedWelcomeIntroDelay = false
        viewModel.begin(mode: .guided)
    }

    func sleepIfNeeded(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
            return Task.isCancelled == false
        } catch {
            return false
        }
    }

    // MARK: - Header

    var stepHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(alignment: .center, spacing: spacing.s12) {
                if viewModel.canGoBack {
                    stepHeaderBackButton
                } else {
                    stepHeaderBackButton
                        .hidden()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .center, spacing: spacing.s12) {
                    EvaMascotView(placement: viewModel.step.evaMascotPlacement, size: .chip)
                        .accessibilityHidden(true)

                    OnboardingEyebrowLabel(title: viewModel.step.eyebrowTitle)
                    Spacer(minLength: spacing.s12)
                    Text(viewModel.step.progressLabel)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.goldInk)
                }

                Capsule()
                    .fill(OnboardingTheme.headerAccent.opacity(0.16))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(OnboardingTheme.headerAccent.opacity(0.9))
                                .frame(width: proxy.size.width * (OnboardingProgress(step: viewModel.step)?.fraction ?? 0))
                        }
                    }
                    .frame(height: 7)
                    .animation(reduceMotion ? nil : LifeBoardAnimation.stateChange, value: viewModel.step)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.progress)
                    .accessibilityLabel("Setup progress")
                    .accessibilityValue(viewModel.step.accessibilitySummary)
            }
        }
    }

    var stepHeaderBackButton: some View {
        Button {
            feedbackController.light()
            viewModel.goBack()
        } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(.lifeBoardChip)
    }

    // MARK: - Step routing

    @ViewBuilder
    var stepBody: some View {
        switch viewModel.step {
        case .welcome:
            EmptyView()
        case .intent:
            intentStep
        case .lifeAreas:
            lifeAreasStep
        case .guide:
            guideStep
        case .dayShape:
            dayShapeStep
        case .modules:
            modulesStep
        case .firstWin:
            firstWinStep
        case .permissions:
            permissionsStep
        case .success:
            EmptyView()
        }
    }

    var intentStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(title: OnboardingCopy.Intent.title)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.goal)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 240 : 170), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                ForEach(Array(OnboardingPrimaryGoal.allCases.enumerated()), id: \.element.id) { index, goal in
                    OnboardingSelectableCard(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        icon: goal.symbolName,
                        accentColor: currentVisualTheme.accent,
                        accessibilityID: AppOnboardingAccessibilityID.primaryGoal(goal.id),
                        isSelected: viewModel.selectedGoal == goal
                    ) {
                        registerSelection()
                        viewModel.selectGoal(goal)
                    }
                    .cardEntrance(index: index)
                }
            }
        }
    }
}
