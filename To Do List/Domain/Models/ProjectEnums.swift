//
//  ProjectColor.swift
//  Tasker
//
//  Project color scheme for visual organization
//

import Foundation

/// Color schemes for projects
public enum ProjectColor: String, CaseIterable, Codable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case gray = "gray"
    case brown = "brown"
    case teal = "teal"

    public var displayName: String {
        return rawValue.capitalized
    }

    /// Hex color string for UI representation (platform-agnostic)
    public var hexString: String {
        switch self {
        case .red: return "#C11317"
        case .orange: return "#9E5F0A"
        case .yellow: return "#FEBF2B"
        case .green: return "#293A18"
        case .blue: return "#B1205F"
        case .purple: return "#B1205F"
        case .pink: return "#B1205F"
        case .gray: return "#8E7151"
        case .brown: return "#9E5F0A"
        case .teal: return "#293A18"
        }
    }
}

/// Project icons for visual identification
public enum ProjectIcon: String, CaseIterable, Codable {
    case folder = "folder"
    case inbox = "tray"
    case work = "briefcase"
    case personal = "person"
    case health = "heart.fill"
    case learning = "book"
    case creative = "paintbrush"
    case social = "person.2"
    case shopping = "cart"
    case finance = "dollarsign.circle"
    case travel = "airplane"
    case home = "house"
    case car = "car"
    case sports = "sportscourt"
    case music = "music.note"
    case camera = "camera"
    case gamecontroller = "gamecontroller"
    case star = "star"
    case heartIcon = "heart"  // Renamed to avoid conflict
    case flag = "flag"
    
    public var displayName: String {
        switch self {
        case .folder: return "Folder"
        case .inbox: return "Inbox"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health"
        case .learning: return "Learning"
        case .creative: return "Creative"
        case .social: return "Social"
        case .shopping: return "Shopping"
        case .finance: return "Finance"
        case .travel: return "Travel"
        case .home: return "Home"
        case .car: return "Car"
        case .sports: return "Sports"
        case .music: return "Music"
        case .camera: return "Camera"
        case .gamecontroller: return "Games"
        case .star: return "Star"
        case .heartIcon: return "Heart"
        case .flag: return "Flag"
        }
    }
    
    public var systemImageName: String {
        return rawValue
    }
}

/// Project status lifecycle
public enum ProjectStatus: String, CaseIterable, Codable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    public var emoji: String {
        switch self {
        case .planning: return "🔄"
        case .active: return "✅"
        case .onHold: return "⏸️"
        case .completed: return "🎉"
        case .cancelled: return "❌"
        }
    }
    
    public var isActive: Bool {
        return self == .active || self == .planning
    }
}

/// Project priority levels
public enum ProjectPriority: Int, CaseIterable, Codable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var emoji: String {
        switch self {
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        }
    }
    
    public var sortOrder: Int {
        return rawValue
    }
}

/// Project health status
public enum ProjectHealth: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }
    
    public var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .warning: return "🟠"
        case .critical: return "🔴"
        case .unknown: return "⚫"
        }
    }

    /// Hex color string for UI representation (platform-agnostic)
    public var colorHex: String {
        switch self {
        case .excellent: return "#293A18"
        case .good: return "#FEBF2B"
        case .warning: return "#9E5F0A"
        case .critical: return "#C11317"
        case .unknown: return "#8E7151"
        }
    }
}

/// Project settings and preferences
public struct ProjectSettings: Codable, Equatable {
    public var autoArchiveCompletedTasks: Bool
    public var defaultTaskPriority: TaskPriority
    public var defaultTaskType: TaskType
    public var allowSubprojects: Bool
    public var taskNumberingEnabled: Bool
    public var reminderSettings: ProjectReminderSettings
    public var viewSettings: ProjectViewSettings
    
    /// Initializes a new instance.
    public init(
        autoArchiveCompletedTasks: Bool = false,
        defaultTaskPriority: TaskPriority = .low,  // Use .low instead of .medium
        defaultTaskType: TaskType = .morning,
        allowSubprojects: Bool = true,
        taskNumberingEnabled: Bool = false,
        reminderSettings: ProjectReminderSettings = ProjectReminderSettings(),
        viewSettings: ProjectViewSettings = ProjectViewSettings()
    ) {
        self.autoArchiveCompletedTasks = autoArchiveCompletedTasks
        self.defaultTaskPriority = defaultTaskPriority
        self.defaultTaskType = defaultTaskType
        self.allowSubprojects = allowSubprojects
        self.taskNumberingEnabled = taskNumberingEnabled
        self.reminderSettings = reminderSettings
        self.viewSettings = viewSettings
    }
}

/// Project reminder settings
public struct ProjectReminderSettings: Codable, Equatable {
    public var enableDueDateReminders: Bool
    public var reminderOffsetDays: Int
    public var enableDailyDigest: Bool
    public var digestTime: String // HH:mm format
    
    /// Initializes a new instance.
    public init(
        enableDueDateReminders: Bool = true,
        reminderOffsetDays: Int = 1,
        enableDailyDigest: Bool = false,
        digestTime: String = "09:00"
    ) {
        self.enableDueDateReminders = enableDueDateReminders
        self.reminderOffsetDays = reminderOffsetDays
        self.enableDailyDigest = enableDailyDigest
        self.digestTime = digestTime
    }
}

/// Project view settings
public struct ProjectViewSettings: Codable, Equatable {
    public var defaultSortOrder: ProjectSortOrder
    public var showCompletedTasks: Bool
    public var groupTasksByDate: Bool
    public var showTaskCount: Bool
    
    /// Initializes a new instance.
    public init(
        defaultSortOrder: ProjectSortOrder = .priority,
        showCompletedTasks: Bool = true,
        groupTasksByDate: Bool = true,
        showTaskCount: Bool = true
    ) {
        self.defaultSortOrder = defaultSortOrder
        self.showCompletedTasks = showCompletedTasks
        self.groupTasksByDate = groupTasksByDate
        self.showTaskCount = showTaskCount
    }
}

/// Project sort orders
public enum ProjectSortOrder: String, CaseIterable, Codable {
    case name = "name"
    case priority = "priority"
    case dueDate = "due_date"
    case createdDate = "created_date"
    case taskCount = "task_count"
    
    public var displayName: String {
        switch self {
        case .name: return "Name"
        case .priority: return "Priority"
        case .dueDate: return "Due Date"
        case .createdDate: return "Created Date"
        case .taskCount: return "Task Count"
        }
    }
}
