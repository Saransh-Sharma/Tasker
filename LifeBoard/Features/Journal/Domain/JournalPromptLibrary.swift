import Foundation

/// A small library of prompts by intent, reusing the persisted `promptID` on
/// text blocks. The five contextual prompts stay the defaults; these are the
/// ones a person reaches for on purpose.
struct JournalPromptSet: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let prompts: [JournalPrompt]
}

enum JournalPromptLibrary {
    static let sets: [JournalPromptSet] = [
        JournalPromptSet(id: "gratitude", title: String(localized: "Gratitude"), systemImage: "heart", prompts: [
            JournalPrompt(id: "gratitude.small", title: String(localized: "What went right today?"), supportiveCopy: String(localized: "Big or small.")),
            JournalPrompt(id: "gratitude.person", title: String(localized: "Who made today easier?"), supportiveCopy: String(localized: "A name is enough.")),
            JournalPrompt(id: "gratitude.body", title: String(localized: "What did your body do for you today?"), supportiveCopy: String(localized: "Walking, resting, anything.")),
        ]),
        JournalPromptSet(id: "morning", title: String(localized: "Morning"), systemImage: "sunrise", prompts: [
            JournalPrompt(id: "morning.one", title: String(localized: "What’s the one thing for today?"), supportiveCopy: String(localized: "One, not the list.")),
            JournalPrompt(id: "morning.energy", title: String(localized: "How much energy do you have today?"), supportiveCopy: String(localized: "Plan for that.")),
            JournalPrompt(id: "morning.worry", title: String(localized: "What’s already on your mind?"), supportiveCopy: String(localized: "Name it.")),
        ]),
        JournalPromptSet(id: "evening", title: String(localized: "Evening"), systemImage: "moon.stars", prompts: [
            JournalPrompt(id: "evening.kept", title: String(localized: "What stayed with you today?"), supportiveCopy: String(localized: "What stood out.")),
            JournalPrompt(id: "evening.letgo", title: String(localized: "What can you leave for tomorrow?"), supportiveCopy: String(localized: "It can wait.")),
            JournalPrompt(id: "evening.tomorrow", title: String(localized: "What would make tomorrow easier?"), supportiveCopy: String(localized: "A sentence, not a plan.")),
        ]),
        JournalPromptSet(id: "reframe", title: String(localized: "Reframe"), systemImage: "arrow.triangle.2.circlepath", prompts: [
            JournalPrompt(id: "reframe.thought", title: String(localized: "What thought keeps coming back?"), supportiveCopy: String(localized: "Write it as it sounds.")),
            JournalPrompt(id: "reframe.evidence", title: String(localized: "What would you tell a friend thinking this?"), supportiveCopy: String(localized: "Say it to yourself.")),
            JournalPrompt(id: "reframe.next", title: String(localized: "What’s a kinder way to see it?"), supportiveCopy: String(localized: "Keep it true.")),
        ]),
        JournalPromptSet(id: "weekly", title: String(localized: "Weekly"), systemImage: "calendar", prompts: [
            JournalPrompt(id: "weekly.proud", title: String(localized: "What are you proud of this week?"), supportiveCopy: String(localized: "Big or small.")),
            JournalPrompt(id: "weekly.friction", title: String(localized: "What kept getting in the way?"), supportiveCopy: String(localized: "Describe it, don’t fix it.")),
            JournalPrompt(id: "weekly.carry", title: String(localized: "What will you take into next week?"), supportiveCopy: String(localized: "One to keep, one to drop.")),
        ]),
    ]

    static var all: [JournalPrompt] { sets.flatMap(\.prompts) }

    static func prompt(id: String) -> JournalPrompt? {
        all.first { $0.id == id }
    }
}
