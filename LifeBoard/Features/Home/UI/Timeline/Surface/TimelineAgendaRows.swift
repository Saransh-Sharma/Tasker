import SwiftUI

// The agenda presentation, which is the compact one without the spine.

// MARK: - DailyTimelineAgendaView

struct DailyTimelineAgendaView: View {
    let projection: TimelineDayProjection
    let layoutClass: LayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onAddTask: (Date?) -> Void
    let onScheduleInbox: () -> Void
    let stablePresentation: TimelineDayStablePresentation

    enum Entry: Identifiable {
        case anchor(TimelineAnchorItem)
        case gap(TimelineGap)
        case block(TimelineTimeBlock)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            case .block(let block):
                return "block:\(block.id)"
            }
        }
    }

    var entries: [Entry] {
        let beforeWakeBlocks = agendaBlocks(from: projection.beforeWakeItems)
        let blocks = agendaBlocks(from: projection.timedItems)
        let afterSleepBlocks = agendaBlocks(from: projection.afterSleepItems)
        let gaps = projection.actionableGaps.sorted { $0.startDate < $1.startDate }
        var blockIndex = 0
        var gapIndex = 0
        var result = beforeWakeBlocks.map(Entry.block)
        result.append(.anchor(projection.wakeAnchor))

        while blockIndex < blocks.count || gapIndex < gaps.count {
            if blockIndex >= blocks.count {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
                continue
            }
            if gapIndex >= gaps.count {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
                continue
            }
            if gaps[gapIndex].startDate <= blocks[blockIndex].startDate {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
            } else {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
            }
        }

        result.append(.anchor(projection.sleepAnchor))
        result.append(contentsOf: afterSleepBlocks.map(Entry.block))
        return result
    }

    init(
        projection: TimelineDayProjection,
        layoutClass: LayoutClass,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAnchorTap: @escaping (TimelineAnchorItem) -> Void,
        onAddTask: @escaping (Date?) -> Void,
        onScheduleInbox: @escaping () -> Void
    ) {
        self.projection = projection
        self.layoutClass = layoutClass
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAnchorTap = onAnchorTap
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.stablePresentation = TimelineDayStablePresentation(projection: projection)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                    switch entry {
                    case .anchor(let anchor):
                        TimelineAgendaAnchorRow(
                            anchor: anchor,
                            row: presentation.row(for: anchor),
                            onTap: { onAnchorTap(anchor) }
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .gap(let gap):
                        let suggestedDate = timelineSuggestedAddDate(for: gap, now: presentation.now)
                        TimelineGapPrompt(
                            gap: gap,
                            row: presentation.row(for: gap),
                            suggestedDate: suggestedDate,
                            onAddTask: { onAddTask(suggestedDate) },
                            onPlanBlock: onScheduleInbox
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .block(let block):
                        agendaBlockView(block, presentation: presentation)
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    }
                }
            }
        }
    }

    func agendaBlocks(from items: [TimelinePlanItem]) -> [TimelineTimeBlock] {
        let dayStart = Calendar.current.startOfDay(for: projection.date)
        return TimelineTimeBlock.make(from: items.compactMap { item in
            guard let startDate = item.startDate, let endDate = item.endDate else { return nil }
            let startMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: startDate).minute ?? 0)
            let endMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: endDate).minute ?? 0)
            return TimelineTimeBlock.Input(
                item: item,
                startDate: startDate,
                endDate: endDate,
                startMinute: startMinute,
                endMinute: max(endMinute, startMinute + 1),
                y: 0,
                height: 0
            )
        })
    }

    @ViewBuilder
    func agendaBlockView(
        _ block: TimelineTimeBlock,
        presentation: TimelineDayPresentation
    ) -> some View {
        switch block.kind {
        case .single(let item):
            TimelineAgendaItemRow(
                item: item,
                row: presentation.row(for: item),
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        case .conflict:
            TimelineTimeBlockCard(
                block: block,
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        }
    }
}

// MARK: - TimelineAgendaAnchorRow

struct TimelineAgendaAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let onTap: () -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if let style = TimelineRoutineAnchorVisualStyle.resolve(anchorID: anchor.id, title: anchor.title, subtitle: row.subtitle) {
            TimelineRoutineAnchorCard(
                style: style,
                timeText: TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact),
                onTap: onTap,
                minimumHeight: 112,
                leadingArtworkReserve: 112,
                accessibilityHint: TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint
            )
            .accessibilityIdentifier("home.timeline.anchor.\(anchor.id)")
        } else {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(TimelineVisualTokens.anchorCapsuleFill)
                        .frame(width: metrics.agendaAnchorCircleSize, height: metrics.agendaAnchorCircleSize)
                        .overlay {
                            Image(systemName: anchor.systemImageName)
                                .font(.system(size: metrics.agendaAnchorIconSize, weight: .semibold))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .accessibilityHidden(true)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(anchor.time.formatted(date: .omitted, time: .shortened))
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                        Text(anchor.title)
                            .font(.lifeboard(.title3))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        if let subtitle = row.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(TimelineVisualTokens.utilityText)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
            .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
        }
    }
}

// MARK: - TimelineAgendaItemRow

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
