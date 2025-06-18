import Foundation

//

import Foundation

/// DateUtils provides static utility methods for date formatting and manipulation
class DateUtils {
    
    // MARK: - Date Formatting
    
    /// Formats a date for display in the UI
    /// - Parameter date: The date to format
    /// - Returns: A formatted string representation of the date
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            // Same week - show day name
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            // Same year - show month and day
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        } else {
            // Different year - show full date
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    /// Formats a date with time for detailed display
    /// - Parameter date: The date to format
    /// - Returns: A formatted string with date and time
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Formats a date for short display (e.g., "12/25")
    /// - Parameter date: The date to format
    /// - Returns: A short formatted string
    static func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

/// A comprehensive utility for Date operations used throughout the app
public extension Date {
    // MARK: - Day Comparisons
    
    /// Returns true if the date is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if the date is tomorrow
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    /// Returns true if the date is yesterday
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns true if the date is in the future (after now)
    var isFuture: Bool {
        return self > Date()
    }
    
    /// Returns true if the date is in the past (before now)
    var isPast: Bool {
        return self < Date()
    }
    
    /// Returns true if the date is in the current week
    var isInCurrentWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    // MARK: - Date Components
    
    /// Returns the start of the day (00:00:00) for this date
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day (23:59:59) for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    
    /// Returns the hour component of this date
    var hour: Int {
        return Calendar.current.component(.hour, from: self)
    }
    
    /// Returns the minute component of this date
    var minute: Int {
        return Calendar.current.component(.minute, from: self)
    }
    
    /// Returns the day component of this date
    var day: Int {
        return Calendar.current.component(.day, from: self)
    }
    
    /// Returns the weekday component of this date
    var weekday: Int {
        return Calendar.current.component(.weekday, from: self)
    }
    
    /// Returns the month component of this date
    var month: Int {
        return Calendar.current.component(.month, from: self)
    }
    
    /// Returns the year component of this date
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
    
    // MARK: - Date Manipulation
    
    /// Returns a new date by adding the specified number of days
    /// - Parameter days: Number of days to add (can be negative)
    /// - Returns: A new Date with days added
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    
    /// Returns a new date by adding the specified number of weeks
    /// - Parameter weeks: Number of weeks to add (can be negative)
    /// - Returns: A new Date with weeks added
    func adding(weeks: Int) -> Date {
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self)!
    }
    
    /// Returns a new date by adding the specified number of months
    /// - Parameter months: Number of months to add (can be negative)
    /// - Returns: A new Date with months added
    func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self)!
    }
    
    // MARK: - Week Dates
    
    /// Returns the first day of the week containing this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components)!
    }
    
    /// Returns the last day of the week containing this date
    var endOfWeek: Date {
        return startOfWeek.adding(days: 6)
    }
    
    /// Returns all the dates in the week containing this date
    var datesInWeek: [Date] {
        let calendar = Calendar.current
        let startOfWeek = self.startOfWeek
        
        return (0...6).map { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)!
        }
    }
    
    // MARK: - Month Dates
    
    /// Returns the first day of the month containing this date
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
    
    /// Returns the last day of the month containing this date
    var endOfMonth: Date {
        return startOfMonth.adding(months: 1).adding(days: -1)
    }
    
    /// Returns all the dates in the month containing this date
    var datesInMonth: [Date] {
        let calendar = Calendar.current
        let startOfMonth = self.startOfMonth
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        return range.map { day in
            let components = DateComponents(year: year, month: month, day: day)
            return calendar.date(from: components)!
        }
    }
    
    // MARK: - Formatting
    
    /// Returns a formatted string using the specified format
    /// - Parameter format: The date format string
    /// - Returns: A formatted date string
    func toString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    /// Returns a formatted string suitable for task display
    /// - Returns: A formatted date string
    func toTaskDisplayString() -> String {
        if isToday {
            return "Today"
        } else if isTomorrow {
            return "Tomorrow"
        } else if isInCurrentWeek {
            return toString(format: "EEEE")
        } else {
            return toString(format: "MMM d, yyyy")
        }
    }
    
    // MARK: - Time Classification
    
    /// Returns true if the time is in the morning (before noon)
    var isMorning: Bool {
        return hour < 12
    }
    
    /// Returns true if the time is in the afternoon (noon to 5 PM)
    var isAfternoon: Bool {
        return hour >= 12 && hour < 17
    }
    
    /// Returns true if the time is in the evening (5 PM to 9 PM)
    var isEvening: Bool {
        return hour >= 17 && hour < 21
    }
    
    /// Returns true if the time is at night (9 PM or later)
    var isNight: Bool {
        return hour >= 21
    }
    
    // MARK: - Relative Time
    
    /// Returns a string representation of the relative time from now
    /// - Returns: A string like "2 hours ago" or "in 3 days"
    func relativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    // MARK: - Time Intervals
    
    /// Returns the number of days between this date and another
    /// - Parameter date: The date to compare against
    /// - Returns: Number of days (absolute value)
    func daysBetween(date: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: self)
        let endDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return abs(components.day ?? 0)
    }
}
