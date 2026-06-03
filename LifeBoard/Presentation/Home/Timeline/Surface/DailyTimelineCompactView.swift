import SwiftUI

struct DailyTimelineCompactView: View {
    let projection: TimelineDayProjection
    let layoutClass: LifeBoardLayoutClass
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
        layoutClass: LifeBoardLayoutClass,
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
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineCompactPlanBuild")
        self.plan = TimelineCompactLayoutPlan(projection: projection, layoutClass: layoutClass)
        LifeBoardPerformanceTrace.end(interval)
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
