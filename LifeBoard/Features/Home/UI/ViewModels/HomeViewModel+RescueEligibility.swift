//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

enum OverdueRescueEligibilityPolicy {
    static func isStaleOverdueTask(
        _ task: TaskDefinition,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isComplete, task.parentTaskID == nil, let dueDate = task.dueDate else {
            return false
        }

        let anchorDay = calendar.startOfDay(for: referenceDate)
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: anchorDay) else {
            return false
        }
        return dueDate < cutoff
    }
}

extension HomeViewModel {
    func isRescueEligibleTask(_ task: TaskDefinition, on referenceDate: Date) -> Bool {
        OverdueRescueEligibilityPolicy.isStaleOverdueTask(task, referenceDate: referenceDate)
    }

    func isOverdueRescueDeckEligibleTask(_ task: TaskDefinition, on referenceDate: Date) -> Bool {
        isRescueEligibleTask(task, on: referenceDate)
    }

    func compareRescueRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        let lhsPriority = rescuePriority(for: lhs)
        let rhsPriority = rescuePriority(for: rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func rescuePriority(for row: HomeTodayRow) -> Int {
        switch row {
        case .task(let task):
            return task.priority.scorePoints
        case .habit:
            return 0
        }
    }

    nonisolated static func trackingHomeRows(
        from rows: [HabitLibraryRow],
        historyByHabitID: [UUID: [HabitDayMark]] = [:],
        on date: Date
    ) -> [HomeHabitRow] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return rows.compactMap { row in
            guard !row.isArchived, !row.isPaused, row.trackingMode == .lapseOnly else {
                return nil
            }

            let marks = historyByHabitID[row.habitID] ?? row.last14Days
            let todayMark = marks.first(where: { mark in
                let markDate = calendar.startOfDay(for: mark.date)
                return markDate >= startOfDay && markDate < endOfDay
            })
            let state: HomeHabitRowState
            switch todayMark?.state {
            case .failure:
                state = .lapsedToday
            default:
                state = .tracking
            }

            let compactCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 7,
                calendar: calendar
            )
            let expandedCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 30,
                calendar: calendar
            )

            return HomeHabitRow(
                habitID: row.habitID,
                title: row.title,
                kind: row.kind,
                trackingMode: row.trackingMode,
                lifeAreaID: row.lifeAreaID,
                lifeAreaName: row.lifeAreaName,
                projectID: row.projectID,
                projectName: row.projectName,
                iconSymbolName: row.icon?.symbolName ?? "circle.dashed",
                accentHex: row.colorHex,
                cadence: row.cadence,
                cadenceLabel: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar),
                dueAt: row.nextDueAt,
                state: state,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                last14Days: marks,
                boardCellsCompact: compactCells,
                boardCellsExpanded: expandedCells,
                riskState: todayMark?.state == .failure ? .broken : .stable,
                helperText: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar)
            )
        }
    }

}
