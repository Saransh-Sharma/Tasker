import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingTrustRow: View {
    let items: [(String, String)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 6) {
                        Image(systemName: item.0)
                        Text(item.1)
                    }
                    .lifeboardFont(.caption2)
                    .foregroundStyle(OnboardingTheme.textSecondary)

                    if index < items.count - 1 {
                        Text("·")
                            .lifeboardFont(.caption2)
                            .foregroundStyle(OnboardingTheme.textTertiary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    pill(icon: item.0, title: item.1)
                }
            }
        }
    }

    func pill(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .lifeboardFont(.caption2)
        .foregroundStyle(OnboardingTheme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OnboardingTheme.surfaceElevated.opacity(0.88), in: Capsule())
        .overlay(
            Capsule()
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
