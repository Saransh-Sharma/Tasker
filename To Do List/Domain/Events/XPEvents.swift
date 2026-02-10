//
//  XPEvents.swift
//  Tasker
//
//  Domain events related to XP (experience points) operations
//

import Foundation

// MARK: - XP Domain Events

/// Event fired when XP is added to a user's account
public struct XPAddedEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPAdded"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // XP addition data
    public let amount: Int
    public let newTotal: Int
    public let source: XPSource
    public let sourceID: UUID
    public let date: Date

    public init(
        userId: UUID,
        amount: Int,
        newTotal: Int,
        source: XPSource,
        sourceID: UUID,
        date: Date = Date()
    ) {
        self.aggregateId = userId
        self.amount = amount
        self.newTotal = newTotal
        self.source = source
        self.sourceID = sourceID
        self.date = date
    }
}

/// Event fired when XP is subtracted from a user's account
public struct XPSubtractedEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPSubtracted"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // XP subtraction data
    public let amount: Int
    public let newTotal: Int
    public let source: XPSource
    public let sourceID: UUID
    public let date: Date

    public init(
        userId: UUID,
        amount: Int,
        newTotal: Int,
        source: XPSource,
        sourceID: UUID,
        date: Date = Date()
    ) {
        self.aggregateId = userId
        self.amount = amount
        self.newTotal = newTotal
        self.source = source
        self.sourceID = sourceID
        self.date = date
    }
}

/// Event fired when XP changes (generic, covers both addition and subtraction)
public struct XPChangedEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPChanged"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // XP change data
    public let delta: Int              // Amount of change (positive or negative)
    public let newTotal: Int
    public let source: XPSource
    public let sourceID: UUID
    public let isAddition: Bool
    public let date: Date

    public init(
        userId: UUID,
        delta: Int,
        newTotal: Int,
        source: XPSource,
        sourceID: UUID,
        isAddition: Bool,
        date: Date = Date()
    ) {
        self.aggregateId = userId
        self.delta = delta
        self.newTotal = newTotal
        self.source = source
        self.sourceID = sourceID
        self.isAddition = isAddition
        self.date = date
    }
}

/// Event fired when daily XP is reset (typically at midnight)
public struct XPResetEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPReset"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // Reset data
    public let date: Date              // The date that was reset
    public let previousTotal: Int      // XP before reset
    public let resetReason: ResetReason

    public init(
        userId: UUID,
        date: Date,
        previousTotal: Int,
        resetReason: ResetReason = .midnight
    ) {
        self.aggregateId = userId
        self.date = date
        self.previousTotal = previousTotal
        self.resetReason = resetReason
    }

    /// Reason for the XP reset
    public enum ResetReason: String, Codable {
        case midnight      // Daily reset at midnight
        case manual        // Manually triggered reset
        case testing       // Reset for testing purposes
    }
}

/// Event fired when a user achieves a new level or milestone
public struct XPMilestoneEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPMilestone"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // Milestone data
    public let milestone: XPMilestone
    public let value: Int              // The value that triggered the milestone
    public let date: Date

    public init(
        userId: UUID,
        milestone: XPMilestone,
        value: Int,
        date: Date = Date()
    ) {
        self.aggregateId = userId
        self.milestone = milestone
        self.value = value
        self.date = date
    }

    /// Types of XP milestones
    public enum XPMilestone: String, Codable {
        case firstTask           // First task completed
        case dailyGoal           // Daily XP goal reached
        case streak3             // 3-day streak
        case streak7             // 7-day streak
        case streak14            // 14-day streak
        case streak30            // 30-day streak
        case level10             // Reached 10 total XP
        case level50             // Reached 50 total XP
        case level100            // Reached 100 total XP
        case tasks10             // 10 tasks completed
        case tasks50             // 50 tasks completed
        case tasks100            // 100 tasks completed
    }
}

/// Event fired when a streak bonus is awarded
public struct XPStreakBonusEvent: DomainEvent {
    public let eventId: UUID = UUID()
    public let occurredAt: Date = Date()
    public let eventType: String = "XPStreakBonus"
    public let aggregateId: UUID
    public let metadata: [String: Any]? = nil
    public let userId: UUID? = nil

    // Streak bonus data
    public let baseXP: Int
    public let multiplier: Double   // e.g., 1.5x, 2x, 3x
    public let bonusXP: Int
    public let totalXP: Int
    public let streakDays: Int
    public let sourceID: UUID       // Habit ID that triggered the streak
    public let date: Date

    public init(
        userId: UUID,
        baseXP: Int,
        multiplier: Double,
        bonusXP: Int,
        totalXP: Int,
        streakDays: Int,
        sourceID: UUID,
        date: Date = Date()
    ) {
        self.aggregateId = userId
        self.baseXP = baseXP
        self.multiplier = multiplier
        self.bonusXP = bonusXP
        self.totalXP = totalXP
        self.streakDays = streakDays
        self.sourceID = sourceID
        self.date = date
    }
}
