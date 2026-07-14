import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingJourneyView {
    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
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

    var evaSolutionBullets: [String] {
        let selectedPainPoints = viewModel.selectedPainPoints
        var bullets: [String] = []
        if selectedPainPoints.contains(.overwhelm) || selectedPainPoints.contains(.tooManyPriorities) {
            bullets.append("LifeBoard picks one clear next task across work and life.")
        }
        if selectedPainPoints.contains(.forgottenFollowUps) || selectedPainPoints.contains(.listCalendarMismatch) {
            bullets.append("Calendar events, areas, and follow-ups stay in one view.")
        }
        if selectedPainPoints.contains(.habitRestarts) {
            bullets.append("Your starter habit gets a visible streak board today.")
        }
        if selectedPainPoints.contains(.hijackedDay) {
            bullets.append("\(viewModel.selectedMascotPersona.displayName) helps choose a new task when the day changes.")
        }
        if bullets.isEmpty {
            bullets = [
                "LifeBoard organizes areas, tasks, habits, and calendar context.",
                "\(viewModel.selectedMascotPersona.displayName) prepares suggestions after your starter setup is ready."
            ]
        }
        return bullets
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

    var onboardingBackdropMode: OnboardingCinematicBackdrop.Mode {
        if shouldShowWelcomeExperience {
            return .intro(welcomeIntroPhase)
        }
        return .steady(currentVisualTheme)
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

    /// The dark cinematic video backs only the welcome intro. Every other
    /// step sits on the Sunrise Glass canvas with a pastel step wash. The
    /// slow crossfade out of the video is the sunrise moment itself.
    var backgroundLayer: some View {
        ZStack {
            if shouldShowWelcomeExperience {
                OnboardingCinematicBackdrop(
                    mode: onboardingBackdropMode,
                    includeWelcomeAccessibilityMarkers: true
                )
            } else {
                AppOnboardingBackground()
            }
        }
        .animation(
            pageMotionIsReduced ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.6),
            value: shouldShowWelcomeExperience
        )
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
            welcomeExperienceContent
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
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .onboardingConcentricPageMotion(step: viewModel.step, reduceMotion: pageMotionIsReduced)
        }
    }

    var welcomeExperienceContent: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var globalSkipButton: some View {
        Button("Skip") {
            feedbackController.light()
            Task {
                await viewModel.skipToFocusRoom()
            }
        }
        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.skipButton)
    }

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

    func runWelcomeIntroSequenceIfNeeded() async {
        guard shouldShowWelcomeExperience,
              hasCompletedWelcomeIntro == false,
              hasSkippedWelcomeIntroDelay == false
        else { return }

        if reduceMotion {
            await MainActor.run {
                welcomeIntroPhase = .introVideoOnly
            }

            guard await sleepIfNeeded(milliseconds: 2500) else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.36)) {
                    welcomeIntroPhase = .introCardHold
                }
            }

            guard await sleepIfNeeded(milliseconds: 2000) else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.24)) {
                    welcomeIntroPhase = .introCTAReady
                }
            }
            return
        }

        await MainActor.run {
            welcomeIntroPhase = .introVideoOnly
        }

        guard await sleepIfNeeded(milliseconds: 2500) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15)) {
                welcomeIntroPhase = .introTitleReveal
            }
        }

        guard await sleepIfNeeded(milliseconds: 550) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 0.92, 0.24, 1, duration: 1.15)) {
                welcomeIntroPhase = .introSubtitleReveal
            }
        }

        guard await sleepIfNeeded(milliseconds: 1350) else { return }

        await MainActor.run {
            welcomeIntroPhase = .introCardHold
        }

        guard await sleepIfNeeded(milliseconds: 2000) else { return }

        await MainActor.run {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) {
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
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)) {
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.progress)
                    .accessibilityLabel("Onboarding progress")
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
                .lifeboardFont(.buttonSmall)
                .foregroundStyle(OnboardingTheme.textPrimary)
        }
        .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textPrimary)
    }

    @ViewBuilder
    var stepBody: some View {
        switch viewModel.step {
        case .welcome:
            EmptyView()
        case .goal:
            goalStep
        case .pain:
            painStep
        case .evaValue:
            evaValueStep
        case .blocker:
            EmptyView()
        case .lifeAreas:
            lifeAreasStep
        case .projects:
            EmptyView()
        case .habits:
            EmptyView()
        case .habitSetup:
            habitSetupStep
        case .streakPreview:
            EmptyView()
        case .evaStyle:
            evaStyleStep
        case .workBlockers:
            workBlockersStep
        case .weeklyOutcomes:
            weeklyOutcomesStep
        case .processing:
            EmptyView()
        case .firstTask:
            firstTaskStep
        case .focusRoom:
            EmptyView()
        case .habitCheckIn:
            EmptyView()
        case .homeDemo:
            homeDemoStep
        case .calendarPermission:
            calendarPermissionStep
        case .notificationPermission:
            notificationPermissionStep
        case .success:
            EmptyView()
        }
    }

    var goalStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Goal.title,
                subtitle: OnboardingCopy.Goal.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.goal)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 240 : 170), spacing: spacing.s12)],
                spacing: spacing.s12
            ) {
                ForEach(OnboardingPrimaryGoal.allCases) { goal in
                    OnboardingSelectableCard(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        icon: goal.symbolName,
                        accentColor: OnboardingTheme.accent,
                        accessibilityID: AppOnboardingAccessibilityID.primaryGoal(goal.id),
                        isSelected: viewModel.selectedGoal == goal
                    ) {
                        feedbackController.selection()
                        viewModel.selectGoal(goal)
                    }
                }
            }
        }
    }
}
