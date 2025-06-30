import UIKit
import Foundation

// MARK: - Navigation Bar Title Helper
/// Provides a dedicated helper to format and update the navigation bar title
/// with the selected date and its corresponding daily score.
extension HomeViewController {
    /// Updates the navigation bar title or `navigationTitleLabel` with a formatted string combining the date and score.
    /// - Parameters:
    ///   - date: The date to show in the title.
    ///   - score: The daily score value to embed.
    /// Updates the navigation bar title with rich, context-aware messaging.
    /// The title adapts to different date contexts (Today, Yesterday, Tomorrow,
    /// past dates, upcoming dates) and to whether the score for that date is
    /// zero or non-zero.
    ///
    /// Desired examples:
    ///   • Today (non-zero):   "It’s Monday, June 30th • 87 XP gained!"
    ///   • Today (zero):       "It’s Monday, June 30th • Your task streak awaits!"
    ///   • Yesterday:          "Yesterday, Sun, June 29 • 87 XP gained!"
    ///   • Tomorrow:           "Tomorrow, Sun, June 29 • Plan ahead!"
    ///   • Upcoming (non-zero):"Wed, July 3rd • 42 XP planned"
    ///   • Upcoming (zero):    "Wed, July 3rd • Plan ahead!"
    ///
    /// - Parameters:
    ///   - date:  The date the user is viewing.
    ///   - score: The XP score (task completion score) for that date.
    func updateNavigationBarTitle(date: Date, score: Int) {
        let calendar = Calendar.current
        let today = Date.today()

        // Helper for ordinal day suffix (1st, 2nd, 3rd …)
        func ordinalDay(for date: Date) -> String {
            let day = calendar.component(.day, from: date)
            let suffix: String
            switch day {
            case 11, 12, 13:
                suffix = "th"
            default:
                switch day % 10 {
                case 1: suffix = "st"
                case 2: suffix = "nd"
                case 3: suffix = "rd"
                default: suffix = "th"
                }
            }
            return "\(day)\(suffix)"
        }

        // Format parts we’ll need
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE"
        let shortWeekdayFormatter = DateFormatter()
        shortWeekdayFormatter.dateFormat = "EEE"
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"

        let fullWeekday = weekdayFormatter.string(from: date) // Monday
        let shortWeekday = shortWeekdayFormatter.string(from: date) // Mon
        let monthName = monthFormatter.string(from: date) // June
        let dayOrdinal = ordinalDay(for: date)            // 30th

        // Build the date portion of the title depending on context
        var datePrefix = ""
        var dateBody  = ""

        if calendar.isDate(date, inSameDayAs: today) {
            // Today
            datePrefix = "It’s "
            dateBody = "\(fullWeekday), \(monthName) \(dayOrdinal)"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
            // Yesterday
            datePrefix = "Yesterday, "
            dateBody = "\(shortWeekday), \(monthName) \(dayOrdinal)"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today)!) {
            // Tomorrow
            datePrefix = "Tomorrow, "
            dateBody = "\(shortWeekday), \(monthName) \(dayOrdinal)"
        } else {
            // Other past or upcoming dates
            dateBody = "\(shortWeekday), \(monthName) \(dayOrdinal)"
        }

        // Build the score / encouragement part
        let isFuture = date > today && !calendar.isDateInToday(date)
        let xpString: String
        if score == 0 {
            if calendar.isDateInToday(date) {
                xpString = "Your task streak awaits!"
            } else if isFuture {
                xpString = "Plan ahead!"
            } else {
                xpString = "No XP recorded"
            }
        } else {
            xpString = isFuture ? "\(score) XP planned" : "\(score) XP gained!"
        }

        let composedTitle = "\(datePrefix)\(dateBody) • \(xpString)"

        // Prefer dedicated label if present (allows custom styling), else fallback
        if let label = navigationTitleLabel {
            label.text = composedTitle
        } else {
            navigationItem.title = composedTitle
        }
    }
}
