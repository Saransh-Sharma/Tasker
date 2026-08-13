import Foundation

public enum ReminderSourceType: String, Codable, Sendable {
    case task
    case habit
    case occurrence
}

public enum ReminderTriggerType: String, Codable, Sendable {
    case absolute
    case relative
    case location
}

public struct ReminderDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var sourceType: ReminderSourceType
    public var sourceID: UUID
    public var occurrenceID: UUID?
    public var policy: String
    public var channelMask: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var updatedAt: Date

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(id: UUID, sourceType: ReminderSourceType, sourceID: UUID, occurrenceID: UUID? = nil, policy: String, channelMask: Int, isEnabled: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.occurrenceID = occurrenceID
        self.policy = policy
        self.channelMask = channelMask
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReminderTriggerDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var reminderID: UUID
    public var triggerType: ReminderTriggerType
    public var fireAt: Date?
    public var offsetSeconds: Int?
    public var locationPayloadData: Data?
    public var createdAt: Date

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(id: UUID, reminderID: UUID, triggerType: ReminderTriggerType, fireAt: Date? = nil, offsetSeconds: Int? = nil, locationPayloadData: Data? = nil, createdAt: Date) {
        self.id = id
        self.reminderID = reminderID
        self.triggerType = triggerType
        self.fireAt = fireAt
        self.offsetSeconds = offsetSeconds
        self.locationPayloadData = locationPayloadData
        self.createdAt = createdAt
    }
}

public struct ReminderDeliveryDefinition: Codable, Equatable, Hashable, Sendable {
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

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(id: UUID, reminderID: UUID, triggerID: UUID, status: String, scheduledAt: Date? = nil, sentAt: Date? = nil, ackAt: Date? = nil, snoozedUntil: Date? = nil, errorCode: String? = nil, createdAt: Date) {
        self.id = id
        self.reminderID = reminderID
        self.triggerID = triggerID
        self.status = status
        self.scheduledAt = scheduledAt
        self.sentAt = sentAt
        self.ackAt = ackAt
        self.snoozedUntil = snoozedUntil
        self.errorCode = errorCode
        self.createdAt = createdAt
    }
}

public struct ReminderDeliveryResponseAggregate: Codable, Equatable, Hashable, Sendable {
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
