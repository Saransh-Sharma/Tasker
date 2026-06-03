import SwiftUI

struct TimelineDayPresentation {
    let current: TimelineDayCurrentState

    var now: Date { current.now }
    var dayRelation: TimelineDayRelation { current.dayRelation }
    var currentBoundaryDate: Date? { current.currentBoundaryDate }
    var currentTintHex: String? { current.currentTintHex }

    init(projection: TimelineDayProjection, now: Date, calendar: Calendar = .current) {
        self.init(stable: TimelineDayStablePresentation(projection: projection, calendar: calendar), now: now)
    }

    init(stable: TimelineDayStablePresentation, now: Date) {
        self.current = TimelineDayCurrentState(stable: stable, now: now)
    }

    func row(for item: TimelinePlanItem) -> TimelineRenderableRow {
        let state = TimelineDayPresentation.resolveTaskState(
            item: item,
            now: current.now,
            dayRelation: current.dayRelation
        )
        let progressRatio = TimelineDayPresentation.progressRatio(for: item, now: current.now, state: state)
        let metadataMode: TimelineMetadataMode?
        switch state {
        case .currentTask:
            if let end = item.endDate {
                let remaining = max(1, Int(ceil(end.timeIntervalSince(current.now) / 60)))
                metadataMode = .remainingTime(remaining)
            } else {
                metadataMode = .scheduled
            }
        case .pastCompleted:
            metadataMode = .done
        case .pastIncomplete, .futureTask:
            metadataMode = .scheduled
        default:
            metadataMode = nil
        }

        return TimelineRenderableRow(
            id: item.id,
            kind: .task,
            temporalState: state,
            metadataMode: metadataMode,
            utilityItems: TimelineDayPresentation.utilityItems(for: item),
            progressRatio: progressRatio,
            title: item.title,
            subtitle: item.subtitle,
            isInteractiveRing: item.source == .task,
            stemLeading: TimelineDayPresentation.leadingStemState(for: state, tintHex: item.tintHex, progressRatio: progressRatio),
            stemTrailing: TimelineDayPresentation.trailingStemState(for: state, tintHex: item.tintHex),
            isCurrentRailEmphasis: state == .currentTask
        )
    }

    func row(for gap: TimelineGap) -> TimelineRenderableRow {
        let state: TimelineTemporalState
        switch current.dayRelation {
        case .today:
            state = current.activeGapID == gap.id ? .activeGap : .futureGap
        case .past:
            state = .activeGap
        case .future:
            state = .futureGap
        }

        return TimelineRenderableRow(
            id: gap.id,
            kind: .gap,
            temporalState: state,
            metadataMode: nil,
            utilityItems: [],
            progressRatio: 0,
            title: gap.headline,
            subtitle: gap.supportingText,
            isInteractiveRing: false,
            stemLeading: TimelineDayPresentation.leadingGapStemState(for: gap, now: current.now, dayRelation: current.dayRelation),
            stemTrailing: TimelineDayPresentation.trailingGapStemState(for: gap, now: current.now, dayRelation: current.dayRelation),
            isCurrentRailEmphasis: current.activeGapID == gap.id
        )
    }

    func row(for anchor: TimelineAnchorItem) -> TimelineRenderableRow {
        let pastAnchor = current.dayRelation == .past || (current.dayRelation == .today && anchor.time <= current.now)
        return TimelineRenderableRow(
            id: anchor.id,
            kind: .anchor,
            temporalState: .anchor,
            metadataMode: .scheduled,
            utilityItems: [],
            progressRatio: 0,
            title: anchor.title,
            subtitle: anchor.subtitle,
            isInteractiveRing: anchor.isActionable,
            stemLeading: pastAnchor ? .gapPastSegment : .futureSegment,
            stemTrailing: pastAnchor ? .gapPastSegment : .futureSegment,
            isCurrentRailEmphasis: false
        )
    }

    static func resolveTaskState(
        item: TimelinePlanItem,
        now: Date,
        dayRelation: TimelineDayRelation
    ) -> TimelineTemporalState {
        if item.isComplete {
            return .pastCompleted
        }

        guard let start = item.startDate, let end = item.endDate else {
            return dayRelation == .past ? .pastIncomplete : .futureTask
        }

        switch dayRelation {
        case .today:
            if start <= now && now < end {
                return .currentTask
            }
            if end <= now {
                return .pastIncomplete
            }
            return .futureTask
        case .past:
            return .pastIncomplete
        case .future:
            return .futureTask
        }
    }

    static func progressRatio(for item: TimelinePlanItem, now: Date, state: TimelineTemporalState) -> CGFloat {
        guard state == .currentTask,
              let start = item.startDate,
              let end = item.endDate
        else { return state == .pastCompleted ? 1 : 0 }

        let total = max(end.timeIntervalSince(start), 1)
        let elapsed = max(0, min(now.timeIntervalSince(start), total))
        return CGFloat(elapsed / total)
    }

    static func utilityItems(for item: TimelinePlanItem) -> [TimelineUtilityItem] {
        var items: [TimelineUtilityItem] = []
        if let checklistSummary = item.checklistSummary, checklistSummary.isEmpty == false {
            items.append(.checklist(checklistSummary))
        }
        if item.hasNotes {
            items.append(.note)
        }
        if item.isRecurring {
            items.append(.recurring)
        }
        if item.source == .calendarEvent {
            items.append(.calendar)
        }
        if item.isMeetingLike {
            items.append(.meeting)
        }
        if item.showsProjectUtility, let subtitle = item.subtitle, subtitle.isEmpty == false {
            items.append(.project(subtitle))
        }
        return items
    }

    static func leadingStemState(for state: TimelineTemporalState, tintHex: String?, progressRatio: CGFloat) -> TimelineStemSegmentState {
        switch state {
        case .pastCompleted:
            return .pastCompletedSegment(tintHex)
        case .pastIncomplete:
            return .pastIncompleteSegment(tintHex)
        case .currentTask:
            return .currentElapsedSegment(tintHex, progress: progressRatio)
        case .futureTask:
            return .futureSegment
        case .activeGap:
            return .gapPastSegment
        case .futureGap, .anchor:
            return .gapFutureSegment
        }
    }

    static func trailingStemState(for state: TimelineTemporalState, tintHex: String?) -> TimelineStemSegmentState {
        switch state {
        case .pastCompleted:
            return .pastCompletedSegment(tintHex)
        case .pastIncomplete:
            return .pastIncompleteSegment(tintHex)
        case .currentTask:
            return .currentRemainingSegment
        case .futureTask:
            return .futureSegment
        case .activeGap:
            return .gapFutureSegment
        case .futureGap, .anchor:
            return .gapFutureSegment
        }
    }

    static func leadingGapStemState(for gap: TimelineGap, now: Date, dayRelation: TimelineDayRelation) -> TimelineStemSegmentState {
        switch dayRelation {
        case .past:
            return .gapPastSegment
        case .future:
            return .gapFutureSegment
        case .today:
            return gap.endDate <= now ? .gapPastSegment : .gapFutureSegment
        }
    }

    static func trailingGapStemState(for gap: TimelineGap, now: Date, dayRelation: TimelineDayRelation) -> TimelineStemSegmentState {
        switch dayRelation {
        case .past:
            return .gapPastSegment
        case .future:
            return .gapFutureSegment
        case .today:
            return gap.startDate <= now && now < gap.endDate ? .gapFutureSegment : (gap.endDate <= now ? .gapPastSegment : .gapFutureSegment)
        }
    }
}
