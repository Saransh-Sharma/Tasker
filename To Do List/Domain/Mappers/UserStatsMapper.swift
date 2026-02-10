//
//  UserStatsMapper.swift
//  Tasker
//
//  Mapper for converting between UserStats domain models and Core Data entities
//

import Foundation
import CoreData

/// Mapper class for converting between domain UserStats and Core Data NUserStats
public class UserStatsMapper {

    // MARK: - Domain to Core Data

    /// Convert a domain UserStats to Core Data NUserStats
    /// - Parameters:
    ///   - stats: The domain UserStats model
    ///   - context: The Core Data managed object context
    /// - Returns: The Core Data NUserStats entity
    public static func toEntity(from stats: UserStats, in context: NSManagedObjectContext) -> NUserStats {
        let entity = NUserStats(context: context)
        updateEntity(entity, from: stats)
        return entity
    }

    /// Update an existing NUserStats entity with domain UserStats data
    /// - Parameters:
    ///   - entity: The Core Data NUserStats entity to update
    ///   - stats: The domain UserStats model
    public static func updateEntity(_ entity: NUserStats, from stats: UserStats) {
        entity.userID = stats.userID
        entity.lifetimeXP = Int32(stats.lifetimeXP)
        entity.dailyXP = Int32(stats.dailyXP)
        entity.weeklyXP = Int32(stats.weeklyXP)
        entity.currentStreak = Int16(stats.currentStreak)
        entity.longestStreak = Int16(stats.longestStreak)
        entity.daysActive = Int16(stats.daysActive)
        entity.weeklyStreaks = Int16(stats.weeklyStreaks)
        entity.monthlyStreaks = Int16(stats.monthlyStreaks)
        entity.bestDayXP = Int32(stats.bestDayXP)
        entity.averageDailyXP = stats.averageDailyXP
        entity.totalTasksCompleted = Int32(stats.totalTasksCompleted)
        entity.totalHabitsCompleted = Int32(stats.totalHabitsCompleted)
        entity.lastXPUpdate = stats.lastXPUpdate
        entity.lastActiveDate = stats.lastActiveDate
    }

    // MARK: - Core Data to Domain

    /// Convert a Core Data NUserStats to domain UserStats
    /// - Parameter entity: The Core Data NUserStats entity
    /// - Returns: The domain UserStats model
    public static func toDomain(from entity: NUserStats) -> UserStats {
        return UserStats(
            userID: entity.userID ?? "default",
            lifetimeXP: Int(entity.lifetimeXP),
            dailyXP: Int(entity.dailyXP),
            weeklyXP: Int(entity.weeklyXP),
            currentStreak: Int(entity.currentStreak),
            longestStreak: Int(entity.longestStreak),
            daysActive: Int(entity.daysActive),
            weeklyStreaks: Int(entity.weeklyStreaks),
            monthlyStreaks: Int(entity.monthlyStreaks),
            bestDayXP: Int(entity.bestDayXP),
            averageDailyXP: entity.averageDailyXP,
            totalTasksCompleted: Int(entity.totalTasksCompleted),
            totalHabitsCompleted: Int(entity.totalHabitsCompleted),
            lastXPUpdate: entity.lastXPUpdate ?? Date(),
            lastActiveDate: entity.lastActiveDate
        )
    }

    // MARK: - Find Operations

    /// Find or create user stats for a given user ID
    /// - Parameters:
    ///   - userID: The user ID to find stats for
    ///   - context: The Core Data managed object context
    /// - Returns: The NUserStats entity (existing or newly created)
    public static func findOrCreate(forUserID userID: String, in context: NSManagedObjectContext) -> NUserStats {
        let request: NSFetchRequest<NUserStats> = NUserStats.fetchRequest()
        request.predicate = NSPredicate(format: "userID == %@", userID)
        request.fetchLimit = 1

        do {
            if let existing = try context.fetch(request).first {
                return existing
            }
        } catch {
            print("Error fetching user stats: \(error)")
        }

        // Create new stats
        let newStats = UserStats(userID: userID)
        return toEntity(from: newStats, in: context)
    }

    /// Get user stats for the default user
    /// - Parameter context: The Core Data managed object context
    /// - Returns: The NUserStats entity for the default user
    public static func getDefault(in context: NSManagedObjectContext) -> NUserStats {
        return findOrCreate(forUserID: "default", in: context)
    }
}
