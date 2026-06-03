import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct HomeOnboardingGuidanceBanner: View {
    let state: HomeOnboardingGuidanceModel.State

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
            }
            Spacer()
        }
        .padding(16)
        .background(OnboardingTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.border, lineWidth: 1)
        )
        .accessibilityIdentifier("home.onboarding.guide")
    }
}
