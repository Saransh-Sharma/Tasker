//
//  HomeTodayRow.swift
//  Tasker
//
//  Mixed due-today agenda row model for Home.
//

import Foundation

public enum HomeSectionAnchor: Equatable, Hashable {
    case project(id: UUID, name: String, iconSystemName: String, isInbox: Bool)
    case lifeArea(id: UUID?, name: String, iconSystemName: String)
    case dueTodaySummary
    case focusNow

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
    public let anchor: HomeSectionAnchor
    public let rows: [HomeTodayRow]
    public let isOverdueSection: Bool

    public init(
        anchor: HomeSectionAnchor,
        rows: [HomeTodayRow],
        isOverdueSection: Bool = false
    ) {
        self.anchor = anchor
        self.rows = rows
        self.isOverdueSection = isOverdueSection
    }

    public var id: String {
        isOverdueSection ? "overdue:\(anchor.id)" : anchor.id
    }

    public var title: String {
        guard isOverdueSection else { return anchor.title }
        return "Overdue · \(anchor.title)"
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
