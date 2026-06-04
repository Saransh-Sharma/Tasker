import SwiftUI

enum TimelineItemVisuals {
    @MainActor
    static func metaColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.lifeboard.textTertiary.opacity(0.68) : Color.lifeboard.textSecondary
    }

    @MainActor
    static func titleColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.lifeboard.textSecondary.opacity(0.72) : Color.lifeboard.textPrimary
    }

    @MainActor
    static func accessoryColor(for item: TimelinePlanItem, isActive: Bool) -> Color {
        if item.isComplete {
            return Color.lifeboard.textSecondary.opacity(0.62)
        }
        return isActive ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary
    }
}
