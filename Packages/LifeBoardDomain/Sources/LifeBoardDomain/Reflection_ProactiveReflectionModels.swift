//
//  ProactiveReflectionModels.swift
//  ReflectionKit
//
//  Shared, deterministic proactive reflection vocabulary and analyzer.
//  Host apps own persistence, scheduling, assistant naming, and presentation.
//

import Foundation

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
                title: isLongSilence ? String(localized: "Fewer entries lately") : String(localized: "More entries lately"),
                message: isLongSilence
                ? String(localized: "More days between entries than before.")
                : String(localized: "Entries are closer together than before."),
                prompt: isLongSilence ? String(localized: "What got in the way of writing?") : String(localized: "What brought you back to writing?"),
                evidence: evidenceSet(source: recent.prefix(2), baseline: baseline.prefix(3)),
                kind: .cadenceChange,
                feedbackKey: feedbackKey(kind: .cadenceChange, subject: isLongSilence ? "long silence" : "dense return", window: "recent rhythm"),
                explanation: isLongSilence
                ? String(localized: "Recent gaps are over twice as long as before.")
                : String(localized: "Recent gaps are under half as long as before."),
                confidence: .medium,
                suggestedQuestion: String(localized: "How has my journaling changed lately?"),
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
                title: String(localized: "New topics lately"),
                message: String(localized: "Recent entries cover different topics than before."),
                prompt: String(localized: "What changed recently?"),
                evidence: evidenceSet(source: recent, baseline: baseline.prefix(3)),
                kind: .contrast,
                feedbackKey: feedbackKey(kind: .contrast, subject: "topic shift", window: "recent"),
                explanation: String(localized: "Your last 3 entries share few topics with earlier ones."),
                confidence: .medium,
                suggestedQuestion: String(localized: "What new topics are in my journal?"),
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
                title: String(localized: "A recurring topic"),
                message: String(localized: "\(theme.key.capitalized) comes up in \(theme.value.count) recent entries."),
                prompt: String(localized: "What stands out about \(theme.key)?"),
                evidence: theme.value.prefix(4).map { evidence(from: $0, role: .source) },
                kind: .patternSignal,
                feedbackKey: feedbackKey(kind: .patternSignal, subject: theme.key, window: "recent theme"),
                explanation: String(localized: "Mentioned in \(theme.value.count) of your last \(recent.count) entries."),
                confidence: theme.value.count >= 4 ? .high : .medium,
                suggestedQuestion: String(localized: "What has been coming up around \(theme.key)?"),
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
                title: String(localized: "An older topic is back"),
                message: String(localized: "\(match.theme.capitalized) appears in recent and older entries."),
                prompt: String(localized: "What feels different about \(match.theme) now?"),
                evidence: evidenceSet(source: match.recent.prefix(2), baseline: match.older.prefix(3)),
                kind: .resurfacedThread,
                feedbackKey: feedbackKey(kind: .resurfacedThread, subject: match.theme, window: "28d"),
                explanation: String(localized: "Also in \(match.older.count) entries from 4 or more weeks ago."),
                confidence: match.older.count >= 3 ? .high : .medium,
                suggestedQuestion: String(localized: "How has \(match.theme) changed since I first wrote about it?"),
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
                title: String(localized: "Same topic, different feeling"),
                message: lighter
                ? String(localized: "\(match.theme.capitalized) reads lighter than before.")
                : String(localized: "\(match.theme.capitalized) reads heavier than before."),
                prompt: lighter ? String(localized: "What helped this feel lighter?") : String(localized: "What feels heavier about \(match.theme) now?"),
                evidence: evidenceSet(source: match.recentEntries.prefix(2), baseline: match.previousEntries.prefix(3)),
                kind: .contrast,
                feedbackKey: feedbackKey(kind: .contrast, subject: match.theme, window: "60d"),
                explanation: String(localized: "Compared with \(match.previousEntries.count) earlier entries about \(match.theme)."),
                confidence: abs(match.delta) >= 0.45 ? .high : .medium,
                suggestedQuestion: String(localized: "How has my feeling about \(match.theme) changed?"),
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
                title: String(localized: "Not mentioned lately"),
                message: String(localized: "\(match.key) hasn’t come up in 2 weeks."),
                prompt: String(localized: "Anything on your mind about \(match.key)?"),
                evidence: match.value.prefix(3).map { evidence(from: $0, role: .baseline) },
                kind: .quietEntity,
                feedbackKey: feedbackKey(kind: .quietEntity, subject: match.key, window: "14d"),
                explanation: String(localized: "In \(match.value.count) earlier entries, none in the last 2 weeks."),
                confidence: .medium,
                suggestedQuestion: String(localized: "What has changed around \(match.key)?"),
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
                title: String(localized: "\(match.theme.capitalized) and your mood"),
                message: lifts
                ? String(localized: "Entries about \(match.theme) read lighter than usual.")
                : String(localized: "Entries about \(match.theme) read heavier than usual."),
                prompt: lifts ? String(localized: "How can you keep more of this?") : String(localized: "What would help with \(match.theme)?"),
                evidence: match.entries.prefix(4).map { evidence(from: $0, role: .source) },
                kind: .moodAssociation,
                feedbackKey: feedbackKey(kind: .moodAssociation, subject: match.theme, window: "45d"),
                explanation: String(localized: "Based on \(match.entries.count) entries from the last 45 days."),
                confidence: match.entries.count >= 4 ? .high : .medium,
                suggestedQuestion: lifts
                ? String(localized: "What seems to help me around \(match.theme)?")
                : String(localized: "What seems to drain me around \(match.theme)?"),
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
                title: String(localized: "A recurring question"),
                message: String(localized: "You asked about \(match.key) in \(match.value.count) entries."),
                prompt: String(localized: "What’s your answer today?"),
                evidence: match.value.prefix(3).map { evidence(from: $0, role: .source) },
                kind: .repeatedQuestion,
                feedbackKey: feedbackKey(kind: .repeatedQuestion, subject: match.key, window: "45d"),
                explanation: String(localized: "Based on entries from the last 45 days."),
                confidence: match.value.count >= 3 ? .high : .medium,
                suggestedQuestion: String(localized: "What question do I keep returning to around \(match.key)?"),
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
                title: String(localized: "Lighter entries lately"),
                message: String(localized: "Recent entries read lighter than usual."),
                prompt: String(localized: "What helped lately?"),
                evidence: evidenceSet(source: recent.prefix(3), baseline: baseline.prefix(3)),
                kind: .carryForward,
                feedbackKey: feedbackKey(kind: .carryForward, subject: "lighter pattern", window: "recent"),
                explanation: String(localized: "Your last \(recent.count) entries compared with \(baseline.count) earlier ones."),
                confidence: recentAverage - baselineAverage >= 0.40 ? .high : .medium,
                suggestedQuestion: String(localized: "What helped my recent entries feel lighter?"),
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
}

extension ProactiveReflectionAnalyzer {
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
            moodLine = String(localized: "\(currentWeek.count) entries this week.")
        } else if moodDelta > 0.12 {
            moodLine = String(localized: "Lighter than last week.")
        } else if moodDelta < -0.12 {
            moodLine = String(localized: "Heavier than last week.")
        } else {
            moodLine = String(localized: "Similar tone to last week.")
        }

        let volumeLine: String
        if previousWeek.isEmpty {
            volumeLine = String(localized: "\(currentWords) words.")
        } else if currentWords > previousWords {
            volumeLine = String(localized: "You wrote more.")
        } else if currentWords < previousWords {
            volumeLine = String(localized: "You wrote less.")
        } else {
            volumeLine = String(localized: "You wrote about the same.")
        }

        let decisionLine: String
        switch weekDecisions.count {
        case 0: decisionLine = ""
        case 1: decisionLine = " " + String(localized: "1 decision noted.")
        default: decisionLine = " " + String(localized: "\(weekDecisions.count) decisions noted.")
        }
        let summary = "\(moodLine) \(volumeLine)\(decisionLine)"
        let prompt = weekDecisions.isEmpty
        ? String(localized: "What do you want to keep from this week?")
        : String(localized: "Which decision needs another look?")

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
                title: unresolved.kind == .regret ? String(localized: "Revisit a regret") : String(localized: "Check in on a decision"),
                message: unresolved.kind == .regret
                ? String(localized: "A regret from a recent entry.")
                : String(localized: "A decision from a recent entry."),
                prompt: unresolved.kind == .regret ? String(localized: "What would you do differently now?") : String(localized: "How does that choice feel now?"),
                evidence: [evidence(from: entry, role: .source)],
                kind: .decisionFollowUp,
                feedbackKey: feedbackKey(kind: .decisionFollowUp, subject: unresolved.phraseHash, window: "follow-up"),
                explanation: String(localized: "Written at least 2 days ago."),
                confidence: .high,
                suggestedQuestion: unresolved.kind == .regret ? String(localized: "What regret should I revisit?") : String(localized: "Which decision should I check in on?"),
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
                title: String(localized: "A question for this week"),
                message: weeklyRecap.suggestedPrompt,
                prompt: weeklyRecap.suggestedPrompt,
                evidence: weeklyRecap.evidence,
                kind: .weeklyRecap,
                feedbackKey: feedbackKey(kind: .weeklyRecap, subject: weeklyRecap.id, window: "week"),
                explanation: String(localized: "Based on \(weeklyRecap.currentWeekEntryCount) entries this week."),
                confidence: weeklyRecap.previousWeekEntryCount >= 2 ? .high : .medium,
                suggestedQuestion: String(localized: "What stood out in my week?"),
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
        return String(collapsed.prefix(147)) + "…"
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
                    title: heavier ? String(localized: "A heavier entry") : String(localized: "A lighter entry"),
                    message: heavier
                    ? String(localized: "Heavier in tone than your recent entries.")
                    : String(localized: "Lighter in tone than your recent entries."),
                    prompt: heavier ? String(localized: "What felt heavy today?") : String(localized: "What went well today?"),
                    evidence: evidenceSet(source: [latest], baseline: baseline.prefix(3)),
                    kind: .moodAssociation,
                    feedbackKey: feedbackKey(kind: .moodAssociation, subject: heavier ? "heavier entry" : "lighter entry", window: "recent baseline"),
                    explanation: String(localized: "Compared with your last \(baseline.count) entries."),
                    confidence: abs(sentimentZScore ?? 0) >= 2.2 ? .high : .medium,
                    suggestedQuestion: heavier ? String(localized: "Why did this entry feel heavier than usual?") : String(localized: "What helped this entry feel lighter than usual?"),
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
                title: more ? String(localized: "A longer entry") : String(localized: "A shorter entry"),
                message: more
                ? String(localized: "Longer than your recent entries.")
                : String(localized: "Shorter than your recent entries."),
                prompt: more ? String(localized: "What was on your mind?") : String(localized: "Anything you want to add?"),
                evidence: evidenceSet(source: [latest], baseline: baseline.prefix(3)),
                kind: .volumeChange,
                feedbackKey: feedbackKey(kind: .volumeChange, subject: more ? "more words" : "fewer words", window: "recent baseline"),
                explanation: String(localized: "Compared with your last \(baseline.count) entries."),
                confidence: abs(wordZScore ?? 0) >= 2.2 ? .high : .medium,
                suggestedQuestion: more ? String(localized: "When do I write much more than usual?") : String(localized: "When do I write less than usual?"),
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
                title: String(localized: "A heavier stretch"),
                message: String(localized: "Your last 5 entries each read a little heavier."),
                prompt: String(localized: "What would help this week?"),
                evidence: recent.map { evidence(from: $0, role: .trajectory) },
                kind: .moodTrajectory,
                feedbackKey: feedbackKey(kind: .moodTrajectory, subject: "downward", window: "five entries"),
                explanation: String(localized: "Based on your last 5 entries."),
                confidence: .high,
                suggestedQuestion: String(localized: "What’s been weighing on me lately?"),
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
                    title: decision.kind == .regret ? String(localized: "A regret you wrote about") : String(localized: "A decision you made"),
                    message: String(localized: "From an entry this week."),
                    prompt: decision.kind == .regret ? String(localized: "What’s a good next step?") : String(localized: "How will you know it worked?"),
                    evidence: [evidence(from: entry, role: .source)],
                    kind: .decisionFollowUp,
                    feedbackKey: feedbackKey(kind: .decisionFollowUp, subject: decision.phraseHash, window: "recent"),
                    explanation: decision.kind == .regret
                    ? String(localized: "Your entry mentions a regret.")
                    : String(localized: "Your entry mentions a decision."),
                    confidence: .high,
                    suggestedQuestion: decision.kind == .regret ? String(localized: "What regret have I been replaying?") : String(localized: "What decision should I check in on?"),
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
            title: String(localized: "This week so far"),
            message: recap.summary,
            prompt: recap.suggestedPrompt,
            evidence: recap.evidence,
            kind: .weeklyRecap,
            feedbackKey: feedbackKey(kind: .weeklyRecap, subject: recap.id, window: "week"),
            explanation: String(localized: "Based on \(recap.currentWeekEntryCount) entries this week."),
            confidence: recap.previousWeekEntryCount >= 2 ? .high : .medium,
            suggestedQuestion: String(localized: "What from this week should I keep doing?"),
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
