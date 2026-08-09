import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSuccessSummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
            Text(value)
                .lifeboardFont(.bodyEmphasis)
                .foregroundStyle(OnboardingTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
