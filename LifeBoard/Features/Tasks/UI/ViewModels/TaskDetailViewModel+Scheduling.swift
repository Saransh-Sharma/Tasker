import Foundation

extension TaskDetailViewModel {
    nonisolated public static let scheduleIntervalMinutes = 15

    public static func defaultScheduledStart(
        now: Date = Date(),
        intervalMinutes: Int = scheduleIntervalMinutes,
        calendar: Calendar = .current
    ) -> Date {
        let intervalSeconds = TimeInterval(max(1, intervalMinutes) * 60)
        let nextSlot = ceil(now.timeIntervalSinceReferenceDate / intervalSeconds) * intervalSeconds
        return Date(timeIntervalSinceReferenceDate: nextSlot)
    }

    public static func roundedToNearestScheduleSlot(
        _ date: Date,
        intervalMinutes: Int = scheduleIntervalMinutes,
        calendar: Calendar = .current
    ) -> Date {
        let intervalSeconds = TimeInterval(max(1, intervalMinutes) * 60)
        let rounded = (date.timeIntervalSinceReferenceDate / intervalSeconds).rounded() * intervalSeconds
        return clearingSubminuteComponents(Date(timeIntervalSinceReferenceDate: rounded), calendar: calendar)
    }

    public static func scheduleRangeLabel(start: Date, end: Date?, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        guard let end else {
            return normalizedTimeText(formatter.string(from: start))
        }
        let startText = normalizedTimeText(formatter.string(from: start))
        let endText = normalizedTimeText(formatter.string(from: end))
        if localeUses12HourClock(formatter.locale) {
            let periodFormatter = DateFormatter()
            periodFormatter.locale = formatter.locale
            periodFormatter.calendar = formatter.calendar
            periodFormatter.timeZone = formatter.timeZone
            periodFormatter.dateFormat = "a"
            let startPeriod = normalizedTimeText(periodFormatter.string(from: start))
            let endPeriod = normalizedTimeText(periodFormatter.string(from: end))
            if startPeriod.isEmpty == false,
               startPeriod == endPeriod,
               startText.hasSuffix(startPeriod),
               endText.hasSuffix(endPeriod) {
                let compactStart = startText
                    .dropLast(startPeriod.count)
                    .trimmingCharacters(in: .whitespaces)
                return "\(compactStart)-\(endText)"
            }
        }
        return "\(startText)-\(endText)"
    }

    public static func scheduleRangeAccessibilityLabel(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let end else {
            return normalizedTimeText(formatter.string(from: start))
        }
        return "\(normalizedTimeText(formatter.string(from: start))) to \(normalizedTimeText(formatter.string(from: end)))"
    }

    static func clearingSubminuteComponents(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func normalizedTimeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static func localeUses12HourClock(_ locale: Locale) -> Bool {
        DateFormatter
            .dateFormat(fromTemplate: "j", options: 0, locale: locale)?
            .contains("a") == true
    }

    static func durationLabel(for duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainder) min"
    }

    /// Executes sortTasksByDueThenName.
    static func sortTasksByDueThenName(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        let lhsDue = lhs.dueDate ?? Date.distantFuture
        let rhsDue = rhs.dueDate ?? Date.distantFuture
        if lhsDue == rhsDue {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhsDue < rhsDue
    }

    /// Executes sortSteps.
    static func sortSteps(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.isComplete != rhs.isComplete {
            return !lhs.isComplete
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    /// Executes areDatesDifferent.
    func areDatesDifferent(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case let (left?, right?):
            return abs(left.timeIntervalSince(right)) > 0.5
        default:
            return true
        }
    }

    /// Executes areDurationsDifferent.
    func areDurationsDifferent(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case let (left?, right?):
            return abs(left - right) > 0.5
        default:
            return true
        }
    }
}
