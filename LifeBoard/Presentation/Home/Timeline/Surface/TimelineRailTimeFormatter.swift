import SwiftUI

enum TimelineRailTimeFormatter {
    static func railText(for date: Date, kind: TimelineRailLabelKind, calendar: Calendar = .current) -> String {
        switch kind {
        case .compactHour:
            return formatted(date, format: "h a", calendar: calendar)
        case .exact, .current:
            return formatted(date, format: "h:mm a", calendar: calendar)
        }
    }

    static func railText(forItemStart date: Date, calendar: Calendar = .current) -> String {
        let minute = calendar.component(.minute, from: date)
        let kind: TimelineRailLabelKind = minute == 0 ? .compactHour : .exact
        return railText(for: date, kind: kind, calendar: calendar)
    }

    static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
