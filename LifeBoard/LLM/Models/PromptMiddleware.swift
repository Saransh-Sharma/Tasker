//
//  PromptMiddleware.swift
//  Tasker LLM
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
    static func buildTasksSummary(range: TaskRange, projectName: String? = nil) async -> String {
        let allTasks = await fetchAllTasks()
        let targetProject = projectName?.lowercased()
        let openTasks = allTasks.filter { task in
            guard !task.isComplete else { return false }
            if let targetProject {
                let projectName = task.projectName?.lowercased() ?? ""
                if projectName != targetProject { return false }
            }
            return task.dueDate != nil
        }

        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .all:
            if openTasks.isEmpty { return "(no tasks)" }
            return openTasks.map { "• \($0.title)" }.joined(separator: "\n")
        case .today:
            let startOfToday = calendar.startOfDay(for: now)
            let overdue = openTasks.filter {
                guard let due = $0.dueDate else { return false }
                return due < startOfToday
            }
            let dueToday = openTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInToday(due)
            }

            var lines: [String] = []
            if overdue.isEmpty == false {
                lines.append("Overdue:")
                lines.append(contentsOf: overdue.map { "• [overdue] \($0.title)" })
            }
            if dueToday.isEmpty == false {
                lines.append("Due today:")
                lines.append(contentsOf: dueToday.map { "• [today] \($0.title)" })
            }
            if lines.isEmpty { return "(no tasks)" }
            return lines.joined(separator: "\n")
        case .tomorrow:
            let tomorrow = openTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDateInTomorrow(due)
            }
            if tomorrow.isEmpty { return "(no tasks)" }
            return tomorrow.map { "• \($0.title)" }.joined(separator: "\n")
        case .week:
            let week = openTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDate(due, equalTo: now, toGranularity: .weekOfYear)
            }
            if week.isEmpty { return "(no tasks)" }
            return week.map { "• \($0.title)" }.joined(separator: "\n")
        case .month:
            let month = openTasks.filter {
                guard let due = $0.dueDate else { return false }
                return calendar.isDate(due, equalTo: now, toGranularity: .month)
            }
            if month.isEmpty { return "(no tasks)" }
            return month.map { "• \($0.title)" }.joined(separator: "\n")
        }
    }

    /// Executes fetchAllTasks.
    private static func fetchAllTasks() async -> [TaskDefinition] {
        guard let repository = LLMContextRepositoryProvider.taskReadModelRepository else {
            return []
        }

        return await withCheckedContinuation { continuation in
            repository.fetchTasks(
                query: TaskReadQuery(
                    includeCompleted: true,
                    sortBy: .dueDateAscending,
                    limit: 5_000,
                    offset: 0
                )
            ) { result in
                switch result {
                case .success(let slice):
                    continuation.resume(returning: slice.tasks)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
