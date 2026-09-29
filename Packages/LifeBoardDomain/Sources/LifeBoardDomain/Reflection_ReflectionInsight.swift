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
        guard !evidence.isEmpty else { return String(localized: "From your journal.") }
        let count = evidence.count
        return count == 1
            ? String(localized: "Based on 1 entry.")
            : String(localized: "Based on \(count) entries.")
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
