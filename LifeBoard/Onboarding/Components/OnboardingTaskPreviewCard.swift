import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingTaskPreviewCard: View {
    let task: TaskDefinition
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(projectName.uppercased())
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
            Text(task.title)
                .lifeboardFont(.headline)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text("This is a real starter task, not a demo.")
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
