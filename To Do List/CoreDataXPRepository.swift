//
//  CoreDataXPRepository.swift
//  Tasker
//
//  CoreData implementation of XP repository for persisting XP data.
//

import Foundation
import CoreData

/// CoreData implementation of XP repository
public final class CoreDataXPRepository: XPRepositoryProtocol {

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let calendar: Calendar

    // MARK: - Initialization

    public init(context: NSManagedObjectContext) {
        self.context = context
        self.calendar = Calendar.current
    }

    // MARK: - Daily XP Operations

    public func getDailyXP(for date: Date) -> DailyXP {
        let normalizedDate = normalizeDate(date)

        // Try to fetch from CoreData (via UserStats for now, as we're using cache)
        let request: NSFetchRequest<NUserStats> = NUserStats.fetchRequest()
        request.fetchLimit = 1

        do {
            if let stats = try context.fetch(request).first {
                // If the stats' last update is today, return cached daily XP
                if calendar.isDate(stats.lastXPUpdate ?? Date(), inSameDayAs: normalizedDate) {
                    return DailyXP(
                        date: normalizedDate,
                        earnedXP: Int(stats.dailyXP),
                        completedTaskIDs: [],
                        completedHabitIDs: []
                    )
                }
            }
        } catch {
            logError("Error fetching user stats for daily XP: \(error)")
        }

        // Return new DailyXP if not found or date mismatch
        return DailyXP(date: normalizedDate)
    }

    public func saveDailyXP(_ dailyXP: DailyXP) throws {
        let stats = UserStatsMapper.getDefault(in: context)

        // Update daily XP if it's for today
        if calendar.isDate(stats.lastXPUpdate ?? Date(), inSameDayAs: dailyXP.date) {
            stats.dailyXP = Int32(dailyXP.earnedXP)
        }

        try context.save()
    }

    public func getDailyXP(from startDate: Date, to endDate: Date) -> [DailyXP] {
        // For now, return empty array since we're using in-memory cache
        // In a full implementation, this would query a DailyXP entity
        return []
    }

    public func deleteDailyXPOlderThan(_ date: Date) throws {
        // In a full implementation, this would delete old DailyXP records
        // For now, no-op since we're using in-memory cache
    }

    // MARK: - User Stats Operations

    public func getUserStats() -> UserStats {
        let entity = UserStatsMapper.getDefault(in: context)
        return UserStatsMapper.toDomain(from: entity)
    }

    public func saveUserStats(_ stats: UserStats) throws {
        let entity = UserStatsMapper.findOrCreate(forUserID: stats.userID, in: context)
        UserStatsMapper.updateEntity(entity, from: stats)
        try context.save()
    }

    public func updateUserStats(with event: XPEvent, dailyXP: DailyXP) throws {
        var stats = getUserStats()

        // Update based on event
        if event.isAddition {
            stats.addLifetimeXP(event.amount)
            stats.addDailyXP(event.amount)

            switch event.source {
            case .task:
                stats.addTasksCompleted()
            case .habit:
                stats.addHabitsCompleted()
            case .streakBonus:
                break
            }

            // Update days active and streak
            if let lastActive = stats.lastActiveDate {
                let daysSince = calendar.dateComponents([.day], from: lastActive, to: event.date).day ?? 0
                if daysSince == 1 {
                    stats.incrementStreak()
                } else if daysSince > 1 {
                    stats.resetStreak()
                }
            } else {
                stats.incrementStreak()
                stats.daysActive = 1
            }

            stats.lastActiveDate = event.date
        } else {
            // XP subtraction
            stats.lifetimeXP = max(0, stats.lifetimeXP - event.amount)
            stats.dailyXP = max(0, stats.dailyXP - event.amount)

            switch event.source {
            case .task:
                stats.removeTasksCompleted()
            case .habit:
                stats.removeHabitsCompleted()
            case .streakBonus:
                break
            }
        }

        stats.updateAverageDailyXP()

        try saveUserStats(stats)
    }

    // MARK: - XP Event Operations

    public func saveXPEvent(_ event: XPEvent) throws {
        // In a full implementation, this would save to an NXPEvent entity
        // For now, we update user stats which tracks the totals
        let dailyXP = getDailyXP(for: event.date)
        try updateUserStats(with: event, dailyXP: dailyXP)
    }

    public func getXPEvents(for date: Date) -> [XPEvent] {
        // In a full implementation, this would query NXPEvent entities
        return []
    }

    public func getXPEvents(from startDate: Date, to endDate: Date) -> [XPEvent] {
        // In a full implementation, this would query NXPEvent entities
        return []
    }

    // MARK: - Batch Operations

    public func resetDailyXP() throws {
        let stats = UserStatsMapper.getDefault(in: context)

        // Reset only if it's a new day
        if !calendar.isDate(stats.lastXPUpdate ?? Date(), inSameDayAs: Date()) {
            stats.dailyXP = 0
            try context.save()

            // Publish reset event
            DomainEventPublisher.shared.publish(
                XPResetEvent(
                    userId: UUID(uuidString: stats.userID ?? "") ?? UUID(),
                    date: Date(),
                    previousTotal: Int(stats.dailyXP)
                )
            )
        }
    }

    public func updateWeeklyXP() throws {
        let stats = UserStatsMapper.getDefault(in: context)

        // Calculate last 7 days total
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var weeklyTotal = 0

        // Sum daily XP for the past week (simplified - using daily cache)
        // In a full implementation, this would aggregate stored DailyXP records
        let todayXP = getDailyXP(for: Date()).earnedXP
        weeklyTotal = todayXP // Placeholder - would sum 7 days

        stats.weeklyXP = Int32(weeklyTotal)
        try context.save()
    }

    // MARK: - Private Helpers

    /// Normalize a date to start of day
    private func normalizeDate(_ date: Date) -> Date {
        return calendar.startOfDay(for: date)
    }
}
