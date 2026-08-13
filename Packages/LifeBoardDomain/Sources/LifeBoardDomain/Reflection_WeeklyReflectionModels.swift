//
//  WeeklyReflectionModels.swift
//  ReflectionKit
//
//  Shared weekly-reflection vocabulary: safety ladder, eligibility, evidence
//  references, themes, and the report envelope. Processing stays local-only.
//

import Foundation

public enum WeeklyReflectionProcessingMode: String, Codable, Sendable {
    case local
}

public enum WeeklyReflectionStatus: String, Codable, Sendable {
    case ready
    case seen
    case dismissed
    case superseded
    case deleted
    case insufficientData
    case failed
}

public enum WeeklyReflectionSafetyLevel: String, Codable, Sendable {
    case none
    case mildDistress
    case moderateConcern
    case highRiskExcluded
}

public enum WeeklyReflectionEligibilityKind: String, Codable, Sendable {
    case full
    case light
    case empty
}

public enum WeeklyReflectionSourceType: String, Codable, Sendable {
    case text
    case voiceTranscript
    case photoNote
}

public struct WeeklyReflectionSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var reminderWeekday: Int
    public var reminderHour: Int
    public var reminderMinute: Int
    public var showHomeCard: Bool
    public var sendNotification: Bool

    public init(
        isEnabled: Bool,
        reminderWeekday: Int,
        reminderHour: Int,
        reminderMinute: Int,
        showHomeCard: Bool,
        sendNotification: Bool
    ) {
        self.isEnabled = isEnabled
        self.reminderWeekday = reminderWeekday
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.showHomeCard = showHomeCard
        self.sendNotification = sendNotification
    }

    public static let `default` = WeeklyReflectionSettings(
        isEnabled: true,
        reminderWeekday: 1,
        reminderHour: 19,
        reminderMinute: 0,
        showHomeCard: true,
        sendNotification: true
    )
}

public struct WeeklyReflectionPeriod: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}

public struct WeeklyReflectionEligibility: Equatable, Sendable {
    public let kind: WeeklyReflectionEligibilityKind
    public let entryCount: Int
    public let wordCount: Int

    public init(kind: WeeklyReflectionEligibilityKind, entryCount: Int, wordCount: Int) {
        self.kind = kind
        self.entryCount = entryCount
        self.wordCount = wordCount
    }
}

public struct WeeklyReflectionEvidenceRef: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let entryId: UUID
    public let entryDate: Date
    public let sourceType: WeeklyReflectionSourceType
    public let quote: String?
    public let reason: String?

    public init(id: UUID, entryId: UUID, entryDate: Date, sourceType: WeeklyReflectionSourceType, quote: String?, reason: String?) {
        self.id = id
        self.entryId = entryId
        self.entryDate = entryDate
        self.sourceType = sourceType
        self.quote = quote
        self.reason = reason
    }
}

public struct WeeklyReflectionTheme: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var evidenceRefs: [WeeklyReflectionEvidenceRef]

    public init(id: UUID, title: String, summary: String, evidenceRefs: [WeeklyReflectionEvidenceRef]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.evidenceRefs = evidenceRefs
    }
}

public struct WeeklyReflectionEmotionalArc: Codable, Hashable, Sendable {
    public var label: String
    public var description: String

    public init(label: String, description: String) {
        self.label = label
        self.description = description
    }
}

public struct WeeklyReflectionReport: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let periodStart: Date
    public let periodEnd: Date
    public var generatedAt: Date
    public var versionNumber: Int
    public var processingMode: WeeklyReflectionProcessingMode
    public var status: WeeklyReflectionStatus
    public var eligibility: WeeklyReflectionEligibilityKind
    public var includedEntryIds: [UUID]
    public var hiddenEntryIds: [UUID]
    public var unavailableEntryIds: [UUID]
    public var privateEntryCount: Int
    public var inputSignature: String
    public var heroSentence: String
    public var summary: String
    public var emotionalArc: WeeklyReflectionEmotionalArc?
    public var themes: [WeeklyReflectionTheme]
    public var wins: [String]
    public var frictions: [String]
    public var questions: [String]
    public var savedTakeaway: String?
    public var safetyLevel: WeeklyReflectionSafetyLevel
    public var userMarkedHelpful: Bool?

    public init(
        id: UUID,
        periodStart: Date,
        periodEnd: Date,
        generatedAt: Date,
        versionNumber: Int,
        processingMode: WeeklyReflectionProcessingMode,
        status: WeeklyReflectionStatus,
        eligibility: WeeklyReflectionEligibilityKind,
        includedEntryIds: [UUID],
        hiddenEntryIds: [UUID],
        unavailableEntryIds: [UUID],
        privateEntryCount: Int,
        inputSignature: String,
        heroSentence: String,
        summary: String,
        emotionalArc: WeeklyReflectionEmotionalArc?,
        themes: [WeeklyReflectionTheme],
        wins: [String],
        frictions: [String],
        questions: [String],
        savedTakeaway: String?,
        safetyLevel: WeeklyReflectionSafetyLevel,
        userMarkedHelpful: Bool?
    ) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
        self.versionNumber = versionNumber
        self.processingMode = processingMode
        self.status = status
        self.eligibility = eligibility
        self.includedEntryIds = includedEntryIds
        self.hiddenEntryIds = hiddenEntryIds
        self.unavailableEntryIds = unavailableEntryIds
        self.privateEntryCount = privateEntryCount
        self.inputSignature = inputSignature
        self.heroSentence = heroSentence
        self.summary = summary
        self.emotionalArc = emotionalArc
        self.themes = themes
        self.wins = wins
        self.frictions = frictions
        self.questions = questions
        self.savedTakeaway = savedTakeaway
        self.safetyLevel = safetyLevel
        self.userMarkedHelpful = userMarkedHelpful
    }

    public var period: WeeklyReflectionPeriod {
        WeeklyReflectionPeriod(start: periodStart, end: periodEnd)
    }

    public var isVisibleInHistory: Bool {
        status != .deleted && status != .superseded
    }

    public var isVisibleOnHome: Bool {
        switch status {
        case .ready, .seen, .insufficientData, .failed:
            return true
        case .dismissed, .superseded, .deleted:
            return false
        }
    }
}

public struct WeeklyReflectionEntrySnapshot: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let updatedAt: Date
    public let mood: String?
    public let text: String
    public let wordCount: Int
    public let sourceType: WeeklyReflectionSourceType
    public let sentiment: Double

    public init(id: UUID, date: Date, updatedAt: Date, mood: String?, text: String, sourceType: WeeklyReflectionSourceType) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.date = date
        self.updatedAt = updatedAt
        self.mood = mood
        self.text = trimmed
        self.wordCount = trimmed.split { $0.isWhitespace || $0.isNewline }.count
        self.sourceType = sourceType
        self.sentiment = ReflectionSentiment.score(text: trimmed, mood: mood)
    }
}

/// Shared deterministic eligibility boundary used by every host app before
/// it creates a weekly reflection. The engine deliberately returns evidence
/// density only; host apps retain their own voice and visual composition.
public enum WeeklyReflectionEligibilityEngine {
    /// OffRecord's shipped weekly-reflection thresholds are the canonical
    /// contract for every JournalKit host. Fewer than 150 words is an empty
    /// reflection; three entries or 600 words unlocks the full reflection;
    /// everything in between is a light reflection.
    public static let minimumVisibleWordCount = 150
    public static let fullEntryCount = 3
    public static let fullWordCount = 600

    public static func evaluate(
        entries: [WeeklyReflectionEntrySnapshot],
        in period: WeeklyReflectionPeriod
    ) -> WeeklyReflectionEligibility {
        let eligible = entries.filter { period.contains($0.date) && !$0.text.isEmpty }
        let words = eligible.reduce(0) { $0 + $1.wordCount }
        let kind: WeeklyReflectionEligibilityKind
        if words < minimumVisibleWordCount {
            kind = .empty
        } else if eligible.count >= fullEntryCount || words >= fullWordCount {
            kind = .full
        } else {
            kind = .light
        }
        return WeeklyReflectionEligibility(kind: kind, entryCount: eligible.count, wordCount: words)
    }
}
