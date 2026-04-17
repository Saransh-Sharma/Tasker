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

public enum TaskerDailySummaryKind: String, Equatable, Codable {
    case morning
    case nightly
}

public enum TaskerNotificationRoute: Equatable, Codable {
    case homeToday(taskID: UUID?)
    case homeDone
    case taskDetail(taskID: UUID)
    case dailySummary(kind: TaskerDailySummaryKind, dateStamp: String?)

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
        case .dailySummary(let kind, let dateStamp):
            if let dateStamp, dateStamp.isEmpty == false {
                return "daily_summary:\(kind.rawValue):\(dateStamp)"
            }
            return "daily_summary:\(kind.rawValue)"
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
        case .dailySummary:
            return nil
        }
    }

    public static func from(payload: String, fallbackTaskID: UUID?) -> TaskerNotificationRoute {
        if payload.hasPrefix("daily_summary:") {
            let value = String(payload.dropFirst("daily_summary:".count))
            let components = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let kindRaw = components.first.map(String.init) ?? ""
            if let kind = TaskerDailySummaryKind(rawValue: kindRaw) {
                let dateStamp = components.count > 1 ? String(components[1]) : nil
                let normalizedDateStamp = dateStamp?.isEmpty == false ? dateStamp : nil
                return .dailySummary(kind: kind, dateStamp: normalizedDateStamp)
            }
        }
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
    public var dueSoonLeadMinutes: Int
    public var quietHoursEnabled: Bool
    public var quietHoursStartHour: Int
    public var quietHoursStartMinute: Int
    public var quietHoursEndHour: Int
    public var quietHoursEndMinute: Int
    public var quietHoursAppliesToTaskAlerts: Bool
    public var quietHoursAppliesToDailySummaries: Bool

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
        dueSoonLeadMinutes: Int = 30,
        quietHoursEnabled: Bool = false,
        quietHoursStartHour: Int = 22,
        quietHoursStartMinute: Int = 0,
        quietHoursEndHour: Int = 7,
        quietHoursEndMinute: Int = 0,
        quietHoursAppliesToTaskAlerts: Bool = true,
        quietHoursAppliesToDailySummaries: Bool = false
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
        self.dueSoonLeadMinutes = Self.clampDueSoonLeadMinutes(dueSoonLeadMinutes)
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStartHour = max(0, min(23, quietHoursStartHour))
        self.quietHoursStartMinute = max(0, min(59, quietHoursStartMinute))
        self.quietHoursEndHour = max(0, min(23, quietHoursEndHour))
        self.quietHoursEndMinute = max(0, min(59, quietHoursEndMinute))
        self.quietHoursAppliesToTaskAlerts = quietHoursAppliesToTaskAlerts
        self.quietHoursAppliesToDailySummaries = quietHoursAppliesToDailySummaries
    }

    public var morningTimeComponents: DateComponents {
        DateComponents(hour: morningHour, minute: morningMinute)
    }

    public var nightlyTimeComponents: DateComponents {
        DateComponents(hour: nightlyHour, minute: nightlyMinute)
    }

    public var quietHoursStartComponents: DateComponents {
        DateComponents(hour: quietHoursStartHour, minute: quietHoursStartMinute)
    }

    public var quietHoursEndComponents: DateComponents {
        DateComponents(hour: quietHoursEndHour, minute: quietHoursEndMinute)
    }

    private static func clampDueSoonLeadMinutes(_ value: Int) -> Int {
        let allowed = [15, 30, 45, 60, 90, 120]
        if allowed.contains(value) {
            return value
        }
        return 30
    }

    private enum CodingKeys: String, CodingKey {
        case taskRemindersEnabled
        case dueSoonEnabled
        case overdueNudgesEnabled
        case morningAgendaEnabled
        case nightlyRetrospectiveEnabled
        case morningHour
        case morningMinute
        case nightlyHour
        case nightlyMinute
        case dueSoonLeadMinutes
        case quietHoursEnabled
        case quietHoursStartHour
        case quietHoursStartMinute
        case quietHoursEndHour
        case quietHoursEndMinute
        case quietHoursAppliesToTaskAlerts
        case quietHoursAppliesToDailySummaries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            taskRemindersEnabled: try container.decodeIfPresent(Bool.self, forKey: .taskRemindersEnabled) ?? true,
            dueSoonEnabled: try container.decodeIfPresent(Bool.self, forKey: .dueSoonEnabled) ?? true,
            overdueNudgesEnabled: try container.decodeIfPresent(Bool.self, forKey: .overdueNudgesEnabled) ?? true,
            morningAgendaEnabled: try container.decodeIfPresent(Bool.self, forKey: .morningAgendaEnabled) ?? true,
            nightlyRetrospectiveEnabled: try container.decodeIfPresent(Bool.self, forKey: .nightlyRetrospectiveEnabled) ?? true,
            morningHour: try container.decodeIfPresent(Int.self, forKey: .morningHour) ?? 8,
            morningMinute: try container.decodeIfPresent(Int.self, forKey: .morningMinute) ?? 0,
            nightlyHour: try container.decodeIfPresent(Int.self, forKey: .nightlyHour) ?? 21,
            nightlyMinute: try container.decodeIfPresent(Int.self, forKey: .nightlyMinute) ?? 0,
            dueSoonLeadMinutes: try container.decodeIfPresent(Int.self, forKey: .dueSoonLeadMinutes) ?? 30,
            quietHoursEnabled: try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false,
            quietHoursStartHour: try container.decodeIfPresent(Int.self, forKey: .quietHoursStartHour) ?? 22,
            quietHoursStartMinute: try container.decodeIfPresent(Int.self, forKey: .quietHoursStartMinute) ?? 0,
            quietHoursEndHour: try container.decodeIfPresent(Int.self, forKey: .quietHoursEndHour) ?? 7,
            quietHoursEndMinute: try container.decodeIfPresent(Int.self, forKey: .quietHoursEndMinute) ?? 0,
            quietHoursAppliesToTaskAlerts: try container.decodeIfPresent(Bool.self, forKey: .quietHoursAppliesToTaskAlerts) ?? true,
            quietHoursAppliesToDailySummaries: try container.decodeIfPresent(Bool.self, forKey: .quietHoursAppliesToDailySummaries) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskRemindersEnabled, forKey: .taskRemindersEnabled)
        try container.encode(dueSoonEnabled, forKey: .dueSoonEnabled)
        try container.encode(overdueNudgesEnabled, forKey: .overdueNudgesEnabled)
        try container.encode(morningAgendaEnabled, forKey: .morningAgendaEnabled)
        try container.encode(nightlyRetrospectiveEnabled, forKey: .nightlyRetrospectiveEnabled)
        try container.encode(morningHour, forKey: .morningHour)
        try container.encode(morningMinute, forKey: .morningMinute)
        try container.encode(nightlyHour, forKey: .nightlyHour)
        try container.encode(nightlyMinute, forKey: .nightlyMinute)
        try container.encode(dueSoonLeadMinutes, forKey: .dueSoonLeadMinutes)
        try container.encode(quietHoursEnabled, forKey: .quietHoursEnabled)
        try container.encode(quietHoursStartHour, forKey: .quietHoursStartHour)
        try container.encode(quietHoursStartMinute, forKey: .quietHoursStartMinute)
        try container.encode(quietHoursEndHour, forKey: .quietHoursEndHour)
        try container.encode(quietHoursEndMinute, forKey: .quietHoursEndMinute)
        try container.encode(quietHoursAppliesToTaskAlerts, forKey: .quietHoursAppliesToTaskAlerts)
        try container.encode(quietHoursAppliesToDailySummaries, forKey: .quietHoursAppliesToDailySummaries)
    }
}

public struct TaskerWorkspacePreferences: Codable, Equatable {
    public var weekStartsOn: Weekday
    public var selectedCalendarIDs: [String]
    public var includeDeclinedCalendarEvents: Bool
    public var includeCanceledCalendarEvents: Bool
    public var includeAllDayInAgenda: Bool
    public var includeAllDayInBusyStrip: Bool

    public init(
        weekStartsOn: Weekday = .monday,
        selectedCalendarIDs: [String] = [],
        includeDeclinedCalendarEvents: Bool = false,
        includeCanceledCalendarEvents: Bool = false,
        includeAllDayInAgenda: Bool = true,
        includeAllDayInBusyStrip: Bool = false
    ) {
        self.weekStartsOn = weekStartsOn
        self.selectedCalendarIDs = Self.normalizeSelectedCalendarIDs(selectedCalendarIDs)
        self.includeDeclinedCalendarEvents = includeDeclinedCalendarEvents
        self.includeCanceledCalendarEvents = includeCanceledCalendarEvents
        self.includeAllDayInAgenda = includeAllDayInAgenda
        self.includeAllDayInBusyStrip = includeAllDayInBusyStrip
    }

    private enum CodingKeys: String, CodingKey {
        case weekStartsOn
        case selectedCalendarIDs
        case includeDeclinedCalendarEvents
        case includeCanceledCalendarEvents
        case includeAllDayInAgenda
        case includeAllDayInBusyStrip
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekStartsOn = try container.decodeIfPresent(Weekday.self, forKey: .weekStartsOn) ?? .monday
        selectedCalendarIDs = Self.normalizeSelectedCalendarIDs(
            try container.decodeIfPresent([String].self, forKey: .selectedCalendarIDs) ?? []
        )
        includeDeclinedCalendarEvents = try container.decodeIfPresent(Bool.self, forKey: .includeDeclinedCalendarEvents) ?? false
        includeCanceledCalendarEvents = try container.decodeIfPresent(Bool.self, forKey: .includeCanceledCalendarEvents) ?? false
        includeAllDayInAgenda = try container.decodeIfPresent(Bool.self, forKey: .includeAllDayInAgenda) ?? true
        includeAllDayInBusyStrip = try container.decodeIfPresent(Bool.self, forKey: .includeAllDayInBusyStrip) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weekStartsOn, forKey: .weekStartsOn)
        try container.encode(selectedCalendarIDs, forKey: .selectedCalendarIDs)
        try container.encode(includeDeclinedCalendarEvents, forKey: .includeDeclinedCalendarEvents)
        try container.encode(includeCanceledCalendarEvents, forKey: .includeCanceledCalendarEvents)
        try container.encode(includeAllDayInAgenda, forKey: .includeAllDayInAgenda)
        try container.encode(includeAllDayInBusyStrip, forKey: .includeAllDayInBusyStrip)
    }

    public func normalizedForPersistence() -> TaskerWorkspacePreferences {
        TaskerWorkspacePreferences(
            weekStartsOn: weekStartsOn,
            selectedCalendarIDs: Self.normalizeSelectedCalendarIDs(selectedCalendarIDs),
            includeDeclinedCalendarEvents: includeDeclinedCalendarEvents,
            includeCanceledCalendarEvents: includeCanceledCalendarEvents,
            includeAllDayInAgenda: includeAllDayInAgenda,
            includeAllDayInBusyStrip: includeAllDayInBusyStrip
        )
    }

    public static func normalizeSelectedCalendarIDs(_ calendarIDs: [String]) -> [String] {
        var deduped: [String] = []
        deduped.reserveCapacity(calendarIDs.count)
        var seen: Set<String> = []

        for id in calendarIDs where seen.insert(id).inserted {
            deduped.append(id)
        }

        return deduped.sorted()
    }
}

public final class TaskerNotificationPreferencesStore {
    public static let shared = TaskerNotificationPreferencesStore()

    private let defaults: UserDefaults
    private let key = "tasker.notification.preferences.v2"
    private let legacyKey = "tasker.notification.preferences.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Initializes a new instance.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> TaskerNotificationPreferences {
        if let data = defaults.data(forKey: key),
           let preferences = try? decoder.decode(TaskerNotificationPreferences.self, from: data) {
            return preferences
        }
        if let legacyData = defaults.data(forKey: legacyKey),
           let legacyPreferences = try? decoder.decode(TaskerNotificationPreferences.self, from: legacyData) {
            save(legacyPreferences)
            defaults.removeObject(forKey: legacyKey)
            return legacyPreferences
        }
        return TaskerNotificationPreferences()
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

public final class TaskerWorkspacePreferencesStore {
    public static let shared = TaskerWorkspacePreferencesStore()
    public static let didChangeNotification = Notification.Name("tasker.workspacePreferences.didChange")

    private let defaults: UserDefaults
    private let key = "tasker.workspace.preferences.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> TaskerWorkspacePreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? decoder.decode(TaskerWorkspacePreferences.self, from: data) else {
            return TaskerWorkspacePreferences()
        }
        return preferences
    }

    public func save(_ preferences: TaskerWorkspacePreferences) {
        let normalized = preferences.normalizedForPersistence()
        let current = load()
        guard current != normalized else { return }
        guard let data = try? encoder.encode(normalized) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: normalized)
    }

    public func update(_ mutate: (inout TaskerWorkspacePreferences) -> Void) {
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
