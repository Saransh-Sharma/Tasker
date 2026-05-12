import SwiftUI

struct HomeMomentumSummaryCard: View {
    let progress: HomeProgressState
    let completionRate: Double
    let reflectionEligible: Bool
    let momentumGuidanceText: String
    let animate: Bool
    var onChartTap: (() -> Void)? = nil
    var onOpenReflection: (() -> Void)? = nil

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private var progressRatio: Double {
        min(1, Double(progress.earnedXP) / Double(safeTodayTargetXP))
    }

    private var safeTodayTargetXP: Int {
        max(1, progress.todayTargetXP)
    }

    private var completionPercent: Int {
        Int((completionRate * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s12) {
                NavPieChart(
                    score: progress.earnedXP,
                    maxScore: safeTodayTargetXP,
                    accessibilityContainerID: "home.navXpPieChart",
                    accessibilityButtonID: "home.navXpPieChart.button",
                    onTap: { onChartTap?() }
                )
                .padding(4)
                .lifeboardChromeSurface(
                    cornerRadius: 26,
                    accentColor: Color.lifeboard.accentSecondary,
                    level: .e1
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.earnedXP)/\(safeTodayTargetXP) XP")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .accessibilityIdentifier("home.dailyScoreLabel")
                        .lineLimit(1)

                    HStack(spacing: spacing.s8) {
                        Text("\(completionPercent)% complete")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .accessibilityIdentifier("home.completionRateLabel")
                            .lineLimit(1)

                        streakIndicator
                            .accessibilityIdentifier("home.streakLabel")
                    }
                }

                Spacer(minLength: spacing.s4)

                if reflectionEligible, let onOpenReflection {
                    Button("Reflection", action: onOpenReflection)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.lifeboard.accentPrimary)
                        .accessibilityIdentifier("home.reflectionChip")
                }
            }

            HomeMomentumProgressBar(
                progress: progressRatio,
                colors: progressGradientColors,
                animate: animate
            )

            Text(momentumGuidanceText)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .lifeboardPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.lifeboard.surfaceSecondary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.8),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e2
        )
    }

    private var progressGradientColors: [Color] {
        if progress.isStreakSafeToday {
            return [Color.lifeboard.accentPrimary, Color.lifeboard.accentSecondary]
        }
        return [Color.lifeboard.statusWarning, Color.lifeboard.statusWarning.opacity(0.7)]
    }

    private var streakIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(progress.isStreakSafeToday ? Color.lifeboard.accentSecondary : Color.lifeboard.statusWarning)
                .symbolEffect(
                    .pulse,
                    options: .repeating.speed(0.5),
                    isActive: !progress.isStreakSafeToday && animate
                )

            Text("\(progress.streakDays)d")
                .font(.lifeboard(.caption1))
                .fontWeight(.medium)
                .foregroundStyle(progress.isStreakSafeToday ? Color.lifeboard.textSecondary : Color.lifeboard.statusWarning)
        }
    }
}
