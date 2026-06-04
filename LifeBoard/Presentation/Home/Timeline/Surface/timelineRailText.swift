import SwiftUI

func timelineRailText(for item: TimelinePlanItem) -> String {
    guard let start = item.startDate else { return "All day" }
    return start.formatted(date: .omitted, time: .shortened)
}
