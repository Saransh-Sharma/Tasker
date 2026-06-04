import SwiftUI

struct TimelineTaskBlockRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TimelineCapsule(item: item, row: row, palette: palette)
                .frame(width: 42, height: 58)
                .accessibilityHidden(true)

            Button {
                onTaskTap(item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TASK")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(TimelineItemVisuals.accessoryColor(for: item, isActive: row.temporalState == .currentTask))
                        .lineLimit(1)

                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(timelineTitleColor(for: row, item: item))
                        .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                        .lineLimit(2)

                    Text(timelineMetaText(for: row, item: item))
                        .font(.lifeboard(.support))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
            .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))

            TimelineCompletionRing(
                color: timelineRingColor(for: row, palette: palette),
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
            .frame(width: 34, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.lifeboard.surfacePrimary.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
        }
    }
}
