import SwiftUI

struct HomeScopeSummaryButtonView: View {
    let dateText: String
    let summaryText: String

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: spacing.s2) {
                Text(dateText)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text(summaryText)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .frame(minHeight: 44)
        .taskerChromeSurface(
            cornerRadius: 22,
            accentColor: Color.tasker.accentSecondary,
            level: .e1
        )
        .contentShape(Capsule())
    }
}
