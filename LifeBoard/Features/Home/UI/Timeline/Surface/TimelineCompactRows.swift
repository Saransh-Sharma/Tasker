import SwiftUI

// The compact presentation: one row type per kind of thing a day holds.

// MARK: - DailyTimelineCompactView

struct DailyTimelineCompactView: View {
    let projection: TimelineDayProjection
    let layoutClass: LayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onAddTask: (Date?) -> Void
    let onScheduleInbox: () -> Void

    let plan: TimelineCompactLayoutPlan
    let stablePresentation: TimelineDayStablePresentation
    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

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
        let interval = PerformanceTrace.begin("HomeTimelineCompactPlanBuild")
        self.plan = TimelineCompactLayoutPlan(projection: projection, layoutClass: layoutClass)
        PerformanceTrace.end(interval)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)

            let content = VStack(alignment: .leading, spacing: 0) {
                ForEach(plan.entries.indices, id: \.self) { index in
                    rowView(for: plan.entries[index], presentation: presentation)

                    if index < plan.entries.count - 1 {
                        connector(
                            trailing: row(for: plan.entries[index], presentation: presentation).stemTrailing,
                            leading: row(for: plan.entries[index + 1], presentation: presentation).stemLeading
                        )
                    }
                }
            }
            .padding(.top, plan.topInset)
            .padding(.bottom, plan.bottomInset)
            .frame(minHeight: plan.contentHeight, alignment: .top)

            if let readableWidth = metrics.compactReadableWidth, layoutClass == .padCompact {
                content
                    .frame(maxWidth: readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    func rowView(for entry: TimelineCompactLayoutPlan.Entry, presentation: TimelineDayPresentation) -> some View {
        switch entry {
        case .anchor(let anchor):
            TimelineCompactAnchorRow(
                anchor: anchor.anchor,
                row: presentation.row(for: anchor.anchor),
                layoutClass: layoutClass,
                onTap: { onAnchorTap(anchor.anchor) }
            )
            .frame(minHeight: anchor.rowHeight, alignment: .center)
        case .item(let item):
            TimelineCompactItemRow(
                item: item.item,
                row: presentation.row(for: item.item),
                capsuleHeight: item.capsuleHeight,
                layoutClass: layoutClass,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
            .frame(minHeight: item.rowHeight, alignment: .center)
        case .gap(let gap):
            let suggestedDate = timelineSuggestedAddDate(for: gap.gap, now: presentation.now)
            TimelineCompactGapRow(
                gap: gap.gap,
                row: presentation.row(for: gap.gap),
                layoutClass: layoutClass,
                onAddTask: { onAddTask(suggestedDate) },
                onScheduleInbox: onScheduleInbox
            )
            .frame(minHeight: gap.rowHeight, alignment: .center)
        }
    }

    func row(for entry: TimelineCompactLayoutPlan.Entry, presentation: TimelineDayPresentation) -> TimelineRenderableRow {
        switch entry {
        case .anchor(let anchor):
            return presentation.row(for: anchor.anchor)
        case .item(let item):
            return presentation.row(for: item.item)
        case .gap(let gap):
            return presentation.row(for: gap.gap)
        }
    }

    func connector(trailing: TimelineStemSegmentState, leading: TimelineStemSegmentState) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: metrics.compactTimeGutter + metrics.compactTimeToLaneGap, height: plan.connectorHeight)

            TimelineCompactConnector(
                laneWidth: metrics.compactLaneWidth,
                height: plan.connectorHeight,
                topState: trailing,
                bottomState: leading
            )

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - TimelineCompactAnchorRow

struct TimelineCompactAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let layoutClass: LayoutClass
    let onTap: () -> Void

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if let style = TimelineRoutineAnchorVisualStyle.resolve(anchorID: anchor.id, title: anchor.title, subtitle: row.subtitle) {
            HStack(alignment: .center, spacing: 0) {
                Text(anchor.time.formatted(date: .omitted, time: .shortened))
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)
                    .accessibilityHidden(true)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Circle()
                    .fill(style.borderColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(LBColorTokens.whiteStroke.opacity(0.72), lineWidth: 2)
                    }
                    .frame(width: metrics.compactLaneWidth)
                    .accessibilityHidden(true)

                TimelineRoutineAnchorCard(
                    style: style,
                    timeText: TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact),
                    onTap: onTap,
                    minimumHeight: 92,
                    leadingArtworkReserve: 76,
                    accessibilityHint: TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint
                )
                .accessibilityIdentifier("home.timeline.anchor.\(anchor.id)")

                if anchor.isActionable {
                    TimelineCompletionRing(
                        color: Color.lifeboard.accentPrimary,
                        isCompleted: false,
                        isInteractive: false,
                        label: anchor.title,
                        action: {}
                    )
                    .frame(width: metrics.compactTrailingLaneWidth, alignment: .center)
                } else {
                    Color.clear
                        .frame(width: metrics.compactTrailingLaneWidth, height: 1)
                }
            }
        } else {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 0) {
                    Text(anchor.time.formatted(date: .omitted, time: .shortened))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                    Color.clear
                        .frame(width: metrics.compactTimeToLaneGap)

                    Circle()
                        .fill(TimelineVisualTokens.anchorCapsuleFill)
                        .frame(width: metrics.compactAnchorCircleSize, height: metrics.compactAnchorCircleSize)
                        .overlay {
                            Image(systemName: anchor.systemImageName)
                                .font(.system(size: metrics.compactAnchorIconSize, weight: .semibold))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(width: metrics.compactLaneWidth)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(anchor.title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        if let subtitle = row.subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(TimelineVisualTokens.utilityText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 12)

                    if anchor.isActionable {
                        TimelineCompletionRing(
                            color: Color.lifeboard.accentPrimary,
                            isCompleted: false,
                            isInteractive: false,
                            label: anchor.title,
                            action: {}
                        )
                        .frame(width: metrics.compactTrailingLaneWidth, alignment: .center)
                    } else {
                        Color.clear
                            .frame(width: metrics.compactTrailingLaneWidth, height: 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
            .accessibilityValue(anchor.id == "wake" ? "Timeline start" : "Timeline end")
            .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
        }
    }
}

// MARK: - TimelineCompactConnector

struct TimelineCompactConnector: View {
    let laneWidth: CGFloat
    let height: CGFloat
    let topState: TimelineStemSegmentState
    let bottomState: TimelineStemSegmentState
    let spec = TimelineRailPresentationSpec.compactConnector

    var body: some View {
        ZStack {
            Path { path in
                let x = laneWidth / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(
                Color.lifeboard.strokeHairline.opacity(spec.opacity),
                style: StrokeStyle(lineWidth: spec.lineWidth)
            )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(timelineStemColor(for: topState, fallbackPalette: .resolve(from: nil)))
                    .frame(width: spec.lineWidth, height: height / 2)
                Rectangle()
                    .fill(timelineStemColor(for: bottomState, fallbackPalette: .resolve(from: nil)))
                    .frame(width: spec.lineWidth, height: height / 2)
            }
        }
        .frame(width: laneWidth, height: height)
    }
}

// MARK: - TimelineCompactGapRow

struct TimelineCompactGapRow: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let layoutClass: LayoutClass
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        Menu {
            Button(TimelineGapAction.addTask.title, action: onAddTask)
            Button("Place inbox with Compass", action: onScheduleInbox)
            Button(TimelineGapAction.dismiss.title, role: .destructive) {}
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text(gap.startDate.formatted(date: .omitted, time: .shortened))
                    .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                    .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText.opacity(0.92))
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: metrics.compactLaneWidth)
                    .accessibilityHidden(true)

                timelineGapPromptText(for: gap, row: row)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.vertical, 6)
                    .padding(.leading, metrics.compactContentLeadingPadding)
                    .padding(.trailing, metrics.compactContentTrailingPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityLabel("\(gap.headline), \(gap.supportingText), \(gap.compactDurationText)")
                }
            }
        .buttonStyle(.plain)
    }
}

// MARK: - TimelineCompactItemRow

struct TimelineCompactItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let capsuleHeight: CGFloat
    let layoutClass: LayoutClass
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

// MARK: - TimelineCompactLayoutPlan

struct TimelineCompactLayoutPlan: Equatable {
    struct PositionedAnchor: Equatable, Identifiable {
        let anchor: TimelineAnchorItem
        let rowHeight: CGFloat

        var id: String { anchor.id }
    }

    struct PositionedItem: Equatable, Identifiable {
        let item: TimelinePlanItem
        let rowHeight: CGFloat
        let capsuleHeight: CGFloat

        var id: String { item.id }
    }

    struct PositionedGap: Equatable, Identifiable {
        let gap: TimelineGap
        let rowHeight: CGFloat

        var id: String { gap.id }
    }

    enum Entry: Equatable, Identifiable {
        case anchor(PositionedAnchor)
        case item(PositionedItem)
        case gap(PositionedGap)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .item(let item):
                return "item:\(item.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            }
        }

        var rowHeight: CGFloat {
            switch self {
            case .anchor(let anchor):
                return anchor.rowHeight
            case .item(let item):
                return item.rowHeight
            case .gap(let gap):
                return gap.rowHeight
            }
        }
    }

    let entries: [Entry]
    let connectorHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    init(
        projection: TimelineDayProjection,
        layoutClass: LayoutClass = .phone,
        anchorHeight: CGFloat? = nil,
        itemHeight: CGFloat? = nil,
        gapHeight: CGFloat? = nil,
        connectorHeight: CGFloat? = nil,
        topInset: CGFloat = 4,
        bottomInset: CGFloat = 12
    ) {
        let metrics = TimelineSurfaceMetrics.make(for: layoutClass)
        let resolvedAnchorHeight = anchorHeight ?? metrics.compactAnchorRowHeight
        let resolvedItemHeight = itemHeight ?? metrics.compactItemMinRowHeight
        let resolvedGapHeight = gapHeight ?? metrics.compactGapRowHeight
        let resolvedConnectorHeight = connectorHeight ?? metrics.compactConnectorHeight
        self.connectorHeight = resolvedConnectorHeight
        self.topInset = topInset
        self.bottomInset = bottomInset

        let beforeWakeItems = projection.beforeWakeItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedItems = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let afterSleepItems = projection.afterSleepItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedGaps = projection.actionableGaps.sorted { $0.startDate < $1.startDate }

        var itemIndex = 0
        var gapIndex = 0
        var resolvedEntries = beforeWakeItems.map {
            Self.itemEntry(for: $0, minimumRowHeight: resolvedItemHeight)
        }
        resolvedEntries.append(.anchor(.init(anchor: projection.wakeAnchor, rowHeight: resolvedAnchorHeight)))

        while itemIndex < sortedItems.count || gapIndex < sortedGaps.count {
            if itemIndex >= sortedItems.count {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: resolvedGapHeight)))
                gapIndex += 1
                continue
            }
            if gapIndex >= sortedGaps.count {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: resolvedItemHeight))
                itemIndex += 1
                continue
            }

            if sortedGaps[gapIndex].startDate <= (sortedItems[itemIndex].startDate ?? .distantFuture) {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: resolvedGapHeight)))
                gapIndex += 1
            } else {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: resolvedItemHeight))
                itemIndex += 1
            }
        }

        resolvedEntries.append(.anchor(.init(anchor: projection.sleepAnchor, rowHeight: resolvedAnchorHeight)))
        resolvedEntries.append(contentsOf: afterSleepItems.map {
            Self.itemEntry(for: $0, minimumRowHeight: resolvedItemHeight)
        })
        self.entries = resolvedEntries
    }

    var contentHeight: CGFloat {
        let rowsHeight = entries.reduce(CGFloat.zero) { $0 + $1.rowHeight }
        let connectorsHeight = CGFloat(max(entries.count - 1, 0)) * connectorHeight
        return topInset + rowsHeight + connectorsHeight + bottomInset
    }

    static func itemEntry(for item: TimelinePlanItem, minimumRowHeight: CGFloat) -> Entry {
        let capsuleHeight = timelineCapsuleHeight(for: item.duration)
        return .item(.init(
            item: item,
            rowHeight: max(minimumRowHeight, capsuleHeight + 20),
            capsuleHeight: capsuleHeight
        ))
    }
}
