import Foundation

/// Data snapshot written by the app and read by widgets.
/// Serialized as JSON to the App Group container.
public struct GamificationWidgetSnapshot: Codable {
    public var dailyXP: Int
    public var dailyCap: Int
    public var level: Int
    public var totalXP: Int64
    public var nextLevelXP: Int64
    public var currentLevelThreshold: Int64
    public var streakDays: Int
    public var bestStreak: Int
    public var tasksCompletedToday: Int
    public var focusMinutesToday: Int

    // Weekly bars (7 entries, Mon-Sun)
    public var weeklyXP: [Int]  // 7 elements
    public var weeklyTotalXP: Int

    // Next milestone
    public var nextMilestoneName: String?
    public var nextMilestoneXP: Int64?
    public var milestoneProgress: Double  // 0.0-1.0

    public var updatedAt: Date

    public init(
        dailyXP: Int = 0,
        dailyCap: Int = 250,
        level: Int = 1,
        totalXP: Int64 = 0,
        nextLevelXP: Int64 = 0,
        currentLevelThreshold: Int64 = 0,
        streakDays: Int = 0,
        bestStreak: Int = 0,
        tasksCompletedToday: Int = 0,
        focusMinutesToday: Int = 0,
        weeklyXP: [Int] = Array(repeating: 0, count: 7),
        weeklyTotalXP: Int = 0,
        nextMilestoneName: String? = nil,
        nextMilestoneXP: Int64? = nil,
        milestoneProgress: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.dailyXP = dailyXP
        self.dailyCap = dailyCap
        self.level = level
        self.totalXP = totalXP
        self.nextLevelXP = nextLevelXP
        self.currentLevelThreshold = currentLevelThreshold
        self.streakDays = streakDays
        self.bestStreak = bestStreak
        self.tasksCompletedToday = tasksCompletedToday
        self.focusMinutesToday = focusMinutesToday
        self.weeklyXP = weeklyXP
        self.weeklyTotalXP = weeklyTotalXP
        self.nextMilestoneName = nextMilestoneName
        self.nextMilestoneXP = nextMilestoneXP
        self.milestoneProgress = milestoneProgress
        self.updatedAt = updatedAt
    }

    // MARK: - Read / Write

    public static func load() -> GamificationWidgetSnapshot {
        guard let url = AppGroupConstants.snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(GamificationWidgetSnapshot.self, from: data) else {
            return GamificationWidgetSnapshot()
        }
        return snapshot
    }

    public func save() {
        guard let url = AppGroupConstants.snapshotURL,
              let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// A compact task row projection consumed by task-list widgets.
public struct TaskListWidgetTask: Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var projectID: UUID?
    public var projectName: String?
    public var priorityCode: String
    public var dueDate: Date?
    public var isOverdue: Bool
    public var estimatedDurationMinutes: Int?
    public var energy: String
    public var context: String
    public var isComplete: Bool
    public var hasDependencies: Bool

    public init(
        id: UUID,
        title: String,
        projectID: UUID? = nil,
        projectName: String? = nil,
        priorityCode: String = "P1",
        dueDate: Date? = nil,
        isOverdue: Bool = false,
        estimatedDurationMinutes: Int? = nil,
        energy: String = "medium",
        context: String = "anywhere",
        isComplete: Bool = false,
        hasDependencies: Bool = false
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.projectName = projectName
        self.priorityCode = priorityCode
        self.dueDate = dueDate
        self.isOverdue = isOverdue
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.energy = energy
        self.context = context
        self.isComplete = isComplete
        self.hasDependencies = hasDependencies
    }
}

public struct TaskListWidgetProjectSlice: Codable, Equatable, Hashable, Identifiable {
    public var id: String {
        projectID?.uuidString ?? projectName.lowercased()
    }

    public var projectID: UUID?
    public var projectName: String
    public var openCount: Int
    public var overdueCount: Int

    public init(
        projectID: UUID? = nil,
        projectName: String,
        openCount: Int,
        overdueCount: Int
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.openCount = openCount
        self.overdueCount = overdueCount
    }
}

public struct TaskListWidgetEnergyBucket: Codable, Equatable, Hashable, Identifiable {
    public var id: String { energy }

    public var energy: String
    public var count: Int

    public init(energy: String, count: Int) {
        self.energy = energy
        self.count = count
    }
}

public struct TaskListWidgetSnapshotHealth: Codable, Equatable {
    public var source: String
    public var generatedAt: Date
    public var isStale: Bool
    public var hasCorruptionFallback: Bool

    public init(
        source: String = "full_query",
        generatedAt: Date = Date(),
        isStale: Bool = false,
        hasCorruptionFallback: Bool = false
    ) {
        self.source = source
        self.generatedAt = generatedAt
        self.isStale = isStale
        self.hasCorruptionFallback = hasCorruptionFallback
    }
}

public enum TaskListWidgetCalendarStatus: String, Codable, Equatable, Hashable {
    case permissionRequired
    case noCalendarsSelected
    case empty
    case allDayOnly
    case error
    case active
}

public struct TaskListWidgetCalendarEvent: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var calendarTitle: String
    public var calendarColorHex: String?
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var isBusy: Bool
    public var isCanceled: Bool
    public var isTentative: Bool

    public init(
        id: String,
        title: String,
        calendarTitle: String,
        calendarColorHex: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isBusy: Bool,
        isCanceled: Bool = false,
        isTentative: Bool = false
    ) {
        self.id = id
        self.title = title
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.startDate = startDate
        self.endDate = max(endDate, startDate)
        self.isAllDay = isAllDay
        self.isBusy = isBusy
        self.isCanceled = isCanceled
        self.isTentative = isTentative
    }
}

public struct TaskListWidgetCalendarNextMeeting: Codable, Equatable, Hashable {
    public var event: TaskListWidgetCalendarEvent
    public var isInProgress: Bool
    public var minutesUntilStart: Int

    public init(
        event: TaskListWidgetCalendarEvent,
        isInProgress: Bool,
        minutesUntilStart: Int
    ) {
        self.event = event
        self.isInProgress = isInProgress
        self.minutesUntilStart = minutesUntilStart
    }
}

public struct TaskListWidgetCalendarDay: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var date: Date
    public var eventCount: Int
    public var timedEvents: [TaskListWidgetCalendarEvent]
    public var allDayEvents: [TaskListWidgetCalendarEvent]

    public init(
        date: Date,
        eventCount: Int,
        timedEvents: [TaskListWidgetCalendarEvent] = [],
        allDayEvents: [TaskListWidgetCalendarEvent] = []
    ) {
        self.id = TaskListWidgetCalendarDay.id(for: date)
        self.date = date
        self.eventCount = eventCount
        self.timedEvents = timedEvents
        self.allDayEvents = allDayEvents
    }

    private static func id(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct TaskListWidgetCalendarSnapshot: Codable, Equatable {
    public var status: TaskListWidgetCalendarStatus
    public var date: Date
    public var updatedAt: Date
    public var selectedCalendarCount: Int
    public var availableCalendarCount: Int
    public var eventsTodayCount: Int
    public var nextMeeting: TaskListWidgetCalendarNextMeeting?
    public var freeUntil: Date?
    public var timedEvents: [TaskListWidgetCalendarEvent]
    public var allDayEvents: [TaskListWidgetCalendarEvent]
    public var weekDays: [TaskListWidgetCalendarDay]
    public var isLoading: Bool
    public var errorMessage: String?

    public init(
        status: TaskListWidgetCalendarStatus = .permissionRequired,
        date: Date = Date(),
        updatedAt: Date = Date(),
        selectedCalendarCount: Int = 0,
        availableCalendarCount: Int = 0,
        eventsTodayCount: Int = 0,
        nextMeeting: TaskListWidgetCalendarNextMeeting? = nil,
        freeUntil: Date? = nil,
        timedEvents: [TaskListWidgetCalendarEvent] = [],
        allDayEvents: [TaskListWidgetCalendarEvent] = [],
        weekDays: [TaskListWidgetCalendarDay] = [],
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.status = status
        self.date = date
        self.updatedAt = updatedAt
        self.selectedCalendarCount = selectedCalendarCount
        self.availableCalendarCount = availableCalendarCount
        self.eventsTodayCount = eventsTodayCount
        self.nextMeeting = nextMeeting
        self.freeUntil = freeUntil
        self.timedEvents = timedEvents
        self.allDayEvents = allDayEvents
        self.weekDays = weekDays
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    public static let empty = TaskListWidgetCalendarSnapshot()
}

public enum TaskListWidgetTimelineItemSource: String, Codable, Equatable, Hashable {
    case task
    case calendarEvent
}

public enum TaskListWidgetTimelineLoadLevel: String, Codable, Equatable, Hashable {
    case light
    case balanced
    case busy
}

public struct TaskListWidgetTimelineItem: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var source: TaskListWidgetTimelineItemSource
    public var taskID: UUID?
    public var eventID: String?
    public var title: String
    public var subtitle: String?
    public var startDate: Date?
    public var endDate: Date?
    public var isAllDay: Bool
    public var isComplete: Bool
    public var tintHex: String?
    public var systemImageName: String
    public var accessoryText: String?
    public var isCurrent: Bool

    public init(
        id: String,
        source: TaskListWidgetTimelineItemSource,
        taskID: UUID? = nil,
        eventID: String? = nil,
        title: String,
        subtitle: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        isComplete: Bool = false,
        tintHex: String? = nil,
        systemImageName: String = "calendar",
        accessoryText: String? = nil,
        isCurrent: Bool = false
    ) {
        self.id = id
        self.source = source
        self.taskID = taskID
        self.eventID = eventID
        self.title = title
        self.subtitle = subtitle
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isComplete = isComplete
        self.tintHex = tintHex
        self.systemImageName = systemImageName
        self.accessoryText = accessoryText
        self.isCurrent = isCurrent
    }
}

public struct TaskListWidgetTimelineGap: Codable, Equatable, Hashable, Identifiable {
    public var id: String
    public var startDate: Date
    public var endDate: Date
    public var suggestedTaskCount: Int
    public var headline: String
    public var supportingText: String

    public init(
        startDate: Date,
        endDate: Date,
        suggestedTaskCount: Int,
        headline: String = "Open time",
        supportingText: String = "Add a task or place something from Inbox."
    ) {
        self.id = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        self.startDate = startDate
        self.endDate = max(endDate, startDate)
        self.suggestedTaskCount = suggestedTaskCount
        self.headline = headline
        self.supportingText = supportingText
    }

    public var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

public struct TaskListWidgetTimelineWeekDay: Codable, Equatable, Hashable, Identifiable {
    public var id: String { dayKey }

    public var date: Date
    public var dayKey: String
    public var allDayCount: Int
    public var timedCount: Int
    public var tintHexes: [String]
    public var loadLevel: TaskListWidgetTimelineLoadLevel

    public init(
        date: Date,
        dayKey: String,
        allDayCount: Int,
        timedCount: Int,
        tintHexes: [String] = [],
        loadLevel: TaskListWidgetTimelineLoadLevel = .light
    ) {
        self.date = date
        self.dayKey = dayKey
        self.allDayCount = allDayCount
        self.timedCount = timedCount
        self.tintHexes = tintHexes
        self.loadLevel = loadLevel
    }
}

public struct TaskListWidgetTimelineDay: Codable, Equatable, Hashable {
    public var date: Date
    public var wakeAnchor: Date
    public var sleepAnchor: Date
    public var currentTime: Date
    public var allDayItems: [TaskListWidgetTimelineItem]
    public var inboxItems: [TaskListWidgetTimelineItem]
    public var timedItems: [TaskListWidgetTimelineItem]
    public var gaps: [TaskListWidgetTimelineGap]
    public var currentItemID: String?

    public init(
        date: Date = Date(),
        wakeAnchor: Date = Date(),
        sleepAnchor: Date = Date(),
        currentTime: Date = Date(),
        allDayItems: [TaskListWidgetTimelineItem] = [],
        inboxItems: [TaskListWidgetTimelineItem] = [],
        timedItems: [TaskListWidgetTimelineItem] = [],
        gaps: [TaskListWidgetTimelineGap] = [],
        currentItemID: String? = nil
    ) {
        self.date = date
        self.wakeAnchor = wakeAnchor
        self.sleepAnchor = sleepAnchor
        self.currentTime = currentTime
        self.allDayItems = allDayItems
        self.inboxItems = inboxItems
        self.timedItems = timedItems
        self.gaps = gaps
        self.currentItemID = currentItemID
    }
}

public struct TaskListWidgetTimelineSnapshot: Codable, Equatable, Hashable {
    public var date: Date
    public var updatedAt: Date
    public var day: TaskListWidgetTimelineDay
    public var weekDays: [TaskListWidgetTimelineWeekDay]
    public var calendarPlottingEnabled: Bool

    public init(
        date: Date = Date(),
        updatedAt: Date = Date(),
        day: TaskListWidgetTimelineDay = TaskListWidgetTimelineDay(),
        weekDays: [TaskListWidgetTimelineWeekDay] = [],
        calendarPlottingEnabled: Bool = false
    ) {
        self.date = date
        self.updatedAt = updatedAt
        self.day = day
        self.weekDays = weekDays
        self.calendarPlottingEnabled = calendarPlottingEnabled
    }

    public static let empty = TaskListWidgetTimelineSnapshot()
}

/// Data snapshot for task-list widgets, serialized in the App Group container.
public struct TaskListWidgetSnapshot: Codable, Equatable {
    public static let currentSchemaVersion = 4

    public var schemaVersion: Int
    public var updatedAt: Date
    public var todayTopTasks: [TaskListWidgetTask]
    public var upcomingTasks: [TaskListWidgetTask]
    public var overdueTasks: [TaskListWidgetTask]
    public var quickWins: [TaskListWidgetTask]
    public var projectSlices: [TaskListWidgetProjectSlice]
    public var doneTodayCount: Int
    public var focusNow: [TaskListWidgetTask]
    public var waitingOn: [TaskListWidgetTask]
    public var energyBuckets: [TaskListWidgetEnergyBucket]
    public var openTodayCount: Int
    public var openTaskPool: [TaskListWidgetTask]
    public var completedTodayTasks: [TaskListWidgetTask]
    public var snapshotHealth: TaskListWidgetSnapshotHealth
    public var calendar: TaskListWidgetCalendarSnapshot
    public var timeline: TaskListWidgetTimelineSnapshot

    public init(
        schemaVersion: Int = TaskListWidgetSnapshot.currentSchemaVersion,
        updatedAt: Date = Date(),
        todayTopTasks: [TaskListWidgetTask] = [],
        upcomingTasks: [TaskListWidgetTask] = [],
        overdueTasks: [TaskListWidgetTask] = [],
        quickWins: [TaskListWidgetTask] = [],
        projectSlices: [TaskListWidgetProjectSlice] = [],
        doneTodayCount: Int = 0,
        focusNow: [TaskListWidgetTask] = [],
        waitingOn: [TaskListWidgetTask] = [],
        energyBuckets: [TaskListWidgetEnergyBucket] = [],
        openTodayCount: Int = 0,
        openTaskPool: [TaskListWidgetTask] = [],
        completedTodayTasks: [TaskListWidgetTask] = [],
        snapshotHealth: TaskListWidgetSnapshotHealth = TaskListWidgetSnapshotHealth(),
        calendar: TaskListWidgetCalendarSnapshot = .empty,
        timeline: TaskListWidgetTimelineSnapshot = .empty
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.todayTopTasks = todayTopTasks
        self.upcomingTasks = upcomingTasks
        self.overdueTasks = overdueTasks
        self.quickWins = quickWins
        self.projectSlices = projectSlices
        self.doneTodayCount = doneTodayCount
        self.focusNow = focusNow
        self.waitingOn = waitingOn
        self.energyBuckets = energyBuckets
        self.openTodayCount = openTodayCount
        self.openTaskPool = openTaskPool
        self.completedTodayTasks = completedTodayTasks
        self.snapshotHealth = snapshotHealth
        self.calendar = calendar
        self.timeline = timeline
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case todayTopTasks
        case upcomingTasks
        case overdueTasks
        case quickWins
        case projectSlices
        case doneTodayCount
        case focusNow
        case waitingOn
        case energyBuckets
        case openTodayCount
        case openTaskPool
        case completedTodayTasks
        case snapshotHealth
        case calendar
        case timeline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.todayTopTasks = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .todayTopTasks) ?? []
        self.upcomingTasks = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .upcomingTasks) ?? []
        self.overdueTasks = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .overdueTasks) ?? []
        self.quickWins = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .quickWins) ?? []
        self.projectSlices = try container.decodeIfPresent([TaskListWidgetProjectSlice].self, forKey: .projectSlices) ?? []
        self.doneTodayCount = try container.decodeIfPresent(Int.self, forKey: .doneTodayCount) ?? 0
        self.focusNow = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .focusNow) ?? []
        self.waitingOn = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .waitingOn) ?? []
        self.energyBuckets = try container.decodeIfPresent([TaskListWidgetEnergyBucket].self, forKey: .energyBuckets) ?? []
        self.openTodayCount = try container.decodeIfPresent(Int.self, forKey: .openTodayCount) ?? todayTopTasks.count
        self.openTaskPool = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .openTaskPool) ?? []
        self.completedTodayTasks = try container.decodeIfPresent([TaskListWidgetTask].self, forKey: .completedTodayTasks) ?? []
        self.snapshotHealth = try container.decodeIfPresent(TaskListWidgetSnapshotHealth.self, forKey: .snapshotHealth) ?? TaskListWidgetSnapshotHealth()
        self.calendar = try container.decodeIfPresent(TaskListWidgetCalendarSnapshot.self, forKey: .calendar) ?? .empty
        self.timeline = try container.decodeIfPresent(TaskListWidgetTimelineSnapshot.self, forKey: .timeline) ?? .empty
    }

    public static func load() -> TaskListWidgetSnapshot {
        let decoder = JSONDecoder()
        if let url = AppGroupConstants.taskListSnapshotURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? decoder.decode(TaskListWidgetSnapshot.self, from: data) {
            return snapshot
        }

        if let backupURL = AppGroupConstants.taskListSnapshotBackupURL,
           let data = try? Data(contentsOf: backupURL),
           var backup = try? decoder.decode(TaskListWidgetSnapshot.self, from: data) {
            backup.snapshotHealth.hasCorruptionFallback = true
            return backup
        }

        return TaskListWidgetSnapshot(
            snapshotHealth: TaskListWidgetSnapshotHealth(
                source: "empty_default",
                generatedAt: Date(),
                isStale: true,
                hasCorruptionFallback: false
            )
        )
    }

    public func save() {
        guard let url = AppGroupConstants.taskListSnapshotURL,
              let backupURL = AppGroupConstants.taskListSnapshotBackupURL,
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        try? data.write(to: url, options: .atomic)
        try? data.write(to: backupURL, options: .atomic)
    }
}

public enum TaskListWidgetActionType: String, Codable, Equatable {
    case complete
    case defer15m
    case defer60m
}

public struct TaskListWidgetActionCommand: Codable, Equatable {
    public var commandID: UUID
    public var taskID: UUID
    public var action: TaskListWidgetActionType
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        commandID: UUID = UUID(),
        taskID: UUID,
        action: TaskListWidgetActionType,
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(5 * 60)
    ) {
        self.commandID = commandID
        self.taskID = taskID
        self.action = action
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    @discardableResult
    public func savePending() -> Bool {
        guard let url = AppGroupConstants.taskListActionCommandURL,
              let data = try? JSONEncoder().encode(self) else {
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public static func loadPending() -> TaskListWidgetActionCommand? {
        guard let url = AppGroupConstants.taskListActionCommandURL,
              let data = try? Data(contentsOf: url),
              let command = try? JSONDecoder().decode(TaskListWidgetActionCommand.self, from: data) else {
            return nil
        }
        return command
    }

    public static func clearPending() {
        guard let url = AppGroupConstants.taskListActionCommandURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
