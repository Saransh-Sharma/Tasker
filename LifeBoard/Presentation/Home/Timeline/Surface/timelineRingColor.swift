import SwiftUI

@MainActor
func timelineRingColor(for row: TimelineRenderableRow, palette: TimelinePalette) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return palette.progress
    case .pastIncomplete:
        return palette.base.opacity(0.74)
    case .currentTask:
        return palette.progress
    default:
        return palette.ring
    }
}
