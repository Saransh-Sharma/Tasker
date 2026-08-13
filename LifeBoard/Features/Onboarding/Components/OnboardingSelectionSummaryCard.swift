import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSelectionSummaryCard: View {
    let title: String
    let message: String
    let mascotPlacement: EvaMascotPlacement?

    init(title: String, message: String, mascotPlacement: EvaMascotPlacement? = nil) {
        self.title = title
        self.message = message
        self.mascotPlacement = mascotPlacement
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                if let mascotPlacement {
                    EvaMascotView(placement: mascotPlacement, size: .chip)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)

                Spacer(minLength: 0)
            }
            Text(message)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
