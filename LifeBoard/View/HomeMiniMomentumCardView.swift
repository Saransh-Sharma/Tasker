import SwiftUI

struct HomeMiniMomentumCardView: View {
    let progress: HomeProgressState
    let completionRate: Double
    let reflectionEligible: Bool
    let animate: Bool
    let onTap: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var completionPercent: Int {
        Int((completionRate * 100).rounded())
    }

    private var progressRatio: Double {
        let denominator = max(1, progress.todayTargetXP)
        return min(1, Double(progress.earnedXP) / Double(denominator))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                    Text("\(progress.earnedXP)/\(progress.todayTargetXP) XP")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("home.dailyScoreLabel")

                    Spacer(minLength: spacing.s4)

                    Text("\(completionPercent)% done")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("home.completionRateLabel")

                    Label {
                        Text("\(progress.streakDays)d")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.tasker(.caption1))
                    .foregroundStyle(progress.isStreakSafeToday ? Color.tasker.textSecondary : Color.tasker.statusWarning)
                    .lineLimit(1)
                    .accessibilityIdentifier("home.streakLabel")

                    if reflectionEligible {
                        Text("Reflection ready")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textTertiary)
                            .lineLimit(1)
                    }
                }

                HomeMiniMomentumProgressBar(
                    progress: progressRatio,
                    isStreakSafeToday: progress.isStreakSafeToday,
                    animate: animate
                )
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .taskerPremiumSurface(
                cornerRadius: corner.card,
                fillColor: Color.tasker.surfaceSecondary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.8),
                accentColor: Color.tasker.accentSecondary,
                level: .e2
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            reflectionEligible
            ? "Momentum summary. \(progress.earnedXP) of \(progress.todayTargetXP) XP, \(completionPercent) percent done, \(progress.streakDays) day streak, reflection available."
            : "Momentum summary. \(progress.earnedXP) of \(progress.todayTargetXP) XP, \(completionPercent) percent done, \(progress.streakDays) day streak."
        )
        .accessibilityHint("Opens analytics")
        .accessibilityIdentifier("home.momentumMiniCard")
    }
}
