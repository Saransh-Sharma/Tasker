//
//  PromptMiddleware.swift
//  Tasker LLM
//
//

import Foundation

// Enum describing the task time range requested by the user
public enum TaskRange: String {
    case today, tomorrow, week, month, all

    public var description: String {
        switch self {
        case .today: return "today"
        case .tomorrow: return "tomorrow"
        case .week: return "this week"
        case .month: return "this month"
        case .all: return "all"
        }
    }
}

struct PromptMiddleware {
    /// Build a bullet list of open tasks filtered by date range and optional project.
    /// - Parameters:
    ///   - range: Time window to filter tasks.
    ///   - projectName: Optional project name to scope tasks.
    /// - Returns: String summary, one task per line or "(no tasks)".
    static func buildTasksSummary(range: TaskRange, projectName: String? = nil) -> String {
        let allTasks = fetchAllTasksSync()
        let targetProject = projectName?.lowercased()
        let tasks = allTasks.filter { task in
            guard !task.isComplete else { return false }
            // project filter
            if let targetProject {
                let projName = task.projectName?.lowercased() ?? ""
                if projName != targetProject { return false }
            }
            // date range filter
            guard let due = task.dueDate else { return false }
            let cal = Calendar.current
            switch range {
            case .all:
                return true
            case .today:
                return cal.isDateInToday(due)
            case .tomorrow:
                return cal.isDateInTomorrow(due)
            case .week:
                return cal.isDate(due, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return cal.isDate(due, equalTo: Date(), toGranularity: .month)
            }
        }
        if tasks.isEmpty { return "(no tasks)" }
        return tasks.map { "• \($0.title)" }.joined(separator: "\n")
    }

    private static func fetchAllTasksSync() -> [TaskDefinition] {
        guard let repository = LLMContextRepositoryProvider.taskReadModelRepository else {
            return []
        }
        let semaphore = DispatchSemaphore(value: 0)
        var fetched: [TaskDefinition] = []
        repository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            if case .success(let slice) = result {
                fetched = slice.tasks
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return fetched
    }
}
