import SwiftUI

struct HomeBackToTodayButtonView: View {
    let action: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(spacing: spacing.s4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))

                Text("Today")
                    .font(.tasker(.caption1).weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundStyle(Color.tasker.textSecondary)
            .padding(.horizontal, spacing.s12)
            .frame(minHeight: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel("Back to Today")
        .accessibilityHint("Returns to the default Today view")
        .accessibilityIdentifier("home.backToToday.button")
    }
}
