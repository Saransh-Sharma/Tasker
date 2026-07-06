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

            Text(OnboardingCopy.Success.subtitle)
                .lifeboardFont(.body)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(22)
        .onboardingHeroPanel(cornerRadius: 32)
        .onAppear {
            guard reduceMotion == false else { return }
            // One gentle settle-in, then a soft two-beat halo pulse — a single
            // celebratory moment, never a looping reward.
            haloScale = 0.86
            withAnimation(.spring(duration: 0.5, bounce: 0.36)) {
                haloScale = 1
            }
            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
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
