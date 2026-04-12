import Foundation

public struct WeeklyReview: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var weeklyPlanID: UUID
    public var wins: String?
    public var blockers: String?
    public var lessons: String?
    public var nextWeekPrepNotes: String?
    public var perceivedWeekRating: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        weeklyPlanID: UUID,
        wins: String? = nil,
        blockers: String? = nil,
        lessons: String? = nil,
        nextWeekPrepNotes: String? = nil,
        perceivedWeekRating: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.weeklyPlanID = weeklyPlanID
        self.wins = wins
        self.blockers = blockers
        self.lessons = lessons
        self.nextWeekPrepNotes = nextWeekPrepNotes
        self.perceivedWeekRating = perceivedWeekRating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct WeeklyReviewDraft: Codable, Equatable, Hashable {
    public let weekStartDate: Date
    public var wins: String?
    public var blockers: String?
    public var lessons: String?
    public var nextWeekPrepNotes: String?
    public var perceivedWeekRating: Int?
    public var taskDecisions: [UUID: WeeklyReviewTaskDisposition]
    public var outcomeStatuses: [UUID: WeeklyOutcomeStatus]
    public var updatedAt: Date

    public init(
        weekStartDate: Date,
        wins: String? = nil,
        blockers: String? = nil,
        lessons: String? = nil,
        nextWeekPrepNotes: String? = nil,
        perceivedWeekRating: Int? = nil,
        taskDecisions: [UUID: WeeklyReviewTaskDisposition] = [:],
        outcomeStatuses: [UUID: WeeklyOutcomeStatus] = [:],
        updatedAt: Date = Date()
    ) {
        self.weekStartDate = weekStartDate
        self.wins = wins
        self.blockers = blockers
        self.lessons = lessons
        self.nextWeekPrepNotes = nextWeekPrepNotes
        self.perceivedWeekRating = perceivedWeekRating
        self.taskDecisions = taskDecisions
        self.outcomeStatuses = outcomeStatuses
        self.updatedAt = updatedAt
    }
}
