import SwiftUI

struct HomeWeeklySummaryCard: View {
    let summary: HomeWeeklySummary?
    let onPrimaryAction: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Group {
            if let summary {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    HStack(alignment: .top, spacing: spacing.s12) {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            Text("WEEKLY OPERATING LAYER")
                                .font(.tasker(.eyebrow))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .tracking(0.8)

                            Text(summary.ctaState == .reviewWeek ? "Review this week while it's still fresh." : "Plan this week before the backlog plans it for you.")
                                .font(.tasker(.title2))
                                .foregroundStyle(Color.tasker.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: spacing.s8) {
                                TaskerStatusPill(
                                    text: WeeklyCopy.weekRangeText(for: summary.weekStartDate),
                                    systemImage: "calendar",
                                    tone: .quiet
                                )
                                TaskerStatusPill(
                                    text: summary.ctaState == .reviewWeek ? "Review this week" : "Plan this week",
                                    systemImage: summary.ctaState == .reviewWeek ? "checklist" : "scope",
                                    tone: summary.ctaState == .reviewWeek ? .accent : .quiet
                                )
                            }
                        }

                        Spacer(minLength: spacing.s8)

                        Button(summary.ctaState == .reviewWeek ? "Review this week" : "Plan this week") {
                            onPrimaryAction()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(summary.ctaState == .reviewWeek ? Color.tasker.accentSecondary : Color.tasker.accentPrimary)
                    }

                    HStack(spacing: spacing.s8) {
                        summaryMetric(value: "\(summary.outcomeCount)", label: "Outcomes")
                        summaryMetric(value: "\(summary.thisWeekTaskCount)", label: "This Week")
                        summaryMetric(value: "\(summary.completedThisWeekTaskCount)", label: "Done")
                    }

                    if summary.overCapacityCount > 0 {
                        WeeklyInlineMessage(
                            text: WeeklyCopy.overloadHelper(count: summary.overCapacityCount),
                            tone: .warning
                        )
                    } else {
                        Text(summary.reviewCompleted
                             ? "This week already has a completed review."
                             : "A smaller, clearer weekly plan is easier to trust and easier to finish.")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(spacing.cardPadding)
                .taskerPremiumSurface(
                    cornerRadius: 24,
                    fillColor: Color.tasker.surfacePrimary,
                    strokeColor: Color.tasker.strokeHairline.opacity(0.82),
                    accentColor: summary.ctaState == .reviewWeek ? Color.tasker.accentSecondary : Color.tasker.accentPrimary,
                    level: .e2
                )
            }
        }
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.accentPrimary)
            Text(label)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
