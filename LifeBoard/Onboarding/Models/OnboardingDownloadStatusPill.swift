import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingDownloadStatusPill: View {
    let state: OnboardingEvaPreparationState
    let assistantName: String

    var normalizedProgress: Double {
        min(max(state.progress, 0), 1)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.phase == .downloading ? "arrow.down.circle.fill" : "clock.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingTheme.marigold)
                .accessibilityHidden(true)

            Text(statusText)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if state.phase == .downloading {
                ProgressView(value: normalizedProgress)
                    .tint(OnboardingTheme.marigold)
                    .frame(width: 76)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OnboardingTheme.surfaceMuted.opacity(0.86), in: Capsule())
        .overlay(
            Capsule()
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
        .accessibilityLabel(statusText)
    }

    var statusText: String {
        switch state.phase {
        case .downloading:
            return "\(assistantName) downloads in the background"
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
}
