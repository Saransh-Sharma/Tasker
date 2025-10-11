//
//  TaskRepeatPattern.swift
//  Tasker
//
//  Task repeat patterns for recurring tasks
//

import Foundation

/// Repeat patterns for recurring tasks
public enum TaskRepeatPattern: Codable, Equatable {
    case daily
    case weekdays // Monday to Friday
    case weekly(DaysOfWeek)
    case biweekly(DaysOfWeek)
    case monthly(MonthlyPattern)
    case yearly(YearlyPattern)
    case custom(CustomPattern)
    
    public struct DaysOfWeek: OptionSet, Codable {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let sunday = DaysOfWeek(rawValue: 1 << 0)
        public static let monday = DaysOfWeek(rawValue: 1 << 1)
        public static let tuesday = DaysOfWeek(rawValue: 1 << 2)
        public static let wednesday = DaysOfWeek(rawValue: 1 << 3)
        public static let thursday = DaysOfWeek(rawValue: 1 << 4)
        public static let friday = DaysOfWeek(rawValue: 1 << 5)
        public static let saturday = DaysOfWeek(rawValue: 1 << 6)
        
        public static let weekdays: DaysOfWeek = [.monday, .tuesday, .wednesday, .thursday, .friday]
        public static let weekends: DaysOfWeek = [.saturday, .sunday]
        public static let allDays: DaysOfWeek = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    }
    
    public enum MonthlyPattern: Codable, Equatable {
        case onDate(Int) // e.g., 15th of every month
        case onWeekday(weekOfMonth: Int, dayOfWeek: Int) // e.g., 2nd Tuesday
        case lastWeekday(dayOfWeek: Int) // e.g., last Friday
    }
    
    public enum YearlyPattern: Codable, Equatable {
        case onDate(month: Int, day: Int) // e.g., January 15th
        case onWeekday(month: Int, weekOfMonth: Int, dayOfWeek: Int) // e.g., 2nd Tuesday of March
    }
    
    public struct CustomPattern: Codable, Equatable {
        public let intervalDays: Int
        public let endDate: Date?
        public let maxOccurrences: Int?
        
        public init(intervalDays: Int, endDate: Date? = nil, maxOccurrences: Int? = nil) {
            self.intervalDays = intervalDays
            self.endDate = endDate
            self.maxOccurrences = maxOccurrences
        }
    }
    
    // MARK: - Helper Methods
    
    public var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays (Mon-Fri)"
        case .weekly(let days):
            return "Weekly (\(days.displayName))"
        case .biweekly(let days):
            return "Biweekly (\(days.displayName))"
        case .monthly(let pattern):
            return "Monthly (\(pattern.displayName))"
        case .yearly(let pattern):
            return "Yearly (\(pattern.displayName))"
        case .custom(let pattern):
            return "Every \(pattern.intervalDays) days"
        }
    }
    
    /// Calculate next occurrence after given date
    public func nextOccurrence(after date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
            
        case .weekdays:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
            let weekday = calendar.component(.weekday, from: tomorrow)
            
            // If tomorrow is Saturday (7), move to Monday (+2 days)
            // If tomorrow is Sunday (1), move to Monday (+1 day)
            if weekday == 7 { // Saturday
                return calendar.date(byAdding: .day, value: 2, to: tomorrow)
            } else if weekday == 1 { // Sunday
                return calendar.date(byAdding: .day, value: 1, to: tomorrow)
            } else {
                return tomorrow
            }
            
        case .weekly(let days):
            return nextWeeklyOccurrence(after: date, days: days)
            
        case .biweekly(let days):
            return nextBiweeklyOccurrence(after: date, days: days)
            
        case .monthly(let pattern):
            return nextMonthlyOccurrence(after: date, pattern: pattern)
            
        case .yearly(let pattern):
            return nextYearlyOccurrence(after: date, pattern: pattern)
            
        case .custom(let pattern):
            return calendar.date(byAdding: .day, value: pattern.intervalDays, to: date)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func nextWeeklyOccurrence(after date: Date, days: DaysOfWeek) -> Date? {
        let calendar = Calendar.current
        
        for i in 1...7 {
            guard let nextDate = calendar.date(byAdding: .day, value: i, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: nextDate)
            let dayOfWeek = DaysOfWeek(rawValue: 1 << (weekday - 1))
            
            if days.contains(dayOfWeek) {
                return nextDate
            }
        }
        
        return nil
    }
    
    private func nextBiweeklyOccurrence(after date: Date, days: DaysOfWeek) -> Date? {
        // First try next week
        if let nextWeek = nextWeeklyOccurrence(after: date, days: days) {
            return nextWeek
        }
        
        // Then try the week after
        let calendar = Calendar.current
        guard let twoWeeksLater = calendar.date(byAdding: .weekOfYear, value: 2, to: date) else { return nil }
        return nextWeeklyOccurrence(after: twoWeeksLater, days: days)
    }
    
    private func nextMonthlyOccurrence(after date: Date, pattern: MonthlyPattern) -> Date? {
        let calendar = Calendar.current
        
        switch pattern {
        case .onDate(let day):
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { return nil }
            return calendar.date(bySetting: .day, value: day, of: nextMonth)
            
        case .onWeekday(let weekOfMonth, let dayOfWeek):
            // Complex calculation for nth weekday of month
            return nil // Simplified for now
            
        case .lastWeekday(let dayOfWeek):
            // Complex calculation for last weekday of month
            return nil // Simplified for now
        }
    }
    
    private func nextYearlyOccurrence(after date: Date, pattern: YearlyPattern) -> Date? {
        let calendar = Calendar.current
        
        switch pattern {
        case .onDate(let month, let day):
            guard let nextYear = calendar.date(byAdding: .year, value: 1, to: date) else { return nil }
            var components = calendar.dateComponents([.year], from: nextYear)
            components.month = month
            components.day = day
            return calendar.date(from: components)
            
        case .onWeekday(let month, let weekOfMonth, let dayOfWeek):
            // Complex calculation for nth weekday of specific month
            return nil // Simplified for now
        }
    }
}

// MARK: - Extensions

extension TaskRepeatPattern.DaysOfWeek {
    public var displayName: String {
        var days: [String] = []
        
        if contains(.sunday) { days.append("Sun") }
        if contains(.monday) { days.append("Mon") }
        if contains(.tuesday) { days.append("Tue") }
        if contains(.wednesday) { days.append("Wed") }
        if contains(.thursday) { days.append("Thu") }
        if contains(.friday) { days.append("Fri") }
        if contains(.saturday) { days.append("Sat") }
        
        return days.joined(separator: ", ")
    }
}

extension TaskRepeatPattern.MonthlyPattern {
    public var displayName: String {
        switch self {
        case .onDate(let day):
            return "on \(day)th"
        case .onWeekday(let week, let dayOfWeek):
            return "\(week.ordinal) \(dayOfWeek.weekdayName)"
        case .lastWeekday(let dayOfWeek):
            return "last \(dayOfWeek.weekdayName)"
        }
    }
}

extension TaskRepeatPattern.YearlyPattern {
    public var displayName: String {
        switch self {
        case .onDate(let month, let day):
            return "\(month.monthName) \(day)"
        case .onWeekday(let month, let week, let dayOfWeek):
            return "\(week.ordinal) \(dayOfWeek.weekdayName) of \(month.monthName)"
        }
    }
}

// MARK: - Private Extensions

private extension Int {
    var ordinal: String {
        switch self {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(self)th"
        }
    }
    
    var weekdayName: String {
        let weekdays = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekdays[safe: self] ?? "Unknown"
    }
    
    var monthName: String {
        let months = ["", "January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        return months[safe: self] ?? "Unknown"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}