import Foundation

public enum PulseDimension: String, Codable, CaseIterable, Hashable {
    case execution
    case integrity
    case focus
    case routine
    case attention
    case recovery
}

public enum PulseSourceKind: String, Codable, Hashable {
    case task
    case habit
    case focus
    case replan
    case meeting
    case telemetry
    case reflection
    case weekly
}

public struct PulseContribution: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let dimension: PulseDimension
    public let title: String
    public let explanation: String
    public let delta: Int
    public let sourceKind: PulseSourceKind
    public let sourceID: String?
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        dimension: PulseDimension,
        title: String,
        explanation: String,
        delta: Int,
        sourceKind: PulseSourceKind,
        sourceID: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.dimension = dimension
        self.title = title
        self.explanation = explanation
        self.delta = delta
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.timestamp = timestamp
    }
}

public struct PulseDimensionScore: Codable, Equatable, Hashable {
    public let dimension: PulseDimension
    public let score: Int
    public let weight: Int
    public let contributions: [PulseContribution]

    public init(
        dimension: PulseDimension,
        score: Int,
        weight: Int,
        contributions: [PulseContribution] = []
    ) {
        self.dimension = dimension
        self.score = score
        self.weight = weight
        self.contributions = contributions
    }
}

public enum OpportunityActionKind: String, Codable, Hashable {
    case completeTask
    case startFocus
    case rescueTask
    case rescheduleTask
    case dropTask
    case rescueHabit
    case reflection
    case runWeeklyPlan
    case runWeeklyReview
}

public enum RewardBehaviorType: String, Codable, CaseIterable, Hashable {
    case execution
    case clarity
    case courage
    case consistency
    case focus
    case recovery
    case planning
    case reflection
}

public enum RewardDirection: String, Codable, Hashable {
    case positive
    case negative
    case neutral
}

public struct RewardBreakdownLine: Codable, Equatable, Hashable, Identifiable {
    public let key: String
    public let title: String
    public let value: String
    public let direction: RewardDirection

    public init(
        key: String,
        title: String,
        value: String,
        direction: RewardDirection
    ) {
        self.key = key
        self.title = title
        self.value = value
        self.direction = direction
    }

    public var id: String { key }
}

public struct RewardQuote: Codable, Equatable, Hashable {
    public let estimatedXP: Int
    public let estimatedFocusCredits: Int
    public let estimatedPulseDelta: Int
    public let behaviorType: RewardBehaviorType
    public let breakdown: [RewardBreakdownLine]
    public let reservedUntil: Date?
    public let reservationID: UUID?

    public init(
        estimatedXP: Int,
        estimatedFocusCredits: Int,
        estimatedPulseDelta: Int,
        behaviorType: RewardBehaviorType,
        breakdown: [RewardBreakdownLine],
        reservedUntil: Date? = nil,
        reservationID: UUID? = nil
    ) {
        self.estimatedXP = estimatedXP
        self.estimatedFocusCredits = estimatedFocusCredits
        self.estimatedPulseDelta = estimatedPulseDelta
        self.behaviorType = behaviorType
        self.breakdown = breakdown
        self.reservedUntil = reservedUntil
        self.reservationID = reservationID
    }
}

public struct PulseOpportunity: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let explanation: String
    public let estimatedPulseDelta: Int
    public let rewardQuote: RewardQuote
    public let actionKind: OpportunityActionKind
    public let targetID: String?
    public let confidence: Double
    public let expiresAt: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        explanation: String,
        estimatedPulseDelta: Int,
        rewardQuote: RewardQuote,
        actionKind: OpportunityActionKind,
        targetID: String? = nil,
        confidence: Double = 1,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.estimatedPulseDelta = estimatedPulseDelta
        self.rewardQuote = rewardQuote
        self.actionKind = actionKind
        self.targetID = targetID
        self.confidence = confidence
        self.expiresAt = expiresAt
    }
}

public struct PulseSnapshot: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let date: Date
    public let overallScore: Int
    public let previousScore: Int?
    public let level: Int
    public let focusCreditBalance: Int
    public let dimensions: [PulseDimensionScore]
    public let strongestPositives: [PulseContribution]
    public let strongestNegatives: [PulseContribution]
    public let opportunities: [PulseOpportunity]
    public let confidence: Double
    public let attentionTelemetryAvailable: Bool
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        overallScore: Int,
        previousScore: Int? = nil,
        level: Int = 1,
        focusCreditBalance: Int = 0,
        dimensions: [PulseDimensionScore],
        strongestPositives: [PulseContribution],
        strongestNegatives: [PulseContribution],
        opportunities: [PulseOpportunity],
        confidence: Double,
        attentionTelemetryAvailable: Bool,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.overallScore = overallScore
        self.previousScore = previousScore
        self.level = level
        self.focusCreditBalance = focusCreditBalance
        self.dimensions = dimensions
        self.strongestPositives = strongestPositives
        self.strongestNegatives = strongestNegatives
        self.opportunities = opportunities
        self.confidence = confidence
        self.attentionTelemetryAvailable = attentionTelemetryAvailable
        self.generatedAt = generatedAt
    }
}

public struct RewardGrant: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let xp: Int
    public let focusCredits: Int
    public let behaviorType: RewardBehaviorType
    public let reason: String
    public let idempotencyKey: String
    public let sourceEventID: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        xp: Int,
        focusCredits: Int,
        behaviorType: RewardBehaviorType,
        reason: String,
        idempotencyKey: String,
        sourceEventID: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.xp = xp
        self.focusCredits = focusCredits
        self.behaviorType = behaviorType
        self.reason = reason
        self.idempotencyKey = idempotencyKey
        self.sourceEventID = sourceEventID
    }
}

public struct FocusCreditLedgerEntry: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let delta: Int
    public let reason: String
    public let sourceEventID: String
    public let behaviorType: RewardBehaviorType?
    public let balanceAfter: Int

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        delta: Int,
        reason: String,
        sourceEventID: String,
        behaviorType: RewardBehaviorType? = nil,
        balanceAfter: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.delta = delta
        self.reason = reason
        self.sourceEventID = sourceEventID
        self.behaviorType = behaviorType
        self.balanceAfter = balanceAfter
    }
}

public enum QuestKind: String, Codable, Hashable {
    case daily
    case weekly
}

public struct QuestInstance: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let kind: QuestKind
    public let startsAt: Date
    public let endsAt: Date
    public let progress: Int
    public let target: Int
    public let rewardXP: Int
    public let rewardFocusCredits: Int
    public let isCompleted: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        kind: QuestKind,
        startsAt: Date,
        endsAt: Date,
        progress: Int,
        target: Int,
        rewardXP: Int,
        rewardFocusCredits: Int,
        isCompleted: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.progress = progress
        self.target = target
        self.rewardXP = rewardXP
        self.rewardFocusCredits = rewardFocusCredits
        self.isCompleted = isCompleted
    }
}
