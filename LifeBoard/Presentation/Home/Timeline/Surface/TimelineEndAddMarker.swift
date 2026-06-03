import SwiftUI

struct TimelineEndAddMarker: View {
    let suggestedDate: Date
    let accessibilityValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.55))
                .frame(width: TimelineCanvasLayoutPlan.endMarkerHitArea, height: TimelineCanvasLayoutPlan.endMarkerHitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task after timeline")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens Add Task with a suggested timeline time.")
        .accessibilityIdentifier("home.timeline.endAdd")
    }
}
