import Foundation

public enum WeeklyOutcomeStatus: String, Codable, CaseIterable, Hashable {
    case planned
    case inProgress
    case completed
    case dropped
}

public struct WeeklyOutcome: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var weeklyPlanID: UUID
    public var sourceProjectID: UUID?
    public var title: String
    public var whyItMatters: String?
    public var successDefinition: String?
    public var status: WeeklyOutcomeStatus
    public var orderIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        weeklyPlanID: UUID,
        sourceProjectID: UUID? = nil,
        title: String,
        whyItMatters: String? = nil,
        successDefinition: String? = nil,
        status: WeeklyOutcomeStatus = .planned,
        orderIndex: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.weeklyPlanID = weeklyPlanID
        self.sourceProjectID = sourceProjectID
        self.title = title
        self.whyItMatters = whyItMatters
        self.successDefinition = successDefinition
        self.status = status
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
