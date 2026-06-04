import SwiftUI

func timelineAccessibilityIdentifier(for item: TimelinePlanItem) -> String {
    if let eventID = item.eventID {
        return "home.timeline.event.\(eventID)"
    }
    if let taskID = item.taskID {
        return "home.timeline.task.\(taskID.uuidString)"
    }
    return "home.timeline.item.\(item.id)"
}
