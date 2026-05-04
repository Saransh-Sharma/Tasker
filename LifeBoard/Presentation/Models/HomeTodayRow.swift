//
//  HomeTodayRow.swift
//  LifeBoard
//
//  Mixed due-today agenda row model for Home.
//

import Foundation

public enum HomeSectionAnchor: Equatable, Hashable {
    case project(id: UUID, name: String, iconSystemName: String, isInbox: Bool)
    case lifeArea(id: UUID?, name: String, iconSystemName: String)
    case dueTodaySummary
    case focusNow
    case plainList(id: String)

    public var id: String {
        switch self {
        case .project(let id, _, _, _):
            return "project:\(id.uuidString)"
        case .lifeArea(let id, let name, _):
            if let id {
                return "life_area:\(id.uuidString)"
            }
            return "life_area_name:\(name.lowercased())"
        case .dueTodaySummary:
            return "due_today_summary"
        case .focusNow:
            return "focus_now"
        case .plainList(let id):
            return "plain_list:\(id)"
        }
    }

    public var title: String {
        switch self {
        case .project(_, let name, _, _):
            return name
        case .lifeArea(_, let name, _):
            return name
        case .dueTodaySummary:
            return "Due today"
        case .focusNow:
            return "Focus now"
        case .plainList:
            return ""
        }
    }

    public var iconSystemName: String {
        switch self {
        case .project(_, _, let iconSystemName, _):
            return iconSystemName
        case .lifeArea(_, _, let iconSystemName):
            return iconSystemName
        case .dueTodaySummary:
            return "calendar.badge.clock"
        case .focusNow:
            return "flame.fill"
        case .plainList:
            return "list.bullet"
        }
    }

    public var isInboxProject: Bool {
        if case .project(_, _, _, let isInbox) = self {
            return isInbox
        }
        return false
    }
}

public struct HomeListSection: Equatable, Identifiable {
    public enum DisplayStyle: Equatable {
        case sectioned
        case plain
    }

    public let identifier: String
    public let anchor: HomeSectionAnchor
    public let rows: [HomeTodayRow]
    public let isOverdueSection: Bool
    public let displayStyle: DisplayStyle
    public let accentHex: String?

    public init(
        anchor: HomeSectionAnchor,
        rows: [HomeTodayRow],
        isOverdueSection: Bool = false,
        displayStyle: DisplayStyle = .sectioned,
        identifier: String? = nil,
        accentHex: String? = nil
    ) {
        self.identifier = identifier ?? Self.defaultIdentifier(anchor: anchor, isOverdueSection: isOverdueSection)
        self.anchor = anchor
        self.rows = rows
        self.isOverdueSection = isOverdueSection
        self.displayStyle = displayStyle
        self.accentHex = accentHex
    }

    public var id: String {
        identifier
    }

    public var title: String {
        guard isOverdueSection else { return anchor.title }
        return "Overdue · \(anchor.title)"
    }

    public var showsHeader: Bool {
        displayStyle == .sectioned
    }

    private static func defaultIdentifier(anchor: HomeSectionAnchor, isOverdueSection: Bool) -> String {
        isOverdueSection ? "overdue:\(anchor.id)" : anchor.id
    }
}

public enum HomeTodayRow: Equatable, Identifiable {
    case task(TaskDefinition)
    case habit(HomeHabitRow)

    public var id: String {
        switch self {
        case .task(let task):
            return "task:\(task.id.uuidString)"
        case .habit(let habit):
            return "habit:\(habit.id)"
        }
    }

    public var dueDate: Date? {
        switch self {
        case .task(let task):
            return task.dueDate
        case .habit(let habit):
            return habit.dueAt
        }
    }

    public var isHabit: Bool {
        if case .habit = self { return true }
        return false
    }

    public var title: String {
        switch self {
        case .task(let task):
            return task.title
        case .habit(let habit):
            return habit.title
        }
    }

    public var projectID: UUID? {
        switch self {
        case .task(let task):
            return task.projectID
        case .habit(let habit):
            return habit.projectID
        }
    }

    public var projectName: String? {
        switch self {
        case .task(let task):
            return task.projectName
        case .habit(let habit):
            return habit.projectName
        }
    }

    public var lifeAreaID: UUID? {
        switch self {
        case .task:
            return nil
        case .habit(let habit):
            return habit.lifeAreaID
        }
    }

    public var lifeAreaName: String? {
        switch self {
        case .task:
            return nil
        case .habit(let habit):
            return habit.lifeAreaName
        }
    }

    public var isResolved: Bool {
        switch self {
        case .task(let task):
            return task.isComplete
        case .habit(let habit):
            switch habit.state {
            case .completedToday, .lapsedToday, .skippedToday:
                return true
            case .due, .overdue, .tracking:
                return false
            }
        }
    }

    public var isOverdueLike: Bool {
        switch self {
        case .task(let task):
            return !task.isComplete && task.isOverdue
        case .habit(let habit):
            return habit.state == .overdue
        }
    }

    public var isOpenForFocus: Bool {
        switch self {
        case .task(let task):
            return !task.isComplete
        case .habit(let habit):
            switch habit.state {
            case .due, .overdue:
                return true
            case .completedToday, .lapsedToday, .skippedToday, .tracking:
                return false
            }
        }
    }

    public var isOpenForHomeCount: Bool {
        switch self {
        case .task(let task):
            return !task.isComplete
        case .habit(let habit):
            switch habit.state {
            case .due, .overdue, .tracking:
                return true
            case .completedToday, .lapsedToday, .skippedToday:
                return false
            }
        }
    }
}
