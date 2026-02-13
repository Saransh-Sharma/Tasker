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

    /// Deterministically sets the completion status based on explicit user intent.
    /// This avoids stale fetch-driven toggle direction errors.
    public func setCompletion(
        taskId: UUID,
        to desiredCompletion: Bool,
        taskSnapshot: Task?,
        completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void
    ) {
        let inputState = taskSnapshot?.isComplete
        logDebug(
            "HOME_ROW_STATE usecase.set_completion " +
            "id=\(taskId.uuidString) requested=\(desiredCompletion) input=\(String(describing: inputState))"
        )

        if desiredCompletion {
            forceComplete(taskId: taskId, taskSnapshot: taskSnapshot, completion: completion)
        } else {
            forceUncomplete(taskId: taskId, taskSnapshot: taskSnapshot, completion: completion)
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

    private func forceComplete(
        taskId: UUID,
        taskSnapshot: Task?,
        completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void
    ) {
        taskRepository.completeTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let updatedTask):
                guard let self else { return }
                let score = self.scoreForCompletion(task: updatedTask, fallback: taskSnapshot)
                self.analyticsService?.trackTaskCompleted(
                    task: updatedTask,
                    score: score,
                    completionTime: Date()
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskCompletionChanged"),
                    object: updatedTask
                )

                logDebug(
                    "HOME_ROW_STATE usecase.set_completion_result " +
                    "id=\(taskId.uuidString) requested=true result=\(updatedTask.isComplete)"
                )

                completion(.success(TaskCompletionResult(
                    task: updatedTask,
                    scoreEarned: score,
                    currentStreak: self.calculateStreak(for: updatedTask),
                    completedAt: updatedTask.dateCompleted ?? Date()
                )))

            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }

    private func forceUncomplete(
        taskId: UUID,
        taskSnapshot: Task?,
        completion: @escaping (Result<TaskCompletionResult, CompleteTaskError>) -> Void
    ) {
        taskRepository.uncompleteTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let updatedTask):
                guard let self else { return }
                let scoreToDeduct = self.scoreForUncompletion(task: updatedTask, fallback: taskSnapshot)
                self.analyticsService?.trackTaskUncompleted(
                    task: updatedTask,
                    scoreDeducted: scoreToDeduct
                )

                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskCompletionChanged"),
                    object: updatedTask
                )

                logDebug(
                    "HOME_ROW_STATE usecase.set_completion_result " +
                    "id=\(taskId.uuidString) requested=false result=\(updatedTask.isComplete)"
                )

                completion(.success(TaskCompletionResult(
                    task: updatedTask,
                    scoreEarned: -scoreToDeduct,
                    currentStreak: 0,
                    completedAt: nil
                )))

            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }

    private func scoreForCompletion(task: Task, fallback: Task?) -> Int {
        var scoringTask = task
        if !scoringTask.isComplete {
            scoringTask.isComplete = true
        }
        if scoringTask.dateCompleted == nil {
            scoringTask.dateCompleted = Date()
        }

        let computed = scoringService.calculateScore(for: scoringTask)
        if computed > 0 {
            return computed
        }

        if let fallback {
            var fallbackScoringTask = fallback
            fallbackScoringTask.isComplete = true
            fallbackScoringTask.dateCompleted = fallbackScoringTask.dateCompleted ?? Date()
            let fallbackScore = scoringService.calculateScore(for: fallbackScoringTask)
            if fallbackScore > 0 {
                return fallbackScore
            }
            return fallback.priority.scorePoints
        }

        return task.priority.scorePoints
    }

    private func scoreForUncompletion(task: Task, fallback: Task?) -> Int {
        if let fallback {
            var fallbackScoringTask = fallback
            fallbackScoringTask.isComplete = true
            fallbackScoringTask.dateCompleted = fallbackScoringTask.dateCompleted ?? Date()
            let fallbackScore = scoringService.calculateScore(for: fallbackScoringTask)
            if fallbackScore > 0 {
                return fallbackScore
            }
            return fallback.priority.scorePoints
        }

        var scoringTask = task
        scoringTask.isComplete = true
        scoringTask.dateCompleted = scoringTask.dateCompleted ?? Date()
        let computed = scoringService.calculateScore(for: scoringTask)
        return computed > 0 ? computed : task.priority.scorePoints
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

