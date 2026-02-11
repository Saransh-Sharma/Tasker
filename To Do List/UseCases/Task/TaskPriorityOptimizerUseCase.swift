//
//  TaskPriorityOptimizerUseCase.swift
//  Tasker
//
//  Use case for dynamic task priority optimization based on context and patterns
//

import Foundation

/// Use case for dynamically optimizing task priorities based on various factors
public final class TaskPriorityOptimizerUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let analyticsRepository: AnalyticsRepositoryProtocol?
    private let contextService: ContextAnalysisService
    private let priorityEngine: PriorityOptimizationEngine
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol? = nil,
        contextService: ContextAnalysisService? = nil,
        priorityEngine: PriorityOptimizationEngine? = nil
    ) {
        self.taskRepository = taskRepository
        self.analyticsRepository = analyticsRepository
        self.contextService = contextService ?? ContextAnalysisService()
        self.priorityEngine = priorityEngine ?? PriorityOptimizationEngine()
    }
    
    // MARK: - Priority Optimization
    
    /// Optimize priorities for all tasks
    public func optimizeAllTaskPriorities(completion: @escaping (Result<PriorityOptimizationResult, PriorityOptimizationError>) -> Void) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.performPriorityOptimization(for: tasks, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Optimize priorities for tasks due today
    public func optimizeTodayTaskPriorities(completion: @escaping (Result<PriorityOptimizationResult, PriorityOptimizationError>) -> Void) {
        let today = Date()
        taskRepository.fetchTasks(for: today) { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.performPriorityOptimization(for: tasks, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Optimize priority for a specific task
    public func optimizeTaskPriority(
        taskId: UUID,
        completion: @escaping (Result<TaskPriorityUpdate, PriorityOptimizationError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                self?.optimizeSingleTask(task, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Auto-adjust priorities based on deadlines and context
    public func autoAdjustPriorities(completion: @escaping (Result<PriorityOptimizationResult, PriorityOptimizationError>) -> Void) {
        // Get context information
        let currentContext = contextService.getCurrentContext()
        
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                let adjustments = self?.calculateAutoAdjustments(tasks: tasks, context: currentContext) ?? []
                self?.applyPriorityAdjustments(adjustments, completion: completion)
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Smart Priority Suggestions
    
    /// Get priority suggestions for a task
    public func getPrioritySuggestions(
        for task: Task,
        completion: @escaping (Result<[PrioritySuggestion], PriorityOptimizationError>) -> Void
    ) {
        // Analyze task context
        let analysis = contextService.analyzeTask(task)
        
        // Get suggestions from priority engine
        let suggestions = priorityEngine.generateSuggestions(
            for: task,
            context: analysis,
            historicalData: getHistoricalData(for: task)
        )
        
        completion(.success(suggestions))
    }
    
    /// Get bulk priority recommendations
    public func getBulkPriorityRecommendations(
        for tasks: [Task],
        completion: @escaping (Result<[TaskPriorityRecommendation], PriorityOptimizationError>) -> Void
    ) {
        let context = contextService.getCurrentContext()
        var recommendations: [TaskPriorityRecommendation] = []
        
        for task in tasks {
            let taskContext = contextService.analyzeTask(task)
            let recommendation = priorityEngine.recommendPriority(
                for: task,
                context: taskContext,
                globalContext: context
            )
            recommendations.append(recommendation)
        }
        
        completion(.success(recommendations))
    }
    
    // MARK: - Priority Learning
    
    /// Learn from user priority adjustments
    public func learnFromUserAdjustment(
        taskId: UUID,
        oldPriority: TaskPriority,
        newPriority: TaskPriority,
        userReason: String?
    ) {
        let learningData = PriorityLearningData(
            taskId: taskId,
            oldPriority: oldPriority,
            newPriority: newPriority,
            adjustmentTime: Date(),
            userReason: userReason,
            context: contextService.getCurrentContext()
        )
        
        priorityEngine.recordLearningData(learningData)
    }
    
    /// Get priority insights based on learning
    public func getPriorityInsights(completion: @escaping (Result<PriorityInsights, PriorityOptimizationError>) -> Void) {
        analyticsRepository?.fetchCompletionPatterns(for: nil) { [weak self] result in
            switch result {
            case .success(let completionPatterns):
                // Convert completion patterns to analytics
                let analytics = PriorityAnalytics(
                    totalAdjustments: completionPatterns.count,
                    accurateRecommendations: completionPatterns.filter { $0.successRate > 0.7 }.count,
                    mostCommonAdjustment: "Priority optimization based on completion patterns"
                )
                let insights = self?.priorityEngine.generateInsights(from: analytics) ?? PriorityInsights()
                completion(.success(insights))
            case .failure(let error):
                completion(.failure(.analyticsError(error)))
            }
        } ?? completion(.success(PriorityInsights()))
    }
    
    // MARK: - Private Methods
    
    private func performPriorityOptimization(
        for tasks: [Task],
        completion: @escaping (Result<PriorityOptimizationResult, PriorityOptimizationError>) -> Void
    ) {
        let context = contextService.getCurrentContext()
        var optimizedTasks: [Task] = []
        var changes: [PriorityChange] = []
        
        for task in tasks {
            let taskContext = contextService.analyzeTask(task)
            let optimizedPriority = priorityEngine.optimizePriority(
                for: task,
                context: taskContext,
                globalContext: context
            )
            
            if optimizedPriority != task.priority {
                var updatedTask = task
                updatedTask.priority = optimizedPriority
                optimizedTasks.append(updatedTask)
                
                changes.append(PriorityChange(
                    taskId: task.id,
                    oldPriority: task.priority,
                    newPriority: optimizedPriority,
                    reason: priorityEngine.getOptimizationReason(for: task, newPriority: optimizedPriority)
                ))
            }
        }
        
        // Apply changes
        if !optimizedTasks.isEmpty {
            applyPriorityChanges(optimizedTasks) { result in
                switch result {
                case .success:
                    let optimizationResult = PriorityOptimizationResult(
                        tasksOptimized: optimizedTasks.count,
                        changes: changes,
                        optimizationTime: Date()
                    )
                    completion(.success(optimizationResult))
                case .failure(let error):
                    completion(.failure(.repositoryError(error)))
                }
            }
        } else {
            let result = PriorityOptimizationResult(
                tasksOptimized: 0,
                changes: [],
                optimizationTime: Date()
            )
            completion(.success(result))
        }
    }
    
    private func optimizeSingleTask(
        _ task: Task,
        completion: @escaping (Result<TaskPriorityUpdate, PriorityOptimizationError>) -> Void
    ) {
        let taskContext = contextService.analyzeTask(task)
        let globalContext = contextService.getCurrentContext()
        
        let optimizedPriority = priorityEngine.optimizePriority(
            for: task,
            context: taskContext,
            globalContext: globalContext
        )
        
        if optimizedPriority != task.priority {
            var updatedTask = task
            updatedTask.priority = optimizedPriority
            
            taskRepository.updateTask(updatedTask) { result in
                switch result {
                case .success(let savedTask):
                    let update = TaskPriorityUpdate(
                        task: savedTask,
                        oldPriority: task.priority,
                        newPriority: optimizedPriority,
                        optimizationReason: self.priorityEngine.getOptimizationReason(for: task, newPriority: optimizedPriority)
                    )
                    completion(.success(update))
                case .failure(let error):
                    completion(.failure(.repositoryError(error)))
                }
            }
        } else {
            let update = TaskPriorityUpdate(
                task: task,
                oldPriority: task.priority,
                newPriority: task.priority,
                optimizationReason: "Priority already optimal"
            )
            completion(.success(update))
        }
    }
    
    private func calculateAutoAdjustments(tasks: [Task], context: ContextInformation) -> [PriorityAdjustment] {
        var adjustments: [PriorityAdjustment] = []
        
        for task in tasks {
            let taskContext = contextService.analyzeTask(task)
            
            // Check if priority needs adjustment based on:
            // 1. Approaching deadline
            // 2. Dependencies
            // 3. User patterns
            // 4. Context changes
            
            if let adjustment = priorityEngine.calculateAdjustment(
                for: task,
                context: taskContext,
                globalContext: context
            ) {
                adjustments.append(adjustment)
            }
        }
        
        return adjustments
    }
    
    private func applyPriorityAdjustments(
        _ adjustments: [PriorityAdjustment],
        completion: @escaping (Result<PriorityOptimizationResult, PriorityOptimizationError>) -> Void
    ) {
        let group = DispatchGroup()
        var updatedTasks: [Task] = []
        var changes: [PriorityChange] = []
        var hasError = false
        
        for adjustment in adjustments {
            group.enter()
            
            taskRepository.fetchTask(withId: adjustment.taskId) { [weak self] result in
                switch result {
                case .success(let task):
                    guard var task = task else {
                        hasError = true
                        group.leave()
                        return
                    }
                    let oldPriority = task.priority
                    task.priority = adjustment.newPriority
                    
                    self?.taskRepository.updateTask(task) { updateResult in
                        switch updateResult {
                        case .success(let savedTask):
                            updatedTasks.append(savedTask)
                            changes.append(PriorityChange(
                                taskId: savedTask.id,
                                oldPriority: oldPriority,
                                newPriority: adjustment.newPriority,
                                reason: adjustment.reason
                            ))
                        case .failure:
                            hasError = true
                        }
                        group.leave()
                    }
                case .failure:
                    hasError = true
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if hasError {
                completion(.failure(.optimizationFailed))
            } else {
                let result = PriorityOptimizationResult(
                    tasksOptimized: updatedTasks.count,
                    changes: changes,
                    optimizationTime: Date()
                )
                completion(.success(result))
            }
        }
    }
    
    private func applyPriorityChanges(
        _ tasks: [Task],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let group = DispatchGroup()
        var hasError = false
        
        for task in tasks {
            group.enter()
            taskRepository.updateTask(task) { result in
                if case .failure = result {
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if hasError {
                completion(.failure(PriorityOptimizationError.optimizationFailed))
            } else {
                completion(.success(()))
            }
        }
    }
    
    private func getHistoricalData(for task: Task) -> TaskHistoricalData? {
        // This would typically fetch from analytics repository
        return nil
    }
}

// MARK: - Supporting Services

public class ContextAnalysisService {
    
    public init() {}
    
    public func getCurrentContext() -> ContextInformation {
        return ContextInformation(
            currentTime: Date(),
            dayOfWeek: Calendar.current.component(.weekday, from: Date()),
            timeOfDay: getTimeOfDay(),
            location: nil, // Would be populated from location service
            workingHours: isWorkingHours(),
            userActivity: .unknown
        )
    }
    
    public func analyzeTask(_ task: Task) -> TaskAnalysisContext {
        return TaskAnalysisContext(
            urgencyScore: calculateUrgencyScore(task),
            importanceScore: calculateImportanceScore(task),
            effortEstimate: task.estimatedDuration ?? 0,
            dependencies: [], // Would be calculated
            contextRelevance: calculateContextRelevance(task)
        )
    }
    
    private func getTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
    
    private func isWorkingHours() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday >= 2 && weekday <= 6 && hour >= 9 && hour <= 17
    }
    
    private func calculateUrgencyScore(_ task: Task) -> Double {
        guard let dueDate = task.dueDate else { return 0.5 }
        
        let timeInterval = dueDate.timeIntervalSinceNow
        let daysUntilDue = timeInterval / (24 * 60 * 60)
        
        switch daysUntilDue {
        case ...0: return 1.0 // Overdue
        case 0...1: return 0.9 // Due today
        case 1...3: return 0.7 // Due in 1-3 days
        case 3...7: return 0.5 // Due in a week
        default: return 0.3 // Due later
        }
    }
    
    private func calculateImportanceScore(_ task: Task) -> Double {
        return task.priority.normalizedValue
    }
    
    private func calculateContextRelevance(_ task: Task) -> Double {
        // This would analyze if the task is relevant to current context
        return 0.5
    }
}

public class PriorityOptimizationEngine {
    
    private var learningData: [PriorityLearningData] = []
    
    public init() {}
    
    public func optimizePriority(
        for task: Task,
        context: TaskAnalysisContext,
        globalContext: ContextInformation
    ) -> TaskPriority {
        let score = calculateOptimalPriorityScore(
            task: task,
            context: context,
            globalContext: globalContext
        )
        
        return TaskPriority.fromScore(score)
    }
    
    public func recommendPriority(
        for task: Task,
        context: TaskAnalysisContext,
        globalContext: ContextInformation
    ) -> TaskPriorityRecommendation {
        let recommendedPriority = optimizePriority(
            for: task,
            context: context,
            globalContext: globalContext
        )
        
        let confidence = calculateConfidence(
            task: task,
            context: context,
            recommendedPriority: recommendedPriority
        )
        
        return TaskPriorityRecommendation(
            taskId: task.id,
            currentPriority: task.priority,
            recommendedPriority: recommendedPriority,
            confidence: confidence,
            reasoning: generateReasoning(
                task: task,
                context: context,
                recommendedPriority: recommendedPriority
            )
        )
    }
    
    public func generateSuggestions(
        for task: Task,
        context: TaskAnalysisContext,
        historicalData: TaskHistoricalData?
    ) -> [PrioritySuggestion] {
        var suggestions: [PrioritySuggestion] = []
        
        // Generate suggestions based on different factors
        if context.urgencyScore > 0.8 {
            suggestions.append(PrioritySuggestion(
                priority: .max,
                reason: "Task is very urgent due to approaching deadline",
                confidence: 0.9
            ))
        }
        
        if context.importanceScore > 0.8 {
            suggestions.append(PrioritySuggestion(
                priority: .high,
                reason: "Task has high importance based on priority indicators",
                confidence: 0.8
            ))
        }
        
        return suggestions
    }
    
    public func calculateAdjustment(
        for task: Task,
        context: TaskAnalysisContext,
        globalContext: ContextInformation
    ) -> PriorityAdjustment? {
        let currentScore = task.priority.normalizedValue
        let optimalScore = calculateOptimalPriorityScore(
            task: task,
            context: context,
            globalContext: globalContext
        )
        
        let difference = abs(optimalScore - currentScore)
        
        if difference > 0.2 { // Significant difference
            let newPriority = TaskPriority.fromScore(optimalScore)
            return PriorityAdjustment(
                taskId: task.id,
                newPriority: newPriority,
                reason: "Priority adjusted based on current context and urgency"
            )
        }
        
        return nil
    }
    
    public func getOptimizationReason(for task: Task, newPriority: TaskPriority) -> String {
        return "Priority optimized based on task analysis and current context"
    }
    
    public func recordLearningData(_ data: PriorityLearningData) {
        learningData.append(data)
    }
    
    public func generateInsights(from analytics: PriorityAnalytics) -> PriorityInsights {
        return PriorityInsights(
            totalAdjustments: analytics.totalAdjustments,
            accurateRecommendations: analytics.accurateRecommendations,
            mostCommonAdjustment: analytics.mostCommonAdjustment,
            learningProgress: calculateLearningProgress()
        )
    }
    
    private func calculateOptimalPriorityScore(
        task: Task,
        context: TaskAnalysisContext,
        globalContext: ContextInformation
    ) -> Double {
        var score = context.urgencyScore * 0.4 + context.importanceScore * 0.3
        
        // Add context-based adjustments
        if globalContext.workingHours && task.category == .work {
            score += 0.1
        }
        
        // Add effort-based adjustments
        if context.effortEstimate < 30 { // Quick tasks
            score += 0.05
        }
        
        return min(1.0, max(0.0, score))
    }
    
    private func calculateConfidence(
        task: Task,
        context: TaskAnalysisContext,
        recommendedPriority: TaskPriority
    ) -> Double {
        // Calculate confidence based on data quality and historical patterns
        return 0.75 // Default confidence
    }
    
    private func generateReasoning(
        task: Task,
        context: TaskAnalysisContext,
        recommendedPriority: TaskPriority
    ) -> String {
        var reasons: [String] = []
        
        if context.urgencyScore > 0.7 {
            reasons.append("high urgency due to deadline")
        }
        
        if context.importanceScore > 0.7 {
            reasons.append("high importance")
        }
        
        if reasons.isEmpty {
            return "Priority recommendation based on task analysis"
        }
        
        return "Recommended due to: " + reasons.joined(separator: ", ")
    }
    
    private func calculateLearningProgress() -> Double {
        guard !learningData.isEmpty else { return 0.0 }
        
        // Simple learning progress calculation
        return min(1.0, Double(learningData.count) / 100.0)
    }
}

// MARK: - Models and Types

public struct PriorityOptimizationResult {
    public let tasksOptimized: Int
    public let changes: [PriorityChange]
    public let optimizationTime: Date
}

public struct TaskPriorityUpdate {
    public let task: Task
    public let oldPriority: TaskPriority
    public let newPriority: TaskPriority
    public let optimizationReason: String
}

public struct PriorityChange {
    public let taskId: UUID
    public let oldPriority: TaskPriority
    public let newPriority: TaskPriority
    public let reason: String
}

public struct PriorityAdjustment {
    public let taskId: UUID
    public let newPriority: TaskPriority
    public let reason: String
}

public struct PrioritySuggestion {
    public let priority: TaskPriority
    public let reason: String
    public let confidence: Double
}

public struct TaskPriorityRecommendation {
    public let taskId: UUID
    public let currentPriority: TaskPriority
    public let recommendedPriority: TaskPriority
    public let confidence: Double
    public let reasoning: String
}

public struct PriorityLearningData {
    public let taskId: UUID
    public let oldPriority: TaskPriority
    public let newPriority: TaskPriority
    public let adjustmentTime: Date
    public let userReason: String?
    public let context: ContextInformation
}

public struct PriorityInsights {
    public let totalAdjustments: Int
    public let accurateRecommendations: Int
    public let mostCommonAdjustment: String
    public let learningProgress: Double
    
    init(
        totalAdjustments: Int = 0,
        accurateRecommendations: Int = 0,
        mostCommonAdjustment: String = "None",
        learningProgress: Double = 0.0
    ) {
        self.totalAdjustments = totalAdjustments
        self.accurateRecommendations = accurateRecommendations
        self.mostCommonAdjustment = mostCommonAdjustment
        self.learningProgress = learningProgress
    }
}

public struct ContextInformation {
    public let currentTime: Date
    public let dayOfWeek: Int
    public let timeOfDay: TimeOfDay
    public let location: String?
    public let workingHours: Bool
    public let userActivity: UserActivity
}

public struct TaskAnalysisContext {
    public let urgencyScore: Double
    public let importanceScore: Double
    public let effortEstimate: TimeInterval
    public let dependencies: [UUID]
    public let contextRelevance: Double
}

public struct TaskHistoricalData {
    public let completionPatterns: [String]
    public let averageCompletionTime: TimeInterval
    public let priorityAdjustments: [PriorityChange]
}

public struct PriorityAnalytics {
    public let totalAdjustments: Int
    public let accurateRecommendations: Int
    public let mostCommonAdjustment: String
}

public enum TimeOfDay {
    case morning, afternoon, evening, night
}

public enum UserActivity {
    case work, commute, leisure, sleep, unknown
}

// MARK: - Extensions

extension TaskPriority {
    var normalizedValue: Double {
        switch self {
        case .none: return 0.1
        case .low: return 0.3
        case .high: return 0.7
        case .max: return 1.0
        }
    }
    
    static func fromScore(_ score: Double) -> TaskPriority {
        switch score {
        case 0.8...1.0: return .max
        case 0.5..<0.8: return .high
        case 0.2..<0.5: return .low
        default: return .none
        }
    }
}

// MARK: - Error Types

public enum PriorityOptimizationError: LocalizedError {
    case repositoryError(Error)
    case analyticsError(Error)
    case optimizationFailed
    case invalidInput
    case taskNotFound
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .analyticsError(let error):
            return "Analytics error: \(error.localizedDescription)"
        case .optimizationFailed:
            return "Priority optimization failed"
        case .invalidInput:
            return "Invalid input provided"
        case .taskNotFound:
            return "Task not found"
        }
    }
}
