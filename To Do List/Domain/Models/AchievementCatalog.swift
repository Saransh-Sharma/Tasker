import Foundation

public struct AchievementDefinition {
    public let key: String
    public let name: String
    public let description: String
    public let sfSymbol: String
    public let category: AchievementCategory

    public enum AchievementCategory: String, CaseIterable {
        case completion
        case streak
        case xp
        case mastery
    }
}

public enum AchievementCatalog {

    public static let all: [AchievementDefinition] = [
        AchievementDefinition(
            key: "first_step",
            name: "First Step",
            description: "Complete your first task",
            sfSymbol: "shoe.fill",
            category: .completion
        ),
        AchievementDefinition(
            key: "xp_100",
            name: "Century",
            description: "Reach 100 XP",
            sfSymbol: "star.fill",
            category: .xp
        ),
        AchievementDefinition(
            key: "week_warrior",
            name: "Week Warrior",
            description: "Maintain a 7-day streak",
            sfSymbol: "calendar.badge.checkmark",
            category: .streak
        ),
        AchievementDefinition(
            key: "seven_day_return",
            name: "Comeback Kid",
            description: "Maintain a 7-day return streak",
            sfSymbol: "arrow.counterclockwise",
            category: .streak
        ),
        AchievementDefinition(
            key: "on_time_10_week",
            name: "Punctual Pro",
            description: "Complete 10 tasks on time in a week",
            sfSymbol: "clock.badge.checkmark",
            category: .completion
        ),
        AchievementDefinition(
            key: "decomposer_20",
            name: "Decomposer",
            description: "Break down 20 tasks into subtasks",
            sfSymbol: "square.split.2x2",
            category: .mastery
        ),
        AchievementDefinition(
            key: "reflection_7",
            name: "Mindful",
            description: "Complete 7 daily reflections",
            sfSymbol: "brain.head.profile",
            category: .mastery
        ),
        AchievementDefinition(
            key: "comeback_after_7_idle",
            name: "Phoenix",
            description: "Return after 7+ idle days",
            sfSymbol: "sunrise.fill",
            category: .streak
        ),
    ]

    public static func definition(for key: String) -> AchievementDefinition? {
        all.first { $0.key == key }
    }
}
