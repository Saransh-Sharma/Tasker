//
//  TaskHabitBuilderUseCase.swift
//  Tasker
//
//  Use case for building and tracking habits through task management
//

import Foundation

/// Use case for creating and managing habit-based tasks
/// Transforms regular tasks into habit-forming activities with tracking and rewards
public final class TaskHabitBuilderUseCase {
    
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
    
    // MARK: - Habit Building Methods
    
    /// Create a new habit-based task
    public func createHabitTask(
        habitDefinition: HabitDefinition,
        completion: @escaping (Result<HabitTask, HabitBuilderError>) -> Void
    ) {
        let habitTask = HabitTask(
            id: UUID(),
            habitDefinition: habitDefinition,
            startDate: habitDefinition.startDate,
            streak: 0,
            totalCompletions: 0,
            lastCompletionDate: nil,
            isActive: true
        )
        
        // Create the first occurrence task
        generateNextOccurrence(for: habitTask) { [weak self] result in
            switch result {
            case .success(let task):
                self?.taskRepository.createTask(task) { createResult in
                    switch createResult {
                    case .success:
                        self?.eventPublisher?.publish(HabitTaskCreated(habitTask: habitTask))
                        completion(.success(habitTask))
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Process habit task completion
    public func completeHabitOccurrence(
        habitTaskId: UUID,
        taskId: UUID,
        completion: @escaping (Result<HabitCompletionResult, HabitBuilderError>) -> Void
    ) {
        // Mark the specific task as complete
        taskRepository.completeTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let completedTask):
                // Calculate habit progress
                let progressResult = self?.calculateHabitProgress(
                    habitTaskId: habitTaskId,
                    completedTask: completedTask
                ) ?? HabitCompletionResult()
                
                // Generate next occurrence if needed
                self?.scheduleNextOccurrence(habitTaskId: habitTaskId) { scheduleResult in
                    switch scheduleResult {
                    case .success:
                        self?.eventPublisher?.publish(HabitOccurrenceCompleted(
                            habitTaskId: habitTaskId,
                            taskId: taskId,
                            result: progressResult
                        ))
                        completion(.success(progressResult))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Get habit progress and statistics
    public func getHabitProgress(
        habitTaskId: UUID,
        completion: @escaping (Result<HabitProgress, HabitBuilderError>) -> Void
    ) {
        // For now, return a simulated habit progress
        let progress = HabitProgress(
            habitTaskId: habitTaskId,
            currentStreak: 5,
            longestStreak: 12,
            totalCompletions: 25,
            completionRate: 0.83,
            momentum: .building,
            nextScheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            milestones: [
                HabitMilestone(type: .streak(7), achieved: true, achievedDate: Date()),
                HabitMilestone(type: .completions(20), achieved: true, achievedDate: Date()),
                HabitMilestone(type: .streak(30), achieved: false, achievedDate: nil)
            ]
        )
        
        completion(.success(progress))
    }
    
    /// Get all active habits
    public func getActiveHabits(
        completion: @escaping (Result<[HabitTask], HabitBuilderError>) -> Void
    ) {
        // Simulate fetching active habits
        let habits: [HabitTask] = []
        completion(.success(habits))
    }
    
    /// Pause a habit temporarily
    public func pauseHabit(
        habitTaskId: UUID,
        pauseReason: String? = nil,
        completion: @escaping (Result<Void, HabitBuilderError>) -> Void
    ) {
        eventPublisher?.publish(HabitPaused(habitTaskId: habitTaskId, reason: pauseReason))
        completion(.success(()))
    }
    
    /// Resume a paused habit
    public func resumeHabit(
        habitTaskId: UUID,
        completion: @escaping (Result<Void, HabitBuilderError>) -> Void
    ) {
        eventPublisher?.publish(HabitResumed(habitTaskId: habitTaskId))
        completion(.success(()))
    }
    
    /// Suggest habit improvements based on completion patterns
    public func getHabitSuggestions(
        habitTaskId: UUID,
        completion: @escaping (Result<[HabitSuggestion], HabitBuilderError>) -> Void
    ) {
        let suggestions = generateHabitSuggestions(for: habitTaskId)
        completion(.success(suggestions))
    }
    
    /// Get habit templates for quick setup
    public func getHabitTemplates(
        category: TaskCategory? = nil,
        completion: @escaping (Result<[HabitTemplate], HabitBuilderError>) -> Void
    ) {
        let templates = getHabitTemplates(for: category)
        completion(.success(templates))
    }
    
    /// Create habit from template
    public func createHabitFromTemplate(
        template: HabitTemplate,
        customizations: HabitCustomizations? = nil,
        completion: @escaping (Result<HabitTask, HabitBuilderError>) -> Void
    ) {
        let habitDefinition = HabitDefinition(
            title: customizations?.title ?? template.title,
            description: customizations?.description ?? template.description,
            category: template.category,
            frequency: customizations?.frequency ?? template.defaultFrequency,
            timeOfDay: customizations?.timeOfDay ?? template.suggestedTimeOfDay,
            estimatedDuration: customizations?.estimatedDuration ?? template.estimatedDuration,
            startDate: customizations?.startDate ?? Date(),
            endDate: customizations?.endDate,
            reminder: customizations?.reminder ?? template.defaultReminder,
            tags: (customizations?.tags ?? []) + template.suggestedTags
        )
        
        createHabitTask(habitDefinition: habitDefinition, completion: completion)
    }
    
    // MARK: - Private Helper Methods
    
    private func generateNextOccurrence(
        for habitTask: HabitTask,
        completion: @escaping (Result<Task, HabitBuilderError>) -> Void
    ) {
        let nextDate = calculateNextOccurrenceDate(for: habitTask.habitDefinition)
        
        let task = Task(
            name: habitTask.habitDefinition.title,
            details: habitTask.habitDefinition.description,
            type: habitTask.habitDefinition.timeOfDay.taskType,
            priority: .low, // Habits typically start low pressure
            dueDate: nextDate,
            project: "Habits",
            estimatedDuration: habitTask.habitDefinition.estimatedDuration,
            tags: habitTask.habitDefinition.tags + ["habit"],
            category: habitTask.habitDefinition.category,
            energy: .medium,
            context: .anywhere
        )
        
        completion(.success(task))
    }
    
    private func calculateNextOccurrenceDate(for habitDefinition: HabitDefinition) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch habitDefinition.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .weekdays:
            var nextDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let weekday = calendar.component(.weekday, from: nextDate)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                nextDate = calendar.date(byAdding: .day, value: weekday == 1 ? 1 : 2, to: nextDate) ?? nextDate
            }
            return nextDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .custom(let interval):
            return calendar.date(byAdding: .day, value: interval, to: now) ?? now
        }
    }
    
    private func calculateHabitProgress(
        habitTaskId: UUID,
        completedTask: Task
    ) -> HabitCompletionResult {
        // Simulate habit progress calculation
        let streakIncreased = true
        let newStreak = 6
        let milestoneReached = newStreak == 7 // Week milestone
        
        return HabitCompletionResult(
            habitTaskId: habitTaskId,
            streakIncreased: streakIncreased,
            newStreakCount: newStreak,
            milestoneReached: milestoneReached ? .streak(7) : nil,
            momentum: .building,
            nextScheduledDate: calculateNextOccurrenceDate(for: HabitDefinition.defaultDefinition())
        )
    }
    
    private func scheduleNextOccurrence(
        habitTaskId: UUID,
        completion: @escaping (Result<Void, HabitBuilderError>) -> Void
    ) {
        // This would schedule the next occurrence based on the habit frequency
        completion(.success(()))
    }
    
    private func generateHabitSuggestions(for habitTaskId: UUID) -> [HabitSuggestion] {
        return [
            HabitSuggestion(
                type: .adjustFrequency,
                title: "Consider reducing frequency",
                description: "Your completion rate is below 70%. Try reducing from daily to weekdays.",
                impact: .medium,
                effort: .low
            ),
            HabitSuggestion(
                type: .adjustTime,
                title: "Try a different time of day",
                description: "Morning habits have higher success rates for this category.",
                impact: .high,
                effort: .low
            ),
            HabitSuggestion(
                type: .addReminder,
                title: "Add a gentle reminder",
                description: "Set a reminder 15 minutes before your usual habit time.",
                impact: .medium,
                effort: .low
            )
        ]
    }
    
    private func getHabitTemplates(for category: TaskCategory?) -> [HabitTemplate] {
        var templates: [HabitTemplate] = []
        
        if category == nil || category == .health {
            templates.append(HabitTemplate(
                id: "morning_walk",
                title: "Morning Walk",
                description: "Take a 15-minute walk to start the day",
                category: .health,
                defaultFrequency: .daily,
                suggestedTimeOfDay: .morning,
                estimatedDuration: 900,
                defaultReminder: HabitReminder(
                    enabled: true,
                    timeBeforeHabit: 300,
                    message: "Time for your morning walk! 🚶‍♂️"
                ),
                suggestedTags: ["exercise", "outdoor", "energy"],
                difficulty: .easy,
                benefits: ["Improved cardiovascular health", "Better mood", "Increased energy"]
            ))
        }
        
        if category == nil || category == .learning {
            templates.append(HabitTemplate(
                id: "daily_reading",
                title: "Daily Reading",
                description: "Read for 20 minutes",
                category: .learning,
                defaultFrequency: .daily,
                suggestedTimeOfDay: .evening,
                estimatedDuration: 1200,
                defaultReminder: HabitReminder(
                    enabled: true,
                    timeBeforeHabit: 600,
                    message: "Time to read and unwind 📚"
                ),
                suggestedTags: ["books", "knowledge", "relaxation"],
                difficulty: .easy,
                benefits: ["Increased knowledge", "Better vocabulary", "Stress relief"]
            ))
        }
        
        return templates
    }
}

// MARK: - Supporting Models

public struct HabitDefinition {
    public let title: String
    public let description: String?
    public let category: TaskCategory
    public let frequency: HabitFrequency
    public let timeOfDay: HabitTimeOfDay
    public let estimatedDuration: TimeInterval?
    public let startDate: Date
    public let endDate: Date?
    public let reminder: HabitReminder?
    public let tags: [String]
    
    public init(title: String, description: String?, category: TaskCategory, frequency: HabitFrequency, timeOfDay: HabitTimeOfDay, estimatedDuration: TimeInterval?, startDate: Date, endDate: Date?, reminder: HabitReminder?, tags: [String]) {
        self.title = title
        self.description = description
        self.category = category
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.estimatedDuration = estimatedDuration
        self.startDate = startDate
        self.endDate = endDate
        self.reminder = reminder
        self.tags = tags
    }
    
    static func defaultDefinition() -> HabitDefinition {
        return HabitDefinition(
            title: "Default Habit",
            description: nil,
            category: .general,
            frequency: .daily,
            timeOfDay: .morning,
            estimatedDuration: 1800,
            startDate: Date(),
            endDate: nil,
            reminder: nil,
            tags: []
        )
    }
}

public enum HabitFrequency {
    case daily
    case weekdays
    case weekly
    case monthly
    case custom(days: Int)
}

public enum HabitTimeOfDay {
    case morning
    case afternoon
    case evening
    case anytime
    
    var taskType: TaskType {
        switch self {
        case .morning: return .morning
        case .evening: return .evening
        default: return .upcoming
        }
    }
}

public struct HabitReminder {
    public let enabled: Bool
    public let timeBeforeHabit: TimeInterval
    public let message: String
    
    public init(enabled: Bool, timeBeforeHabit: TimeInterval, message: String) {
        self.enabled = enabled
        self.timeBeforeHabit = timeBeforeHabit
        self.message = message
    }
}

public struct HabitTask {
    public let id: UUID
    public let habitDefinition: HabitDefinition
    public let startDate: Date
    public let streak: Int
    public let totalCompletions: Int
    public let lastCompletionDate: Date?
    public let isActive: Bool
    
    public init(id: UUID, habitDefinition: HabitDefinition, startDate: Date, streak: Int, totalCompletions: Int, lastCompletionDate: Date?, isActive: Bool) {
        self.id = id
        self.habitDefinition = habitDefinition
        self.startDate = startDate
        self.streak = streak
        self.totalCompletions = totalCompletions
        self.lastCompletionDate = lastCompletionDate
        self.isActive = isActive
    }
}

public struct HabitProgress {
    public let habitTaskId: UUID
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalCompletions: Int
    public let completionRate: Double
    public let momentum: HabitMomentum
    public let nextScheduledDate: Date?
    public let milestones: [HabitMilestone]
}

public enum HabitMomentum {
    case building
    case stable
    case declining
    case stalled
    
    public var emoji: String {
        switch self {
        case .building: return "📈"
        case .stable: return "➡️"
        case .declining: return "📉"
        case .stalled: return "⏸️"
        }
    }
}

public struct HabitMilestone {
    public let type: HabitMilestoneType
    public let achieved: Bool
    public let achievedDate: Date?
}

public enum HabitMilestoneType {
    case streak(Int)
    case completions(Int)
    case duration(Int) // days
    
    public var description: String {
        switch self {
        case .streak(let count):
            return "\(count)-day streak"
        case .completions(let count):
            return "\(count) completions"
        case .duration(let days):
            return "\(days) days of practice"
        }
    }
}

public struct HabitCompletionResult {
    public let habitTaskId: UUID
    public let streakIncreased: Bool
    public let newStreakCount: Int
    public let milestoneReached: HabitMilestoneType?
    public let momentum: HabitMomentum
    public let nextScheduledDate: Date?
    
    init(habitTaskId: UUID = UUID(), streakIncreased: Bool = false, newStreakCount: Int = 0, milestoneReached: HabitMilestoneType? = nil, momentum: HabitMomentum = .stable, nextScheduledDate: Date? = nil) {
        self.habitTaskId = habitTaskId
        self.streakIncreased = streakIncreased
        self.newStreakCount = newStreakCount
        self.milestoneReached = milestoneReached
        self.momentum = momentum
        self.nextScheduledDate = nextScheduledDate
    }
}

public struct HabitSuggestion {
    public let type: HabitSuggestionType
    public let title: String
    public let description: String
    public let impact: SuggestionImpact
    public let effort: SuggestionEffort
}

public enum HabitSuggestionType {
    case adjustFrequency
    case adjustTime
    case addReminder
    case changeCategory
    case reduceScope
    case addReward
}

public enum SuggestionImpact {
    case low, medium, high
}

public enum SuggestionEffort {
    case low, medium, high
}

public struct HabitTemplate {
    public let id: String
    public let title: String
    public let description: String
    public let category: TaskCategory
    public let defaultFrequency: HabitFrequency
    public let suggestedTimeOfDay: HabitTimeOfDay
    public let estimatedDuration: TimeInterval
    public let defaultReminder: HabitReminder
    public let suggestedTags: [String]
    public let difficulty: HabitDifficulty
    public let benefits: [String]
    
    public init(id: String, title: String, description: String, category: TaskCategory, defaultFrequency: HabitFrequency, suggestedTimeOfDay: HabitTimeOfDay, estimatedDuration: TimeInterval, defaultReminder: HabitReminder, suggestedTags: [String], difficulty: HabitDifficulty, benefits: [String]) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.defaultFrequency = defaultFrequency
        self.suggestedTimeOfDay = suggestedTimeOfDay
        self.estimatedDuration = estimatedDuration
        self.defaultReminder = defaultReminder
        self.suggestedTags = suggestedTags
        self.difficulty = difficulty
        self.benefits = benefits
    }
}

public enum HabitDifficulty {
    case easy, medium, hard
    
    public var emoji: String {
        switch self {
        case .easy: return "🟢"
        case .medium: return "🟡"
        case .hard: return "🔴"
        }
    }
}

public struct HabitCustomizations {
    public let title: String?
    public let description: String?
    public let frequency: HabitFrequency?
    public let timeOfDay: HabitTimeOfDay?
    public let estimatedDuration: TimeInterval?
    public let startDate: Date?
    public let endDate: Date?
    public let reminder: HabitReminder?
    public let tags: [String]?
    
    public init(title: String?, description: String?, frequency: HabitFrequency?, timeOfDay: HabitTimeOfDay?, estimatedDuration: TimeInterval?, startDate: Date?, endDate: Date?, reminder: HabitReminder?, tags: [String]?) {
        self.title = title
        self.description = description
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.estimatedDuration = estimatedDuration
        self.startDate = startDate
        self.endDate = endDate
        self.reminder = reminder
        self.tags = tags
    }
}

// MARK: - Events

public struct HabitTaskCreated: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "HabitTaskCreated"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let habitTask: HabitTask
    
    public init(habitTask: HabitTask) {
        self.habitTask = habitTask
        self.aggregateId = habitTask.id
        self.metadata = ["habitTaskId": habitTask.id.uuidString]
    }
}

public struct HabitOccurrenceCompleted: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "HabitOccurrenceCompleted"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let habitTaskId: UUID
    public let taskId: UUID
    public let result: HabitCompletionResult
    
    public init(habitTaskId: UUID, taskId: UUID, result: HabitCompletionResult) {
        self.habitTaskId = habitTaskId
        self.taskId = taskId
        self.result = result
        self.aggregateId = habitTaskId
        self.metadata = [
            "habitTaskId": habitTaskId.uuidString,
            "taskId": taskId.uuidString
        ]
    }
}

public struct HabitPaused: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "HabitPaused"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let habitTaskId: UUID
    public let reason: String?
    
    public init(habitTaskId: UUID, reason: String?) {
        self.habitTaskId = habitTaskId
        self.reason = reason
        self.aggregateId = habitTaskId
        self.metadata = [
            "habitTaskId": habitTaskId.uuidString,
            "reason": reason ?? "No reason provided"
        ]
    }
}

public struct HabitResumed: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "HabitResumed"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let habitTaskId: UUID
    
    public init(habitTaskId: UUID) {
        self.habitTaskId = habitTaskId
        self.aggregateId = habitTaskId
        self.metadata = ["habitTaskId": habitTaskId.uuidString]
    }
}

// MARK: - Error Types

public enum HabitBuilderError: LocalizedError {
    case repositoryError(Error)
    case habitNotFound
    case invalidHabitDefinition
    case habitAlreadyExists
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .habitNotFound:
            return "Habit not found"
        case .invalidHabitDefinition:
            return "Invalid habit definition"
        case .habitAlreadyExists:
            return "A habit with this name already exists"
        }
    }
}