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

    func isRescueEligibleTask(_ task: TaskDefinition, on referenceDate: Date) -> Bool {
        guard !task.isComplete, let dueDate = task.dueDate else {
            return false
        }

        let anchorDay = Calendar.current.startOfDay(for: referenceDate)
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: anchorDay) else {
            return false
        }
        return dueDate < cutoff
    }

    func isOverdueRescueDeckEligibleTask(_ task: TaskDefinition, on referenceDate: Date) -> Bool {
        guard !task.isComplete, let dueDate = task.dueDate else {
            return false
        }

        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: referenceDate)
        guard dueDate < anchorDay else {
            return false
        }
        if let deferred = task.deferredFromWeekStart, calendar.isDate(deferred, inSameDayAs: anchorDay) {
            return false
        }
        if task.recurrenceSeriesID != nil, dueDate >= anchorDay {
            return false
        }
        return true
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

    func computeFocusWhyShuffleCandidates() -> [TaskDefinition] {
        guard V2FeatureFlags.evaFocusEnabled else { return [] }
        guard activeScope.quickView == .today else { return [] }

        let openTasks = focusOpenTasksForCurrentState()
        let currentFocusIDs = Set(focusTasks.filter { !$0.isComplete }.prefix(Self.maxPinnedFocusTasks).map(\.id))
        guard currentFocusIDs.isEmpty == false else { return [] }

        let candidates = openTasks.filter { !currentFocusIDs.contains($0.id) }
        guard candidates.isEmpty == false else { return [] }

        let excluded = Set(recentShuffledFocusTaskIDs.suffix(shuffleExclusionWindow))
        let preferred = candidates.filter { !excluded.contains($0.id) }
        let effective = preferred.isEmpty ? candidates : preferred
        let ranked = rankedFocusTasks(from: effective, relativeTo: activeScope)
        return Array(ranked.prefix(Self.maxPinnedFocusTasks))
    }

    func focusPriority(for row: HomeTodayRow) -> Int {
        switch row {
        case .task(let task):
            if task.isOverdue { return 0 }
            if task.priority.isHighPriority, task.dueDate != nil { return 3 }
            return 5

        case .habit(let habit):
            if habit.state == .overdue { return 1 }
            if habit.kind == .negative, habit.riskState == .atRisk { return 2 }
            return 4
        }
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
