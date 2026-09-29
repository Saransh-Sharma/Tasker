import Foundation

extension TrackerAggregation {
    var displayName: String {
        switch self {
        case .latest: String(localized: "Latest")
        case .sum: String(localized: "Total")
        case .average: String(localized: "Average")
        case .minimum: String(localized: "Minimum")
        case .maximum: String(localized: "Maximum")
        case .count: String(localized: "Entry count")
        }
    }
}

extension TrackerPrivacyClass {
    var displayName: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .personal: String(localized: "Personal")
        case .sensitive: String(localized: "Sensitive")
        }
    }
}
