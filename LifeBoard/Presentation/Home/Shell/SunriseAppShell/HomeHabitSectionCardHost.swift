//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct HomeHabitSectionCardHost: View, Equatable {
    let title: String
    let summaryLine: String
    let rows: [HomeHabitRow]
    let accessibilityIdentifier: String
    let onOpenBoard: () -> Void
    let onPrimaryAction: (HomeHabitRow) -> Void
    let onSecondaryAction: (HomeHabitRow) -> Void
    let onRowAction: (HomeHabitRow) -> Void
    let onLastCellAction: (HomeHabitRow) -> Void
    let onOpenHabit: (HomeHabitRow) -> Void
    let showsAddHabitCTA: Bool
    let onAddHabit: (() -> Void)?

    nonisolated static func == (lhs: HomeHabitSectionCardHost, rhs: HomeHabitSectionCardHost) -> Bool {
        lhs.title == rhs.title
            && lhs.summaryLine == rhs.summaryLine
            && lhs.rows == rhs.rows
            && lhs.accessibilityIdentifier == rhs.accessibilityIdentifier
            && lhs.showsAddHabitCTA == rhs.showsAddHabitCTA
    }

    var body: some View {
        let _ = HomePerformanceSignposts.habitsSectionRendered(rowCount: rows.count)
        return HabitHomeSectionCard(
            title: title,
            summaryLine: summaryLine,
            rows: rows,
            onOpenBoard: onOpenBoard,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onSecondaryAction,
            onRowAction: onRowAction,
            onLastCellAction: onLastCellAction,
            onOpenHabit: onOpenHabit,
            onAddHabit: showsAddHabitCTA ? onAddHabit : nil
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
