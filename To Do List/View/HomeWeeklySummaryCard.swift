import SwiftUI

struct HomeWeeklySummaryCard: View {
    let summary: HomeWeeklySummary?
    let onPrimaryAction: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Group {
            if let summary {
                VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Weekly operating layer")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)

                        Text(summary.ctaState == .reviewWeek ? "Close the week cleanly." : "Shape the week before it shapes you.")
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: spacing.s8)

                    Button(summary.ctaState == .reviewWeek ? "Review week" : "Plan week") {
                        onPrimaryAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(summary.ctaState == .reviewWeek ? Color.tasker.accentSecondary : Color.tasker.accentPrimary)
                }

                HStack(spacing: spacing.s8) {
                    metricChip(
                        value: "\(summary.outcomeCount)",
                        label: "Outcomes",
                        accent: Color.tasker.accentSecondary
                    )
                    metricChip(
                        value: "\(summary.thisWeekTaskCount)",
                        label: "This Week",
                        accent: Color.tasker.accentSecondary
                    )
                    metricChip(
                        value: "\(summary.completedThisWeekTaskCount)",
                        label: "Finished",
                        accent: Color.tasker.accentSecondary
                    )

                    if summary.overCapacityCount > 0 {
                        metricChip(
                            value: "+\(summary.overCapacityCount)",
                            label: "Over capacity",
                            accent: Color.tasker.statusWarning
                        )
                    }
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s12)
                .taskerPremiumSurface(
                    cornerRadius: corner.card,
                    fillColor: Color.tasker.surfaceSecondary,
                    strokeColor: Color.tasker.strokeHairline.opacity(0.82),
                    accentColor: summary.ctaState == .reviewWeek ? Color.tasker.accentSecondary : Color.tasker.accentPrimary,
                    level: .e2
                )
            }
        }
    }

    @MainActor
    private func metricChip(value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(accent)
            Text(label)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfaceTertiary.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: corner.chip, style: .continuous))
    }
}
