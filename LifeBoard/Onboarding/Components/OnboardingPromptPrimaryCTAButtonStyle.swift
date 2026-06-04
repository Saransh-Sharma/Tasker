import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptPrimaryCTAButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return configuration.label
            .lifeboardFont(.button)
            .foregroundStyle(OnboardingPromptTheme.accentOnPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 18)
            .background(configuration.isPressed ? OnboardingPromptTheme.accentPressed : OnboardingPromptTheme.accent, in: shape)
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: OnboardingPromptTheme.shadow.opacity(0.14), radius: 18, y: 8)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.98 : 1)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
