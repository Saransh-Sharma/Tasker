import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingConcentricTransitionLayer: View {
    let step: OnboardingStep
    let theme: OnboardingStepVisualTheme
    let isEnabled: Bool

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @State var expansion: CGFloat = 0
    @State var isAnimating = false
    @State var pulseColor: Color = .clear

    var body: some View {
        GeometryReader { proxy in
            if isAnimating && isEnabled && reduceMotion == false {
                let diameter = max(proxy.size.width, proxy.size.height) * 2.45 * expansion
                transitionPulse(diameter: diameter)
                    .frame(width: diameter, height: diameter)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 74)
                    .opacity(1 - Double(max(0, expansion - 0.72)) / 0.28)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: step) { _, _ in
            guard isEnabled, reduceMotion == false else { return }
            pulseColor = theme.backdrop
            expansion = 0.02
            isAnimating = true
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.62)) {
                expansion = 1
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 680_000_000)
                isAnimating = false
                expansion = 0
            }
        }
    }

    @ViewBuilder
    func transitionPulse(diameter: CGFloat) -> some View {
        if #available(iOS 26.0, *), reduceTransparency == false {
            Circle()
                .fill(pulseColor.opacity(pulseFillOpacity))
                .glassEffect(.regular, in: Circle())
                .overlay(
                    Circle()
                        .fill(theme.accent.opacity(0.22))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(colorSchemeContrast == .increased ? 0.34 : 0.22), lineWidth: 1)
                )
        } else {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.accent.opacity(0.42),
                            pulseColor.opacity(pulseFillOpacity),
                            Color.white.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(1, diameter / 2)
                    )
                )
        }
    }

    var pulseFillOpacity: Double {
        if reduceTransparency { return 0.90 }
        return colorSchemeContrast == .increased ? 0.84 : 0.78
    }
}
