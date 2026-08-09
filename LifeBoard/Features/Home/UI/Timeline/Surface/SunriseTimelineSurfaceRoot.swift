import SwiftUI

// The surface root and its placement helpers.

// MARK: - SunriseTimelineSurfaceRoot

struct TimelineSurface: View {


    let snapshot: HomeTimelineSnapshot

    let layoutClass: LayoutClass

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
        layoutClass: LayoutClass,
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
                TimelineBar(
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

// MARK: - TimelineSurface+PlacementHelpers

extension TimelineSurface {
    var spacing: LifeBoardSpacingTokens { ThemeStore.shared.tokens(for: layoutClass).spacing }

    var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var rendererMode: TimelineRendererMode {
        TimelineRendererPolicy.mode(
            layoutClass: layoutClass,
            dayLayoutMode: snapshot.day.layoutMode,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    var suggestedPlacementTime: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(snapshot.selectedDate),
           snapshot.day.currentTime > snapshot.day.wakeAnchor.time,
           snapshot.day.currentTime < snapshot.day.sleepAnchor.time {
            return snapshot.day.currentTime
        }
        return snapshot.day.wakeAnchor.time
    }

    var hasMixedTimedOverlap: Bool {
        let timedItems = snapshot.day.timedItems
            .filter { $0.isAllDay == false }
            .compactMap { item -> (source: TimelinePlanItemSource, start: Date, end: Date)? in
                guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
                return (item.source, start, end)
            }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.end < rhs.end
            }

        for index in timedItems.indices {
            let candidate = timedItems[index]
            for other in timedItems[timedItems.index(after: index)...] {
                guard other.start < candidate.end else { break }
                if other.source != candidate.source {
                    return true
                }
            }
        }
        return false
    }
}
