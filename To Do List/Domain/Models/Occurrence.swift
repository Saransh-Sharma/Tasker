import Foundation

public enum OccurrenceState: String, Codable {
    case pending
    case completed
    case skipped
    case missed
}

public enum OccurrenceResolutionType: String, Codable {
    case completed
    case skipped
    case missed
    case deferred
}

public enum OccurrenceActor: String, Codable {
    case user
    case system
    case assistant
}

public struct OccurrenceDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceKey: String
    public var scheduleTemplateID: UUID
    public var sourceType: ScheduleSourceType
    public var sourceID: UUID
    public var scheduledAt: Date
    public var dueAt: Date?
    public var state: OccurrenceState
    public var isGenerated: Bool
    public var generationWindow: String?
    public var createdAt: Date
    public var updatedAt: Date
}

public struct OccurrenceResolutionDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceID: UUID
    public var resolutionType: OccurrenceResolutionType
    public var resolvedAt: Date
    public var actor: String
    public var reason: String?
    public var createdAt: Date
}
