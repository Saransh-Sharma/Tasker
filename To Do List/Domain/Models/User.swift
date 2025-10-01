//
//  User.swift
//  Tasker
//
//  Domain model for User - Pure Swift, no framework dependencies
//

import Foundation

/// Pure domain model representing a User
public struct User {
    // MARK: - Properties
    
    public let id: UUID
    public var name: String
    public var email: String
    public var avatarURL: URL?
    public var isActive: Bool
    public var preferences: UserPreferences
    public var dateJoined: Date
    public var lastSeen: Date?
    
    // MARK: - Enhanced Properties
    
    public var timezone: TimeZone
    public var languageCode: String
    public var notificationSettings: NotificationSettings
    public var collaborationLevel: CollaborationLevel
    public var skills: [String]
    public var availability: UserAvailability?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        name: String,
        email: String,
        avatarURL: URL? = nil,
        isActive: Bool = true,
        preferences: UserPreferences = UserPreferences(),
        dateJoined: Date = Date(),
        lastSeen: Date? = nil,
        timezone: TimeZone = TimeZone.current,
        languageCode: String = "en",
        notificationSettings: NotificationSettings = NotificationSettings(),
        collaborationLevel: CollaborationLevel = .member,
        skills: [String] = [],
        availability: UserAvailability? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.isActive = isActive
        self.preferences = preferences
        self.dateJoined = dateJoined
        self.lastSeen = lastSeen
        self.timezone = timezone
        self.languageCode = languageCode
        self.notificationSettings = notificationSettings
        self.collaborationLevel = collaborationLevel
        self.skills = skills
        self.availability = availability
    }
    
    // MARK: - Business Logic
    
    /// Check if user is currently online
    public var isOnline: Bool {
        guard let lastSeen = lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 300 // 5 minutes
    }
    
    /// Get user's display name
    public var displayName: String {
        return name.isEmpty ? email : name
    }
    
    /// Check if user can collaborate on tasks
    public var canCollaborate: Bool {
        return isActive && collaborationLevel != .restricted
    }
    
    /// Get user's initials for avatar fallback
    public var initials: String {
        let components = displayName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0).uppercased() }
        return initials.prefix(2).joined()
    }
    
    // MARK: - Validation
    
    /// Validate the user data
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UserValidationError.emptyName
        }
        
        if name.count > 100 {
            throw UserValidationError.nameTooLong
        }
        
        if !isValidEmail(email) {
            throw UserValidationError.invalidEmail
        }
        
        if email.count > 200 {
            throw UserValidationError.emailTooLong
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}

// MARK: - Supporting Types

public struct UserPreferences {
    public var taskViewStyle: TaskViewStyle
    public var defaultProject: String?
    public var workingHours: WorkingHours
    public var reminderOffset: TimeInterval
    public var autoCompleteSubtasks: Bool
    
    public init(
        taskViewStyle: TaskViewStyle = .list,
        defaultProject: String? = nil,
        workingHours: WorkingHours = WorkingHours(),
        reminderOffset: TimeInterval = 900, // 15 minutes
        autoCompleteSubtasks: Bool = false
    ) {
        self.taskViewStyle = taskViewStyle
        self.defaultProject = defaultProject
        self.workingHours = workingHours
        self.reminderOffset = reminderOffset
        self.autoCompleteSubtasks = autoCompleteSubtasks
    }
}

public struct NotificationSettings {
    public var pushNotificationsEnabled: Bool
    public var emailNotificationsEnabled: Bool
    public var taskReminders: Bool
    public var collaborationUpdates: Bool
    public var achievementNotifications: Bool
    public var quietHours: QuietHours?
    
    public init(
        pushNotificationsEnabled: Bool = true,
        emailNotificationsEnabled: Bool = true,
        taskReminders: Bool = true,
        collaborationUpdates: Bool = true,
        achievementNotifications: Bool = true,
        quietHours: QuietHours? = nil
    ) {
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.emailNotificationsEnabled = emailNotificationsEnabled
        self.taskReminders = taskReminders
        self.collaborationUpdates = collaborationUpdates
        self.achievementNotifications = achievementNotifications
        self.quietHours = quietHours
    }
}

public struct WorkingHours {
    public var startTime: Date
    public var endTime: Date
    public var workDays: Set<Weekday>
    
    public init(
        startTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
        endTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date(),
        workDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.workDays = workDays
    }
}

public struct QuietHours {
    public var startTime: Date
    public var endTime: Date
    public var enabled: Bool
    
    public init(
        startTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date(),
        endTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
        enabled: Bool = false
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.enabled = enabled
    }
}

public struct UserAvailability {
    public var status: AvailabilityStatus
    public var message: String?
    public var until: Date?
    
    public init(
        status: AvailabilityStatus = .available,
        message: String? = nil,
        until: Date? = nil
    ) {
        self.status = status
        self.message = message
        self.until = until
    }
}

// MARK: - Enums

public enum TaskViewStyle: String, CaseIterable {
    case list = "list"
    case grid = "grid"
    case kanban = "kanban"
    case calendar = "calendar"
}

public enum CollaborationLevel: String, CaseIterable {
    case admin = "admin"
    case moderator = "moderator"
    case member = "member"
    case viewer = "viewer"
    case restricted = "restricted"
    
    public var displayName: String {
        switch self {
        case .admin: return "Administrator"
        case .moderator: return "Moderator"
        case .member: return "Member"
        case .viewer: return "Viewer"
        case .restricted: return "Restricted"
        }
    }
    
    public var permissions: [Permission] {
        switch self {
        case .admin:
            return [.read, .write, .delete, .share, .manage]
        case .moderator:
            return [.read, .write, .delete, .share]
        case .member:
            return [.read, .write, .share]
        case .viewer:
            return [.read]
        case .restricted:
            return []
        }
    }
}

public enum AvailabilityStatus: String, CaseIterable {
    case available = "available"
    case busy = "busy"
    case away = "away"
    case doNotDisturb = "do_not_disturb"
    case offline = "offline"
    
    public var displayName: String {
        switch self {
        case .available: return "Available"
        case .busy: return "Busy"
        case .away: return "Away"
        case .doNotDisturb: return "Do Not Disturb"
        case .offline: return "Offline"
        }
    }
}

public enum Weekday: String, CaseIterable {
    case sunday = "sunday"
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    
    public var number: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

public enum Permission: String, CaseIterable {
    case read = "read"
    case write = "write"
    case delete = "delete"
    case share = "share"
    case manage = "manage"
}

// MARK: - Validation Errors

public enum UserValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case invalidEmail
    case emailTooLong
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "User name cannot be empty"
        case .nameTooLong:
            return "User name cannot exceed 100 characters"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .emailTooLong:
            return "Email address cannot exceed 200 characters"
        }
    }
}

// MARK: - Equatable

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension User: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}