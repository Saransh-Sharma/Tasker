//
//  DeleteTaskUseCase.swift
//  Tasker
//
//  Use case for deleting tasks with cleanup
//

import Foundation

/// Use case for deleting tasks
/// Handles task deletion with proper cleanup and notifications
public final class DeleteTaskUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?
    private let analyticsService: AnalyticsServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        notificationService: NotificationServiceProtocol? = nil,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
        self.analyticsService = analyticsService
    }
    
    // MARK: - Execution
    
    /// Deletes a single task
    /// - Parameters:
    ///   - taskId: The ID of the task to delete
    ///   - completion: Completion handler with success or error
    public func execute(
        taskId: UUID,
        completion: @escaping (Result<Void, DeleteTaskError>) -> Void
    ) {
        // Step 1: Fetch the task to get its details before deletion
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    // Task doesn't exist, consider it already deleted
                    completion(.success(()))
                    return
                }
                
                // Step 2: Cancel any scheduled reminders
                if task.alertReminderTime != nil {
                    self?.notificationService?.cancelTaskReminder(taskId: task.id)
                }
                
                // Step 3: Track deletion in analytics
                self?.analyticsService?.trackTaskDeleted(task: task)
                
                // Step 4: Delete from repository
                self?.taskRepository.deleteTask(withId: taskId) { deleteResult in
                    switch deleteResult {
                    case .success:
                        // Step 5: Post deletion notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TaskDeleted"),
                            object: task
                        )
                        completion(.success(()))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Deletes multiple tasks
    /// - Parameters:
    ///   - taskIds: Array of task IDs to delete
    ///   - completion: Completion handler with count of deleted tasks or error
    public func executeBatch(
        taskIds: [UUID],
        completion: @escaping (Result<BatchDeleteResult, DeleteTaskError>) -> Void
    ) {
        guard !taskIds.isEmpty else {
            completion(.success(BatchDeleteResult(deletedCount: 0, failedCount: 0)))
            return
        }
        
        var deletedCount = 0
        var failedCount = 0
        let group = DispatchGroup()
        
        for taskId in taskIds {
            group.enter()
            execute(taskId: taskId) { result in
                switch result {
                case .success:
                    deletedCount += 1
                case .failure:
                    failedCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let result = BatchDeleteResult(
                deletedCount: deletedCount,
                failedCount: failedCount
            )
            completion(.success(result))
        }
    }
    
    /// Deletes all completed tasks
    /// - Parameter completion: Completion handler with success or error
    public func deleteAllCompleted(completion: @escaping (Result<Void, DeleteTaskError>) -> Void) {
        taskRepository.deleteCompletedTasks { result in
            switch result {
            case .success:
                // Post notification for bulk deletion
                NotificationCenter.default.post(
                    name: NSNotification.Name("CompletedTasksDeleted"),
                    object: nil
                )
                completion(.success(()))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Deletes tasks older than a specified date
    /// - Parameters:
    ///   - date: Delete tasks older than this date
    ///   - includeIncomplete: Whether to include incomplete tasks
    ///   - completion: Completion handler with count of deleted tasks
    public func deleteTasksOlderThan(
        date: Date,
        includeIncomplete: Bool = false,
        completion: @escaping (Result<Int, DeleteTaskError>) -> Void
    ) {
        // Fetch all tasks first
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                // Filter tasks older than the specified date
                let tasksToDelete = tasks.filter { task in
                    guard let taskDate = task.dueDate ?? task.dateAdded else { return false }
                    
                    if includeIncomplete {
                        return taskDate < date
                    } else {
                        return task.isComplete && taskDate < date
                    }
                }
                
                // Delete filtered tasks
                let taskIds = tasksToDelete.map { $0.id }
                self?.executeBatch(taskIds: taskIds) { batchResult in
                    switch batchResult {
                    case .success(let result):
                        completion(.success(result.deletedCount))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
}

// MARK: - Result Models

public struct BatchDeleteResult {
    public let deletedCount: Int
    public let failedCount: Int
    
    public var totalCount: Int {
        return deletedCount + failedCount
    }
    
    public var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(deletedCount) / Double(totalCount)
    }
}

// MARK: - Error Types

public enum DeleteTaskError: LocalizedError {
    case taskNotFound
    case repositoryError(Error)
    case batchDeletePartialFailure(deletedCount: Int, failedCount: Int)
    
    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .batchDeletePartialFailure(let deleted, let failed):
            return "Batch delete partially failed: \(deleted) deleted, \(failed) failed"
        }
    }
}
