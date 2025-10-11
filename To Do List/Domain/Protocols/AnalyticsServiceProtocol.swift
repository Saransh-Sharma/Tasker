//
//  AnalyticsServiceProtocol.swift
//  Tasker
//
//  Protocol for analytics service abstraction
//

import Foundation

/// Protocol for handling task analytics and tracking
public protocol AnalyticsServiceProtocol {
    
    // MARK: - Task Analytics
    
    /// Track when a task is completed
    /// - Parameters:
    ///   - task: The completed task
    ///   - score: Score earned from completion
    ///   - completionTime: When the task was completed
    func trackTaskCompleted(task: Task, score: Int, completionTime: Date)
    
    /// Track when a task is marked as incomplete
    /// - Parameters:
    ///   - task: The task that was uncompleted
    ///   - scoreDeducted: Score deducted for uncompleting
    func trackTaskUncompleted(task: Task, scoreDeducted: Int)
    
    /// Track when a task is created
    /// - Parameter task: The newly created task
    func trackTaskCreated(task: Task)
    
    /// Track when a task is deleted
    /// - Parameter task: The deleted task
    func trackTaskDeleted(task: Task)
    
    /// Track when a task is updated
    /// - Parameters:
    ///   - oldTask: The task before update
    ///   - newTask: The task after update
    func trackTaskUpdated(oldTask: Task, newTask: Task)
    
    /// Track when a task is rescheduled
    /// - Parameters:
    ///   - task: The rescheduled task
    ///   - oldDate: Previous due date
    ///   - newDate: New due date
    func trackTaskRescheduled(task: Task, oldDate: Date?, newDate: Date?)
    
    // MARK: - User Behavior Analytics
    
    /// Track user productivity metrics
    /// - Parameters:
    ///   - date: Date for the metrics
    ///   - completedTasks: Number of tasks completed
    ///   - totalScore: Total score earned
    func trackDailyProductivity(date: Date, completedTasks: Int, totalScore: Int)
    
    /// Track streak milestones
    /// - Parameters:
    ///   - streakCount: Current streak count
    ///   - streakType: Type of streak (daily, weekly, etc.)
    func trackStreakMilestone(streakCount: Int, streakType: String)
    
    /// Track feature usage
    /// - Parameters:
    ///   - feature: Feature name
    ///   - action: Action performed
    ///   - metadata: Additional metadata
    func trackFeatureUsage(feature: String, action: String, metadata: [String: Any]?)
    
    // MARK: - Gamification Analytics
    
    /// Track achievement unlocked
    /// - Parameters:
    ///   - achievement: Achievement details
    ///   - unlockedAt: When the achievement was unlocked
    func trackAchievementUnlocked(achievement: String, unlockedAt: Date)
    
    /// Track level progression
    /// - Parameters:
    ///   - oldLevel: Previous level
    ///   - newLevel: New level
    ///   - totalScore: Total score when level changed
    func trackLevelProgression(oldLevel: Int, newLevel: Int, totalScore: Int)
}