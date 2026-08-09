import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSectionHeader: View {
    let title: String
    /// Optional on purpose. Several steps say everything they need in the title;
    /// a supporting line that only restates it is noise, not guidance.
    var subtitle: String? = nil
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .lifeboardFont(.title1)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.goldInk)
                }
            }

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .lifeboardFont(.body)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
