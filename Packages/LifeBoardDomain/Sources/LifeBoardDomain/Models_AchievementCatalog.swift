import Foundation

public struct AchievementDefinition: Sendable {
    public let key: String
    public let name: String
    public let description: String
    public let sfSymbol: String
    public let category: AchievementCategory

    public enum AchievementCategory: String, CaseIterable, Sendable {
        case completion
        case streak
        case xp
        case mastery
    }

    // Memberwise initializer, written out because a public struct's implicit
    // one is internal and this type is constructed from outside the package.
    public init(key: String, name: String, description: String, sfSymbol: String, category: AchievementCategory) {
        self.key = key
        self.name = name
        self.description = description
        self.sfSymbol = sfSymbol
        self.category = category
    }
}

public enum AchievementCatalog {

    public static let all: [AchievementDefinition] = [
        AchievementDefinition(
            key: "first_step",
            name: String(localized: "First step"),
            description: String(localized: "Complete your first task"),
            sfSymbol: "shoe.fill",
            category: .completion
        ),
        AchievementDefinition(
            key: "xp_100",
            name: String(localized: "Century"),
            description: String(localized: "Reach 100 XP"),
            sfSymbol: "star.fill",
            category: .xp
        ),
        AchievementDefinition(
            key: "week_warrior",
            name: String(localized: "Week warrior"),
            description: String(localized: "Keep a 7-day streak"),
            sfSymbol: "calendar.badge.checkmark",
            category: .streak
        ),
        AchievementDefinition(
            key: "seven_day_return",
            name: String(localized: "Comeback kid"),
            description: String(localized: "Come back 7 days in a row"),
            sfSymbol: "arrow.counterclockwise",
            category: .streak
        ),
        AchievementDefinition(
            key: "on_time_10_week",
            name: String(localized: "Punctual pro"),
            description: String(localized: "Complete 10 tasks on time in a week"),
            sfSymbol: "clock.badge.checkmark",
            category: .completion
        ),
        AchievementDefinition(
            key: "decomposer_20",
            name: String(localized: "Decomposer"),
            description: String(localized: "Break down 20 tasks into subtasks"),
            sfSymbol: "square.split.2x2",
            category: .mastery
        ),
        AchievementDefinition(
            key: "reflection_7",
            name: String(localized: "Mindful"),
            description: String(localized: "Reflect on 7 days"),
            sfSymbol: "brain.head.profile",
            category: .mastery
        ),
        AchievementDefinition(
            key: "comeback_after_7_idle",
            name: String(localized: "Phoenix"),
            description: String(localized: "Come back after 7 days away"),
            sfSymbol: "sunrise.fill",
            category: .streak
        ),
    ]

    public static func definition(for key: String) -> AchievementDefinition? {
        all.first { $0.key == key }
    }
}
