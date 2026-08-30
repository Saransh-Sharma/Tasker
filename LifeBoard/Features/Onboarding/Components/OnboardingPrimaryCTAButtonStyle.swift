import SwiftUI

/// Onboarding's primary action.
///
/// It keeps its own accent, because onboarding sits over the dawn hero video
/// and needs to hold against moving imagery. What it does not keep is its own
/// *geometry* or its own material: it drew a 20-point rounded rectangle at 52
/// points tall with 18-point padding and a hand-rolled stroke, where
/// `DESIGN.md`'s `primary-action` is a pill at 48 points with `spacing.xl`
/// padding. A person meets this button before any other in the product, and it
/// was the one that looked least like the rest of it.
///
/// The file also imported `MLXLMCommon`, `Network`, `AVFoundation`, `CoreHaptics`
/// and `Combine` to declare a button style.
struct OnboardingPrimaryCTAButtonStyle: ButtonStyle {
    let disabled: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeboardFont(.button)
            .foregroundStyle(disabled ? OnboardingTheme.textSecondary : OnboardingTheme.accentOnPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 24)
            .lifeBoardClaySurface(
                .raised,
                cornerRadius: Radius.pill,
                fill: disabled ? OnboardingTheme.textSecondary.opacity(0.4) : OnboardingTheme.accent,
                isPressed: configuration.isPressed && disabled == false
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed && disabled == false && reduceMotion == false ? 0.98 : 1)
            .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: configuration.isPressed)
    }
}
