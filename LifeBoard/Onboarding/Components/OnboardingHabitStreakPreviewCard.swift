import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingHabitStreakPreviewCard: View {
    let presentation: HabitBoardRowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Label(presentation.title, systemImage: presentation.iconSymbolName)
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                Spacer()
                Text("\(presentation.metrics.currentStreak)d current")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
            }

            HabitBoardStripView(
                cells: presentation.cells,
                family: presentation.colorFamily,
                mode: .expanded
            )

            HStack(spacing: 12) {
                OnboardingMiniMetric(title: "Current", value: "\(presentation.metrics.currentStreak)d")
                OnboardingMiniMetric(title: "Best", value: "\(presentation.metrics.bestStreak)d")
                OnboardingMiniMetric(title: "Last 7", value: "\(presentation.metrics.weekCount)")
            }
        }
        .padding(20)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
