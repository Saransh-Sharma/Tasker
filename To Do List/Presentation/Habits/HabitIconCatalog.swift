import Foundation

public struct HabitIconOption: Identifiable, Equatable, Hashable {
    public let symbolName: String
    public let displayName: String
    public let categoryKey: String
    public let keywords: [String]
    public let aliases: [String]
    public let supportedKinds: Set<String>

    public var id: String { symbolName }

    public init(
        symbolName: String,
        displayName: String,
        categoryKey: String,
        keywords: [String],
        aliases: [String] = [],
        supportedKinds: Set<String> = ["positive", "negative"]
    ) {
        self.symbolName = symbolName
        self.displayName = displayName
        self.categoryKey = categoryKey
        self.keywords = keywords
        self.aliases = aliases
        self.supportedKinds = supportedKinds
    }
}

public final class HabitIconCatalog {
    public static let shared = HabitIconCatalog()

    public let all: [HabitIconOption] = [
        HabitIconOption(symbolName: "checkmark.circle.fill", displayName: "Checkmark Circle", categoryKey: "general", keywords: ["done", "complete", "win", "positive", "build"]),
        HabitIconOption(symbolName: "circle.dashed", displayName: "Open Loop", categoryKey: "general", keywords: ["start", "habit", "routine", "repeat"]),
        HabitIconOption(symbolName: "sparkles", displayName: "Sparkles", categoryKey: "growth", keywords: ["improve", "build", "focus", "upgrade"]),
        HabitIconOption(symbolName: "flame.fill", displayName: "Flame", categoryKey: "discipline", keywords: ["intensity", "streak", "consistency", "quit"]),
        HabitIconOption(symbolName: "heart.fill", displayName: "Heart", categoryKey: "health", keywords: ["health", "wellness", "self care", "positive"]),
        HabitIconOption(symbolName: "lungs.fill", displayName: "Lungs", categoryKey: "recovery", keywords: ["smoking", "breath", "quit", "negative"]),
        HabitIconOption(symbolName: "drop.fill", displayName: "Drop", categoryKey: "health", keywords: ["water", "hydrate", "hydration"]),
        HabitIconOption(symbolName: "moon.stars.fill", displayName: "Moon Stars", categoryKey: "sleep", keywords: ["sleep", "rest", "night", "bed"]),
        HabitIconOption(symbolName: "bed.double.fill", displayName: "Bed", categoryKey: "sleep", keywords: ["sleep", "bedtime", "wind down"]),
        HabitIconOption(symbolName: "figure.walk", displayName: "Walk", categoryKey: "movement", keywords: ["walk", "steps", "movement", "exercise"]),
        HabitIconOption(symbolName: "figure.run", displayName: "Run", categoryKey: "movement", keywords: ["run", "cardio", "fitness"]),
        HabitIconOption(symbolName: "dumbbell.fill", displayName: "Dumbbell", categoryKey: "movement", keywords: ["gym", "strength", "lift", "workout"]),
        HabitIconOption(symbolName: "leaf.fill", displayName: "Leaf", categoryKey: "mindfulness", keywords: ["calm", "nature", "meditation", "quiet"]),
        HabitIconOption(symbolName: "brain.head.profile", displayName: "Brain", categoryKey: "mindfulness", keywords: ["focus", "study", "thinking", "mental"]),
        HabitIconOption(symbolName: "book.fill", displayName: "Book", categoryKey: "learning", keywords: ["read", "study", "learn", "education"]),
        HabitIconOption(symbolName: "pencil.and.outline", displayName: "Pencil", categoryKey: "learning", keywords: ["write", "journal", "notes", "reflect"]),
        HabitIconOption(symbolName: "fork.knife", displayName: "Fork Knife", categoryKey: "nutrition", keywords: ["food", "eat", "meal", "diet"]),
        HabitIconOption(symbolName: "carrot.fill", displayName: "Carrot", categoryKey: "nutrition", keywords: ["healthy food", "vegetable", "diet"]),
        HabitIconOption(symbolName: "figure.child", displayName: "Recovery", categoryKey: "recovery", keywords: ["quit", "reduce", "break", "avoid"]),
        HabitIconOption(symbolName: "no.smoking", displayName: "No Smoking", categoryKey: "recovery", keywords: ["smoking", "avoid", "quit", "negative"]),
        HabitIconOption(symbolName: "nosign", displayName: "No Sign", categoryKey: "recovery", keywords: ["no alcohol", "avoid", "skip", "negative"]),
        HabitIconOption(symbolName: "alarm.fill", displayName: "Alarm", categoryKey: "routine", keywords: ["morning", "schedule", "reminder", "consistency"]),
        HabitIconOption(symbolName: "sun.max.fill", displayName: "Sun", categoryKey: "routine", keywords: ["morning", "energy", "daylight", "wake"]),
        HabitIconOption(symbolName: "house.fill", displayName: "House", categoryKey: "home", keywords: ["home", "clean", "organize", "tidy"]),
        HabitIconOption(symbolName: "broom.fill", displayName: "Broom", categoryKey: "home", keywords: ["clean", "tidy", "declutter", "reset"]),
        HabitIconOption(symbolName: "person.2.fill", displayName: "People", categoryKey: "social", keywords: ["friends", "family", "social", "connect"]),
        HabitIconOption(symbolName: "hand.raised.fill", displayName: "Hand Raised", categoryKey: "discipline", keywords: ["pause", "resist", "stop", "avoid"]),
        HabitIconOption(symbolName: "chart.line.uptrend.xyaxis", displayName: "Trend", categoryKey: "tracking", keywords: ["streak", "analytics", "progress", "improvement"]),
        HabitIconOption(symbolName: "target", displayName: "Target", categoryKey: "tracking", keywords: ["goal", "aim", "focus", "win"]),
        HabitIconOption(symbolName: "flag.fill", displayName: "Flag", categoryKey: "tracking", keywords: ["milestone", "goal", "checkpoint"]),
        HabitIconOption(symbolName: "bolt.fill", displayName: "Bolt", categoryKey: "energy", keywords: ["energy", "push", "action", "momentum"]),
        HabitIconOption(symbolName: "timer", displayName: "Timer", categoryKey: "routine", keywords: ["timer", "session", "practice", "check in"]),
        HabitIconOption(symbolName: "gift.fill", displayName: "Gift", categoryKey: "motivation", keywords: ["reward", "joy", "celebrate", "positive"]),
        HabitIconOption(symbolName: "star.fill", displayName: "Star", categoryKey: "motivation", keywords: ["favorite", "best", "priority", "shine"]),
        HabitIconOption(symbolName: "wand.and.stars", displayName: "Magic Wand", categoryKey: "motivation", keywords: ["reset", "boost", "change", "habit"]),
        HabitIconOption(symbolName: "checklist", displayName: "Checklist", categoryKey: "tracking", keywords: ["track", "log", "check in", "routine"])
    ]

    public func search(
        query: String,
        habitKind: AddHabitKind?,
        preferredLifeAreaName: String? = nil
    ) -> [HabitIconOption] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let queryTokens = normalizedQuery
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "-" || $0 == "_" })
            .map(String.init)

        return all
            .filter { option in
                guard let habitKind else { return true }
                return option.supportedKinds.contains(habitKind.iconSupportKey)
            }
            .map { option in
                (option, score(option: option, query: normalizedQuery, tokens: queryTokens, preferredLifeAreaName: preferredLifeAreaName))
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.categoryKey != rhs.0.categoryKey { return lhs.0.categoryKey < rhs.0.categoryKey }
                return lhs.0.displayName < rhs.0.displayName
            }
            .filter { normalizedQuery.isEmpty || $0.1 > 0 }
            .map(\.0)
    }

    private func score(
        option: HabitIconOption,
        query: String,
        tokens: [String],
        preferredLifeAreaName: String?
    ) -> Int {
        guard query.isEmpty == false else {
            var base = 0
            if option.categoryKey == "general" { base += 20 }
            if option.supportedKinds.contains("positive") { base += 2 }
            return base
        }

        var score = 0
        let searchable = ([option.displayName, option.categoryKey] + option.keywords + option.aliases)
            .joined(separator: " ")
            .lowercased()

        if searchable == query { score += 120 }
        if option.displayName.lowercased() == query { score += 100 }
        if option.displayName.lowercased().hasPrefix(query) { score += 80 }
        if option.categoryKey.lowercased().contains(query) { score += 50 }

        for token in tokens {
            if option.displayName.lowercased().contains(token) { score += 18 }
            if option.categoryKey.lowercased().contains(token) { score += 12 }
            if option.keywords.contains(where: { $0.lowercased().contains(token) }) { score += 10 }
            if option.aliases.contains(where: { $0.lowercased().contains(token) }) { score += 10 }
            if searchable.contains(token) { score += 4 }
        }

        if let preferredLifeAreaName {
            let normalizedLifeArea = preferredLifeAreaName.lowercased()
            if searchable.contains(normalizedLifeArea) { score += 15 }
        }

        if option.supportedKinds.contains("positive") { score += 1 }
        return score
    }
}
