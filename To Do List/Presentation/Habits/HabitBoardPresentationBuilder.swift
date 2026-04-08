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

        var preliminary = (0..<dayCount).compactMap { offset -> HabitBoardCell? in
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
                state = calendar.isDate(dayStart, inSameDayAs: endDay) ? .todayPending : .missed
            } else {
                state = .bridge(kind: .single, source: .notScheduled)
            }

            return HabitBoardCell(
                date: dayStart,
                state: state,
                isToday: calendar.isDate(dayStart, inSameDayAs: endDay),
                isWeekend: isWeekend
            )
        }

        var streakDepth = 0
        for index in preliminary.indices {
            switch preliminary[index].state {
            case .done:
                streakDepth += 1
                preliminary[index] = HabitBoardCell(
                    date: preliminary[index].date,
                    state: .done(depth: min(streakDepth, 8)),
                    isToday: preliminary[index].isToday,
                    isWeekend: preliminary[index].isWeekend
                )
            case .bridge, .todayPending:
                continue
            case .missed:
                streakDepth = 0
            case .future:
                continue
            }
        }

        return classifyBridgeKinds(in: preliminary)
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

    static func remapVisibleDisplayDepths(
        in cells: [HabitBoardCell]
    ) -> [HabitBoardCell] {
        var resolved = cells
        var visibleRunDepth = 0

        for index in resolved.indices {
            switch resolved[index].state {
            case .done:
                visibleRunDepth += 1
                resolved[index] = HabitBoardCell(
                    date: resolved[index].date,
                    state: .done(depth: min(visibleRunDepth, 8)),
                    isToday: resolved[index].isToday,
                    isWeekend: resolved[index].isWeekend
                )
            case .bridge, .todayPending:
                continue
            case .missed, .future:
                visibleRunDepth = 0
            }
        }

        return resolved
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
            return .done(depth: 1)
        case .failure:
            return .missed
        case .skipped:
            return .bridge(kind: .single, source: .skipped)
        case .future:
            return .future
        case .none:
            if day > referenceDay {
                return .future
            }
            if shouldOccur(on: day, cadence: cadence, calendar: calendar) {
                return calendar.isDate(day, inSameDayAs: referenceDay) ? .todayPending : .missed
            }
            return .bridge(kind: .single, source: .notScheduled)
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
            case .done:
                streak += 1
            case .bridge, .todayPending:
                continue
            case .missed:
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
            case .done:
                streak += 1
                best = max(best, streak)
            case .bridge, .todayPending:
                continue
            case .missed:
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

    private static func classifyBridgeKinds(in cells: [HabitBoardCell]) -> [HabitBoardCell] {
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

            let previousDone = nearestDoneState(in: resolved, before: start)
            let nextDone = nearestDoneState(in: resolved, after: end)
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

    private static func nearestDoneState(in cells: [HabitBoardCell], before index: Int) -> Bool {
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

    private static func nearestDoneState(in cells: [HabitBoardCell], after index: Int) -> Bool {
        guard index < cells.count - 1 else { return false }
        for cursor in (index + 1)..<cells.count {
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

private extension HabitBoardCell {
    var isSuccess: Bool {
        if case .done = state {
            return true
        }
        return false
    }
}
