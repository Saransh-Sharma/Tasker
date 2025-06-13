//
//  PromptMiddleware.swift
//  Tasker LLM
//
//  Created by Cascade AI on 13/06/2025.
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
    ///   - project: Optional project to scope tasks.
    /// - Returns: String summary, one task per line or "(no tasks)".
    static func buildTasksSummary(range: TaskRange, project: Projects? = nil) -> String {
        let tasks = TaskManager.sharedInstance.getAllTasks.filter { task in
            guard !task.isComplete else { return false }
            // project filter
            if let project, let projName = task.project?.lowercased() {
                if projName != project.projectName?.lowercased() { return false }
            }
            // date range filter
            guard let due = task.dueDate as Date? else { return false }
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
        return tasks.map { "• \($0.name)" }.joined(separator: "\n")
    }
}
