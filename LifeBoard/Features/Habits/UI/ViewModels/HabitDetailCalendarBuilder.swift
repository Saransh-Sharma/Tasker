import Foundation
import SwiftUI

enum HabitDetailCalendarBuilder {
    static let historyDayCount = 84

    static func buildWeeks(
        row: HabitLibraryRow,
        marks: [HabitDayMark],
        referenceDate: Date,
        dayCount: Int = historyDayCount,
        calendar: Calendar = .current
    ) -> [HabitDetailCalendarWeek] {
        let endDay = calendar.startOfDay(for: referenceDate)
        let requestedStart = calendar.date(byAdding: .day, value: -(max(dayCount, 1) - 1), to: endDay) ?? endDay
        let startDay = calendar.dateInterval(of: .weekOfYear, for: requestedStart)?.start ?? requestedStart
        let endWeek = calendar.dateInterval(of: .weekOfYear, for: endDay)
        let endGridDay = calendar.date(byAdding: .day, value: 6, to: endWeek?.start ?? endDay) ?? endDay
        let totalDays = max(calendar.dateComponents([.day], from: startDay, to: endGridDay).day ?? 0, 0) + 1
        let marksByDay = Dictionary(uniqueKeysWithValues: marks.map { mark in
            (calendar.startOfDay(for: mark.date), mark)
        })

        let days = (0..<totalDays).compactMap { offset -> HabitDetailDayCell? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let scheduled = occurs(on: dayStart, cadence: row.cadence, trackingMode: row.trackingMode, calendar: calendar)
            let mark = marksByDay[dayStart]
            let state = resolveState(
                mark: mark,
                day: dayStart,
                referenceDay: endDay,
                scheduled: scheduled
            )

            return HabitDetailDayCell(
                date: dayStart,
                state: state,
                isToday: calendar.isDate(dayStart, inSameDayAs: endDay),
                isInteractive: dayStart <= endDay && !row.isPaused && !row.isArchived
            )
        }

        var previousMonthAnchor: Date?

        return stride(from: 0, to: days.count, by: 7).compactMap { index in
            let cells = Array(days[index..<min(index + 7, days.count)])
            guard let firstDay = cells.first?.date else { return nil }
            let monthAnchor = cells.first(where: {
                calendar.component(.day, from: $0.date) == 1
            })?.date ?? (index == 0 ? firstDay : nil)
            let monthLabel: String?
            if let monthAnchor {
                if let previousMonthAnchor, calendar.isDate(monthAnchor, equalTo: previousMonthAnchor, toGranularity: .month) {
                    monthLabel = nil
                } else {
                    monthLabel = monthAnchor.formatted(.dateTime.month(.wide).year())
                    previousMonthAnchor = monthAnchor
                }
            } else {
                monthLabel = nil
            }

            return HabitDetailCalendarWeek(
                startDate: firstDay,
                monthLabel: monthLabel,
                cells: cells
            )
        }
    }

    static func buildViewState(
        row: HabitLibraryRow,
        marks: [HabitDayMark],
        referenceDate: Date,
        dayCount: Int = historyDayCount,
        calendar: Calendar = .current
    ) -> HabitDetailCalendarViewState {
        let weeks = buildWeeks(
            row: row,
            marks: marks,
            referenceDate: referenceDate,
            dayCount: dayCount,
            calendar: calendar
        )
        let flattenedCells = weeks.flatMap(\.cells)
        let streakDepthByDate = streakDepthMap(for: flattenedCells, calendar: calendar)

        return HabitDetailCalendarViewState(
            helperText: helperText(for: row),
            weeks: weeks.map { week in
                HabitDetailCalendarWeekViewState(
                    startDate: week.startDate,
                    monthLabel: week.monthLabel,
                    cells: week.cells.map { cell in
                        let dayStart = calendar.startOfDay(for: cell.date)
                        return HabitDetailCalendarCellViewState(
                            cell: cell,
                            streakDepth: streakDepthByDate[dayStart],
                            dayNumber: String(calendar.component(.day, from: cell.date)),
                            accessibilityLabel: fullDateFormatter.string(from: cell.date),
                            accessibilityValue: accessibilityValue(for: cell, row: row),
                            accessibilityHint: accessibilityHint(for: cell, row: row),
                            accessibilityIdentifier: accessibilityIdentifier(for: cell.date)
                        )
                    }
                )
            },
            summaryMetrics: summaryMetrics(
                for: flattenedCells,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak
            )
        )
    }

    static func helperText(for row: HabitLibraryRow) -> String {
        if row.isArchived {
            return String(localized: "Archived habits are read-only.")
        }
        if row.isPaused {
            return String(localized: "Resume to edit days.")
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, .dailyCheckIn):
            return String(localized: "Tap a day to mark it done or skipped.")
        case (.negative, .dailyCheckIn):
            return String(localized: "Tap a day to mark it clean or a slip.")
        case (.negative, .lapseOnly):
            return String(localized: "Tap a day to log or clear a slip.")
        case (.positive, .lapseOnly):
            return String(localized: "Tap a day to update it.")
        }
    }

    static func accessibilityIdentifier(for date: Date) -> String {
        "habitDetail.cell.\(accessibilityStampFormatter.string(from: date))"
    }

    static func nextMutation(
        for row: HabitLibraryRow,
        state: HabitDetailDayCellState
    ) -> HabitDetailDayMutationRequest? {
        guard !row.isPaused, !row.isArchived else { return nil }

        switch (row.kind, row.trackingMode, state) {
        case (_, _, .future):
            return nil

        case (.positive, .dailyCheckIn, .empty), (.positive, .dailyCheckIn, .notScheduled):
            return .resolve(.complete)
        case (.positive, .dailyCheckIn, .success):
            return .resolve(.skip)
        case (.positive, .dailyCheckIn, .skipped), (.positive, .dailyCheckIn, .lapsed):
            return .reset

        case (.negative, .dailyCheckIn, .empty), (.negative, .dailyCheckIn, .notScheduled):
            return .resolve(.abstained)
        case (.negative, .dailyCheckIn, .success):
            return .resolve(.lapsed)
        case (.negative, .dailyCheckIn, .skipped):
            return .reset
        case (.negative, .dailyCheckIn, .lapsed):
            return .reset

        case (.negative, .lapseOnly, .empty), (.negative, .lapseOnly, .notScheduled):
            return .resolve(.lapsed)
        case (.negative, .lapseOnly, .success):
            return .resolve(.lapsed)
        case (.negative, .lapseOnly, .lapsed):
            return .resolve(.abstained)
        case (.negative, .lapseOnly, .skipped):
            return .reset

        case (.positive, .lapseOnly, .empty), (.positive, .lapseOnly, .notScheduled):
            return .resolve(.complete)
        case (.positive, .lapseOnly, .success), (.positive, .lapseOnly, .skipped), (.positive, .lapseOnly, .lapsed):
            return .reset
        }
    }

    static func mutationFeedback(
        for request: HabitDetailDayMutationRequest,
        row: HabitLibraryRow,
        date: Date,
        calendar: Calendar = .current
    ) -> HabitDetailMutationFeedback {
        let stateLabel: String
        let haptic: HabitDetailMutationFeedbackHaptic

        switch request {
        case .resolve(.complete):
            stateLabel = String(localized: "Marked complete")
            haptic = .success
        case .resolve(.skip):
            stateLabel = String(localized: "Marked skipped")
            haptic = .selection
        case .resolve(.abstained):
            stateLabel = row.kind == .negative ? String(localized: "Marked clean") : String(localized: "Marked complete")
            haptic = .success
        case .resolve(.lapsed):
            stateLabel = String(localized: "Slip logged")
            haptic = .warning
        case .reset:
            stateLabel = String(localized: "Cleared")
            haptic = .selection
        }

        let dayLabel = calendar.startOfDay(for: date).formatted(.dateTime.month(.abbreviated).day())
        return HabitDetailMutationFeedback(
            message: String(localized: "\(dayLabel): \(stateLabel)"),
            haptic: haptic
        )
    }

    static func accessibilityValue(for cell: HabitDetailDayCell, row: HabitLibraryRow) -> String {
        switch cell.state {
        case .empty:
            return String(localized: "Not logged")
        case .success:
            return row.kind == .negative ? String(localized: "Stayed clean") : String(localized: "Done")
        case .skipped:
            return String(localized: "Skipped")
        case .lapsed:
            return row.kind == .negative ? String(localized: "Slip") : String(localized: "Not done")
        case .notScheduled:
            return String(localized: "Not scheduled")
        case .future:
            return String(localized: "Future day")
        }
    }

    static func accessibilityHint(for cell: HabitDetailDayCell, row: HabitLibraryRow) -> String {
        guard cell.isInteractive,
              let mutation = nextMutation(for: row, state: cell.state) else { return "" }

        switch mutation {
        case .resolve(let action):
            switch action {
            case .complete:
                return String(localized: "Marks done.")
            case .skip:
                return String(localized: "Marks skipped.")
            case .abstained:
                return String(localized: "Marks clean.")
            case .lapsed:
                return String(localized: "Logs a slip.")
            }
        case .reset:
            return String(localized: "Clears this day.")
        }
    }

    private static func summaryMetrics(
        for cells: [HabitDetailDayCell],
        currentStreak: Int,
        bestStreak: Int
    ) -> HabitDetailCalendarSummaryMetrics {
        let elapsedScheduledCells = cells.filter { cell in
            switch cell.state {
            case .future, .notScheduled:
                return false
            case .empty, .success, .skipped, .lapsed:
                return true
            }
        }
        let totalCount = elapsedScheduledCells.filter { $0.state == .success }.count
        let scheduledElapsedCount = elapsedScheduledCells.count
        let completionRate = scheduledElapsedCount > 0
            ? Double(totalCount) / Double(scheduledElapsedCount)
            : 0

        return HabitDetailCalendarSummaryMetrics(
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalCount: totalCount,
            scheduledElapsedCount: scheduledElapsedCount,
            completionRate: completionRate
        )
    }

    private static func resolveState(
        mark: HabitDayMark?,
        day: Date,
        referenceDay: Date,
        scheduled: Bool
    ) -> HabitDetailDayCellState {
        guard day <= referenceDay else { return .future }

        if let mark {
            switch mark.state {
            case .success:
                return .success
            case .skipped:
                return .skipped
            case .failure:
                return .lapsed
            case .future:
                return .future
            case .none:
                break
            }
        }

        return scheduled ? .empty : .notScheduled
    }

    private static func occurs(
        on date: Date,
        cadence: HabitCadenceDraft,
        trackingMode: HabitTrackingMode,
        calendar: Calendar
    ) -> Bool {
        switch cadence {
        case .daily:
            return true
        case .weekly(let daysOfWeek, _, _):
            let weekday = calendar.component(.weekday, from: date)
            if trackingMode == .lapseOnly && daysOfWeek.isEmpty {
                return true
            }
            return daysOfWeek.contains(weekday)
        case .interval(let days, _, _):
            let epoch = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
            let offset = calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: date)).day ?? 0
            return offset.isMultiple(of: max(1, days))
        }
    }

    private static func streakDepthMap(
        for cells: [HabitDetailDayCell],
        calendar: Calendar
    ) -> [Date: Int] {
        var streakDepthByDate: [Date: Int] = [:]
        var streakDepth = 0

        for cell in cells.sorted(by: { $0.date < $1.date }) {
            switch cell.state {
            case .success:
                streakDepth = min(streakDepth + 1, 8)
                streakDepthByDate[calendar.startOfDay(for: cell.date)] = streakDepth
            case .skipped, .notScheduled:
                continue
            case .empty, .lapsed:
                streakDepth = 0
            case .future:
                continue
            }
        }

        return streakDepthByDate
    }

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private static let accessibilityStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
