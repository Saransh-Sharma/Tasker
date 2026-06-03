import SwiftUI

struct TimelineAgendaItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if item.source == .calendarEvent {
            TimelineMeetingBlockRow(
                item: item,
                row: row,
                isNested: false,
                action: { onTaskTap(item) }
            )
            .padding(.vertical, 10)
        } else {
            HStack(alignment: .top, spacing: 14) {
                TimelineCapsule(item: item, row: row, palette: palette)
                    .frame(width: metrics.agendaCapsuleWidth, height: 88)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(timelineMetaText(for: row, item: item))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(timelineMetaColor(for: row))
                    Button {
                        onTaskTap(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.lifeboard(row.temporalState == .currentTask ? .title3 : .headline))
                                .foregroundStyle(timelineTitleColor(for: row, item: item))
                                .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            if row.utilityItems.isEmpty == false {
                                TimelineUtilityRow(items: row.utilityItems)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
                    .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))
                    .accessibilityHint("Opens the task details.")
                }

                TimelineCompletionRing(
                    color: timelineRingColor(for: row, palette: palette),
                    isCompleted: item.isComplete,
                    isInteractive: true,
                    label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
                ) {
                    onToggleComplete(item)
                }
            }
            .padding(.vertical, 10)
        }
    }
}
