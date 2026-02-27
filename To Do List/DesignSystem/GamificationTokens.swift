import UIKit

public enum GamificationTokens {

    // MARK: - XP Ring Sizes

    public enum XPRingSize {
        case navCompact   // 32x32, 4pt ring (existing NavPieChart)
        case homeHero     // 80x80, 6pt ring (Home daily progress)
        case widgetSmall  // 56x56, 5pt ring (widget ring)
        case insightLarge // 120x120, 8pt ring (Insights detail)

        public var diameter: CGFloat {
            switch self {
            case .navCompact: return 32
            case .homeHero: return 80
            case .widgetSmall: return 56
            case .insightLarge: return 120
            }
        }

        public var ringWidth: CGFloat {
            switch self {
            case .navCompact: return 4
            case .homeHero: return 6
            case .widgetSmall: return 5
            case .insightLarge: return 8
            }
        }
    }

    // MARK: - Level Badge

    public static let levelBadgeSize: CGFloat = 28
    public static let levelBadgeFontSize: CGFloat = 13

    // MARK: - Streak Flame

    public static let streakFlameSize: CGFloat = 20
    public static let streakGlowOpacity: CGFloat = 0.15

    // MARK: - Achievement Card

    public static let achievementCardIconSize: CGFloat = 72
    public static let lockedOverlayOpacity: CGFloat = 0.6

    // MARK: - Weekly Bar Chart

    public static let weeklyBarWidth: CGFloat = 28
    public static let weeklyBarSpacing: CGFloat = 8
    public static let weeklyBarMaxHeight: CGFloat = 160
    public static let weeklyBarCornerRadius: CGFloat = 8

    // MARK: - Focus Timer Ring

    public static let focusTimerSize: CGFloat = 200
    public static let focusTimerRingWidth: CGFloat = 10
    public static let focusTimerFontSize: CGFloat = 48

    // MARK: - Progress Bar

    public static let progressBarHeight: CGFloat = 6
    public static let progressBarHeightLarge: CGFloat = 8

    // MARK: - Animation Durations

    public static let xpCelebrationDuration: TimeInterval = 0.9
    public static let levelUpDuration: TimeInterval = 2.5
    public static let milestoneDuration: TimeInterval = 4.0
    public static let badgeUnlockDuration: TimeInterval = 3.0
    public static let badgeUnlockEntryDuration: TimeInterval = 0.4

    // MARK: - Spring Parameters

    public struct SpringConfig {
        public let response: Double
        public let dampingFraction: Double

        public static let xpCelebration = SpringConfig(response: 0.4, dampingFraction: 0.6)
        public static let levelUp = SpringConfig(response: 0.5, dampingFraction: 0.65)
        public static let ringProgress = SpringConfig(response: 0.6, dampingFraction: 0.7)
        public static let badgeUnlock = SpringConfig(response: 0.35, dampingFraction: 0.55)
    }

    // MARK: - Daily Cap

    public static let dailyXPCap: Int = 250
}
