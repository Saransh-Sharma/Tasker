import SwiftUI

/// Detail sheet shown when tapping an unlocked achievement badge.
public struct BadgeDetailSheet: View {

    private let achievement: AchievementDefinition
    private let unlockDate: Date?
    private let progressState: AchievementProgressState?

    public init(
        achievement: AchievementDefinition,
        unlockDate: Date? = nil,
        progressState: AchievementProgressState? = nil
    ) {
        self.achievement = achievement
        self.unlockDate = unlockDate
        self.progressState = progressState
    }

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            ZStack {
                Circle()
                    .fill(Color.lifeboard.accentPrimary.opacity(0.12))
                    .frame(width: 96, height: 96)

                Image(systemName: achievement.sfSymbol)
                    .font(.system(size: 40))
                    .foregroundColor(Color.lifeboard.accentPrimary)
            }

            Text(achievement.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text(achievement.description)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)

            if let progressState, progressState.unlocked == false {
                VStack(spacing: spacing.s8) {
                    Text("Progress: \(progressState.progressLabel)")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textSecondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.lifeboard.surfaceTertiary)
                            Capsule()
                                .fill(Color.lifeboard.accentPrimary)
                                .frame(width: geo.size.width * progressState.progressFraction)
                        }
                    }
                    .frame(height: 8)

                    Text("Next step: complete more tasks to unlock this badge.")
                        .font(.lifeboard(.caption2))
                        .foregroundColor(Color.lifeboard.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            if let date = unlockDate ?? progressState?.unlockDate {
                HStack(spacing: spacing.s4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.lifeboard.statusSuccess)

                    Text("Unlocked \(date, style: .date)")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(achievement.name). \(achievement.description). \((unlockDate != nil || progressState?.unlocked == true) ? "Unlocked" : "Locked")"
        )
    }
}
