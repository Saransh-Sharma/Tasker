//
//  CalculateAnalyticsUseCase.swift
//  Tasker
//
//  Use case for calculating task analytics and productivity metrics
//

import Foundation

/// Use case for calculating analytics and productivity metrics
public final class CalculateAnalyticsUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let scoringService: TaskScoringService
    private let cacheService: CacheServiceProtocol?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        scoringService: TaskScoringService? = nil,
        cacheService: CacheServiceProtocol? = nil
    ) {
        self.taskRepository = taskRepository
        self.scoringService = scoringService ?? TaskScoringService()
        self.cacheService = cacheService
    }
    
    // MARK: - Daily Analytics
    
    /// Calculate analytics for today
    public func calculateTodayAnalytics(completion: @escaping (Result<DailyAnalytics, AnalyticsError>) -> Void) {
        calculateDailyAnalytics(for: Date(), completion: completion)
    }
    
    /// Calculate analytics for a specific date
    public func calculateDailyAnalytics(
        for date: Date,
        completion: @escaping (Result<DailyAnalytics, AnalyticsError>) -> Void
    ) {
        taskRepository.fetchTasks(for: date) { [weak self] result in
            switch result {
            case .success(let tasks):
                let analytics = self?.computeDailyAnalytics(tasks: tasks, date: date) ?? DailyAnalytics(date: date)
                completion(.success(analytics))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Weekly Analytics
    
    /// Calculate analytics for the current week
    public func calculateWeeklyAnalytics(completion: @escaping (Result<WeeklyAnalytics, AnalyticsError>) -> Void) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            completion(.failure(.invalidDateRange))
            return
        }
        
        calculateAnalytics(from: weekInterval.start, to: weekInterval.end) { result in
            switch result {
            case .success(let periodAnalytics):
                let weeklyAnalytics = WeeklyAnalytics(
                    weekStartDate: weekInterval.start,
                    weekEndDate: weekInterval.end,
                    dailyAnalytics: periodAnalytics.dailyBreakdown,
                    totalScore: periodAnalytics.totalScore,
                    totalTasksCompleted: periodAnalytics.totalTasksCompleted,
                    completionRate: periodAnalytics.completionRate,
                    averageTasksPerDay: periodAnalytics.averageTasksPerDay,
                    mostProductiveDay: periodAnalytics.mostProductiveDay,
                    leastProductiveDay: periodAnalytics.leastProductiveDay
                )
                completion(.success(weeklyAnalytics))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Monthly Analytics
    
    /// Calculate analytics for the current month
    public func calculateMonthlyAnalytics(completion: @escaping (Result<MonthlyAnalytics, AnalyticsError>) -> Void) {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else {
            completion(.failure(.invalidDateRange))
            return
        }
        
        calculateAnalytics(from: monthInterval.start, to: monthInterval.end) { result in
            switch result {
            case .success(let periodAnalytics):
                // Calculate weekly breakdown
                var weeklyBreakdown: [WeeklyAnalytics] = []
                var currentWeekStart = monthInterval.start
                
                while currentWeekStart < monthInterval.end {
                    if let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) {
                        let weekAnalytics = WeeklyAnalytics(
                            weekStartDate: currentWeekStart,
                            weekEndDate: min(weekEnd, monthInterval.end),
                            dailyAnalytics: periodAnalytics.dailyBreakdown.filter { analytics in
                                analytics.date >= currentWeekStart && analytics.date <= weekEnd
                            },
                            totalScore: 0, // Will be calculated
                            totalTasksCompleted: 0,
                            completionRate: 0,
                            averageTasksPerDay: 0,
                            mostProductiveDay: nil,
                            leastProductiveDay: nil
                        )
                        weeklyBreakdown.append(weekAnalytics)
                    }
                    
                    currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? monthInterval.end
                }
                
                let monthlyAnalytics = MonthlyAnalytics(
                    month: monthInterval.start,
                    weeklyBreakdown: weeklyBreakdown,
                    totalScore: periodAnalytics.totalScore,
                    totalTasksCompleted: periodAnalytics.totalTasksCompleted,
                    completionRate: periodAnalytics.completionRate,
                    averageTasksPerDay: periodAnalytics.averageTasksPerDay,
                    mostProductiveWeek: weeklyBreakdown.max { $0.totalScore < $1.totalScore },
                    projectBreakdown: periodAnalytics.projectBreakdown,
                    priorityBreakdown: periodAnalytics.priorityBreakdown
                )
                completion(.success(monthlyAnalytics))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Period Analytics
    
    /// Calculate analytics for a custom date range
    public func calculateAnalytics(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<PeriodAnalytics, AnalyticsError>) -> Void
    ) {
        // Validate date range
        guard startDate <= endDate else {
            completion(.failure(.invalidDateRange))
            return
        }
        
        // Fetch all tasks in the date range
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                // Filter tasks within date range
                let tasksInRange = allTasks.filter { task in
                    guard let dueDate = task.dueDate else { return false }
                    return dueDate >= startDate && dueDate <= endDate
                }
                
                let analytics = self?.computePeriodAnalytics(
                    tasks: tasksInRange,
                    startDate: startDate,
                    endDate: endDate
                ) ?? PeriodAnalytics(startDate: startDate, endDate: endDate)
                
                completion(.success(analytics))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Productivity Score
    
    /// Calculate overall productivity score
    public func calculateProductivityScore(completion: @escaping (Result<ProductivityScore, AnalyticsError>) -> Void) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let tasks):
                let score = self?.computeProductivityScore(tasks: tasks) ?? ProductivityScore()
                completion(.success(score))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Streak Calculation
    
    /// Calculate current completion streak
    public func calculateStreak(completion: @escaping (Result<StreakInfo, AnalyticsError>) -> Void) {
        taskRepository.fetchCompletedTasks { [weak self] result in
            switch result {
            case .success(let completedTasks):
                let streak = self?.computeStreak(completedTasks: completedTasks) ?? StreakInfo()
                completion(.success(streak))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Computation Methods
    
    private func computeDailyAnalytics(tasks: [Task], date: Date) -> DailyAnalytics {
        let completedTasks = tasks.filter { $0.isComplete }
        let totalTasks = tasks.count
        let completionRate = totalTasks > 0 ? Double(completedTasks.count) / Double(totalTasks) : 0
        
        // Calculate score
        let totalScore = completedTasks.reduce(0) { sum, task in
            sum + scoringService.calculateScore(for: task)
        }
        
        // Group by priority
        var priorityBreakdown: [TaskPriority: Int] = [:]
        for task in completedTasks {
            priorityBreakdown[task.priority, default: 0] += 1
        }
        
        // Group by type
        var typeBreakdown: [TaskType: Int] = [:]
        for task in completedTasks {
            typeBreakdown[task.type, default: 0] += 1
        }
        
        return DailyAnalytics(
            date: date,
            totalTasks: totalTasks,
            completedTasks: completedTasks.count,
            completionRate: completionRate,
            totalScore: totalScore,
            morningTasksCompleted: typeBreakdown[.morning] ?? 0,
            eveningTasksCompleted: typeBreakdown[.evening] ?? 0,
            priorityBreakdown: priorityBreakdown
        )
    }
    
    private func computePeriodAnalytics(tasks: [Task], startDate: Date, endDate: Date) -> PeriodAnalytics {
        let calendar = Calendar.current
        var dailyBreakdown: [DailyAnalytics] = []
        var currentDate = startDate
        
        // Calculate daily analytics for each day in the period
        while currentDate <= endDate {
            let dayTasks = tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: currentDate)
            }
            
            let dailyAnalytics = computeDailyAnalytics(tasks: dayTasks, date: currentDate)
            dailyBreakdown.append(dailyAnalytics)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        // Calculate totals
        let totalScore = dailyBreakdown.reduce(0) { $0 + $1.totalScore }
        let totalTasksCompleted = dailyBreakdown.reduce(0) { $0 + $1.completedTasks }
        let totalTasks = dailyBreakdown.reduce(0) { $0 + $1.totalTasks }
        let completionRate = totalTasks > 0 ? Double(totalTasksCompleted) / Double(totalTasks) : 0
        
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let averageTasksPerDay = dayCount > 0 ? Double(totalTasksCompleted) / Double(dayCount) : 0
        
        // Find most and least productive days
        let mostProductiveDay = dailyBreakdown.max { $0.totalScore < $1.totalScore }
        let leastProductiveDay = dailyBreakdown.min { $0.totalScore < $1.totalScore }
        
        // Calculate project breakdown
        var projectBreakdown: [String: Int] = [:]
        for task in tasks.filter({ $0.isComplete }) {
            let projectName = task.project ?? "Inbox"
            projectBreakdown[projectName, default: 0] += 1
        }
        
        // Calculate priority breakdown
        var priorityBreakdown: [TaskPriority: Int] = [:]
        for task in tasks.filter({ $0.isComplete }) {
            priorityBreakdown[task.priority, default: 0] += 1
        }
        
        return PeriodAnalytics(
            startDate: startDate,
            endDate: endDate,
            dailyBreakdown: dailyBreakdown,
            totalScore: totalScore,
            totalTasksCompleted: totalTasksCompleted,
            completionRate: completionRate,
            averageTasksPerDay: averageTasksPerDay,
            mostProductiveDay: mostProductiveDay,
            leastProductiveDay: leastProductiveDay,
            projectBreakdown: projectBreakdown,
            priorityBreakdown: priorityBreakdown
        )
    }
    
    private func computeProductivityScore(tasks: [Task]) -> ProductivityScore {
        let completedTasks = tasks.filter { $0.isComplete }
        let totalScore = completedTasks.reduce(0) { sum, task in
            sum + scoringService.calculateScore(for: task)
        }
        
        // Calculate level based on score
        let level = totalScore / 100
        let currentLevelProgress = totalScore % 100
        let nextLevelRequirement = 100
        
        return ProductivityScore(
            totalScore: totalScore,
            level: level,
            currentLevelProgress: currentLevelProgress,
            nextLevelRequirement: nextLevelRequirement,
            rank: determineRank(level: level)
        )
    }
    
    private func computeStreak(completedTasks: [Task]) -> StreakInfo {
        let calendar = Calendar.current
        let sortedTasks = completedTasks
            .compactMap { task -> (task: Task, date: Date)? in
                guard let completedDate = task.dateCompleted else { return nil }
                return (task, completedDate)
            }
            .sorted { $0.date > $1.date }
        
        var currentStreak = 0
        var longestStreak = 0
        var lastDate: Date?
        
        for (_, completedDate) in sortedTasks {
            let date = calendar.startOfDay(for: completedDate)
            
            if let last = lastDate {
                let daysDifference = calendar.dateComponents([.day], from: date, to: last).day ?? 0
                
                if daysDifference == 1 {
                    currentStreak += 1
                } else if daysDifference > 1 {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = date
        }
        
        longestStreak = max(longestStreak, currentStreak)
        
        // Check if streak is still active (completed task today or yesterday)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let isActive = sortedTasks.contains { _, date in
            let taskDate = calendar.startOfDay(for: date)
            return taskDate == today || taskDate == yesterday
        }
        
        if !isActive {
            currentStreak = 0
        }
        
        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletionDate: sortedTasks.first?.date
        )
    }
    
    private func determineRank(level: Int) -> String {
        switch level {
        case 0..<5: return "Beginner"
        case 5..<10: return "Novice"
        case 10..<20: return "Intermediate"
        case 20..<30: return "Advanced"
        case 30..<50: return "Expert"
        case 50..<75: return "Master"
        case 75..<100: return "Grandmaster"
        default: return "Legend"
        }
    }
}

// MARK: - Analytics Models

public struct DailyAnalytics {
    public let date: Date
    public let totalTasks: Int
    public let completedTasks: Int
    public let completionRate: Double
    public let totalScore: Int
    public let morningTasksCompleted: Int
    public let eveningTasksCompleted: Int
    public let priorityBreakdown: [TaskPriority: Int]
    
    init(
        date: Date,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        completionRate: Double = 0,
        totalScore: Int = 0,
        morningTasksCompleted: Int = 0,
        eveningTasksCompleted: Int = 0,
        priorityBreakdown: [TaskPriority: Int] = [:]
    ) {
        self.date = date
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.completionRate = completionRate
        self.totalScore = totalScore
        self.morningTasksCompleted = morningTasksCompleted
        self.eveningTasksCompleted = eveningTasksCompleted
        self.priorityBreakdown = priorityBreakdown
    }
}

public struct WeeklyAnalytics {
    public let weekStartDate: Date
    public let weekEndDate: Date
    public let dailyAnalytics: [DailyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveDay: DailyAnalytics?
    public let leastProductiveDay: DailyAnalytics?
}

public struct MonthlyAnalytics {
    public let month: Date
    public let weeklyBreakdown: [WeeklyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveWeek: WeeklyAnalytics?
    public let projectBreakdown: [String: Int]
    public let priorityBreakdown: [TaskPriority: Int]
}

public struct PeriodAnalytics {
    public let startDate: Date
    public let endDate: Date
    public let dailyBreakdown: [DailyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveDay: DailyAnalytics?
    public let leastProductiveDay: DailyAnalytics?
    public let projectBreakdown: [String: Int]
    public let priorityBreakdown: [TaskPriority: Int]
    
    init(
        startDate: Date,
        endDate: Date,
        dailyBreakdown: [DailyAnalytics] = [],
        totalScore: Int = 0,
        totalTasksCompleted: Int = 0,
        completionRate: Double = 0,
        averageTasksPerDay: Double = 0,
        mostProductiveDay: DailyAnalytics? = nil,
        leastProductiveDay: DailyAnalytics? = nil,
        projectBreakdown: [String: Int] = [:],
        priorityBreakdown: [TaskPriority: Int] = [:]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.dailyBreakdown = dailyBreakdown
        self.totalScore = totalScore
        self.totalTasksCompleted = totalTasksCompleted
        self.completionRate = completionRate
        self.averageTasksPerDay = averageTasksPerDay
        self.mostProductiveDay = mostProductiveDay
        self.leastProductiveDay = leastProductiveDay
        self.projectBreakdown = projectBreakdown
        self.priorityBreakdown = priorityBreakdown
    }
}

public struct ProductivityScore {
    public let totalScore: Int
    public let level: Int
    public let currentLevelProgress: Int
    public let nextLevelRequirement: Int
    public let rank: String
    
    init(
        totalScore: Int = 0,
        level: Int = 0,
        currentLevelProgress: Int = 0,
        nextLevelRequirement: Int = 100,
        rank: String = "Beginner"
    ) {
        self.totalScore = totalScore
        self.level = level
        self.currentLevelProgress = currentLevelProgress
        self.nextLevelRequirement = nextLevelRequirement
        self.rank = rank
    }
}

public struct StreakInfo {
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCompletionDate: Date?
    
    init(currentStreak: Int = 0, longestStreak: Int = 0, lastCompletionDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletionDate = lastCompletionDate
    }
}

// MARK: - Error Types

public enum AnalyticsError: LocalizedError {
    case repositoryError(Error)
    case invalidDateRange
    case insufficientData
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .insufficientData:
            return "Insufficient data for analytics calculation"
        }
    }
}

// MARK: - Scoring Service

public class TaskScoringService: TaskScoringServiceProtocol {
    
    public init() {}
    
    public func calculateScore(for task: Task) -> Int {
        guard task.isComplete else { return 0 }
        return task.priority.scoreValue
    }
    
    public func getTotalScore(completion: @escaping (Int) -> Void) {
        // This would typically fetch from a persistent store
        completion(0)
    }
    
    public func getScoreHistory(days: Int, completion: @escaping ([DailyScore]) -> Void) {
        // This would typically fetch from a persistent store
        completion([])
    }
}
