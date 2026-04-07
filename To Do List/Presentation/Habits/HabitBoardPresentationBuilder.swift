import Foundation

enum HabitBoardPresentationBuilder {
    static func cadenceLabel(
        for cadence: HabitCadenceDraft,
        calendar: Calendar = .current
    ) -> String {
        switch cadence {
        case .daily:
            return "Every day"
        case .weekly(let daysOfWeek, _, _):
            let sortedDays = daysOfWeek.sorted()
            if sortedDays == [2, 3, 4, 5, 6] {
                return "Mon-Fri"
            }
            if sortedDays == [1, 7] {
                return "Weekends"
            }
            let formatter = calendar.shortWeekdaySymbols
            let names = sortedDays.compactMap { weekday -> String? in
                guard (1...7).contains(weekday) else { return nil }
                return formatter[weekday - 1]
            }
            return names.joined(separator: " ")
        }
    }

    static func buildCells(
        marks: [HabitDayMark],
        cadence: HabitCadenceDraft,
        referenceDate: Date,
        dayCount: Int,
        calendar: Calendar = .current
    ) -> [HabitBoardCell] {
        guard dayCount > 0 else { return [] }
        let sortedMarks = marks.sorted { $0.date < $1.date }
        let marksByDay = Dictionary(uniqueKeysWithValues: sortedMarks.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDay) ?? endDay

        let preliminary = (0..<dayCount).compactMap { offset -> HabitBoardCell? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let isFuture = dayStart > endDay
            let isWeekend = calendar.isDateInWeekend(dayStart)
            let state: HabitBoardCellState

            if isFuture {
                state = .future
            } else if let mark = marksByDay[dayStart] {
                state = boardState(for: mark.state, day: dayStart, cadence: cadence, referenceDay: endDay, calendar: calendar)
            } else if shouldOccur(on: dayStart, cadence: cadence, calendar: calendar) {
                state = .none
            } else {
                state = .scheduledOff
            }

            return HabitBoardCell(
                date: dayStart,
                state: state,
                isToday: calendar.isDate(dayStart, inSameDayAs: endDay),
                isWeekend: isWeekend
            )
        }

        var frozenRunDepth = 0
        return preliminary.map { cell in
            switch cell.state {
            case .success:
                frozenRunDepth += 1
                return HabitBoardCell(
                    date: cell.date,
                    state: .success(runDepth: min(frozenRunDepth, 5)),
                    isToday: cell.isToday,
                    isWeekend: cell.isWeekend
                )
            case .skipped, .scheduledOff:
                return cell
            case .failure, .none:
                frozenRunDepth = 0
                return cell
            case .future:
                return cell
            }
        }
    }

    static func metrics(
        for cells: [HabitBoardCell]
    ) -> HabitBoardRowMetrics {
        let currentStreak = currentStreak(for: cells)
        let bestStreak = bestStreak(for: cells)
        let totalCount = cells.filter(\.isSuccess).count
        let weekCount = Array(cells.suffix(7)).filter(\.isSuccess).count
        let monthCount = Array(cells.suffix(30)).filter(\.isSuccess).count
        let yearCount = Array(cells.suffix(365)).filter(\.isSuccess).count

        return HabitBoardRowMetrics(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCount: totalCount,
            weekCount: weekCount,
            monthCount: monthCount,
            yearCount: yearCount
        )
    }

    static func aggregateDays(
        from rows: [HabitBoardRowPresentation],
        dayCount: Int
    ) -> [HabitBoardAggregateDay] {
        guard let firstRow = rows.first else { return [] }
        let visibleRows = rows.filter { $0.cells.count >= dayCount }
        guard visibleRows.isEmpty == false else { return [] }

        let startIndex = max(0, firstRow.cells.count - dayCount)
        return (startIndex..<firstRow.cells.count).map { index in
            let cells = visibleRows.map { $0.cells[index] }
            return HabitBoardAggregateDay(
                date: firstRow.cells[index].date,
                completedCount: cells.filter(\.isSuccess).count,
                habitCount: cells.filter { $0.state != .future }.count,
                isToday: firstRow.cells[index].isToday
            )
        }
    }

    static func splitHomeRows(
        _ rows: [HomeHabitRow]
    ) -> (primary: [HomeHabitRow], recovery: [HomeHabitRow], quiet: [HomeHabitRow]) {
        var primary: [HomeHabitRow] = []
        var recovery: [HomeHabitRow] = []
        var quiet: [HomeHabitRow] = []

        for row in rows {
            if row.trackingMode == .lapseOnly, row.state == .tracking, row.riskState == .stable {
                quiet.append(row)
                continue
            }

            if row.state == .overdue
                || row.state == .lapsedToday
                || row.riskState != .stable {
                recovery.append(row)
            } else {
                primary.append(row)
            }
        }

        return (
            primary.sorted(by: homeRowSort),
            recovery.sorted(by: homeRowSort),
            quiet.sorted(by: homeRowSort)
        )
    }

    private static func boardState(
        for markState: HabitDayState,
        day: Date,
        cadence: HabitCadenceDraft,
        referenceDay: Date,
        calendar: Calendar
    ) -> HabitBoardCellState {
        switch markState {
        case .success:
            return .success(runDepth: 1)
        case .failure:
            return .failure
        case .skipped:
            return .skipped
        case .future:
            return .future
        case .none:
            if day > referenceDay {
                return .future
            }
            return shouldOccur(on: day, cadence: cadence, calendar: calendar) ? .none : .scheduledOff
        }
    }

    private static func shouldOccur(
        on date: Date,
        cadence: HabitCadenceDraft,
        calendar: Calendar
    ) -> Bool {
        switch cadence {
        case .daily:
            return true
        case .weekly(let daysOfWeek, _, _):
            let weekday = calendar.component(.weekday, from: date)
            return daysOfWeek.contains(weekday)
        }
    }

    private static func currentStreak(for cells: [HabitBoardCell]) -> Int {
        var streak = 0
        for cell in cells.reversed() {
            switch cell.state {
            case .future:
                continue
            case .success:
                streak += 1
            case .scheduledOff, .skipped:
                continue
            case .failure, .none:
                return streak
            }
        }
        return streak
    }

    private static func bestStreak(for cells: [HabitBoardCell]) -> Int {
        var best = 0
        var streak = 0

        for cell in cells {
            switch cell.state {
            case .success:
                streak += 1
                best = max(best, streak)
            case .scheduledOff, .skipped:
                continue
            case .failure, .none:
                streak = 0
            case .future:
                continue
            }
        }

        return best
    }

    private static func homeRowSort(_ lhs: HomeHabitRow, _ rhs: HomeHabitRow) -> Bool {
        if lhs.currentStreak != rhs.currentStreak {
            return lhs.currentStreak > rhs.currentStreak
        }
        if lhs.riskState != rhs.riskState {
            return lhs.riskState.rawValue < rhs.riskState.rawValue
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

private extension HabitBoardCell {
    var isSuccess: Bool {
        if case .success = state {
            return true
        }
        return false
    }
}
