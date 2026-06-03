import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingPromptChecklistCard: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OnboardingPromptTheme.accent)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(index == 0 ? OnboardingPromptTheme.taskSoft : OnboardingPromptTheme.assistantSoft)
                        )

                    Text(item)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingPromptTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            reduceTransparency ? OnboardingPromptTheme.surfaceSolid : OnboardingPromptTheme.surfaceGlass,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(OnboardingPromptTheme.border(reduceTransparency: reduceTransparency), lineWidth: 1)
        )
    }
}
