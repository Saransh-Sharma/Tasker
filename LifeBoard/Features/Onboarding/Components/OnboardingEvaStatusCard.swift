import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingEvaStatusCard: View {
    let state: OnboardingEvaPreparationState
    let assistantName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                EvaMascotView(placement: mascotPlacement, size: .chip)
                    .accessibilityHidden(true)

                Text(title)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Spacer()
                if state.phase == .downloading {
                    Text("\(Int(state.progress * 100))%")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
            }
            Text(state.statusMessage ?? fallbackMessage)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
            if state.phase == .downloading {
                ProgressView(value: state.progress)
                    .tint(OnboardingTheme.accent)
            }
        }
        .padding(18)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }

    var title: String {
        switch state.phase {
        case .idle: return "\(assistantName) not started"
        case .waitingForCellularConsent: return "\(assistantName) waiting for approval"
        case .downloading: return "\(assistantName) is getting ready"
        case .ready: return "\(assistantName) is ready"
        case .deferred: return "\(assistantName) waiting for Wi-Fi"
        case .failed: return "\(assistantName) can finish later"
        }
    }

    var mascotPlacement: EvaMascotPlacement {
        switch state.phase {
        case .ready:
            return .onboardingSuccess
        case .failed:
            return .taskDeadlineRisk
        case .downloading:
            return .onboardingProcessing
        case .waitingForCellularConsent, .deferred:
            return .onboardingNotificationPermission
        case .idle:
            return .settingsIdentity
        }
    }

    var fallbackMessage: String {
        switch state.phase {
        case .idle:
            return "\(assistantName) will start preparing when you reach the build step."
        case .waitingForCellularConsent:
            return "Approve mobile data or wait for Wi-Fi."
        case .downloading:
            return "You can keep onboarding while \(assistantName) downloads."
        case .ready:
            return "You can ask \(assistantName) what matters next as soon as you land on Home."
        case .deferred:
            return "LifeBoard will keep your setup moving and resume \(assistantName) later."
        case .failed:
            return "The app is ready now. \(assistantName) can finish later from Home or Settings."
        }
    }
}
