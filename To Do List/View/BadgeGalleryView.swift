import SwiftUI

/// Horizontal scroll of achievement badges, showing unlocked and locked states.
public struct BadgeGalleryView: View {

    let unlockedKeys: Set<String>
    var onBadgeTap: ((String) -> Void)?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack {
                Text("Achievements")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
                Spacer()
                Text("\(unlockedKeys.count) / \(AchievementCatalog.all.count)")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    ForEach(AchievementCatalog.all, id: \.key) { achievement in
                        let isUnlocked = unlockedKeys.contains(achievement.key)
                        BadgeCardView(achievement: achievement, isUnlocked: isUnlocked)
                            .onTapGesture {
                                if isUnlocked {
                                    onBadgeTap?(achievement.key)
                                }
                            }
                    }
                }
            }
        }
    }
}

/// Individual badge card within the gallery.
struct BadgeCardView: View {

    let achievement: AchievementDefinition
    let isUnlocked: Bool

    private let cardSize: CGFloat = GamificationTokens.achievementCardIconSize

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isUnlocked ? Color.tasker.surfacePrimary : Color.tasker.surfaceTertiary)
                    .frame(width: cardSize, height: cardSize)
                    .shadow(
                        color: isUnlocked ? Color.tasker.accentPrimary.opacity(0.15) : .clear,
                        radius: 4
                    )

                if isUnlocked {
                    Image(systemName: achievement.sfSymbol)
                        .font(.system(size: 28))
                        .foregroundColor(Color.tasker.accentPrimary)
                } else {
                    ZStack {
                        Image(systemName: achievement.sfSymbol)
                            .font(.system(size: 28))
                            .foregroundColor(Color.tasker.textQuaternary)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.tasker.surfaceTertiary.opacity(GamificationTokens.lockedOverlayOpacity))
                    }
                }
            }

            Text(achievement.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isUnlocked ? Color.tasker.textPrimary : Color.tasker.textQuaternary)
                .lineLimit(1)
                .frame(width: cardSize)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.name). \(isUnlocked ? "Unlocked" : "Locked"). \(achievement.description)")
    }
}
