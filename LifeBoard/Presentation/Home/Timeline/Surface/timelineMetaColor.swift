import SwiftUI

@MainActor
func timelineMetaColor(for row: TimelineRenderableRow) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.lifeboard.textTertiary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.statusWarning.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary.opacity(0.92)
    default:
        return TimelineVisualTokens.metaText
    }
}
