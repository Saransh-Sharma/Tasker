import Foundation

/// The three bounded decision rituals EVA can host outside chat.
public enum EvaDecisionRitualKind: String, Codable, CaseIterable, Hashable, Sendable {
    case makeItFitToday
    case frictionDetective
    case weeklyReset
}

/// Lightweight, restorable navigation state. The app deliberately persists IDs
/// and choices rather than copies of mutable task, plan, or calendar records.
public struct EvaRitualDraftReference: Codable, Equatable, Hashable, Sendable {
    public var kind: EvaDecisionRitualKind
    public var recordIDs: [UUID]
    public var referenceDate: Date
    public var phaseRaw: String
    public var choices: [String: String]
    public var actionRunID: UUID?
    public var updatedAt: Date

    public init(
        kind: EvaDecisionRitualKind,
        recordIDs: [UUID] = [],
        referenceDate: Date = Date(),
        phaseRaw: String,
        choices: [String: String] = [:],
        actionRunID: UUID? = nil,
        updatedAt: Date = Date()
    ) {
        self.kind = kind
        self.recordIDs = Array(Set(recordIDs))
            .sorted { $0.uuidString < $1.uuidString }
        self.referenceDate = referenceDate
        self.phaseRaw = phaseRaw
        self.choices = choices
        self.actionRunID = actionRunID
        self.updatedAt = updatedAt
    }
}

public enum FrictionReason: String, Codable, CaseIterable, Hashable, Sendable {
    case scopeTooLarge
    case nextStepUnclear
    case timingOrEnergy
    case blockedOrWaiting
    case interruptions
    case priorityChanged
    case other
}

public enum FrictionIntervention: String, Codable, CaseIterable, Hashable, Sendable {
    case clarifyNextAction
    case splitTask
    case reduceScope
    case moveToBetterWindow
    case moveLater
    case releaseToSomeday
    case noteDependency
}

public enum FrictionFindingOutcome: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case helped
    case didNotHelp
    case dismissed
}

/// A user-confirmed learning from Friction Detective.
///
/// Model hypotheses never enter this record. Custom prose lives in a linked
/// `ReflectionNote`, keeping the structured record useful without turning
/// sensitive reflection text into analytics or cloud context.
public struct FrictionFinding: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var taskID: UUID
    public var detectedAt: Date
    public var deferredCountAtDetection: Int
    public var replanCountAtDetection: Int
    public var evidence: [Insight.Evidence]
    public var selectedReason: FrictionReason
    public var customReflectionNoteID: UUID?
    public var intervention: FrictionIntervention
    public var actionRunID: UUID?
    public var reviewAfter: Date
    public var outcome: FrictionFindingOutcome
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        detectedAt: Date = Date(),
        deferredCountAtDetection: Int,
        replanCountAtDetection: Int,
        evidence: [Insight.Evidence],
        selectedReason: FrictionReason,
        customReflectionNoteID: UUID? = nil,
        intervention: FrictionIntervention,
        actionRunID: UUID? = nil,
        reviewAfter: Date,
        outcome: FrictionFindingOutcome = .pending,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.detectedAt = detectedAt
        self.deferredCountAtDetection = max(0, deferredCountAtDetection)
        self.replanCountAtDetection = max(0, replanCountAtDetection)
        self.evidence = evidence
        self.selectedReason = selectedReason
        self.customReflectionNoteID = customReflectionNoteID
        self.intervention = intervention
        self.actionRunID = actionRunID
        self.reviewAfter = reviewAfter
        self.outcome = outcome
        self.updatedAt = updatedAt
    }

    public var distinctEventCountFallback: Int {
        max(deferredCountAtDetection, replanCountAtDetection)
    }
}

public struct FrictionFindingQuery: Codable, Equatable, Hashable, Sendable {
    public var taskID: UUID?
    public var outcomes: [FrictionFindingOutcome]
    public var reviewDueBefore: Date?
    public var limit: Int?

    public init(
        taskID: UUID? = nil,
        outcomes: [FrictionFindingOutcome] = [],
        reviewDueBefore: Date? = nil,
        limit: Int? = nil
    ) {
        self.taskID = taskID
        self.outcomes = outcomes
        self.reviewDueBefore = reviewDueBefore
        self.limit = limit
    }
}
