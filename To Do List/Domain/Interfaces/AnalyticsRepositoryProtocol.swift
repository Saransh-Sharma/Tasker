//
//  AnalyticsRepositoryProtocol.swift
//  Tasker
//
//  Protocol for analytics data repository operations
//

import Foundation

/// Protocol for analytics repository operations
public protocol AnalyticsRepositoryProtocol {
    
    // MARK: - Analytics Data
    
    /// Fetch analytics data for a specific date range
    /// - Parameters:
    ///   - startDate: Start date for analytics
    ///   - endDate: End date for analytics
    ///   - completion: Completion handler with analytics data or error
    func fetchAnalyticsData(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<AnalyticsData, Error>) -> Void
    )
    
    /// Save analytics data
    /// - Parameters:
    ///   - data: Analytics data to save
    ///   - completion: Completion handler with success or error
    func saveAnalyticsData(
        _ data: AnalyticsData,
        completion: @escaping (Result<Void, Error>) -> Void
    )
    
    /// Fetch task completion patterns
    /// - Parameters:
    ///   - userId: User identifier (optional)
    ///   - completion: Completion handler with patterns or error
    func fetchCompletionPatterns(
        for userId: UUID?,
        completion: @escaping (Result<[CompletionPattern], Error>) -> Void
    )
    
    /// Save task completion pattern
    /// - Parameters:
    ///   - pattern: Completion pattern to save
    ///   - completion: Completion handler with success or error
    func saveCompletionPattern(
        _ pattern: CompletionPattern,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

// MARK: - Analytics Models

/// Represents analytics data for a time period
public struct AnalyticsData {
    public let timeRange: DateInterval
    public let tasksCompleted: Int
    public let totalScore: Int
    public let averageScore: Double
    public let completionRate: Double
    public let streakData: StreakData
    
    public init(
        timeRange: DateInterval,
        tasksCompleted: Int,
        totalScore: Int,
        averageScore: Double,
        completionRate: Double,
        streakData: StreakData
    ) {
        self.timeRange = timeRange
        self.tasksCompleted = tasksCompleted
        self.totalScore = totalScore
        self.averageScore = averageScore
        self.completionRate = completionRate
        self.streakData = streakData
    }
}

/// Represents streak analytics data
public struct StreakData {
    public let currentStreak: Int
    public let longestStreak: Int
    public let streakStartDate: Date?
    public let lastCompletionDate: Date?
    
    public init(
        currentStreak: Int,
        longestStreak: Int,
        streakStartDate: Date? = nil,
        lastCompletionDate: Date? = nil
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.streakStartDate = streakStartDate
        self.lastCompletionDate = lastCompletionDate
    }
}

/// Represents task completion patterns
public struct CompletionPattern {
    public let userId: UUID?
    public let timeOfDay: TimeInterval // Seconds since midnight
    public let dayOfWeek: Int // 1-7 for Monday-Sunday
    public let taskType: TaskType
    public let successRate: Double
    public let averageCompletionTime: TimeInterval
    
    public init(
        userId: UUID? = nil,
        timeOfDay: TimeInterval,
        dayOfWeek: Int,
        taskType: TaskType,
        successRate: Double,
        averageCompletionTime: TimeInterval
    ) {
        self.userId = userId
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.taskType = taskType
        self.successRate = successRate
        self.averageCompletionTime = averageCompletionTime
    }
}