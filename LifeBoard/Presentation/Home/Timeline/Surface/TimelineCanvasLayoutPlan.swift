import SwiftUI

struct TimelineCanvasLayoutPlan: Equatable {
    struct Candidate {
        let item: TimelinePlanItem
        let startDate: Date
        let endDate: Date
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

    struct PositionedBlock: Equatable, Identifiable {
        let block: TimelineTimeBlock
        let temporalY: CGFloat
        let visualY: CGFloat
        let visualHeight: CGFloat
        let wasVisuallyShifted: Bool
        let startMinute: CGFloat
        let endMinute: CGFloat

        var id: String { block.id }
        var y: CGFloat { visualY }
        var height: CGFloat { visualHeight }
    }

    struct PositionedVisualTimelineElement: Equatable, Identifiable {
        let element: VisualTimelineElement
        let temporalY: CGFloat
        let visualY: CGFloat
        let height: CGFloat
        let wasShifted: Bool

        var id: String { element.id }
        var y: CGFloat { visualY }
        var centerY: CGFloat { visualY + (height / 2) }
        var bottomY: CGFloat { visualY + height }
    }

    struct PositionedLongGapIndicator: Equatable, Identifiable {
        let id: String
        let text: String
        let y: CGFloat
        let height: CGFloat
    }

    struct SpineExtent: Equatable {
        let startY: CGFloat
        let solidEndY: CGFloat
        let fadeStartY: CGFloat
        let fadeEndY: CGFloat
    }

    struct EndMarker: Equatable {
        let centerY: CGFloat
        let suggestedDate: Date
        let accessibilityValue: String
    }


    static let minimumBlockGap: CGFloat = 12

    static let routineIconLayoutSize: CGFloat = 72

    static let routineMarkerHeight: CGFloat = max(96, routineIconLayoutSize + 20)

    static let taskMarkerMinHeight: CGFloat = 48

    static let taskMarkerIdealHeight: CGFloat = 56

    static let calendarCardVisualHeight: CGFloat = 68

    static let cardVisualHeight: CGFloat = 84

    static let flockMinHeight: CGFloat = 104

    static let gapPromptHeight: CGFloat = 56

    static let sparseEmptyCardHeight: CGFloat = 96

    static let endMarkerHitArea: CGFloat = 44

    static let endMarkerTopGapAfterFade: CGFloat = 4

    static let spineFadeHeight: CGFloat = 36

    static let spineFadeOffset: CGFloat = 16

    let visibleStart: Date

    let visibleEnd: Date

    let pointsPerMinute: CGFloat

    let minimumItemHeight: CGFloat

    let topInset: CGFloat

    let bottomInset: CGFloat

    let wakeAnchor: PositionedAnchor

    let sleepAnchor: PositionedAnchor

    let items: [PositionedItem]

    let blocks: [PositionedBlock]

    let gaps: [PositionedGap]

    let visualElements: [PositionedVisualTimelineElement]

    let longGapIndicators: [PositionedLongGapIndicator]

    let spineExtent: SpineExtent

    let endMarker: EndMarker

    init(
        projection: TimelineDayProjection,
        pointsPerMinute: CGFloat = 1.2,
        minimumItemHeight: CGFloat = 44,
        topInset: CGFloat = 36,
        bottomInset: CGFloat = 36,
        maxVisualColumns: Int = 3,
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

        let compressedRowStride = minimumItemHeight + 24
        let beforeWakeItems = projection.beforeWakeItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let afterSleepItems = projection.afterSleepItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let beforeBandHeight = CGFloat(beforeWakeItems.count) * compressedRowStride
        let wakeY = topInset + beforeBandHeight + (beforeWakeItems.isEmpty ? 0 : 24)
        let sleepY = wakeY + Self.yPosition(for: end, start: start, pointsPerMinute: pointsPerMinute, calendar: calendar)
        self.wakeAnchor = PositionedAnchor(anchor: projection.wakeAnchor, y: wakeY)
        self.sleepAnchor = PositionedAnchor(anchor: projection.sleepAnchor, y: sleepY)

        let beforeCandidates = beforeWakeItems.enumerated().compactMap { index, item -> Candidate? in
            guard let startDate = item.startDate, let endDate = item.endDate else { return nil }
            let renderedHeight = max(timelineCapsuleHeight(for: item.duration), minimumItemHeight)
            let compressedMinute = CGFloat(index) * 10 - CGFloat(max(beforeWakeItems.count, 1)) * 10
            return Candidate(
                item: item,
                startDate: startDate,
                endDate: endDate,
                startMinute: compressedMinute,
                endMinute: compressedMinute + 1,
                y: topInset + CGFloat(index) * compressedRowStride,
                height: renderedHeight
            )
        }

        let operationalCandidates = projection.timedItems.compactMap { item -> Candidate? in
            guard let interval = projection.layoutInterval(for: item) else { return nil }
            let startDate = interval.start
            let inferredEnd = interval.end
            let clampedEnd = max(inferredEnd, startDate.addingTimeInterval(60))
            let startMinute = Self.minuteOffset(for: startDate, start: start, calendar: calendar)
            let endMinute = max(Self.minuteOffset(for: clampedEnd, start: start, calendar: calendar), startMinute + 1)
            let y = wakeY + (startMinute * pointsPerMinute)
            let renderedHeight = max((endMinute - startMinute) * pointsPerMinute, minimumItemHeight)
            return Candidate(
                item: item,
                startDate: startDate,
                endDate: clampedEnd,
                startMinute: startMinute,
                endMinute: endMinute,
                y: y,
                height: renderedHeight
            )
        }

        let afterCandidates = afterSleepItems.enumerated().compactMap { index, item -> Candidate? in
            guard let startDate = item.startDate, let endDate = item.endDate else { return nil }
            let renderedHeight = max(timelineCapsuleHeight(for: item.duration), minimumItemHeight)
            let compressedMinute = 100_000 + CGFloat(index) * 10
            return Candidate(
                item: item,
                startDate: startDate,
                endDate: endDate,
                startMinute: compressedMinute,
                endMinute: compressedMinute + 1,
                y: sleepY + 24 + CGFloat(index) * compressedRowStride,
                height: renderedHeight
            )
        }

        let candidates = (beforeCandidates + operationalCandidates + afterCandidates)
        .sorted {
            if $0.startMinute == $1.startMinute {
                return $0.endMinute < $1.endMinute
            }
            return $0.startMinute < $1.startMinute
        }

        let positionedItems = Self.positionedItems(from: candidates)
        let positionedBlocks = Self.positionedBlocks(
            from: candidates,
            pointsPerMinute: pointsPerMinute,
            minimumItemHeight: minimumItemHeight,
            maxVisualColumns: maxVisualColumns
        )

        let positionedGaps: [PositionedGap] = projection.actionableGaps.compactMap { gap -> PositionedGap? in
            let startMinute = Self.minuteOffset(for: gap.startDate, start: start, calendar: calendar)
            let endMinute = Self.minuteOffset(for: gap.endDate, start: start, calendar: calendar)
            let gapHeight = max((endMinute - startMinute) * pointsPerMinute, 0)
            guard gapHeight > 0 else { return nil }
            return PositionedGap(
                gap: gap,
                startY: wakeY + (startMinute * pointsPerMinute),
                height: gapHeight
            )
        }

        let visualFlow = Self.positionedVisualElements(
            projection: projection,
            wakeY: wakeY,
            sleepY: sleepY,
            blocks: positionedBlocks,
            gaps: positionedGaps,
            now: projection.currentTime,
            calendar: calendar
        )
        let resolvedSpineExtent = Self.spineExtent(for: visualFlow.elements)
        let resolvedEndMarker = Self.endMarker(
            for: visualFlow.elements,
            projection: projection,
            spineExtent: resolvedSpineExtent,
            calendar: calendar
        )

        self.items = positionedItems
        self.blocks = positionedBlocks
        self.gaps = positionedGaps
        self.visualElements = visualFlow.elements
        self.longGapIndicators = visualFlow.longGapIndicators
        self.spineExtent = resolvedSpineExtent
        self.endMarker = resolvedEndMarker
    }

    static func rawVisualElements(
        projection: TimelineDayProjection,
        wakeY: CGFloat,
        sleepY: CGFloat,
        blocks: [PositionedBlock],
        gaps: [PositionedGap],
        calendar: Calendar
    ) -> [VisualTimelineElement] {
        let wakeElement = VisualTimelineElement.routineMarker(.init(
            anchor: projection.wakeAnchor,
            temporalY: max(wakeY - (routineMarkerHeight / 2), 0),
            height: routineMarkerHeight
        ))
        let sleepElement = VisualTimelineElement.routineMarker(.init(
            anchor: projection.sleepAnchor,
            temporalY: max(sleepY - (routineMarkerHeight / 2), 0),
            height: routineMarkerHeight
        ))

        switch projection.timelineDensityMode {
        case .sparse:
            return [
                wakeElement,
                emptyStateElement(
                    id: "empty:sparse",
                    projection: projection,
                    temporalStart: midpointDate(from: projection.wakeAnchor.time, to: projection.sleepAnchor.time, calendar: calendar)
                ),
                sleepElement
            ]
        case .lightTimeline:
            let blockElements = blocks.map { visualElement(for: $0) }
            let promptStart = lightPromptDate(for: projection, blocks: blocks, calendar: calendar)
            return [wakeElement]
                + blockElements
                + [emptyStateElement(id: "empty:light", projection: projection, temporalStart: promptStart)]
                + [sleepElement]
        case .normal:
            let blockElements = blocks.map { visualElement(for: $0) }
            let gapElements = gaps.compactMap { gap -> VisualTimelineElement? in
                let minutes = minutesBetween(gap.gap.startDate, gap.gap.endDate, calendar: calendar)
                guard minutes < 180 else { return nil }
                let promptY = gap.startY + min(max(10, gap.height * 0.16), max(gap.height - gapPromptHeight, 10))
                return .gapPrompt(.init(
                    gap: gap.gap,
                    temporalY: promptY,
                    height: gapPromptHeight
                ))
            }
            return [wakeElement] + blockElements + gapElements + [sleepElement]
        }
    }

    static func visualElement(for positioned: PositionedBlock) -> VisualTimelineElement {
        switch positioned.block.kind {
        case .conflict:
            return .flock(.init(
                block: positioned.block,
                temporalY: positioned.temporalY,
                height: positioned.height
            ))
        case .single(let item):
            let model = VisualTimelineElement.SingleItemModel(
                item: item,
                temporalY: positioned.temporalY,
                height: positioned.height,
                isEmphasized: item.taskPriority?.isHighPriority == true
            )
            if item.source == .calendarEvent {
                return .meetingCard(model)
            }
            if shouldRenderTaskAsCard(item) {
                return .taskCard(model)
            }
            return .taskMarker(model)
        }
    }

    static func emptyStateElement(
        id: String,
        projection: TimelineDayProjection,
        temporalStart: Date
    ) -> VisualTimelineElement {
        let calendarHidden = projection.calendarPlottingEnabled == false
        let isLightPrompt = id == "empty:light"
        let title: String
        let subtitle: String
        if calendarHidden {
            title = "Calendar is hidden"
            subtitle = "Add tasks here or turn calendar plotting back on."
        } else if isLightPrompt {
            title = "Plenty of open time"
            subtitle = "Add a task or let \(AssistantIdentityText.currentSnapshot().displayName) help shape the rest of the day."
        } else {
            title = "No meetings today"
            subtitle = "Add a task or let \(AssistantIdentityText.currentSnapshot().displayName) help you shape the day."
        }
        return .emptyState(.init(
            id: id,
            title: title,
            subtitle: subtitle,
            primaryTitle: "Add task",
            secondaryTitle: calendarHidden ? "Show calendar" : "Plan with \(AssistantIdentityText.currentSnapshot().displayName)",
            showsCalendarAction: calendarHidden,
            suggestedDate: projection.wakeAnchor.time.addingTimeInterval(60 * 60),
            temporalStart: temporalStart,
            temporalY: 0,
            height: sparseEmptyCardHeight
        ))
    }
}
