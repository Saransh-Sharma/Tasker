import SwiftUI

struct TimelineCompactItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let capsuleHeight: CGFloat
    let layoutClass: LifeBoardLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(timelineRailText(for: item))
                .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
                .frame(width: metrics.compactTimeGutter, alignment: .trailing)

            Color.clear
                .frame(width: metrics.compactTimeToLaneGap)

            TimelineCapsule(item: item, row: row, palette: palette)
                .frame(width: metrics.compactLaneWidth, height: capsuleHeight)
                .frame(width: metrics.compactLaneWidth)
                .accessibilityHidden(true)

            Button {
                onTaskTap(item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timelineMetaText(for: row, item: item))
                        .font(.lifeboard(.meta).weight(row.temporalState == .currentTask ? .semibold : .medium))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(timelineTitleColor(for: row, item: item))
                        .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if row.utilityItems.isEmpty == false {
                        TimelineUtilityRow(items: row.utilityItems)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, metrics.compactContentLeadingPadding)
                .padding(.trailing, metrics.compactContentTrailingPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
            .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))
            .accessibilityHint("Opens the task details.")

            TimelineCompletionRing(
                color: timelineRingColor(for: row, palette: palette),
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
            .frame(width: metrics.compactTrailingLaneWidth, alignment: .center)
        }
    }
}
