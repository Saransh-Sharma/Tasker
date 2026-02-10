//
//  XPRepositoryProtocol.swift
//  Tasker
//
//  Protocol defining the interface for XP persistence operations.
//  Provides CRUD operations for DailyXP and UserStats records.
//

import Foundation

/// Protocol for XP data persistence
public protocol XPRepositoryProtocol {

    // MARK: - Daily XP Operations

    /// Get DailyXP record for a specific date
    /// - Parameter date: The date to fetch XP for
    /// - Returns: The DailyXP record, or a new one if not found
    func getDailyXP(for date: Date) -> DailyXP

    /// Save a DailyXP record
    /// - Parameter dailyXP: The DailyXP record to save
    /// - Throws: Error if save fails
    func saveDailyXP(_ dailyXP: DailyXP) throws

    /// Get DailyXP records for a date range
    /// - Parameters:
    ///   - startDate: Start of the range (inclusive)
    ///   - endDate: End of the range (inclusive)
    /// - Returns: Array of DailyXP records in the range
    func getDailyXP(from startDate: Date, to endDate: Date) -> [DailyXP]

    /// Delete DailyXP records older than a given date
    /// - Parameter date: Records before this date will be deleted
    /// - Throws: Error if deletion fails
    func deleteDailyXPOlderThan(_ date: Date) throws

    // MARK: - User Stats Operations

    /// Get the user's stats record
    /// - Returns: The UserStats record
    func getUserStats() -> UserStats

    /// Save the user's stats record
    /// - Parameter stats: The UserStats record to save
    /// - Throws: Error if save fails
    func saveUserStats(_ stats: UserStats) throws

    /// Update user stats with a new XP event
    /// - Parameters:
    ///   - event: The XP event that occurred
    ///   - dailyXP: The affected DailyXP record
    /// - Throws: Error if update fails
    func updateUserStats(with event: XPEvent, dailyXP: DailyXP) throws

    // MARK: - XP Event Operations

    /// Save an XP event
    /// - Parameter event: The XP event to save
    /// - Throws: Error if save fails
    func saveXPEvent(_ event: XPEvent) throws

    /// Get XP events for a specific date
    /// - Parameter date: The date to fetch events for
    /// - Returns: Array of XP events for that date
    func getXPEvents(for date: Date) -> [XPEvent]

    /// Get XP events for a date range
    /// - Parameters:
    ///   - startDate: Start of the range (inclusive)
    ///   - endDate: End of the range (inclusive)
    /// - Returns: Array of XP events in the range
    func getXPEvents(from startDate: Date, to endDate: Date) -> [XPEvent]

    // MARK: - Batch Operations

    /// Reset daily XP (typically called at midnight)
    /// - Throws: Error if reset fails
    func resetDailyXP() throws

    /// Calculate and update weekly XP total
    /// - Throws: Error if calculation fails
    func updateWeeklyXP() throws
}
