import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension View {
    func onboardingConcentricPageMotion(step: OnboardingStep, reduceMotion: Bool) -> some View {
        self
            .id(step)
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .offset(x: 46, y: 22)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                        removal: .offset(x: -88, y: -18)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.92, anchor: .top))
                    )
            )
    }

    func onboardingPromptGlassPanel(cornerRadius: CGFloat) -> some View {
        modifier(OnboardingPromptGlassPanelModifier(cornerRadius: cornerRadius))
    }

    func onboardingPromptFooterMaterial() -> some View {
        modifier(OnboardingPromptFooterMaterialModifier())
    }

    /// Both of these hand-rolled their own fill, hairline, and drop shadow, which
    /// is how onboarding ended up with an elevation language nothing else in the
    /// app shared. They now defer to the canonical clay depths — one hero per
    /// screen at `.floating`, ordinary content at `.raised` — so onboarding
    /// inherits the same press physics and Reduce Transparency behaviour.
    func onboardingHeroPanel(cornerRadius: CGFloat) -> some View {
        lifeBoardClaySurface(.floating, cornerRadius: cornerRadius)
    }

    func onboardingGlassPanel(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        lifeBoardClaySurface(.raised, cornerRadius: cornerRadius)
    }

    func onboardingPrimaryButton(disabled: Bool = false) -> some View {
        self
            .disabled(disabled)
            .buttonStyle(OnboardingPrimaryCTAButtonStyle(disabled: disabled))
    }

    func onboardingSecondaryButtonStyle(accent: Color) -> some View {
        self
            .lifeboardFont(.buttonSmall)
            .foregroundStyle(accent)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}
