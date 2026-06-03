import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingCompactHabitRail: View {
    let presentation: HabitBoardRowPresentation
    let evaState: OnboardingEvaPreparationState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Starter streak")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                Text("\(presentation.metrics.currentStreak)d current")
                    .lifeboardFont(.bodyEmphasis)
                    .foregroundStyle(OnboardingTheme.textPrimary)
            }
            Spacer()
            HabitBoardStripView(cells: Array(presentation.cells.suffix(7)), family: presentation.colorFamily, mode: .compact)
            if evaState.phase == .downloading {
                ProgressView(value: evaState.progress)
                    .frame(width: 44)
                    .tint(OnboardingTheme.accent)
            }
        }
        .padding(16)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
