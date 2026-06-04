import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingHomeDemoSnapshotFactory {
    static let demoTaskID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let secondTaskID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let demoHabitID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let secondHabitID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    static func snapshot(taskDone: Bool, referenceDate: Date = Date(), calendar: Calendar = .current) -> HomeTimelineSnapshot {
        let day = calendar.startOfDay(for: referenceDate)
        let wake = date(on: day, hour: 7, minute: 0, calendar: calendar)
        let windDown = date(on: day, hour: 22, minute: 0, calendar: calendar)
        let wakeAnchor = TimelineAnchorItem(
            id: "wake",
            title: "Rise and shine",
            time: wake,
            systemImageName: "sunrise.fill",
            subtitle: "Start of day"
        )
        let sleepAnchor = TimelineAnchorItem(
            id: "sleep",
            title: "Wind down",
            time: windDown,
            systemImageName: "moon.zzz.fill",
            subtitle: "End of day"
        )
        let timedItems = [
            calendarItem(
                id: "demo-design-review",
                title: "Design review",
                subtitle: "Work calendar",
                start: date(on: day, hour: 9, minute: 30, calendar: calendar),
                end: date(on: day, hour: 10, minute: 15, calendar: calendar),
                tintHex: "#7EC8FF"
            ),
            taskItem(
                id: demoTaskID,
                title: "Send proposal recap",
                subtitle: "Client launch",
                start: date(on: day, hour: 11, minute: 0, calendar: calendar),
                end: date(on: day, hour: 11, minute: 30, calendar: calendar),
                isComplete: taskDone,
                tintHex: "#F4C95D"
            ),
            calendarItem(
                id: "demo-budget-sync",
                title: "Budget sync",
                subtitle: "Finance calendar",
                start: date(on: day, hour: 14, minute: 15, calendar: calendar),
                end: date(on: day, hour: 15, minute: 0, calendar: calendar),
                tintHex: "#B8A7FF"
            ),
            taskItem(
                id: secondTaskID,
                title: "Draft workout plan",
                subtitle: "Health",
                start: date(on: day, hour: 16, minute: 30, calendar: calendar),
                end: date(on: day, hour: 17, minute: 0, calendar: calendar),
                isComplete: false,
                tintHex: "#8FEA8B"
            )
        ]
        let projection = TimelineDayProjection(
            date: day,
            allDayItems: [],
            inboxItems: [],
            timedItems: timedItems,
            gaps: [],
            layoutMode: .expanded,
            calendarPlottingEnabled: true,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            activeItemID: nil,
            currentTime: date(on: day, hour: 10, minute: 30, calendar: calendar)
        )
        return HomeTimelineSnapshot(
            selectedDate: day,
            sunriseAnchor: .collapsed,
            day: projection,
            week: weekSummary(selectedDate: day, timedItems: timedItems, calendar: calendar),
            placementCandidate: nil
        )
    }

    static func habitRows(habitDone: Bool, referenceDate: Date = Date(), calendar: Calendar = .current) -> [HomeHabitRow] {
        [
            habitRow(
                id: demoHabitID,
                title: "Move",
                icon: "figure.walk",
                accentHex: "#4E9A2F",
                isDone: habitDone,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            habitRow(
                id: secondHabitID,
                title: "Plan",
                icon: "checklist",
                accentHex: "#4A86E8",
                isDone: false,
                referenceDate: referenceDate,
                calendar: calendar
            )
        ]
    }

    static func taskItem(
        id: UUID,
        title: String,
        subtitle: String,
        start: Date,
        end: Date,
        isComplete: Bool,
        tintHex: String
    ) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "task:\(id.uuidString)",
            source: .task,
            taskID: id,
            eventID: nil,
            title: title,
            subtitle: subtitle,
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: isComplete,
            tintHex: tintHex,
            systemImageName: "checkmark.circle",
            accessoryText: nil,
            taskPriority: .low,
            showsProjectUtility: true
        )
    }

    static func calendarItem(
        id: String,
        title: String,
        subtitle: String,
        start: Date,
        end: Date,
        tintHex: String
    ) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "event:\(id)",
            source: .calendarEvent,
            taskID: nil,
            eventID: id,
            title: title,
            subtitle: subtitle,
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: false,
            tintHex: tintHex,
            systemImageName: "calendar",
            accessoryText: nil,
            isMeetingLike: true
        )
    }

    static func habitRow(
        id: UUID,
        title: String,
        icon: String,
        accentHex: String,
        isDone: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> HomeHabitRow {
        let today = calendar.startOfDay(for: referenceDate)
        let cells = (0..<14).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 13, to: today) ?? today
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let state: HabitBoardCellState
            if isToday {
                state = isDone ? .done(depth: 5) : .todayPending
            } else if offset % 5 == 0 {
                state = .missed
            } else {
                state = .done(depth: min(offset + 1, 8))
            }
            return HabitBoardCell(
                date: date,
                state: state,
                isToday: isToday,
                isWeekend: calendar.isDateInWeekend(date)
            )
        }
        return HomeHabitRow(
            habitID: id,
            title: title,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            projectName: "Routine",
            iconSymbolName: icon,
            accentHex: accentHex,
            cadence: .daily(hour: 8, minute: 0),
            cadenceLabel: "Every day",
            dueAt: date(on: today, hour: 8, minute: 0, calendar: calendar),
            state: isDone ? .completedToday : .due,
            currentStreak: isDone ? 5 : 4,
            bestStreak: 9,
            boardCellsCompact: Array(cells.suffix(7)),
            boardCellsExpanded: cells,
            riskState: .stable,
            helperText: isDone ? "Done today" : "Tap to mark today"
        )
    }

    static func weekSummary(selectedDate: Date, timedItems: [TimelinePlanItem], calendar: Calendar) -> TimelineWeekSummary {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? selectedDate
            let dayItems = timedItems.filter { item in
                guard let startDate = item.startDate else { return false }
                return calendar.isDate(startDate, inSameDayAs: date)
            }
            return TimelineWeekDaySummary(
                date: date,
                dayKey: "\(Int(date.timeIntervalSince1970))",
                allDayCount: 0,
                replanEligibleCount: 0,
                timedMarkers: dayItems.compactMap(\.startDate),
                tintHexes: Array(dayItems.compactMap(\.tintHex).prefix(4)),
                summaryText: dayItems.isEmpty ? "Open" : "\(dayItems.count) planned",
                loadLevel: dayItems.count > 3 ? .busy : dayItems.count > 1 ? .balanced : .light
            )
        }
        return TimelineWeekSummary(weekStart: weekStart, weekStartsOn: .monday, days: days)
    }

    static func date(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}
