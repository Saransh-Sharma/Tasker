import SwiftUI

struct SunriseTimelineSurface: View {


    let snapshot: HomeTimelineSnapshot

    let layoutClass: LifeBoardLayoutClass

    let showsRevealHandle: Bool

    let hasNextHomeWidget: Bool

    let onSelectDate: (Date) -> Void

    let onSnapAnchor: (SunriseAnchor) -> Void

    let onDragChanged: (CGFloat) -> Void

    let onDragEnded: (CGFloat) -> Void

    let onTaskTap: (TimelinePlanItem) -> Void

    let onToggleComplete: (TimelinePlanItem) -> Void

    let onAnchorTap: (TimelineAnchorItem) -> Void

    let onAddTask: (Date?) -> Void

    let onScheduleInbox: () -> Void

    let onShowCalendarInTimeline: () -> Void

    let onPlaceReplanAtTime: (TimelinePlacementCandidate, Date) -> Void

    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    let onCancelReplanPlacement: () -> Void

    let onSkipReplanPlacement: () -> Void

    let onClearReplanError: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    init(
        snapshot: HomeTimelineSnapshot,
        layoutClass: LifeBoardLayoutClass,
        showsRevealHandle: Bool = true,
        hasNextHomeWidget: Bool = false,
        onSelectDate: @escaping (Date) -> Void,
        onSnapAnchor: @escaping (SunriseAnchor) -> Void,
        onDragChanged: @escaping (CGFloat) -> Void,
        onDragEnded: @escaping (CGFloat) -> Void,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAnchorTap: @escaping (TimelineAnchorItem) -> Void,
        onAddTask: @escaping (Date?) -> Void,
        onScheduleInbox: @escaping () -> Void,
        onShowCalendarInTimeline: @escaping () -> Void,
        onPlaceReplanAtTime: @escaping (TimelinePlacementCandidate, Date) -> Void,
        onPlaceReplanAllDay: @escaping (TimelinePlacementCandidate, Date) -> Void,
        onCancelReplanPlacement: @escaping () -> Void,
        onSkipReplanPlacement: @escaping () -> Void,
        onClearReplanError: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.layoutClass = layoutClass
        self.showsRevealHandle = showsRevealHandle
        self.hasNextHomeWidget = hasNextHomeWidget
        self.onSelectDate = onSelectDate
        self.onSnapAnchor = onSnapAnchor
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAnchorTap = onAnchorTap
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.onShowCalendarInTimeline = onShowCalendarInTimeline
        self.onPlaceReplanAtTime = onPlaceReplanAtTime
        self.onPlaceReplanAllDay = onPlaceReplanAllDay
        self.onCancelReplanPlacement = onCancelReplanPlacement
        self.onSkipReplanPlacement = onSkipReplanPlacement
        self.onClearReplanError = onClearReplanError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            if let candidate = snapshot.placementCandidate {
                TimelinePlacementPrompt(
                    candidate: candidate,
                    selectedDate: snapshot.selectedDate,
                    suggestedTime: suggestedPlacementTime,
                    onPlaceAtSuggestedTime: {
                        onPlaceReplanAtTime(candidate, suggestedPlacementTime)
                    },
                    onPlaceAllDay: {
                        onPlaceReplanAllDay(candidate, snapshot.selectedDate)
                    },
                    onBack: onCancelReplanPlacement,
                    onSkip: onSkipReplanPlacement,
                    onClearError: onClearReplanError
                )
            }

            if showsRevealHandle {
                SunriseTimelineBar(
                    onSnapAnchor: onSnapAnchor,
                    onDragChanged: onDragChanged,
                    onDragEnded: onDragEnded
                )
                .reportHeight(to: TimelineHeaderHeightPreferenceKey.self)
            }

            TimelinePlanningShelf(
                allDayItems: snapshot.day.allDayItems,
                inboxItems: snapshot.day.inboxItems,
                placementCandidate: snapshot.placementCandidate,
                selectedDate: snapshot.selectedDate,
                onTaskTap: onTaskTap,
                onScheduleInbox: onScheduleInbox,
                onPlaceReplanAllDay: onPlaceReplanAllDay
            )

            switch rendererMode {
            case .agenda:
                DailyTimelineAgendaView(
                    projection: snapshot.day,
                    layoutClass: layoutClass,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAnchorTap: onAnchorTap,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox
                )
            case .compact:
                DailyTimelineCompactView(
                    projection: snapshot.day,
                    layoutClass: layoutClass,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAnchorTap: onAnchorTap,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox
                )
            case .expanded:
                DailyTimelineCanvas(
                    projection: snapshot.day,
                    layoutClass: layoutClass,
                    bottomInset: metrics.resolvedTimelineBottomPadding(hasNextHomeWidget: hasNextHomeWidget),
                    placementCandidate: snapshot.placementCandidate,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAnchorTap: onAnchorTap,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox,
                    onShowCalendarInTimeline: onShowCalendarInTimeline,
                    onPlaceReplanAtTime: onPlaceReplanAtTime
                )
                .padding(.horizontal, layoutClass == .phone ? -spacing.s8 : 0)
            }

            if let candidate = snapshot.placementCandidate {
                TimelinePlacementDock(candidate: candidate)
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.top, showsRevealHandle ? spacing.s8 : 0)
        .padding(.bottom, metrics.resolvedTimelineBottomPadding(hasNextHomeWidget: hasNextHomeWidget))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.timeline.content")
        .overlay(alignment: .topLeading) {
            if hasMixedTimedOverlap {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Timeline overlap between task and meeting")
                    .accessibilityIdentifier("home.timeline.conflictBlock")
            }
        }
    }
}
