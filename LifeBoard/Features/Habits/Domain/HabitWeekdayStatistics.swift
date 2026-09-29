import Foundation
import LifeBoardDomain

/// What the last twelve weeks say about *when* a habit happens, computed from
/// the same day marks the detail calendar draws.
///
/// Only scheduled days count: a success or a failure. Skipped, unscheduled
/// and future days are neither. The copy never blames ("You tend to…" and
/// only with enough days to mean it); the PRD rules out pressure and shame.
struct HabitWeekdayStatistics: Equatable {
    struct Weekday: Equatable, Identifiable {
        /// 1 = Sunday … 7 = Saturday, `Calendar.Component.weekday`.
        let weekday: Int
        let successes: Int
        let scheduled: Int

        var id: Int { weekday }
        var rate: Double? { scheduled > 0 ? Double(successes) / Double(scheduled) : nil }
    }

    struct WeekPoint: Equatable, Identifiable {
        let weekStart: Date
        let successes: Int
        let scheduled: Int

        var id: Date { weekStart }
        var rate: Double? { scheduled > 0 ? Double(successes) / Double(scheduled) : nil }
    }

    /// Fewer scheduled days than this on a weekday and it has no opinion.
    static let minimumScheduledDaysPerWeekday = 4

    let weekdays: [Weekday]
    let weeks: [WeekPoint]

    static func make(marks: [HabitDayMark], weeks weekCount: Int = 12, now: Date = Date(), calendar: Calendar = .current) -> HabitWeekdayStatistics {
        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -(weekCount * 7 - 1), to: today) ?? today
        var byWeekday: [Int: (successes: Int, scheduled: Int)] = [:]
        var byWeek: [Date: (successes: Int, scheduled: Int)] = [:]

        for mark in marks {
            let day = calendar.startOfDay(for: mark.date)
            guard day >= windowStart, day <= today else { continue }
            let counted: Bool
            switch mark.state {
            case .success: counted = true
            case .failure: counted = false
            case .skipped, .none, .future: continue
            }
            let weekday = calendar.component(.weekday, from: day)
            var entry = byWeekday[weekday] ?? (0, 0)
            entry.scheduled += 1
            if counted { entry.successes += 1 }
            byWeekday[weekday] = entry

            let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            var week = byWeek[weekStart] ?? (0, 0)
            week.scheduled += 1
            if counted { week.successes += 1 }
            byWeek[weekStart] = week
        }

        // Weekdays in the calendar's own order (first weekday first).
        let ordered = (0..<7).map { offset in ((calendar.firstWeekday - 1 + offset) % 7) + 1 }
        let weekdays = ordered.map { weekday in
            let entry = byWeekday[weekday] ?? (0, 0)
            return Weekday(weekday: weekday, successes: entry.successes, scheduled: entry.scheduled)
        }
        let weeks = byWeek.keys.sorted().map { start in
            let entry = byWeek[start] ?? (0, 0)
            return WeekPoint(weekStart: start, successes: entry.successes, scheduled: entry.scheduled)
        }
        return HabitWeekdayStatistics(weekdays: weekdays, weeks: weeks)
    }

    /// The weekday with the highest rate among those with enough days.
    var strongest: Weekday? {
        qualified.max { ($0.rate ?? 0, -$0.weekday) < ($1.rate ?? 0, -$1.weekday) }
    }

    /// The weekday with the lowest rate among those with enough days.
    var weakest: Weekday? {
        qualified.min { ($0.rate ?? 0, $0.weekday) < ($1.rate ?? 0, $1.weekday) }
    }

    private var qualified: [Weekday] {
        weekdays.filter { $0.scheduled >= Self.minimumScheduledDaysPerWeekday }
    }

    /// "Most often Tuesdays · least often Fridays", or `nil` until there are
    /// enough scheduled days to say anything. Never causal, never a verdict.
    func summary(calendar: Calendar = .current) -> String? {
        guard let strongest, let strongestRate = strongest.rate else { return nil }
        // A calendar built without a locale falls back to ICU's root names
        // ("Tues"); the person's locale gives "Tuesday".
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        let names = formatter.standaloneWeekdaySymbols ?? calendar.standaloneWeekdaySymbols
        func plural(_ weekday: Int) -> String { names[(weekday - 1) % 7] + "s" }
        var parts = [String(localized: "Most often \(plural(strongest.weekday))")]
        if let weakest, weakest.weekday != strongest.weekday, let weakestRate = weakest.rate, weakestRate < strongestRate {
            parts.append(String(localized: "least often \(plural(weakest.weekday))"))
        }
        return parts.joined(separator: " · ")
    }

    /// "4 of 5", the text equivalent of one bar.
    static func barText(_ weekday: Weekday) -> String {
        weekday.scheduled == 0 ? String(localized: "No scheduled days") : String(localized: "\(weekday.successes) of \(weekday.scheduled)")
    }
}
