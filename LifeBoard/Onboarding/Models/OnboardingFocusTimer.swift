import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFocusTimer: View {
    let startedAt: Date?
    let estimatedDuration: TimeInterval?
    let isActive: Bool

    var body: some View {
        Group {
            if isActive {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    timerBody(valueText: formatted(max(0, Int(timeline.date.timeIntervalSince(startedAt ?? timeline.date)))))
                }
            } else if let startedAt {
                timerBody(valueText: formatted(max(0, Int(Date().timeIntervalSince(startedAt)))))
            } else {
                timerBody(valueText: estimateText)
            }
        }
    }

    func timerBody(valueText: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(OnboardingTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(labelText)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                Text(valueText)
                    .lifeboardFont(.title2)
                    .foregroundStyle(OnboardingTheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .background(OnboardingTheme.surfaceMuted.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var estimateText: String {
        guard let estimatedDuration, estimatedDuration > 0 else { return "No estimate" }
        let minutes = max(1, Int(estimatedDuration / 60))
        return "\(minutes) min"
    }

    var labelText: String {
        if isActive {
            return "Time in focus"
        }
        if startedAt != nil {
            return "Focused for"
        }
        return "Suggested focus"
    }

    func formatted(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
