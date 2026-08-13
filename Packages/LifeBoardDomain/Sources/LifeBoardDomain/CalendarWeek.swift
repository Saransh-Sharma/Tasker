import Foundation

public extension Calendar {
    func daysWithSameWeekOfYear(as date: Date) -> [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.year, from: date)
        guard let firstDayOfWeek = calendar.date(
            from: DateComponents(weekOfYear: weekOfYear, yearForWeekOfYear: year)
        ) else {
            return []
        }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDayOfWeek)
        }
    }
}

public extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        DateComponents(day: 1, second: -1)
            .date(from: Calendar.current, relativeTo: startOfDay) ?? startOfDay
    }
}

private extension DateComponents {
    func date(from calendar: Calendar, relativeTo date: Date) -> Date? {
        calendar.date(byAdding: self, to: date)
    }
}
