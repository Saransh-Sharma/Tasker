//
//  NUserStats+CoreDataProperties.swift
//  Tasker
//
//  Core Data properties extension for NUserStats entity.
//

import Foundation
import CoreData

extension NUserStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NUserStats> {
        return NSFetchRequest<NUserStats>(entityName: "NUserStats")
    }

    @NSManaged public var averageDailyXP: Double
    @NSManaged public var bestDayXP: Int32
    @NSManaged public var currentStreak: Int16
    @NSManaged public var dailyXP: Int32
    @NSManaged public var daysActive: Int16
    @NSManaged public var lastActiveDate: Date?
    @NSManaged public var lastXPUpdate: Date?
    @NSManaged public var lifetimeXP: Int32
    @NSManaged public var longestStreak: Int16
    @NSManaged public var monthlyStreaks: Int16
    @NSManaged public var totalHabitsCompleted: Int32
    @NSManaged public var totalTasksCompleted: Int32
    @NSManaged public var userID: String?
    @NSManaged public var weeklyStreaks: Int16
    @NSManaged public var weeklyXP: Int32
}

// MARK: - Computed Properties

extension NUserStats {

    /// Check if this entity has a valid user ID
    public var isValid: Bool {
        userID != nil && !userID!.isEmpty
    }

    /// Current level based on lifetime XP
    public var currentLevel: Int {
        guard lifetimeXP > 0 else { return 1 }
        return Int(floor(sqrt(Double(lifetimeXP) / 100))) + 1
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
