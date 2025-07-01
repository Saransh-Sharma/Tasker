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
            // Convert suffix letters to Unicode superscript where possible
            func superscript(_ letters: String) -> String {
                let map: [Character: Character] = [
                    "s": "ˢ", // U+02E2
                    "t": "ᵗ", // U+1D57
                    "n": "ⁿ", // U+207F
                    "d": "ᵈ", // U+1D48
                    "r": "ʳ", // U+02B3
                    "h": "ʰ"  // U+02B0
                ]
                return String(letters.compactMap { map[$0] })
            }
            return "\(day)\(superscript(suffix))"
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

        // Build two-line attributed string
        let dateLine = "\(datePrefix)\(dateBody)"
        let scoreLine = xpString

        let attributed = NSMutableAttributedString(
            string: dateLine + "\n",
            attributes: [
                // .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold)
            ])
        attributed.append(NSAttributedString(
            string: scoreLine,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .thin)
            ]))

        // Ensure label exists and is configured only once
        let label: UILabel
        if let existing = navigationTitleLabel {
            label = existing
            // Ensure proper styling (in case it was lost)
            label.numberOfLines = 2
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.textColor = .white
            label.lineBreakMode = .byWordWrapping
        } else {
            let newLabel = UILabel()
            newLabel.numberOfLines = 2
            newLabel.textAlignment = .center
            newLabel.adjustsFontSizeToFitWidth = true
            newLabel.minimumScaleFactor = 0.5
            newLabel.textColor = .white
            newLabel.lineBreakMode = .byWordWrapping
            navigationTitleLabel = newLabel
            label = newLabel
        }
        label.attributedText = attributed
        label.sizeToFit()
        // Clear legacy title to prevent FluentUI large-leading label
        navigationItem.title = ""
        // Attach to navigation bar directly to avoid being hidden behind FluentUI accessory views
        if let navBar = navigationController?.navigationBar {
            if label.superview != navBar {
                label.translatesAutoresizingMaskIntoConstraints = false
                navBar.addSubview(label)
                NSLayoutConstraint.activate([
                    label.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
                    label.centerYAnchor.constraint(equalTo: navBar.centerYAnchor)
                ])
            }
            // Make sure it stays on top of other subviews
            label.layer.zPosition = 800
        }
    }
}
