import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingChecklistRow: View {
    let title: String
    let symbolName: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.marigold : OnboardingTheme.textSecondary)
                Text(title)
                    .lifeboardFont(.body)
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OnboardingTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? OnboardingTheme.marigold : OnboardingTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
