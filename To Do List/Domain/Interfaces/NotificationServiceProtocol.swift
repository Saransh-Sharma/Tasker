//
//  NotificationServiceProtocol.swift
//  Tasker
//
//  Protocol for notification service abstraction
//

import Foundation

/// Protocol for handling task notifications and reminders
public protocol NotificationServiceProtocol {
    
    // MARK: - Task Reminders
    
    /// Schedule a reminder notification for a task
    /// - Parameters:
    ///   - taskId: The unique identifier of the task
    ///   - taskName: The name of the task for the notification
    ///   - at: The date and time when the reminder should fire
    func scheduleTaskReminder(taskId: UUID, taskName: String, at date: Date)
    
    /// Cancel a scheduled reminder for a task
    /// - Parameter taskId: The unique identifier of the task
    func cancelTaskReminder(taskId: UUID)
    
    /// Cancel all scheduled reminders
    func cancelAllReminders()
    
    // MARK: - Collaboration Notifications
    
    /// Send a collaboration notification
    /// - Parameter notification: The notification to send
    func send(_ notification: CollaborationNotification)
    
    /// Request permission to send notifications
    /// - Parameter completion: Completion handler with permission result
    func requestPermission(completion: @escaping (Bool) -> Void)
    
    /// Check if notifications are authorized
    /// - Parameter completion: Completion handler with authorization status
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void)
}

// MARK: - Notification Models

/// Represents a collaboration notification
public struct CollaborationNotification {
    public let type: CollaborationType
    public let taskId: UUID?
    public let message: String
    public let recipientId: UUID
    public let timestamp: Date
    
    public init(
        type: CollaborationType,
        taskId: UUID? = nil,
        message: String,
        recipientId: UUID,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.taskId = taskId
        self.message = message
        self.recipientId = recipientId
        self.timestamp = timestamp
    }
}

/// Types of collaboration notifications
public enum CollaborationType {
    case taskShared
    case collectionShared
    case taskAssigned
    case permissionChanged
    case accessRevoked
    case commentAdded
    case commentMention
}