//
//  BulkUpdateTasksUseCase.swift
//  Tasker
//
//  Use case for performing bulk operations on tasks
//  Provides batch operations for efficient task management
//

import Foundation

/// Use case for bulk task operations
/// This enables efficient batch processing of multiple tasks
public final class BulkUpdateTasksUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let eventPublisher: DomainEventPublisher?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        eventPublisher: DomainEventPublisher? = nil
    ) {
        self.taskRepository = taskRepository
        self.eventPublisher = eventPublisher
    }
    
    // MARK: - Bulk Update Methods
    
    /// Complete multiple tasks at once
    public func bulkCompleteTasks(
        taskIds: [UUID],
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.isComplete = true
                updatedTask.dateCompleted = Date()
                return updatedTask
            },
            operationType: .complete,
            completion: completion
        )
    }
    
    /// Delete multiple tasks at once
    public func bulkDeleteTasks(
        taskIds: [UUID],
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        guard !taskIds.isEmpty else {
            completion(.failure(.emptyTaskList))
            return
        }
        
        var successCount = 0
        var failedIds: [UUID] = []
        let dispatchGroup = DispatchGroup()
        
        for taskId in taskIds {
            dispatchGroup.enter()
            
            taskRepository.deleteTask(withId: taskId) { result in
                switch result {
                case .success:
                    successCount += 1
                    self.eventPublisher?.publish(TaskDeletedEvent(taskId: taskId, taskName: "Task"))
                case .failure:
                    failedIds.append(taskId)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let result = BulkOperationResult(
                operationType: .delete,
                totalRequested: taskIds.count,
                successCount: successCount,
                failedIds: failedIds
            )
            completion(.success(result))
        }
    }
    
    /// Update priority for multiple tasks
    public func bulkUpdatePriority(
        taskIds: [UUID],
        newPriority: TaskPriority,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.priority = newPriority
                return updatedTask
            },
            operationType: .updatePriority,
            completion: completion
        )
    }
    
    /// Move multiple tasks to a different project
    public func bulkMoveToProject(
        taskIds: [UUID],
        projectName: String,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.project = projectName
                return updatedTask
            },
            operationType: .moveToProject,
            completion: completion
        )
    }
    
    /// Update category for multiple tasks
    public func bulkUpdateCategory(
        taskIds: [UUID],
        newCategory: TaskCategory,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.category = newCategory
                return updatedTask
            },
            operationType: .updateCategory,
            completion: completion
        )
    }
    
    /// Update context for multiple tasks
    public func bulkUpdateContext(
        taskIds: [UUID],
        newContext: TaskContext,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.context = newContext
                return updatedTask
            },
            operationType: .updateContext,
            completion: completion
        )
    }
    
    /// Update energy level for multiple tasks
    public func bulkUpdateEnergyLevel(
        taskIds: [UUID],
        newEnergyLevel: TaskEnergy,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.energy = newEnergyLevel
                return updatedTask
            },
            operationType: .updateEnergy,
            completion: completion
        )
    }
    
    /// Add tags to multiple tasks
    public func bulkAddTags(
        taskIds: [UUID],
        tags: [String],
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                let newTags = Set(updatedTask.tags).union(Set(tags))
                updatedTask.tags = Array(newTags)
                return updatedTask
            },
            operationType: .addTags,
            completion: completion
        )
    }
    
    /// Remove tags from multiple tasks
    public func bulkRemoveTags(
        taskIds: [UUID],
        tags: [String],
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.tags = updatedTask.tags.filter { !tags.contains($0) }
                return updatedTask
            },
            operationType: .removeTags,
            completion: completion
        )
    }
    
    /// Reschedule multiple tasks to a new date
    public func bulkReschedule(
        taskIds: [UUID],
        newDueDate: Date,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: { task in
                var updatedTask = task
                updatedTask.dueDate = newDueDate
                return updatedTask
            },
            operationType: .reschedule,
            completion: completion
        )
    }
    
    /// Archive completed tasks (move to archived project)
    public func bulkArchiveCompletedTasks(
        projectName: String? = nil,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        // First, fetch completed tasks
        let fetchCompletion: (Result<[Task], Error>) -> Void = { [weak self] result in
            switch result {
            case .success(let tasks):
                let completedTasks = tasks.filter { $0.isComplete }
                let taskIds = completedTasks.map { $0.id }
                
                guard !taskIds.isEmpty else {
                    completion(.success(BulkOperationResult(
                        operationType: .archive,
                        totalRequested: 0,
                        successCount: 0,
                        failedIds: []
                    )))
                    return
                }
                
                // Move to "Archived" project
                self?.bulkMoveToProject(
                    taskIds: taskIds,
                    projectName: "Archived",
                    completion: completion
                )
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
        
        if let projectName = projectName {
            taskRepository.fetchTasks(for: projectName, completion: fetchCompletion)
        } else {
            taskRepository.fetchCompletedTasks(completion: fetchCompletion)
        }
    }
    
    /// Perform custom bulk operation with provided update function
    public func bulkUpdateWithCustomOperation(
        taskIds: [UUID],
        updateOperation: @escaping (Task) -> Task,
        operationType: BulkOperationType,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        performBulkOperation(
            taskIds: taskIds,
            operation: updateOperation,
            operationType: operationType,
            completion: completion
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func performBulkOperation(
        taskIds: [UUID],
        operation: @escaping (Task) -> Task,
        operationType: BulkOperationType,
        completion: @escaping (Result<BulkOperationResult, BulkUpdateError>) -> Void
    ) {
        guard !taskIds.isEmpty else {
            completion(.failure(.emptyTaskList))
            return
        }
        
        guard taskIds.count <= BulkUpdateLimits.maxTasksPerOperation else {
            completion(.failure(.tooManyTasks(taskIds.count)))
            return
        }
        
        var successCount = 0
        var failedIds: [UUID] = []
        let dispatchGroup = DispatchGroup()
        
        for taskId in taskIds {
            dispatchGroup.enter()
            
            // First fetch the task
            taskRepository.fetchTask(withId: taskId) { [weak self] fetchResult in
                switch fetchResult {
                case .success(let task):
                    guard let task = task else {
                        failedIds.append(taskId)
                        dispatchGroup.leave()
                        return
                    }
                    
                    // Apply the operation
                    let updatedTask = operation(task)
                    
                    // Save the updated task
                    self?.taskRepository.updateTask(updatedTask) { updateResult in
                        switch updateResult {
                        case .success:
                            successCount += 1
                            self?.publishEventForOperation(operationType, task: updatedTask)
                        case .failure:
                            failedIds.append(taskId)
                        }
                        dispatchGroup.leave()
                    }
                    
                case .failure:
                    failedIds.append(taskId)
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let result = BulkOperationResult(
                operationType: operationType,
                totalRequested: taskIds.count,
                successCount: successCount,
                failedIds: failedIds
            )
            completion(.success(result))
        }
    }
    
    private func publishEventForOperation(_ operationType: BulkOperationType, task: Task) {
        switch operationType {
        case .complete:
            eventPublisher?.publish(TaskCompletedEvent(
                taskId: task.id,
                taskName: task.name,
                taskPriority: task.priority,
                scoreEarned: 0
            ))
        case .updatePriority:
            eventPublisher?.publish(TaskUpdatedEvent(
                taskId: task.id,
                changedFields: ["priority"],
                oldValues: [:],
                newValues: ["priority": task.priority.rawValue]
            ))
        case .moveToProject:
            eventPublisher?.publish(TaskUpdatedEvent(
                taskId: task.id,
                changedFields: ["project"],
                oldValues: [:],
                newValues: ["project": task.project ?? ""]
            ))
        case .updateCategory, .updateContext, .updateEnergy, .addTags, .removeTags, .reschedule:
            eventPublisher?.publish(TaskUpdatedEvent(
                taskId: task.id,
                changedFields: ["general"],
                oldValues: [:],
                newValues: [:]
            ))
        default:
            break
        }
    }
}

// MARK: - Supporting Models

public struct BulkOperationResult {
    public let operationType: BulkOperationType
    public let totalRequested: Int
    public let successCount: Int
    public let failedIds: [UUID]
    
    public var failureCount: Int { failedIds.count }
    public var successRate: Double {
        totalRequested > 0 ? Double(successCount) / Double(totalRequested) : 0.0
    }
    public var hasFailures: Bool { !failedIds.isEmpty }
}

public enum BulkOperationType {
    case complete
    case delete
    case updatePriority
    case moveToProject
    case updateCategory
    case updateContext
    case updateEnergy
    case addTags
    case removeTags
    case reschedule
    case archive
    case custom(String)
    
    public var displayName: String {
        switch self {
        case .complete: return "Complete Tasks"
        case .delete: return "Delete Tasks"
        case .updatePriority: return "Update Priority"
        case .moveToProject: return "Move to Project"
        case .updateCategory: return "Update Category"
        case .updateContext: return "Update Context"
        case .updateEnergy: return "Update Energy Level"
        case .addTags: return "Add Tags"
        case .removeTags: return "Remove Tags"
        case .reschedule: return "Reschedule Tasks"
        case .archive: return "Archive Tasks"
        case .custom(let name): return name
        }
    }
}

public struct BulkUpdateLimits {
    public static let maxTasksPerOperation = 100
    public static let maxTagsPerOperation = 10
}

// MARK: - Error Types

public enum BulkUpdateError: LocalizedError {
    case emptyTaskList
    case tooManyTasks(Int)
    case repositoryError(Error)
    case partialFailure([UUID])
    case invalidOperation
    
    public var errorDescription: String? {
        switch self {
        case .emptyTaskList:
            return "No tasks provided for bulk operation"
        case .tooManyTasks(let count):
            return "Too many tasks (\(count)). Maximum allowed: \(BulkUpdateLimits.maxTasksPerOperation)"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .partialFailure(let failedIds):
            return "Bulk operation partially failed. \(failedIds.count) tasks could not be updated."
        case .invalidOperation:
            return "Invalid bulk operation specified"
        }
    }
}