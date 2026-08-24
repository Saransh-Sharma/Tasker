import Foundation

public enum ReflectionNoteKind: String, Codable, CaseIterable, Hashable, Sendable {
    case taskCompletion
    case weeklyReview
    case projectReflection
    case habitRecovery
    /// Optional private prose captured while the user confirms a Friction
    /// Detective finding. The structured reason lives in `FrictionFinding`.
    case frictionFinding
    case freeform
    /// The one line written when a day is closed.
    ///
    /// Additive and safe on older builds: `kind` is a free-form `String` column,
    /// so an older app degrades this to an untyped note rather than losing it.
    case dayClose
    /// Text migrated from the retired Sunrise Daily Reflection store.
    ///
    /// The original reflection date is retained in `createdAt`, while `prompt`
    /// carries a human-readable provenance label. No plan draft or completion
    /// marker is promoted into a Daily Loop receipt during this migration.
    case legacyDailyReflection
}

public struct ReflectionNote: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: ReflectionNoteKind
    public var linkedTaskID: UUID?
    public var linkedProjectID: UUID?
    public var linkedHabitID: UUID?
    public var linkedWeeklyPlanID: UUID?
    public var energy: Int?
    public var mood: Int?
    public var prompt: String?
    public var noteText: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kind: ReflectionNoteKind = .freeform,
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        energy: Int? = nil,
        mood: Int? = nil,
        prompt: String? = nil,
        noteText: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.energy = energy
        self.mood = mood
        self.prompt = prompt
        self.noteText = noteText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReflectionNoteQuery: Codable, Equatable, Hashable, Sendable {
    public var linkedTaskID: UUID?
    public var linkedProjectID: UUID?
    public var linkedHabitID: UUID?
    public var linkedWeeklyPlanID: UUID?
    public var kinds: [ReflectionNoteKind]
    public var limit: Int?

    public init(
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        kinds: [ReflectionNoteKind] = [],
        limit: Int? = nil
    ) {
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.kinds = kinds
        self.limit = limit
    }
}
