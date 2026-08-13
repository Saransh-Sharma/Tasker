import Foundation

// The weekly-review vocabulary: what a review decides about each task, and the
// request/result pair the use case exchanges with its repository.
//
// These are domain contracts, not use-case implementation detail. They lived in
// UseCases/Weekly, which made `Domain/Interfaces` depend upward on the use-case
// layer — invisible in a single module, and a hard stop for extracting Domain
// as a package.
public enum WeeklyReviewTaskDisposition: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case carry
    case later
    case drop
}

public struct WeeklyReviewTaskDecision: Codable, Equatable, Hashable, Sendable {
    public let taskID: UUID
    public let disposition: WeeklyReviewTaskDisposition

    public init(taskID: UUID, disposition: WeeklyReviewTaskDisposition) {
        self.taskID = taskID
        self.disposition = disposition
    }
}

public struct CompleteWeeklyReviewRequest: Equatable, Sendable {
    public let weeklyPlanID: UUID
    public let wins: String?
    public let blockers: String?
    public let lessons: String?
    public let nextWeekPrepNotes: String?
    public let perceivedWeekRating: Int?
    public let taskDecisions: [WeeklyReviewTaskDecision]
    public let outcomeStatusesByOutcomeID: [UUID: WeeklyOutcomeStatus]
    public let completedAt: Date

    public init(
        weeklyPlanID: UUID,
        wins: String? = nil,
        blockers: String? = nil,
        lessons: String? = nil,
        nextWeekPrepNotes: String? = nil,
        perceivedWeekRating: Int? = nil,
        taskDecisions: [WeeklyReviewTaskDecision] = [],
        outcomeStatusesByOutcomeID: [UUID: WeeklyOutcomeStatus] = [:],
        completedAt: Date = Date()
    ) {
        self.weeklyPlanID = weeklyPlanID
        self.wins = wins
        self.blockers = blockers
        self.lessons = lessons
        self.nextWeekPrepNotes = nextWeekPrepNotes
        self.perceivedWeekRating = perceivedWeekRating
        self.taskDecisions = taskDecisions
        self.outcomeStatusesByOutcomeID = outcomeStatusesByOutcomeID
        self.completedAt = completedAt
    }
}

public struct CompleteWeeklyReviewResult: Equatable, Sendable {
    public let review: WeeklyReview
    public let skippedTaskIDs: [UUID]
    public let skippedOutcomeIDs: [UUID]

    public init(
        review: WeeklyReview,
        skippedTaskIDs: [UUID] = [],
        skippedOutcomeIDs: [UUID] = []
    ) {
        self.review = review
        self.skippedTaskIDs = skippedTaskIDs
        self.skippedOutcomeIDs = skippedOutcomeIDs
    }
}
