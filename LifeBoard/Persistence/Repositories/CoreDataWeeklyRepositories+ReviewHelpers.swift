import Foundation
import LifeBoardDomain

extension UserDefaultsWeeklyReviewDraftStore {
    struct WeeklyReviewLocalStateFile: Codable, Equatable {
        var draftsByWeekKey: [String: WeeklyReviewDraft]
        var completedTaskDecisionsByWeekKey: [String: [WeeklyReviewTaskDecision]]
    }
}

extension CoreDataWeeklyReviewMutationRepository {
    static func mapFinalizeError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain != "CoreDataWeeklyReviewMutationRepository" else {
            return error
        }

        return NSError(
            domain: "CoreDataWeeklyReviewMutationRepository",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey: String(localized: "Couldn’t save weekly review."),
                NSUnderlyingErrorKey: error
            ]
        )
    }
}
