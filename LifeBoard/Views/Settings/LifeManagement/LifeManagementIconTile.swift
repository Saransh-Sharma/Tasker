import SwiftUI
import UIKit

struct LifeManagementIconTile: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            VStack(spacing: spacing.s8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.lifeboard.accentWash : Color.lifeboard.surfaceSecondary)
                    .frame(height: 46)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary)
                    }

                Text(title)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(spacing.s8)
            .frame(minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                    .fill(Color.lifeboard.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.lifeboard.accentPrimary.opacity(0.34) : Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
