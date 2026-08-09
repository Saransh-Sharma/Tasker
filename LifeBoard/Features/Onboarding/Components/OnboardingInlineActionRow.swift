import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingInlineActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let mascotPlacement: EvaMascotPlacement

    var body: some View {
        HStack(spacing: 12) {
            EvaMascotView(placement: mascotPlacement, size: .chip)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Text(subtitle)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: systemImage)
                .foregroundStyle(OnboardingTheme.marigold)
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
