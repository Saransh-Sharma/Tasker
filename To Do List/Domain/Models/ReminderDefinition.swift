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

public struct ReminderDeliveryResponseAggregate: Codable, Equatable, Hashable {
    public var configuredReminderCount: Int
    public var totalDeliveries: Int
    public var acknowledgedDeliveries: Int
    public var snoozedDeliveries: Int
    public var pendingDeliveries: Int

    public var responseRate: Double {
        guard totalDeliveries > 0 else { return 0 }
        return Double(acknowledgedDeliveries + snoozedDeliveries) / Double(totalDeliveries)
    }

    public init(
        configuredReminderCount: Int = 0,
        totalDeliveries: Int = 0,
        acknowledgedDeliveries: Int = 0,
        snoozedDeliveries: Int = 0,
        pendingDeliveries: Int = 0
    ) {
        self.configuredReminderCount = max(0, configuredReminderCount)
        self.totalDeliveries = max(0, totalDeliveries)
        self.acknowledgedDeliveries = max(0, acknowledgedDeliveries)
        self.snoozedDeliveries = max(0, snoozedDeliveries)
        self.pendingDeliveries = max(0, pendingDeliveries)
    }
}
