import SwiftUI

/// Horizontal scroll of achievement badges, showing unlocked and locked states.
public struct BadgeGalleryView: View {

    let achievements: [AchievementDefinition]
    let unlockedKeys: Set<String>
    let progressByKey: [String: AchievementProgressState]
    var onBadgeTap: ((String) -> Void)?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

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
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)
                Spacer()
                Text("\(unlockedKeys.count) / \(AchievementCatalog.all.count)")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
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
                    .fill(isUnlocked ? Color.lifeboard.surfacePrimary : Color.lifeboard.surfaceTertiary)
                    .frame(width: cardSize, height: cardSize)
                    .shadow(
                        color: isUnlocked ? Color.lifeboard.accentPrimary.opacity(0.15) : .clear,
                        radius: 4
                    )

                if isUnlocked {
                    Image(systemName: achievement.sfSymbol)
                        .font(.system(size: 28))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                } else {
                    ZStack {
                        Image(systemName: achievement.sfSymbol)
                            .font(.system(size: 28))
                            .foregroundColor(Color.lifeboard.textQuaternary)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.lifeboard.surfaceTertiary.opacity(GamificationTokens.lockedOverlayOpacity))
                    }
                }
            }

            Text(achievement.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isUnlocked ? Color.lifeboard.textPrimary : Color.lifeboard.textQuaternary)
                .lineLimit(1)
                .frame(width: cardSize)

            Text(progress?.progressLabel ?? (isUnlocked ? "Unlocked" : "Locked"))
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textTertiary)
                .lineLimit(1)
                .frame(width: cardSize)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(achievement.name). \(isUnlocked ? "Unlocked" : "Locked"). \(progress?.progressLabel ?? "No progress"). \(achievement.description)"
        )
    }
}
