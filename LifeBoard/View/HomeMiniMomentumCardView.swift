import SwiftUI

struct HomeMiniMomentumCardView: View {
    let progress: HomeProgressState
    let completionRate: Double
    let reflectionEligible: Bool
    let animate: Bool
    let onTap: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private var completionPercent: Int {
        Int((completionRate * 100).rounded())
    }

    private var progressRatio: Double {
        min(1, max(0, completionRate))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                    Text("Daily rhythm")
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(1)
                        .accessibilityIdentifier("home.dailyRhythmLabel")

                    Spacer(minLength: spacing.s4)

                    Text("\(completionPercent)% done")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("home.completionRateLabel")

                    Label {
                        Text("\(progress.streakDays)d active")
                    } icon: {
                        Image(systemName: "leaf.fill")
                    }
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("home.activeDaysLabel")

                    if reflectionEligible {
                        Text("Reflection ready")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textTertiary)
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
            .lifeboardPremiumSurface(
                cornerRadius: corner.card,
                fillColor: Color.lifeboard.surfaceSecondary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.8),
                accentColor: Color.lifeboard.accentSecondary,
                level: .e2
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            reflectionEligible
            ? "Daily rhythm summary. \(completionPercent) percent done, \(progress.streakDays) active days, reflection available."
            : "Daily rhythm summary. \(completionPercent) percent done, \(progress.streakDays) active days."
        )
        .accessibilityHint("Opens analytics")
        .accessibilityIdentifier("home.momentumMiniCard")
    }
}
