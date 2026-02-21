import Foundation

public enum ScheduleSourceType: String, Codable {
    case task
    case habit
    case reminder
}

public enum TemporalReference: String, Codable {
    case floating
    case anchored
}

public struct ScheduleTemplateDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var sourceType: ScheduleSourceType
    public var sourceID: UUID
    public var timezoneID: String?
    public var temporalReference: TemporalReference
    public var anchorAt: Date?
    public var windowStart: String?
    public var windowEnd: String?
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        sourceType: ScheduleSourceType,
        sourceID: UUID,
        timezoneID: String? = nil,
        temporalReference: TemporalReference = .anchored,
        anchorAt: Date? = nil,
        windowStart: String? = nil,
        windowEnd: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.timezoneID = timezoneID
        self.temporalReference = temporalReference
        self.anchorAt = anchorAt
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ScheduleRuleDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var scheduleTemplateID: UUID
    public var ruleType: String
    public var interval: Int
    public var byDayMask: Int?
    public var byMonthDay: Int?
    public var byHour: Int?
    public var byMinute: Int?
    public var rawRuleData: Data?
    public var createdAt: Date
}

public enum ScheduleExceptionAction: String, Codable {
    case skip
    case move
    case modify
}

public struct ScheduleExceptionDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var scheduleTemplateID: UUID
    public var occurrenceKey: String
    public var action: ScheduleExceptionAction
    public var movedToAt: Date?
    public var payloadData: Data?
    public var createdAt: Date
}
