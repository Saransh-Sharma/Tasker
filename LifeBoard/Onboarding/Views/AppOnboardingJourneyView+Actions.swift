import SwiftUI

extension AppOnboardingJourneyView {
    /// The single primary action per step.
    ///
    /// Every label is now "Continue" unless the button does something other than
    /// advance — the old flow named each one after its screen ("Choose goal",
    /// "Use areas", "Set habit"), which made the same gesture read as six
    /// different commitments.
    var floatingPrimaryAction: OnboardingFloatingNextAction? {
        switch viewModel.step {
        case .welcome:
            return nil

        case .intent:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Intent.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.canContinueGoal == false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromIntent()
            }

        case .lifeAreas:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.LifeAreas.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.useAreas,
                disabled: viewModel.canContinueLifeAreas == false || viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromLifeAreas() }
            }

        case .guide:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Guide.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromGuide()
            }

        case .dayShape:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.DayShape.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromDayShape() }
            }

        case .modules:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Modules.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromModules() }
            }

        case .firstWin:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.FirstWin.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.goFinishTask,
                disabled: viewModel.starterTask == nil || viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromFirstWin() }
            }

        case .permissions:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Permissions.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.permissionInFlight != nil,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromPermissions()
            }

        case .success:
            guard viewModel.successSummary != nil else { return nil }
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Success.goHomeCTA,
                systemImage: "house.fill",
                accessibilityIdentifier: AppOnboardingAccessibilityID.goHome,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.finishOnboarding()
                onDismissFlow()
            }
        }
    }
}
