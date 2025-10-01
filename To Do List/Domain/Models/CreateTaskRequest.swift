//
//  CreateTaskRequest.swift
//  Tasker
//
//  Request model for creating new tasks
//

import Foundation

/// Request model for creating a new task
public struct CreateTaskRequest {
    // MARK: - Properties
    
    public var name: String
    public var details: String?
    public var type: TaskType
    public var priority: TaskPriority
    public var dueDate: Date?
    public var project: String?
    public var alertReminderTime: Date?
    public var estimatedDuration: TimeInterval?
    public var tags: [String]
    public var dependencies: [UUID]
    public var category: TaskCategory
    public var energy: TaskEnergy
    public var context: TaskContext
    public var repeatPattern: TaskRepeatPattern?
    
    // MARK: - Initialization
    
    public init(
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        dueDate: Date? = nil,
        project: String? = "Inbox",
        alertReminderTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        tags: [String] = [],
        dependencies: [UUID] = [],
        category: TaskCategory = .general,
        energy: TaskEnergy = .medium,
        context: TaskContext = .anywhere,
        repeatPattern: TaskRepeatPattern? = nil
    ) {
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.project = project
        self.alertReminderTime = alertReminderTime
        self.estimatedDuration = estimatedDuration
        self.tags = tags
        self.dependencies = dependencies
        self.category = category
        self.energy = energy
        self.context = context
        self.repeatPattern = repeatPattern
    }
    
    // MARK: - Convenience Initializers
    
    /// Create a quick task request with minimal information
    public static func quick(
        name: String,
        priority: TaskPriority = .low,
        dueDate: Date? = nil
    ) -> CreateTaskRequest {
        return CreateTaskRequest(
            name: name,
            priority: priority,
            dueDate: dueDate
        )
    }
    
    /// Create a detailed task request
    public static func detailed(
        name: String,
        details: String,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        dueDate: Date?,
        project: String? = nil,
        estimatedDuration: TimeInterval? = nil
    ) -> CreateTaskRequest {
        return CreateTaskRequest(
            name: name,
            details: details,
            type: type,
            priority: priority,
            dueDate: dueDate,
            project: project,
            estimatedDuration: estimatedDuration
        )
    }
    
    /// Create a recurring task request
    public static func recurring(
        name: String,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        repeatPattern: TaskRepeatPattern
    ) -> CreateTaskRequest {
        return CreateTaskRequest(
            name: name,
            type: type,
            priority: priority,
            repeatPattern: repeatPattern
        )
    }
    
    // MARK: - Conversion
    
    /// Convert to a Task domain model
    public func toTask() -> Task {
        return Task(
            name: name,
            details: details,
            type: type,
            priority: priority,
            dueDate: dueDate,
            project: project,
            alertReminderTime: alertReminderTime,
            estimatedDuration: estimatedDuration,
            tags: tags,
            dependencies: dependencies,
            category: category,
            energy: energy,
            context: context,
            repeatPattern: repeatPattern
        )
    }
    
    // MARK: - Validation
    
    /// Validate the request data
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CreateTaskValidationError.emptyName
        }
        
        if name.count > 200 {
            throw CreateTaskValidationError.nameTooLong
        }
        
        if let details = details, details.count > 1000 {
            throw CreateTaskValidationError.detailsTooLong
        }
        
        if let estimatedDuration = estimatedDuration, estimatedDuration <= 0 {
            throw CreateTaskValidationError.invalidDuration
        }
        
        if tags.count > 10 {
            throw CreateTaskValidationError.tooManyTags
        }
        
        if dependencies.count > 20 {
            throw CreateTaskValidationError.tooManyDependencies
        }
        
        // Validate project name if provided
        if let project = project, project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CreateTaskValidationError.emptyProject
        }
        
        // Validate due date is not in the past (with 1 minute tolerance)
        if let dueDate = dueDate, dueDate < Date().addingTimeInterval(-60) {
            throw CreateTaskValidationError.dueDateInPast
        }
        
        // Validate reminder time is before due date
        if let reminderTime = alertReminderTime,
           let dueDate = dueDate,
           reminderTime >= dueDate {
            throw CreateTaskValidationError.reminderAfterDueDate
        }
    }
}

// MARK: - Validation Errors

public enum CreateTaskValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case detailsTooLong
    case invalidDuration
    case tooManyTags
    case tooManyDependencies
    case emptyProject
    case dueDateInPast
    case reminderAfterDueDate
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Task name cannot be empty"
        case .nameTooLong:
            return "Task name cannot exceed 200 characters"
        case .detailsTooLong:
            return "Task details cannot exceed 1000 characters"
        case .invalidDuration:
            return "Estimated duration must be greater than 0"
        case .tooManyTags:
            return "Cannot have more than 10 tags"
        case .tooManyDependencies:
            return "Cannot have more than 20 dependencies"
        case .emptyProject:
            return "Project name cannot be empty if specified"
        case .dueDateInPast:
            return "Due date cannot be in the past"
        case .reminderAfterDueDate:
            return "Reminder time must be before due date"
        }
    }
}

// MARK: - Builder Pattern

/// Builder for creating CreateTaskRequest with fluent API
public class CreateTaskRequestBuilder {
    private var request: CreateTaskRequest
    
    public init(name: String) {
        self.request = CreateTaskRequest(name: name)
    }
    
    public func details(_ details: String) -> CreateTaskRequestBuilder {
        request.details = details
        return self
    }
    
    public func type(_ type: TaskType) -> CreateTaskRequestBuilder {
        request.type = type
        return self
    }
    
    public func priority(_ priority: TaskPriority) -> CreateTaskRequestBuilder {
        request.priority = priority
        return self
    }
    
    public func dueDate(_ date: Date) -> CreateTaskRequestBuilder {
        request.dueDate = date
        return self
    }
    
    public func project(_ project: String) -> CreateTaskRequestBuilder {
        request.project = project
        return self
    }
    
    public func reminder(_ time: Date) -> CreateTaskRequestBuilder {
        request.alertReminderTime = time
        return self
    }
    
    public func estimatedDuration(_ duration: TimeInterval) -> CreateTaskRequestBuilder {
        request.estimatedDuration = duration
        return self
    }
    
    public func tags(_ tags: [String]) -> CreateTaskRequestBuilder {
        request.tags = tags
        return self
    }
    
    public func addTag(_ tag: String) -> CreateTaskRequestBuilder {
        request.tags.append(tag)
        return self
    }
    
    public func dependencies(_ dependencies: [UUID]) -> CreateTaskRequestBuilder {
        request.dependencies = dependencies
        return self
    }
    
    public func addDependency(_ taskId: UUID) -> CreateTaskRequestBuilder {
        request.dependencies.append(taskId)
        return self
    }
    
    public func category(_ category: TaskCategory) -> CreateTaskRequestBuilder {
        request.category = category
        return self
    }
    
    public func energy(_ energy: TaskEnergy) -> CreateTaskRequestBuilder {
        request.energy = energy
        return self
    }
    
    public func context(_ context: TaskContext) -> CreateTaskRequestBuilder {
        request.context = context
        return self
    }
    
    public func repeatPattern(_ pattern: TaskRepeatPattern) -> CreateTaskRequestBuilder {
        request.repeatPattern = pattern
        return self
    }
    
    public func build() throws -> CreateTaskRequest {
        try request.validate()
        return request
    }
    
    public func buildUnsafe() -> CreateTaskRequest {
        return request
    }
}

// MARK: - Extensions

extension CreateTaskRequest {
    /// Create a builder for this request type
    public static func builder(name: String) -> CreateTaskRequestBuilder {
        return CreateTaskRequestBuilder(name: name)
    }
}