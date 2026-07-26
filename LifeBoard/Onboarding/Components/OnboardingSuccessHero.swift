import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSuccessHero: View {
    @Environment(\.lifeboardLayoutClass) var layoutClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var pulse = false
    @State var haloScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.success.opacity(pulse ? 0.18 : 0.12))
                    .frame(width: mascotHaloSize, height: mascotHaloSize)
                EvaMascotView(placement: .onboardingSuccess, size: .custom(mascotSize))
                    .accessibilityHidden(true)
            }
            .scaleEffect(haloScale)

            Text(OnboardingCopy.Success.title)
                .lifeboardFont(.display)
                .foregroundStyle(OnboardingTheme.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(22)
        .lifeBoardClaySurface(.floating)
        .onAppear {
            guard reduceMotion == false else { return }
            // One gentle settle-in, then a soft two-beat halo pulse — a single
            // celebratory moment, never a looping reward. The settle uses the
            // shared completion spring: the one place in the system where an
            // overshoot is earned.
            haloScale = 0.86
            withAnimation(LifeBoardInteractionMotion.completion(reduceMotion: reduceMotion)) {
                haloScale = 1
            }
            withAnimation(LifeBoardAnimation.celebration.repeatCount(2, autoreverses: true)) {
                pulse = true
            }
        }
    }

    var mascotSize: CGFloat {
        layoutClass.isPad ? 190 : 152
    }

    var mascotHaloSize: CGFloat {
        layoutClass.isPad ? 216 : 176
    }
}
