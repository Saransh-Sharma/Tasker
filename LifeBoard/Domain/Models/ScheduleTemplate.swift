import Foundation

public enum ScheduleSourceType: String, Codable, Sendable {
    case task
    case habit
    case tracker
    case reminder
}

public enum BehaviorDomain: String, Codable, CaseIterable, Sendable {
    case habit
    case tracker
}

public enum BehaviorResponseShape: Codable, Hashable, Sendable {
    case binary
    case avoidance
    case quantitative(unit: String?)
    case quota(target: Int, period: String)
    case timed(targetSeconds: TimeInterval)
    case tracker(valueType: String)
}

/// A value-layer bridge over the existing Habit/Tracker and Schedule records.
/// It intentionally is not a stored Core Data entity.
public struct BehaviorDefinition: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { domainID }
    public var domain: BehaviorDomain
    public var domainID: UUID
    public var scheduleTemplateID: UUID
    public var responseShape: BehaviorResponseShape
    public var timezoneID: String
    public var isActive: Bool

    public init(
        domain: BehaviorDomain,
        domainID: UUID,
        scheduleTemplateID: UUID,
        responseShape: BehaviorResponseShape,
        timezoneID: String,
        isActive: Bool = true
    ) {
        self.domain = domain
        self.domainID = domainID
        self.scheduleTemplateID = scheduleTemplateID
        self.responseShape = responseShape
        self.timezoneID = timezoneID
        self.isActive = isActive
    }
}

public protocol BehaviorScheduleResolving: Sendable {
    func occurrences(
        for behavior: BehaviorDefinition,
        from start: Date,
        to end: Date
    ) async throws -> [OccurrenceDefinition]
}

public enum TemporalReference: String, Codable, Sendable {
    case floating
    case anchored
}

public struct ScheduleTemplateDefinition: Codable, Equatable, Hashable, Sendable {
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

public struct ScheduleRuleDefinition: Codable, Equatable, Hashable, Sendable {
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

public enum ScheduleExceptionAction: String, Codable, Sendable {
    case skip
    case move
    case modify
}

public struct ScheduleExceptionDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var scheduleTemplateID: UUID
    public var occurrenceKey: String
    public var action: ScheduleExceptionAction
    public var movedToAt: Date?
    public var payloadData: Data?
    public var createdAt: Date
}
