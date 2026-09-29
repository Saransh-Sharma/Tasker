import Foundation

extension TrackRootView {
    func trackerSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    static func duration(_ interval: TimeInterval) -> String {
        let elapsed = LifeBoardDuration.text(minutes: Int(interval) / 60)
        return String(localized: "\(elapsed) elapsed")
    }
}
