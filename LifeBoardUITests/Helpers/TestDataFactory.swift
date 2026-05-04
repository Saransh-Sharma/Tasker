//
//  TestDataFactory.swift
//  To Do ListUITests
//
//  Factory for generating test data for UI tests
//

import Foundation

struct TestDataFactory {

    // MARK: - Task Data

    struct TaskData {
        let title: String
        let description: String?
        let priority: TaskPriority
        let taskType: TaskType
        let dueDate: Date?
        let project: String?
        let hasReminder: Bool

        init(
            title: String = "Test Task",
            description: String? = nil,
            priority: TaskPriority = .medium,
            taskType: TaskType = .morning,
            dueDate: Date? = nil,
            project: String? = nil,
            hasReminder: Bool = false
        ) {
            self.title = title
            self.description = description
            self.priority = priority
            self.taskType = taskType
            self.dueDate = dueDate
            self.project = project
            self.hasReminder = hasReminder
        }
    }

    enum TaskPriority: String, CaseIterable {
        case none = "None"
        case low = "Low"       // P3 = 2 points
        case medium = "Medium" // P2 = 3 points
        case high = "High"     // P1 = 4 points
        case max = "Max"       // P0 = 7 points

        var scorePoints: Int {
            switch self {
            case .none: return 0
            case .low: return 2
            case .medium: return 3
            case .high: return 4
            case .max: return 7
            }
        }

        var displayName: String {
            return rawValue
        }
    }

    enum TaskType: String, CaseIterable {
        case morning = "Morning"
        case evening = "Evening"
        case upcoming = "Upcoming"
        case inbox = "Inbox"

        var displayName: String {
            return rawValue
        }
    }

    // MARK: - Project Data

    struct ProjectData {
        let name: String
        let description: String?
        let color: String
        let icon: String

        init(
            name: String = "Test Project",
            description: String? = nil,
            color: String = "Blue",
            icon: String = "Folder"
        ) {
            self.name = name
            self.description = description
            self.color = color
            self.icon = icon
        }
    }

    // MARK: - Predefined Test Data

    /// Create a simple morning task
    static func simpleMorningTask() -> TaskData {
        return TaskData(
            title: "Morning Exercise",
            priority: .medium,
            taskType: .morning
        )
    }

    /// Create a simple evening task
    static func simpleEveningTask() -> TaskData {
        return TaskData(
            title: "Evening Review",
            priority: .low,
            taskType: .evening
        )
    }

    /// Create a high priority task with all properties
    static func completeMorningTask(withDueDate dueDate: Date = Date()) -> TaskData {
        return TaskData(
            title: "Important Morning Meeting",
            description: "Quarterly review meeting with team leads",
            priority: .high,
            taskType: .morning,
            dueDate: dueDate,
            project: "Work",
            hasReminder: true
        )
    }

    /// Create a maximum priority task
    static func maxPriorityTask() -> TaskData {
        return TaskData(
            title: "Critical Deadline Task",
            description: "Must be completed today",
            priority: .max,
            taskType: .morning,
            dueDate: Date()
        )
    }

    /// Create upcoming task
    static func upcomingTask(daysFromNow days: Int) -> TaskData {
        let dueDate = Calendar.current.date(byAdding: .day, value: days, to: Date())
        return TaskData(
            title: "Future Task",
            description: "Scheduled for later",
            priority: .medium,
            taskType: .upcoming,
            dueDate: dueDate
        )
    }

    /// Create task with very long title (for validation testing)
    static func taskWithLongTitle() -> TaskData {
        let longTitle = String(repeating: "A", count: 250) // Exceeds 200 char limit
        return TaskData(
            title: longTitle,
            priority: .low,
            taskType: .morning
        )
    }

    /// Create task with empty title (for validation testing)
    static func taskWithEmptyTitle() -> TaskData {
        return TaskData(
            title: "",
            priority: .medium,
            taskType: .morning
        )
    }

    /// Create task with long description (for validation testing)
    static func taskWithLongDescription() -> TaskData {
        let longDescription = String(repeating: "B", count: 1100) // Exceeds 1000 char limit
        return TaskData(
            title: "Task with Long Description",
            description: longDescription,
            priority: .medium,
            taskType: .morning
        )
    }

    /// Create multiple tasks with varying priorities
    static func tasksWithVariedPriorities(count: Int = 5) -> [TaskData] {
        var tasks: [TaskData] = []
        let priorities: [TaskPriority] = [.max, .high, .medium, .low, .none]

        for i in 0..<count {
            let priority = priorities[i % priorities.count]
            tasks.append(TaskData(
                title: "Task \(i + 1) - Priority \(priority.displayName)",
                priority: priority,
                taskType: i % 2 == 0 ? .morning : .evening
            ))
        }

        return tasks
    }

    /// Create tasks for scoring system test
    static func tasksForScoringTest() -> [TaskData] {
        return [
            TaskData(title: "Max Priority Task", priority: .max, taskType: .morning),     // 7 points
            TaskData(title: "High Priority Task", priority: .high, taskType: .morning),   // 4 points
            TaskData(title: "Medium Priority Task", priority: .medium, taskType: .evening), // 3 points
            TaskData(title: "Low Priority Task", priority: .low, taskType: .evening)      // 2 points
            // Total: 7 + 4 + 3 + 2 = 16 points
        ]
    }

    // MARK: - Project Test Data

    /// Create a simple project
    static func simpleProject() -> ProjectData {
        return ProjectData(
            name: "Personal",
            color: "Blue",
            icon: "Person"
        )
    }

    /// Create a work project
    static func workProject() -> ProjectData {
        return ProjectData(
            name: "Work",
            description: "Work-related tasks and projects",
            color: "Red",
            icon: "Briefcase"
        )
    }

    /// Create project with long name (for validation testing)
    static func projectWithLongName() -> ProjectData {
        let longName = String(repeating: "C", count: 150) // Exceeds 100 char limit
        return ProjectData(
            name: longName,
            color: "Green",
            icon: "Folder"
        )
    }

    /// Create project with empty name (for validation testing)
    static func projectWithEmptyName() -> ProjectData {
        return ProjectData(
            name: "",
            color: "Blue",
            icon: "Folder"
        )
    }

    /// Create multiple projects
    static func multipleProjects(count: Int = 5) -> [ProjectData] {
        let projectNames = ["Work", "Personal", "Health", "Learning", "Hobbies", "Family", "Finance"]
        let colors = ["Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Pink"]
        let icons = ["Briefcase", "Person", "Heart", "Book", "Star", "House", "DollarSign"]

        var projects: [ProjectData] = []

        for i in 0..<min(count, projectNames.count) {
            projects.append(ProjectData(
                name: projectNames[i],
                description: "\(projectNames[i]) related tasks",
                color: colors[i % colors.count],
                icon: icons[i % icons.count]
            ))
        }

        return projects
    }

    // MARK: - Date Helpers

    /// Get today's date at start of day
    static func today() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }

    /// Get tomorrow's date
    static func tomorrow() -> Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: today())!
    }

    /// Get yesterday's date
    static func yesterday() -> Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: today())!
    }

    /// Get date n days from now
    static func daysFromNow(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: today())!
    }

    /// Get date n days ago
    static func daysAgo(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: -days, to: today())!
    }

    /// Create time for morning (9:00 AM)
    static func morningTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components)!
    }

    /// Create time for evening (6:00 PM)
    static func eveningTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 0
        return Calendar.current.date(from: components)!
    }

    // MARK: - Random Data Generators

    /// Generate random task title
    static func randomTaskTitle() -> String {
        let adjectives = ["Important", "Urgent", "Quick", "Complex", "Simple", "Critical"]
        let nouns = ["Meeting", "Task", "Review", "Planning", "Discussion", "Analysis"]

        let adjective = adjectives.randomElement()!
        let noun = nouns.randomElement()!

        return "\(adjective) \(noun) \(Int.random(in: 1...100))"
    }

    /// Generate random project name
    static func randomProjectName() -> String {
        let prefixes = ["Team", "Project", "Initiative", "Program", "Campaign"]
        let suffixes = ["Alpha", "Beta", "Gamma", "Delta", "Omega", "Prime"]

        let prefix = prefixes.randomElement()!
        let suffix = suffixes.randomElement()!

        return "\(prefix) \(suffix)"
    }

    // MARK: - Utility Methods

    /// Format date for UI display (e.g., "Jan 15, 2025")
    static func formatDateForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Format date and time for UI display (e.g., "Jan 15, 2025 at 3:30 PM")
    static func formatDateTimeForDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
