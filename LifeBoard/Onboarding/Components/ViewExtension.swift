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

    func onboardingHeroPanel(cornerRadius: CGFloat) -> some View {
        background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft.opacity(0.95), lineWidth: 1)
            )
            .shadow(color: LBColorTokens.elevationShadow.opacity(0.5), radius: 18, y: 8)
    }

    func onboardingGlassPanel(cornerRadius: CGFloat, shadowOpacity: Double = 0.06) -> some View {
        background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
            )
            .shadow(color: LBColorTokens.elevationShadow.opacity(shadowOpacity * 10), radius: 14, y: 6)
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
