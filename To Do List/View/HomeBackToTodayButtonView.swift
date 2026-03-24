import SwiftUI

struct HomeBackToTodayButtonView: View {
    enum DisplayStyle {
        case label
        case iconOnly
    }

    let displayStyle: DisplayStyle
    let action: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            labelContent
        }
        .font(.tasker(.caption1))
        .foregroundStyle(Color.tasker.textPrimary)
        .taskerChromeSurface(
            cornerRadius: 20,
            accentColor: Color.tasker.accentPrimary,
            level: .e1
        )
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel("Back to Today")
        .accessibilityHint("Returns to the default Today view")
        .accessibilityIdentifier("home.backToToday.button")
    }

    @ViewBuilder
    private var labelContent: some View {
        switch displayStyle {
        case .label:
            Label("Back to Today", systemImage: "arrow.uturn.backward.circle")
                .lineLimit(1)
                .minimumScaleFactor(0.95)
                .padding(.horizontal, spacing.s12)
                .frame(minHeight: 44)
                .fixedSize(horizontal: true, vertical: true)
        case .iconOnly:
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
        }
    }
}
