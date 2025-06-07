import Foundation
import CoreData

/// Service responsible for handling task scoring and gamification logic
final class TaskScoringService {
    
    // MARK: - Singleton Instance (for backward compatibility)
    
    /// Shared instance for global access
    /// Note: Using dependency injection is preferred over singleton when possible
    static let shared = TaskScoringService()
    
    // MARK: - Scoring Methods
    
    /// Calculate the score value of an individual task based on its priority
    /// - Parameter taskPriority: The priority level of the task (TaskPriority enum)
    /// - Returns: Integer score value
    func calculateScore(for taskPriority: TaskPriority) -> Int {
        switch taskPriority {
        case .high:   return 7  // Highest priority
        case .medium: return 4  // Medium priority
        case .low:    return 2  // Low priority
        @unknown default:
            return 1  // Fallback
        }
    }
    
    /// Calculate the score value of an individual task
    /// - Parameter taskData: The task data to calculate score for
    /// - Returns: Integer score value
    func calculateScore(for taskData: TaskData) -> Int {
        return calculateScore(for: taskData.priority)
    }
    
    /// Calculate the score value of an individual managed task
    /// - Parameter task: The managed task to calculate score for
    /// - Returns: Integer score value
    func calculateScore(for task: NTask) -> Int {
        let priority = TaskPriority(rawValue: task.taskPriority) ?? .low
        return calculateScore(for: priority)
    }
    
    /// Calculate the total score for a given date
    /// - Parameters:
    ///   - date: The date to calculate score for
    ///   - repository: The task repository to use for fetching tasks
    ///   - completion: Completion handler with the total score
    func calculateTotalScore(
        for date: Date,
        using repository: TaskRepository,
        completion: @escaping (Int) -> Void
    ) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Tasks completed on this date
        let completedOnDatePredicate = NSPredicate(
            format: "dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        repository.fetchTasks(predicate: completedOnDatePredicate, sortDescriptors: nil) { [weak self] tasks in
            guard let self = self else {
                completion(0)
                return
            }
            
            var totalScore = 0
            for task in tasks {
                // Handle TaskData type
                if let taskData = task as? TaskData {
                    totalScore += self.calculateScore(for: taskData.priority)
                }
            }
            
            completion(totalScore)
        }
    }
    
    /// Calculate the streak of consecutive days with completed tasks
    /// - Parameters:
    ///   - fromDate: The start date to calculate the streak from
    ///   - repository: The task repository to use for fetching tasks
    ///   - completion: Completion handler with the streak count
    func calculateStreak(
        from fromDate: Date,
        using repository: TaskRepository,
        completion: @escaping (Int) -> Void
    ) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        // Start with today and count backwards
        var currentDate = startOfToday
        var streak = 0
        var checkNextDay = true
        
        // We'll check one day at a time, up to 30 days back maximum
        let group = DispatchGroup()
        
        for dayOffset in 0..<30 {
            // If we've already found a day with no tasks, stop checking
            if !checkNextDay {
                break
            }
            
            // Calculate the date to check
            currentDate = calendar.date(byAdding: .day, value: -dayOffset, to: startOfToday)!
            
            group.enter()
            calculateTotalScore(for: currentDate, using: repository) { score in
                if score > 0 {
                    // Day has completed tasks
                    streak += 1
                    checkNextDay = true
                } else {
                    // Day has no completed tasks, stop the streak
                    checkNextDay = false
                }
                group.leave()
            }
            
            group.wait()
        }
        
        completion(streak)
    }
    
    /// Calculate the efficiency score (percentage of planned tasks that were completed)
    /// - Parameters:
    ///   - date: The date to calculate efficiency for
    ///   - repository: The task repository to use
    ///   - completion: Completion handler with efficiency percentage (0-100)
    func calculateEfficiency(
        for date: Date,
        using repository: TaskRepository,
        completion: @escaping (Double) -> Void
    ) {
        // Tasks due on this date
        repository.getTasksForInbox(date: date) { tasks in
            let totalTasks = tasks.count
            let completedTasks = tasks.filter { $0.isComplete }.count
            
            guard totalTasks > 0 else {
                completion(0.0)
                return
            }
            
            let efficiency = Double(completedTasks) / Double(totalTasks) * 100.0
            completion(efficiency)
        }
    }
}
