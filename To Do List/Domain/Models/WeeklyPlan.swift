import Foundation

public enum WeeklyPlanReviewStatus: String, Codable, CaseIterable, Hashable {
    case notStarted
    case ready
    case completed
}

public struct WeeklyPlan: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var weekStartDate: Date
    public var weekEndDate: Date
    public var focusStatement: String?
    public var selectedHabitIDs: [UUID]
    public var targetCapacity: Int?
    public var minimumViableWeekEnabled: Bool
    public var reviewStatus: WeeklyPlanReviewStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        weekStartDate: Date,
        weekEndDate: Date,
        focusStatement: String? = nil,
        selectedHabitIDs: [UUID] = [],
        targetCapacity: Int? = nil,
        minimumViableWeekEnabled: Bool = false,
        reviewStatus: WeeklyPlanReviewStatus = .notStarted,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.focusStatement = focusStatement
        self.selectedHabitIDs = selectedHabitIDs
        self.targetCapacity = targetCapacity
        self.minimumViableWeekEnabled = minimumViableWeekEnabled
        self.reviewStatus = reviewStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
