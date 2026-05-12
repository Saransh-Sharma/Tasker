import Foundation

public enum XPActionCategory: String, Codable, CaseIterable, Sendable {
    case complete
    case start
    case decompose
    case recoverReschedule
    case reflection
    case reflectionCapture
    case focus
    case weeklyPlan
    case weeklyReview
    case weeklyCarryCleanup
    case habitPositiveComplete
    case habitNegativeSuccess
    case habitNegativeLapse
    case habitPositiveCompleteUndo
    case habitNegativeSuccessUndo
    case habitRecovery
    case habitStreakMilestone
}

public enum XPSource: String, Codable, CaseIterable, Sendable {
    case manual
    case notification
    case assistant
    case system
    case habit
}

public enum TaskMutationSource: String, Codable, CaseIterable, Sendable {
    case manual
    case notification
    case assistant
    case system
}
