import SwiftUI

extension TimelineCanvasLayoutPlan {
    static func maxVisualColumns(for layoutClass: LifeBoardLayoutClass) -> Int {
        switch layoutClass {
        case .phone:
            return 3
        case .padCompact, .padRegular, .padExpanded:
            return 4
        }
    }

    var contentHeight: CGFloat {
        max(
            visualElements.map { $0.y + $0.height }.max() ?? 0,
            endMarker.centerY + (Self.endMarkerHitArea / 2)
        ) + bottomInset
    }

    func date(atY y: CGFloat, calendar: Calendar = .current) -> Date {
        let rawMinutes = max(0, (y - wakeAnchor.y) / pointsPerMinute)
        let visibleSpanMinutes = CGFloat(calendar.dateComponents([.minute], from: visibleStart, to: visibleEnd).minute ?? 0)
        let clampedMinutes = min(rawMinutes, max(visibleSpanMinutes, 0))
        let roundedMinutes = Int((clampedMinutes / 15).rounded() * 15)
        return calendar.date(byAdding: .minute, value: roundedMinutes, to: visibleStart) ?? visibleStart
    }

    func currentTimeY(now: Date, selectedDate: Date, calendar: Calendar = .current) -> CGFloat? {
        guard calendar.isDate(selectedDate, inSameDayAs: now),
              now >= visibleStart,
              now <= visibleEnd else {
            return nil
        }
        return visualTimeY(for: now)
    }

    struct VisualTimeAnchor {
        let date: Date
        let y: CGFloat
    }

    struct VisualTimeSegment {
        let startDate: Date
        let endDate: Date
        let startY: CGFloat
        let endY: CGFloat

        var anchors: [VisualTimeAnchor] {
            [
                VisualTimeAnchor(date: startDate, y: startY),
                VisualTimeAnchor(date: endDate, y: endY)
            ]
        }

        func contains(_ date: Date) -> Bool {
            startDate <= date && date < endDate
        }

        func y(for date: Date) -> CGFloat {
            let duration = max(endDate.timeIntervalSince(startDate), 1)
            let ratio = min(max(date.timeIntervalSince(startDate) / duration, 0), 1)
            return startY + ((endY - startY) * CGFloat(ratio))
        }
    }

    func visualTimeY(for date: Date) -> CGFloat? {
        if date <= visibleStart {
            return visualRoutineAnchorY(id: wakeAnchor.id)
        }
        if date >= visibleEnd {
            return visualRoutineAnchorY(id: sleepAnchor.id)
        }

        let segments = visualTimeSegments()
        if let activeSegment = segments.first(where: { $0.contains(date) }) {
            return activeSegment.y(for: date)
        }

        let anchors = visualTimeAnchors(from: segments)
        guard anchors.isEmpty == false else { return nil }

        let exactAnchors = anchors.filter { abs($0.date.timeIntervalSince(date)) < 0.5 }
        if let exactY = exactAnchors.map(\.y).max() {
            return exactY
        }

        let previous = anchors.last { $0.date < date }
        let next = anchors.first { $0.date > date }

        switch (previous, next) {
        case (.some(let previous), .some(let next)):
            let duration = max(next.date.timeIntervalSince(previous.date), 1)
            let ratio = min(max(date.timeIntervalSince(previous.date) / duration, 0), 1)
            let interpolated = previous.y + ((next.y - previous.y) * CGFloat(ratio))
            return min(max(interpolated, min(previous.y, next.y)), max(previous.y, next.y))
        case (.some(let previous), .none):
            return previous.y
        case (.none, .some(let next)):
            return next.y
        case (.none, .none):
            return nil
        }
    }

    func visualTimeSegments() -> [VisualTimeSegment] {
        visualElements.compactMap { positioned -> VisualTimeSegment? in
            switch positioned.element {
            case .meetingCard, .taskMarker, .taskCard, .flock:
                let startDate = positioned.element.temporalStart
                let endDate = positioned.element.temporalEnd
                guard endDate > startDate else { return nil }
                return VisualTimeSegment(
                    startDate: startDate,
                    endDate: endDate,
                    startY: positioned.y,
                    endY: positioned.bottomY
                )
            case .routineMarker, .gapPrompt, .emptyState:
                return nil
            }
        }
        .sorted {
            if $0.startDate != $1.startDate {
                return $0.startDate < $1.startDate
            }
            return $0.endDate < $1.endDate
        }
    }

    func visualTimeAnchors(from segments: [VisualTimeSegment]) -> [VisualTimeAnchor] {
        let routineAnchors = visualElements.compactMap { positioned -> VisualTimeAnchor? in
            guard case .routineMarker(let model) = positioned.element else { return nil }
            return VisualTimeAnchor(date: model.anchor.time, y: positioned.centerY)
        }
        return (routineAnchors + segments.flatMap(\.anchors))
            .sorted {
                if $0.date != $1.date {
                    return $0.date < $1.date
                }
                return $0.y < $1.y
            }
    }

    func visualRoutineAnchorY(id: String) -> CGFloat? {
        visualElements.first { positioned in
            guard case .routineMarker(let model) = positioned.element else { return false }
            return model.anchor.id == id
        }?.centerY
    }

    static func positionedItems(from candidates: [Candidate]) -> [PositionedItem] {
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

    static func positionedBlocks(
        from candidates: [Candidate],
        pointsPerMinute: CGFloat,
        minimumItemHeight: CGFloat,
        maxVisualColumns: Int
    ) -> [PositionedBlock] {
        let rawBlocks = TimelineTimeBlock.make(from: candidates.map {
            TimelineTimeBlock.Input(
                item: $0.item,
                startDate: $0.startDate,
                endDate: $0.endDate,
                startMinute: $0.startMinute,
                endMinute: $0.endMinute,
                y: $0.y,
                height: $0.height
            )
        }, maxVisualColumns: maxVisualColumns)

        var previousVisualBottom: CGFloat?

        return rawBlocks.map { block in
            let durationHeight = max((block.endMinute - block.startMinute) * pointsPerMinute, minimumItemHeight)
            let visualHeight = block.isConflict
                ? max(TimelineFlockModel.displayHeight(itemCount: block.items.count), flockMinHeight)
                : singleVisualHeight(for: block.items.first, durationHeight: durationHeight, minimumItemHeight: minimumItemHeight)
            let minimumVisualY = (previousVisualBottom ?? -.infinity) + minimumBlockGap
            let visualY = max(block.y, minimumVisualY)
            previousVisualBottom = visualY + visualHeight
            return PositionedBlock(
                block: block,
                temporalY: block.y,
                visualY: visualY,
                visualHeight: visualHeight,
                wasVisuallyShifted: visualY > block.y + 0.5,
                startMinute: block.startMinute,
                endMinute: block.endMinute
            )
        }
    }

    static func positionedVisualElements(
        projection: TimelineDayProjection,
        wakeY: CGFloat,
        sleepY: CGFloat,
        blocks: [PositionedBlock],
        gaps: [PositionedGap],
        now: Date,
        calendar: Calendar
    ) -> (elements: [PositionedVisualTimelineElement], longGapIndicators: [PositionedLongGapIndicator]) {
        let rawElements = rawVisualElements(
            projection: projection,
            wakeY: wakeY,
            sleepY: sleepY,
            blocks: blocks,
            gaps: gaps,
            calendar: calendar
        )
        .sorted { lhs, rhs in
            VisualTimelineElement.elementSort(lhs, rhs, now: now)
        }

        var cursorY: CGFloat = wakeY - (routineMarkerHeight / 2)
        var previousElement: VisualTimelineElement?
        var positionedElements: [PositionedVisualTimelineElement] = []
        var longGapIndicators: [PositionedLongGapIndicator] = []

        for element in rawElements {
            let temporalY = element.temporalY
            let gapHeight: CGFloat
            if let previousElement {
                let minutes = minutesBetween(previousElement.temporalEnd, element.temporalStart, calendar: calendar)
                gapHeight = visualGap(for: minutes)
                if projection.timelineDensityMode == .normal,
                   minutes >= 180,
                   previousElement.isPlottedContent,
                   element.isPlottedContent {
                    longGapIndicators.append(PositionedLongGapIndicator(
                        id: "long-gap:\(previousElement.id):\(element.id)",
                        text: longGapIndicatorText(for: minutes),
                        y: cursorY + ((gapHeight - 22) / 2),
                        height: 22
                    ))
                }
            } else {
                gapHeight = 0
            }

            let visualY = max(cursorY + gapHeight, 0)
            let positioned = PositionedVisualTimelineElement(
                element: element,
                temporalY: temporalY,
                visualY: visualY,
                height: element.measuredHeight,
                wasShifted: visualY > temporalY + 0.5
            )
            positionedElements.append(positioned)
            cursorY = positioned.bottomY
            previousElement = element
        }

        return (positionedElements, longGapIndicators)
    }

    static func visualGap(for gapMinutes: Int) -> CGFloat {
        switch gapMinutes {
        case ...0:
            return minimumBlockGap
        case 1...15:
            return max(CGFloat(gapMinutes) * 1.2, minimumBlockGap)
        case 16...60:
            return CGFloat(gapMinutes) * 1.2
        case 61...180:
            return min(112, 72 + CGFloat(gapMinutes - 60) * 0.35)
        default:
            return 112
        }
    }

    static func minutesBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.minute], from: start, to: end).minute ?? 0)
    }

    static func longGapIndicatorText(for minutes: Int) -> String {
        "· · · \(TimelineFormatting.durationText(TimeInterval(minutes * 60))) free · · ·"
    }

    static func midpointDate(from start: Date, to end: Date, calendar: Calendar) -> Date {
        let minutes = max(0, calendar.dateComponents([.minute], from: start, to: end).minute ?? 0)
        return calendar.date(byAdding: .minute, value: minutes / 2, to: start) ?? start
    }

    static func lightPromptDate(for projection: TimelineDayProjection, blocks: [PositionedBlock], calendar: Calendar) -> Date {
        let latestEnd = blocks.map(\.block.endDate).max() ?? projection.wakeAnchor.time
        let remaining = max(0, calendar.dateComponents([.minute], from: latestEnd, to: projection.sleepAnchor.time).minute ?? 0)
        return calendar.date(byAdding: .minute, value: max(30, remaining / 2), to: latestEnd) ?? latestEnd
    }

    static func spineExtent(for elements: [PositionedVisualTimelineElement]) -> SpineExtent {
        guard let first = elements.first, let last = elements.last else {
            return SpineExtent(startY: 0, solidEndY: 0, fadeStartY: 16, fadeEndY: 56)
        }
        let startY = first.centerY
        let solidEndY = last.centerY
        let fadeStartY = solidEndY + spineFadeOffset
        return SpineExtent(
            startY: startY,
            solidEndY: solidEndY,
            fadeStartY: fadeStartY,
            fadeEndY: fadeStartY + spineFadeHeight
        )
    }

    static func endMarker(
        for elements: [PositionedVisualTimelineElement],
        projection: TimelineDayProjection,
        spineExtent: SpineExtent,
        calendar: Calendar
    ) -> EndMarker {
        let lastElement = elements.last?.element
        let suggestedDate: Date
        if case .routineMarker(let model) = lastElement, model.anchor.id == projection.sleepAnchor.id {
            suggestedDate = model.anchor.time.addingTimeInterval(15 * 60)
        } else if let lastElement {
            suggestedDate = lastElement.temporalEnd
        } else {
            suggestedDate = projection.sleepAnchor.time.addingTimeInterval(15 * 60)
        }
        let selectedDay = calendar.startOfDay(for: projection.date)
        let suggestedDay = calendar.startOfDay(for: suggestedDate)
        return EndMarker(
            centerY: spineExtent.fadeEndY + endMarkerTopGapAfterFade + (endMarkerHitArea / 2),
            suggestedDate: suggestedDate,
            accessibilityValue: suggestedDay > selectedDay ? "Later tonight" : suggestedDate.formatted(date: .omitted, time: .shortened)
        )
    }

    static func shouldRenderTaskAsCard(_ item: TimelinePlanItem) -> Bool {
        guard item.source == .task else { return false }
        if item.isPinnedFocusTask { return true }
        if item.taskPriority == .max { return true }
        guard item.taskPriority?.isHighPriority == true else { return false }
        return (item.duration ?? 0) >= 45 * 60
    }

    static func singleVisualHeight(
        for item: TimelinePlanItem?,
        durationHeight: CGFloat,
        minimumItemHeight: CGFloat
    ) -> CGFloat {
        guard let item else { return max(durationHeight, minimumItemHeight, cardVisualHeight) }
        if item.source == .calendarEvent {
            return max(calendarCardVisualHeight, durationHeight)
        }
        if shouldRenderTaskAsCard(item) {
            return max(cardVisualHeight, durationHeight)
        }
        return max(taskMarkerMinHeight, min(max(durationHeight, taskMarkerIdealHeight), 72))
    }

    static func minuteOffset(for date: Date, start: Date, calendar: Calendar) -> CGFloat {
        CGFloat(calendar.dateComponents([.minute], from: start, to: date).minute ?? 0)
    }
}
