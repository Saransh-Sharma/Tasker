import Foundation

public enum ReflectionNoteKind: String, Codable, CaseIterable, Hashable {
    case taskCompletion
    case weeklyReview
    case projectReflection
    case habitRecovery
    case freeform
}

public struct ReflectionNote: Codable, Equatable, Hashable, Identifiable {
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

public struct ReflectionNoteQuery: Codable, Equatable, Hashable {
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
