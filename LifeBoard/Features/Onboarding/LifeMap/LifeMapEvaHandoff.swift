import Foundation
import LifeBoardContracts
import LifeBoardDomain

// The bridge from a finished Life Map to a usable EVA: what EVA should know
// about this person, and what they should ask it first.

// MARK: - Profile

/// Translates the Life Map into the profile EVA's own onboarding used to collect.
///
/// EVA's `aboutYou` and `goals` stages asked for working style, momentum
/// blockers, and goals. The Life Map already asks richer versions of all three,
/// so re-asking was pure duplication — this maps across instead.
///
/// The enum mappings below are lossy by construction: five desired changes and
/// four frictions do not partition eight working styles and eight blockers.
/// That is why the user's own wording also travels, in the free-text notes,
/// which are not lossy. If the two ever disagree, the literal text is the one
/// that reflects what the person actually chose.
enum LifeMapEvaProfileMapper {
    static func profileDraft(from draft: LifeMapDraft) -> EvaProfileDraft {
        var profile = EvaProfileDraft()

        if let change = draft.desiredChange {
            profile.selectedWorkingStyleIDs = [workingStyle(for: change).rawValue]
            profile.customWorkingStyleNote = change.title
        }

        let frictions = draft.frictionIDs.compactMap(LifeMapFriction.init(rawValue:))
        profile.selectedMomentumBlockerIDs = frictions.map { blocker(for: $0).rawValue }
        if frictions.isEmpty == false {
            profile.customMomentumNote = frictions.map(\.title).joined(separator: " ")
        }

        profile.goals = goals(from: draft)
        return profile
    }

    static func workingStyle(for change: LifeMapDesiredChange) -> EvaWorkingStyleID {
        switch change {
        case .seeWeek: .prioritizeForMe
        case .clearHead: .concise
        case .flexibleConsistency: .keepPlansRealistic
        case .makeRoom: .focus
        case .knowNext: .decideFaster
        }
    }

    static func blocker(for friction: LifeMapFriction) -> EvaMomentumBlockerID {
        switch friction {
        case .scattered: .contextSwitching
        case .plansBreak: .loseSteamMidDay
        case .urgentWins: .stuckChoosing
        case .rigidBurden: .overPlanning
        }
    }

    /// Priority order is the signal here, not the set. "Health, then Work, then
    /// Family" tells EVA what to protect when they collide; an unordered list
    /// would not.
    private static func goals(from draft: LifeMapDraft) -> [String] {
        var lines: [String] = []
        let areas = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
        if areas.isEmpty == false {
            lines.append("This season I'm prioritising \(onboardingNaturalLanguageList(areas, fallback: "a few areas")), in that order.")
        }
        let hours = weeklyHours(from: draft.dayShape)
        if hours > 0 {
            lines.append("I have about \(hours) hours of working time in a normal week.")
        }
        return lines
    }

    static func weeklyHours(from dayShape: OnboardingDayShapeDraft) -> Int {
        let weekdayMinutes = max(0, dayShape.weekdayEndMinute - dayShape.weekdayStartMinute) * 5
        let weekendMinutes = dayShape.worksWeekends
            ? max(0, dayShape.weekendEndMinute - dayShape.weekendStartMinute) * 2
            : 0
        return (weekdayMinutes + weekendMinutes) / 60
    }
}

// MARK: - Opening prompts

/// The first thing the user asks EVA, built from what they just told us.
///
/// The stock activation opener is "How is my day looking today?", which on day
/// one asks EVA to summarise a workspace that is nearly empty — a thin answer
/// at the exact moment first impressions are formed. These prompts instead
/// reason over the profile the person just authored, which exists in full, and
/// over the calendar they just connected. Every clause is conditional: absent
/// facts drop out rather than being invented.
enum LifeMapEvaOpeningPrompt {
    static func prompts(for draft: LifeMapDraft, upcomingEventCount: Int?) -> [EvaStarterPrompt] {
        var result: [EvaStarterPrompt] = [
            EvaStarterPrompt(
                id: "lifemap_where_to_start",
                title: "Where should I start?",
                submissionText: openingSubmission(for: draft, upcomingEventCount: upcomingEventCount),
                style: .naturalLanguage,
                isRecommended: true
            )
        ]

        if let count = upcomingEventCount, count > 0 {
            result.append(EvaStarterPrompt(
                id: "lifemap_crowding_week",
                title: "What's already crowding my week?",
                submissionText: "I have \(count) \(count == 1 ? "event" : "events") on my calendar this week and about \(LifeMapEvaProfileMapper.weeklyHours(from: draft.dayShape)) hours of working time. What is already crowding my week, and what does that leave?",
                style: .naturalLanguage,
                isRecommended: false
            ))
        }

        if let capture = draft.stagedCapture, capture.isReviewed, capture.kind == .task {
            result.append(EvaStarterPrompt(
                id: "lifemap_break_down_capture",
                title: "Turn “\(capture.text)” into next steps",
                submissionText: "Help me break “\(capture.text)” into next steps I can actually start.",
                style: .naturalLanguage,
                isRecommended: false
            ))
        }

        if let topArea = topAreaName(in: draft) {
            result.append(EvaStarterPrompt(
                id: "lifemap_protect_top_area",
                title: "Protect time for \(topArea)",
                submissionText: "\(topArea) is my top priority this season. Help me protect time for it in a normal week.",
                style: .naturalLanguage,
                isRecommended: false
            ))
        }

        return result
    }

    static func openingSubmission(for draft: LifeMapDraft, upcomingEventCount: Int?) -> String {
        var sentences = ["I've just set up LifeBoard."]

        if let change = draft.desiredChange {
            let frictions = draft.frictionIDs
                .compactMap(LifeMapFriction.init(rawValue:))
                .map { $0.title.lowercased() }
            if frictions.isEmpty {
                sentences.append("What I want is to \(change.title.lowercased()).")
            } else {
                sentences.append(
                    "What I want is to \(change.title.lowercased()), and what gets in my way is that \(onboardingNaturalLanguageList(frictions, fallback: "things pile up"))."
                )
            }
        }

        let areas = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
        if areas.isEmpty == false {
            sentences.append("This season I'm prioritising \(onboardingNaturalLanguageList(areas, fallback: "a few areas")), in that order.")
        }

        var capacity: [String] = []
        let hours = LifeMapEvaProfileMapper.weeklyHours(from: draft.dayShape)
        if hours > 0 { capacity.append("about \(hours) hours of working time a week") }
        if let count = upcomingEventCount, count > 0 {
            capacity.append("\(count) \(count == 1 ? "thing" : "things") already on my calendar")
        }
        if capacity.isEmpty == false {
            sentences.append("I have \(onboardingNaturalLanguageList(capacity, fallback: "some time")).")
        }

        if let capture = draft.stagedCapture, capture.isReviewed {
            sentences.append("I've put one thing in already: “\(capture.text)”.")
        }

        sentences.append("Given that — where should I start?")
        return sentences.joined(separator: " ")
    }

    private static func topAreaName(in draft: LifeMapDraft) -> String? {
        draft.orderedLifeAreaTemplateIDs.first.flatMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
    }
}

// MARK: - Hand-off store

/// Carries the composed prompts across the onboarding dismissal.
///
/// Single-drain on purpose: these are an opening move, not a permanent set of
/// suggestions. Once the person has said anything to EVA the openers are stale,
/// so `ChatView` clears them on the first send.
enum EvaOpeningPromptStore {
    static let key = "eva.opening_prompt.v1"

    private struct Stored: Codable {
        let id: String
        let title: String
        let submissionText: String
        let isRecommended: Bool
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    static func stage(_ prompts: [EvaStarterPrompt], defaults: UserDefaults? = nil) {
        let payload = prompts.map {
            Stored(id: $0.id, title: $0.title, submissionText: $0.submissionText, isRecommended: $0.isRecommended)
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        (defaults ?? Self.defaults).set(data, forKey: key)
    }

    static func load(defaults: UserDefaults? = nil) -> [EvaStarterPrompt] {
        guard let data = (defaults ?? Self.defaults).data(forKey: key),
              let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return [] }
        return stored.map {
            EvaStarterPrompt(
                id: $0.id,
                title: $0.title,
                submissionText: $0.submissionText,
                style: .naturalLanguage,
                isRecommended: $0.isRecommended
            )
        }
    }

    static func clear(defaults: UserDefaults? = nil) {
        (defaults ?? Self.defaults).removeObject(forKey: key)
    }
}
