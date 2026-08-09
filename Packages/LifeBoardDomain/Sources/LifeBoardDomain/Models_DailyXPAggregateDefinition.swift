import Foundation

public struct DailyXPAggregateDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var dateKey: String
    public var totalXP: Int
    public var eventCount: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        dateKey: String,
        totalXP: Int = 0,
        eventCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.totalXP = totalXP
        self.eventCount = eventCount
        self.updatedAt = updatedAt
    }
}
