//
//  CompleteTaskUseCase.swift
//  Tasker
//
//  Use case for completing tasks with scoring and analytics
//

import Foundation

/// Use case for completing or uncompleting tasks
/// Handles scoring, analytics, and notifications
public final class CompleteTaskUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let scoringService: TaskScoringServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        scoringService: TaskScoringServiceProtocol,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.scoringService = scoringService
        self.analyticsService = analyticsService
    }
    
    // MARK: - Execution
    
    /// Toggles the completion status of a task
    /// - Parameters:
    ///   - taskId: The ID of the task to toggle
    ///   - completion: Completion handler with the updated task or error
    public func execute(taskId: UUID, completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void) {
        // Step 1: Fetch the current task
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                // Step 2: Toggle completion status
                if task.isComplete {
                    self?.uncompleteTask(task, completion: completion)
                } else {
                    self?.completeTask(task, completion: completion)
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Marks a specific task as complete
    public func completeTask(_ taskId: UUID, completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                self?.completeTask(task, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Marks a specific task as incomplete
    public func uncompleteTask(_ taskId: UUID, completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                self?.uncompleteTask(task, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func completeTask(_ task: Task, completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void) {
        // Business rule: Can't complete an already completed task
        guard !task.isComplete else {
            completion(.failure(.alreadyCompleted))
            return
        }
        
        // Step 3: Calculate score
        let score = scoringService.calculateScore(for: task)
        
        // Step 4: Update task in repository
        taskRepository.completeTask(withId: task.id) { [weak self] result in
            switch result {
            case .success(let updatedTask):
                // Step 5: Track analytics
                self?.analyticsService?.trackTaskCompleted(
                    task: updatedTask,
                    score: score,
                    completionTime: Date()
                )
                
                // Step 6: Calculate streak
                let streak = self?.calculateStreak(for: updatedTask) ?? 0
                
                // Step 7: Post completion notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskCompletionChanged"),
                    object: updatedTask
                )
                
                // Step 8: Return result
                let result = TaskCompletionResult(
                    task: updatedTask,
                    scoreEarned: score,
                    currentStreak: streak,
                    completedAt: Date()
                )
                
                completion(.success(result))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    private func uncompleteTask(_ task: Task, completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void) {
        // Business rule: Can't uncomplete a task that's not completed
        guard task.isComplete else {
            completion(.failure(.notCompleted))
            return
        }
        
        // Step 3: Calculate score to deduct
        let scoreToDeduct = scoringService.calculateScore(for: task)
        
        // Step 4: Update task in repository
        taskRepository.uncompleteTask(withId: task.id) { [weak self] result in
            switch result {
            case .success(let updatedTask):
                // Step 5: Track analytics
                self?.analyticsService?.trackTaskUncompleted(
                    task: updatedTask,
                    scoreDeducted: scoreToDeduct
                )
                
                // Step 6: Post completion notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskCompletionChanged"),
                    object: updatedTask
                )
                
                // Step 7: Return result
                let result = TaskCompletionResult(
                    task: updatedTask,
                    scoreEarned: -scoreToDeduct,
                    currentStreak: 0,
                    completedAt: nil
                )
                
                completion(.success(result))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    private func calculateStreak(for task: Task) -> Int {
        // This is a simplified streak calculation
        // In a real implementation, you'd track consecutive days of task completion
        return 1
    }
}

// MARK: - Result Model

public struct TaskCompletionResult {
    public let task: Task
    public let scoreEarned: Int
    public let currentStreak: Int
    public let completedAt: Date?
}

// MARK: - Error Types

public enum CompleteTaskError: LocalizedError {
    case taskNotFound
    case alreadyCompleted
    case notCompleted
    case repositoryError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .alreadyCompleted:
            return "Task is already completed"
        case .notCompleted:
            return "Task is not completed"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service Protocols

public protocol TaskScoringServiceProtocol {
    func calculateScore(for task: Task) -> Int
    func getTotalScore(completion: @escaping (Int) -> Void)
    func getScoreHistory(days: Int, completion: @escaping ([DailyScore]) -> Void)
}

public protocol AnalyticsServiceProtocol {
    func trackTaskCompleted(task: Task, score: Int, completionTime: Date)
    func trackTaskUncompleted(task: Task, scoreDeducted: Int)
    func trackTaskCreated(task: Task)
    func trackTaskDeleted(task: Task)
}

public struct DailyScore {
    public let date: Date
    public let score: Int
    public let tasksCompleted: Int
}
