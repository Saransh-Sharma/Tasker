import SwiftUI

struct TimelineHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineCalendarCardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineBackdropWeekHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeightPreferenceReader<Key: PreferenceKey>: ViewModifier where Key.Value == CGFloat {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(key: Key.self, value: proxy.size.height)
            }
        }
    }
}

extension View {
    func reportHeight<Key: PreferenceKey>(to key: Key.Type) -> some View where Key.Value == CGFloat {
        modifier(HeightPreferenceReader<Key>())
    }
}

struct TimelineCanvasLayoutPlan: Equatable {
    private struct Candidate {
        let item: TimelinePlanItem
        let startMinute: CGFloat
        let endMinute: CGFloat
        let y: CGFloat
        let height: CGFloat
    }

    struct PositionedAnchor: Equatable, Identifiable {
        let anchor: TimelineAnchorItem
        let y: CGFloat

        var id: String { anchor.id }
    }

    struct PositionedItem: Equatable, Identifiable {
        let item: TimelinePlanItem
        let y: CGFloat
        let height: CGFloat
        let startMinute: CGFloat
        let endMinute: CGFloat
        let columnIndex: Int
        let columnCount: Int

        var id: String { item.id }
    }

    struct PositionedGap: Equatable, Identifiable {
        let gap: TimelineGap
        let startY: CGFloat
        let height: CGFloat

        var id: String { gap.id }
    }

    let visibleStart: Date
    let visibleEnd: Date
    let pointsPerMinute: CGFloat
    let minimumItemHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    let wakeAnchor: PositionedAnchor
    let sleepAnchor: PositionedAnchor
    let items: [PositionedItem]
    let gaps: [PositionedGap]

    init(
        projection: TimelineDayProjection,
        pointsPerMinute: CGFloat = 1.08,
        minimumItemHeight: CGFloat = 44,
        topInset: CGFloat = 36,
        bottomInset: CGFloat = 36,
        calendar: Calendar = .current
    ) {
        let start = projection.wakeAnchor.time
        let end = projection.sleepAnchor.time > start ? projection.sleepAnchor.time : start.addingTimeInterval(60)
        self.visibleStart = start
        self.visibleEnd = end
        self.pointsPerMinute = pointsPerMinute
        self.minimumItemHeight = minimumItemHeight
        self.topInset = topInset
        self.bottomInset = bottomInset

        let wakeY: CGFloat = topInset
        let sleepY = topInset + Self.yPosition(for: end, start: start, pointsPerMinute: pointsPerMinute, calendar: calendar)
        self.wakeAnchor = PositionedAnchor(anchor: projection.wakeAnchor, y: wakeY)
        self.sleepAnchor = PositionedAnchor(anchor: projection.sleepAnchor, y: sleepY)

        let candidates = projection.timedItems.compactMap { item -> Candidate? in
            guard let startDate = item.startDate else { return nil }
            let inferredEnd = item.endDate ?? startDate.addingTimeInterval(item.duration ?? (30 * 60))
            let clampedEnd = max(inferredEnd, startDate.addingTimeInterval(60))
            let startMinute = Self.minuteOffset(for: startDate, start: start, calendar: calendar)
            let endMinute = max(Self.minuteOffset(for: clampedEnd, start: start, calendar: calendar), startMinute + 1)
            let y = topInset + (startMinute * pointsPerMinute)
            let renderedHeight = max((endMinute - startMinute) * pointsPerMinute, minimumItemHeight)
            return Candidate(
                item: item,
                startMinute: startMinute,
                endMinute: endMinute,
                y: y,
                height: renderedHeight
            )
        }
        .sorted {
            if $0.startMinute == $1.startMinute {
                return $0.endMinute < $1.endMinute
            }
            return $0.startMinute < $1.startMinute
        }

        self.items = Self.positionedItems(from: candidates)

        self.gaps = projection.gaps.compactMap { gap in
            let startMinute = Self.minuteOffset(for: gap.startDate, start: start, calendar: calendar)
            let endMinute = Self.minuteOffset(for: gap.endDate, start: start, calendar: calendar)
            let gapHeight = max((endMinute - startMinute) * pointsPerMinute, 0)
            guard gapHeight > 0 else { return nil }
            return PositionedGap(
                gap: gap,
                startY: topInset + (startMinute * pointsPerMinute),
                height: gapHeight
            )
        }
    }

    var contentHeight: CGFloat {
        max(sleepAnchor.y, items.map { $0.y + $0.height }.max() ?? 0) + bottomInset
    }

    func date(atY y: CGFloat, calendar: Calendar = .current) -> Date {
        let rawMinutes = max(0, (y - topInset) / pointsPerMinute)
        let visibleSpanMinutes = CGFloat(calendar.dateComponents([.minute], from: visibleStart, to: visibleEnd).minute ?? 0)
        let clampedMinutes = min(rawMinutes, max(visibleSpanMinutes, 0))
        let roundedMinutes = Int((clampedMinutes / 15).rounded() * 15)
        return calendar.date(byAdding: .minute, value: roundedMinutes, to: visibleStart) ?? visibleStart
    }

    private static func positionedItems(from candidates: [Candidate]) -> [PositionedItem] {
        guard candidates.isEmpty == false else { return [] }

        var groups: [[Candidate]] = []
        var currentGroup: [Candidate] = []
        var currentGroupMaxEnd: CGFloat = 0

        for candidate in candidates {
            if currentGroup.isEmpty {
                currentGroup = [candidate]
                currentGroupMaxEnd = candidate.endMinute
                continue
            }

            if candidate.startMinute < currentGroupMaxEnd {
                currentGroup.append(candidate)
                currentGroupMaxEnd = max(currentGroupMaxEnd, candidate.endMinute)
            } else {
                groups.append(currentGroup)
                currentGroup = [candidate]
                currentGroupMaxEnd = candidate.endMinute
            }
        }

        if currentGroup.isEmpty == false {
            groups.append(currentGroup)
        }

        return groups.flatMap { group in
            var columnEndMinutes: [CGFloat] = []
            var positioned: [(Candidate, Int)] = []

            for candidate in group {
                if let availableColumn = columnEndMinutes.firstIndex(where: { $0 <= candidate.startMinute }) {
                    columnEndMinutes[availableColumn] = candidate.endMinute
                    positioned.append((candidate, availableColumn))
                } else {
                    let newColumn = columnEndMinutes.count
                    columnEndMinutes.append(candidate.endMinute)
                    positioned.append((candidate, newColumn))
                }
            }

            let columnCount = max(columnEndMinutes.count, 1)
            return positioned.map { candidate, columnIndex in
                PositionedItem(
                    item: candidate.item,
                    y: candidate.y,
                    height: candidate.height,
                    startMinute: candidate.startMinute,
                    endMinute: candidate.endMinute,
                    columnIndex: columnIndex,
                    columnCount: columnCount
                )
            }
        }
    }

    private static func minuteOffset(for date: Date, start: Date, calendar: Calendar) -> CGFloat {
        CGFloat(calendar.dateComponents([.minute], from: start, to: date).minute ?? 0)
    }

    private static func yPosition(for date: Date, start: Date, pointsPerMinute: CGFloat, calendar: Calendar) -> CGFloat {
        minuteOffset(for: date, start: start, calendar: calendar) * pointsPerMinute
    }
}

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
        layoutClass: TaskerLayoutClass = .phone,
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

        let sortedItems = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedGaps = projection.gaps.sorted { $0.startDate < $1.startDate }

        var itemIndex = 0
        var gapIndex = 0
        var resolvedEntries: [Entry] = [
            .anchor(.init(anchor: projection.wakeAnchor, rowHeight: resolvedAnchorHeight))
        ]

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
        self.entries = resolvedEntries
    }

    var contentHeight: CGFloat {
        let rowsHeight = entries.reduce(CGFloat.zero) { $0 + $1.rowHeight }
        let connectorsHeight = CGFloat(max(entries.count - 1, 0)) * connectorHeight
        return topInset + rowsHeight + connectorsHeight + bottomInset
    }

    private static func itemEntry(for item: TimelinePlanItem, minimumRowHeight: CGFloat) -> Entry {
        let capsuleHeight = timelineCapsuleHeight(for: item.duration)
        return .item(.init(
            item: item,
            rowHeight: max(minimumRowHeight, capsuleHeight + 20),
            capsuleHeight: capsuleHeight
        ))
    }
}

private enum TimelineFormatting {
    static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    static func timeRangeText(start: Date, end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
    }
}

private enum TimelineItemVisuals {
    @MainActor
    static func metaColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.tasker.textTertiary.opacity(0.68) : Color.tasker.textSecondary
    }

    @MainActor
    static func titleColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.tasker.textSecondary.opacity(0.72) : Color.tasker.textPrimary
    }

    @MainActor
    static func accessoryColor(for item: TimelinePlanItem, isActive: Bool) -> Color {
        if item.isComplete {
            return Color.tasker.textSecondary.opacity(0.62)
        }
        return isActive ? Color.tasker.accentPrimary : Color.tasker.textSecondary
    }
}

private enum TimelineDayRelation {
    case past
    case today
    case future
}

private struct TimelineDayPresentation {
    let now: Date
    let dayRelation: TimelineDayRelation
    let currentBoundaryDate: Date?
    let currentTintHex: String?
    private let taskRowsByID: [String: TimelineRenderableRow]
    private let gapRowsByID: [String: TimelineRenderableRow]
    private let anchorRowsByID: [String: TimelineRenderableRow]

    init(projection: TimelineDayProjection, now: Date, calendar: Calendar = .current) {
        self.now = now
        let selectedDay = calendar.startOfDay(for: projection.date)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            dayRelation = .past
        } else if selectedDay > today {
            dayRelation = .future
        } else {
            dayRelation = .today
        }

        let sortedItems = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedGaps = projection.gaps.sorted { $0.startDate < $1.startDate }

        let currentItem = sortedItems.first(where: { item in
            guard let start = item.startDate, let end = item.endDate, item.isComplete == false else { return false }
            return start <= now && now < end
        })

        let activeGap = currentItem == nil && dayRelation == .today
            ? sortedGaps.first(where: { $0.startDate <= now && now < $0.endDate })
            : nil

        currentBoundaryDate = dayRelation == .today ? min(max(now, projection.wakeAnchor.time), projection.sleepAnchor.time) : nil
        currentTintHex = currentItem?.tintHex
            ?? projection.timedItems.first(where: { $0.isComplete && $0.tintHex != nil })?.tintHex

        var resolvedTaskRows: [String: TimelineRenderableRow] = [:]
        for item in projection.timedItems {
            let state = TimelineDayPresentation.resolveTaskState(
                item: item,
                now: now,
                dayRelation: dayRelation
            )
            let progressRatio = TimelineDayPresentation.progressRatio(for: item, now: now, state: state)
            let utilityItems = TimelineDayPresentation.utilityItems(for: item)
            let metadataMode: TimelineMetadataMode?
            switch state {
            case .currentTask:
                if let end = item.endDate {
                    let remaining = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
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

            resolvedTaskRows[item.id] = TimelineRenderableRow(
                id: item.id,
                kind: .task,
                temporalState: state,
                metadataMode: metadataMode,
                utilityItems: utilityItems,
                progressRatio: progressRatio,
                title: item.title,
                subtitle: item.subtitle,
                isInteractiveRing: item.source == .task,
                stemLeading: TimelineDayPresentation.leadingStemState(for: state, tintHex: item.tintHex, progressRatio: progressRatio),
                stemTrailing: TimelineDayPresentation.trailingStemState(for: state, tintHex: item.tintHex),
                isCurrentRailEmphasis: state == .currentTask
            )
        }

        var resolvedGapRows: [String: TimelineRenderableRow] = [:]
        for gap in projection.gaps {
            let state: TimelineTemporalState
            switch dayRelation {
            case .today:
                if activeGap?.id == gap.id {
                    state = .activeGap
                } else {
                    state = .futureGap
                }
            case .past:
                state = .activeGap
            case .future:
                state = .futureGap
            }

            resolvedGapRows[gap.id] = TimelineRenderableRow(
                id: gap.id,
                kind: .gap,
                temporalState: state,
                metadataMode: nil,
                utilityItems: [],
                progressRatio: 0,
                title: gap.headline,
                subtitle: gap.supportingText,
                isInteractiveRing: false,
                stemLeading: TimelineDayPresentation.leadingGapStemState(for: gap, now: now, dayRelation: dayRelation),
                stemTrailing: TimelineDayPresentation.trailingGapStemState(for: gap, now: now, dayRelation: dayRelation),
                isCurrentRailEmphasis: activeGap?.id == gap.id
            )
        }

        let anchors = [projection.wakeAnchor, projection.sleepAnchor]
        var resolvedAnchorRows: [String: TimelineRenderableRow] = [:]
        for anchor in anchors {
            let pastAnchor = dayRelation == .past || (dayRelation == .today && anchor.time <= now)
            resolvedAnchorRows[anchor.id] = TimelineRenderableRow(
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

        taskRowsByID = resolvedTaskRows
        gapRowsByID = resolvedGapRows
        anchorRowsByID = resolvedAnchorRows
    }

    func row(for item: TimelinePlanItem) -> TimelineRenderableRow {
        taskRowsByID[item.id] ?? TimelineRenderableRow(
            id: item.id,
            kind: .task,
            temporalState: .futureTask,
            metadataMode: .scheduled,
            utilityItems: [],
            progressRatio: 0,
            title: item.title,
            subtitle: item.subtitle,
            isInteractiveRing: item.source == .task,
            stemLeading: .futureSegment,
            stemTrailing: .futureSegment,
            isCurrentRailEmphasis: false
        )
    }

    func row(for gap: TimelineGap) -> TimelineRenderableRow {
        gapRowsByID[gap.id] ?? TimelineRenderableRow(
            id: gap.id,
            kind: .gap,
            temporalState: .futureGap,
            metadataMode: nil,
            utilityItems: [],
            progressRatio: 0,
            title: gap.headline,
            subtitle: gap.supportingText,
            isInteractiveRing: false,
            stemLeading: .gapFutureSegment,
            stemTrailing: .gapFutureSegment,
            isCurrentRailEmphasis: false
        )
    }

    func row(for anchor: TimelineAnchorItem) -> TimelineRenderableRow {
        anchorRowsByID[anchor.id] ?? TimelineRenderableRow(
            id: anchor.id,
            kind: .anchor,
            temporalState: .anchor,
            metadataMode: .scheduled,
            utilityItems: [],
            progressRatio: 0,
            title: anchor.title,
            subtitle: anchor.subtitle,
            isInteractiveRing: anchor.isActionable,
            stemLeading: .futureSegment,
            stemTrailing: .futureSegment,
            isCurrentRailEmphasis: false
        )
    }

    private static func resolveTaskState(
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

    private static func progressRatio(for item: TimelinePlanItem, now: Date, state: TimelineTemporalState) -> CGFloat {
        guard state == .currentTask,
              let start = item.startDate,
              let end = item.endDate
        else { return state == .pastCompleted ? 1 : 0 }

        let total = max(end.timeIntervalSince(start), 1)
        let elapsed = max(0, min(now.timeIntervalSince(start), total))
        return CGFloat(elapsed / total)
    }

    private static func utilityItems(for item: TimelinePlanItem) -> [TimelineUtilityItem] {
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

    private static func leadingStemState(for state: TimelineTemporalState, tintHex: String?, progressRatio: CGFloat) -> TimelineStemSegmentState {
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

    private static func trailingStemState(for state: TimelineTemporalState, tintHex: String?) -> TimelineStemSegmentState {
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

    private static func leadingGapStemState(for gap: TimelineGap, now: Date, dayRelation: TimelineDayRelation) -> TimelineStemSegmentState {
        switch dayRelation {
        case .past:
            return .gapPastSegment
        case .future:
            return .gapFutureSegment
        case .today:
            return gap.endDate <= now ? .gapPastSegment : .gapFutureSegment
        }
    }

    private static func trailingGapStemState(for gap: TimelineGap, now: Date, dayRelation: TimelineDayRelation) -> TimelineStemSegmentState {
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

private enum TimelineVisualTokens {
    @MainActor
    static var neutralStem: Color { Color.tasker.strokeHairline.opacity(0.42) }

    @MainActor
    static var gapPastStem: Color { Color.tasker.accentPrimary.opacity(0.18) }

    @MainActor
    static var futureCapsule: Color { Color.tasker.surfacePrimary.opacity(0.9) }

    @MainActor
    static var futureCapsuleStroke: Color { Color.tasker.strokeHairline.opacity(0.58) }

    @MainActor
    static var anchorCapsuleFill: Color { Color.tasker.surfacePrimary.opacity(0.94) }

    @MainActor
    static var metaText: Color { Color.tasker.textSecondary }

    @MainActor
    static var utilityText: Color { Color.tasker.textTertiary }
}

struct TimelineSurfaceMetrics {
    let compactTimeGutter: CGFloat
    let compactLaneWidth: CGFloat
    let compactTrailingLaneWidth: CGFloat
    let compactTimeToLaneGap: CGFloat
    let compactConnectorHeight: CGFloat
    let compactAnchorRowHeight: CGFloat
    let compactGapRowHeight: CGFloat
    let compactItemMinRowHeight: CGFloat
    let compactReadableWidth: CGFloat?
    let compactContentLeadingPadding: CGFloat
    let compactContentTrailingPadding: CGFloat
    let compactAnchorCircleSize: CGFloat
    let compactAnchorIconSize: CGFloat

    let expandedTimeGutter: CGFloat
    let expandedSpineLaneWidth: CGFloat
    let expandedTrailingLaneWidth: CGFloat
    let expandedContentInset: CGFloat
    let expandedTimeToSpineGap: CGFloat
    let expandedCapsuleMinWidth: CGFloat
    let expandedSingleColumnTextMaxWidth: CGFloat
    let expandedOverlappingTextMaxWidth: CGFloat
    let expandedAnchorCircleSize: CGFloat
    let expandedAnchorIconSize: CGFloat

    let agendaCapsuleWidth: CGFloat
    let agendaAnchorCircleSize: CGFloat
    let agendaAnchorIconSize: CGFloat

    let timelineBottomPadding: CGFloat

    static func make(for layoutClass: TaskerLayoutClass) -> TimelineSurfaceMetrics {
        switch layoutClass {
        case .phone:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 62,
                compactLaneWidth: 52,
                compactTrailingLaneWidth: 40,
                compactTimeToLaneGap: 10,
                compactConnectorHeight: 10,
                compactAnchorRowHeight: 56,
                compactGapRowHeight: 56,
                compactItemMinRowHeight: 72,
                compactReadableWidth: nil,
                compactContentLeadingPadding: 12,
                compactContentTrailingPadding: 4,
                compactAnchorCircleSize: 48,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 64,
                expandedSpineLaneWidth: 72,
                expandedTrailingLaneWidth: 44,
                expandedContentInset: 12,
                expandedTimeToSpineGap: 10,
                expandedCapsuleMinWidth: 60,
                expandedSingleColumnTextMaxWidth: 360,
                expandedOverlappingTextMaxWidth: 300,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 56,
                agendaAnchorCircleSize: 48,
                agendaAnchorIconSize: 18,
                timelineBottomPadding: 20
            )
        case .padCompact:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 72,
                compactLaneWidth: 60,
                compactTrailingLaneWidth: 48,
                compactTimeToLaneGap: 12,
                compactConnectorHeight: 12,
                compactAnchorRowHeight: 60,
                compactGapRowHeight: 62,
                compactItemMinRowHeight: 78,
                compactReadableWidth: 680,
                compactContentLeadingPadding: 14,
                compactContentTrailingPadding: 8,
                compactAnchorCircleSize: 52,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 76,
                expandedSpineLaneWidth: 84,
                expandedTrailingLaneWidth: 52,
                expandedContentInset: 16,
                expandedTimeToSpineGap: 12,
                expandedCapsuleMinWidth: 64,
                expandedSingleColumnTextMaxWidth: 420,
                expandedOverlappingTextMaxWidth: 320,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 60,
                agendaAnchorCircleSize: 52,
                agendaAnchorIconSize: 18,
                timelineBottomPadding: 24
            )
        case .padRegular, .padExpanded:
            return TimelineSurfaceMetrics(
                compactTimeGutter: 72,
                compactLaneWidth: 60,
                compactTrailingLaneWidth: 48,
                compactTimeToLaneGap: 12,
                compactConnectorHeight: 12,
                compactAnchorRowHeight: 60,
                compactGapRowHeight: 62,
                compactItemMinRowHeight: 78,
                compactReadableWidth: 680,
                compactContentLeadingPadding: 14,
                compactContentTrailingPadding: 8,
                compactAnchorCircleSize: 52,
                compactAnchorIconSize: 18,
                expandedTimeGutter: 76,
                expandedSpineLaneWidth: 84,
                expandedTrailingLaneWidth: 52,
                expandedContentInset: 16,
                expandedTimeToSpineGap: 12,
                expandedCapsuleMinWidth: 64,
                expandedSingleColumnTextMaxWidth: 420,
                expandedOverlappingTextMaxWidth: 320,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 60,
                agendaAnchorCircleSize: 56,
                agendaAnchorIconSize: 20,
                timelineBottomPadding: 24
            )
        }
    }
}

private func timelineDisplayedNow(for projection: TimelineDayProjection, timelineDate: Date) -> Date {
    Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
}

private func timelineMetaText(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil, anchor: TimelineAnchorItem? = nil) -> String {
    switch row.metadataMode {
    case .remainingTime(let minutes):
        return "\(minutes)m remaining"
    case .done:
        guard let item, let start = item.startDate, let end = item.endDate else { return "Done" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText) · Done"
    case .scheduled, .none:
        if let anchor {
            return anchor.time.formatted(date: .omitted, time: .shortened)
        }
        guard let item, let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(TimelineFormatting.timeRangeText(start: start, end: end)) · \(durationText)"
    }
}

@MainActor
private func timelineMetaColor(for row: TimelineRenderableRow) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.tasker.textTertiary.opacity(0.72)
    case .pastIncomplete:
        return Color.tasker.statusWarning.opacity(0.92)
    case .currentTask:
        return Color.tasker.textPrimary.opacity(0.92)
    default:
        return TimelineVisualTokens.metaText
    }
}

@MainActor
private func timelineTitleColor(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.tasker.textSecondary.opacity(0.72)
    case .pastIncomplete:
        return Color.tasker.textPrimary.opacity(0.92)
    case .currentTask:
        return Color.tasker.textPrimary
    default:
        if let item {
            return TimelineItemVisuals.titleColor(for: item)
        }
        return Color.tasker.textPrimary
    }
}

@MainActor
private func timelineRingColor(for row: TimelineRenderableRow, palette: TimelinePalette) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return palette.progress
    case .pastIncomplete:
        return palette.base.opacity(0.74)
    case .currentTask:
        return palette.progress
    default:
        return palette.ring
    }
}

private func timelineAccessibilityLabel(for row: TimelineRenderableRow, item: TimelinePlanItem) -> String {
    var parts = [item.title, timelineMetaText(for: row, item: item)]
    if row.utilityItems.isEmpty == false {
        parts.append(row.utilityItems.map(\.accessibilityLabel).joined(separator: ", "))
    }
    return parts.joined(separator: ", ")
}

private func timelineRailText(for item: TimelinePlanItem) -> String {
    guard let start = item.startDate else { return "All day" }
    return start.formatted(date: .omitted, time: .shortened)
}

@MainActor
private func timelineStemColor(for state: TimelineStemSegmentState, fallbackPalette: TimelinePalette) -> Color {
    switch state {
    case .pastCompletedSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress
    case .pastIncompleteSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress.opacity(0.46)
    case .currentElapsedSegment(let tintHex, _):
        return TimelinePalette.resolve(from: tintHex).progress
    case .currentRemainingSegment, .futureSegment, .gapFutureSegment:
        return TimelineVisualTokens.neutralStem
    case .gapPastSegment:
        return TimelineVisualTokens.gapPastStem
    }
}

@MainActor
private func timelineGapPromptText(for gap: TimelineGap, row: TimelineRenderableRow) -> AttributedString {
    let duration = gap.compactDurationText
    let promptSource = gap.supportingText.localizedCaseInsensitiveContains(duration)
        ? gap.supportingText
        : "\(gap.supportingText) \(duration)"
    var prompt = AttributedString(promptSource)
    if let range = prompt.range(of: duration) {
        prompt[range].foregroundColor = row.temporalState == .activeGap ? Color.tasker.textPrimary : gapPromptTint(for: gap)
        prompt[range].font = .tasker(.callout).weight(.semibold)
    }
    return prompt
}

@MainActor
private func gapPromptTint(for gap: TimelineGap) -> Color {
    switch gap.emphasis {
    case .openTime:
        return Color.tasker.accentPrimary
    case .prepWindow:
        return Color.tasker.statusWarning
    case .quietWindow:
        return Color.tasker.statusSuccess
    }
}

private func timelineCapsuleHeight(for duration: TimeInterval?) -> CGFloat {
    let minutes = Int(max(1, (duration ?? 30 * 60) / 60))
    switch minutes {
    case ..<23:
        return 64
    case ..<38:
        return 90
    case ..<53:
        return 110
    case ..<76:
        return 128
    case ..<106:
        return 168
    default:
        return 176
    }
}

private extension TimelineUtilityItem {
    var accessibilityLabel: String {
        switch self {
        case .checklist(let summary):
            return "\(summary.completedCount) of \(summary.totalCount) checklist items complete"
        case .note:
            return "Has notes"
        case .recurring:
            return "Recurring"
        case .calendar:
            return "Calendar event"
        case .meeting:
            return "Meeting"
        case .project(let name):
            return name
        }
    }
}

struct TimelineRailPresentationSpec: Equatable {
    let lineWidth: CGFloat
    let opacity: Double
    let isDashed: Bool

    static let compactConnector = TimelineRailPresentationSpec(
        lineWidth: 1.5,
        opacity: 0.46,
        isDashed: false
    )
}

struct TimelineForedropView: View {
    let snapshot: HomeTimelineSnapshot
    let layoutClass: TaskerLayoutClass
    let showsRevealHandle: Bool
    let onSelectDate: (Date) -> Void
    let onSnapAnchor: (ForedropAnchor) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAtTime: (TimelinePlacementCandidate, Date) -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void
    let onCancelReplanPlacement: () -> Void
    let onSkipReplanPlacement: () -> Void
    let onClearReplanError: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    private enum RendererMode {
        case compact
        case expanded
        case agenda
    }

    private var rendererMode: RendererMode {
        if dynamicTypeSize.isAccessibilitySize {
            return .agenda
        }

        switch layoutClass {
        case .phone:
            return snapshot.day.layoutMode == .expanded ? .expanded : .compact
        case .padCompact:
            return .compact
        case .padRegular, .padExpanded:
            return .expanded
        }
    }

    init(
        snapshot: HomeTimelineSnapshot,
        layoutClass: TaskerLayoutClass,
        showsRevealHandle: Bool = true,
        onSelectDate: @escaping (Date) -> Void,
        onSnapAnchor: @escaping (ForedropAnchor) -> Void,
        onDragChanged: @escaping (CGFloat) -> Void,
        onDragEnded: @escaping (CGFloat) -> Void,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAddTask: @escaping () -> Void,
        onScheduleInbox: @escaping () -> Void,
        onPlaceReplanAtTime: @escaping (TimelinePlacementCandidate, Date) -> Void,
        onPlaceReplanAllDay: @escaping (TimelinePlacementCandidate, Date) -> Void,
        onCancelReplanPlacement: @escaping () -> Void,
        onSkipReplanPlacement: @escaping () -> Void,
        onClearReplanError: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.layoutClass = layoutClass
        self.showsRevealHandle = showsRevealHandle
        self.onSelectDate = onSelectDate
        self.onSnapAnchor = onSnapAnchor
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
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
                TimelineForedropBar(
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
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox
                )
            case .compact:
                DailyTimelineCompactView(
                    projection: snapshot.day,
                    layoutClass: layoutClass,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox
                )
            case .expanded:
                DailyTimelineCanvas(
                    projection: snapshot.day,
                    layoutClass: layoutClass,
                    placementCandidate: snapshot.placementCandidate,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox,
                    onPlaceReplanAtTime: onPlaceReplanAtTime
                )
            }

            if let candidate = snapshot.placementCandidate {
                TimelinePlacementDock(candidate: candidate)
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.top, showsRevealHandle ? spacing.s8 : 0)
        .padding(.bottom, metrics.timelineBottomPadding)
        .accessibilityIdentifier("home.timeline.content")
    }

    private var suggestedPlacementTime: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(snapshot.selectedDate),
           snapshot.day.currentTime > snapshot.day.wakeAnchor.time,
           snapshot.day.currentTime < snapshot.day.sleepAnchor.time {
            return snapshot.day.currentTime
        }
        return snapshot.day.wakeAnchor.time
    }
}

private struct TimelinePlacementPrompt: View {
    let candidate: TimelinePlacementCandidate
    let selectedDate: Date
    let suggestedTime: Date
    let onPlaceAtSuggestedTime: () -> Void
    let onPlaceAllDay: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    let onClearError: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.tasker.accentWash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Place this in your day")
                        .font(.tasker(.headline).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text("Drop on a time or move it to All Day.")
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Back", action: onBack)
                    .font(.tasker(.support).weight(.semibold))
                    .disabled(candidate.isApplying)
            }

            if candidate.isApplying {
                ProgressView("Scheduling...")
                    .font(.tasker(.support).weight(.semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            if let errorMessage = candidate.errorMessage {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(errorMessage)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Spacer(minLength: 0)
                    Button("Dismiss", action: onClearError)
                        .font(.tasker(.support).weight(.semibold))
                }
                .padding(10)
                .background(Color.tasker.surfacePrimary.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            placementActions
        }
        .padding(14)
        .background(Color.tasker.accentWash.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.tasker.accentPrimary.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Place \(candidate.title) in \(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))")
        .accessibilityAction(named: Text("Back to Replan")) {
            onBack()
        }
        .accessibilityAction(named: Text("Skip")) {
            onSkip()
        }
        .accessibilityAction(named: Text("Place at suggested time")) {
            onPlaceAtSuggestedTime()
        }
        .accessibilityAction(named: Text("Move to All Day")) {
            onPlaceAllDay()
        }
    }

    @ViewBuilder
    private var placementActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                Button("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", action: onPlaceAtSuggestedTime)
                    .buttonStyle(.borderedProminent)
                    .disabled(candidate.isApplying)
                Button("Move to All Day", action: onPlaceAllDay)
                    .buttonStyle(.bordered)
                    .disabled(candidate.isApplying)
                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)
                    .disabled(candidate.isApplying)
            }
            .font(.tasker(.support).weight(.semibold))
        } else {
            HStack(spacing: 10) {
                Button("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", action: onPlaceAtSuggestedTime)
                    .buttonStyle(.borderedProminent)
                    .disabled(candidate.isApplying)
                Button("Move to All Day", action: onPlaceAllDay)
                    .buttonStyle(.bordered)
                    .disabled(candidate.isApplying)
                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)
                    .disabled(candidate.isApplying)
            }
            .font(.tasker(.support).weight(.semibold))
        }
    }
}

private struct TimelinePlacementDock: View {
    let candidate: TimelinePlacementCandidate

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.tasker.textSecondary)
                .accessibilityHidden(true)
            Text(candidate.title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Drag to place")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.tasker.surfaceSecondary, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.tasker.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .draggable(candidate.taskID.uuidString)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.title), drag to place")
        .accessibilityIdentifier("home.needsReplan.placementDock")
    }
}

private struct TimelinePalette {
    let base: Color
    let fill: Color
    let progress: Color
    let icon: Color
    let ring: Color
    let halo: Color

    @MainActor
    static func resolve(from tintHex: String?) -> TimelinePalette {
        let base: Color
        if let tintHex {
            base = Color(uiColor: UIColor(taskerHex: tintHex))
        } else {
            base = Color.tasker.accentPrimary
        }
        return TimelinePalette(
            base: base,
            fill: base.opacity(0.16),
            progress: base.opacity(0.74),
            icon: base.opacity(0.96),
            ring: base.opacity(0.88),
            halo: base.opacity(0.12)
        )
    }
}

struct TimelineForedropBar: View {
    let onSnapAnchor: (ForedropAnchor) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        Capsule()
            .fill(Color.tasker.textTertiary.opacity(0.24))
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timeline reveal handle")
            .accessibilityHint("Drag to reveal the weekly layer behind the timeline.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onSnapAnchor(.midReveal)
            }
        .padding(.top, 6)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    onDragChanged(value.translation.height)
                }
                .onEnded { value in
                    onDragEnded(value.predictedEndTranslation.height)
                }
        )
        .accessibilityIdentifier("home.timeline.handle")
    }
}

private struct TimelinePlanningShelf: View {
    let allDayItems: [TimelinePlanItem]
    let inboxItems: [TimelinePlanItem]
    let placementCandidate: TimelinePlacementCandidate?
    let selectedDate: Date
    let onTaskTap: (TimelinePlanItem) -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let placementCandidate {
                Button {
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                } label: {
                    Label("Make All Day", systemImage: "calendar.badge.plus")
                        .font(.tasker(.support).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .dropDestination(for: String.self) { items, _ in
                    guard items.contains(placementCandidate.taskID.uuidString) else { return false }
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                    return true
                }
                .accessibilityHint("Places the replanned task in the all-day row for this date.")
            }

            if allDayItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All-day commitments")
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(allDayItems) { item in
                                TimelineShelfItemCard(item: item) {
                                    onTaskTap(item)
                                }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .accessibilityLabel("All-day commitments")
                    .accessibilityHint(allDayItems.count > 2 ? "Scroll horizontally to browse all all-day items." : "Double-tap an item to inspect it.")
                }
            }

            if inboxItems.isEmpty == false {
                TimelineInboxPlanningCard(
                    inboxItems: inboxItems,
                    onTaskTap: onTaskTap,
                    onScheduleInbox: onScheduleInbox
                )
            }
        }
    }
}

private struct TimelineShelfItemCard: View {
    let item: TimelinePlanItem
    let action: () -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(palette.fill)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: item.systemImageName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.icon)
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("All day")
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker.textSecondary)
                    Text(item.title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(2)
                }
            }
            .frame(width: 220, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue("All-day item")
        .accessibilityHint("Opens the item details.")
    }
}

private struct TimelineInboxPlanningCard: View {
    let inboxItems: [TimelinePlanItem]
    let onTaskTap: (TimelinePlanItem) -> Void
    let onScheduleInbox: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(inboxItems.count == 1 ? "1 inbox task ready" : "\(inboxItems.count) inbox tasks ready")
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker.textSecondary)
                    Text("Fill open time first")
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text("Pull something unplaced into the timeline before inspecting the rest of the day.")
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Schedule Inbox") {
                    onScheduleInbox()
                }
                .buttonStyle(.plain)
                .font(.tasker(.buttonSmall))
                .foregroundStyle(Color.tasker.accentOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.tasker.accentPrimary, in: Capsule())
                .accessibilityHint("Starts placing inbox tasks into open time.")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inboxItems.prefix(4)) { item in
                        Button {
                            onTaskTap(item)
                        } label: {
                            Text(item.title)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.tasker.surfacePrimary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if inboxItems.count > 4 {
                        Text("+\(inboxItems.count - 4) more")
                            .font(.tasker(.caption1).weight(.semibold))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.tasker.surfacePrimary, in: Capsule())
                            .accessibilityLabel("\(inboxItems.count - 4) more inbox tasks")
                    }
                }
                .padding(.trailing, 4)
            }
            .accessibilityLabel("Inbox task previews")
            .accessibilityHint(inboxItems.count > 4 ? "Scroll horizontally to inspect more inbox tasks." : "Swipe through inbox tasks to inspect them.")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
    }
}

struct DailyTimelineCanvas: View {
    let projection: TimelineDayProjection
    let layoutClass: TaskerLayoutClass
    let placementCandidate: TimelinePlacementCandidate?
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAtTime: (TimelinePlacementCandidate, Date) -> Void

    private let plan: TimelineCanvasLayoutPlan
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    init(
        projection: TimelineDayProjection,
        layoutClass: TaskerLayoutClass,
        placementCandidate: TimelinePlacementCandidate?,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAddTask: @escaping () -> Void,
        onScheduleInbox: @escaping () -> Void,
        onPlaceReplanAtTime: @escaping (TimelinePlacementCandidate, Date) -> Void
    ) {
        self.projection = projection
        self.layoutClass = layoutClass
        self.placementCandidate = placementCandidate
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.onPlaceReplanAtTime = onPlaceReplanAtTime
        self.plan = TimelineCanvasLayoutPlan(projection: projection)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            canvasBody(now: displayedNow(from: timeline.date))
        }
    }

    @ViewBuilder
    private func canvasBody(now: Date) -> some View {
        let presentation = TimelineDayPresentation(projection: projection, now: now)
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let timeGutterWidth = metrics.expandedTimeGutter
            let spineLaneWidth = metrics.expandedSpineLaneWidth
            let trailingLaneWidth = metrics.expandedTrailingLaneWidth
            let contentInset = metrics.expandedContentInset
            let capsuleMinWidth = metrics.expandedCapsuleMinWidth
            let timeToSpineGap = metrics.expandedTimeToSpineGap
            let spineCenterX = timeGutterWidth + timeToSpineGap + (spineLaneWidth / 2)
            let contentX = timeGutterWidth + timeToSpineGap + spineLaneWidth + contentInset
            let contentWidth = max(totalWidth - contentX - trailingLaneWidth - contentInset, 140)
            let completionX = totalWidth - (trailingLaneWidth / 2)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(TimelineVisualTokens.neutralStem)
                    .frame(width: 2, height: plan.contentHeight)
                    .offset(x: spineCenterX - 1)
                    .accessibilityHidden(true)

                if let currentBoundaryY = currentBoundaryY(now: now) {
                    Rectangle()
                        .fill((TimelinePalette.resolve(from: presentation.currentTintHex).progress).opacity(0.9))
                        .frame(width: 2, height: max(0, currentBoundaryY - plan.wakeAnchor.y))
                        .offset(x: spineCenterX - 1, y: plan.wakeAnchor.y)
                        .accessibilityHidden(true)
                }

                ForEach(plan.gaps) { gap in
                    TimelineStemSegments(
                        leading: presentation.row(for: gap.gap).stemLeading,
                        trailing: presentation.row(for: gap.gap).stemTrailing,
                        fallbackPalette: .resolve(from: presentation.currentTintHex),
                        width: 2,
                        height: gap.height
                    )
                    .offset(x: spineCenterX - 1, y: gap.startY)
                    .accessibilityHidden(true)
                }

                ForEach(plan.gaps) { gap in
                    TimelineGapPrompt(
                        gap: gap.gap,
                        row: presentation.row(for: gap.gap),
                        onAddTask: onAddTask,
                        onPlanBlock: onScheduleInbox
                    )
                        .frame(width: contentWidth, alignment: .leading)
                        .offset(
                            x: contentX,
                            y: gap.startY + min(max(10, gap.height * 0.16), max(gap.height - 56, 10))
                        )
                }

                anchorView(
                    plan.wakeAnchor,
                    row: presentation.row(for: plan.wakeAnchor.anchor),
                    timeGutterWidth: timeGutterWidth,
                    spineCenterX: spineCenterX,
                    contentX: contentX
                )

                ForEach(plan.items) { positioned in
                    let columnSpacing: CGFloat = 10
                    let widthForColumns = max(contentWidth - CGFloat(max(positioned.columnCount - 1, 0)) * columnSpacing, capsuleMinWidth)
                    let columnWidth = widthForColumns / CGFloat(positioned.columnCount)
                    let itemX = contentX + CGFloat(positioned.columnIndex) * (columnWidth + columnSpacing)

                    TimelineStemSegments(
                        leading: presentation.row(for: positioned.item).stemLeading,
                        trailing: presentation.row(for: positioned.item).stemTrailing,
                        fallbackPalette: TimelinePalette.resolve(from: positioned.item.tintHex),
                        width: 2,
                        height: positioned.height
                    )
                    .offset(x: spineCenterX - 1, y: positioned.y)
                    .accessibilityHidden(true)

                    timelineItemView(
                        positioned,
                        row: presentation.row(for: positioned.item),
                        itemX: itemX,
                        itemWidth: columnWidth,
                        timeGutterWidth: timeGutterWidth,
                        contentX: contentX,
                        contentWidth: contentWidth,
                        spineCenterX: spineCenterX,
                        completionX: completionX
                    )
                }

                anchorView(
                    plan.sleepAnchor,
                    row: presentation.row(for: plan.sleepAnchor.anchor),
                    timeGutterWidth: timeGutterWidth,
                    spineCenterX: spineCenterX,
                    contentX: contentX
                )
            }
        }
        .frame(height: plan.contentHeight + 36)
        .dropDestination(for: String.self) { items, location in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            onPlaceReplanAtTime(placementCandidate, plan.date(atY: location.y))
            return true
        }
    }

    private func displayedNow(from timelineDate: Date) -> Date {
        Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
    }

    private func currentBoundaryY(now: Date) -> CGFloat? {
        guard Calendar.current.isDate(projection.date, inSameDayAs: now),
              now >= plan.visibleStart,
              now <= plan.visibleEnd else {
            return nil
        }
        let minutes = CGFloat(Calendar.current.dateComponents([.minute], from: plan.visibleStart, to: now).minute ?? 0)
        return plan.topInset + (minutes * plan.pointsPerMinute)
    }

    @ViewBuilder
    private func anchorView(
        _ anchor: TimelineCanvasLayoutPlan.PositionedAnchor,
        row: TimelineRenderableRow,
        timeGutterWidth: CGFloat,
        spineCenterX: CGFloat,
        contentX: CGFloat
    ) -> some View {
        let iconSize = metrics.expandedAnchorCircleSize
        let anchorCenterY = anchor.y
        let iconTop = max(anchorCenterY - (iconSize / 2), 0)

        Text(anchor.anchor.time.formatted(date: .omitted, time: .shortened))
            .font(.tasker(.meta))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(anchorCenterY - 12, 0))

        Circle()
            .fill(TimelineVisualTokens.anchorCapsuleFill)
            .frame(width: iconSize, height: iconSize)
            .overlay {
                Image(systemName: anchor.anchor.systemImageName)
                    .font(.system(size: metrics.expandedAnchorIconSize, weight: .semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .accessibilityHidden(true)
            }
            .offset(x: spineCenterX - (iconSize / 2), y: iconTop)
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
            Text(anchor.anchor.title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
                .lineLimit(2)
            if let subtitle = row.subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .lineLimit(1)
            }
        }
        .offset(x: contentX, y: max(anchorCenterY - 22, 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.anchor.title), \(anchor.anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityValue(anchor.anchor.id == "wake" ? "Timeline start" : "Timeline end")
    }

    @ViewBuilder
    private func timelineItemView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedItem,
        row: TimelineRenderableRow,
        itemX: CGFloat,
        itemWidth: CGFloat,
        timeGutterWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        spineCenterX: CGFloat,
        completionX: CGFloat
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
            .font(row.isCurrentRailEmphasis ? .tasker(.meta).weight(.semibold) : .tasker(.meta))
            .foregroundStyle(row.isCurrentRailEmphasis ? Color.tasker.textPrimary : TimelineVisualTokens.metaText)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(positioned.y - 2, 0))

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

    @ViewBuilder
    private func timelineItemTextContent(row: TimelineRenderableRow, item: TimelinePlanItem, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metaText(for: row, item: item))
                .font(.tasker(row.temporalState == .currentTask && isExpanded ? .callout : .meta).weight(row.temporalState == .currentTask ? .semibold : .medium))
                .foregroundStyle(metaColor(for: row, item: item))
                .multilineTextAlignment(.leading)
                .lineLimit(1)

            Text(item.title)
                .font(.tasker(isExpanded && row.temporalState == .currentTask ? .title3 : .headline))
                .foregroundStyle(titleColor(for: row, item: item))
                .strikethrough(item.isComplete, color: titleColor(for: row, item: item))
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if row.utilityItems.isEmpty == false {
                TimelineUtilityRow(items: row.utilityItems)
            }
        }
    }

    private func timeLabel(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate else { return "All day" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    private func metaText(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil, anchor: TimelineAnchorItem? = nil) -> String {
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

    private func metaColor(for row: TimelineRenderableRow, item: TimelinePlanItem) -> Color {
        switch row.temporalState {
        case .pastCompleted:
            return Color.tasker.textTertiary.opacity(0.72)
        case .pastIncomplete:
            return Color.tasker.statusWarning.opacity(0.92)
        case .currentTask:
            return Color.tasker.textPrimary.opacity(0.92)
        default:
            return TimelineVisualTokens.metaText
        }
    }

    private func titleColor(for row: TimelineRenderableRow, item: TimelinePlanItem) -> Color {
        switch row.temporalState {
        case .pastCompleted:
            return Color.tasker.textSecondary.opacity(0.72)
        case .pastIncomplete:
            return Color.tasker.textPrimary.opacity(0.92)
        case .currentTask:
            return Color.tasker.textPrimary
        default:
            return TimelineItemVisuals.titleColor(for: item)
        }
    }

    private func ringColor(for row: TimelineRenderableRow, palette: TimelinePalette) -> Color {
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

    private func accessibilityLabel(for row: TimelineRenderableRow, item: TimelinePlanItem) -> String {
        var parts = [item.title]
        parts.append(metaText(for: row, item: item))
        if row.utilityItems.isEmpty == false {
            parts.append(row.utilityItems.map(\.accessibilityLabel).joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}

private struct DailyTimelineCompactView: View {
    let projection: TimelineDayProjection
    let layoutClass: TaskerLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    private let plan: TimelineCompactLayoutPlan
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    init(
        projection: TimelineDayProjection,
        layoutClass: TaskerLayoutClass,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAddTask: @escaping () -> Void,
        onScheduleInbox: @escaping () -> Void
    ) {
        self.projection = projection
        self.layoutClass = layoutClass
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.plan = TimelineCompactLayoutPlan(projection: projection, layoutClass: layoutClass)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(projection: projection, now: now)

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
    private func rowView(for entry: TimelineCompactLayoutPlan.Entry, presentation: TimelineDayPresentation) -> some View {
        switch entry {
        case .anchor(let anchor):
            TimelineCompactAnchorRow(
                anchor: anchor.anchor,
                row: presentation.row(for: anchor.anchor),
                layoutClass: layoutClass
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
            TimelineCompactGapRow(
                gap: gap.gap,
                row: presentation.row(for: gap.gap),
                layoutClass: layoutClass,
                onAddTask: onAddTask,
                onScheduleInbox: onScheduleInbox
            )
            .frame(minHeight: gap.rowHeight, alignment: .center)
        }
    }

    private func row(for entry: TimelineCompactLayoutPlan.Entry, presentation: TimelineDayPresentation) -> TimelineRenderableRow {
        switch entry {
        case .anchor(let anchor):
            return presentation.row(for: anchor.anchor)
        case .item(let item):
            return presentation.row(for: item.item)
        case .gap(let gap):
            return presentation.row(for: gap.gap)
        }
    }

    private func connector(trailing: TimelineStemSegmentState, leading: TimelineStemSegmentState) -> some View {
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

private struct TimelineCompactAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let layoutClass: TaskerLayoutClass

    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(anchor.time.formatted(date: .omitted, time: .shortened))
                .font(.tasker(.meta))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: metrics.compactTimeGutter, alignment: .trailing)

            Color.clear
                .frame(width: metrics.compactTimeToLaneGap)

            Circle()
                .fill(TimelineVisualTokens.anchorCapsuleFill)
                .frame(width: metrics.compactAnchorCircleSize, height: metrics.compactAnchorCircleSize)
                .overlay {
                    Image(systemName: anchor.systemImageName)
                        .font(.system(size: metrics.compactAnchorIconSize, weight: .semibold))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(width: metrics.compactLaneWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(anchor.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
                if let subtitle = row.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(TimelineVisualTokens.utilityText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if anchor.isActionable {
                TimelineCompletionRing(
                    color: Color.tasker.accentPrimary,
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityValue(anchor.id == "wake" ? "Timeline start" : "Timeline end")
    }
}

private struct TimelineCompactItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let capsuleHeight: CGFloat
    let layoutClass: TaskerLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(timelineRailText(for: item))
                .font(row.isCurrentRailEmphasis ? .tasker(.meta).weight(.semibold) : .tasker(.meta))
                .foregroundStyle(row.isCurrentRailEmphasis ? Color.tasker.textPrimary : TimelineVisualTokens.metaText)
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
                        .font(.tasker(.meta).weight(row.temporalState == .currentTask ? .semibold : .medium))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                    Text(item.title)
                        .font(.tasker(.headline).weight(.semibold))
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

private struct TimelineCompactGapRow: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let layoutClass: TaskerLayoutClass
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        Menu {
            Button(TimelineGapAction.addTask.title, action: onAddTask)
            Button(TimelineGapAction.planBlock.title, action: onScheduleInbox)
            Button(TimelineGapAction.dismiss.title, role: .destructive) {}
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text(gap.startDate.formatted(date: .omitted, time: .shortened))
                    .font(row.isCurrentRailEmphasis ? .tasker(.meta).weight(.semibold) : .tasker(.meta))
                    .foregroundStyle(row.isCurrentRailEmphasis ? Color.tasker.textPrimary : TimelineVisualTokens.metaText.opacity(0.92))
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: metrics.compactLaneWidth)
                    .accessibilityHidden(true)

                Text(timelineGapPromptText(for: gap, row: row))
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
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

private struct TimelineCompactConnector: View {
    let laneWidth: CGFloat
    let height: CGFloat
    let topState: TimelineStemSegmentState
    let bottomState: TimelineStemSegmentState
    private let spec = TimelineRailPresentationSpec.compactConnector

    var body: some View {
        ZStack {
            Path { path in
                let x = laneWidth / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(
                Color.tasker.strokeHairline.opacity(spec.opacity),
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

private struct DailyTimelineAgendaView: View {
    let projection: TimelineDayProjection
    let layoutClass: TaskerLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    private enum Entry: Identifiable {
        case anchor(TimelineAnchorItem)
        case gap(TimelineGap)
        case item(TimelinePlanItem)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            case .item(let item):
                return "item:\(item.id)"
            }
        }
    }

    private var entries: [Entry] {
        let items = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let gaps = projection.gaps.sorted { $0.startDate < $1.startDate }
        var itemIndex = 0
        var gapIndex = 0
        var result: [Entry] = [.anchor(projection.wakeAnchor)]

        while itemIndex < items.count || gapIndex < gaps.count {
            if itemIndex >= items.count {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
                continue
            }
            if gapIndex >= gaps.count {
                result.append(.item(items[itemIndex]))
                itemIndex += 1
                continue
            }
            if gaps[gapIndex].startDate <= (items[itemIndex].startDate ?? .distantFuture) {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
            } else {
                result.append(.item(items[itemIndex]))
                itemIndex += 1
            }
        }

        result.append(.anchor(projection.sleepAnchor))
        return result
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(projection: projection, now: now)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                    switch entry {
                    case .anchor(let anchor):
                        TimelineAgendaAnchorRow(anchor: anchor, row: presentation.row(for: anchor))
                            .environment(\.taskerLayoutClass, layoutClass)
                    case .gap(let gap):
                        TimelineGapPrompt(gap: gap, row: presentation.row(for: gap), onAddTask: onAddTask, onPlanBlock: onScheduleInbox)
                            .environment(\.taskerLayoutClass, layoutClass)
                    case .item(let item):
                        TimelineAgendaItemRow(item: item, row: presentation.row(for: item), onTaskTap: onTaskTap, onToggleComplete: onToggleComplete)
                            .environment(\.taskerLayoutClass, layoutClass)
                    }
                }
            }
        }
    }
}

private struct TimelineAgendaAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(TimelineVisualTokens.anchorCapsuleFill)
                .frame(width: metrics.agendaAnchorCircleSize, height: metrics.agendaAnchorCircleSize)
                .overlay {
                    Image(systemName: anchor.systemImageName)
                        .font(.system(size: metrics.agendaAnchorIconSize, weight: .semibold))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .accessibilityHidden(true)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(anchor.time.formatted(date: .omitted, time: .shortened))
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)
                Text(anchor.title)
                    .font(.tasker(.title3))
                    .foregroundStyle(Color.tasker.textPrimary)
                if let subtitle = row.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(TimelineVisualTokens.utilityText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
    }
}

private struct TimelineAgendaItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TimelineCapsule(item: item, row: row, palette: palette)
                .frame(width: metrics.agendaCapsuleWidth, height: 88)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(timelineMetaText(for: row, item: item))
                    .font(.tasker(.meta))
                    .foregroundStyle(timelineMetaColor(for: row))
                Button {
                    onTaskTap(item)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.tasker(row.temporalState == .currentTask ? .title3 : .headline))
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
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct TimelineStemSegments: View {
    let leading: TimelineStemSegmentState
    let trailing: TimelineStemSegmentState
    let fallbackPalette: TimelinePalette
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(timelineStemColor(for: leading, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
            Rectangle()
                .fill(timelineStemColor(for: trailing, fallbackPalette: fallbackPalette))
                .frame(width: width, height: height / 2)
        }
        .frame(width: width, height: height)
    }
}

private struct TimelineUtilityRow: View {
    let items: [TimelineUtilityItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                utilityItemView(entry.element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func utilityItemView(_ item: TimelineUtilityItem) -> some View {
        switch item {
        case .checklist(let summary):
            Label("\(summary.completedCount)/\(summary.totalCount)", systemImage: "checklist")
                .font(.tasker(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.tasker.surfaceSecondary, in: Capsule())
        case .note:
            utilityGlyph("note.text")
        case .recurring:
            utilityGlyph("repeat")
        case .calendar:
            utilityGlyph("calendar")
        case .meeting:
            utilityGlyph("video")
        case .project(let name):
            Label(name, systemImage: "line.3.horizontal.decrease.circle")
                .font(.tasker(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .lineLimit(1)
        }
    }

    private func utilityGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(TimelineVisualTokens.utilityText)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

private struct TimelineCapsule: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let palette: TimelinePalette
    @Environment(\.taskerLayoutClass) private var layoutClass

    var body: some View {
        GeometryReader { proxy in
            let capsuleShape = RoundedRectangle(cornerRadius: proxy.size.width / 2, style: .continuous)
            let progress = min(max(row.progressRatio, 0), 1)
            let progressHeight = proxy.size.height * progress
            let transitionHeight = min(12, max(6, proxy.size.height * 0.10))
            let isCompleted = row.temporalState == .pastCompleted
            let isCurrent = row.temporalState == .currentTask
            let isPastIncomplete = row.temporalState == .pastIncomplete
            let isExpandedPad = layoutClass == .padRegular || layoutClass == .padExpanded
            let baseFill: Color = {
                if isCompleted {
                    return palette.progress.opacity(0.92)
                }
                if isPastIncomplete {
                    return palette.fill.opacity(0.28)
                }
                return TimelineVisualTokens.futureCapsule
            }()
            let iconColor: Color = {
                if isCompleted || isCurrent {
                    return Color.white.opacity(0.96)
                }
                if isPastIncomplete {
                    return palette.icon.opacity(0.9)
                }
                return palette.icon
            }()

            ZStack(alignment: .top) {
                capsuleShape
                    .fill(baseFill)

                if isCurrent, progressHeight > 0 {
                    VStack(spacing: 0) {
                        capsuleShape
                            .fill(palette.progress)
                            .frame(height: progressHeight)
                        Spacer(minLength: 0)
                    }
                    .clipShape(capsuleShape)

                    if progressHeight < proxy.size.height {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.progress.opacity(0),
                                        palette.halo.opacity(isExpandedPad ? 0.54 : 0.82),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: transitionHeight)
                            .offset(y: max(0, progressHeight - (transitionHeight / 2)))
                            .clipShape(capsuleShape)
                    }
                }

                Image(systemName: item.systemImageName)
                    .font(.system(size: proxy.size.width >= 56 ? 22 : (proxy.size.width >= 48 ? 20 : 18), weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay {
                capsuleShape
                    .stroke(
                        isCurrent
                            ? palette.halo.opacity(isExpandedPad ? 0.74 : 0.9)
                            : (isCompleted
                                ? palette.halo.opacity(0.22)
                                : (layoutClass.isPad ? TimelineVisualTokens.futureCapsuleStroke : palette.halo.opacity(0.58))),
                        lineWidth: isCurrent ? 1.25 : 1
                    )
            }
        }
    }
}

private struct TimelineCompletionRing: View {
    let color: Color
    let isCompleted: Bool
    let isInteractive: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Group {
            if isInteractive {
                Button(action: action) {
                    ringBody
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityValue(isCompleted ? "Completed" : "Not completed")
            } else {
                ringBody
                    .accessibilityHidden(true)
            }
        }
    }

    private var ringBody: some View {
        ZStack {
            Circle()
                .strokeBorder(color.opacity(0.82), lineWidth: 2.2)
                .background(
                    Circle()
                        .fill(isCompleted ? color.opacity(0.16) : Color.clear)
                )
                .frame(width: 28, height: 28)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }
}

private struct TimelineGapPrompt: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let onAddTask: () -> Void
    let onPlanBlock: () -> Void
    @Environment(\.taskerLayoutClass) private var layoutClass

    var body: some View {
        Menu {
            Button(TimelineGapAction.addTask.title, action: onAddTask)
            Button(TimelineGapAction.planBlock.title, action: onPlanBlock)
            Button(TimelineGapAction.dismiss.title, role: .destructive) {}
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .accessibilityHidden(true)
                Text(timelineGapPromptText(for: gap, row: row))
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, layoutClass.isPad ? 6 : 8)
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }
}

private extension TimelineGap {
    var compactDurationText: String {
        TimelineFormatting.durationText(duration)
    }
}

struct TimelineBackdropWeekView: View {
    let snapshot: HomeTimelineSnapshot
    let onSelectDate: (Date) -> Void
    let onStartReplanForDate: (Date) -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(snapshot.week.days) { day in
                TimelineWeekDayCell(
                    day: day,
                    isSelected: Calendar.current.isDate(day.date, inSameDayAs: snapshot.selectedDate),
                    isAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
                    action: {
                        onSelectDate(day.date)
                    },
                    onStartReplan: {
                        onStartReplanForDate(day.date)
                    },
                    placementCandidate: snapshot.placementCandidate,
                    onDropPlacement: { candidate in
                        onPlaceReplanAllDay(candidate, day.date)
                    }
                )
            }
        }
        .padding(.top, 4)
        .reportHeight(to: TimelineBackdropWeekHeightPreferenceKey.self)
        .accessibilityIdentifier("home.weeklyCalendar")
    }
}

private struct TimelineWeekDayCell: View {
    let day: TimelineWeekDaySummary
    let isSelected: Bool
    let isAccessibilityLayout: Bool
    let action: () -> Void
    let onStartReplan: () -> Void
    let placementCandidate: TimelinePlacementCandidate?
    let onDropPlacement: (TimelinePlacementCandidate) -> Void

    private var paletteColor: Color {
        switch day.loadLevel {
        case .light:
            return Color.tasker.statusSuccess
        case .balanced:
            return Color.tasker.accentPrimary
        case .busy:
            return Color.tasker.statusWarning
        }
    }

    var body: some View {
        VStack(spacing: isAccessibilityLayout ? 8 : 6) {
            Button(action: action) {
                dayContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Switches the daily timeline to this date.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())

            if canStartReplan {
                Button(action: onStartReplan) {
                    Label(replanActionTitle, systemImage: "arrow.triangle.2.circlepath")
                        .font(.tasker(.support).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color.tasker.accentWash.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(replanAccessibilityLabel)
                .accessibilityHint("Starts Plan the Day for this past date.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: isAccessibilityLayout ? 176 : 152, alignment: .top)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isSelected ? Color.tasker.surfacePrimary : Color.tasker.surfacePrimary.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? Color.tasker.accentPrimary.opacity(0.25) : Color.tasker.strokeHairline.opacity(0.45), lineWidth: 1)
        )
        .contextMenu {
            if canStartReplan {
                Button(replanAccessibilityLabel, systemImage: "arrow.triangle.2.circlepath") {
                    onStartReplan()
                }
            }
        }
        .accessibilityAction(named: Text(replanAccessibilityLabel)) {
            if canStartReplan {
                onStartReplan()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            onDropPlacement(placementCandidate)
            return true
        }
    }

    private var dayContent: some View {
        VStack(spacing: isAccessibilityLayout ? 8 : 6) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.tasker(.meta))
                    .foregroundStyle(Color.tasker.textSecondary)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                        .frame(width: 44, height: 44)
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.tasker(.headline))
                        .foregroundStyle(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                }

                Text(day.summaryText)
                    .font(.tasker(isAccessibilityLayout ? .caption1 : .meta).weight(.semibold))
                    .foregroundStyle(isSelected ? Color.tasker.textPrimary : paletteColor)
                    .lineLimit(isAccessibilityLayout ? 2 : 1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    ForEach(Array(day.tintHexes.prefix(3).enumerated()), id: \.offset) { entry in
                        Circle()
                            .fill(Color(uiColor: UIColor(taskerHex: entry.element)).opacity(0.88))
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    if day.allDayCount > 0 {
                        Text("\(day.allDayCount)")
                            .font(.tasker(.caption2).weight(.semibold))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.tasker.surfaceSecondary, in: Capsule())
                    }
                }
                .frame(minHeight: 12)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var accessibilityLabel: String {
        let allDayText = day.allDayCount > 0 ? ", \(day.allDayCount) all-day items" : ""
        let replanText = day.replanEligibleCount > 0 ? ", \(day.replanEligibleCount) needs replan" : ""
        return "\(day.date.formatted(.dateTime.weekday(.wide).day().month())), \(day.summaryText)\(allDayText)\(replanText)"
    }

    private var canStartReplan: Bool {
        let calendar = Calendar.current
        return day.replanEligibleCount > 0
            && calendar.startOfDay(for: day.date) < calendar.startOfDay(for: Date())
    }

    private var replanActionTitle: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }

    private var replanAccessibilityLabel: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }
}
