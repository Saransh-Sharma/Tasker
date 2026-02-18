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
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                // Step 2: Apply updates
                self?.applyUpdates(to: task, from: request) { updateResult in
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
                                self?.updateNotifications(oldTask: task, newTask: savedTask)
                                
                                // Step 6: Post update notification
                                TaskNotificationDispatcher.postOnMain(
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
        to task: Task,
        from request: UpdateTaskRequest,
        completion: @escaping (Result<Task, UpdateTaskError>) -> Void
    ) {
        var task = task
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
            let resolvedDueDate = dueDate < today ? today : dueDate
            task.dueDate = resolvedDueDate
            
            // Auto-adjust task type based on new date only when type was not explicitly provided.
            if request.type == nil, let newType = determineTaskType(for: resolvedDueDate) {
                task.type = newType
                task.isEveningTask = (newType == .evening)
            }
        }
        
        if let reminderTime = request.alertReminderTime {
            task.alertReminderTime = reminderTime
        }
        
        // Handle project change.
        let normalizedProjectName: String? = {
            guard let projectName = request.projectName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  projectName.isEmpty == false else {
                return nil
            }
            return projectName
        }()

        guard request.projectID != nil || normalizedProjectName != nil else {
            completion(.success(task))
            return
        }

        var updatedTask = task

        func applyFallbackProject() {
            updatedTask.projectID = ProjectConstants.inboxProjectID
            updatedTask.project = ProjectConstants.inboxProjectName
        }

        if let requestedProjectID = request.projectID {
            projectRepository.fetchProject(withId: requestedProjectID) { result in
                switch result {
                case .success(let project):
                    if let project {
                        updatedTask.projectID = project.id
                        updatedTask.project = project.name
                    } else if let normalizedProjectName {
                        // Preserve name intent if caller passed one, but keep a valid identity.
                        updatedTask.projectID = ProjectConstants.inboxProjectID
                        updatedTask.project = normalizedProjectName
                    } else {
                        applyFallbackProject()
                    }
                    completion(.success(updatedTask))

                case .failure:
                    if let normalizedProjectName {
                        updatedTask.projectID = ProjectConstants.inboxProjectID
                        updatedTask.project = normalizedProjectName
                    } else {
                        applyFallbackProject()
                    }
                    completion(.success(updatedTask))
                }
            }
            return
        }

        if let normalizedProjectName {
            projectRepository.fetchProject(withName: normalizedProjectName) { result in
                switch result {
                case .success(let project):
                    if let project {
                        updatedTask.projectID = project.id
                        updatedTask.project = project.name
                    } else {
                        applyFallbackProject()
                    }
                    completion(.success(updatedTask))

                case .failure:
                    applyFallbackProject()
                    completion(.success(updatedTask))
                }
            }
            return
        }

        completion(.success(updatedTask))
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
    public let projectID: UUID?
    public let projectName: String?
    public let alertReminderTime: Date?
    
    public init(
        name: String? = nil,
        details: String? = nil,
        type: TaskType? = nil,
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        projectID: UUID? = nil,
        projectName: String? = nil,
        alertReminderTime: Date? = nil
    ) {
        self.name = name
        self.details = details
        self.type = type
        self.priority = priority
        self.dueDate = dueDate
        self.projectID = projectID
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
