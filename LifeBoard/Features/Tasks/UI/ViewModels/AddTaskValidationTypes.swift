import Foundation

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case emptyTaskName
    case taskNameTooLong
    case pastDueDate
    case pastReminderTime

    public var errorDescription: String? {
        switch self {
        case .emptyTaskName:
            return String(localized: "Add a task name.")
        case .taskNameTooLong:
            return String(localized: "Use 200 characters or fewer.")
        case .pastDueDate:
            return String(localized: "Pick a due date from today on.")
        case .pastReminderTime:
            return String(localized: "Pick a reminder time later than now.")
        }
    }
}

/// State structure for the add task view
public struct AddTaskViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let isTaskCreated: Bool
    public let validationErrors: [ValidationError]
    public let projects: [Project]
    public let lifeAreas: [LifeArea]
    public let sections: [ProjectSectionDefinition]
    public let tags: [TagDefinition]
    public let canSubmit: Bool
}

// MARK: - View State

extension AddTaskViewModel {

    /// Combined state for the view
    public var viewState: AddTaskViewState {
        return AddTaskViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            isTaskCreated: isTaskCreated,
            validationErrors: validationErrors,
            projects: projects,
            lifeAreas: lifeAreas,
            sections: sections,
            tags: tags,
            canSubmit: validationErrorsForCurrentInput(now: nowProvider()).isEmpty
        )
    }
}
