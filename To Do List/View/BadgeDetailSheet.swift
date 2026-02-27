import SwiftUI

/// Detail sheet shown when tapping an unlocked achievement badge.
public struct BadgeDetailSheet: View {

    let achievement: AchievementDefinition
    let unlockDate: Date?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            Spacer().frame(height: spacing.s8)

            ZStack {
                Circle()
                    .fill(Color.tasker.accentPrimary.opacity(0.12))
                    .frame(width: 96, height: 96)

                Image(systemName: achievement.sfSymbol)
                    .font(.system(size: 40))
                    .foregroundColor(Color.tasker.accentPrimary)
            }

            Text(achievement.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.tasker.textPrimary)

            Text(achievement.description)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)

            if let date = unlockDate {
                HStack(spacing: spacing.s4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.tasker.statusSuccess)

                    Text("Unlocked \(date, style: .date)")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.name). \(achievement.description). \(unlockDate != nil ? "Unlocked" : "Locked")")
    }
}
