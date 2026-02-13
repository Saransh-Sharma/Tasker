//
//  CreateTaskUseCase.swift
//  Tasker
//
//  Use case for creating new tasks with validation and business rules
//

import Foundation

/// Use case for creating a new task
/// Encapsulates all business logic related to task creation
public final class CreateTaskUseCase {
    
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
    
    /// Creates a new task with validation and business rules
    /// - Parameter request: The task creation request
    /// - Returns: The created task or an error
    public func execute(request: CreateTaskRequest, completion: @escaping (Result<Task, CreateTaskError>) -> Void) {
        // Step 1: Validate the request
        guard let validationResult = validate(request: request) else {
            completion(.failure(.validationFailed("Invalid request data")))
            return
        }

        if !validationResult {
            completion(.failure(.validationFailed("Task validation failed")))
            return
        }

        // Step 2: Resolve project ID (prefer explicit UUID, then project name, then Inbox fallback)
        resolveProjectID(for: request) { [weak self] resolvedProjectID in
            self?.createTaskWithProjectID(request: request, projectID: resolvedProjectID, completion: completion)
        }
    }
    
    // MARK: - Private Methods
    
    private func createTaskWithProject(request: CreateTaskRequest, projectName: String, completion: @escaping (Result<Task, CreateTaskError>) -> Void) {
        // Deprecated: Use createTaskWithProjectID instead
        // Default to Inbox for backward compatibility
        createTaskWithProjectID(request: request, projectID: ProjectConstants.inboxProjectID, completion: completion)
    }

    private func resolveProjectID(for request: CreateTaskRequest, completion: @escaping (UUID) -> Void) {
        if let specifiedProjectID = request.projectID {
            projectRepository.fetchProject(withId: specifiedProjectID) { result in
                switch result {
                case .success(let project):
                    if project != nil || specifiedProjectID == ProjectConstants.inboxProjectID {
                        completion(specifiedProjectID)
                    } else {
                        completion(ProjectConstants.inboxProjectID)
                    }
                case .failure:
                    logWarning(
                        event: "create_task_project_lookup_failed",
                        message: "Failed to resolve project by ID; using Inbox",
                        fields: ["source": "project_id"]
                    )
                    completion(ProjectConstants.inboxProjectID)
                }
            }
            return
        }

        let requestedProjectName = request.project?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !requestedProjectName.isEmpty {
            projectRepository.fetchProject(withName: requestedProjectName) { result in
                switch result {
                case .success(let project):
                    if let project {
                        completion(project.id)
                    } else {
                        completion(ProjectConstants.inboxProjectID)
                    }
                case .failure:
                    logWarning(
                        event: "create_task_project_lookup_failed",
                        message: "Failed to resolve project by name; using Inbox",
                        fields: ["source": "project_name"]
                    )
                    completion(ProjectConstants.inboxProjectID)
                }
            }
            return
        }

        completion(ProjectConstants.inboxProjectID)
    }

    private func createTaskWithProjectID(request: CreateTaskRequest, projectID: UUID, completion: @escaping (Result<Task, CreateTaskError>) -> Void) {
        // Step 3: Apply business rules
        let today = Calendar.current.startOfDay(for: Date())
        var dueDate = request.dueDate ?? today
        var taskType = request.type

        // Business rule: If due date is in the past (before today), set to today
        if dueDate < today {
            dueDate = today
        }

        // Business rule: Determine task type based on time if not specified
        if request.type == .morning { // Use explicit default
            let hour = Calendar.current.component(.hour, from: dueDate)
            if hour < 12 {
                taskType = .morning
            } else if hour < 18 {
                taskType = .evening
            } else {
                taskType = .evening
            }
        }

        // Business rule: If task is due more than 7 days from now, mark as upcoming
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if daysUntilDue > 7 {
            taskType = .upcoming
        }

        // Step 4: Create the task with projectID
        let task = Task(
            projectID: projectID,
            name: request.name,
            details: request.details,
            type: taskType,
            priority: request.priority,
            dueDate: dueDate,
            project: request.project, // Keep for backward compatibility
            isComplete: false,
            dateAdded: Date(),
            isEveningTask: taskType == .evening,
            alertReminderTime: request.alertReminderTime,
            estimatedDuration: request.estimatedDuration,
            tags: request.tags,
            dependencies: request.dependencies,
            category: request.category,
            energy: request.energy,
            context: request.context,
            repeatPattern: request.repeatPattern
        )
        
        // Step 5: Validate the task
        do {
            try task.validate()
        } catch {
            completion(.failure(.validationFailed(error.localizedDescription)))
            return
        }
        
        // Step 6: Save to repository
        taskRepository.createTask(task) { [weak self] result in
            switch result {
            case .success(let createdTask):
                // Step 7: Schedule notification if reminder is set
                if let reminderTime = createdTask.alertReminderTime {
                    self?.notificationService?.scheduleTaskReminder(
                        taskId: createdTask.id,
                        taskName: createdTask.name,
                        at: reminderTime
                    )
                }
                
                // Step 8: Post creation notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskCreated"),
                    object: createdTask
                )
                
                completion(.success(createdTask))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    private func validate(request: CreateTaskRequest) -> Bool? {
        // Validate name
        if request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        // Validate name length
        if request.name.count > 200 {
            return false
        }
        
        // Validate details length if present
        if let details = request.details, details.count > 1000 {
            return false
        }
        
        return true
    }
}

// MARK: - Error Types

public enum CreateTaskError: LocalizedError {
    case validationFailed(String)
    case projectNotFound
    case repositoryError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .projectNotFound:
            return "Project not found"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        }
    }
}
