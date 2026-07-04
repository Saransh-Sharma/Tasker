import SwiftUI

enum TimelineRailTimeFormatter {
    static func railText(for date: Date, kind: TimelineRailLabelKind, calendar: Calendar = .current) -> String {
        switch kind {
        case .compactHour:
            return date.formatted(style(calendar: calendar).hour())
        case .exact, .current:
            return date.formatted(style(calendar: calendar).hour().minute())
        }
    }

    static func railText(forItemStart date: Date, calendar: Calendar = .current) -> String {
        let minute = calendar.component(.minute, from: date)
        let kind: TimelineRailLabelKind = minute == 0 ? .compactHour : .exact
        return railText(for: date, kind: kind, calendar: calendar)
    }

    /// Visible rail times follow the user's locale and 12/24-hour preference.
    private static func style(calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(
            locale: calendar.locale ?? .current,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
    }
}
