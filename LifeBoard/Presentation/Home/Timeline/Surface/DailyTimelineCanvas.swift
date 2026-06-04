import SwiftUI

struct DailyTimelineCanvas: View {


    let projection: TimelineDayProjection

    let layoutClass: LifeBoardLayoutClass

    let placementCandidate: TimelinePlacementCandidate?

    let onTaskTap: (TimelinePlanItem) -> Void

    let onToggleComplete: (TimelinePlanItem) -> Void

    let onAnchorTap: (TimelineAnchorItem) -> Void

    let onAddTask: (Date?) -> Void

    let onScheduleInbox: () -> Void

    let onShowCalendarInTimeline: () -> Void

    let onPlaceReplanAtTime: (TimelinePlacementCandidate, Date) -> Void

    let plan: TimelineCanvasLayoutPlan

    let stablePresentation: TimelineDayStablePresentation

    @State var isCanvasDropTargeted = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(
        projection: TimelineDayProjection,
        layoutClass: LifeBoardLayoutClass,
        bottomInset: CGFloat? = nil,
        placementCandidate: TimelinePlacementCandidate?,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAnchorTap: @escaping (TimelineAnchorItem) -> Void,
        onAddTask: @escaping (Date?) -> Void,
        onScheduleInbox: @escaping () -> Void,
        onShowCalendarInTimeline: @escaping () -> Void,
        onPlaceReplanAtTime: @escaping (TimelinePlacementCandidate, Date) -> Void
    ) {
        self.projection = projection
        self.layoutClass = layoutClass
        self.placementCandidate = placementCandidate
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAnchorTap = onAnchorTap
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.onShowCalendarInTimeline = onShowCalendarInTimeline
        self.onPlaceReplanAtTime = onPlaceReplanAtTime
        self.stablePresentation = TimelineDayStablePresentation(projection: projection)
        let resolvedMetrics = TimelineSurfaceMetrics.make(for: layoutClass)
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineCanvasPlanBuild")
        self.plan = TimelineCanvasLayoutPlan(
            projection: projection,
            bottomInset: bottomInset ?? resolvedMetrics.timelineBottomPadding,
            maxVisualColumns: TimelineCanvasLayoutPlan.maxVisualColumns(for: layoutClass)
        )
        LifeBoardPerformanceTrace.end(interval)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            canvasBody(now: displayedNow(from: timeline.date))
        }
    }

    @ViewBuilder
    func visualElementView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedVisualTimelineElement,
        presentation: TimelineDayPresentation,
        totalWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        streamGeometry: TimelineStreamGeometry,
        completionX: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        switch positioned.element {
        case .routineMarker(let model):
            anchorView(
                .init(anchor: model.anchor, y: positioned.y + (positioned.height / 2)),
                row: presentation.row(for: model.anchor),
                streamGeometry: streamGeometry,
                totalWidth: totalWidth,
                contentX: contentX,
                contentWidth: contentWidth,
                cardHeight: positioned.height
            )
            .zIndex(3)
        case .meetingCard(let model):
            let row = presentation.row(for: model.item)
            TimelineMeetingBlockRow(
                item: model.item,
                row: row,
                isNested: false,
                action: { onTaskTap(model.item) }
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(2)
        case .taskMarker(let model):
            let row = presentation.row(for: model.item)
            TimelineTaskMarkerRow(
                item: model.item,
                row: row,
                isEmphasized: model.isEmphasized,
                spineIconCenterX: TimelineSpineMounting.centerX(
                    for: streamGeometry,
                    atY: positioned.y + TimelineTaskMarkerRow.iconCenterYOffset
                ),
                completionX: completionX,
                onTap: { onTaskTap(model.item) },
                onToggleComplete: { onToggleComplete(model.item) }
            )
            .frame(width: totalWidth, height: positioned.height, alignment: .leading)
            .offset(x: 0, y: positioned.y)
            .zIndex(1)
        case .taskCard(let model):
            let row = presentation.row(for: model.item)
            let title = TimelineDenseTitleFormatter.displayTitles(for: [model.item])[model.item.id] ?? model.item.title
            TimelineNormalItemCard(
                item: model.item,
                row: row,
                title: title,
                onTap: { onTaskTap(model.item) },
                onToggleComplete: {
                    guard model.item.source == .task else { return }
                    onToggleComplete(model.item)
                }
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(2)
        case .flock(let model):
            TimelineFlockBlock(
                model: TimelineFlockModel(block: model.block, now: presentation.now),
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(3)
        case .gapPrompt(let model):
            let suggestedDate = timelineSuggestedAddDate(for: model.gap, now: presentation.now)
            TimelineGapPrompt(
                gap: model.gap,
                row: presentation.row(for: model.gap),
                suggestedDate: suggestedDate,
                onAddTask: { onAddTask(suggestedDate) },
                onPlanBlock: onScheduleInbox
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(1.5)
        case .emptyState(let model):
            TimelineEmptyStateCard(model: model) {
                onAddTask(model.suggestedDate)
            } secondaryAction: {
                if model.showsCalendarAction {
                    onShowCalendarInTimeline()
                } else {
                    onScheduleInbox()
                }
            }
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(1)
        }
    }
}
