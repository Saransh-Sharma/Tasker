//
//  NotificationServiceProtocol.swift
//  Tasker
//
//  Protocol for notification service abstraction
//

import Foundation
import UserNotifications

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

    // MARK: - Typed Local Notifications

    /// Schedule a typed local notification request.
    func schedule(request: TaskerLocalNotificationRequest)

    /// Cancel pending requests by identifier.
    func cancel(ids: [String])

    /// Inspect pending notification requests.
    func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void)

    /// Register local notification action categories.
    func registerCategories(_ categories: Set<UNNotificationCategory>)

    /// Set notification center delegate.
    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?)

    /// Fetch fine-grained authorization status.
    func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void)
}

public extension NotificationServiceProtocol {
    func schedule(request: TaskerLocalNotificationRequest) {
        _ = request
        assertionFailure("NotificationServiceProtocol.schedule(request:) must be implemented by concrete notification services.")
    }

    func cancel(ids: [String]) {
        _ = ids
        assertionFailure("NotificationServiceProtocol.cancel(ids:) must be implemented by concrete notification services.")
    }

    func pendingRequests(completion: @escaping ([TaskerPendingNotificationRequest]) -> Void) {
        assertionFailure("NotificationServiceProtocol.pendingRequests(completion:) should be implemented for typed notification reconciliation.")
        completion([])
    }

    func registerCategories(_ categories: Set<UNNotificationCategory>) {
        _ = categories
    }

    func setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {
        _ = delegate
    }

    func fetchAuthorizationStatus(completion: @escaping (TaskerNotificationAuthorizationStatus) -> Void) {
        checkAuthorizationStatus { authorized in
            completion(authorized ? .authorized : .denied)
        }
    }
}

public enum TaskerNotificationCategoryID: String, CaseIterable {
    case taskActionable = "tasker.task_actionable"
    case dailyMorning = "tasker.daily_morning"
    case dailyNightly = "tasker.daily_nightly"
}

public enum TaskerLocalNotificationKind: String, Codable, CaseIterable {
    case taskReminder
    case dueSoon
    case overdue
    case morningPlan
    case nightlyRetrospective
    case snoozedTask
    case snoozedMorning
    case snoozedNightly

    public var defaultCategoryID: TaskerNotificationCategoryID {
        switch self {
        case .taskReminder, .dueSoon, .overdue, .snoozedTask:
            return .taskActionable
        case .morningPlan, .snoozedMorning:
            return .dailyMorning
        case .nightlyRetrospective, .snoozedNightly:
            return .dailyNightly
        }
    }
}

public enum TaskerNotificationActionID: String, Codable, CaseIterable {
    case open = "tasker.action.open"
    case complete = "tasker.action.complete"
    case snooze15m = "tasker.action.snooze_15m"
    case openToday = "tasker.action.open_today"
    case snooze30m = "tasker.action.snooze_30m"
    case openDone = "tasker.action.open_done"
    case snooze60m = "tasker.action.snooze_60m"
}

public enum TaskerNotificationAuthorizationStatus: String, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public enum TaskerNotificationRoute: Equatable, Codable {
    case homeToday(taskID: UUID?)
    case homeDone
    case taskDetail(taskID: UUID)

    public var payload: String {
        switch self {
        case .homeToday(let taskID):
            if let taskID {
                return "home_today:\(taskID.uuidString)"
            }
            return "home_today"
        case .homeDone:
            return "home_done"
        case .taskDetail(let taskID):
            return "task_detail:\(taskID.uuidString)"
        }
    }

    public var taskID: UUID? {
        switch self {
        case .homeToday(let taskID):
            return taskID
        case .homeDone:
            return nil
        case .taskDetail(let taskID):
            return taskID
        }
    }

    public static func from(payload: String, fallbackTaskID: UUID?) -> TaskerNotificationRoute {
        if payload == "home_done" {
            return .homeDone
        }
        if payload.hasPrefix("task_detail:") {
            let value = String(payload.dropFirst("task_detail:".count))
            if let taskID = UUID(uuidString: value) {
                return .taskDetail(taskID: taskID)
            }
        }
        if payload.hasPrefix("home_today:") {
            let value = String(payload.dropFirst("home_today:".count))
            if let taskID = UUID(uuidString: value) {
                return .homeToday(taskID: taskID)
            }
        }
        if payload == "home_today" {
            return .homeToday(taskID: fallbackTaskID)
        }
        if let fallbackTaskID {
            return .taskDetail(taskID: fallbackTaskID)
        }
        return .homeToday(taskID: nil)
    }
}

public struct TaskerLocalNotificationRequest: Equatable {
    public enum UserInfoKey {
        public static let kind = "tasker.kind"
        public static let route = "tasker.route"
        public static let taskID = "tasker.task_id"
        public static let fireDateUnix = "tasker.fire_date_unix"
    }

    public let id: String
    public let kind: TaskerLocalNotificationKind
    public let title: String
    public let body: String
    public let fireDate: Date
    public let repeats: Bool
    public let route: TaskerNotificationRoute
    public let taskID: UUID?
    public let categoryIdentifier: String
    public let userInfo: [String: String]

    /// Initializes a new instance.
    public init(
        id: String,
        kind: TaskerLocalNotificationKind,
        title: String,
        body: String,
        fireDate: Date,
        repeats: Bool = false,
        route: TaskerNotificationRoute,
        taskID: UUID? = nil,
        categoryIdentifier: String? = nil,
        userInfo: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.repeats = repeats
        self.route = route
        self.taskID = taskID ?? route.taskID
        self.categoryIdentifier = categoryIdentifier ?? kind.defaultCategoryID.rawValue
        self.userInfo = userInfo
    }
}

public struct TaskerPendingNotificationRequest: Equatable {
    public let id: String
    public let fireDate: Date?
    public let kind: TaskerLocalNotificationKind?
    public let title: String
    public let body: String
    public let categoryIdentifier: String
    public let routePayload: String?
    public let taskID: UUID?

    /// Initializes a new instance.
    public init(
        id: String,
        fireDate: Date?,
        kind: TaskerLocalNotificationKind?,
        title: String = "",
        body: String = "",
        categoryIdentifier: String = "",
        routePayload: String? = nil,
        taskID: UUID? = nil
    ) {
        self.id = id
        self.fireDate = fireDate
        self.kind = kind
        self.title = title
        self.body = body
        self.categoryIdentifier = categoryIdentifier
        self.routePayload = routePayload
        self.taskID = taskID
    }
}

public struct TaskerNotificationPreferences: Codable, Equatable {
    public var taskRemindersEnabled: Bool
    public var dueSoonEnabled: Bool
    public var overdueNudgesEnabled: Bool
    public var morningAgendaEnabled: Bool
    public var nightlyRetrospectiveEnabled: Bool
    public var morningHour: Int
    public var morningMinute: Int
    public var nightlyHour: Int
    public var nightlyMinute: Int
    public var quietHoursEnabled: Bool

    /// Initializes a new instance.
    public init(
        taskRemindersEnabled: Bool = true,
        dueSoonEnabled: Bool = true,
        overdueNudgesEnabled: Bool = true,
        morningAgendaEnabled: Bool = true,
        nightlyRetrospectiveEnabled: Bool = true,
        morningHour: Int = 8,
        morningMinute: Int = 0,
        nightlyHour: Int = 21,
        nightlyMinute: Int = 0,
        quietHoursEnabled: Bool = false
    ) {
        self.taskRemindersEnabled = taskRemindersEnabled
        self.dueSoonEnabled = dueSoonEnabled
        self.overdueNudgesEnabled = overdueNudgesEnabled
        self.morningAgendaEnabled = morningAgendaEnabled
        self.nightlyRetrospectiveEnabled = nightlyRetrospectiveEnabled
        self.morningHour = max(0, min(23, morningHour))
        self.morningMinute = max(0, min(59, morningMinute))
        self.nightlyHour = max(0, min(23, nightlyHour))
        self.nightlyMinute = max(0, min(59, nightlyMinute))
        self.quietHoursEnabled = quietHoursEnabled
    }

    public var morningTimeComponents: DateComponents {
        DateComponents(hour: morningHour, minute: morningMinute)
    }

    public var nightlyTimeComponents: DateComponents {
        DateComponents(hour: nightlyHour, minute: nightlyMinute)
    }
}

public final class TaskerNotificationPreferencesStore {
    public static let shared = TaskerNotificationPreferencesStore()

    private let defaults: UserDefaults
    private let key = "tasker.notification.preferences.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Initializes a new instance.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> TaskerNotificationPreferences {
        guard let data = defaults.data(forKey: key) else {
            return TaskerNotificationPreferences()
        }
        guard let preferences = try? decoder.decode(TaskerNotificationPreferences.self, from: data) else {
            return TaskerNotificationPreferences()
        }
        return preferences
    }

    public func save(_ preferences: TaskerNotificationPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }

    public func update(_ mutate: (inout TaskerNotificationPreferences) -> Void) {
        var current = load()
        mutate(&current)
        save(current)
    }
}

// MARK: - Notification Models

/// Represents a collaboration notification
public struct CollaborationNotification {
    public let type: CollaborationType
    public let taskId: UUID?
    public let message: String
    public let recipientId: UUID
    public let timestamp: Date
    
    /// Initializes a new instance.
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
