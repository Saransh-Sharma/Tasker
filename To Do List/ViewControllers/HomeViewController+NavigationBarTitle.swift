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
    func updateNavigationBarTitle(date: Date, score: Int) {
        // Format the date as "d MMM" (e.g., "29 Jun")
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        let dateString = formatter.string(from: date)

        // Add "Today" prefix when appropriate
        let titleDatePart: String = Calendar.current.isDateInToday(date) ? "Today · \(dateString)" : dateString

        // Compose final title string (e.g., "Today · 29 Jun  •  42")
        let composedTitle = "\(titleDatePart)  •  \(score)"

        // Prefer the dedicated label if it exists, else fall back to the navigationItem's title
        if let label = navigationTitleLabel {
            label.text = composedTitle
        } else {
            navigationItem.title = composedTitle
        }
    }
}
