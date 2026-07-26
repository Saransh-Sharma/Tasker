import SwiftUI

struct AppOnboardingJourneyView: View {

    @ObservedObject var viewModel: OnboardingFlowModel

    let feedbackController: OnboardingFeedbackController

    let onOpenCustomTaskComposer: (AddTaskPrefillTemplate) -> Bool

    let onOpenCustomHabitComposer: (AddHabitPrefillTemplate) -> Bool

    let onEditTask: (TaskDefinition) -> Bool

    let onDismissFlow: () -> Void

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    @Environment(\.scenePhase) var scenePhase

    @State var hasPlayedSuccess = false

    @State var welcomeIntroPhase: WelcomeIntroPhase = .introVideoOnly

    @State var hasCompletedWelcomeIntro = false

    @State var hasSkippedWelcomeIntroDelay = false

    @State var welcomeIntroRunID = UUID()

    /// Drives the one-shot press bloom under whatever the user just tapped.
    @State var selectionBloomTrigger = 0

    @State var successBurstTrigger = 0

    @State var permissionRippleTrigger = 0

    @State var didCelebrateFirstWin = false

    @FocusState var focusedInputField: OnboardingInputField?

    /// Resolved per-view, as everywhere else in the app — there is no environment
    /// key for the motion policy.
    var motionPolicy: LifeBoardMotionPolicy {
        LifeBoardMotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        )
    }

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            OnboardingConcentricColorField(theme: currentVisualTheme)
                .ignoresSafeArea()

            contentLayer
                .allowsHitTesting(isWelcomeIntroActive == false)

            OnboardingConcentricTransitionLayer(
                step: viewModel.step,
                theme: currentVisualTheme,
                isEnabled: shouldShowWelcomeExperience == false && isKeyboardEditing == false
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()

            if isWelcomeIntroActive {
                OnboardingWelcomeCinematicOverlay(
                    phase: welcomeIntroPhase,
                    onContinue: continueFromWelcomeIntro,
                    onSkipDelay: skipWelcomeIntroDelay
                )
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.welcomeIntroOverlay)
            }

            if shouldShowGlobalSkipButton {
                globalSkipButton
                    .padding(.top, skipTopPadding)
                    .padding(.trailing, horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(2)
            }
        }
        // A warm bloom from the last tap, and a burst when setup lands. Both are
        // prewarmed Metal effects that fall back on their own under Reduce Motion,
        // Reduce Transparency, and Low Power.
        .lifeboardClayPressBloom(trigger: selectionBloomTrigger, tint: currentVisualTheme.accent)
        .lifeboardCompletionBurst(trigger: successBurstTrigger)
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomDock {
                bottomDock
            }
        }
        .interactiveDismissDisabled(true)
        .animation(pageMotionIsReduced ? nil : LifeBoardAnimation.panelIn, value: viewModel.step)
        .animation(pageMotionIsReduced ? nil : LifeBoardAnimation.panelIn, value: viewModel.successSummary != nil)
        .onAppear {
            feedbackController.prepare()
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.step) { _, _ in
            focusedInputField = nil
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.successSummary != nil) { _, isShowingSuccess in
            scheduleWelcomeIntroIfNeeded()
            guard isShowingSuccess, hasPlayedSuccess == false else { return }
            hasPlayedSuccess = true
            feedbackController.successSignature()
            guard motionPolicy.allowsSpatialMotion else { return }
            successBurstTrigger &+= 1
        }
        .task(id: welcomeIntroRunID) {
            await runWelcomeIntroSequenceIfNeeded()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedInputField = nil
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AppOnboardingAccessibilityID.flow)
    }

    /// Every selection in the flow routes through here so the tap feedback and
    /// the bloom stay in step, and so the haptic inherits the motion policy.
    func registerSelection() {
        feedbackController.selection()
        guard motionPolicy.allowsSpatialMotion else { return }
        selectionBloomTrigger &+= 1
    }
}
