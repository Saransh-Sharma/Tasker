//
//  Task.swift
//  Tasker
//
//  Domain model for Task - Pure Swift, no framework dependencies
//

import Foundation

/// Pure domain model representing a Task
/// This model is independent of any persistence framework (Core Data, etc.)
public struct Task: Codable {
    // MARK: - Properties
    
    public let id: UUID
    public var projectID: UUID // UUID reference to the associated project
    public var name: String
    public var details: String?
    public var type: TaskType
    public var priority: TaskPriority
    public var dueDate: Date?
    public var project: String? // Deprecated: kept for backward compatibility, use projectID
    public var isComplete: Bool
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var isEveningTask: Bool
    public var alertReminderTime: Date?
    
    // MARK: - Enhanced Properties
    
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var tags: [String]
    public var dependencies: [UUID] // Task dependencies
    public var subtasks: [UUID] // Subtask IDs
    public var category: TaskCategory
    public var energy: TaskEnergy
    public var context: TaskContext
    public var repeatPattern: TaskRepeatPattern?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        projectID: UUID = ProjectConstants.inboxProjectID,
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        dueDate: Date? = nil,
        project: String? = "Inbox", // Deprecated: use projectID
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        isEveningTask: Bool = false,
        alertReminderTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        tags: [String] = [],
        dependencies: [UUID] = [],
        subtasks: [UUID] = [],
        category: TaskCategory = .general,
        energy: TaskEnergy = .medium,
        context: TaskContext = .anywhere,
        repeatPattern: TaskRepeatPattern? = nil
    ) {
        self.id = id
        self.projectID = projectID
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
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.tags = tags
        self.dependencies = dependencies
        self.subtasks = subtasks
        self.category = category
        self.energy = energy
        self.context = context
        self.repeatPattern = repeatPattern
    }
    
    // MARK: - Business Logic
    
    /// Calculate the score for this task based on priority
    public var score: Int {
        guard isComplete else { return 0 }
        return priority.scorePoints
    }
    
    /// Check if the task is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate, !isComplete else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return dueDate < startOfToday
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
    
    // MARK: - Enhanced Business Logic
    
    /// Check if the task can be completed today based on dependencies and constraints
    public func canBeCompletedToday() -> Bool {
        // Cannot complete if there are blocking dependencies
        guard !isBlocked() else { return false }
        
        // Cannot complete if overdue by more than 7 days (needs rescheduling)
        if let dueDate = dueDate, !isComplete {
            let daysSinceOverdue = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            if daysSinceOverdue > 7 {
                return false
            }
        }
        
        // Check if we have enough time today for estimated duration
        if let estimatedDuration = estimatedDuration {
            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let timeLeft = endOfDay.timeIntervalSince(now)
            return timeLeft >= estimatedDuration
        }
        
        return true
    }
    
    /// Calculate efficiency score based on estimated vs actual duration
    public func calculateEfficiencyScore() -> Double {
        guard let estimated = estimatedDuration,
              let actual = actualDuration,
              estimated > 0 else { return 1.0 }
        
        // Perfect efficiency = 1.0, less efficient < 1.0, more efficient > 1.0
        return estimated / actual
    }
    
    /// Check if task is blocked by dependencies
    public func isBlocked() -> Bool {
        // For now, return false - would need dependency resolution service
        // In a real implementation, this would check if all dependencies are completed
        return !dependencies.isEmpty // Simplified: blocked if has dependencies
    }
    
    /// Get energy requirement description
    public var energyDescription: String {
        switch energy {
        case .low: return "Low energy required"
        case .medium: return "Medium energy required"
        case .high: return "High energy required"
        }
    }
    
    /// Check if task fits current context
    public func fitsContext(_ currentContext: TaskContext) -> Bool {
        return context == TaskContext.anywhere || context == currentContext
    }
    
    /// Calculate task complexity score
    public var complexityScore: Int {
        var score = priority.scorePoints
        
        // Add complexity for dependencies
        score += dependencies.count * 2
        
        // Add complexity for subtasks
        score += subtasks.count
        
        // Add complexity for estimated duration
        if let duration = estimatedDuration {
            let hours = duration / 3600
            score += Int(hours)
        }
        
        return max(score, 1)
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
        
        // Enhanced validation
        if let estimated = estimatedDuration, estimated <= 0 {
            throw TaskValidationError.invalidDuration
        }
        
        if let actual = actualDuration, actual <= 0 {
            throw TaskValidationError.invalidDuration
        }
        
        if tags.count > 10 {
            throw TaskValidationError.tooManyTags
        }
        
        if dependencies.count > 20 {
            throw TaskValidationError.tooManyDependencies
        }
        
        // Check for circular dependencies (simplified)
        if dependencies.contains(id) {
            throw TaskValidationError.circularDependency
        }
    }
}

// MARK: - Validation Errors

public enum TaskValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case detailsTooLong
    case invalidDuration
    case tooManyTags
    case tooManyDependencies
    case circularDependency
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Task name cannot be empty"
        case .nameTooLong:
            return "Task name cannot exceed 200 characters"
        case .detailsTooLong:
            return "Task details cannot exceed 1000 characters"
        case .invalidDuration:
            return "Duration must be greater than 0"
        case .tooManyTags:
            return "Cannot have more than 10 tags"
        case .tooManyDependencies:
            return "Cannot have more than 20 dependencies"
        case .circularDependency:
            return "Task cannot depend on itself"
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
