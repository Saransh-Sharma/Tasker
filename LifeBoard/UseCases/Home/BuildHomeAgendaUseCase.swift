//
//  BuildHomeAgendaUseCase.swift
//  LifeBoard
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

public struct BuildHomeAgendaUseCase: Sendable {
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

        var agendaRows: [HomeTodayRow] = []
        agendaRows.reserveCapacity(filteredTasks.count + filteredHabits.count)
        agendaRows.append(contentsOf: filteredTasks.map(HomeTodayRow.task))
        agendaRows.append(contentsOf: filteredHabits.map(HomeTodayRow.habit))

        let rows = agendaRows.sorted { lhs, rhs in
            compareRows(lhs, rhs, anchorDate: anchorDate)
        }

        return HomeAgendaResult(
            rows: rows,
            taskCount: filteredTasks.count,
            habitCount: filteredHabits.count
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
            case .completedToday:
                return 3
            case .lapsedToday:
                return 4
            case .skippedToday:
                return 5
            }
        }
    }

    private func isTaskOverdue(_ task: TaskDefinition, anchorDate: Date) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < anchorDate
    }
}
