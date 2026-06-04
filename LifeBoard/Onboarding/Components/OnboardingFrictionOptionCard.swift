import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFrictionOptionCard: View {
    let title: String
    let symbolName: String
    let helperCopy: String
    let isSelected: Bool
    let layout: OnboardingFrictionSelectorLayout
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? OnboardingTheme.accent.opacity(0.14) : OnboardingTheme.surfaceElevated.opacity(0.92))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: symbolName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
                                .contentTransition(.symbolEffect(.replace))
                        )

                    Text(title)
                        .lifeboardFont(.buttonSmall)
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(layout == .twoColumn ? 2 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .fill(isSelected ? OnboardingTheme.accent : .clear)
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? OnboardingTheme.accent : OnboardingTheme.border, lineWidth: 1.5)
                            )
                            .frame(width: 22, height: 22)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(OnboardingTheme.accentOnPrimary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                if isSelected {
                    Text(helperCopy)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AppOnboardingAccessibilityID.frictionHelper)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, layout == .stacked ? 14 : 16)
            .padding(.vertical, layout == .stacked ? 14 : 16)
            .frame(
                maxWidth: .infinity,
                minHeight: layout == .twoColumn ? 86 : 74,
                alignment: .leading
            )
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(
                color: isSelected ? OnboardingTheme.accent.opacity(reduceMotion ? 0.0 : 0.10) : .clear,
                radius: isSelected ? 14 : 0,
                x: 0,
                y: isSelected ? 8 : 0
            )
        }
        .buttonStyle(OnboardingPressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(reduceMotion ? .none : .easeOut(duration: 0.22), value: isSelected)
    }

    @ViewBuilder
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(OnboardingTheme.surfaceMuted)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(OnboardingTheme.accent.opacity(0.10))
                }
            }
    }

    @ViewBuilder
    var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(isSelected ? OnboardingTheme.accent.opacity(0.20) : OnboardingTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
    }
}
