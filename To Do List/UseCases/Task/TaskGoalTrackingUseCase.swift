//
//  TaskGoalTrackingUseCase.swift
//  Tasker
//
//  Use case for goal achievement system and tracking progress toward objectives
//

import Foundation

/// Use case for setting and tracking goals through task completion
public final class TaskGoalTrackingUseCase {
    
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
    
    // MARK: - Goal Management Methods
    
    /// Create a new goal
    public func createGoal(
        definition: GoalDefinition,
        completion: @escaping (Result<Goal, GoalTrackingError>) -> Void
    ) {
        let goal = Goal(
            id: UUID(),
            definition: definition,
            status: .active,
            progress: 0.0,
            createdDate: Date(),
            targetDate: definition.targetDate,
            completedDate: nil,
            milestones: generateMilestones(for: definition)
        )
        
        eventPublisher?.publish(GoalCreated(goal: goal))
        completion(.success(goal))
    }
    
    /// Update goal progress based on task completions
    public func updateGoalProgress(
        goalId: UUID,
        completedTask: Task,
        completion: @escaping (Result<GoalProgressUpdate, GoalTrackingError>) -> Void
    ) {
        // Calculate progress based on completed task
        let progressUpdate = calculateProgressUpdate(goalId: goalId, completedTask: completedTask)
        
        // Check for milestone achievements
        let milestonesReached = checkMilestoneAchievements(goalId: goalId, newProgress: progressUpdate.newProgress)
        
        let result = GoalProgressUpdate(
            goalId: goalId,
            previousProgress: progressUpdate.previousProgress,
            newProgress: progressUpdate.newProgress,
            progressDelta: progressUpdate.progressDelta,
            milestonesReached: milestonesReached,
            isGoalCompleted: progressUpdate.newProgress >= 1.0
        )
        
        if result.isGoalCompleted {
            eventPublisher?.publish(GoalCompleted(goalId: goalId))
        }
        
        for milestone in milestonesReached {
            eventPublisher?.publish(GoalMilestoneReached(goalId: goalId, milestone: milestone))
        }
        
        completion(.success(result))
    }
    
    /// Get all active goals with their progress
    public func getActiveGoals(
        completion: @escaping (Result<[GoalWithProgress], GoalTrackingError>) -> Void
    ) {
        // Simulate fetching goals
        let goals = generateSampleGoals()
        completion(.success(goals))
    }
    
    /// Get goal details with task breakdown
    public func getGoalDetails(
        goalId: UUID,
        completion: @escaping (Result<GoalDetails, GoalTrackingError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let goalTasks = allTasks.filter { self?.isTaskContributingToGoal($0, goalId: goalId) ?? false }
                let details = GoalDetails(
                    goalId: goalId,
                    contributingTasks: goalTasks,
                    completedTasks: goalTasks.filter { $0.isComplete },
                    remainingTasks: goalTasks.filter { !$0.isComplete },
                    estimatedTimeToCompletion: self?.calculateEstimatedTimeToCompletion(tasks: goalTasks) ?? 0
                )
                completion(.success(details))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Suggest tasks to help achieve a goal
    public func suggestTasksForGoal(
        goalId: UUID,
        completion: @escaping (Result<[TaskSuggestionForGoal], GoalTrackingError>) -> Void
    ) {
        let suggestions = generateTaskSuggestions(for: goalId)
        completion(.success(suggestions))
    }
    
    /// Get goal analytics and insights
    public func getGoalAnalytics(
        timeframe: GoalAnalyticsTimeframe = .thisMonth,
        completion: @escaping (Result<GoalAnalytics, GoalTrackingError>) -> Void
    ) {
        let analytics = GoalAnalytics(
            timeframe: timeframe,
            totalGoals: 8,
            completedGoals: 3,
            activeGoals: 4,
            overdue: 1,
            averageCompletionTime: 21, // days
            mostSuccessfulCategory: .health,
            goalCompletionRate: 0.75
        )
        
        completion(.success(analytics))
    }

    // MARK: - Private Helper Methods

    private func generateMilestones(for definition: GoalDefinition) -> [GoalMilestone] {
        switch definition.type {
        case .taskCount(let targetCount):
            let quarterMark = max(targetCount / 4, 1)
            let halfMark = max(targetCount / 2, 1)
            let threeQuarterMark = max((targetCount * 3) / 4, 1)
            
            return [
                GoalMilestone(id: UUID(), title: "Getting Started", description: "Complete \(quarterMark) tasks", targetValue: Double(quarterMark), isReached: false, reachedDate: nil),
                GoalMilestone(id: UUID(), title: "Halfway There", description: "Complete \(halfMark) tasks", targetValue: Double(halfMark), isReached: false, reachedDate: nil),
                GoalMilestone(id: UUID(), title: "Almost Done", description: "Complete \(threeQuarterMark) tasks", targetValue: Double(threeQuarterMark), isReached: false, reachedDate: nil)
            ]
            
        case .habitStreak(let days):
            let weekMark = min(days, 7)
            let twoWeekMark = min(days, 14)
            
            return [
                GoalMilestone(id: UUID(), title: "Week Strong", description: "Maintain streak for \(weekMark) days", targetValue: Double(weekMark), isReached: false, reachedDate: nil),
                GoalMilestone(id: UUID(), title: "Two Weeks", description: "Maintain streak for \(twoWeekMark) days", targetValue: Double(twoWeekMark), isReached: false, reachedDate: nil)
            ]
            
        case .categoryFocus(let category, let taskCount):
            return [
                GoalMilestone(id: UUID(), title: "\(category.displayName) Focus", description: "Complete \(taskCount/2) \(category.displayName) tasks", targetValue: Double(taskCount/2), isReached: false, reachedDate: nil)
            ]
            
        case .timeSpent(let hours):
            return [
                GoalMilestone(id: UUID(), title: "Time Investment", description: "Spend \(hours/2) hours", targetValue: Double(hours/2), isReached: false, reachedDate: nil)
            ]
            
        case .custom:
            return []
        }
    }
    
    private func calculateProgressUpdate(goalId: UUID, completedTask: Task) -> GoalProgressUpdate {
        // Simplified progress calculation
        let previousProgress = 0.4 // Simulated current progress
        let progressDelta = 0.1 // Each task contributes 10%
        let newProgress = min(previousProgress + progressDelta, 1.0)
        
        return GoalProgressUpdate(
            goalId: goalId,
            previousProgress: previousProgress,
            newProgress: newProgress,
            progressDelta: progressDelta,
            milestonesReached: [],
            isGoalCompleted: newProgress >= 1.0
        )
    }
    
    private func checkMilestoneAchievements(goalId: UUID, newProgress: Double) -> [GoalMilestone] {
        // Simulate milestone checking
        if newProgress >= 0.5 && newProgress < 0.6 {
            return [GoalMilestone(id: UUID(), title: "Halfway There", description: "50% completed", targetValue: 0.5, isReached: true, reachedDate: Date())]
        }
        return []
    }
    
    private func generateSampleGoals() -> [GoalWithProgress] {
        return [
            GoalWithProgress(
                goal: Goal(
                    id: UUID(),
                    definition: GoalDefinition(
                        title: "Health & Fitness Focus",
                        description: "Complete 20 health-related tasks this month",
                        type: .categoryFocus(.health, taskCount: 20),
                        targetDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                        priority: .high
                    ),
                    status: .active,
                    progress: 0.65,
                    createdDate: Date(),
                    targetDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                    completedDate: nil,
                    milestones: []
                ),
                currentProgress: 0.65,
                tasksCompleted: 13,
                tasksRemaining: 7,
                estimatedDaysToCompletion: 8
            )
        ]
    }
    
    private func isTaskContributingToGoal(_ task: Task, goalId: UUID) -> Bool {
        // Logic to determine if a task contributes to a specific goal
        return task.tags.contains("goal-\(goalId.uuidString.prefix(8))")
    }
    
    private func calculateEstimatedTimeToCompletion(tasks: [Task]) -> TimeInterval {
        let remainingTasks = tasks.filter { !$0.isComplete }
        return remainingTasks.compactMap { $0.estimatedDuration }.reduce(0, +)
    }
    
    private func generateTaskSuggestions(for goalId: UUID) -> [TaskSuggestionForGoal] {
        return [
            TaskSuggestionForGoal(
                title: "Morning Workout",
                description: "30-minute cardio session",
                category: .health,
                estimatedDuration: 1800,
                priority: .high,
                reasoning: "Regular exercise helps build the health habit you're working toward"
            ),
            TaskSuggestionForGoal(
                title: "Meal Prep",
                description: "Prepare healthy meals for the week",
                category: .health,
                estimatedDuration: 3600,
                priority: TaskPriority.high,
                reasoning: "Meal preparation supports your nutrition goals"
            )
        ]
    }
}

// MARK: - Supporting Models

public struct GoalDefinition {
    public let title: String
    public let description: String?
    public let type: GoalType
    public let targetDate: Date?
    public let priority: TaskPriority
    
    public init(title: String, description: String?, type: GoalType, targetDate: Date?, priority: TaskPriority) {
        self.title = title
        self.description = description
        self.type = type
        self.targetDate = targetDate
        self.priority = priority
    }
}

public enum GoalType {
    case taskCount(Int)
    case habitStreak(days: Int)
    case categoryFocus(TaskCategory, taskCount: Int)
    case timeSpent(hours: Int)
    case custom(String)
}

public enum GoalStatus {
    case active
    case completed
    case paused
    case cancelled
}

public struct Goal {
    public let id: UUID
    public let definition: GoalDefinition
    public let status: GoalStatus
    public let progress: Double
    public let createdDate: Date
    public let targetDate: Date?
    public let completedDate: Date?
    public let milestones: [GoalMilestone]
    
    public init(id: UUID, definition: GoalDefinition, status: GoalStatus, progress: Double, createdDate: Date, targetDate: Date?, completedDate: Date?, milestones: [GoalMilestone]) {
        self.id = id
        self.definition = definition
        self.status = status
        self.progress = progress
        self.createdDate = createdDate
        self.targetDate = targetDate
        self.completedDate = completedDate
        self.milestones = milestones
    }
}

public struct GoalMilestone {
    public let id: UUID
    public let title: String
    public let description: String
    public let targetValue: Double
    public let isReached: Bool
    public let reachedDate: Date?
    
    public init(id: UUID, title: String, description: String, targetValue: Double, isReached: Bool, reachedDate: Date?) {
        self.id = id
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.isReached = isReached
        self.reachedDate = reachedDate
    }
}

public struct GoalProgressUpdate {
    public let goalId: UUID
    public let previousProgress: Double
    public let newProgress: Double
    public let progressDelta: Double
    public let milestonesReached: [GoalMilestone]
    public let isGoalCompleted: Bool
    
    public init(goalId: UUID, previousProgress: Double, newProgress: Double, progressDelta: Double, milestonesReached: [GoalMilestone], isGoalCompleted: Bool) {
        self.goalId = goalId
        self.previousProgress = previousProgress
        self.newProgress = newProgress
        self.progressDelta = progressDelta
        self.milestonesReached = milestonesReached
        self.isGoalCompleted = isGoalCompleted
    }
}

public struct GoalWithProgress {
    public let goal: Goal
    public let currentProgress: Double
    public let tasksCompleted: Int
    public let tasksRemaining: Int
    public let estimatedDaysToCompletion: Int
    
    public init(goal: Goal, currentProgress: Double, tasksCompleted: Int, tasksRemaining: Int, estimatedDaysToCompletion: Int) {
        self.goal = goal
        self.currentProgress = currentProgress
        self.tasksCompleted = tasksCompleted
        self.tasksRemaining = tasksRemaining
        self.estimatedDaysToCompletion = estimatedDaysToCompletion
    }
}

public struct GoalDetails {
    public let goalId: UUID
    public let contributingTasks: [Task]
    public let completedTasks: [Task]
    public let remainingTasks: [Task]
    public let estimatedTimeToCompletion: TimeInterval
    
    public init(goalId: UUID, contributingTasks: [Task], completedTasks: [Task], remainingTasks: [Task], estimatedTimeToCompletion: TimeInterval) {
        self.goalId = goalId
        self.contributingTasks = contributingTasks
        self.completedTasks = completedTasks
        self.remainingTasks = remainingTasks
        self.estimatedTimeToCompletion = estimatedTimeToCompletion
    }
}

public struct TaskSuggestionForGoal {
    public let title: String
    public let description: String
    public let category: TaskCategory
    public let estimatedDuration: TimeInterval
    public let priority: TaskPriority
    public let reasoning: String
    
    public init(title: String, description: String, category: TaskCategory, estimatedDuration: TimeInterval, priority: TaskPriority, reasoning: String) {
        self.title = title
        self.description = description
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.priority = priority
        self.reasoning = reasoning
    }
}

public enum GoalAnalyticsTimeframe {
    case thisWeek
    case thisMonth
    case thisQuarter
    case thisYear
}

public struct GoalAnalytics {
    public let timeframe: GoalAnalyticsTimeframe
    public let totalGoals: Int
    public let completedGoals: Int
    public let activeGoals: Int
    public let overdue: Int
    public let averageCompletionTime: Int // days
    public let mostSuccessfulCategory: TaskCategory
    public let goalCompletionRate: Double
    
    public init(timeframe: GoalAnalyticsTimeframe, totalGoals: Int, completedGoals: Int, activeGoals: Int, overdue: Int, averageCompletionTime: Int, mostSuccessfulCategory: TaskCategory, goalCompletionRate: Double) {
        self.timeframe = timeframe
        self.totalGoals = totalGoals
        self.completedGoals = completedGoals
        self.activeGoals = activeGoals
        self.overdue = overdue
        self.averageCompletionTime = averageCompletionTime
        self.mostSuccessfulCategory = mostSuccessfulCategory
        self.goalCompletionRate = goalCompletionRate
    }
}

// MARK: - Events

public struct GoalCreated: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "GoalCreated"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let goal: Goal
    
    public init(goal: Goal) {
        self.goal = goal
        self.aggregateId = goal.id
        self.metadata = ["goalId": goal.id.uuidString]
    }
}

public struct GoalCompleted: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "GoalCompleted"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let goalId: UUID
    
    public init(goalId: UUID) {
        self.goalId = goalId
        self.aggregateId = goalId
        self.metadata = ["goalId": goalId.uuidString]
    }
}

public struct GoalMilestoneReached: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "GoalMilestoneReached"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let goalId: UUID
    public let milestone: GoalMilestone
    
    public init(goalId: UUID, milestone: GoalMilestone) {
        self.goalId = goalId
        self.milestone = milestone
        self.aggregateId = goalId
        self.metadata = [
            "goalId": goalId.uuidString,
            "milestoneId": milestone.id.uuidString
        ]
    }
}

// MARK: - Error Types

public enum GoalTrackingError: LocalizedError {
    case repositoryError(Error)
    case goalNotFound
    case invalidGoalDefinition
    case goalAlreadyCompleted
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .goalNotFound:
            return "Goal not found"
        case .invalidGoalDefinition:
            return "Invalid goal definition"
        case .goalAlreadyCompleted:
            return "Goal is already completed"
        }
    }
}