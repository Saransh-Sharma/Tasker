import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct HomeOnboardingGuidanceBanner: View {
    let state: HomeOnboardingGuidanceModel.State
    var onStart: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            EvaMascotView(placement: .featureDiscovery, size: .chip)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.title)
                    .lifeboardFont(.headline)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Text(state.message)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                if state.isInvitation {
                    HStack(spacing: 12) {
                        Button("Build my Life Map", action: onStart)
                            .lifeboardFont(.caption1)
                            .accessibilityIdentifier("home.onboarding.lifeMap.start")
                        Button("Not now", action: onDismiss)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .accessibilityIdentifier("home.onboarding.lifeMap.dismiss")
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .accessibilityIdentifier("home.onboarding.guide")
    }
}
