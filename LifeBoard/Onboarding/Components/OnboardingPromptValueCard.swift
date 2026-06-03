import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptValueCard: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    let snapshot: OnboardingWorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingPromptTheme.accent)
                .frame(width: 42, height: 42)
                .background(OnboardingPromptTheme.assistantSoft, in: Circle())

            Text("Start from what already fits.")
                .lifeboardFont(.title2)
                .foregroundStyle(OnboardingPromptTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("LifeBoard can reuse what is already working, keep the setup clean, and guide you into one small win without replaying the whole intro.")
                .lifeboardFont(.body)
                .foregroundStyle(OnboardingPromptTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(promptSummaryText)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingPromptTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            reduceTransparency ? OnboardingPromptTheme.surfaceSolid : OnboardingPromptTheme.assistantSoft.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OnboardingPromptTheme.border(reduceTransparency: reduceTransparency), lineWidth: 1)
        )
    }

    var promptSummaryText: String {
        let areas = String.localizedStringWithFormat(
            snapshot.customLifeAreaCount == 1
                ? String(localized: "onboarding.summary.area.singular")
                : String(localized: "onboarding.summary.area.plural"),
            snapshot.customLifeAreaCount
        )
        let projects = String.localizedStringWithFormat(
            snapshot.customProjectCount == 1
                ? String(localized: "onboarding.summary.project.singular")
                : String(localized: "onboarding.summary.project.plural"),
            snapshot.customProjectCount
        )
        let tasks = String.localizedStringWithFormat(
            snapshot.taskCount == 1
                ? String(localized: "onboarding.summary.task.singular")
                : String(localized: "onboarding.summary.task.plural"),
            snapshot.taskCount
        )
        return String.localizedStringWithFormat(
            String(localized: "onboarding.summary.alreadyInPlace"),
            areas,
            projects,
            tasks
        )
    }
}
