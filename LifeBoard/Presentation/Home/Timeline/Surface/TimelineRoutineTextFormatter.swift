import SwiftUI

enum TimelineRoutineTextFormatter {
    static func subtitle(for anchor: TimelineAnchorItem, subtitle: String?, calendar: Calendar = .current) -> String {
        let timeText = TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact, calendar: calendar)
        guard let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              subtitle.isEmpty == false else {
            return timeText
        }
        return "\(timeText) · \(subtitle)"
    }
}
