import Foundation

public enum ReminderSourceType: String, Codable {
    case task
    case habit
    case occurrence
}

public enum ReminderTriggerType: String, Codable {
    case absolute
    case relative
    case location
}

public struct ReminderDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var sourceType: ReminderSourceType
    public var sourceID: UUID
    public var occurrenceID: UUID?
    public var policy: String
    public var channelMask: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date
}

public struct ReminderTriggerDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var reminderID: UUID
    public var triggerType: ReminderTriggerType
    public var fireAt: Date?
    public var offsetSeconds: Int?
    public var locationPayloadData: Data?
    public var createdAt: Date
}

public struct ReminderDeliveryDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var reminderID: UUID
    public var triggerID: UUID
    public var status: String
    public var scheduledAt: Date?
    public var sentAt: Date?
    public var ackAt: Date?
    public var snoozedUntil: Date?
    public var errorCode: String?
    public var createdAt: Date
}
