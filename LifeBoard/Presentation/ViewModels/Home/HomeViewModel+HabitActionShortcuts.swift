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

extension HomeViewModel {
    public func completeHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, source: source)
    }

    public func skipHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .skip, source: source)
    }

    public func lapseHabit(_ row: HomeHabitRow, source: String = "habit_row_action") {
        resolveHabit(row, action: .lapsed, source: source)
    }

    public func performHabitLastCellAction(
        _ row: HomeHabitRow,
        source: String = "habit_home_last_cell"
    ) {
        let interaction = HomeHabitLastCellInteraction.resolve(for: row)
        switch interaction.action {
        case .complete:
            completeHabit(row, source: source)
        case .skip:
            skipHabit(row, source: source)
        case .lapse:
            lapseHabit(row, source: source)
        case .clear:
            resetHabit(row, source: source)
        }
    }

    public func logHabitProgress(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: row.kind == .positive ? .complete : .abstained, on: date, source: source)
    }

    public func logHabitLapse(
        _ row: HomeHabitRow,
        on date: Date,
        source: String = "quiet_tracking"
    ) {
        resolveHabit(row, action: .lapsed, on: date, source: source)
    }

    /// Deterministically sets completion to a desired value.

}
