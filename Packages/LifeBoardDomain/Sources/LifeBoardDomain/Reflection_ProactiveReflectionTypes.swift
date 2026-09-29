import Foundation

public struct ReflectionCardFeedback: Identifiable, Codable, Equatable, Sendable {
    public var id: String { insightID }
    public let insightID: String
    public var feedbackKey: String { insightID }
    public var saved: Bool
    public var dismissedAt: Date?
    public var snoozedUntil: Date?
    public var notUsefulReason: String?
    public var updatedAt: Date

    public init(
        insightID: String,
        saved: Bool = false,
        dismissedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        notUsefulReason: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.insightID = insightID
        self.saved = saved
        self.dismissedAt = dismissedAt
        self.snoozedUntil = snoozedUntil
        self.notUsefulReason = notUsefulReason
        self.updatedAt = updatedAt
    }

    public var isDismissed: Bool {
        dismissedAt != nil || notUsefulReason != nil
    }

    public func isSnoozed(now: Date = Date()) -> Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > now
    }
}

public struct DecisionFollowUpState: Identifiable, Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case pending
        case prompted
        case reflected
        case dismissed
    }

    public let id: String
    public let decisionID: String
    public let sourceEntryID: UUID
    public let phraseHash: String
    public var state: State
    public let firstSeenAt: Date
    public var lastPromptedAt: Date?
    public var resolvedAt: Date?

    public init(
        id: String,
        decisionID: String,
        sourceEntryID: UUID,
        phraseHash: String,
        state: State,
        firstSeenAt: Date,
        lastPromptedAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.decisionID = decisionID
        self.sourceEntryID = sourceEntryID
        self.phraseHash = phraseHash
        self.state = state
        self.firstSeenAt = firstSeenAt
        self.lastPromptedAt = lastPromptedAt
        self.resolvedAt = resolvedAt
    }
}

public struct DecisionMoment: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case decision
        case regret
    }

    public let id: String
    public let kind: Kind
    public let phrase: String
    public let phraseHash: String
    public let entryID: UUID
    public let date: Date
    public let topicKeywords: [String]
    public let sentiment: Double
    public let followUpDueAt: Date
    public var followUp: DecisionFollowUpState

    public var isFollowedUp: Bool {
        followUp.state == .reflected || followUp.state == .dismissed
    }
}

public struct WeeklyReflectionRecap: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let summary: String
    public let suggestedPrompt: String
    public let currentWeekEntryCount: Int
    public let previousWeekEntryCount: Int
    public let currentWordCount: Int
    public let previousWordCount: Int
    public let topTopics: [String]
    public let decisionCount: Int
    public let evidence: [ReflectionEvidence]
    public let generatedAt: Date
}

public struct ReflectionEntrySnapshot: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let updatedAt: Date
    public let mood: String?
    public let text: String
    public let wordCount: Int
    public let sentiment: Double

    public init(id: UUID, date: Date, updatedAt: Date? = nil, mood: String?, text: String, sentiment: Double? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.date = date
        self.updatedAt = updatedAt ?? date
        self.mood = mood
        self.text = trimmed
        self.wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        self.sentiment = sentiment ?? ProactiveReflectionAnalyzer.sentimentScore(text: trimmed, mood: mood)
    }

}

public struct ProactiveReflectionAnalysisResult: Equatable, Sendable {
    public let insights: [ReflectionInsight]
    public let decisions: [DecisionMoment]
    public let followUpStates: [DecisionFollowUpState]
    public let weeklyRecap: WeeklyReflectionRecap?
    public let selectedPrompt: ReflectionInsight?
}
