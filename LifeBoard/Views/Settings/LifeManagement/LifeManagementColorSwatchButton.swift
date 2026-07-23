import SwiftUI
import UIKit

struct LifeManagementColorSwatchButton: View {
    let title: String
    let color: Color?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            VStack(spacing: spacing.s8) {
                ZStack {
                    Circle()
                        .fill(color ?? Color.lifeboard.surfaceSecondary)
                        .frame(width: 26, height: 26)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color == nil ? Color.lifeboard.textSecondary : Color.lifeboard(.textInverse))
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.strokeHairline, lineWidth: isSelected ? 2 : 1)
                )

                Text(title)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 74)
            .frame(minHeight: 76)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.lifeboard.accentWash : Color.lifeboard.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.lifeboard.accentMuted : Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
