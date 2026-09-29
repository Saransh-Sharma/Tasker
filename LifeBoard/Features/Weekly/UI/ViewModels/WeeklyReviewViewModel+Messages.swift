import Foundation

extension WeeklyReviewViewModel {
    func completionMessage(for result: CompleteWeeklyReviewResult) -> String {
        let staleCount = result.skippedTaskIDs.count + result.skippedOutcomeIDs.count
        guard staleCount > 0 else {
            return WeeklyCopy.reviewSaveSuccess
        }
        if staleCount == 1 {
            return String(localized: "Review saved. 1 change skipped.")
        }
        return String(localized: "Review saved. \(staleCount) changes skipped.")
    }

    func presentationErrorMessage(for error: Error) -> String {
        if error is SyncWriteClosedError {
            return String(localized: "Couldn’t save review. Try again after sync finishes.")
        }

        let nsError = error as NSError
        if nsError.domain == "WeeklyReviewViewModel", nsError.code == 900 {
            return String(localized: "Review saved. Reopen to see changes.")
        }
        if nsError.domain == "CoreDataWeeklyReviewMutationRepository", nsError.code == 500 {
            return String(localized: "Couldn’t save review. Try again.")
        }

        return error.localizedDescription
    }
}
