import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingDownloadStatusStrip: View {
    let state: OnboardingEvaPreparationState
    let assistantName: String

    var normalizedProgress: Double {
        min(max(state.progress, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(OnboardingTheme.marigold)
                Text(statusTitle)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Spacer()
                if state.phase == .downloading {
                    Text("\(Int(normalizedProgress * 100))%")
                        .lifeboardFont(.caption2)
                        .foregroundStyle(OnboardingTheme.marigold)
                }
            }

            if state.phase == .downloading {
                ProgressView(value: normalizedProgress)
                    .tint(OnboardingTheme.marigold)
                Text(downloadDetail)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(OnboardingTheme.textTertiary)
            }
        }
        .padding(12)
        .background(OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
        .accessibilityLabel(statusTitle)
    }

    var statusTitle: String {
        switch state.phase {
        case .downloading:
            return "\(assistantName) is downloading in the background"
        case .waitingForCellularConsent:
            return "\(assistantName) is waiting for Wi-Fi"
        case .deferred:
            return "\(assistantName) will finish later"
        case .ready:
            return "\(assistantName) is ready"
        case .failed:
            return "\(assistantName) can finish later"
        case .idle:
            return "\(assistantName) will start soon"
        }
    }

    var statusIcon: String {
        state.phase == .downloading ? "arrow.down.circle.fill" : "clock.badge.checkmark"
    }

    var downloadDetail: String {
        let remaining = max(1, Int((1 - normalizedProgress) * 6))
        let speed = max(0.4, 2.8 * max(normalizedProgress, 0.18))
        return "About \(remaining) min left • \(String(format: "%.1f", speed)) MB/s"
    }
}
