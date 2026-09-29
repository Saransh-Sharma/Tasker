import Foundation

struct WeeklyReviewOutcomeSnapshot: Equatable, Identifiable {
    let outcome: WeeklyOutcome
    let selectedStatus: WeeklyOutcomeStatus
    let linkedTaskCount: Int

    var id: UUID { outcome.id }
}

struct WeeklyReviewSnapshot: Equatable {
    let completedTasks: [TaskDefinition]
    let unfinishedTasks: [TaskDefinition]
    let selectedHabits: [HabitLibraryRow]
    let outcomeSnapshots: [WeeklyReviewOutcomeSnapshot]
    let reflectionNotes: [ReflectionNote]
    let reviewSteps: [WeeklyRitualStep]
    let completionSummaryText: String

    static func == (lhs: WeeklyReviewSnapshot, rhs: WeeklyReviewSnapshot) -> Bool {
        lhs.completedTasks == rhs.completedTasks
            && lhs.unfinishedTasks == rhs.unfinishedTasks
            && lhs.selectedHabits == rhs.selectedHabits
            && lhs.outcomeSnapshots == rhs.outcomeSnapshots
            && lhs.reflectionNotes == rhs.reflectionNotes
            && lhs.completionSummaryText == rhs.completionSummaryText
            && lhs.reviewSteps.map(\.id) == rhs.reviewSteps.map(\.id)
            && lhs.reviewSteps.map(\.title) == rhs.reviewSteps.map(\.title)
            && lhs.reviewSteps.map(\.isComplete) == rhs.reviewSteps.map(\.isComplete)
    }
}

struct WeeklyReviewFooterSnapshot: Equatable {
    let completionSummaryText: String
    let canFinishReview: Bool
}
