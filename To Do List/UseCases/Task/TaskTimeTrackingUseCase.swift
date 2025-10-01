//
//  TaskTimeTrackingUseCase.swift
//  Tasker
//
//  Use case for time estimation and tracking functionality
//

import Foundation

/// Use case for tracking time spent on tasks and improving time estimation
public final class TaskTimeTrackingUseCase {
    
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
    
    // MARK: - Time Tracking Methods
    
    /// Start tracking time for a task
    public func startTimeTracking(
        for taskId: UUID,
        completion: @escaping (Result<TimeTrackingSession, TimeTrackingError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                let session = TimeTrackingSession(
                    id: UUID(),
                    taskId: taskId,
                    startTime: Date(),
                    endTime: nil,
                    pausedDuration: 0,
                    isActive: true
                )
                
                self?.eventPublisher?.publish(TimeTrackingStarted(session: session, task: task))
                completion(.success(session))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Stop tracking time and update task
    public func stopTimeTracking(
        sessionId: UUID,
        completion: @escaping (Result<TimeTrackingResult, TimeTrackingError>) -> Void
    ) {
        // For now, simulate stopping time tracking
        let endTime = Date()
        let duration = TimeInterval(3600) // 1 hour simulation
        
        let result = TimeTrackingResult(
            sessionId: sessionId,
            totalDuration: duration,
            productiveDuration: duration * 0.9, // 90% productive
            breaksDuration: duration * 0.1,
            efficiency: 0.9
        )
        
        eventPublisher?.publish(TimeTrackingStopped(sessionId: sessionId, result: result))
        completion(.success(result))
    }
    
    /// Pause time tracking
    public func pauseTimeTracking(
        sessionId: UUID,
        completion: @escaping (Result<Void, TimeTrackingError>) -> Void
    ) {
        eventPublisher?.publish(TimeTrackingPaused(sessionId: sessionId, pauseTime: Date()))
        completion(.success(()))
    }
    
    /// Resume time tracking
    public func resumeTimeTracking(
        sessionId: UUID,
        completion: @escaping (Result<Void, TimeTrackingError>) -> Void
    ) {
        eventPublisher?.publish(TimeTrackingResumed(sessionId: sessionId, resumeTime: Date()))
        completion(.success(()))
    }
    
    /// Get time tracking history for a task
    public func getTimeTrackingHistory(
        for taskId: UUID,
        completion: @escaping (Result<TaskTimeHistory, TimeTrackingError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                let history = TaskTimeHistory(
                    taskId: taskId,
                    estimatedDuration: task.estimatedDuration,
                    actualDuration: task.actualDuration,
                    sessions: [], // Would be populated from a time tracking repository
                    efficiency: self.calculateEfficiency(estimated: task.estimatedDuration, actual: task.actualDuration),
                    averageSessionDuration: task.actualDuration ?? 0
                )
                
                completion(.success(history))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Update task with actual time spent
    public func updateTaskWithActualTime(
        taskId: UUID,
        actualDuration: TimeInterval,
        completion: @escaping (Result<Task, TimeTrackingError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard var task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                task.actualDuration = actualDuration
                
                self?.taskRepository.updateTask(task) { updateResult in
                    switch updateResult {
                    case .success(let updatedTask):
                        self?.eventPublisher?.publish(TaskTimeUpdated(task: updatedTask, actualDuration: actualDuration))
                        completion(.success(updatedTask))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get time tracking analytics
    public func getTimeTrackingAnalytics(
        completion: @escaping (Result<TimeTrackingAnalytics, TimeTrackingError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let analytics = self?.calculateTimeTrackingAnalytics(from: allTasks) ?? TimeTrackingAnalytics()
                completion(.success(analytics))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Suggest time estimate for a new task based on similar tasks
    public func suggestTimeEstimate(
        for taskData: TaskEstimationData,
        completion: @escaping (Result<TimeEstimateSuggestion, TimeTrackingError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let suggestion = self?.generateTimeEstimate(for: taskData, basedOn: allTasks) ?? TimeEstimateSuggestion()
                completion(.success(suggestion))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateEfficiency(estimated: TimeInterval?, actual: TimeInterval?) -> Double {
        guard let estimated = estimated, let actual = actual, estimated > 0, actual > 0 else {
            return 1.0
        }
        return estimated / actual
    }
    
    private func calculateTimeTrackingAnalytics(from tasks: [Task]) -> TimeTrackingAnalytics {
        let tasksWithBothTimes = tasks.filter { 
            $0.estimatedDuration != nil && $0.actualDuration != nil 
        }
        
        let totalEstimated = tasksWithBothTimes.compactMap { $0.estimatedDuration }.reduce(0, +)
        let totalActual = tasksWithBothTimes.compactMap { $0.actualDuration }.reduce(0, +)
        
        let efficiencyScores = tasksWithBothTimes.map { task in
            calculateEfficiency(estimated: task.estimatedDuration, actual: task.actualDuration)
        }
        
        let averageEfficiency = efficiencyScores.isEmpty ? 1.0 : efficiencyScores.reduce(0, +) / Double(efficiencyScores.count)
        
        let overestimatedTasks = efficiencyScores.filter { $0 > 1.2 }.count
        let underestimatedTasks = efficiencyScores.filter { $0 < 0.8 }.count
        let accurateEstimates = efficiencyScores.filter { $0 >= 0.8 && $0 <= 1.2 }.count
        
        return TimeTrackingAnalytics(
            totalTasksTracked: tasksWithBothTimes.count,
            totalEstimatedTime: totalEstimated,
            totalActualTime: totalActual,
            averageEfficiency: averageEfficiency,
            overestimatedTasks: overestimatedTasks,
            underestimatedTasks: underestimatedTasks,
            accurateEstimates: accurateEstimates,
            estimationAccuracy: tasksWithBothTimes.isEmpty ? 0 : Double(accurateEstimates) / Double(tasksWithBothTimes.count)
        )
    }
    
    private func generateTimeEstimate(for taskData: TaskEstimationData, basedOn allTasks: [Task]) -> TimeEstimateSuggestion {
        // Find similar tasks
        let similarTasks = allTasks.filter { task in
            var similarity = 0
            
            // Same category
            if task.category == taskData.category { similarity += 3 }
            
            // Same priority
            if task.priority == taskData.priority { similarity += 2 }
            
            // Same energy level
            if task.energy == taskData.energy { similarity += 2 }
            
            // Similar name (basic keyword matching)
            let taskWords = task.name.lowercased().components(separatedBy: .whitespaces)
            let dataWords = taskData.name.lowercased().components(separatedBy: .whitespaces)
            let commonWords = Set(taskWords).intersection(Set(dataWords))
            if !commonWords.isEmpty { similarity += commonWords.count }
            
            return similarity >= 3 // Minimum similarity threshold
        }
        
        if similarTasks.isEmpty {
            // Default estimates based on category and priority
            let baseEstimate = getDefaultEstimate(for: taskData)
            return TimeEstimateSuggestion(
                estimatedDuration: baseEstimate,
                confidence: .low,
                reasoning: "Default estimate based on task category and priority",
                similarTasksCount: 0,
                confidenceScore: 0.3
            )
        }
        
        // Calculate average duration from similar tasks
        let durations = similarTasks.compactMap { $0.actualDuration ?? $0.estimatedDuration }
        let averageDuration = durations.reduce(0, +) / Double(durations.count)
        
        let confidence = getConfidence(basedOn: similarTasks.count)
        
        return TimeEstimateSuggestion(
            estimatedDuration: averageDuration,
            confidence: confidence,
            reasoning: "Based on \(similarTasks.count) similar tasks",
            similarTasksCount: similarTasks.count,
            confidenceScore: min(Double(similarTasks.count) / 10.0, 1.0)
        )
    }
    
    private func getDefaultEstimate(for taskData: TaskEstimationData) -> TimeInterval {
        var baseTime: TimeInterval = 1800 // 30 minutes default
        
        // Adjust by category
        switch taskData.category {
        case .learning: baseTime = 3600 // 1 hour
        case .work: baseTime = 2700 // 45 minutes
        case .health: baseTime = 1800 // 30 minutes
        case .creative: baseTime = 5400 // 1.5 hours
        default: baseTime = 1800
        }
        
        // Adjust by priority
        switch taskData.priority {
        case .max: baseTime *= 1.5
        case .high: baseTime *= 1.2
        case .low: baseTime *= 0.8
        case .none: baseTime *= 0.6
        }
        
        // Adjust by energy
        switch taskData.energy {
        case .high: baseTime *= 1.3
        case .medium: baseTime *= 1.0
        case .low: baseTime *= 0.7
        }
        
        return baseTime
    }
    
    private func getConfidence(basedOn similarTasksCount: Int) -> EstimationConfidence {
        switch similarTasksCount {
        case 0...2: return .low
        case 3...5: return .medium
        case 6...10: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Supporting Models

public struct TimeTrackingSession {
    public let id: UUID
    public let taskId: UUID
    public let startTime: Date
    public let endTime: Date?
    public let pausedDuration: TimeInterval
    public let isActive: Bool
    
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime) - pausedDuration
    }
}

public struct TimeTrackingResult {
    public let sessionId: UUID
    public let totalDuration: TimeInterval
    public let productiveDuration: TimeInterval
    public let breaksDuration: TimeInterval
    public let efficiency: Double
}

public struct TaskTimeHistory {
    public let taskId: UUID
    public let estimatedDuration: TimeInterval?
    public let actualDuration: TimeInterval?
    public let sessions: [TimeTrackingSession]
    public let efficiency: Double
    public let averageSessionDuration: TimeInterval
}

public struct TimeTrackingAnalytics {
    public let totalTasksTracked: Int
    public let totalEstimatedTime: TimeInterval
    public let totalActualTime: TimeInterval
    public let averageEfficiency: Double
    public let overestimatedTasks: Int
    public let underestimatedTasks: Int
    public let accurateEstimates: Int
    public let estimationAccuracy: Double
    
    init(
        totalTasksTracked: Int = 0,
        totalEstimatedTime: TimeInterval = 0,
        totalActualTime: TimeInterval = 0,
        averageEfficiency: Double = 1.0,
        overestimatedTasks: Int = 0,
        underestimatedTasks: Int = 0,
        accurateEstimates: Int = 0,
        estimationAccuracy: Double = 0
    ) {
        self.totalTasksTracked = totalTasksTracked
        self.totalEstimatedTime = totalEstimatedTime
        self.totalActualTime = totalActualTime
        self.averageEfficiency = averageEfficiency
        self.overestimatedTasks = overestimatedTasks
        self.underestimatedTasks = underestimatedTasks
        self.accurateEstimates = accurateEstimates
        self.estimationAccuracy = estimationAccuracy
    }
}

public struct TaskEstimationData {
    public let name: String
    public let category: TaskCategory
    public let priority: TaskPriority
    public let energy: TaskEnergy
    public let context: TaskContext
    public let details: String?
    
    public init(name: String, category: TaskCategory, priority: TaskPriority, energy: TaskEnergy, context: TaskContext, details: String? = nil) {
        self.name = name
        self.category = category
        self.priority = priority
        self.energy = energy
        self.context = context
        self.details = details
    }
}

public enum EstimationConfidence {
    case low, medium, high, veryHigh
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }
}

public struct TimeEstimateSuggestion {
    public let estimatedDuration: TimeInterval
    public let confidence: EstimationConfidence
    public let reasoning: String
    public let similarTasksCount: Int
    public let confidenceScore: Double
    
    init(
        estimatedDuration: TimeInterval = 1800,
        confidence: EstimationConfidence = .low,
        reasoning: String = "",
        similarTasksCount: Int = 0,
        confidenceScore: Double = 0
    ) {
        self.estimatedDuration = estimatedDuration
        self.confidence = confidence
        self.reasoning = reasoning
        self.similarTasksCount = similarTasksCount
        self.confidenceScore = confidenceScore
    }
}

// MARK: - Events

public struct TimeTrackingStarted: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TimeTrackingStarted"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let session: TimeTrackingSession
    public let task: Task
    
    public init(session: TimeTrackingSession, task: Task) {
        self.session = session
        self.task = task
        self.aggregateId = task.id
        self.metadata = [
            "sessionId": session.id.uuidString,
            "taskId": task.id.uuidString
        ]
    }
}

public struct TimeTrackingStopped: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TimeTrackingStopped"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let sessionId: UUID
    public let result: TimeTrackingResult
    
    public init(sessionId: UUID, result: TimeTrackingResult) {
        self.sessionId = sessionId
        self.result = result
        self.aggregateId = sessionId // Using session as aggregate for tracking events
        self.metadata = [
            "sessionId": sessionId.uuidString,
            "duration": result.totalDuration
        ]
    }
}

public struct TimeTrackingPaused: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TimeTrackingPaused"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let sessionId: UUID
    public let pauseTime: Date
    
    public init(sessionId: UUID, pauseTime: Date) {
        self.sessionId = sessionId
        self.pauseTime = pauseTime
        self.aggregateId = sessionId
        self.metadata = [
            "sessionId": sessionId.uuidString,
            "pauseTime": pauseTime.timeIntervalSince1970
        ]
    }
}

public struct TimeTrackingResumed: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TimeTrackingResumed"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let sessionId: UUID
    public let resumeTime: Date
    
    public init(sessionId: UUID, resumeTime: Date) {
        self.sessionId = sessionId
        self.resumeTime = resumeTime
        self.aggregateId = sessionId
        self.metadata = [
            "sessionId": sessionId.uuidString,
            "resumeTime": resumeTime.timeIntervalSince1970
        ]
    }
}

public struct TaskTimeUpdated: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TaskTimeUpdated"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let task: Task
    public let actualDuration: TimeInterval
    
    public init(task: Task, actualDuration: TimeInterval) {
        self.task = task
        self.actualDuration = actualDuration
        self.aggregateId = task.id
        self.metadata = [
            "taskId": task.id.uuidString,
            "duration": actualDuration
        ]
    }
}

// MARK: - Error Types

public enum TimeTrackingError: LocalizedError {
    case taskNotFound
    case sessionNotFound
    case repositoryError(Error)
    case invalidTimeData
    case trackingAlreadyActive
    
    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .sessionNotFound:
            return "Time tracking session not found"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidTimeData:
            return "Invalid time tracking data"
        case .trackingAlreadyActive:
            return "Time tracking is already active for this task"
        }
    }
}