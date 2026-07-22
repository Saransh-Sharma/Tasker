import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFloatingNextButton: View {
    let action: OnboardingFloatingNextAction
    let theme: OnboardingStepVisualTheme

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action.action) {
            HStack(spacing: 12) {
                Text(action.title)
                    .lifeboardFont(.buttonSmall)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    Circle()
                        .fill(action.disabled ? OnboardingTheme.textSecondary.opacity(0.32) : theme.next)
                        .frame(width: 64, height: 64)
                        .shadow(color: theme.next.opacity(action.disabled ? 0 : 0.32), radius: 22, y: 10)

                    if action.showsProgress {
                        ProgressView()
                            .tint(theme.nextForeground)
                    } else {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(action.disabled ? OnboardingTheme.textSecondary : theme.nextForeground)
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(nextButtonChrome)
            .overlay(
                Capsule()
                    .stroke(theme.next.opacity(action.disabled ? 0.18 : 0.46), lineWidth: 1)
            )
        }
        .disabled(action.disabled)
        .buttonStyle(OnboardingPressScaleButtonStyle())
        .accessibilityIdentifier(action.accessibilityIdentifier ?? AppOnboardingAccessibilityID.nextButton)
        .accessibilityLabel(action.title)
        .accessibilityInputLabels([action.title])
        .opacity(action.disabled ? 0.62 : 1)
        .scaleEffect(action.disabled || reduceMotion ? 1 : 1.01)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: action.disabled)
    }

    @ViewBuilder
    var nextButtonChrome: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .lifeBoardSystemGlass(.regular, in: Capsule())
                .overlay(
                    Capsule()
                        .fill(OnboardingTheme.surfaceElevated.opacity(0.40))
                )
        } else {
            Capsule()
                .fill(.regularMaterial)
        }
    }
}
