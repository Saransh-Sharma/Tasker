import SwiftUI

struct HomeWeeklySummaryCard: View {
    let summary: HomeWeeklySummary?
    let isLoading: Bool
    let errorMessage: String?
    let onPrimaryAction: () -> Void
    let onRetryAction: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    private var titleText: String {
        guard let summary else { return "Weekly planning" }
        switch summary.plannerPresentation {
        case .thisWeek:
            return "This week"
        case .upcomingWeek:
            return "Next week"
        }
    }

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
        HStack(alignment: .center, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(titleText)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                if isLoading {
                    Text("Loading weekly summary…")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                } else if let errorMessage, summary == nil {
                    Text(errorMessage)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.statusWarning)
                        .lineLimit(2)
                } else if let summary {
                    Text(statusText(for: summary))
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("Start your weekly plan.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: spacing.s8)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if errorMessage != nil, summary == nil {
                Button("Retry", action: onRetryAction)
                    .buttonStyle(.plain)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
            } else if let summary {
                Button(actionTitle(for: summary), action: onPrimaryAction)
                    .buttonStyle(.plain)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
            }
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .background(Color.lifeboard.surfaceSecondary.opacity(0.28))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
