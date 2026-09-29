import Foundation
import SwiftUI

// The pure geometry behind `PlanDayTimeCanvas`: where a drop lands, how the
// day is labelled and shaded, and when a sideways drag becomes a day change.
// Kept apart from the view so the rules are unit-tested without rendering.

/// Where a drop on the day canvas lands, in time.
enum PlanCanvasDropResolver {
    static let snapMinutes = 15

    static func start(
        forY y: CGFloat,
        timelineStart: Date,
        hourHeight: CGFloat,
        snapMinutes: Int = snapMinutes
    ) -> Date {
        let minutes = max(0, Double(y / hourHeight) * 60)
        let snapped = (minutes / Double(snapMinutes)).rounded() * Double(snapMinutes)
        // Wall-clock, like the ruler: on a daylight-saving day, elapsed time
        // put a drop an hour away from the label it landed on.
        return PlanCanvasGeometry.date(atWallClockMinutes: Int(snapped), after: timelineStart)
    }
}

/// Pure geometry and wording for the day canvas, kept out of the view so the
/// rules are testable.
enum PlanCanvasGeometry {
    /// Hours between two instants as a wall clock reads them. The ruler counts
    /// clock hours, so positions must too: measuring elapsed seconds drew
    /// everything after a daylight-saving change an hour away from its label.
    static func wallClockHours(from origin: Date, to date: Date, calendar: Calendar = .current) -> Double {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: origin),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return Double(days) * 24 + clockHours(date, calendar: calendar) - clockHours(origin, calendar: calendar)
    }

    /// The instant `minutes` of wall-clock time after `origin`.
    static func date(atWallClockMinutes minutes: Int, after origin: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: origin)
        let total = (parts.hour ?? 0) * 60 + (parts.minute ?? 0) + max(0, minutes)
        let day = calendar.date(byAdding: .day, value: total / 1_440, to: calendar.startOfDay(for: origin)) ?? origin
        let remainder = total % 1_440
        return calendar.date(bySettingHour: remainder / 60, minute: remainder % 60, second: 0, of: day)
            ?? origin.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func clockHours(_ date: Date, calendar: Calendar) -> Double {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3_600
    }

    /// Whether the person reads a 12-hour clock. The ruler used to force
    /// "6 PM" on every locale, including 24-hour ones.
    static func uses12HourClock(locale: Locale = .current) -> Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "h a").contains("a")
    }

    /// "6 AM", "Noon", "6 PM" on a 12-hour clock; "06:00", "18:00" on a
    /// 24-hour one. The ruler only needs the hour.
    static func hourLabel(_ hour: Int, locale: Locale = .current) -> String {
        let value = hour % 24
        guard uses12HourClock(locale: locale) else { return String(format: "%02d:00", value) }
        switch value {
        case 0: return "12 AM"
        case 12: return "Noon"
        case let value where value < 12: return "\(value) AM"
        case let value: return "\(value - 12) PM"
        }
    }

    /// Today opens with now a third of the way down; other days open at their
    /// first item, at the top.
    static func initialAnchor(isToday: Bool) -> UnitPoint {
        isToday ? UnitPoint(x: 0.5, y: 0.33) : .top
    }

    /// "7:25": no leading zero, no AM/PM (the ruler beside it already says).
    /// "19:25" on a 24-hour clock.
    static func nowLabel(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard uses12HourClock(locale: locale) else {
            return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        }
        let hour = (parts.hour ?? 0) % 12 == 0 ? 12 : (parts.hour ?? 0) % 12
        return String(format: "%d:%02d", hour, parts.minute ?? 0)
    }

    /// The parts of the drawn span outside working hours, to the minute. It
    /// used to shade whole hours by testing each hour's start, and because
    /// `DateInterval.contains` includes its end, 6 PM counted as working.
    static func nonworkingIntervals(within span: DateInterval, working: [DateInterval]) -> [DateInterval] {
        var gaps: [DateInterval] = []
        var cursor = span.start
        for interval in working.sorted(by: { $0.start < $1.start }) where interval.end > cursor && interval.start < span.end {
            if interval.start > cursor { gaps.append(DateInterval(start: cursor, end: interval.start)) }
            cursor = max(cursor, interval.end)
        }
        if cursor < span.end { gaps.append(DateInterval(start: cursor, end: span.end)) }
        return gaps
    }

    static func labelsOpenWindow(duration: TimeInterval) -> Bool {
        duration >= 45 * 60
    }

    /// A shorter gap still says how long it is ("25m") once it is tall enough
    /// to hold one caption line; below twenty minutes it stays wordless.
    static func labelsOpenWindowBriefly(duration: TimeInterval) -> Bool {
        duration >= 20 * 60 && labelsOpenWindow(duration: duration) == false
    }

    /// Where "1h 20m over" lands on the grid: the planned work that does not
    /// fit the working window, as a band spilling past the end of the last
    /// working interval. The budget is a total, not a position, so the band
    /// says "this much would run past your day" rather than pointing at any
    /// one block. `nil` when nothing is over or no working hours are set.
    static func overloadBand(working: [DateInterval], overload: TimeInterval) -> DateInterval? {
        guard overload > 0, let end = working.map(\.end).max() else { return nil }
        return DateInterval(start: end, duration: overload)
    }
}

/// When a sideways drag on the canvas becomes a day change.
enum PlanDaySwipe {
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 2
    }

    /// +1 for the next day (swipe left), -1 for the previous, 0 to spring back.
    /// Commits past 30% of the width, or on a flick that would carry that far.
    static func dayDelta(translation: CGSize, predictedEndTranslation: CGSize, width: CGFloat) -> Int {
        guard width > 0, isHorizontal(translation), abs(translation.width) >= 24 else { return 0 }
        let threshold = width * 0.3
        let travel = abs(translation.width) >= threshold ? translation.width
            : abs(predictedEndTranslation.width) >= threshold * 1.5 ? predictedEndTranslation.width
            : 0
        guard travel != 0, travel.sign == translation.width.sign else { return 0 }
        return travel < 0 ? 1 : -1
    }
}
