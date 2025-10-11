//
//  UpdateTaskUseCase.swift
//  Tasker
//
//  Use case for updating existing tasks
//

import Foundation

/// Use case for updating existing tasks
/// Handles task updates with validation and business rules
public final class UpdateTaskUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.notificationService = notificationService
    }
    
    // MARK: - Execution
    
    /// Updates an existing task
    /// - Parameters:
    ///   - taskId: The ID of the task to update
    ///   - request: The update request with new values
    ///   - completion: Completion handler with updated task or error
    public func execute(
        taskId: UUID,
        request: UpdateTaskRequest,
        completion: @escaping (Result<Task, UpdateTaskError>) -> Void
    ) {
        // Step 1: Fetch the existing task
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard var task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                // Step 2: Apply updates
                self?.applyUpdates(to: &task, from: request) { updateResult in
                    switch updateResult {
                    case .success(let updatedTask):
                        // Step 3: Validate the updated task
                        do {
                            try updatedTask.validate()
                        } catch {
                            completion(.failure(.validationFailed(error.localizedDescription)))
                            return
                        }
                        
                        // Step 4: Save to repository
                        self?.taskRepository.updateTask(updatedTask) { saveResult in
                            switch saveResult {
                            case .success(let savedTask):
                                // Step 5: Update notifications if needed
                                self?.updateNotifications(
                                    oldTask: task,
                                    newTask: savedTask
                                )
                                
                                // Step 6: Post update notification
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("TaskUpdated"),
                                    object: savedTask
                                )
                                
                                completion(.success(savedTask))
                                
                            case .failure(let error):
                                completion(.failure(.repositoryError(error)))
                            }
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Batch update multiple tasks
    /// - Parameters:
    ///   - updates: Dictionary of task IDs to update requests
    ///   - completion: Completion handler with updated tasks or error
    public func executeBatch(
        updates: [UUID: UpdateTaskRequest],
        completion: @escaping (Result<[Task], UpdateTaskError>) -> Void
    ) {
        var updatedTasks: [Task] = []
        let group = DispatchGroup()
        var hasError = false
        
        for (taskId, request) in updates {
            group.enter()
            execute(taskId: taskId, request: request) { result in
                switch result {
                case .success(let task):
                    updatedTasks.append(task)
                case .failure:
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if hasError && updatedTasks.isEmpty {
                completion(.failure(.batchUpdateFailed))
            } else {
                completion(.success(updatedTasks))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func applyUpdates(
        to task: inout Task,
        from request: UpdateTaskRequest,
        completion: @escaping (Result<Task, UpdateTaskError>) -> Void
    ) {
        // Update basic properties
        if let name = request.name {
            task.name = name
        }
        
        if let details = request.details {
            task.details = details.isEmpty ? nil : details
        }
        
        if let type = request.type {
            task.type = type
            task.isEveningTask = (type == .evening)
        }
        
        if let priority = request.priority {
            task.priority = priority
        }
        
        if let dueDate = request.dueDate {
            // Business rule: If changing to a past date, set to today minimum
            let today = Calendar.current.startOfDay(for: Date())
            task.dueDate = dueDate < today ? today : dueDate
            
            // Auto-adjust task type based on new date
            if let newType = determineTaskType(for: dueDate) {
                task.type = newType
                task.isEveningTask = (newType == .evening)
            }
        }
        
        if let reminderTime = request.alertReminderTime {
            task.alertReminderTime = reminderTime
        }
        
        // Handle project change
        if let projectName = request.projectName {
            var updatedTask = task
            // Verify project exists
            projectRepository.fetchProject(withName: projectName) { result in
                switch result {
                case .success(let project):
                    if project != nil {
                        updatedTask.project = projectName
                    } else {
                        // Project doesn't exist, keep current or use Inbox
                        updatedTask.project = updatedTask.project ?? "Inbox"
                    }
                    completion(.success(updatedTask))
                    
                case .failure:
                    // On error, keep current project
                    completion(.success(updatedTask))
                }
            }
        } else {
            completion(.success(task))
        }
    }
    
    private func determineTaskType(for date: Date) -> TaskType? {
        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        // If more than 7 days away, mark as upcoming
        if daysUntil > 7 {
            return .upcoming
        }
        
        // Otherwise, determine by time of day
        let hour = calendar.component(.hour, from: date)
        if hour < 12 {
            return .morning
        } else {
            return .evening
        }
    }
    
    private func updateNotifications(oldTask: Task, newTask: Task) {
        // Cancel old reminder if it existed
        if oldTask.alertReminderTime != nil {
            notificationService?.cancelTaskReminder(taskId: oldTask.id)
        }
        
        // Schedule new reminder if set
        if let newReminderTime = newTask.alertReminderTime {
            notificationService?.scheduleTaskReminder(
                taskId: newTask.id,
                taskName: newTask.name,
                at: newReminderTime
            )
        }
    }
}

// MARK: - Request Model

public struct UpdateTaskRequest {
    public let name: String?
    public let details: String?
    public let type: TaskType?
    public let priority: TaskPriority?
    public let dueDate: Date?
    public let projectName: String?
    public let alertReminderTime: Date?
    
    public init(
        name: String? = nil,
        details: String? = nil,
        type: TaskType? = nil,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        projectName: String? = nil,
        alertReminderTime: Date? = nil
    ) {
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.projectName = projectName
        self.alertReminderTime = alertReminderTime
    }
}

// MARK: - Error Types

public enum UpdateTaskError: LocalizedError {
    case taskNotFound
    case validationFailed(String)
    case repositoryError(Error)
    case batchUpdateFailed
    
    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .batchUpdateFailed:
            return "Batch update failed"
        }
    }
}
