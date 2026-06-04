import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFocusHeroCard: View {
    let task: TaskDefinition
    let projectName: String
    let xpAward: Int
    let isActive: Bool
    let startedAt: Date?
    let onPrimary: () -> Void
    let onBreakDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                EvaMascotView(placement: isActive ? .focusNextAction : .focusStart, size: .inline)
                    .accessibilityHidden(true)

                Text(OnboardingCopy.Focus.title)
                    .lifeboardFont(.title2)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .accessibilityIdentifier(AppOnboardingAccessibilityID.focusRoom)

                Spacer(minLength: 0)
            }

            Text(OnboardingCopy.Focus.subtitle)
                .lifeboardFont(.body)
                .foregroundStyle(OnboardingTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    pill(projectName, accent: OnboardingTheme.textSecondary)
                    pill(durationText, accent: OnboardingTheme.textSecondary)
                    pill("+\(xpAward) XP", accent: OnboardingTheme.textSecondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        pill(projectName, accent: OnboardingTheme.textSecondary)
                        pill(durationText, accent: OnboardingTheme.textSecondary)
                    }
                    pill("+\(xpAward) XP", accent: OnboardingTheme.textSecondary)
                }
            }

            Text(task.title)
                .lifeboardFont(.title1)
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            OnboardingFocusTimer(
                startedAt: startedAt,
                estimatedDuration: task.estimatedDuration,
                isActive: isActive
            )

            VStack(spacing: 10) {
                Button {
                    onPrimary()
                } label: {
                    Text(isActive ? OnboardingCopy.Focus.completeCTA : OnboardingCopy.Focus.startCTA)
                        .frame(maxWidth: .infinity)
                }
                .onboardingPrimaryButton(disabled: task.isComplete)
                .accessibilityIdentifier(isActive ? AppOnboardingAccessibilityID.markComplete : AppOnboardingAccessibilityID.focusPrimary)
                .accessibilityLabel(isActive ? OnboardingCopy.Focus.completeCTA : OnboardingCopy.Focus.startCTA)

                Button(OnboardingCopy.Focus.breakDownCTA) {
                    onBreakDown()
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.textSecondary)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.breakDown)
            }
        }
        .padding(26)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
        .shadow(color: OnboardingTheme.accent.opacity(0.1), radius: 28, y: 10)
    }

    var durationText: String {
        if let estimated = task.estimatedDuration {
            let minutes = max(1, Int(estimated / 60))
            return "\(minutes) min"
        }
        return "No timer"
    }

    func pill(_ title: String, accent: Color) -> some View {
        Text(title)
            .lifeboardFont(.caption2)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }
}
