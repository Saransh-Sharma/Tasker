//
//  BuildHomeAgendaUseCase.swift
//  Tasker
//
//  Builds a mixed due-today agenda for Home.
//

import Foundation

public struct HomeAgendaResult: Equatable {
    public let rows: [HomeTodayRow]
    public let taskCount: Int
    public let habitCount: Int

    public init(rows: [HomeTodayRow], taskCount: Int, habitCount: Int) {
        self.rows = rows
        self.taskCount = taskCount
        self.habitCount = habitCount
    }
}

public final class BuildHomeAgendaUseCase {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func execute(
        date: Date,
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow]
    ) -> HomeAgendaResult {
        let anchorDate = calendar.startOfDay(for: date)
        let cutoff = calendar.date(byAdding: .day, value: 1, to: anchorDate) ?? .distantFuture
        let filteredTasks = taskRows.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < cutoff
        }
        let filteredHabits = habitRows.filter { habit in
            guard let dueAt = habit.dueAt else { return false }
            return dueAt < cutoff
        }
        let sortedTasks = filteredTasks.sorted { compareTasks($0, $1, anchorDate: anchorDate) }
        let sortedHabits = filteredHabits.sorted(by: compareHabits(_:_:))

        var agendaRows: [HomeTodayRow] = []
        agendaRows.reserveCapacity(sortedTasks.count + sortedHabits.count)
        agendaRows.append(contentsOf: sortedTasks.map(HomeTodayRow.task))
        agendaRows.append(contentsOf: sortedHabits.map(HomeTodayRow.habit))

        let rows = agendaRows.sorted { lhs, rhs in
            compareRows(lhs, rhs, anchorDate: anchorDate)
        }

        return HomeAgendaResult(
            rows: rows,
            taskCount: sortedTasks.count,
            habitCount: sortedHabits.count
        )
    }

    private func compareRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow, anchorDate: Date) -> Bool {
        let lhsRank = rank(lhs, anchorDate: anchorDate)
        let rhsRank = rank(rhs, anchorDate: anchorDate)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        return lhs.id < rhs.id
    }

    private func rank(_ row: HomeTodayRow, anchorDate: Date) -> Int {
        switch row {
        case .task(let task):
            if isTaskOverdue(task, anchorDate: anchorDate) { return 0 }
            if let dueDate = task.dueDate, calendar.isDate(dueDate, inSameDayAs: anchorDate) {
                return 1
            }
            return 2
        case .habit(let habit):
            switch habit.state {
            case .overdue:
                return 0
            case .due:
                return 1
            case .tracking:
                return 2
            case .completedToday, .lapsedToday, .skippedToday:
                return 2
            }
        }
    }

    private func compareTasks(_ lhs: TaskDefinition, _ rhs: TaskDefinition, anchorDate: Date) -> Bool {
        let lhsOverdue = isTaskOverdue(lhs, anchorDate: anchorDate)
        let rhsOverdue = isTaskOverdue(rhs, anchorDate: anchorDate)
        if lhsOverdue != rhsOverdue {
            return lhsOverdue
        }

        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func compareHabits(_ lhs: HomeHabitRow, _ rhs: HomeHabitRow) -> Bool {
        if lhs.state != rhs.state {
            return rank(lhs.state) < rank(rhs.state)
        }

        let lhsDue = lhs.dueAt ?? .distantFuture
        let rhsDue = rhs.dueAt ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func rank(_ state: HomeHabitRowState) -> Int {
        switch state {
        case .overdue:
            return 0
        case .due:
            return 1
        case .tracking:
            return 2
        case .completedToday:
            return 3
        case .lapsedToday:
            return 4
        case .skippedToday:
            return 5
        }
    }

    private func isTaskOverdue(_ task: TaskDefinition, anchorDate: Date) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < calendar.startOfDay(for: anchorDate)
    }
}
