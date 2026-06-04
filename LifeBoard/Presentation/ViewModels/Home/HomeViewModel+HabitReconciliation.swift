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
    func reconcileHabitMutation(
        habitID: UUID,
        on date: Date
    ) {
        let interval = LifeBoardPerformanceTrace.begin("HomeHabitRowReconcile")
        fetchCanonicalHabitMutationState(habitID: habitID, on: date) { [weak self] result in
            Task { @MainActor in
                defer { LifeBoardPerformanceTrace.end(interval) }
                guard let self else { return }
                guard Calendar.current.isDate(date, inSameDayAs: self.selectedDate) else { return }

                switch result {
                case .failure(let error):
                    logWarning(
                        event: "home_habit_reconcile_failed",
                        message: "Failed to reconcile canonical habit state after mutation",
                        fields: [
                            "habit_id": habitID.uuidString,
                            "error": error.localizedDescription
                        ]
                    )

                case .success(let canonicalState):
                    let patch = self.buildHabitMutationSectionPatch(
                        habitID: habitID,
                        canonicalRow: canonicalState.row
                    )

                    self.performHomeRenderStateBatch {
                        self.applyHabitMutationSectionPatch(patch)
                    }

                    if let libraryRow = canonicalState.libraryRow {
                        self.habitLibraryRowsByID[habitID] = libraryRow
                    } else {
                        self.habitLibraryRowsByID.removeValue(forKey: habitID)
                    }

                    LifeBoardPerformanceTrace.event("HomeUserMutationRecomputedRows", value: patch.affectedRowCount)
                    LifeBoardPerformanceTrace.event("HomeUserMutationRecomputedSections", value: patch.affectedSectionCount)
                    logDebug(
                        "HOME_HABIT_STATE vm.reconcile_apply id=\(habitID.uuidString) " +
                        "rows=\(patch.affectedRowCount) sections=\(patch.affectedSectionCount)"
                    )
                }
            }
        }
    }

    func habitSignals(from rows: [HomeHabitRow]) -> [LifeBoardHabitSignal] {
        rows.map { row in
            LifeBoardHabitSignal(
                habitID: row.habitID,
                title: row.title,
                isPositive: row.kind == .positive,
                trackingModeRaw: row.trackingMode.rawValue,
                lifeAreaName: row.lifeAreaName,
                projectName: row.projectName,
                iconSymbolName: row.iconSymbolName,
                iconCategoryKey: nil,
                dueAt: row.dueAt,
                isDueToday: row.state == .due,
                isOverdue: row.state == .overdue,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                riskStateRaw: row.riskState.rawValue,
                outcomeRaw: habitOutcomeRaw(for: row.state),
                occurredAt: row.dueAt,
                keywords: [row.title, row.lifeAreaName, row.projectName].compactMap { $0 },
                last14Days: row.last14Days,
                colorHex: row.accentHex,
                cadence: row.cadence
            )
        }
    }

    func habitOutcomeRaw(for state: HomeHabitRowState) -> String? {
        switch state {
        case .completedToday:
            return "completed"
        case .lapsedToday:
            return "lapsed"
        case .skippedToday:
            return "skipped"
        case .overdue:
            return "missed"
        case .due, .tracking:
            return nil
        }
    }

    func mergeHabitRows(
        agenda: [HomeHabitRow],
        tracking: [HomeHabitRow]
    ) -> [HomeHabitRow] {
        var merged: [String: HomeHabitRow] = [:]
        for row in agenda {
            merged[row.id] = row
        }
        for row in tracking where merged[row.id] == nil {
            merged[row.id] = row
        }
        return merged.values.sorted { lhs, rhs in
            if lhs.projectName != rhs.projectName {
                return (lhs.projectName ?? lhs.lifeAreaName).localizedCaseInsensitiveCompare(rhs.projectName ?? rhs.lifeAreaName) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func sortHabitRows(_ rows: [HomeHabitRow]) -> [HomeHabitRow] {
        rows.sorted { lhs, rhs in
            if lhs.projectName != rhs.projectName {
                return (lhs.projectName ?? lhs.lifeAreaName).localizedCaseInsensitiveCompare(rhs.projectName ?? rhs.lifeAreaName) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func includeHabitInAgenda(_ row: HomeHabitRow) -> Bool {
        switch row.state {
        case .overdue:
            return true
        case .due:
            if row.kind == .positive {
                return true
            }
            return row.riskState != .stable
        case .tracking:
            return false
        case .completedToday, .lapsedToday, .skippedToday:
            return false
        }
    }

    func isStableQuietTrackingRow(_ row: HomeHabitRow) -> Bool {
        row.trackingMode == .lapseOnly
            && row.state == .tracking
            && row.riskState == .stable
    }

    func buildAgendaTailItems(
        rescueEligibleTasks: [TaskDefinition]
    ) -> [HomeAgendaTailItem] {
        guard activeScope.quickView == .today, V2FeatureFlags.evaRescueEnabled else {
            return []
        }

        let rows = rescueEligibleTasks
            .map(HomeTodayRow.task)
            .sorted(by: compareRescueRows(_:_:))
        guard rows.isEmpty == false else {
            return []
        }

        let mode: RescueTailMode = rows.count <= 3 ? .compact : .expanded
        let subtitle: String
        if rows.count == 1 {
            subtitle = "1 task is 2+ weeks overdue"
        } else {
            subtitle = "\(rows.count) tasks are 2+ weeks overdue"
        }

        return [
            .rescue(
                RescueTailState(
                    rows: rows,
                    mode: mode,
                    isInlineExpanded: mode == .expanded,
                    subtitle: subtitle
                )
            )
        ]
    }

    func composeFocusRows(
        taskRows: [TaskDefinition],
        habitRows: [HomeHabitRow]
    ) -> [HomeTodayRow] {
        let openTasks = taskRows.filter { !$0.isComplete }
        let openTaskByID = Dictionary(uniqueKeysWithValues: openTasks.map { ($0.id, $0) })
        let pinnedTaskRows = pinnedFocusTaskIDs.compactMap { openTaskByID[$0] }.map(HomeTodayRow.task)
        let pinnedTaskIDs = Set(pinnedTaskRows.compactMap { row -> UUID? in
            if case .task(let task) = row { return task.id }
            return nil
        })

        let rankedTaskRows = rankedFocusTasks(
            from: openTasks.filter { !pinnedTaskIDs.contains($0.id) },
            relativeTo: activeScope
        ).map(HomeTodayRow.task)

        var results = pinnedTaskRows
        for row in rankedTaskRows where results.count < Self.maxPinnedFocusTasks && !results.contains(where: { $0.id == row.id }) {
            results.append(row)
        }

        if results.isEmpty {
            for row in habitFocusFallbackRows(from: habitRows) where results.count < 1 {
                results.append(row)
            }
        }

        return Array(results.prefix(Self.maxPinnedFocusTasks))
    }

    func compareFocusRows(_ lhs: HomeTodayRow, _ rhs: HomeTodayRow) -> Bool {
        let lhsRank = focusPriority(for: lhs)
        let rhsRank = focusPriority(for: rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        let lhsDue = lhs.dueDate ?? Date.distantFuture
        let rhsDue = rhs.dueDate ?? Date.distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func updateFocusSelection(_ tasks: [TaskDefinition]) {
        let limitedTasks = Array(tasks.prefix(Self.maxPinnedFocusTasks))
        assignIfChanged(\.focusTasks, limitedTasks)
        let rows = limitedTasks.map(HomeTodayRow.task)
        assignIfChanged(\.focusRows, rows)
        assignIfChanged(
            \.focusNowSectionState,
            FocusNowSectionState(rows: rows, pinnedTaskIDs: pinnedFocusTaskIDs)
        )

        refreshFocusWhyCandidatesIfPresented()
    }

    func resolveHabit(
        _ row: HomeHabitRow,
        action: HabitOccurrenceAction,
        source: String
    ) {
        resolveHabit(row, action: action, on: selectedDate, source: source)
    }

    func resolveHabit(
        _ row: HomeHabitRow,
        action: HabitOccurrenceAction,
        on date: Date,
        source: String
    ) {
        performHabitMutation(
            row,
            request: .resolve(action),
            on: date,
            source: source
        )
    }
}
