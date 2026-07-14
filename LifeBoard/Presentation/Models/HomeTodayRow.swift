//
//  HomeTodayRow.swift
//  LifeBoard
//
//  Mixed due-today agenda row model for Home.
//

import Foundation

/// Forward time-horizon buckets used by the Home "stream" lenses (Upcoming and per-project).
/// Tasks are grouped relative to today so the user can see what is overdue, due now, and
/// scheduled further out without losing undated work.
public enum HomeHorizonBucket: String, CaseIterable, Equatable, Hashable, Sendable {
    case overdue
    case today
    case thisWeek
    case nextWeek
    case later
    case someday

    public var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .nextWeek: return "Next week"
        case .later: return "Later"
        case .someday: return "Someday"
        }
    }

    public var iconSystemName: String {
        switch self {
        case .overdue: return "exclamationmark.circle"
        case .today: return "sun.max"
        case .thisWeek: return "calendar"
        case .nextWeek: return "calendar.badge.clock"
        case .later: return "arrow.up.right"
        case .someday: return "tray"
        }
    }

    /// Stable display order for sections.
    public var sortIndex: Int {
        switch self {
        case .overdue: return 0
        case .today: return 1
        case .thisWeek: return 2
        case .nextWeek: return 3
        case .later: return 4
        case .someday: return 5
        }
    }

    /// Calm, non-punitive accent hex per the Sunrise Glass palette.
    /// Overdue uses warm peach (never red) for recovery framing.
    public var accentHex: String {
        switch self {
        case .overdue: return "#FF7A3D"
        case .today: return "#FFB300"
        case .thisWeek: return "#28B53F"
        case .nextWeek: return "#2F8CFF"
        case .later: return "#6842FF"
        case .someday: return "#7A8BA5"
        }
    }
}

public enum HomeSectionAnchor: Equatable, Hashable {
    case project(id: UUID, name: String, iconSystemName: String, isInbox: Bool)
    case lifeArea(id: UUID?, name: String, iconSystemName: String)
    case horizon(bucket: HomeHorizonBucket)
    case horizonProject(horizon: HomeHorizonBucket, projectID: UUID, name: String, iconSystemName: String)
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
        case .horizon(let bucket):
            return "horizon:\(bucket.rawValue)"
        case .horizonProject(let horizon, let projectID, _, _):
            return "horizon:\(horizon.rawValue):project:\(projectID.uuidString)"
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
        case .horizon(let bucket):
            return bucket.title
        case .horizonProject(let horizon, _, let name, _):
            return "\(horizon.title) · \(name)"
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
        case .horizon(let bucket):
            return bucket.iconSystemName
        case .horizonProject(_, _, _, let iconSystemName):
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

// MARK: - Home lenses

/// Home "lens" switcher model: Today (timeline) vs forward streams (Upcoming / per-life-area).
public enum HomeLens: Equatable, Identifiable, Sendable {
    case today
    case upcoming
    case lifeArea(UUID)

    public var id: String {
        switch self {
        case .today: return "lens.today"
        case .upcoming: return "lens.upcoming"
        case .lifeArea(let lifeAreaID): return "lens.lifeArea.\(lifeAreaID.uuidString)"
        }
    }
}

/// A renderable lens chip for the Home lens row.
public struct HomeLensChip: Identifiable, Equatable {
    public let lens: HomeLens
    public let title: String
    public let systemImage: String
    public let isSelected: Bool
    /// Optional identity color (hex) for life-area lenses. Drives the leading dot.
    public let tintHex: String?

    public var id: String { lens.id }

    public init(lens: HomeLens, title: String, systemImage: String, isSelected: Bool, tintHex: String? = nil) {
        self.lens = lens
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.tintHex = tintHex
    }
}

/// Calm life-area-lens header shown in the date hero subtitle while a life-area lens is active.
public struct LifeAreaLensHeader: Equatable, Sendable {
    public let lifeAreaName: String
    public let openCount: Int
    public let nextDueDate: Date?

    public init(lifeAreaName: String, openCount: Int, nextDueDate: Date?) {
        self.lifeAreaName = lifeAreaName
        self.openCount = openCount
        self.nextDueDate = nextDueDate
    }

    public func subtitle(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        var parts: [String] = [lifeAreaName]
        parts.append(openCount == 0 ? "all caught up" : "\(openCount) open")
        if let due = nextDueDate {
            parts.append("next due \(Self.relativeDueText(due, referenceDate: referenceDate, calendar: calendar))")
        }
        return parts.joined(separator: " · ")
    }

    static func relativeDueText(_ due: Date, referenceDate: Date, calendar: Calendar) -> String {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfDue = calendar.startOfDay(for: due)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
        if days < 0 { return "overdue" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        if days < 7 {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            return formatter.string(from: due)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: due)
    }
}

/// Per-life-area signal used to auto-fill the lens row beyond pinned life areas.
public struct HomeLensLifeAreaActivity: Equatable, Sendable {
    public let openCount: Int
    public let nearestDue: Date?

    public init(openCount: Int, nearestDue: Date?) {
        self.openCount = openCount
        self.nearestDue = nearestDue
    }
}

public enum HomeLensResolver {
    public static func activeLens(for filterState: HomeFilterState) -> HomeLens {
        guard filterState.streamsAllForward else { return .today }
        if let lifeAreaID = filterState.selectedLifeAreaIDs.first {
            return .lifeArea(lifeAreaID)
        }
        return .upcoming
    }

    public static func lifeAreaLenses(
        lifeAreas: [LifeArea],
        pinnedLifeAreaIDs: [UUID],
        activeLens: HomeLens,
        activityByID: [UUID: HomeLensLifeAreaActivity]? = nil
    ) -> [HomeLensChip] {
        let selectable = lifeAreas.filter { !$0.isArchived }
        let byID = Dictionary(uniqueKeysWithValues: selectable.map { ($0.id, $0) })

        var orderedIDs: [UUID] = []
        func append(_ id: UUID) {
            guard byID[id] != nil, orderedIDs.contains(id) == false else { return }
            orderedIDs.append(id)
        }

        pinnedLifeAreaIDs.forEach(append)

        let remaining = selectable.filter { orderedIDs.contains($0.id) == false }
        let autoFilled: [LifeArea]
        if let activityByID {
            autoFilled = remaining.sorted { lhs, rhs in
                rankByActivity(lhs, rhs, activityByID: activityByID)
            }
        } else {
            autoFilled = remaining.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        autoFilled.forEach { append($0.id) }

        if let activityByID {
            orderedIDs = orderedIDs.filter { id in
                (activityByID[id]?.openCount ?? 0) > 0
            }
        }

        if case .lifeArea(let activeID) = activeLens,
           byID[activeID] != nil,
           orderedIDs.contains(activeID) == false {
            orderedIDs.insert(activeID, at: 0)
        }

        return orderedIDs.compactMap { id in
            guard let area = byID[id] else { return nil }
            let tintHex = LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id)
            return HomeLensChip(
                lens: .lifeArea(area.id),
                title: area.name,
                systemImage: area.icon ?? "square.grid.2x2",
                isSelected: activeLens == .lifeArea(area.id),
                tintHex: tintHex
            )
        }
    }

    private static func rankByActivity(
        _ lhs: LifeArea,
        _ rhs: LifeArea,
        activityByID: [UUID: HomeLensLifeAreaActivity]
    ) -> Bool {
        let lhsActivity = activityByID[lhs.id]
        let rhsActivity = activityByID[rhs.id]
        let lhsDue = lhsActivity?.nearestDue
        let rhsDue = rhsActivity?.nearestDue

        switch (lhsDue, rhsDue) {
        case let (l?, r?) where l != r:
            return l < r
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }

        let lhsOpen = lhsActivity?.openCount ?? 0
        let rhsOpen = rhsActivity?.openCount ?? 0
        if lhsOpen != rhsOpen {
            return lhsOpen > rhsOpen
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
