//
//  ProjectColor.swift
//  LifeBoard
//
//  Project color scheme for visual organization
//

import Foundation

/// Color schemes for projects
public enum ProjectColor: String, CaseIterable, Codable, Sendable {
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
        switch self {
        case .red: return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        case .green: return String(localized: "Green")
        case .blue: return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink: return String(localized: "Pink")
        case .gray: return String(localized: "Gray")
        case .brown: return String(localized: "Brown")
        case .teal: return String(localized: "Teal")
        }
    }

    /// Hex color string for UI representation (platform-agnostic)
    public var hexString: String {
        switch self {
        case .red: return "#C11317"
        case .orange: return "#D97706"
        case .yellow: return "#FEBF2B"
        case .green: return "#293A18"
        case .blue: return "#2F6B9A"
        case .purple: return "#6D4AA3"
        case .pink: return "#B1205F"
        case .gray: return "#7D7A74"
        case .brown: return "#9E5F0A"
        case .teal: return "#147A72"
        }
    }
}

/// Project icons for visual identification
public enum ProjectIcon: String, CaseIterable, Codable, Sendable {
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
        case .folder: return String(localized: "Folder")
        case .inbox: return String(localized: "Inbox")
        case .work: return String(localized: "Work")
        case .personal: return String(localized: "Personal")
        case .health: return String(localized: "Health")
        case .learning: return String(localized: "Learning")
        case .creative: return String(localized: "Creative")
        case .social: return String(localized: "Social")
        case .shopping: return String(localized: "Shopping")
        case .finance: return String(localized: "Finance")
        case .travel: return String(localized: "Travel")
        case .home: return String(localized: "Home")
        case .car: return String(localized: "Car")
        case .sports: return String(localized: "Sports")
        case .music: return String(localized: "Music")
        case .camera: return String(localized: "Camera")
        case .gamecontroller: return String(localized: "Games")
        case .star: return String(localized: "Star")
        case .heartIcon: return String(localized: "Heart")
        case .flag: return String(localized: "Flag")
        }
    }
    
    public var systemImageName: String {
        return rawValue
    }
}

/// Project status lifecycle
public enum ProjectStatus: String, CaseIterable, Codable, Sendable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        switch self {
        case .planning: return String(localized: "Planning")
        case .active: return String(localized: "Active")
        case .onHold: return String(localized: "On hold")
        case .completed: return String(localized: "Completed")
        case .cancelled: return String(localized: "Cancelled")
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
public enum ProjectPriority: Int, CaseIterable, Codable, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    public var displayName: String {
        switch self {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        case .critical: return String(localized: "Critical")
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
public enum ProjectHealth: String, CaseIterable, Codable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .excellent: return String(localized: "Excellent")
        case .good: return String(localized: "Good")
        case .warning: return String(localized: "Warning")
        case .critical: return String(localized: "Critical")
        case .unknown: return String(localized: "Unknown")
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
        case .unknown: return "#000000"
        }
    }
}

/// Project settings and preferences
public struct ProjectSettings: Codable, Equatable, Sendable {
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
public struct ProjectReminderSettings: Codable, Equatable, Sendable {
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
public struct ProjectViewSettings: Codable, Equatable, Sendable {
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
public enum ProjectSortOrder: String, CaseIterable, Codable, Sendable {
    case name = "name"
    case priority = "priority"
    case dueDate = "due_date"
    case createdDate = "created_date"
    case taskCount = "task_count"
    
    public var displayName: String {
        switch self {
        case .name: return String(localized: "Name")
        case .priority: return String(localized: "Priority")
        case .dueDate: return String(localized: "Due date")
        case .createdDate: return String(localized: "Date created")
        case .taskCount: return String(localized: "Task count")
        }
    }
}
