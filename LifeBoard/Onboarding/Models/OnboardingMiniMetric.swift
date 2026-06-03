import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .lifeboardFont(.headline)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(title)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
