//
//  UserStats.swift
//  Tasker
//
//  Domain model for user statistics and lifetime XP tracking
//

import Foundation

/// User statistics tracking XP, streaks, and achievements
public struct UserStats: Codable, Equatable {
    /// Unique identifier for the user (single-user app, so this is typically constant)
    public let userID: String

    /// Lifetime total XP earned (all-time)
    public var lifetimeXP: Int

    /// Today's XP total
    public var dailyXP: Int

    /// Rolling 7-day XP total
    public var weeklyXP: Int

    /// Current streak of consecutive days with XP earned
    public var currentStreak: Int

    /// Longest streak achieved
    public var longestStreak: Int

    /// Total days the user has earned any XP
    public var daysActive: Int

    /// Number of weeks with at least 1 day of activity
    public var weeklyStreaks: Int

    /// Number of months with at least 1 week of activity
    public var monthlyStreaks: Int

    /// Best single day XP total
    public var bestDayXP: Int

    /// Average daily XP (calculated from daysActive)
    public var averageDailyXP: Double

    /// Total tasks completed all-time
    public var totalTasksCompleted: Int

    /// Total habits completed all-time
    public var totalHabitsCompleted: Int

    /// Last time XP was updated
    public var lastXPUpdate: Date

    /// Date of the most recent activity
    public var lastActiveDate: Date?

    public init(
        userID: String = "default",
        lifetimeXP: Int = 0,
        dailyXP: Int = 0,
        weeklyXP: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        daysActive: Int = 0,
        weeklyStreaks: Int = 0,
        monthlyStreaks: Int = 0,
        bestDayXP: Int = 0,
        averageDailyXP: Double = 0,
        totalTasksCompleted: Int = 0,
        totalHabitsCompleted: Int = 0,
        lastXPUpdate: Date = Date(),
        lastActiveDate: Date? = nil
    ) {
        self.userID = userID
        self.lifetimeXP = max(0, lifetimeXP)
        self.dailyXP = max(0, dailyXP)
        self.weeklyXP = max(0, weeklyXP)
        self.currentStreak = max(0, currentStreak)
        self.longestStreak = max(0, longestStreak)
        self.daysActive = max(0, daysActive)
        self.weeklyStreaks = max(0, weeklyStreaks)
        self.monthlyStreaks = max(0, monthlyStreaks)
        self.bestDayXP = max(0, bestDayXP)
        self.averageDailyXP = max(0, averageDailyXP)
        self.totalTasksCompleted = max(0, totalTasksCompleted)
        self.totalHabitsCompleted = max(0, totalHabitsCompleted)
        self.lastXPUpdate = lastXPUpdate
        self.lastActiveDate = lastActiveDate
    }

    // MARK: - XP Updates

    /// Add XP to lifetime total
    /// - Parameter amount: Amount of XP to add
    /// - Returns: New lifetime total
    @discardableResult
    public mutating func addLifetimeXP(_ amount: Int) -> Int {
        lifetimeXP += max(0, amount)
        lastXPUpdate = Date()
        return lifetimeXP
    }

    /// Add XP to daily total
    /// - Parameter amount: Amount of XP to add
    /// - Returns: New daily total
    @discardableResult
    public mutating func addDailyXP(_ amount: Int) -> Int {
        dailyXP += max(0, amount)
        if dailyXP > bestDayXP {
            bestDayXP = dailyXP
        }
        lastXPUpdate = Date()
        return dailyXP
    }

    /// Reset daily XP (called at midnight)
    public mutating func resetDailyXP() {
        dailyXP = 0
        lastXPUpdate = Date()
    }

    /// Recalculate average daily XP
    public mutating func updateAverageDailyXP() {
        guard daysActive > 0 else {
            averageDailyXP = 0
            return
        }
        averageDailyXP = Double(lifetimeXP) / Double(daysActive)
    }

    // MARK: - Streak Management

    /// Increment current streak
    /// - Returns: New streak value
    @discardableResult
    public mutating func incrementStreak() -> Int {
        currentStreak += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        return currentStreak
    }

    /// Reset current streak (when a day is missed)
    public mutating func resetStreak() {
        currentStreak = 0
    }

    /// Check if streak should continue based on last active date
    /// - Parameter currentDate: The current date to check against
    /// - Returns: True if the streak is still valid
    public func isStreakActive(currentDate: Date = Date()) -> Bool {
        guard let lastActive = lastActiveDate else { return false }
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: lastActive, to: currentDate).day ?? 0
        return daysSince <= 1 // Allow 1 day gap (yesterday)
    }

    // MARK: - Task/Habit Tracking

    /// Increment tasks completed count
    /// - Parameter count: Number to add (default: 1)
    /// - Returns: New total
    @discardableResult
    public mutating func addTasksCompleted(_ count: Int = 1) -> Int {
        totalTasksCompleted += max(0, count)
        return totalTasksCompleted
    }

    /// Decrement tasks completed count (for uncomplete)
    /// - Parameter count: Number to subtract (default: 1)
    /// - Returns: New total
    @discardableResult
    public mutating func removeTasksCompleted(_ count: Int = 1) -> Int {
        totalTasksCompleted = max(0, totalTasksCompleted - count)
        return totalTasksCompleted
    }

    /// Increment habits completed count
    /// - Parameter count: Number to add (default: 1)
    /// - Returns: New total
    @discardableResult
    public mutating func addHabitsCompleted(_ count: Int = 1) -> Int {
        totalHabitsCompleted += max(0, count)
        return totalHabitsCompleted
    }

    /// Decrement habits completed count (for uncomplete)
    /// - Parameter count: Number to subtract (default: 1)
    /// - Returns: New total
    @discardableResult
    public mutating func removeHabitsCompleted(_ count: Int = 1) -> Int {
        totalHabitsCompleted = max(0, totalHabitsCompleted - count)
        return totalHabitsCompleted
    }

    // MARK: - Computed Properties

    /// Current level based on lifetime XP
    /// Level formula: level = floor(sqrt(XP / 100)) + 1
    public var currentLevel: Int {
        guard lifetimeXP > 0 else { return 1 }
        return Int(floor(sqrt(Double(lifetimeXP) / 100))) + 1
    }

    /// XP needed for next level
    public var xpToNextLevel: Int {
        let nextLevel = currentLevel + 1
        let xpNeeded = (nextLevel - 1) * (nextLevel - 1) * 100
        return max(0, xpNeeded - lifetimeXP)
    }

    /// Progress toward next level (0.0 to 1.0)
    public var levelProgress: Double {
        let currentLevelXP = (currentLevel - 1) * (currentLevel - 1) * 100
        let nextLevelXP = currentLevel * currentLevel * 100
        let range = nextLevelXP - currentLevelXP
        guard range > 0 else { return 1.0 }
        return Double(lifetimeXP - currentLevelXP) / Double(range)
    }

    /// Whether user is on a streak (3+ days)
    public var isOnStreak: Bool {
        currentStreak >= 3
    }

    /// Whether user had activity today
    public var hasActivityToday: Bool {
        guard let lastActive = lastActiveDate else { return false }
        return Calendar.current.isDateInToday(lastActive)
    }
}

// MARK: - XP Event for Persistence

/// Individual XP event for tracking all XP changes
public struct XPEvent: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let amount: Int
    public let source: XPSource
    public let sourceID: UUID
    public let isAddition: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        amount: Int,
        source: XPSource,
        sourceID: UUID,
        isAddition: Bool
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.source = source
        self.sourceID = sourceID
        self.isAddition = isAddition
    }

    /// Create an addition event
    public static func addition(amount: Int, source: XPSource, sourceID: UUID, date: Date = Date()) -> XPEvent {
        XPEvent(date: date, amount: amount, source: source, sourceID: sourceID, isAddition: true)
    }

    /// Create a subtraction event
    public static func subtraction(amount: Int, source: XPSource, sourceID: UUID, date: Date = Date()) -> XPEvent {
        XPEvent(date: date, amount: amount, source: source, sourceID: sourceID, isAddition: false)
    }
}
