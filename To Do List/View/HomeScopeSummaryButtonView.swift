import SwiftUI

struct HomeScopeSummaryButtonView: View {
    let viewLabel: String
    let accentColor: Color
    let hasActiveFilters: Bool

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            Text(viewLabel)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
                .lineLimit(1)
                .accessibilityIdentifier("home.focus.menu.button.title")

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.92))

            if hasActiveFilters {
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .frame(minHeight: 44)
        .background(
            Capsule(style: .continuous)
                .fill(Color.tasker.surfaceSecondary.opacity(0.9))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
        )
        .contentShape(Capsule(style: .continuous))
        .accessibilityIdentifier("home.focus.filterButton.nav")
    }
}
