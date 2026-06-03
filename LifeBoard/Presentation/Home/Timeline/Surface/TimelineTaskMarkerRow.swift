import SwiftUI

struct TimelineTaskMarkerRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let isEmphasized: Bool
    let spineIconCenterX: CGFloat
    let completionX: CGFloat
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    static let iconCenterYOffset: CGFloat = TimelineTaskMarkerLayout.iconCenterYOffset

    let iconContainer: CGFloat = 24
    let iconSize: CGFloat = 18
    let textLeadingOffset: CGFloat = 30
    let visibleCompletionSize: CGFloat = 24
    var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if isEmphasized {
                                Image(systemName: item.taskPriority == .max ? "exclamationmark.triangle.fill" : "flag.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(palette.icon)
                                    .accessibilityHidden(true)
                            }
                            Text(item.title)
                                .font(.lifeboard(.headline).weight(isEmphasized ? .bold : .semibold))
                                .foregroundStyle(timelineTitleColor(for: row, item: item))
                                .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(2)
                        }

                        Text(timeText)
                            .font(.lifeboard(.caption1).weight(.medium))
                            .foregroundStyle(timelineMetaColor(for: row))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: spineIconCenterX + textLeadingOffset, y: 5)

            Circle()
                .fill(markerFill)
                .frame(width: iconContainer, height: iconContainer)
                .overlay {
                    Image(systemName: item.systemImageName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(markerIconColor)
                        .accessibilityHidden(true)
                }
                .overlay {
                    Circle()
                        .stroke(markerStroke, lineWidth: isEmphasized ? 1.5 : 1)
                }
                .offset(
                    x: spineIconCenterX - (iconContainer / 2),
                    y: Self.iconCenterYOffset - (iconContainer / 2)
                )
                .accessibilityHidden(true)

            TimelineCompletionRing(
                color: timelineRingColor(for: row, palette: palette),
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete()
            }
            .scaleEffect(visibleCompletionSize / 28)
            .frame(width: 44, height: 44)
            .offset(x: completionX - 22, y: 6)
        }
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))
        .accessibilityHint("Opens the task details.")
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    var markerFill: Color {
        if row.temporalState == .currentTask {
            return palette.progress
        }
        if isEmphasized {
            return palette.fill.opacity(0.98)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.96)
    }

    var markerIconColor: Color {
        row.temporalState == .currentTask ? Color.white.opacity(0.96) : palette.icon
    }

    var markerStroke: Color {
        isEmphasized ? palette.progress.opacity(0.8) : palette.halo.opacity(0.58)
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}
