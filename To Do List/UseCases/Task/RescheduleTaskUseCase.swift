//
//  RescheduleTaskUseCase.swift
//  Tasker
//
//  Use case for rescheduling tasks with smart date suggestions
//

import Foundation

/// Use case for rescheduling tasks
/// Handles intelligent rescheduling with business rules and suggestions
public final class RescheduleTaskUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
    }
    
    // MARK: - Execution
    
    /// Reschedules a task to a new date
    /// - Parameters:
    ///   - taskId: The ID of the task to reschedule
    ///   - newDate: The new due date
    ///   - completion: Completion handler with the updated task or error
    public func execute(
        taskId: UUID,
        newDate: Date,
        completion: @escaping (Result<Task, RescheduleTaskError>) -> Void
    ) {
        // Step 1: Fetch the current task
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                // Step 2: Validate the reschedule
                guard self?.validateReschedule(task: task, newDate: newDate) == true else {
                    completion(.failure(.invalidDate("Cannot reschedule to the past")))
                    return
                }
                
                // Step 3: Apply business rules and reschedule
                self?.performReschedule(task: task, newDate: newDate, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Suggests optimal reschedule dates based on task load
    /// - Parameters:
    ///   - taskId: The task to reschedule
    ///   - completion: Suggested dates with reasoning
    public func suggestRescheduleDates(
        for taskId: UUID,
        completion: @escaping (Result<[RescheduleSuggestion], RescheduleTaskError>) -> Void
    ) {
        taskRepository.fetchTask(withId: taskId) { [weak self] result in
            switch result {
            case .success(let task):
                guard let task = task else {
                    completion(.failure(.taskNotFound))
                    return
                }
                
                self?.generateSuggestions(for: task, completion: completion)
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Bulk reschedule overdue tasks
    public func rescheduleOverdueTasks(
        to date: Date,
        completion: @escaping (Result<[Task], RescheduleTaskError>) -> Void
    ) {
        taskRepository.fetchOverdueTasks { [weak self] result in
            switch result {
            case .success(let overdueTasks):
                var rescheduledTasks: [Task] = []
                let group = DispatchGroup()
                
                for task in overdueTasks {
                    group.enter()
                    self?.performReschedule(task: task, newDate: date) { result in
                        if case .success(let updatedTask) = result {
                            rescheduledTasks.append(updatedTask)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(rescheduledTasks))
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func validateReschedule(task: Task, newDate: Date) -> Bool {
        // Business rule: Cannot reschedule completed tasks
        if task.isComplete {
            return false
        }
        
        // Business rule: Cannot reschedule to more than 1 year in the future
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        if newDate > oneYearFromNow {
            return false
        }
        
        // Allow rescheduling to today or future
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfNewDate = Calendar.current.startOfDay(for: newDate)
        return startOfNewDate >= startOfToday
    }
    
    private func performReschedule(
        task: Task,
        newDate: Date,
        completion: @escaping (Result<Task, RescheduleTaskError>) -> Void
    ) {
        // Determine new task type based on new date
        let taskType = determineTaskType(for: newDate, currentType: task.type)
        
        // Update task
        var updatedTask = task
        updatedTask.dueDate = newDate
        updatedTask.type = taskType
        updatedTask.isEveningTask = (taskType == .evening)
        
        // Save to repository
        taskRepository.rescheduleTask(withId: task.id, to: newDate) { [weak self] result in
            switch result {
            case .success(let rescheduledTask):
                // Update notification if needed
                if let reminderTime = task.alertReminderTime {
                    self?.notificationService?.cancelTaskReminder(taskId: task.id)
                    
                    // Calculate new reminder time based on new due date
                    let newReminderTime = self?.calculateNewReminderTime(
                        oldReminder: reminderTime,
                        oldDueDate: task.dueDate ?? Date(),
                        newDueDate: newDate
                    )
                    
                    if let newReminder = newReminderTime {
                        self?.notificationService?.scheduleTaskReminder(
                            taskId: task.id,
                            taskName: task.name,
                            at: newReminder
                        )
                    }
                }
                
                // Post notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskRescheduled"),
                    object: rescheduledTask
                )
                
                completion(.success(rescheduledTask))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    private func determineTaskType(for date: Date, currentType: TaskType) -> TaskType {
        // If more than 7 days away, mark as upcoming
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if daysUntil > 7 {
            return .upcoming
        }
        
        // Otherwise, keep the current type or determine by time
        if currentType == .upcoming {
            // Determine by time of day
            let hour = Calendar.current.component(.hour, from: date)
            return hour < 12 ? .morning : .evening
        }
        
        return currentType
    }
    
    private func calculateNewReminderTime(
        oldReminder: Date,
        oldDueDate: Date,
        newDueDate: Date
    ) -> Date? {
        // Calculate the offset between old reminder and old due date
        let offset = oldReminder.timeIntervalSince(oldDueDate)
        
        // Apply the same offset to the new due date
        return Date(timeInterval: offset, since: newDueDate)
    }
    
    private func generateSuggestions(
        for task: Task,
        completion: @escaping (Result<[RescheduleSuggestion], RescheduleTaskError>) -> Void
    ) {
        var suggestions: [RescheduleSuggestion] = []
        
        // Suggestion 1: Tomorrow
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
            suggestions.append(RescheduleSuggestion(
                date: tomorrow,
                reason: "Move to tomorrow",
                taskLoad: .medium
            ))
        }
        
        // Suggestion 2: Next Monday
        if let nextMonday = getNextWeekday(TaskWeekday.monday) {
            suggestions.append(RescheduleSuggestion(
                date: nextMonday,
                reason: "Start of next week",
                taskLoad: .low
            ))
        }
        
        // Suggestion 3: Next available light day
        findNextLightDay { lightDay in
            if let lightDay = lightDay {
                suggestions.append(RescheduleSuggestion(
                    date: lightDay,
                    reason: "Next day with light task load",
                    taskLoad: .low
                ))
            }
            
            completion(.success(suggestions))
        }
    }
    
    private func getNextWeekday(_ weekday: TaskWeekday) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        let weekdayNumber = weekday.rawValue
        
        let components = DateComponents(weekday: weekdayNumber)
        return calendar.nextDate(after: today, matching: components, matchingPolicy: .nextTime)
    }
    
    private func findNextLightDay(completion: @escaping (Date?) -> Void) {
        // Check task load for the next 7 days
        let calendar = Calendar.current
        var lightDay: Date?
        let group = DispatchGroup()
        
        for dayOffset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else {
                continue
            }
            
            group.enter()
            taskRepository.fetchTasks(for: date) { result in
                if case .success(let tasks) = result {
                    // Consider a day "light" if it has fewer than 3 tasks
                    if tasks.count < 3 && lightDay == nil {
                        lightDay = date
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(lightDay)
        }
    }
}

// MARK: - Supporting Types

public struct RescheduleSuggestion {
    public let date: Date
    public let reason: String
    public let taskLoad: TaskLoad
    
    public enum TaskLoad {
        case low    // 0-2 tasks
        case medium // 3-5 tasks
        case high   // 6+ tasks
    }
}

public enum RescheduleTaskError: LocalizedError {
    case taskNotFound
    case invalidDate(String)
    case taskCompleted
    case repositoryError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Task not found"
        case .invalidDate(let reason):
            return "Invalid date: \(reason)"
        case .taskCompleted:
            return "Cannot reschedule completed tasks"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        }
    }
}

private enum TaskWeekday: Int {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}
