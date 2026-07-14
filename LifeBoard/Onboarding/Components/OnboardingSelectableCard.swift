import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingSelectableCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String?
    let accentColor: Color?
    let accessibilityID: String
    let isSelected: Bool
    let allowsMultiline: Bool = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(
        title: String,
        subtitle: String,
        icon: String,
        colorHex: String? = nil,
        accentColor: Color? = nil,
        accessibilityID: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colorHex = colorHex
        self.accentColor = accentColor
        self.accessibilityID = accessibilityID
        self.isSelected = isSelected
        self.action = action
    }

    var resolvedAccent: Color {
        accentColor ?? Color(uiColor: UIColor(lifeboardHex: colorHex ?? "#293A18"))
    }

    var iconBackground: Color {
        OnboardingPastelPalette.color(for: title)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(iconBackground)
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .foregroundStyle(resolvedAccent)
                    }
                    Spacer()
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
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .lifeboardFont(.bodyEmphasis)
                        .foregroundStyle(OnboardingTheme.textPrimary)
                    Text(subtitle)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isSelected ? OnboardingTheme.accent : OnboardingTheme.borderSoft, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(OnboardingPressScaleButtonStyle())
        .animation(reduceMotion ? .none : .easeOut(duration: 0.18), value: isSelected)
        .accessibilityRepresentation {
            Button(action: action) {
                Text(title)
            }
            .accessibilityIdentifier(accessibilityID)
            .accessibilityLabel(title)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint(subtitle)
        }
    }
}
