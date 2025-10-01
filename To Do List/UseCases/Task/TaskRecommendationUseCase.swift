//
//  TaskRecommendationUseCase.swift
//  Tasker
//
//  Use case for intelligent task recommendations and smart suggestions
//

import Foundation

/// Use case for providing intelligent task recommendations
/// Uses ML-like algorithms to suggest optimal tasks based on context and history
public final class TaskRecommendationUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let cacheService: CacheServiceProtocol?
    private let userPreferencesService: UserPreferencesServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        cacheService: CacheServiceProtocol? = nil,
        userPreferencesService: UserPreferencesServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.cacheService = cacheService
        self.userPreferencesService = userPreferencesService
    }
    
    // MARK: - Recommendation Methods
    
    /// Get personalized task recommendations for the current context
    public func getPersonalizedRecommendations(
        context: RecommendationContext,
        maxRecommendations: Int = 5,
        completion: @escaping (Result<TaskRecommendations, RecommendationError>) -> Void
    ) {
        // Check cache first
        let cacheKey = "recommendations_\(context.cacheKey)"
        // Note: Cache disabled due to Task not conforming to Codable
        // if let cached = cacheService?.get(TaskRecommendations.self, forKey: cacheKey) {
        //     completion(.success(cached))
        //     return
        // }
        
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let recommendations = self?.generatePersonalizedRecommendations(
                    allTasks: allTasks,
                    context: context,
                    maxCount: maxRecommendations
                ) ?? TaskRecommendations()
                
                // Note: Cache disabled due to Task not conforming to Codable
                // self?.cacheService?.set(recommendations, forKey: cacheKey, expiration: .minutes(15))
                completion(.success(recommendations))
                
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Get next best task recommendation based on current energy and context
    public func getNextBestTask(
        currentEnergy: TaskEnergy,
        currentContext: TaskContext,
        completion: @escaping (Result<TaskRecommendation?, RecommendationError>) -> Void
    ) {
        taskRepository.fetchTodayTasks { [weak self] result in
            switch result {
            case .success(let todayTasks):
                let incompleteTasks = todayTasks.filter { !$0.isComplete }
                let recommendation = self?.selectOptimalTask(
                    from: incompleteTasks,
                    energy: currentEnergy,
                    context: currentContext
                )
                completion(.success(recommendation))
                
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Suggest tasks to break down complex tasks
    public func suggestTaskBreakdown(
        for complexTask: Task,
        completion: @escaping (Result<[TaskSuggestion], RecommendationError>) -> Void
    ) {
        let suggestions = generateBreakdownSuggestions(for: complexTask)
        completion(.success(suggestions))
    }
    
    /// Recommend similar tasks based on completion patterns
    public func recommendSimilarTasks(
        basedOn completedTask: Task,
        completion: @escaping (Result<[TaskSuggestion], RecommendationError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let suggestions = self?.findSimilarTaskPatterns(
                    basedOn: completedTask,
                    from: allTasks
                ) ?? []
                completion(.success(suggestions))
                
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Get time-based recommendations (morning routine, evening wrap-up)
    public func getTimeBasedRecommendations(
        for timeSlot: TimeSlot,
        completion: @escaping (Result<[TaskRecommendation], RecommendationError>) -> Void
    ) {
        taskRepository.fetchTodayTasks { [weak self] result in
            switch result {
            case .success(let todayTasks):
                let recommendations = self?.generateTimeBasedRecommendations(
                    tasks: todayTasks,
                    timeSlot: timeSlot
                ) ?? []
                completion(.success(recommendations))
                
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Recommend tasks for habit building
    public func recommendHabitTasks(
        category: TaskCategory,
        frequency: TaskHabitFrequency,
        completion: @escaping (Result<[HabitTaskSuggestion], RecommendationError>) -> Void
    ) {
        let habitSuggestions = generateHabitRecommendations(
            category: category,
            frequency: frequency
        )
        completion(.success(habitSuggestions))
    }
    
    /// Get quick win recommendations (easy, high-impact tasks)
    public func getQuickWinRecommendations(
        maxDuration: TimeInterval = 900, // 15 minutes
        completion: @escaping (Result<[TaskRecommendation], RecommendationError>) -> Void
    ) {
        taskRepository.fetchTodayTasks { [weak self] result in
            switch result {
            case .success(let todayTasks):
                let quickWins = self?.identifyQuickWins(
                    from: todayTasks,
                    maxDuration: maxDuration
                ) ?? []
                completion(.success(quickWins))
                
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generatePersonalizedRecommendations(
        allTasks: [Task],
        context: RecommendationContext,
        maxCount: Int
    ) -> TaskRecommendations {
        let incompleteTasks = allTasks.filter { !$0.isComplete }
        let completedTasks = allTasks.filter { $0.isComplete }
        
        // Score tasks based on multiple factors
        var scoredTasks: [(task: Task, score: Double)] = []
        
        for task in incompleteTasks {
            let score = calculateRecommendationScore(
                task: task,
                context: context,
                completedTasks: completedTasks
            )
            scoredTasks.append((task: task, score: score))
        }
        
        // Sort by score and take top recommendations
        let topTasks = scoredTasks
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { TaskRecommendation(task: $0.task, score: $0.score, reason: generateReason(for: $0.task, score: $0.score)) }
        
        return TaskRecommendations(
            context: context,
            recommendations: Array(topTasks),
            timestamp: Date()
        )
    }
    
    private func calculateRecommendationScore(
        task: Task,
        context: RecommendationContext,
        completedTasks: [Task]
    ) -> Double {
        var score: Double = 0
        
        // Priority scoring (0-40 points)
        score += Double(task.priority.scorePoints) * 5
        
        // Due date urgency (0-30 points)
        if let dueDate = task.dueDate {
            let hoursUntilDue = dueDate.timeIntervalSince(Date()) / 3600
            if hoursUntilDue < 0 {
                score += 30 // Overdue gets max urgency
            } else if hoursUntilDue < 24 {
                score += 25 // Due today
            } else if hoursUntilDue < 48 {
                score += 20 // Due tomorrow
            } else if hoursUntilDue < 168 {
                score += 15 // Due this week
            }
        }
        
        // Energy level match (0-20 points)
        if task.energy == context.currentEnergy {
            score += 20
        } else if abs(task.energy.rawValue.hashValue - context.currentEnergy.rawValue.hashValue) == 1 {
            score += 10 // Adjacent energy levels
        }
        
        // Context match (0-20 points)
        if task.context == context.currentContext || task.context == .anywhere {
            score += 20
        }
        
        // Time availability (0-15 points)
        if let estimatedDuration = task.estimatedDuration,
           estimatedDuration <= context.availableTime {
            score += 15
        } else if task.estimatedDuration == nil && context.availableTime >= 900 { // 15 min default
            score += 10
        }
        
        // Completion pattern bonus (0-10 points)
        let similarCompletedTasks = completedTasks.filter { completed in
            completed.category == task.category ||
            completed.project == task.project ||
            completed.tags.contains { task.tags.contains($0) }
        }
        
        if !similarCompletedTasks.isEmpty {
            score += min(Double(similarCompletedTasks.count), 10)
        }
        
        // Randomization factor to prevent stagnation (±5 points)
        score += Double.random(in: -5...5)
        
        return max(score, 0)
    }
    
    private func selectOptimalTask(
        from tasks: [Task],
        energy: TaskEnergy,
        context: TaskContext
    ) -> TaskRecommendation? {
        let contextBuilder = RecommendationContext(
            currentEnergy: energy,
            currentContext: context,
            availableTime: 3600, // 1 hour default
            timeOfDay: getCurrentTimeSlot()
        )
        
        let recommendations = generatePersonalizedRecommendations(
            allTasks: tasks,
            context: contextBuilder,
            maxCount: 1
        )
        
        return recommendations.recommendations.first
    }
    
    private func generateBreakdownSuggestions(for complexTask: Task) -> [TaskSuggestion] {
        var suggestions: [TaskSuggestion] = []
        
        // Analyze task complexity
        let hasLongDuration = (complexTask.estimatedDuration ?? 0) > 3600 // > 1 hour
        let hasMultipleWords = complexTask.name.components(separatedBy: .whitespaces).count > 3
        let hasComplexDetails = (complexTask.details?.count ?? 0) > 100
        
        if hasLongDuration || hasMultipleWords || hasComplexDetails {
            // Suggest research phase
            suggestions.append(TaskSuggestion(
                title: "Research: \(complexTask.name)",
                description: "Gather information and plan approach for \(complexTask.name)",
                estimatedDuration: 900, // 15 minutes
                suggestedPriority: complexTask.priority,
                category: complexTask.category,
                reason: "Complex tasks benefit from initial research and planning"
            ))
            
            // Suggest planning phase
            suggestions.append(TaskSuggestion(
                title: "Plan: \(complexTask.name)",
                description: "Create detailed plan and timeline for \(complexTask.name)",
                estimatedDuration: 1200, // 20 minutes
                suggestedPriority: complexTask.priority,
                category: complexTask.category,
                reason: "Breaking down complex tasks improves success rate"
            ))
            
            // Suggest execution phases
            suggestions.append(TaskSuggestion(
                title: "Start: \(complexTask.name)",
                description: "Begin the first phase of \(complexTask.name)",
                estimatedDuration: 1800, // 30 minutes
                suggestedPriority: complexTask.priority,
                category: complexTask.category,
                reason: "Starting with focused time blocks maintains momentum"
            ))
        }
        
        return suggestions
    }
    
    private func findSimilarTaskPatterns(basedOn completedTask: Task, from allTasks: [Task]) -> [TaskSuggestion] {
        var suggestions: [TaskSuggestion] = []
        
        // Find tasks in same category
        let similarByCategory = allTasks.filter { 
            $0.category == completedTask.category && 
            $0.id != completedTask.id &&
            !$0.isComplete
        }
        
        // Find tasks in same project
        let similarByProject = allTasks.filter {
            $0.project == completedTask.project &&
            $0.id != completedTask.id &&
            !$0.isComplete
        }
        
        // Suggest follow-up tasks
        if !similarByCategory.isEmpty {
            let suggestion = TaskSuggestion(
                title: "Continue with \(completedTask.category.displayName) tasks",
                description: "You have \(similarByCategory.count) more tasks in this category",
                estimatedDuration: similarByCategory.first?.estimatedDuration,
                suggestedPriority: completedTask.priority,
                category: completedTask.category,
                reason: "Maintaining focus in one category improves productivity"
            )
            suggestions.append(suggestion)
        }
        
        return suggestions
    }
    
    private func generateTimeBasedRecommendations(
        tasks: [Task],
        timeSlot: TimeSlot
    ) -> [TaskRecommendation] {
        let incompleteTasks = tasks.filter { !$0.isComplete }
        
        switch timeSlot {
        case .earlyMorning:
            // High energy, creative tasks
            return incompleteTasks
                .filter { $0.energy == .high && $0.category == .creative }
                .map { TaskRecommendation(task: $0, score: 90, reason: "High energy creative work is best in the morning") }
            
        case .morning:
            // Important, high-priority tasks
            return incompleteTasks
                .filter { $0.priority == .high || $0.priority == .max }
                .map { TaskRecommendation(task: $0, score: 85, reason: "Tackle important tasks when you're fresh") }
            
        case .afternoon:
            // Medium energy, collaborative tasks
            return incompleteTasks
                .filter { $0.energy == .medium && $0.context == .meeting }
                .map { TaskRecommendation(task: $0, score: 75, reason: "Afternoon is ideal for meetings and collaboration") }
            
        case .evening:
            // Low energy, routine tasks
            return incompleteTasks
                .filter { $0.energy == .low || $0.category == .maintenance }
                .map { TaskRecommendation(task: $0, score: 70, reason: "Wind down with lighter tasks in the evening") }
            
        case .night:
            // Quick, easy tasks
            return incompleteTasks
                .filter { ($0.estimatedDuration ?? 0) < 900 && $0.energy == .low }
                .map { TaskRecommendation(task: $0, score: 60, reason: "Quick tasks are perfect for late hours") }
        }
    }
    
    private func generateHabitRecommendations(
        category: TaskCategory,
        frequency: TaskHabitFrequency
    ) -> [HabitTaskSuggestion] {
        let habitTemplates = getHabitTemplates(for: category)
        
        return habitTemplates.map { template in
            HabitTaskSuggestion(
                title: template.title,
                description: template.description,
                category: category,
                frequency: frequency,
                estimatedDuration: template.estimatedDuration,
                benefits: template.benefits,
                difficulty: template.difficulty
            )
        }
    }
    
    private func identifyQuickWins(from tasks: [Task], maxDuration: TimeInterval) -> [TaskRecommendation] {
        return tasks
            .filter { !$0.isComplete }
            .filter { ($0.estimatedDuration ?? 900) <= maxDuration }
            .filter { $0.priority != .none } // Must have some priority
            .sorted { $0.priority.scorePoints > $1.priority.scorePoints }
            .prefix(3)
            .map { TaskRecommendation(task: $0, score: 80, reason: "Quick win: High impact, low effort") }
            .compactMap { $0 }
    }
    
    private func generateReason(for task: Task, score: Double) -> String {
        if score > 80 {
            return "Highly recommended based on priority, deadline, and context"
        } else if score > 60 {
            return "Good match for your current energy and context"
        } else if score > 40 {
            return "Consider this task when other priorities are complete"
        } else {
            return "Lower priority task for later consideration"
        }
    }
    
    private func getCurrentTimeSlot() -> TimeSlot {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5...7: return .earlyMorning
        case 8...11: return .morning
        case 12...17: return .afternoon
        case 18...21: return .evening
        default: return .night
        }
    }
    
    private func getHabitTemplates(for category: TaskCategory) -> [TaskHabitTemplate] {
        switch category {
        case .health:
            return [
                TaskHabitTemplate(title: "Morning Walk", description: "10-minute walk around the block", estimatedDuration: 600, benefits: "Improved cardiovascular health", difficulty: .easy),
                TaskHabitTemplate(title: "Drink Water", description: "Drink a glass of water", estimatedDuration: 60, benefits: "Better hydration", difficulty: .easy),
                TaskHabitTemplate(title: "Meditation", description: "5-minute mindfulness meditation", estimatedDuration: 300, benefits: "Reduced stress and anxiety", difficulty: .medium)
            ]
        case .learning:
            return [
                TaskHabitTemplate(title: "Read for 15 minutes", description: "Read educational content", estimatedDuration: 900, benefits: "Continuous learning and growth", difficulty: .easy),
                TaskHabitTemplate(title: "Practice new skill", description: "Spend time practicing a new skill", estimatedDuration: 1800, benefits: "Skill development", difficulty: .medium)
            ]
        default:
            return []
        }
    }
}

// MARK: - Supporting Models

public struct RecommendationContext {
    public let currentEnergy: TaskEnergy
    public let currentContext: TaskContext
    public let availableTime: TimeInterval
    public let timeOfDay: TimeSlot
    
    var cacheKey: String {
        return "\(currentEnergy.rawValue)_\(currentContext.rawValue)_\(Int(availableTime))_\(timeOfDay.rawValue)"
    }
}

public enum TimeSlot: String, CaseIterable {
    case earlyMorning = "early_morning"
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
}

public enum TaskHabitFrequency: String, CaseIterable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekly = "weekly"
    case monthly = "monthly"
}

public enum TaskHabitDifficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
}

public struct TaskRecommendations {
    public let context: RecommendationContext
    public let recommendations: [TaskRecommendation]
    public let timestamp: Date
    
    init(context: RecommendationContext = RecommendationContext(currentEnergy: .medium, currentContext: .anywhere, availableTime: 3600, timeOfDay: .morning), recommendations: [TaskRecommendation] = [], timestamp: Date = Date()) {
        self.context = context
        self.recommendations = recommendations
        self.timestamp = timestamp
    }
}

public struct TaskRecommendation {
    public let task: Task
    public let score: Double
    public let reason: String
    
    public var confidenceLevel: String {
        switch score {
        case 80...100: return "High"
        case 60...79: return "Medium"
        case 40...59: return "Low"
        default: return "Very Low"
        }
    }
}

public struct TaskSuggestion {
    public let title: String
    public let description: String
    public let estimatedDuration: TimeInterval?
    public let suggestedPriority: TaskPriority
    public let category: TaskCategory
    public let reason: String
}

public struct HabitTaskSuggestion {
    public let title: String
    public let description: String
    public let category: TaskCategory
    public let frequency: TaskHabitFrequency
    public let estimatedDuration: TimeInterval
    public let benefits: String
    public let difficulty: TaskHabitDifficulty
}

public struct TaskHabitTemplate {
    public let title: String
    public let description: String
    public let estimatedDuration: TimeInterval
    public let benefits: String
    public let difficulty: TaskHabitDifficulty
}

// MARK: - Protocol Definition

public protocol UserPreferencesServiceProtocol {
    func getPreferredWorkingHours() -> (start: Int, end: Int)
    func getPreferredEnergyLevels() -> [TaskEnergy]
    func getPreferredContexts() -> [TaskContext]
}

// MARK: - Extensions for Codable Support

// Remove Codable conformance extensions since Task and other types may not be Codable

// MARK: - Error Types

public enum RecommendationError: LocalizedError {
    case dataError(Error)
    case noRecommendationsAvailable
    case invalidContext
    case userPreferencesUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .dataError(let error):
            return "Data error: \(error.localizedDescription)"
        case .noRecommendationsAvailable:
            return "No recommendations available for current context"
        case .invalidContext:
            return "Invalid recommendation context provided"
        case .userPreferencesUnavailable:
            return "User preferences service unavailable"
        }
    }
}