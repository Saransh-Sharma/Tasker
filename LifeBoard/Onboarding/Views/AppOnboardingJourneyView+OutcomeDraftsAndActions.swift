import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingJourneyView {
    var floatingPrimaryAction: OnboardingFloatingNextAction? {
        switch viewModel.step {
        case .welcome:
            return nil
        case .goal:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Goal.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.canContinueGoal == false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromGoal()
            }
        case .pain:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Pain.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.canContinuePain == false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromPain()
            }
        case .evaValue:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.EvaValue.cta,
                systemImage: "sparkles",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromEvaValue()
            }
        case .lifeAreas:
            return OnboardingFloatingNextAction(
                title: viewModel.isWorking ? "Preparing areas..." : OnboardingCopy.LifeAreas.cta,
                systemImage: "square.grid.2x2",
                accessibilityIdentifier: AppOnboardingAccessibilityID.useAreas,
                disabled: viewModel.canContinueLifeAreas == false || viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromLifeAreas() }
            }
        case .habitSetup:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.HabitSetup.cta,
                systemImage: "repeat.circle.fill",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.canContinueHabitSetup == false,
                showsProgress: false
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromHabitSetup() }
            }
        case .streakPreview:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Streak.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromStreakPreview()
            }
        case .evaStyle:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.EvaStyle.cta,
                systemImage: "checkmark",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromEvaStyle()
            }
        case .workBlockers:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.WorkBlockers.cta,
                systemImage: "checkmark",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromWorkBlockers()
            }
        case .weeklyOutcomes:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.WeeklyOutcomes.cta,
                systemImage: "target",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                commitOutcomeDrafts()
                viewModel.continueFromWeeklyOutcomes()
            }
        case .processing:
            guard viewModel.evaPreparationState.phase == .waitingForCellularConsent else { return nil }
            return OnboardingFloatingNextAction(
                title: "Use mobile data for \(viewModel.selectedMascotPersona.displayName)",
                systemImage: "antenna.radiowaves.left.and.right",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                Task { await viewModel.approveEvaCellularDownload() }
            }
        case .firstTask:
            return OnboardingFloatingNextAction(
                title: viewModel.canContinueToFocus ? OnboardingCopy.FirstTask.ctaReady : OnboardingCopy.FirstTask.ctaMissing,
                systemImage: "play.fill",
                accessibilityIdentifier: AppOnboardingAccessibilityID.goFinishTask,
                disabled: viewModel.canContinueToFocus == false || viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                viewModel.continueFromFirstWinReview()
            }
        case .habitCheckIn:
            return OnboardingFloatingNextAction(
                title: viewModel.starterHabit?.kind == .positive ? "Done" : "Stayed clean",
                systemImage: "checkmark",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: viewModel.isWorking,
                showsProgress: viewModel.isWorking
            ) {
                feedbackController.medium()
                Task { await viewModel.performStarterHabitPrimaryAction() }
            }
        case .homeDemo:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.HomeDemo.cta,
                systemImage: "chevron.forward",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                viewModel.continueFromHomeDemo()
            }
        case .calendarPermission:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Calendar.cta,
                systemImage: "calendar.badge.checkmark",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromCalendarPermission() }
            }
        case .notificationPermission:
            return OnboardingFloatingNextAction(
                title: OnboardingCopy.Notifications.cta,
                systemImage: "bell.badge.fill",
                accessibilityIdentifier: AppOnboardingAccessibilityID.nextButton,
                disabled: false,
                showsProgress: false
            ) {
                feedbackController.medium()
                Task { await viewModel.continueFromNotificationPermission() }
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
        case .focusRoom, .blocker, .projects, .habits:
            return nil
        }
    }

    func weeklyOutcomePlaceholder(at index: Int) -> String {
        switch index {
        case 0: return "Ship one important thing"
        case 1: return "Protect one personal routine"
        default: return "Stay ahead of one deadline"
        }
    }

    func ensureOutcomeDraftCapacity(_ index: Int) {
        while outcomeDrafts.count <= index {
            outcomeDrafts.append("")
        }
    }

    func updateOutcomeDraft(at index: Int, text: String) {
        ensureOutcomeDraftCapacity(index)
        outcomeDrafts[index] = text
    }

    func syncOutcomeDraftsFromModel() {
        let existing = Array(viewModel.evaProfileDraft.goals.prefix(3))
        if existing.isEmpty {
            outcomeDrafts = [""]
            visibleOutcomeCount = 1
        } else {
            outcomeDrafts = existing
            visibleOutcomeCount = min(max(existing.count, 1), 3)
        }
        ensureOutcomeDraftCapacity(visibleOutcomeCount - 1)
    }

    func commitOutcomeDrafts() {
        viewModel.replaceEvaGoals(Array(outcomeDrafts.prefix(3)))
    }

    func continueHomeDemoAfterDemoAction() {
        guard didShowHomeDemoCelebration == false else { return }
        didShowHomeDemoCelebration = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            viewModel.continueFromHomeDemo()
            didShowHomeDemoCelebration = false
        }
    }
}
