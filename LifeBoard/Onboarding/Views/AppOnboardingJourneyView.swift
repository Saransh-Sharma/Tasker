import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingJourneyView: View {


    @ObservedObject var viewModel: OnboardingFlowModel

    let feedbackController: OnboardingFeedbackController

    let onOpenCustomTaskComposer: (AddTaskPrefillTemplate) -> Bool

    let onOpenCustomHabitComposer: (AddHabitPrefillTemplate) -> Bool

    let onEditTask: (TaskDefinition) -> Bool

    let onDismissFlow: () -> Void

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var hasPlayedSuccess = false

    @State var welcomeIntroPhase: WelcomeIntroPhase = .introVideoOnly

    @State var hasCompletedWelcomeIntro = false

    @State var hasSkippedWelcomeIntroDelay = false

    @State var welcomeIntroRunID = UUID()

    @State var customWorkingStyle = ""

    @State var customWorkBlocker = ""

    @State var didShowHomeDemoCelebration = false

    @State var outcomeDrafts = [""]

    @State var visibleOutcomeCount = 1

    @FocusState var focusedInputField: OnboardingInputField?

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
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomDock {
                bottomDock
            }
        }
        .sheet(isPresented: $viewModel.breakdownSheetPresented) {
            breakdownSheet
        }
        .interactiveDismissDisabled(true)
        .animation(pageMotionIsReduced ? .none : .easeOut(duration: 0.22), value: viewModel.step)
        .animation(pageMotionIsReduced ? .none : .easeOut(duration: 0.22), value: viewModel.successSummary != nil)
        .onAppear {
            feedbackController.prepare()
            if viewModel.step == .weeklyOutcomes {
                syncOutcomeDraftsFromModel()
            }
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.step) { _, step in
            focusedInputField = nil
            if step == .weeklyOutcomes {
                syncOutcomeDraftsFromModel()
            }
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.successSummary != nil) { _, _ in
            scheduleWelcomeIntroIfNeeded()
        }
        .onChange(of: viewModel.successSummary != nil) { _, isShowingSuccess in
            guard isShowingSuccess, hasPlayedSuccess == false else { return }
            hasPlayedSuccess = true
            feedbackController.successSignature()
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
}
