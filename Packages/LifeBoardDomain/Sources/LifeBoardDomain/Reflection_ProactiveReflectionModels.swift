//
//  ProactiveReflectionModels.swift
//  ReflectionKit
//
//  Shared, deterministic proactive reflection vocabulary and analyzer.
//  Host apps own persistence, scheduling, assistant naming, and presentation.
//

import Foundation

public struct ReflectionEvidence: Identifiable, Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable {
        case source
        case baseline
        case trajectory
    }

    public let id: String
    public let entryID: UUID
    public let date: Date
    public let mood: String?
    public let role: Role
}

public struct ReflectionInsight: Identifiable, Codable, Equatable, Sendable {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case pattern = "Pattern"
        case decision = "Decision"
        case weekly = "Weekly"
        case prompt = "Prompt"
    }

    public enum Kind: String, Codable, Sendable {
        case patternSignal
        case cadenceChange
        case volumeChange
        case moodTrajectory
        case resurfacedThread
        case contrast
        case decisionFollowUp
        case quietEntity
        case moodAssociation
        case repeatedQuestion
        case weeklyRecap
        case carryForward
    }

    public enum Confidence: String, Codable, Sendable {
        case low
        case medium
        case high
    }

    public enum EvidenceMode: String, Codable, Sendable {
        case semantic
        case deterministicPattern
        case profileSummary
    }

    public enum Action: String, Codable, CaseIterable, Sendable {
        case reflect
        case askFriday
        case openEvidence
        case snooze
        case dismiss
    }

    public enum Priority: Int, Codable, Comparable, Sendable {
        case low = 1
        case medium = 2
        case high = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let id: String
    public let category: Category
    public let priority: Priority
    public let title: String
    public let message: String
    public let prompt: String
    public let evidence: [ReflectionEvidence]
    public let kind: Kind
    public let feedbackKey: String
    public let evidenceMode: EvidenceMode
    public let explanation: String
    public let confidence: Confidence
    public let suggestedQuestion: String?
    public let createdAt: Date
    public let expiresAt: Date?
    public let decisionID: String?

    public init(
        id: String,
        category: Category,
        priority: Priority,
        title: String,
        message: String,
        prompt: String,
        evidence: [ReflectionEvidence],
        kind: Kind = .patternSignal,
        feedbackKey: String? = nil,
        evidenceMode: EvidenceMode = .deterministicPattern,
        explanation: String? = nil,
        confidence: Confidence = .medium,
        suggestedQuestion: String? = nil,
        createdAt: Date,
        expiresAt: Date?,
        decisionID: String? = nil
    ) {
        self.id = id
        self.category = category
        self.priority = priority
        self.title = title
        self.message = message
        self.prompt = prompt
        self.evidence = evidence
        self.kind = kind
        self.feedbackKey = feedbackKey ?? id
        self.evidenceMode = evidenceMode
        self.explanation = explanation ?? Self.defaultExplanation(for: evidence)
        self.confidence = confidence
        self.suggestedQuestion = suggestedQuestion
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.decisionID = decisionID
    }

    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt < now
    }

    public var actions: [Action] {
        var values: [Action] = [.reflect, .askFriday]
        if !evidence.isEmpty { values.append(.openEvidence) }
        values.append(contentsOf: [.snooze, .dismiss])
        return values
    }

    private static func defaultExplanation(for evidence: [ReflectionEvidence]) -> String {
        guard !evidence.isEmpty else { return "Shown as a local pattern summary from your journal." }
        let sourceCount = evidence.filter { $0.role == .source || $0.role == .trajectory }.count
        let baselineCount = evidence.filter { $0.role == .baseline }.count
        if baselineCount > 0 {
            return "Shown because \(sourceCount) recent \(sourceCount == 1 ? "entry" : "entries") stood apart from \(baselineCount) baseline \(baselineCount == 1 ? "entry" : "entries")."
        }
        return "Shown because \(sourceCount) supporting \(sourceCount == 1 ? "entry" : "entries") pointed to this pattern."
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case category
        case priority
        case title
        case message
        case prompt
        case evidence
        case kind
        case feedbackKey
        case evidenceMode
        case explanation
        case confidence
        case suggestedQuestion
        case createdAt
        case expiresAt
        case decisionID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(Category.self, forKey: .category)
        priority = try container.decode(Priority.self, forKey: .priority)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        prompt = try container.decode(String.self, forKey: .prompt)
        evidence = try container.decode([ReflectionEvidence].self, forKey: .evidence)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .patternSignal
        feedbackKey = try container.decodeIfPresent(String.self, forKey: .feedbackKey) ?? id
        evidenceMode = try container.decodeIfPresent(EvidenceMode.self, forKey: .evidenceMode) ?? .deterministicPattern
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation) ?? Self.defaultExplanation(for: evidence)
        confidence = try container.decodeIfPresent(Confidence.self, forKey: .confidence) ?? .medium
        suggestedQuestion = try container.decodeIfPresent(String.self, forKey: .suggestedQuestion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        decisionID = try container.decodeIfPresent(String.self, forKey: .decisionID)
    }
}

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

// MARK: - Analyzer

public enum ProactiveReflectionAnalyzer {
    public static let minimumAnomalyEntries = 10
    private static let currentWeekWindow: TimeInterval = 7 * 24 * 60 * 60
    private static let previousWeekWindow: TimeInterval = 14 * 24 * 60 * 60

    public static func analyze(
        entries: [ReflectionEntrySnapshot],
        existingFollowUps: [DecisionFollowUpState] = [],
        now: Date = Date()
    ) -> ProactiveReflectionAnalysisResult {
        let sorted = entries.sorted { $0.date > $1.date }
        let decisions = extractDecisionMoments(from: sorted, existingFollowUps: existingFollowUps, now: now)
        let weeklyRecap = makeWeeklyRecap(from: sorted, decisions: decisions, now: now)
        let anomalyInsights = detectAnomalies(in: sorted, now: now)
        let decisionInsights = makeDecisionInsights(from: decisions, entries: sorted, now: now)
        let creativeInsights = detectSemanticReflectionOpportunities(in: sorted, now: now)
        let weeklyInsight = weeklyRecap.map { makeWeeklyInsight($0, now: now) }

        var insights = anomalyInsights + creativeInsights + decisionInsights
        if let weeklyInsight { insights.append(weeklyInsight) }

        let selectedPrompt = selectPrompt(
            insights: insights,
            decisions: decisions,
            weeklyRecap: weeklyRecap,
            entries: sorted,
            now: now
        )

        if let selectedPrompt, !insights.contains(where: { $0.id == selectedPrompt.id }) {
            insights.append(selectedPrompt)
        }

        let activeInsights = insights
            .filter { !$0.isExpired(now: now) }
            .sorted {
                if $0.priority == $1.priority { return $0.createdAt > $1.createdAt }
                return $0.priority > $1.priority
            }

        return ProactiveReflectionAnalysisResult(
            insights: Array(activeInsights.prefix(8)),
            decisions: decisions,
            followUpStates: decisions.map(\.followUp),
            weeklyRecap: weeklyRecap,
            selectedPrompt: selectedPrompt
        )
    }

    public static func detectAnomalies(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        guard sortedEntries.count >= minimumAnomalyEntries else { return [] }

        var insights: [ReflectionInsight] = []
        insights.append(contentsOf: detectSentimentAnomaly(in: sortedEntries, now: now))
        insights.append(contentsOf: detectVolumeAnomaly(in: sortedEntries, now: now))
        insights.append(contentsOf: detectTrajectoryAnomaly(in: sortedEntries, now: now))
        insights.append(contentsOf: detectCadenceAnomaly(in: sortedEntries, now: now))
        insights.append(contentsOf: detectTopicShift(in: sortedEntries, now: now))
        insights.append(contentsOf: detectRepeatedTheme(in: sortedEntries, now: now))
        return insights
    }

    public static func detectSemanticReflectionOpportunities(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        var insights: [ReflectionInsight] = []
        insights.append(contentsOf: detectResurfacedThreads(in: entries, now: now))
        insights.append(contentsOf: detectTopicMoodContrasts(in: entries, now: now))
        insights.append(contentsOf: detectQuietEntities(in: entries, now: now))
        insights.append(contentsOf: detectMoodAssociations(in: entries, now: now))
        insights.append(contentsOf: detectRepeatedQuestions(in: entries, now: now))
        insights.append(contentsOf: detectCarryForwardWins(in: entries, now: now))
        return insights
    }

    public static func detectCadenceAnomaly(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        guard sortedEntries.count >= minimumAnomalyEntries else { return [] }
        let recent = Array(sortedEntries.prefix(4))
        let baseline = Array(sortedEntries.dropFirst(4).prefix(10))
        guard recent.count >= 3, baseline.count >= 6 else { return [] }

        let recentAverageGap = averageGaps(in: recent)
        let baselineAverageGap = averageGaps(in: baseline)
        guard recentAverageGap > 0, baselineAverageGap > 0 else { return [] }

        let isLongSilence = recentAverageGap >= baselineAverageGap * 2.2 && recentAverageGap - baselineAverageGap >= 1.5
        let isDenseReturn = baselineAverageGap >= recentAverageGap * 2.2 && baselineAverageGap - recentAverageGap >= 1.5
        guard isLongSilence || isDenseReturn else { return [] }

        return [
            ReflectionInsight(
                id: stableID("cadence-\(recent.map(\.id.uuidString).joined())-\(isLongSilence)"),
                category: .pattern,
                priority: .medium,
                title: isLongSilence ? "Your journaling rhythm changed" : "You returned to journaling more often",
                message: isLongSilence
                ? "Your journal noticed more space between recent entries than your earlier rhythm."
                : "Your journal noticed your recent entries are closer together than your earlier rhythm.",
                prompt: isLongSilence ? "What made journaling harder to return to lately?" : "What brought you back to writing more often?",
                evidence: evidenceSet(source: recent.prefix(2), baseline: baseline.prefix(3)),
                kind: .cadenceChange,
                feedbackKey: feedbackKey(kind: .cadenceChange, subject: isLongSilence ? "long silence" : "dense return", window: "recent rhythm"),
                explanation: isLongSilence
                ? "Shown because your recent entry gaps are more than double your earlier rhythm."
                : "Shown because your recent entries are much closer together than your earlier rhythm.",
                confidence: .medium,
                suggestedQuestion: "How has my journaling rhythm changed lately?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func detectTopicShift(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        guard sortedEntries.count >= minimumAnomalyEntries else { return [] }
        let recent = Array(sortedEntries.prefix(3))
        let baseline = Array(sortedEntries.dropFirst(3).prefix(10))
        guard recent.count == 3, baseline.count >= 6 else { return [] }

        let recentTopics = Set(topTopics(in: recent, limit: 6).map { $0.lowercased() })
        let baselineTopics = Set(topTopics(in: baseline, limit: 8).map { $0.lowercased() })
        guard recentTopics.count >= 3, baselineTopics.count >= 3 else { return [] }
        let overlap = recentTopics.intersection(baselineTopics)
        guard Double(overlap.count) / Double(max(1, recentTopics.count)) <= 0.25 else { return [] }

        return [
            ReflectionInsight(
                id: stableID("topic-shift-\(recent.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .medium,
                title: "A newer theme is taking shape",
                message: "Your journal noticed your recent entries are circling different themes than the earlier baseline.",
                prompt: "What changed around this newer thread?",
                evidence: evidenceSet(source: recent, baseline: baseline.prefix(3)),
                kind: .contrast,
                feedbackKey: feedbackKey(kind: .contrast, subject: "topic shift", window: "recent"),
                explanation: "Shown because the latest three entries share little topic overlap with your earlier baseline.",
                confidence: .medium,
                suggestedQuestion: "What newer theme has been taking shape in my journal?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func detectRepeatedTheme(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let sortedEntries = entries.sorted { $0.date > $1.date }
        guard sortedEntries.count >= minimumAnomalyEntries else { return [] }
        let recent = Array(sortedEntries.prefix(5))
        guard recent.count >= 4 else { return [] }

        var entriesByTheme: [String: [ReflectionEntrySnapshot]] = [:]
        for entry in recent {
            let themes = Set(themeKeywords(in: entry.text))
            for theme in themes {
                entriesByTheme[theme, default: []].append(entry)
            }
        }

        guard let theme = entriesByTheme
            .filter({ $0.value.count >= 3 })
            .sorted(by: {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key < $1.key
            })
            .first else { return [] }

        return [
            ReflectionInsight(
                id: stableID("repeated-theme-\(theme.key)-\(theme.value.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .medium,
                title: "A theme is taking shape",
                message: "Your journal noticed \(theme.key.capitalized) coming up across several recent entries.",
                prompt: "What is this thread asking you to notice?",
                evidence: theme.value.prefix(4).map { evidence(from: $0, role: .source) },
                kind: .patternSignal,
                feedbackKey: feedbackKey(kind: .patternSignal, subject: theme.key, window: "recent theme"),
                explanation: "Shown because \(theme.value.count) recent entries mention \(theme.key.capitalized).",
                confidence: theme.value.count >= 4 ? .high : .medium,
                suggestedQuestion: "What has been coming up around \(theme.key)?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func detectResurfacedThreads(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let recent = entries.filter { ageInDays($0.date, now: now) <= 7 }.sorted { $0.date > $1.date }
        let older = entries.filter { ageInDays($0.date, now: now) >= 28 }.sorted { $0.date > $1.date }
        guard !recent.isEmpty, older.count >= 2 else { return [] }

        let recentThemes = themeBuckets(in: recent)
        let olderThemes = themeBuckets(in: older)
        guard let match = recentThemes.keys
            .compactMap({ theme -> (theme: String, recent: [ReflectionEntrySnapshot], older: [ReflectionEntrySnapshot])? in
                guard let recentEntries = recentThemes[theme], let olderEntries = olderThemes[theme], olderEntries.count >= 2 else { return nil }
                return (theme, recentEntries, olderEntries)
            })
            .sorted(by: { lhs, rhs in
                if lhs.older.count != rhs.older.count { return lhs.older.count > rhs.older.count }
                return lhs.theme < rhs.theme
            })
            .first else { return [] }

        return [
            ReflectionInsight(
                id: stableID("resurfaced-\(match.theme)-\(match.recent.map(\.id.uuidString).joined())-\(match.older.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .medium,
                title: "An older thread resurfaced",
                message: "Your journal noticed \(match.theme.capitalized) connects recent writing to older entries.",
                prompt: "What feels different about \(match.theme) this time?",
                evidence: evidenceSet(source: match.recent.prefix(2), baseline: match.older.prefix(3)),
                kind: .resurfacedThread,
                feedbackKey: feedbackKey(kind: .resurfacedThread, subject: match.theme, window: "28d"),
                explanation: "Shown because \(match.theme.capitalized) appears now and also in entries from at least four weeks ago.",
                confidence: match.older.count >= 3 ? .high : .medium,
                suggestedQuestion: "How has \(match.theme) changed since I first wrote about it?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 10, to: now)
            )
        ]
    }

    public static func detectTopicMoodContrasts(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let recent = entries.filter { ageInDays($0.date, now: now) <= 7 }
        let previous = entries.filter {
            let age = ageInDays($0.date, now: now)
            return age > 7 && age <= 60
        }
        guard !recent.isEmpty, previous.count >= 2 else { return [] }

        let recentThemes = themeBuckets(in: recent)
        let previousThemes = themeBuckets(in: previous)
        let candidates = recentThemes.compactMap { theme, recentEntries -> (theme: String, recentEntries: [ReflectionEntrySnapshot], previousEntries: [ReflectionEntrySnapshot], delta: Double)? in
            guard let previousEntries = previousThemes[theme], previousEntries.count >= 2 else { return nil }
            let delta = average(recentEntries.map(\.sentiment)) - average(previousEntries.map(\.sentiment))
            guard abs(delta) >= 0.30 else { return nil }
            return (theme, recentEntries, previousEntries, delta)
        }
        guard let match = candidates.sorted(by: { abs($0.delta) > abs($1.delta) }).first else { return [] }

        let lighter = match.delta > 0
        return [
            ReflectionInsight(
                id: stableID("contrast-\(match.theme)-\(lighter)-\(match.recentEntries.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .medium,
                title: "Same topic, different feeling",
                message: "Your journal noticed \(match.theme.capitalized) showed up again, but the tone seems \(lighter ? "lighter" : "heavier") than before.",
                prompt: lighter ? "What helped this topic feel lighter this time?" : "What made this topic carry more weight this time?",
                evidence: evidenceSet(source: match.recentEntries.prefix(2), baseline: match.previousEntries.prefix(3)),
                kind: .contrast,
                feedbackKey: feedbackKey(kind: .contrast, subject: match.theme, window: "60d"),
                explanation: "Shown because recent \(match.theme) entries differ emotionally from earlier \(match.theme) entries.",
                confidence: abs(match.delta) >= 0.45 ? .high : .medium,
                suggestedQuestion: "How has my feeling about \(match.theme) changed?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 10, to: now)
            )
        ]
    }

    public static func detectQuietEntities(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let recentText = entries
            .filter { ageInDays($0.date, now: now) <= 14 }
            .map(\.text)
            .joined(separator: " ")
            .lowercased()
        let baseline = entries.filter {
            let age = ageInDays($0.date, now: now)
            return age > 14 && age <= 120
        }
        guard baseline.count >= 4 else { return [] }

        var entriesByEntity: [String: [ReflectionEntrySnapshot]] = [:]
        for entry in baseline {
            for entity in TextSignals.extractEntities(from: entry.text) where entity.count > 2 {
                entriesByEntity[entity, default: []].append(entry)
            }
        }

        guard let match = entriesByEntity
            .filter({ entity, entityEntries in
                entityEntries.count >= 2 && !recentText.contains(entity.lowercased())
            })
            .sorted(by: {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key < $1.key
            })
            .first else { return [] }

        return [
            ReflectionInsight(
                id: stableID("quiet-entity-\(match.key)-\(match.value.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .low,
                title: "A familiar name has gone quiet",
                message: "Your journal noticed \(match.key) used to appear more often and has not shown up in recent entries.",
                prompt: "Is there anything about \(match.key) you want to check in with yourself about?",
                evidence: match.value.prefix(3).map { evidence(from: $0, role: .baseline) },
                kind: .quietEntity,
                feedbackKey: feedbackKey(kind: .quietEntity, subject: match.key, window: "14d"),
                explanation: "Shown because \(match.key) appeared in earlier entries but not in the last two weeks.",
                confidence: .medium,
                suggestedQuestion: "What has changed around \(match.key)?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func detectMoodAssociations(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let window = entries.filter { ageInDays($0.date, now: now) <= 45 }
        guard window.count >= 6 else { return [] }

        let globalAverage = average(window.map(\.sentiment))
        let buckets = themeBuckets(in: window)
        let candidates = buckets.compactMap { theme, themeEntries -> (theme: String, entries: [ReflectionEntrySnapshot], average: Double, delta: Double)? in
            guard themeEntries.count >= 3 else { return nil }
            let themeAverage = average(themeEntries.map(\.sentiment))
            let delta = themeAverage - globalAverage
            guard abs(delta) >= 0.28 || abs(themeAverage) >= 0.35 else { return nil }
            return (theme, themeEntries, themeAverage, delta)
        }
        guard let match = candidates.sorted(by: { abs($0.delta) > abs($1.delta) }).first else { return [] }

        let lifts = match.average >= globalAverage
        return [
            ReflectionInsight(
                id: stableID("mood-association-\(match.theme)-\(lifts)-\(match.entries.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: lifts ? .medium : .high,
                title: lifts ? "\(match.theme.capitalized) seems to lift you" : "\(match.theme.capitalized) seems to weigh on you",
                message: lifts
                ? "Your journal noticed entries around \(match.theme) often read lighter than your recent baseline."
                : "Your journal noticed entries around \(match.theme) often read heavier than your recent baseline.",
                prompt: lifts ? "How can you protect more of what helps here?" : "What support would make this thread easier to carry?",
                evidence: match.entries.prefix(4).map { evidence(from: $0, role: .source) },
                kind: .moodAssociation,
                feedbackKey: feedbackKey(kind: .moodAssociation, subject: match.theme, window: "45d"),
                explanation: "Shown because \(match.entries.count) recent entries connect \(match.theme) with a consistent emotional tone.",
                confidence: match.entries.count >= 4 ? .high : .medium,
                suggestedQuestion: "What seems to \(lifts ? "help" : "drain") me around \(match.theme)?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 10, to: now)
            )
        ]
    }

    public static func detectRepeatedQuestions(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let window = entries.filter { ageInDays($0.date, now: now) <= 45 }
        guard window.count >= 2 else { return [] }

        var entriesByQuestionTopic: [String: [ReflectionEntrySnapshot]] = [:]
        for entry in window {
            let questionTopics = Set(questionTopics(in: entry.text))
            for topic in questionTopics {
                entriesByQuestionTopic[topic, default: []].append(entry)
            }
        }

        guard let match = entriesByQuestionTopic
            .filter({ $0.value.count >= 2 })
            .sorted(by: {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key < $1.key
            })
            .first else { return [] }

        return [
            ReflectionInsight(
                id: stableID("repeated-question-\(match.key)-\(match.value.map(\.id.uuidString).joined())"),
                category: .prompt,
                priority: .medium,
                title: "A question keeps returning",
                message: "Your journal noticed you have asked about \(match.key) more than once.",
                prompt: "What answer would feel honest right now?",
                evidence: match.value.prefix(3).map { evidence(from: $0, role: .source) },
                kind: .repeatedQuestion,
                feedbackKey: feedbackKey(kind: .repeatedQuestion, subject: match.key, window: "45d"),
                explanation: "Shown because multiple recent entries ask a question around \(match.key).",
                confidence: match.value.count >= 3 ? .high : .medium,
                suggestedQuestion: "What question do I keep returning to around \(match.key)?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func detectCarryForwardWins(in entries: [ReflectionEntrySnapshot], now: Date = Date()) -> [ReflectionInsight] {
        let sorted = entries.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(3))
        let baseline = Array(sorted.dropFirst(3).prefix(12))
        guard recent.count >= 2, baseline.count >= 4 else { return [] }

        let recentAverage = average(recent.map(\.sentiment))
        let baselineAverage = average(baseline.map(\.sentiment))
        guard recentAverage - baselineAverage >= 0.25, recentAverage >= 0.25 else { return [] }

        return [
            ReflectionInsight(
                id: stableID("carry-forward-\(recent.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .medium,
                title: "A lighter pattern is worth carrying forward",
                message: "Your journal noticed your recent entries feel lighter than your usual baseline.",
                prompt: "What helped, and how can you protect more of it?",
                evidence: evidenceSet(source: recent.prefix(3), baseline: baseline.prefix(3)),
                kind: .carryForward,
                feedbackKey: feedbackKey(kind: .carryForward, subject: "lighter pattern", window: "recent"),
                explanation: "Shown because the last few entries are noticeably lighter than your earlier baseline.",
                confidence: recentAverage - baselineAverage >= 0.40 ? .high : .medium,
                suggestedQuestion: "What helped my recent entries feel lighter?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    public static func extractDecisionMoments(
        from entries: [ReflectionEntrySnapshot],
        existingFollowUps: [DecisionFollowUpState] = [],
        now: Date = Date()
    ) -> [DecisionMoment] {
        var followUpByKey: [String: DecisionFollowUpState] = [:]
        for followUp in existingFollowUps {
            followUpByKey["\(followUp.sourceEntryID.uuidString)-\(followUp.phraseHash)"] = followUp
        }

        return entries.flatMap { entry in
            sentences(in: entry.text).compactMap { sentence -> DecisionMoment? in
                let lower = sentence.lowercased()
                let kind: DecisionMoment.Kind
                if containsAny(lower, ["i regret", "i wish", "i should have", "i shouldn't have", "i should not have"]) {
                    kind = .regret
                } else if containsAny(lower, ["i decided", "i chose", "i choose", "i picked", "i committed to"]) {
                    kind = .decision
                } else {
                    return nil
                }

                let phrase = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard phrase.split(separator: " ").count >= 4 else { return nil }
                let phraseHash = stableID(phrase.lowercased())
                let decisionID = stableID("\(entry.id)-\(phraseHash)")
                let key = "\(entry.id.uuidString)-\(phraseHash)"
                let existing = followUpByKey[key]
                let followUp = existing ?? DecisionFollowUpState(
                    id: stableID("follow-up-\(decisionID)"),
                    decisionID: decisionID,
                    sourceEntryID: entry.id,
                    phraseHash: phraseHash,
                    state: .pending,
                    firstSeenAt: now,
                    lastPromptedAt: nil,
                    resolvedAt: nil
                )

                return DecisionMoment(
                    id: decisionID,
                    kind: kind,
                    phrase: phrase,
                    phraseHash: phraseHash,
                    entryID: entry.id,
                    date: entry.date,
                    topicKeywords: topicKeywords(in: phrase, limit: 4),
                    sentiment: entry.sentiment,
                    followUpDueAt: Calendar.current.date(byAdding: .day, value: 2, to: entry.date) ?? entry.date,
                    followUp: followUp
                )
            }
        }
    }

    public static func makeWeeklyRecap(from entries: [ReflectionEntrySnapshot], decisions: [DecisionMoment], now: Date = Date()) -> WeeklyReflectionRecap? {
        let currentWeek = entries.filter { now.timeIntervalSince($0.date) >= 0 && now.timeIntervalSince($0.date) <= currentWeekWindow }
        let previousWeek = entries.filter {
            let age = now.timeIntervalSince($0.date)
            return age > currentWeekWindow && age <= previousWeekWindow
        }

        guard currentWeek.count >= 2 else { return nil }
        let currentWords = currentWeek.reduce(0) { $0 + $1.wordCount }
        let previousWords = previousWeek.reduce(0) { $0 + $1.wordCount }
        let currentMood = average(currentWeek.map(\.sentiment))
        let previousMood = average(previousWeek.map(\.sentiment))
        let moodDelta = currentMood - previousMood
        let topics = topTopics(in: currentWeek, limit: 4)
        let weekDecisions = decisions.filter { now.timeIntervalSince($0.date) <= currentWeekWindow }

        let moodLine: String
        if previousWeek.isEmpty {
            moodLine = "Your journal has enough from this week to start a gentle recap."
        } else if moodDelta > 0.12 {
            moodLine = "This week reads a little lighter than last week."
        } else if moodDelta < -0.12 {
            moodLine = "This week reads a little heavier than last week."
        } else {
            moodLine = "Your emotional tone stayed fairly steady this week."
        }

        let volumeLine: String
        if previousWeek.isEmpty {
            volumeLine = "You wrote \(currentWeek.count) entries and \(currentWords) words."
        } else if currentWords > previousWords {
            volumeLine = "You wrote more than last week."
        } else if currentWords < previousWords {
            volumeLine = "You wrote less than last week."
        } else {
            volumeLine = "Your writing volume matched last week."
        }

        let decisionLine = weekDecisions.isEmpty ? "" : " Your journal also noticed \(weekDecisions.count) decision or regret moment\(weekDecisions.count == 1 ? "" : "s")."
        let summary = "\(moodLine) \(volumeLine)\(decisionLine)"
        let prompt = weekDecisions.isEmpty
        ? "What pattern from this week do you want to carry forward?"
        : "Which decision from this week still deserves attention?"

        return WeeklyReflectionRecap(
            id: stableID("weekly-\(Calendar.current.component(.weekOfYear, from: now))-\(Calendar.current.component(.yearForWeekOfYear, from: now))"),
            summary: summary,
            suggestedPrompt: prompt,
            currentWeekEntryCount: currentWeek.count,
            previousWeekEntryCount: previousWeek.count,
            currentWordCount: currentWords,
            previousWordCount: previousWords,
            topTopics: topics,
            decisionCount: weekDecisions.count,
            evidence: Array(currentWeek.prefix(3)).map { evidence(from: $0, role: .source) },
            generatedAt: now
        )
    }

    public static func selectPrompt(
        insights: [ReflectionInsight],
        decisions: [DecisionMoment],
        weeklyRecap: WeeklyReflectionRecap?,
        entries: [ReflectionEntrySnapshot],
        now: Date = Date()
    ) -> ReflectionInsight? {
        if let unresolved = decisions
            .filter({ $0.followUp.state == .pending && $0.followUpDueAt <= now })
            .sorted(by: { $0.date > $1.date })
            .first,
           let entry = entries.first(where: { $0.id == unresolved.entryID }) {
            return ReflectionInsight(
                id: stableID("decision-prompt-\(unresolved.id)"),
                category: .prompt,
                priority: .high,
                title: unresolved.kind == .regret ? "A regret may need a softer second look" : "A decision is ready for a check-in",
                message: "Your journal noticed a recent \(unresolved.kind == .regret ? "regret" : "decision") that may be worth revisiting.",
                prompt: unresolved.kind == .regret ? "What would you do differently with what you know now?" : "How does that choice feel after a little distance?",
                evidence: [evidence(from: entry, role: .source)],
                kind: .decisionFollowUp,
                feedbackKey: feedbackKey(kind: .decisionFollowUp, subject: unresolved.phraseHash, window: "follow-up"),
                explanation: "Shown because a recent \(unresolved.kind == .regret ? "regret" : "decision") is old enough for a check-in.",
                confidence: .high,
                suggestedQuestion: unresolved.kind == .regret ? "What regret should I revisit gently?" : "Which decision is ready for a check-in?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now),
                decisionID: unresolved.id
            )
        }

        if let high = insights.filter({ $0.priority == .high }).sorted(by: { $0.createdAt > $1.createdAt }).first {
            return high
        }

        if let weeklyRecap {
            return ReflectionInsight(
                id: stableID("weekly-prompt-\(weeklyRecap.id)"),
                category: .prompt,
                priority: .medium,
                title: "Your week has a thread worth naming",
                message: "Your journal prepared a gentle weekly reflection from your recent entries.",
                prompt: weeklyRecap.suggestedPrompt,
                evidence: weeklyRecap.evidence,
                kind: .weeklyRecap,
                feedbackKey: feedbackKey(kind: .weeklyRecap, subject: weeklyRecap.id, window: "week"),
                explanation: "Shown because there are enough recent entries for a weekly reflection.",
                confidence: weeklyRecap.previousWeekEntryCount >= 2 ? .high : .medium,
                suggestedQuestion: "What thread from this week is worth naming?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 3, to: now)
            )
        }

        return nil
    }

    public static func sentimentScore(text: String, mood: String?) -> Double {
        ReflectionSentiment.score(text: text, mood: mood)
    }

    public static func evidence(from entry: ReflectionEntrySnapshot, role: ReflectionEvidence.Role = .source) -> ReflectionEvidence {
        ReflectionEvidence(
            id: stableID("\(entry.id)-\(entry.date.timeIntervalSince1970)-\(role.rawValue)"),
            entryID: entry.id,
            date: entry.date,
            mood: entry.mood,
            role: role
        )
    }

    public static func snippet(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard collapsed.count > 150 else { return collapsed }
        return String(collapsed.prefix(147)) + "..."
    }

    public static func stableID(_ value: String) -> String {
        TextSignals.hash(value).prefix(16).description
    }

    public static func feedbackKey(kind: ReflectionInsight.Kind, subject: String? = nil, window: String? = nil) -> String {
        let parts = [
            kind.rawValue,
            subject.map(normalizedFeedbackSubject),
            window.map(normalizedFeedbackSubject)
        ].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: ":")
    }

    private static func normalizedFeedbackSubject(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
        return collapsed.isEmpty ? "general" : collapsed
    }

    private static func detectSentimentAnomaly(in sortedEntries: [ReflectionEntrySnapshot], now: Date) -> [ReflectionInsight] {
        let recentCandidates = Array(sortedEntries.prefix(3))
        for latest in recentCandidates {
            let baseline = sortedEntries.filter { $0.id != latest.id }.prefix(30)
            guard baseline.count >= minimumAnomalyEntries - 1 else { continue }
            let baselineSentiments = baseline.map(\.sentiment)
            let sentimentDelta = latest.sentiment - average(baselineSentiments)
            let sentimentZScore = zScore(value: latest.sentiment, baseline: baselineSentiments)
            guard abs(sentimentZScore ?? 0) >= 1.8 || abs(sentimentDelta) >= 0.35 else { continue }
            let heavier = sentimentDelta < 0
            return [
                ReflectionInsight(
                    id: stableID("sentiment-\(latest.id)-\(heavier)"),
                    category: .pattern,
                    priority: .high,
                    title: heavier ? "This entry felt heavier than usual" : "This entry felt lighter than usual",
                    message: heavier
                    ? "Your journal noticed this entry's tone sits outside your recent baseline."
                    : "Your journal noticed this entry's tone is lighter than your recent baseline.",
                    prompt: heavier ? "What changed the emotional weight of this entry?" : "What helped this entry feel lighter?",
                    evidence: evidenceSet(source: [latest], baseline: baseline.prefix(3)),
                    kind: .moodAssociation,
                    feedbackKey: feedbackKey(kind: .moodAssociation, subject: heavier ? "heavier entry" : "lighter entry", window: "recent baseline"),
                    explanation: "Shown because this entry's emotional tone sits outside your recent baseline.",
                    confidence: abs(sentimentZScore ?? 0) >= 2.2 ? .high : .medium,
                    suggestedQuestion: heavier ? "Why did this entry feel heavier than usual?" : "What helped this entry feel lighter than usual?",
                    createdAt: now,
                    expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
                )
            ]
        }
        return []
    }

    private static func detectVolumeAnomaly(in sortedEntries: [ReflectionEntrySnapshot], now: Date) -> [ReflectionInsight] {
        let latest = sortedEntries[0]
        let baseline = Array(sortedEntries.dropFirst().prefix(30))
        let baselineWordCounts = baseline.map { Double($0.wordCount) }
        let wordZScore = zScore(value: Double(latest.wordCount), baseline: baselineWordCounts)
        let baselineAverage = average(baselineWordCounts)
        let absoluteDelta = Double(latest.wordCount) - baselineAverage
        let flatBaselineOutlier = wordZScore == nil && abs(absoluteDelta) >= max(35, baselineAverage * 1.8)
        guard abs(wordZScore ?? 0) >= 1.8 || flatBaselineOutlier else {
            return []
        }

        let more = (wordZScore ?? absoluteDelta) > 0
        return [
            ReflectionInsight(
                id: stableID("volume-\(latest.id)-\(more)"),
                category: .pattern,
                priority: .medium,
                title: more ? "You had more to say than usual" : "You wrote less than usual",
                message: more
                ? "Your journal noticed this entry was longer than your recent baseline."
                : "Your journal noticed this entry was shorter than your recent baseline.",
                prompt: more ? "What needed the extra space today?" : "Was there something you held back today?",
                evidence: evidenceSet(source: [latest], baseline: baseline.prefix(3)),
                kind: .volumeChange,
                feedbackKey: feedbackKey(kind: .volumeChange, subject: more ? "more words" : "fewer words", window: "recent baseline"),
                explanation: "Shown because this entry's length differs from your recent writing baseline.",
                confidence: abs(wordZScore ?? 0) >= 2.2 ? .high : .medium,
                suggestedQuestion: more ? "When do I write much more than usual?" : "When do I go quieter than usual?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    private static func detectTrajectoryAnomaly(in sortedEntries: [ReflectionEntrySnapshot], now: Date) -> [ReflectionInsight] {
        let recent = Array(sortedEntries.prefix(5)).reversed()
        guard recent.count == 5, recent.map(\.sentiment).isStrictlyDescending else { return [] }
        return [
            ReflectionInsight(
                id: stableID("trajectory-\(recent.map(\.id.uuidString).joined())"),
                category: .pattern,
                priority: .high,
                title: "A downward mood pattern is forming",
                message: "Your journal noticed the last few entries have each felt a little heavier.",
                prompt: "What support would make the next few days easier?",
                evidence: recent.map { evidence(from: $0, role: .trajectory) },
                kind: .moodTrajectory,
                feedbackKey: feedbackKey(kind: .moodTrajectory, subject: "downward", window: "five entries"),
                explanation: "Shown because five consecutive entries moved in a heavier direction.",
                confidence: .high,
                suggestedQuestion: "What has been making my recent entries feel heavier?",
                createdAt: now,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
            )
        ]
    }

    private static func makeDecisionInsights(from decisions: [DecisionMoment], entries: [ReflectionEntrySnapshot], now: Date) -> [ReflectionInsight] {
        decisions
            .filter { now.timeIntervalSince($0.date) <= currentWeekWindow && $0.followUp.state != .dismissed }
            .prefix(2)
            .compactMap { decision in
                guard let entry = entries.first(where: { $0.id == decision.entryID }) else { return nil }
                return ReflectionInsight(
                    id: stableID("decision-\(decision.id)"),
                    category: .decision,
                    priority: decision.kind == .regret ? .high : .medium,
                    title: decision.kind == .regret ? "Your journal noticed a regret thread" : "Your journal noticed a decision point",
                    message: decision.kind == .regret
                    ? "There is a recent moment where you seemed to be replaying a choice."
                    : "There is a recent choice that may be worth tracking after a little distance.",
                    prompt: decision.kind == .regret ? "What would a kinder next step look like from here?" : "What outcome will tell you this was the right choice?",
                    evidence: [evidence(from: entry, role: .source)],
                    kind: .decisionFollowUp,
                    feedbackKey: feedbackKey(kind: .decisionFollowUp, subject: decision.phraseHash, window: "recent"),
                    explanation: "Shown because this entry contains a \(decision.kind == .regret ? "regret" : "decision") that may benefit from a later check-in.",
                    confidence: .high,
                    suggestedQuestion: decision.kind == .regret ? "What regret have I been replaying?" : "What decision should I check in on?",
                    createdAt: now,
                    expiresAt: Calendar.current.date(byAdding: .day, value: 10, to: now),
                    decisionID: decision.id
                )
            }
    }

    private static func makeWeeklyInsight(_ recap: WeeklyReflectionRecap, now: Date) -> ReflectionInsight {
        ReflectionInsight(
            id: stableID("weekly-insight-\(recap.id)"),
            category: .weekly,
            priority: .medium,
            title: "Your weekly pattern recap is ready",
            message: recap.summary,
            prompt: recap.suggestedPrompt,
            evidence: recap.evidence,
            kind: .weeklyRecap,
            feedbackKey: feedbackKey(kind: .weeklyRecap, subject: recap.id, window: "week"),
            explanation: "Shown because the local reflection engine found enough entries from this week to compare with your recent rhythm.",
            confidence: recap.previousWeekEntryCount >= 2 ? .high : .medium,
            suggestedQuestion: "What pattern from this week should I carry forward?",
            createdAt: now,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
        )
    }

    private static func evidenceSet<S: Sequence, B: Sequence>(
        source: S,
        baseline: B
    ) -> [ReflectionEvidence] where S.Element == ReflectionEntrySnapshot, B.Element == ReflectionEntrySnapshot {
        source.map { evidence(from: $0, role: .source) } + baseline.map { evidence(from: $0, role: .baseline) }
    }

    private static func zScore(value: Double, baseline: [Double]) -> Double? {
        guard baseline.count >= 3 else { return nil }
        let mean = average(baseline)
        let variance = baseline.reduce(0) { $0 + pow($1 - mean, 2) } / Double(baseline.count)
        let stdDev = sqrt(variance)
        guard stdDev > 0.0001 else { return nil }
        return (value - mean) / stdDev
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func averageGaps(in entries: [ReflectionEntrySnapshot]) -> Double {
        let ascending = entries.sorted { $0.date < $1.date }
        guard ascending.count > 1 else { return 0 }
        let gaps = zip(ascending.dropFirst(), ascending).map { newer, older in
            newer.date.timeIntervalSince(older.date) / (24 * 60 * 60)
        }
        return average(gaps)
    }

    private static func ageInDays(_ date: Date, now: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0)
    }

    private static func sentences(in text: String) -> [String] {
        text.split(whereSeparator: { ".!?\n".contains($0) }).map(String.init)
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func topicKeywords(in text: String, limit: Int) -> [String] {
        let words = text
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation || $0.isNewline }
            .map(String.init)
            .filter { $0.count > 4 && !ReflectionStopWords.words.contains($0) }
        return Array(NSOrderedSet(array: words).compactMap { $0 as? String }.prefix(limit))
    }

    private static func themeKeywords(in text: String) -> [String] {
        let topics = topicKeywords(in: text, limit: 12)
        let entities = TextSignals.extractEntities(from: text)
            .map { $0.lowercased() }
            .filter { $0.count > 2 && !ReflectionStopWords.words.contains($0) }
        return Array(NSOrderedSet(array: topics + entities).compactMap { $0 as? String })
    }

    private static func themeBuckets(in entries: [ReflectionEntrySnapshot]) -> [String: [ReflectionEntrySnapshot]] {
        var buckets: [String: [ReflectionEntrySnapshot]] = [:]
        for entry in entries {
            for theme in Set(themeKeywords(in: entry.text)) {
                buckets[theme, default: []].append(entry)
            }
        }
        return buckets
    }

    private static func questionTopics(in text: String) -> [String] {
        let questionLeads = ["what", "why", "how", "when", "where", "who", "should", "could", "can", "do", "does", "am", "is"]
        return sentencesWithTerminators(in: text).flatMap { sentence -> [String] in
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            let lower = trimmed.lowercased()
            let firstWord = lower.split { !$0.isLetter }.first.map(String.init)
            guard trimmed.contains("?") || firstWord.map({ questionLeads.contains($0) }) == true else { return [] }
            return Array(topicKeywords(in: lower, limit: 2).prefix(2))
        }
    }

    private static func sentencesWithTerminators(in text: String) -> [String] {
        var results: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if ".!?\n".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { results.append(trimmed) }
                current = ""
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { results.append(trimmed) }
        return results
    }

    private static func topTopics(in entries: [ReflectionEntrySnapshot], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries {
            topicKeywords(in: entry.text, limit: 12).forEach { counts[$0, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key.capitalized }
    }
}

private enum ReflectionStopWords {
    public static let words: Set<String> = [
        "about", "after", "again", "because", "before", "could", "every", "everyone",
        "feels", "going", "their", "there", "these", "thing", "things", "today",
        "tomorrow", "would", "should", "really", "still", "where", "which", "while",
        "project", "entry", "journal", "friday"
    ]
}

private extension Array where Element == Double {
    var isStrictlyDescending: Bool {
        guard count > 1 else { return false }
        for index in 1..<count where self[index] >= self[index - 1] {
            return false
        }
        return true
    }
}
