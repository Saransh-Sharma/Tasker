import SwiftUI

struct HomeWeeklySummaryCard: View {
    let summary: HomeWeeklySummary?
    let onPrimaryAction: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var titleText: String { "This week" }

    private func actionTitle(for summary: HomeWeeklySummary) -> String {
        switch summary.ctaState {
        case .planThisWeek, .planUpcomingWeek:
            return "Plan"
        case .reviewWeek:
            return "Review"
        }
    }

    private func statusText(for summary: HomeWeeklySummary) -> String {
        switch summary.ctaState {
        case .reviewWeek:
            return "Ready to review"
        case .planThisWeek, .planUpcomingWeek:
            if summary.outcomeCount == 0 && summary.thisWeekTaskCount == 0 {
                return "Not planned"
            }
            return "\(summary.outcomeCount) outcomes · \(summary.thisWeekTaskCount) tasks"
        }
    }

    var body: some View {
        Group {
            if let summary {
                HStack(alignment: .center, spacing: spacing.s12) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(titleText)
                            .font(.tasker(.callout).weight(.semibold))
                            .foregroundStyle(Color.tasker.textPrimary)

                        Text(statusText(for: summary))
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: spacing.s8)

                    Button(actionTitle(for: summary)) {
                        onPrimaryAction()
                    }
                    .buttonStyle(.plain)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                }
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s12)
                .background(Color.tasker.surfaceSecondary.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
