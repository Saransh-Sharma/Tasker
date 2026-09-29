import Foundation

/// A month of focus, read from persisted sessions: minutes per day for the
/// grid, the month's totals, the tasks that took the most of it, and the
/// sessions behind any one day. Pure, so every number on the history screen
/// is unit-tested with fixed dates rather than by rendering.
///
/// Only sessions that ended count; a running or paused one belongs to the
/// surface, not to history. Minutes are `focusedDuration`, so a paused
/// stretch is never counted as focus.
struct FocusHistoryProjection: Equatable {
    struct Day: Equatable, Identifiable {
        let date: Date
        let minutes: Int
        let sessionCount: Int
        /// 0 for none, then 1…4 by quartile of the month's non-zero days. A
        /// quartile, not a fraction of the busiest day, so one long day does
        /// not wash every other day out to the lightest tint.
        let tint: Int
        var id: Date { date }

        /// The text equivalent of the tint, for VoiceOver and for
        /// Differentiate Without Colour.
        var summary: String {
            guard minutes > 0 else { return String(localized: "No focus") }
            let length = FocusHistoryProjection.durationText(minutes: minutes)
            return sessionCount == 1
                ? String(localized: "\(length) in 1 session")
                : String(localized: "\(length) in \(sessionCount) sessions")
        }
    }

    struct TaskTotal: Equatable, Identifiable {
        let taskID: UUID?
        let title: String
        let minutes: Int
        let sessionCount: Int
        var id: String { taskID?.uuidString ?? "untitled" }
    }

    struct Session: Equatable, Identifiable {
        let id: UUID
        let taskID: UUID?
        let title: String
        let startedAt: Date
        let minutes: Int
        let outcome: FocusCompletionOutcome?
        let energyAfter: Int?
        let reflection: String?
    }

    let month: Date
    let days: [Day]
    let totalMinutes: Int
    let sessionCount: Int
    let longestMinutes: Int
    let topTasks: [TaskTotal]
    /// Ended sessions in the month, newest first.
    let sessions: [Session]

    /// `titles` resolves a task's title; unknown tasks read as "Untitled focus".
    static func make(
        month: Date,
        sessions: [FocusSessionV2],
        titles: (UUID) -> String?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> FocusHistoryProjection {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count else {
            return FocusHistoryProjection(month: monthStart, days: [], totalMinutes: 0, sessionCount: 0, longestMinutes: 0, topTasks: [], sessions: [])
        }
        let ended = sessions
            .filter { $0.state == .ended && $0.startedAt >= monthStart && $0.startedAt < monthEnd }
            .sorted { $0.startedAt > $1.startedAt }

        var minutesByDay: [Date: Int] = [:]
        var countByDay: [Date: Int] = [:]
        var byTask: [String: (taskID: UUID?, title: String, minutes: Int, count: Int)] = [:]
        var projected: [Session] = []
        var longest = 0
        for session in ended {
            let minutes = Int((session.focusedDuration(at: session.endedAt ?? now) / 60).rounded(.down))
            let day = calendar.startOfDay(for: session.startedAt)
            minutesByDay[day, default: 0] += minutes
            countByDay[day, default: 0] += 1
            longest = max(longest, minutes)
            let title = session.taskID.flatMap(titles) ?? "Untitled focus"
            let key = session.taskID?.uuidString ?? "untitled"
            var entry = byTask[key] ?? (session.taskID, title, 0, 0)
            entry.minutes += minutes
            entry.count += 1
            byTask[key] = entry
            projected.append(Session(
                id: session.id,
                taskID: session.taskID,
                title: title,
                startedAt: session.startedAt,
                minutes: minutes,
                outcome: session.outcome,
                energyAfter: session.energyAfter,
                reflection: session.reflection
            ))
        }

        let nonZero = minutesByDay.values.filter { $0 > 0 }.sorted()
        func tint(for minutes: Int) -> Int {
            guard minutes > 0, nonZero.isEmpty == false else { return 0 }
            // Position among the month's focused days, in quartiles.
            let rank = nonZero.firstIndex(where: { $0 >= minutes }) ?? (nonZero.count - 1)
            let fraction = Double(rank + 1) / Double(nonZero.count)
            return max(1, min(4, Int((fraction * 4).rounded(.up))))
        }
        let days: [Day] = (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
            let minutes = minutesByDay[date] ?? 0
            return Day(date: date, minutes: minutes, sessionCount: countByDay[date] ?? 0, tint: tint(for: minutes))
        }
        let top = byTask.values
            .sorted { $0.minutes == $1.minutes ? $0.title < $1.title : $0.minutes > $1.minutes }
            .prefix(5)
            .map { TaskTotal(taskID: $0.taskID, title: $0.title, minutes: $0.minutes, sessionCount: $0.count) }
        return FocusHistoryProjection(
            month: monthStart,
            days: days,
            totalMinutes: minutesByDay.values.reduce(0, +),
            sessionCount: ended.count,
            longestMinutes: longest,
            topTasks: Array(top),
            sessions: projected
        )
    }

    /// "1 hr, 20 min", "45 min", "0 min": the app's one duration format.
    static func durationText(minutes: Int) -> String {
        LifeBoardDuration.text(minutes: minutes)
    }
}
