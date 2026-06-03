import SwiftUI

@MainActor
func timelineTitleColor(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.lifeboard.textSecondary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.textPrimary.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary
    default:
        if let item {
            return TimelineItemVisuals.titleColor(for: item)
        }
        return Color.lifeboard.textPrimary
    }
}
