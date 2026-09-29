import Foundation

public enum TaskPlanningBucket: String, Codable, CaseIterable, Hashable, Sendable {
    case today
    case thisWeek
    case nextWeek
    case later
    case someday

    public var displayName: String {
        switch self {
        case .today:
            return String(localized: "Today")
        case .thisWeek:
            return String(localized: "This week")
        case .nextWeek:
            return String(localized: "Next week")
        case .later:
            return String(localized: "Later")
        case .someday:
            return String(localized: "Someday")
        }
    }

    public var sortIndex: Int {
        switch self {
        case .today:
            return 0
        case .thisWeek:
            return 1
        case .nextWeek:
            return 2
        case .later:
            return 3
        case .someday:
            return 4
        }
    }

    public var systemImageName: String {
        switch self {
        case .today:
            return "sun.max"
        case .thisWeek:
            return "calendar"
        case .nextWeek:
            return "calendar.badge.plus"
        case .later:
            return "clock.arrow.circlepath"
        case .someday:
            return "archivebox"
        }
    }
}
