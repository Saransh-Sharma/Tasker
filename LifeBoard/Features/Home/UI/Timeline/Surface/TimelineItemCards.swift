import SwiftUI

// Cards for a single scheduled thing: tasks, meetings, and blocks.

// MARK: - TimelineNormalItemCard

struct TimelineNormalItemCard: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let title: String
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onTap) {
                ZStack(alignment: .trailing) {
                    watermarkIcon(size: 72, trailingOffset: 18)

                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: item.systemImageName)
                            .lifeboardFont(.headline)
                            .foregroundStyle(palette.icon)
                            .frame(width: 28, height: 28)
                            .background(palette.fill.opacity(0.92), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.lifeboard(.headline).weight(.semibold))
                                .foregroundStyle(timelineTitleColor(for: row, item: item))
                                .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(2)

                            Text(timeText)
                                .font(.lifeboard(.caption1).weight(.medium))
                                .foregroundStyle(timelineMetaColor(for: row))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if item.source == .task {
                            Color.clear
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.progress.opacity(0.78))
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.lifeboard.strokeHairline.opacity(0.58), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
            .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : item.source == .calendarEvent ? "Calendar event" : "Scheduled"))
            .accessibilityHint("Opens the item details.")
            .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
            .accessibilityAction(named: Text("Open")) {
                onTap()
            }
            .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
                guard item.source == .task else { return }
                onToggleComplete()
            }

            if item.source == .task {
                TimelineCompletionRing(
                    color: timelineRingColor(for: row, palette: palette),
                    isCompleted: item.isComplete,
                    isInteractive: true,
                    label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
                ) {
                    onToggleComplete()
                }
                .padding(.trailing, 12)
            }
        }
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }

    var cardBackground: Color {
        if item.source == .task {
            return palette.base.opacity(0.12)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.95)
    }

    @ViewBuilder
    func watermarkIcon(size: CGFloat, trailingOffset: CGFloat) -> some View {
        if item.source == .task, let lifeAreaSystemImageName = item.lifeAreaSystemImageName {
            Image(systemName: lifeAreaSystemImageName)
                .font(.system(size: size, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.base.opacity(0.14))
                .offset(x: trailingOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - TimelineMeetingBlockRow

struct TimelineMeetingBlockRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let isNested: Bool
    let action: () -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var accessibilityKind: String { item.isMeetingLike ? "Meeting" : "Calendar" }
    var iconName: String { item.isMeetingLike ? "person.3.fill" : "calendar" }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: isNested ? 10 : 11) {
                Circle()
                    .fill(palette.fill.opacity(0.92))
                    .frame(width: isNested ? 34 : 38, height: isNested ? 34 : 38)
                    .overlay {
                        Image(systemName: iconName)
                            .lifeboardFont(isNested ? .buttonSmall : .headline)
                            .foregroundStyle(palette.icon)
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(2)

                    Text(meetingMetadata)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .layoutPriority(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, isNested ? 10 : 11)
            .padding(.vertical, isNested ? 8 : 9)
            .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.78))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.68), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(meetingMetadata)")
        .accessibilityValue(accessibilityKind)
        .accessibilityHint("Opens the calendar item.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
    }

    var meetingMetadata: String {
        if let start = item.startDate, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return ""
    }
}

// MARK: - TimelineTaskBlockRow

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

// MARK: - TimelineTaskMarkerLayout

enum TimelineTaskMarkerLayout {
    static let iconCenterYOffset: CGFloat = 26
}

// MARK: - TimelineTaskMarkerRow

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
                                    .lifeboardFont(.eyebrow)
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
                    Image(systemName: markerSystemImageName)
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
        row.temporalState == .currentTask ? Color.lifeboard(.textInverse).opacity(0.96) : palette.icon
    }

    var markerStroke: Color {
        isEmphasized ? palette.progress.opacity(0.8) : palette.halo.opacity(0.58)
    }

    var markerSystemImageName: String {
        guard item.source == .task else { return item.systemImageName }
        return item.isComplete ? "checkmark.square.fill" : "square"
    }

    var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}

// MARK: - TimelineTimeBlockCard

struct TimelineTimeBlockCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Time Block Conflict: \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text(block.countLabel)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentOnPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.lifeboard.accentPrimary.opacity(0.82), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(block.items) { item in
                    if item.source == .calendarEvent {
                        TimelineMeetingBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            isNested: true,
                            action: { onTaskTap(item) }
                        )
                    } else {
                        TimelineTaskBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            onTaskTap: onTaskTap,
                            onToggleComplete: onToggleComplete
                        )
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.92))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.lifeboard.accentPrimary.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.76), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time block conflict, \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.conflictBlock")
    }
}
