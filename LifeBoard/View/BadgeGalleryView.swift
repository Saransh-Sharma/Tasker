import SwiftUI

/// Horizontal scroll of achievement badges, showing unlocked and locked states.
public struct BadgeGalleryView: View {

    let achievements: [AchievementDefinition]
    let unlockedKeys: Set<String>
    let progressByKey: [String: AchievementProgressState]
    var onBadgeTap: ((String) -> Void)?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public init(
        achievements: [AchievementDefinition] = AchievementCatalog.all,
        unlockedKeys: Set<String>,
        progressByKey: [String: AchievementProgressState] = [:],
        onBadgeTap: ((String) -> Void)? = nil
    ) {
        self.achievements = achievements
        self.unlockedKeys = unlockedKeys
        self.progressByKey = progressByKey
        self.onBadgeTap = onBadgeTap
    }

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
                    ForEach(achievements, id: \.key) { achievement in
                        let isUnlocked = unlockedKeys.contains(achievement.key)
                        BadgeCardView(
                            achievement: achievement,
                            isUnlocked: isUnlocked,
                            progress: progressByKey[achievement.key]
                        )
                            .onTapGesture {
                                onBadgeTap?(achievement.key)
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
    let progress: AchievementProgressState?

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

            Text(progress?.progressLabel ?? (isUnlocked ? "Unlocked" : "Locked"))
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
                .lineLimit(1)
                .frame(width: cardSize)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(achievement.name). \(isUnlocked ? "Unlocked" : "Locked"). \(progress?.progressLabel ?? "No progress"). \(achievement.description)"
        )
    }
}
