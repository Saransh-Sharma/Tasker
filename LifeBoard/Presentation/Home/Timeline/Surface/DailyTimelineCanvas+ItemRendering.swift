import SwiftUI

extension DailyTimelineCanvas {
    @ViewBuilder
    func timelineItemView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedItem,
        row: TimelineRenderableRow,
        itemX: CGFloat,
        itemWidth: CGFloat,
        timeGutterWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        spineCenterX: CGFloat,
        completionX: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        let item = positioned.item
        let isActive = row.temporalState == .currentTask
        let palette = TimelinePalette.resolve(from: item.tintHex)
        let capsuleWidth = max(min(itemWidth * 0.24, metrics.expandedCapsuleMinWidth), metrics.expandedCapsuleMinWidth)
        let overlapCapsuleOffset = CGFloat(positioned.columnIndex) * min(itemWidth * 0.18, 18)
        let capsuleX = spineCenterX - (capsuleWidth / 2) + overlapCapsuleOffset
        let textX = max(itemX, capsuleX + capsuleWidth + 14)
        let availableTextWidth = max(min((itemX + itemWidth) - textX, contentWidth + contentX - textX), 84)
        let textMaxWidth = positioned.columnCount > 1 ? metrics.expandedOverlappingTextMaxWidth : metrics.expandedSingleColumnTextMaxWidth
        let textWidth = min(availableTextWidth, textMaxWidth)

        Text(timeLabel(for: item))
            .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
            .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

        TimelineCapsule(item: item, row: row, palette: palette)
            .frame(width: capsuleWidth, height: positioned.height)
            .offset(x: capsuleX, y: positioned.y)

        Button {
            onTaskTap(item)
        } label: {
            timelineItemTextContent(row: row, item: item, isExpanded: true)
                .frame(width: textWidth, alignment: .leading)
                .frame(minHeight: positioned.height, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: textX, y: positioned.y)
        .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: row, item: item))
            .accessibilityValue(item.isComplete ? "Completed" : (isActive ? "In progress" : "Scheduled"))
            .accessibilityHint("Opens the task details.")

        TimelineCompletionRing(
            color: ringColor(for: row, palette: palette),
            isCompleted: item.isComplete,
            isInteractive: item.source == .task,
            label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
        ) {
            onToggleComplete(item)
        }
        .offset(
            x: completionX - 22,
            y: positioned.y + max((positioned.height / 2) - 22, 6)
        )
    }

    func shouldHideTimeLabel(at labelY: CGFloat, currentY: CGFloat?) -> Bool {
        guard let currentY else { return false }
        return abs(labelY - currentY) < 16
    }

    @ViewBuilder
    func timelineItemTextContent(row: TimelineRenderableRow, item: TimelinePlanItem, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metaText(for: row, item: item))
                .font(.lifeboard(row.temporalState == .currentTask && isExpanded ? .callout : .meta).weight(row.temporalState == .currentTask ? .semibold : .medium))
                .foregroundStyle(metaColor(for: row, item: item))
                .multilineTextAlignment(.leading)
                .lineLimit(1)

            Text(item.title)
                .font(.lifeboard(isExpanded && row.temporalState == .currentTask ? .title3 : .headline))
                .foregroundStyle(titleColor(for: row, item: item))
                .strikethrough(item.isComplete, color: titleColor(for: row, item: item))
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if row.utilityItems.isEmpty == false {
                TimelineUtilityRow(items: row.utilityItems)
            }
        }
    }

    func timeLabel(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate else { return "All day" }
        return TimelineRailTimeFormatter.railText(forItemStart: start)
    }

    func railLabelKind(for item: TimelinePlanItem) -> TimelineRailLabelKind {
        guard let start = item.startDate else { return .exact }
        return railLabelKind(for: start)
    }

    func railLabelKind(for date: Date) -> TimelineRailLabelKind {
        Calendar.current.component(.minute, from: date) == 0 ? .compactHour : .exact
    }

    func metaText(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil, anchor: TimelineAnchorItem? = nil) -> String {
        switch row.metadataMode {
        case .remainingTime(let minutes):
            return "\(minutes)m remaining"
        case .done:
            guard let item, let start = item.startDate, let end = item.endDate else { return "Done" }
            let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
            return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened)) · \(durationText) · Done"
        case .scheduled, .none:
            if let anchor {
                return anchor.time.formatted(date: .omitted, time: .shortened)
            }
            guard let item, let start = item.startDate, let end = item.endDate else { return "All day" }
            let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
            return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened)) · \(durationText)"
        }
    }

    func metaColor(for row: TimelineRenderableRow, item: TimelinePlanItem) -> Color {
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

    func titleColor(for row: TimelineRenderableRow, item: TimelinePlanItem) -> Color {
        switch row.temporalState {
        case .pastCompleted:
            return Color.lifeboard.textSecondary.opacity(0.72)
        case .pastIncomplete:
            return Color.lifeboard.textPrimary.opacity(0.92)
        case .currentTask:
            return Color.lifeboard.textPrimary
        default:
            return TimelineItemVisuals.titleColor(for: item)
        }
    }

    func ringColor(for row: TimelineRenderableRow, palette: TimelinePalette) -> Color {
        switch row.temporalState {
        case .pastCompleted:
            return palette.progress
        case .pastIncomplete:
            return palette.base.opacity(0.7)
        case .currentTask:
            return palette.progress
        default:
            return palette.ring
        }
    }

    func accessibilityLabel(for row: TimelineRenderableRow, item: TimelinePlanItem) -> String {
        var parts = [item.title]
        parts.append(metaText(for: row, item: item))
        if row.utilityItems.isEmpty == false {
            parts.append(row.utilityItems.map(\.accessibilityLabel).joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}
