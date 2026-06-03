import SwiftUI

extension TimelineUtilityItem {
    var accessibilityLabel: String {
        switch self {
        case .checklist(let summary):
            return "\(summary.completedCount) of \(summary.totalCount) checklist items complete"
        case .note:
            return "Has notes"
        case .recurring:
            return "Recurring"
        case .calendar:
            return "Calendar event"
        case .meeting:
            return "Meeting"
        case .project(let name):
            return name
        }
    }
}
