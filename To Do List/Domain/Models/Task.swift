//
//  Task.swift
//  Tasker
//
//  Domain model for Task - Pure Swift, no framework dependencies
//

import Foundation

/// Pure domain model representing a Task
/// This model is independent of any persistence framework (Core Data, etc.)
public struct Task {
    // MARK: - Properties
    
    public let id: UUID
    public var name: String
    public var details: String?
    public var type: TaskType
    public var priority: TaskPriority
    public var dueDate: Date?
    public var project: String?
    public var isComplete: Bool
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var isEveningTask: Bool
    public var alertReminderTime: Date?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        project: String? = "Inbox",
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        isEveningTask: Bool = false,
        alertReminderTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.project = project
        self.isComplete = isComplete
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
        self.isEveningTask = isEveningTask
        self.alertReminderTime = alertReminderTime
    }
    
    // MARK: - Business Logic
    
    /// Calculate the score for this task based on priority
    public var score: Int {
        guard isComplete else { return 0 }
        return priority.scoreValue
    }
    
    /// Check if the task is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate, !isComplete else { return false }
        return dueDate < Date()
    }
    
    /// Check if the task is due today
    public var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    /// Check if this is a morning task
    public var isMorningTask: Bool {
        return type == .morning
    }
    
    /// Check if this is an upcoming task
    public var isUpcomingTask: Bool {
        return type == .upcoming
    }
    
    // MARK: - Validation
    
    /// Validate the task data
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TaskValidationError.emptyName
        }
        
        if name.count > 200 {
            throw TaskValidationError.nameTooLong
        }
        
        if let details = details, details.count > 1000 {
            throw TaskValidationError.detailsTooLong
        }
    }
}

// MARK: - Validation Errors

public enum TaskValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case detailsTooLong
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Task name cannot be empty"
        case .nameTooLong:
            return "Task name cannot exceed 200 characters"
        case .detailsTooLong:
            return "Task details cannot exceed 1000 characters"
        }
    }
}

// MARK: - Equatable

extension Task: Equatable {
    public static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Task: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
