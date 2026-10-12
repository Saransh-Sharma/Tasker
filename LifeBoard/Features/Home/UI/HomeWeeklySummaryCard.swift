import SwiftUI

struct HomeWeeklySummaryCard: View {
    @Environment(\.lifeboardTokens) private var tokens
    let summary: HomeWeeklySummary?
    let isLoading: Bool
    let errorMessage: String?
    let onPrimaryAction: () -> Void
    let onRetryAction: () -> Void

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }

    private var titleText: String {
        guard let summary else { return String(localized: "This week") }
        switch summary.plannerPresentation {
        case .thisWeek:
            return String(localized: "This week")
        case .upcomingWeek:
            return String(localized: "Next week")
        }
    }

    private func actionTitle(for summary: HomeWeeklySummary) -> String {
        switch summary.ctaState {
        case .planThisWeek, .planUpcomingWeek:
            return String(localized: "Plan week")
        case .reviewWeek:
            return String(localized: "Review week")
        }
    }

    private func statusText(for summary: HomeWeeklySummary) -> String {
        switch summary.ctaState {
        case .reviewWeek:
            return String(localized: "Ready to review")
        case .planThisWeek, .planUpcomingWeek:
            if summary.outcomeCount == 0 && summary.thisWeekTaskCount == 0 {
                return String(localized: "Not planned")
            }
            let outcomes = summary.outcomeCount, tasks = summary.thisWeekTaskCount
            let outcomeText = outcomes == 1 ? String(localized: "1 outcome") : String(localized: "\(outcomes) outcomes")
            let taskText = tasks == 1 ? String(localized: "1 task") : String(localized: "\(tasks) tasks")
            return "\(outcomeText) · \(taskText)"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(titleText)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                if isLoading {
                    Text("Loading…")
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
                    Text("Plan week")
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
                Button("Try again", action: onRetryAction)
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
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
