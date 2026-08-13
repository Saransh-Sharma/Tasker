import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSuccessSummaryCard: View {
    let areaNames: [String]
    let projectNames: [String]
    let habitTitles: [String]
    let completedTaskTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What’s now in place")
                .lifeboardFont(.headline)
                .foregroundStyle(OnboardingTheme.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                OnboardingSuccessSummaryRow(
                    label: "Areas",
                    value: onboardingNaturalLanguageList(areaNames, fallback: "Your starting areas")
                )

                Divider()
                    .overlay(OnboardingTheme.borderSoft)
                    .padding(.vertical, 16)

                OnboardingSuccessSummaryRow(
                    label: "Projects",
                    value: onboardingNaturalLanguageList(projectNames, fallback: "Your starting projects")
                )

                Divider()
                    .overlay(OnboardingTheme.borderSoft)
                    .padding(.vertical, 16)

                if habitTitles.isEmpty == false {
                    OnboardingSuccessSummaryRow(
                        label: "Habits",
                        value: onboardingNaturalLanguageList(Array(habitTitles.prefix(2)), fallback: "Your starter habits")
                    )

                    Divider()
                        .overlay(OnboardingTheme.borderSoft)
                        .padding(.vertical, 16)
                }

                OnboardingSuccessSummaryRow(
                    label: "First task",
                    value: completedTaskTitle ?? "Your first task"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(OnboardingTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingTheme.borderSoft, lineWidth: 1)
        )
    }
}
