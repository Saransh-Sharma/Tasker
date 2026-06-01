//
//  TimelineTimeBlock.swift
//  LifeBoard
//
//  Move-only timeline decomposition.
//

import SwiftUI

struct TimelineTimeBlock: Equatable, Identifiable {
    static let defaultClusterPointsPerMinute: CGFloat = 1.35
    static let maxClusterPointsPerMinute: CGFloat = 3
    static let laneGap: CGFloat = 6
    static let packedRowGap: CGFloat = 8
    static let clusterHeaderHeight: CGFloat = 38
    static let clusterVerticalPadding: CGFloat = 18

    struct Input: Equatable {
        let item: TimelinePlanItem
        let startDate: Date
        let endDate: Date
        let startMinute: CGFloat
        let endMinute: CGFloat
        let y: CGFloat
        let height: CGFloat
    }

    enum Kind: Equatable {
        case single(TimelinePlanItem)
        case conflict([TimelinePlanItem])
    }

    enum DensityMode: Equatable {
        case normal
        case dualLane
        case compactLane
        case microLane
        case densePacked

        var minimumCardHeight: CGFloat {
            switch self {
            case .normal:
                return 72
            case .dualLane:
                return 52
            case .compactLane:
                return 48
            case .microLane, .densePacked:
                return 44
            }
        }

        var itemSpacing: CGFloat {
            switch self {
            case .normal:
                return 8
            case .dualLane:
                return 7
            case .compactLane:
                return 6
            case .microLane, .densePacked:
                return 6
            }
        }
    }

    struct LanePlacement: Equatable, Identifiable {
        let item: TimelinePlanItem
        let laneIndex: Int
        let laneCount: Int
        let rowIndex: Int
        let relativeY: CGFloat
        let height: CGFloat
        let startMinute: CGFloat
        let endMinute: CGFloat

        var id: String { item.id }
    }

    let id: String
    let kind: Kind
    let startDate: Date
    let endDate: Date
    let startMinute: CGFloat
    let endMinute: CGFloat
    let y: CGFloat
    let height: CGFloat
    let items: [TimelinePlanItem]
    let overlapDepth: Int
    let visualLaneCount: Int
    let densityMode: DensityMode
    let isDensePacked: Bool
    let compressed: Bool
    let lanePlacements: [LanePlacement]

    var isConflict: Bool {
        guard case .conflict = kind else { return false }
        return true
    }

    var containsTask: Bool {
        items.contains { $0.source == .task }
    }

    var containsCalendarEvent: Bool {
        items.contains { $0.source == .calendarEvent }
    }

    var countLabel: String {
        let noun = items.allSatisfy { $0.source == .calendarEvent } ? "Events" : "Items"
        return "\(items.count) \(noun)"
    }

    static func make(
        from inputs: [Input],
        maxVisualColumns: Int = 3,
        defaultClusterPointsPerMinute: CGFloat = TimelineTimeBlock.defaultClusterPointsPerMinute,
        maxClusterPointsPerMinute: CGFloat = TimelineTimeBlock.maxClusterPointsPerMinute
    ) -> [TimelineTimeBlock] {
        let sortedInputs = inputs.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute { return lhs.startMinute < rhs.startMinute }
            if lhs.endMinute != rhs.endMinute { return lhs.endMinute < rhs.endMinute }
            return itemSort(lhs.item, rhs.item)
        }
        guard sortedInputs.isEmpty == false else { return [] }

        var groups: [[Input]] = []
        var currentGroup: [Input] = []
        var currentGroupEnd: CGFloat = 0

        for input in sortedInputs {
            if currentGroup.isEmpty {
                currentGroup = [input]
                currentGroupEnd = input.endMinute
                continue
            }

            if input.startMinute < currentGroupEnd {
                currentGroup.append(input)
                currentGroupEnd = max(currentGroupEnd, input.endMinute)
            } else {
                groups.append(currentGroup)
                currentGroup = [input]
                currentGroupEnd = input.endMinute
            }
        }

        if currentGroup.isEmpty == false {
            groups.append(currentGroup)
        }

        return groups.map {
            block(
                from: $0,
                maxVisualColumns: maxVisualColumns,
                defaultClusterPointsPerMinute: defaultClusterPointsPerMinute,
                maxClusterPointsPerMinute: maxClusterPointsPerMinute
            )
        }
    }

    private static func block(
        from inputs: [Input],
        maxVisualColumns: Int,
        defaultClusterPointsPerMinute: CGFloat,
        maxClusterPointsPerMinute: CGFloat
    ) -> TimelineTimeBlock {
        let sortedInputs = inputs.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute { return lhs.startMinute < rhs.startMinute }
            if lhs.endMinute != rhs.endMinute { return lhs.endMinute < rhs.endMinute }
            return itemSort(lhs.item, rhs.item)
        }
        let sortedItems = sortedInputs.map(\.item)
        let idSuffix = sortedItems.map(\.id).joined(separator: "|")
        let startDate = inputs.map(\.startDate).min() ?? .distantPast
        let endDate = inputs.map(\.endDate).max() ?? startDate
        let startMinute = inputs.map(\.startMinute).min() ?? 0
        let endMinute = inputs.map(\.endMinute).max() ?? startMinute
        let y = inputs.map(\.y).min() ?? 0
        let kind: Kind = sortedItems.count > 1 ? .conflict(sortedItems) : .single(sortedItems[0])
        let prefix = sortedItems.count > 1 ? "conflict" : "single"
        let overlapDepth = max(Self.overlapDepth(for: sortedInputs), 1)
        let visualLaneCount = max(1, min(overlapDepth, max(maxVisualColumns, 1)))
        let initialDensityMode = Self.densityMode(for: overlapDepth)
        let laneAssignments = Self.logicalLaneAssignments(for: sortedInputs)
        let requiredScale = Self.requiredScale(
            for: laneAssignments,
            minimumCardHeight: initialDensityMode.minimumCardHeight,
            itemSpacing: initialDensityMode.itemSpacing,
            fallbackScale: defaultClusterPointsPerMinute
        )
        let mustPackForColumnCap = overlapDepth > visualLaneCount
        let mustPackForHeightCap = requiredScale > maxClusterPointsPerMinute
        let isDensePacked = mustPackForHeightCap
        let densityMode: DensityMode = isDensePacked ? .densePacked : initialDensityMode
        let lanePlacements: [LanePlacement]

        if mustPackForColumnCap || mustPackForHeightCap {
            lanePlacements = Self.packedPlacements(
                for: sortedInputs,
                visualLaneCount: visualLaneCount,
                densityMode: densityMode
            )
        } else {
            lanePlacements = Self.scaledPlacements(
                for: laneAssignments,
                blockStartMinute: startMinute,
                visualLaneCount: visualLaneCount,
                densityMode: densityMode,
                scale: min(max(requiredScale, defaultClusterPointsPerMinute), maxClusterPointsPerMinute)
            )
        }

        let layoutHeight = lanePlacements.map { $0.relativeY + $0.height }.max() ?? 0
        let inputHeight = max((inputs.map { $0.y + $0.height }.max() ?? y) - y, 0)
        let renderedHeight = sortedItems.count > 1
            ? max(Self.clusterHeaderHeight + layoutHeight + Self.clusterVerticalPadding, inputHeight)
            : inputHeight
        return TimelineTimeBlock(
            id: "\(prefix):\(idSuffix)",
            kind: kind,
            startDate: startDate,
            endDate: endDate,
            startMinute: startMinute,
            endMinute: endMinute,
            y: y,
            height: renderedHeight,
            items: sortedItems,
            overlapDepth: overlapDepth,
            visualLaneCount: visualLaneCount,
            densityMode: densityMode,
            isDensePacked: isDensePacked,
            compressed: mustPackForColumnCap || mustPackForHeightCap,
            lanePlacements: lanePlacements
        )
    }

    private static func densityMode(for overlapDepth: Int) -> DensityMode {
        switch overlapDepth {
        case ..<2:
            return .normal
        case 2:
            return .dualLane
        case 3:
            return .compactLane
        default:
            return .microLane
        }
    }

    private static func overlapDepth(for inputs: [Input]) -> Int {
        let events = inputs.flatMap { input in
            [
                (minute: input.startMinute, delta: 1),
                (minute: input.endMinute, delta: -1)
            ]
        }
        .sorted { lhs, rhs in
            if lhs.minute != rhs.minute { return lhs.minute < rhs.minute }
            return lhs.delta < rhs.delta
        }

        var active = 0
        var maxActive = 0
        for event in events {
            active += event.delta
            maxActive = max(maxActive, active)
        }
        return maxActive
    }

    private static func logicalLaneAssignments(for inputs: [Input]) -> [(input: Input, laneIndex: Int)] {
        var laneEndMinutes: [CGFloat] = []
        var assignments: [(input: Input, laneIndex: Int)] = []

        for input in inputs {
            if let availableLane = laneEndMinutes.firstIndex(where: { $0 <= input.startMinute }) {
                laneEndMinutes[availableLane] = input.endMinute
                assignments.append((input, availableLane))
            } else {
                let laneIndex = laneEndMinutes.count
                laneEndMinutes.append(input.endMinute)
                assignments.append((input, laneIndex))
            }
        }

        return assignments
    }

    private static func requiredScale(
        for assignments: [(input: Input, laneIndex: Int)],
        minimumCardHeight: CGFloat,
        itemSpacing: CGFloat,
        fallbackScale: CGFloat
    ) -> CGFloat {
        var required = fallbackScale
        let grouped = Dictionary(grouping: assignments) { $0.laneIndex }
        for laneAssignments in grouped.values {
            let sorted = laneAssignments.sorted { lhs, rhs in
                if lhs.input.startMinute != rhs.input.startMinute { return lhs.input.startMinute < rhs.input.startMinute }
                return lhs.input.endMinute < rhs.input.endMinute
            }
            guard sorted.count > 1 else { continue }

            for index in 0..<(sorted.count - 1) {
                let current = sorted[index].input
                let next = sorted[index + 1].input
                let startGap = max(next.startMinute - current.startMinute, 1)
                if current.endMinute <= next.startMinute {
                    required = max(required, (minimumCardHeight + itemSpacing) / startGap)
                }
            }
        }
        return required
    }

    private static func scaledPlacements(
        for assignments: [(input: Input, laneIndex: Int)],
        blockStartMinute: CGFloat,
        visualLaneCount: Int,
        densityMode: DensityMode,
        scale: CGFloat
    ) -> [LanePlacement] {
        assignments.map { assignment in
            let input = assignment.input
            let duration = max(input.endMinute - input.startMinute, 1)
            return LanePlacement(
                item: input.item,
                laneIndex: min(assignment.laneIndex, visualLaneCount - 1),
                laneCount: visualLaneCount,
                rowIndex: 0,
                relativeY: max(0, (input.startMinute - blockStartMinute) * scale),
                height: max(duration * scale, densityMode.minimumCardHeight),
                startMinute: input.startMinute,
                endMinute: input.endMinute
            )
        }
    }

    private static func packedPlacements(
        for inputs: [Input],
        visualLaneCount: Int,
        densityMode: DensityMode
    ) -> [LanePlacement] {
        let rowStride = densityMode.minimumCardHeight + Self.packedRowGap
        return inputs.enumerated().map { index, input in
            LanePlacement(
                item: input.item,
                laneIndex: index % visualLaneCount,
                laneCount: visualLaneCount,
                rowIndex: index / visualLaneCount,
                relativeY: CGFloat(index / visualLaneCount) * rowStride,
                height: densityMode.minimumCardHeight,
                startMinute: input.startMinute,
                endMinute: input.endMinute
            )
        }
    }

    static func itemSort(_ lhs: TimelinePlanItem, _ rhs: TimelinePlanItem) -> Bool {
        let lhsStart = lhs.startDate ?? .distantPast
        let rhsStart = rhs.startDate ?? .distantPast
        if lhsStart != rhsStart { return lhsStart < rhsStart }

        let lhsEnd = lhs.endDate ?? lhsStart
        let rhsEnd = rhs.endDate ?? rhsStart
        if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }

        if lhs.source != rhs.source {
            return lhs.source == .calendarEvent
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}
