import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPrimaryCTAButtonStyle: ButtonStyle {
    let disabled: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return configuration.label
            .lifeboardFont(.button)
            .foregroundStyle(disabled ? OnboardingTheme.textSecondary : OnboardingTheme.accentOnPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 18)
            .background(
                disabled ? OnboardingTheme.textSecondary.opacity(0.4) : OnboardingTheme.accent,
                in: shape
            )
            .overlay(
                shape
                    .stroke(disabled ? .clear : OnboardingTheme.accentOnPrimary.opacity(0.18), lineWidth: 1)
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && disabled == false && reduceMotion == false ? 0.98 : 1)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
