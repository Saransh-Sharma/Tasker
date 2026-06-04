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
    func patchDueTodaySection(
        rows: [HomeTodayRow]
    ) -> HomeListSection? {
        dueTodaySection.map { section in
            HomeListSection(
                anchor: section.anchor,
                rows: rows,
                isOverdueSection: section.isOverdueSection,
                accentHex: section.accentHex
            )
        }
    }

    func patchCurrentHabitSignals(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> [LifeBoardHabitSignal] {
        var signals = currentHabitSignals
        if let index = signals.firstIndex(where: { $0.habitID == habitID }) {
            if let canonicalRow {
                signals[index] = habitSignals(from: [canonicalRow])[0]
            } else {
                signals.remove(at: index)
            }
            return signals
        }

        guard let canonicalRow else { return signals }
        signals.append(habitSignals(from: [canonicalRow])[0])
        return signals
    }

    func buildHabitMutationSectionPatch(
        habitID: UUID,
        canonicalRow: HomeHabitRow?
    ) -> HomeHabitMutationSectionPatch {
        let replacement = replacingHabitRow(habitID: habitID, with: canonicalRow)
        let allHabitRows = replacement.primary + replacement.recovery + replacement.quiet
        let agendaRows = patchAgendaRowsForHabitMutation(
            habitID: habitID,
            canonicalRow: canonicalRow
        )
        let updatedDueTodaySection = patchDueTodaySection(rows: agendaRows)

        let updatedFocusRows: [HomeTodayRow]?
        let updatedFocusNowSectionState: FocusNowSectionState?
        if shouldRecomputeHabitFocusFallback(for: habitID) {
            let focusRows = habitFocusFallbackRows(from: allHabitRows)
            updatedFocusRows = focusRows
            updatedFocusNowSectionState = FocusNowSectionState(
                rows: focusRows,
                pinnedTaskIDs: pinnedFocusTaskIDs
            )
        } else {
            updatedFocusRows = nil
            updatedFocusNowSectionState = nil
        }

        return HomeHabitMutationSectionPatch(
            allHabitRows: allHabitRows,
            dueTodayRows: agendaRows,
            dueTodaySection: updatedDueTodaySection,
            habitHomeSectionState: HabitHomeSectionState(
                primaryRows: replacement.primary,
                recoveryRows: replacement.recovery
            ),
            quietTrackingSummaryState: QuietTrackingSummaryState(stableRows: replacement.quiet),
            focusRows: updatedFocusRows,
            focusNowSectionState: updatedFocusNowSectionState,
            currentHabitSignals: patchCurrentHabitSignals(
                habitID: habitID,
                canonicalRow: canonicalRow
            ),
            affectedRowCount: 1 + (updatedFocusRows?.count ?? 0),
            affectedSectionCount: 1 + (updatedFocusRows == nil ? 0 : 1)
        )
    }

    func applyHabitMutationSectionPatch(_ patch: HomeHabitMutationSectionPatch) {
        assignForHabitMutation(\.dueTodayRows, patch.dueTodayRows)
        assignForHabitMutation(\.dueTodaySection, patch.dueTodaySection)
        assignForHabitMutation(\.habitHomeSectionState, patch.habitHomeSectionState)
        assignForHabitMutation(\.quietTrackingSummaryState, patch.quietTrackingSummaryState)
        if let focusRows = patch.focusRows {
            assignForHabitMutation(\.focusRows, focusRows)
        }
        if let focusNowSectionState = patch.focusNowSectionState {
            assignForHabitMutation(\.focusNowSectionState, focusNowSectionState)
        }
        currentHabitSignals = patch.currentHabitSignals
    }

    func habitFocusFallbackRows(from habitRows: [HomeHabitRow]) -> [HomeTodayRow] {
        let highPriorityHabits = habitRows
            .filter(isEligibleForHabitFocusFallback(_:))
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state == .overdue
                }
                let lhsDue = lhs.dueAt ?? .distantFuture
                let rhsDue = rhs.dueAt ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return compareFocusRows(.habit(lhs), .habit(rhs))
            }
            .map(HomeTodayRow.habit)

        return Array(highPriorityHabits.prefix(1))
    }

    func optimisticHabitRow(
        from row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HomeHabitRow? {
        let optimisticDayState = optimisticHabitDayState(for: request)
        let referenceDate = Calendar.current.startOfDay(for: date)
        let marks = optimisticallyPatchedHabitDayMarks(
            from: row.last14Days,
            dayState: optimisticDayState,
            on: referenceDate
        )
        let compactCells = optimisticallyPatchedBoardCells(
            from: row.boardCellsCompact,
            marks: marks,
            cadence: row.cadence,
            referenceDate: referenceDate,
            fallbackDayCount: 7
        )
        let expandedCells = optimisticallyPatchedBoardCells(
            from: row.boardCellsExpanded,
            marks: marks,
            cadence: row.cadence,
            referenceDate: referenceDate,
            fallbackDayCount: 30
        )
        let metrics = HabitBoardPresentationBuilder.metrics(for: expandedCells)
        let occurrenceState = optimisticOccurrenceState(for: request)
        let state = optimisticHomeHabitState(
            for: row,
            request: request,
            on: referenceDate
        )
        let riskState = HabitRuntimeSupport.riskState(
            for: marks,
            dueAt: row.dueAt,
            occurrenceState: occurrenceState,
            referenceDate: referenceDate
        )

        return HomeHabitRow(
            habitID: row.habitID,
            occurrenceID: row.occurrenceID,
            title: row.title,
            kind: row.kind,
            trackingMode: row.trackingMode,
            lifeAreaID: row.lifeAreaID,
            lifeAreaName: row.lifeAreaName,
            projectID: row.projectID,
            projectName: row.projectName,
            iconSymbolName: row.iconSymbolName,
            accentHex: row.accentHex,
            cadence: row.cadence,
            cadenceLabel: row.cadenceLabel,
            dueAt: row.dueAt,
            state: state,
            currentStreak: metrics.currentStreak,
            bestStreak: max(row.bestStreak, metrics.bestStreak),
            last14Days: marks,
            boardCellsCompact: compactCells,
            boardCellsExpanded: expandedCells,
            riskState: riskState,
            helperText: row.helperText
        )
    }

    func optimisticHabitDayState(for request: HomeHabitMutationRequest) -> HabitDayState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .success
        case .resolve(.skip):
            return .skipped
        case .resolve(.lapsed):
            return .failure
        case .reset:
            return .none
        }
    }

    func optimisticOccurrenceState(for request: HomeHabitMutationRequest) -> OccurrenceState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .completed
        case .resolve(.skip):
            return .skipped
        case .resolve(.lapsed):
            return .failed
        case .reset:
            return .pending
        }
    }

    func optimisticHomeHabitState(
        for row: HomeHabitRow,
        request: HomeHabitMutationRequest,
        on date: Date
    ) -> HomeHabitRowState {
        switch request {
        case .resolve(.complete), .resolve(.abstained):
            return .completedToday
        case .resolve(.skip):
            return .skippedToday
        case .resolve(.lapsed):
            return .lapsedToday
        case .reset:
            if row.trackingMode == .lapseOnly {
                return .tracking
            }
            if let dueAt = row.dueAt, dueAt < Calendar.current.startOfDay(for: date) {
                return .overdue
            }
            return .due
        }
    }

    func optimisticallyPatchedHabitDayMarks(
        from existingMarks: [HabitDayMark],
        dayState: HabitDayState,
        on date: Date
    ) -> [HabitDayMark] {
        var marks = existingMarks
        if marks.isEmpty {
            marks = HabitRuntimeSupport.dayMarks(
                from: [],
                endingOn: date,
                dayCount: 30
            )
        }

        let day = Calendar.current.startOfDay(for: date)
        if let index = marks.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            marks[index] = HabitDayMark(date: marks[index].date, state: dayState)
        } else {
            marks.append(HabitDayMark(date: day, state: dayState))
            marks.sort { $0.date < $1.date }
        }
        return marks
    }

    func optimisticallyPatchedBoardCells(
        from existingCells: [HabitBoardCell],
        marks: [HabitDayMark],
        cadence: HabitCadenceDraft,
        referenceDate: Date,
        fallbackDayCount: Int
    ) -> [HabitBoardCell] {
        let calendar = Calendar.current
        let resolvedCells: [HabitBoardCell]
        if existingCells.isEmpty {
            resolvedCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: cadence,
                referenceDate: referenceDate,
                dayCount: fallbackDayCount,
                calendar: calendar
            )
        } else {
            let marksByDay = Dictionary(uniqueKeysWithValues: marks.map {
                (calendar.startOfDay(for: $0.date), $0)
            })
            let referenceDay = calendar.startOfDay(for: referenceDate)
            let patched = existingCells.map { cell in
                let day = calendar.startOfDay(for: cell.date)
                return HabitBoardCell(
                    date: day,
                    state: optimisticBoardCellState(
                        on: day,
                        marksByDay: marksByDay,
                        cadence: cadence,
                        referenceDay: referenceDay,
                        calendar: calendar
                    ),
                    isToday: calendar.isDate(day, inSameDayAs: referenceDay),
                    isWeekend: calendar.isDateInWeekend(day)
                )
            }
            resolvedCells = classifyOptimisticBridgeKinds(
                in: HabitBoardPresentationBuilder.remapVisibleDisplayDepths(in: patched)
            )
        }

        return resolvedCells
    }

    func optimisticBoardCellState(
        on day: Date,
        marksByDay: [Date: HabitDayMark],
        cadence: HabitCadenceDraft,
        referenceDay: Date,
        calendar: Calendar
    ) -> HabitBoardCellState {
        if day > referenceDay {
            return .future
        }

        if let mark = marksByDay[day] {
            switch mark.state {
            case .success:
                return .done(depth: 1)
            case .failure:
                return .missed
            case .skipped:
                return .bridge(kind: .single, source: .skipped)
            case .future:
                return .future
            case .none:
                break
            }
        }

        if optimisticHabitShouldOccur(on: day, cadence: cadence, calendar: calendar) {
            return calendar.isDate(day, inSameDayAs: referenceDay) ? .todayPending : .missed
        }

        return .bridge(kind: .single, source: .notScheduled)
    }

    func optimisticHabitShouldOccur(
        on date: Date,
        cadence: HabitCadenceDraft,
        calendar: Calendar
    ) -> Bool {
        switch cadence {
        case .daily:
            return true
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek.contains(calendar.component(.weekday, from: date))
        }
    }

    func classifyOptimisticBridgeKinds(in cells: [HabitBoardCell]) -> [HabitBoardCell] {
        var resolved = cells
        var index = 0

        while index < resolved.count {
            guard case let .bridge(_, source) = resolved[index].state else {
                index += 1
                continue
            }

            let start = index
            var end = index
            while end + 1 < resolved.count {
                guard case .bridge = resolved[end + 1].state else { break }
                end += 1
            }

            let previousDone = optimisticNearestDoneState(in: resolved, before: start)
            let nextDone = optimisticNearestDoneState(in: resolved, after: end)
            let count = (start...end).count

            for current in start...end {
                let kind: HabitBridgeKind
                if count == 1 {
                    if previousDone && nextDone {
                        kind = .single
                    } else if previousDone {
                        kind = .start
                    } else if nextDone {
                        kind = .end
                    } else {
                        kind = .middle
                    }
                } else if current == start {
                    kind = previousDone ? .start : .middle
                } else if current == end {
                    kind = nextDone ? .end : .middle
                } else {
                    kind = .middle
                }

                resolved[current] = HabitBoardCell(
                    date: resolved[current].date,
                    state: .bridge(kind: kind, source: source),
                    isToday: resolved[current].isToday,
                    isWeekend: resolved[current].isWeekend
                )
            }

            index = end + 1
        }

        return resolved
    }

    func optimisticNearestDoneState(in cells: [HabitBoardCell], before index: Int) -> Bool {
        guard index > 0 else { return false }
        for cursor in stride(from: index - 1, through: 0, by: -1) {
            switch cells[cursor].state {
            case .done:
                return true
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                return false
            }
        }
        return false
    }
}
