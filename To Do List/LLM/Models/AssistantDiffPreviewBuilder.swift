import Foundation

struct AssistantDiffLine: Codable, Equatable, Hashable {
    let text: String
    let isDestructive: Bool
}

struct AssistantDiffPreviewBuilder {
    /// Executes build.
    static func build(
        commands: [AssistantCommand],
        taskTitleByID: [UUID: String],
        projectNameByID: [UUID: String] = [:]
    ) -> [AssistantDiffLine] {
        commands.map { command in
            line(for: command, taskTitleByID: taskTitleByID, projectNameByID: projectNameByID)
        }
    }

    /// Executes destructiveCount.
    static func destructiveCount(for commands: [AssistantCommand]) -> Int {
        commands.filter {
            if case .deleteTask = $0 { return true }
            if case .moveTask = $0 { return true }
            if case .deferTask = $0 { return true }
            if case .dropTaskFromToday = $0 { return true }
            return false
        }.count
    }

    /// Executes affectedTaskCount.
    static func affectedTaskCount(for commands: [AssistantCommand]) -> Int {
        var touched = Set<UUID>()
        for command in commands {
            switch command {
            case .createTask:
                continue
            case .createScheduledTask, .createInboxTask:
                continue
            case .restoreTask(let taskID, _, _, _, _, _):
                touched.insert(taskID)
            case .restoreTaskSnapshot(let snapshot):
                touched.insert(snapshot.id)
            case .deleteTask(let taskID):
                touched.insert(taskID)
            case .updateTask(let taskID, _, _):
                touched.insert(taskID)
            case .setTaskCompletion(let taskID, _, _):
                touched.insert(taskID)
            case .completeTask(let taskID):
                touched.insert(taskID)
            case .moveTask(let taskID, _):
                touched.insert(taskID)
            case .updateTaskSchedule(let taskID, _, _, _, _):
                touched.insert(taskID)
            case .updateTaskFields(let taskID, _, _, _, _, _, _, _, _):
                touched.insert(taskID)
            case .deferTask(let taskID, _, _):
                touched.insert(taskID)
            case .dropTaskFromToday(let taskID, _, _):
                touched.insert(taskID)
            }
        }
        return max(1, touched.count)
    }

    /// Executes line.
    private static func line(
        for command: AssistantCommand,
        taskTitleByID: [UUID: String],
        projectNameByID: [UUID: String]
    ) -> AssistantDiffLine {
        switch command {
        case let .createTask(_, title):
            return AssistantDiffLine(text: "Add: \(title)", isDestructive: false)
        case let .restoreTask(taskID, _, title, _, _, _):
            return AssistantDiffLine(
                text: "Restore task '\(taskTitleByID[taskID] ?? title)'",
                isDestructive: false
            )
        case let .restoreTaskSnapshot(snapshot):
            return AssistantDiffLine(text: "Restore task '\(snapshot.title)'", isDestructive: false)
        case let .deleteTask(taskID):
            return AssistantDiffLine(
                text: "Delete: '\(displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID))'",
                isDestructive: true
            )
        case let .updateTask(taskID, title, dueDate):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            if let dueDate {
                return AssistantDiffLine(
                    text: "Reschedule '\(baseTitle)' to \(format(date: dueDate))",
                    isDestructive: false
                )
            }
            if let title {
                return AssistantDiffLine(
                    text: "Rename '\(baseTitle)' to '\(title)'",
                    isDestructive: false
                )
            }
            return AssistantDiffLine(text: "Update '\(baseTitle)'", isDestructive: false)
        case let .setTaskCompletion(taskID, isComplete, _):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return AssistantDiffLine(
                text: "\(isComplete ? "Complete" : "Reopen"): '\(baseTitle)'",
                isDestructive: false
            )
        case let .completeTask(taskID):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return AssistantDiffLine(text: "Complete: '\(baseTitle)'", isDestructive: false)
        case let .moveTask(taskID, targetProjectID):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            let targetName = projectNameByID[targetProjectID] ?? "selected project"
            return AssistantDiffLine(text: "Move '\(baseTitle)' to '\(targetName)'", isDestructive: true)
        case let .createScheduledTask(_, title, start, end, _, _, _, _, _, _, _, _):
            return AssistantDiffLine(
                text: "Create: \(title) at \(format(time: start))-\(format(time: end))",
                isDestructive: false
            )
        case let .createInboxTask(_, title, _, _, _, _, _, _):
            return AssistantDiffLine(text: "Create inbox: \(title)", isDestructive: false)
        case let .updateTaskSchedule(taskID, start, end, _, dueDate):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            if let start, let end {
                return AssistantDiffLine(
                    text: "Edit '\(baseTitle)' to \(format(time: start))-\(format(time: end))",
                    isDestructive: false
                )
            }
            if let dueDate {
                return AssistantDiffLine(
                    text: "Reschedule '\(baseTitle)' to \(format(date: dueDate))",
                    isDestructive: false
                )
            }
            return AssistantDiffLine(text: "Update schedule for '\(baseTitle)'", isDestructive: false)
        case let .updateTaskFields(taskID, title, _, _, _, _, _, _, _):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            if let title {
                return AssistantDiffLine(text: "Rename '\(baseTitle)' to '\(title)'", isDestructive: false)
            }
            return AssistantDiffLine(text: "Edit fields for '\(baseTitle)'", isDestructive: false)
        case let .deferTask(taskID, targetDate, _):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return AssistantDiffLine(
                text: "Defer '\(baseTitle)' to \(format(date: targetDate))",
                isDestructive: true
            )
        case let .dropTaskFromToday(taskID, destination, _):
            let baseTitle = displayTaskTitle(taskID: taskID, taskTitleByID: taskTitleByID)
            return AssistantDiffLine(
                text: "Drop '\(baseTitle)' from today to \(destination.rawValue)",
                isDestructive: true
            )
        }
    }

    /// Executes displayTaskTitle.
    private static func displayTaskTitle(
        taskID: UUID,
        taskTitleByID: [UUID: String]
    ) -> String {
        let title = taskTitleByID[taskID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "task" : title
    }

    /// Executes format.
    private static func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func format(time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}
