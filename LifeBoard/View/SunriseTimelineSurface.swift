 import SwiftUI

struct TimelineHeaderHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineCalendarCardHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineBackdropWeekHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

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

enum TimelinePhoneRenderModel: Equatable, Identifiable {
    case normal(TimelinePlanItem)
    case flock(TimelineFlockModel)

    var id: String {
        switch self {
        case .normal(let item):
            return "normal:\(item.id)"
        case .flock(let model):
            return model.id
        }
    }

    static func make(from block: TimelineTimeBlock, now: Date) -> TimelinePhoneRenderModel {
        switch block.kind {
        case .single(let item):
            return .normal(item)
        case .conflict:
            return .flock(TimelineFlockModel(block: block, now: now))
        }
    }
}

struct TimelineFlockModel: Equatable, Identifiable {
    enum DensityMode: Equatable {
        case smallFlock
        case mediumFlock
        case denseFlock
        case extremeFlock
    }

    struct Row: Equatable, Identifiable {
        let id: String
        let item: TimelinePlanItem?
        let title: String
        let timeText: String
        let isActiveNow: Bool
        let isCompleted: Bool
        let isSummary: Bool
    }

    static let headerHeight: CGFloat = 36
    static let verticalPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 4
    static let effectiveTapTargetHeight: CGFloat = 44
    static let maximumDisplayHeight: CGFloat = 280

    let id: String
    let startDate: Date
    let endDate: Date
    let countLabel: String
    let densityMode: DensityMode
    let rows: [Row]
    let visibleItemIDs: [String]
    let isCollapsedExtreme: Bool
    let activeItemID: String?

    init(block: TimelineTimeBlock, now: Date) {
        let sortedItems = Self.sortedItems(block.items)
        let visibleItems = Self.visibleItems(from: sortedItems, now: now)
        let titles = TimelineDenseTitleFormatter.displayTitles(for: visibleItems)
        let rowItems = visibleItems.map { item in
            Row(
                id: item.id,
                item: item,
                title: titles[item.id] ?? item.title,
                timeText: Self.compactTimeText(for: item),
                isActiveNow: Self.item(item, contains: now),
                isCompleted: item.isComplete,
                isSummary: false
            )
        }
        let collapsed = sortedItems.count > visibleItems.count
        let summaryRows = collapsed
            ? [
                Row(
                    id: "\(block.id):summary",
                    item: nil,
                    title: "View all \(sortedItems.count) items",
                    timeText: "",
                    isActiveNow: false,
                    isCompleted: false,
                    isSummary: true
                )
            ]
            : []

        self.id = "flock:\(block.id)"
        self.startDate = block.startDate
        self.endDate = block.endDate
        self.countLabel = block.countLabel.lowercased()
        self.densityMode = Self.densityMode(for: sortedItems.count)
        self.rows = rowItems + summaryRows
        self.visibleItemIDs = visibleItems.map(\.id)
        self.isCollapsedExtreme = collapsed
        self.activeItemID = visibleItems.first { Self.item($0, contains: now) }?.id
    }

    var rowVisualHeight: CGFloat {
        Self.rowVisualHeight(for: densityMode)
    }

    var displayHeight: CGFloat {
        Self.displayHeight(itemCount: rows.count, densityMode: densityMode)
    }

    static func densityMode(for itemCount: Int) -> DensityMode {
        switch itemCount {
        case ..<3:
            return .smallFlock
        case 3...4:
            return .mediumFlock
        case 5...7:
            return .denseFlock
        default:
            return .extremeFlock
        }
    }

    static func rowVisualHeight(for densityMode: DensityMode) -> CGFloat {
        switch densityMode {
        case .smallFlock:
            return 40
        case .mediumFlock:
            return 34
        case .denseFlock:
            return 28
        case .extremeFlock:
            return 26
        }
    }

    static func displayHeight(itemCount: Int, densityMode: DensityMode? = nil) -> CGFloat {
        switch itemCount {
        case ..<3:
            return 104
        case 3:
            return 132
        case 4:
            return 156
        default:
            break
        }

        let mode = densityMode ?? Self.densityMode(for: itemCount)
        let rowHeight = Self.rowVisualHeight(for: mode)
        let rawHeight = Self.headerHeight
            + Self.verticalPadding
            + (CGFloat(itemCount) * rowHeight)
            + (CGFloat(max(itemCount - 1, 0)) * Self.rowSpacing)
        return min(max(rawHeight, 156), Self.maximumDisplayHeight)
    }

    private static func visibleItems(from sortedItems: [TimelinePlanItem], now: Date) -> [TimelinePlanItem] {
        guard sortedItems.count >= 8 else { return sortedItems }

        var selected: [TimelinePlanItem] = []
        func appendUnique(_ item: TimelinePlanItem?) {
            guard let item, selected.contains(where: { $0.id == item.id }) == false else { return }
            selected.append(item)
        }

        appendUnique(sortedItems.first { item($0, contains: now) })
        appendUnique(sortedItems.first { ($0.startDate ?? .distantFuture) >= now })
        appendUnique(sortedItems.first { $0.source == .task && $0.isComplete == false })

        for item in sortedItems where selected.count < 6 {
            appendUnique(item)
        }

        return Array(selected.prefix(6))
    }

    private static func sortedItems(_ items: [TimelinePlanItem]) -> [TimelinePlanItem] {
        items.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
            }
            if lhs.endDate != rhs.endDate {
                return (lhs.endDate ?? .distantPast) < (rhs.endDate ?? .distantPast)
            }
            return TimelineTimeBlock.itemSort(lhs, rhs)
        }
    }

    private static func item(_ item: TimelinePlanItem, contains date: Date) -> Bool {
        guard let start = item.startDate, let end = item.endDate else { return false }
        return start <= date && date < end
    }

    private static func compactTimeText(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}

enum SunriseTimelineRendererMode: Equatable {
    case compact
    case expanded
    case agenda
}

enum SunriseTimelineRendererPolicy {
    static func mode(
        layoutClass: LifeBoardLayoutClass,
        dayLayoutMode _: TimelineDayLayoutMode,
        isAccessibilitySize: Bool
    ) -> SunriseTimelineRendererMode {
        if isAccessibilitySize {
            return .agenda
        }

        switch layoutClass {
        case .phone:
            return .expanded
        case .padCompact:
            return .compact
        case .padRegular, .padExpanded:
            return .expanded
        }
    }
}

enum VisualTimelineElement: Equatable, Identifiable {
    struct RoutineMarkerModel: Equatable, Identifiable {
        let anchor: TimelineAnchorItem
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { "routine:\(anchor.id)" }
    }

    struct SingleItemModel: Equatable, Identifiable {
        let item: TimelinePlanItem
        let temporalY: CGFloat
        let height: CGFloat
        let isEmphasized: Bool

        var id: String { item.id }
    }

    struct FlockBlockModel: Equatable, Identifiable {
        let block: TimelineTimeBlock
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { block.id }
    }

    struct GapPromptModel: Equatable, Identifiable {
        let gap: TimelineGap
        let temporalY: CGFloat
        let height: CGFloat

        var id: String { "gap:\(gap.id)" }
    }

    struct EmptyStateModel: Equatable, Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let primaryTitle: String
        let secondaryTitle: String
        let showsCalendarAction: Bool
        let suggestedDate: Date
        let temporalStart: Date
        let temporalY: CGFloat
        let height: CGFloat
    }

    case routineMarker(RoutineMarkerModel)
    case meetingCard(SingleItemModel)
    case taskMarker(SingleItemModel)
    case taskCard(SingleItemModel)
    case flock(FlockBlockModel)
    case gapPrompt(GapPromptModel)
    case emptyState(EmptyStateModel)

    var id: String {
        switch self {
        case .routineMarker(let model):
            return model.id
        case .meetingCard(let model):
            return "meeting:\(model.id)"
        case .taskMarker(let model):
            return "task-marker:\(model.id)"
        case .taskCard(let model):
            return "task-card:\(model.id)"
        case .flock(let model):
            return "flock:\(model.id)"
        case .gapPrompt(let model):
            return model.id
        case .emptyState(let model):
            return model.id
        }
    }

    var temporalStart: Date {
        switch self {
        case .routineMarker(let model):
            return model.anchor.time
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.startDate ?? .distantPast
        case .flock(let model):
            return model.block.startDate
        case .gapPrompt(let model):
            return model.gap.startDate
        case .emptyState(let model):
            return model.temporalStart
        }
    }

    var temporalEnd: Date {
        switch self {
        case .routineMarker(let model):
            return model.anchor.time
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.endDate ?? model.item.startDate ?? .distantPast
        case .flock(let model):
            return model.block.endDate
        case .gapPrompt(let model):
            return model.gap.endDate
        case .emptyState(let model):
            return model.temporalStart
        }
    }

    var temporalY: CGFloat {
        switch self {
        case .routineMarker(let model):
            return model.temporalY
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.temporalY
        case .flock(let model):
            return model.temporalY
        case .gapPrompt(let model):
            return model.temporalY
        case .emptyState(let model):
            return model.temporalY
        }
    }

    var measuredHeight: CGFloat {
        switch self {
        case .routineMarker(let model):
            return model.height
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.height
        case .flock(let model):
            return model.height
        case .gapPrompt(let model):
            return model.height
        case .emptyState(let model):
            return model.height
        }
    }

    var displayPriority: Int {
        switch self {
        case .flock:
            return 0
        case .meetingCard:
            return 1
        case .taskCard:
            return 2
        case .taskMarker:
            return 3
        case .routineMarker:
            return 4
        case .gapPrompt:
            return 5
        case .emptyState:
            return 6
        }
    }

    var isPlottedContent: Bool {
        switch self {
        case .meetingCard, .taskMarker, .taskCard, .flock:
            return true
        case .routineMarker, .gapPrompt, .emptyState:
            return false
        }
    }

    func isActive(at date: Date) -> Bool {
        switch self {
        case .routineMarker:
            return false
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            return model.item.isActive(at: date)
        case .flock(let model):
            return model.block.items.contains { $0.isActive(at: date) }
        case .gapPrompt(let model):
            return model.gap.startDate <= date && date < model.gap.endDate
        case .emptyState:
            return false
        }
    }

    static func elementSort(_ lhs: VisualTimelineElement, _ rhs: VisualTimelineElement, now: Date) -> Bool {
        if lhs.temporalStart != rhs.temporalStart {
            return lhs.temporalStart < rhs.temporalStart
        }
        if lhs.temporalY != rhs.temporalY {
            return lhs.temporalY < rhs.temporalY
        }
        let lhsActive = lhs.isActive(at: now)
        let rhsActive = rhs.isActive(at: now)
        if lhsActive != rhsActive {
            return lhsActive
        }
        if lhs.displayPriority != rhs.displayPriority {
            return lhs.displayPriority < rhs.displayPriority
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}

enum TimelineStreamInfluenceKind: Equatable {
    case range
    case sweep
    case routine
    case meeting
    case task
    case gap
    case flock

    var priority: Int {
        switch self {
        case .flock:
            return 6
        case .meeting:
            return 5
        case .task:
            return 4
        case .routine:
            return 3
        case .gap:
            return 2
        case .range:
            return 0
        case .sweep:
            return 1
        }
    }

    var baseStrength: CGFloat {
        switch self {
        case .range:
            return 0
        case .sweep:
            return 0
        case .routine:
            return 8
        case .task:
            return 5
        case .gap:
            return 0
        case .meeting:
            return 9
        case .flock:
            return 18
        }
    }

    var baseMass: CGFloat {
        switch self {
        case .routine:
            return 0.65
        case .meeting:
            return 0.75
        case .task:
            return 0.45
        case .flock:
            return 1.40
        case .range, .sweep, .gap:
            return 0
        }
    }

    var contributesCurvatureMass: Bool {
        switch self {
        case .routine, .meeting, .task, .flock:
            return true
        case .range, .sweep, .gap:
            return false
        }
    }

    var thicknessBonus: CGFloat {
        switch self {
        case .flock:
            return 1
        case .meeting:
            return 0.5
        case .gap:
            return 0.35
        case .task:
            return 0.25
        case .range, .sweep, .routine:
            return 0
        }
    }

    var overshoot: CGFloat {
        switch self {
        case .flock:
            return 0
        case .meeting:
            return 0
        case .sweep:
            return 0
        case .task:
            return 0
        case .range, .routine, .gap:
            return 0
        }
    }
}

struct TimelineStreamInfluence: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let centerY: CGFloat
    let height: CGFloat
    let tintHex: String?
    let stackCount: Int

    init(
        id: String,
        kind: TimelineStreamInfluenceKind,
        centerY: CGFloat,
        height: CGFloat,
        tintHex: String? = nil,
        stackCount: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.centerY = centerY
        self.height = height
        self.tintHex = tintHex
        self.stackCount = stackCount
    }
}

private extension TimelineStreamInfluence {
    var startY: CGFloat { centerY - (max(height, 40) / 2) }
    var endY: CGFloat { centerY + (max(height, 40) / 2) }
}

enum TimelineStreamDirection: CGFloat, Equatable {
    case leading = -1
    case center = 0
    case trailing = 1

    var inverted: TimelineStreamDirection {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        case .center:
            return .trailing
        }
    }
}

struct TimelineStreamAnchor: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let y: CGFloat
    let strength: CGFloat
    let thickness: CGFloat
    let tintHex: String?
    let direction: TimelineStreamDirection

    var xDirection: CGFloat { direction.rawValue }
}

struct TimelineStreamSegment: Equatable, Identifiable {
    let index: Int
    let start: TimelineStreamAnchor
    let end: TimelineStreamAnchor
    let control1: CGPoint
    let control2: CGPoint

    var id: Int { index }
}

struct TimelineStreamSample: Equatable, Identifiable {
    let index: Int
    let y: CGFloat
    let x: CGFloat
    let lineWidth: CGFloat
    let tintHex: String?
    let progress: CGFloat

    var id: Int { index }
}

struct TimelineStreamGeometry: Equatable {
    struct LaneMetrics: Equatable {
        let width: CGFloat
        let leadingX: CGFloat
        let centerX: CGFloat
        let contentX: CGFloat

        var halfWidth: CGFloat { width / 2 }
    }

    private struct DensityPreset: Equatable {
        let multiplier: CGFloat
        let maxOffset: CGFloat
    }

    private struct CurvatureBody: Equatable {
        let id: String
        let kind: TimelineStreamInfluenceKind
        let centerY: CGFloat
        let height: CGFloat
        let tintHex: String?
        let stackCount: Int
        let isOverlapping: Bool

        var startY: CGFloat { centerY - (height / 2) }
        var endY: CGFloat { centerY + (height / 2) }
    }

    static let baseLineWidth: CGFloat = 4
    static let coreLineWidth: CGFloat = 1.5
    static let glowLineWidth: CGFloat = 8
    static let sampleStride: CGFloat = 14
    static let minimumClusterDistance: CGFloat = 120
    static let clusterGapThreshold: CGFloat = 44
    static let densityWindow: CGFloat = 160
    static let maxSlopeDelta: CGFloat = 3.5
    static let contentGapAfterLane: CGFloat = 10
    static let minimumPhoneContentWidth: CGFloat = 230

    let baseX: CGFloat
    let laneHalfWidth: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let influences: [TimelineStreamInfluence]
    private let curvatureBodies: [CurvatureBody]
    private let samplePoints: [TimelineStreamSample]
    let anchors: [TimelineStreamAnchor]
    let segments: [TimelineStreamSegment]

    init(
        baseX: CGFloat,
        laneHalfWidth: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        influences: [TimelineStreamInfluence]
    ) {
        self.baseX = baseX
        self.laneHalfWidth = max(laneHalfWidth, 1)
        self.startY = min(startY, endY)
        self.endY = max(startY, endY)
        self.influences = influences
        let bodies = Self.curvatureBodies(from: influences)
        self.curvatureBodies = bodies
        self.samplePoints = Self.buildSamples(
            bodies: bodies,
            baseX: baseX,
            laneHalfWidth: self.laneHalfWidth,
            startY: self.startY,
            endY: self.endY,
            stride: Self.sampleStride
        )
        self.anchors = Self.directedAnchors(
            from: Self.rawAnchors(
                influences: influences,
                startY: self.startY,
                endY: self.endY,
                laneHalfWidth: self.laneHalfWidth
            ),
            laneHalfWidth: self.laneHalfWidth
        )
        self.segments = Self.segments(from: self.anchors, baseX: baseX, laneHalfWidth: self.laneHalfWidth)
    }

    static func make(
        plan: TimelineCanvasLayoutPlan,
        baseX: CGFloat,
        laneHalfWidth: CGFloat
    ) -> TimelineStreamGeometry {
        TimelineStreamGeometry(
            baseX: baseX,
            laneHalfWidth: laneHalfWidth,
            startY: plan.spineExtent.startY,
            endY: plan.spineExtent.fadeEndY,
            influences: plan.visualElements.compactMap(Self.influence)
        )
    }

    static func laneMetrics(
        totalWidth: CGFloat,
        labelRightX: CGFloat,
        trailingReservedWidth: CGFloat,
        layoutClass: LifeBoardLayoutClass
    ) -> LaneMetrics {
        let preferred: CGFloat
        let minimum: CGFloat
        let contentGap: CGFloat
        switch layoutClass {
        case .phone:
            if totalWidth <= 390 {
                minimum = 34
                preferred = 36
                contentGap = 8
            } else if totalWidth <= 430 {
                minimum = 36
                preferred = 38
                contentGap = 8
            } else {
                minimum = 40
                preferred = 42
                contentGap = 8
            }
        case .padCompact:
            minimum = 72
            preferred = 78
            contentGap = contentGapAfterLane
        case .padRegular, .padExpanded:
            minimum = 76
            preferred = 84
            contentGap = contentGapAfterLane
        }

        let available = totalWidth
            - labelRightX
            - trailingReservedWidth
            - contentGap
            - minimumPhoneContentWidth
        let laneWidth = min(preferred, max(minimum, available))
        let leadingX = labelRightX
        let centerX = leadingX + (laneWidth / 2)
        let contentX = leadingX + laneWidth + contentGap
        return LaneMetrics(width: laneWidth, leadingX: leadingX, centerX: centerX, contentX: contentX)
    }

    static func influence(
        for positioned: TimelineCanvasLayoutPlan.PositionedVisualTimelineElement
    ) -> TimelineStreamInfluence? {
        switch positioned.element {
        case .routineMarker:
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .routine,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: nil
            )
        case .meetingCard(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .meeting,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.item.tintHex
            )
        case .taskMarker(let model), .taskCard(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .task,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.item.tintHex
            )
        case .flock(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .flock,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.block.items.first(where: { $0.source == .task })?.tintHex
                    ?? model.block.items.first?.tintHex,
                stackCount: max(model.block.items.count, 2)
            )
        case .gapPrompt(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .gap,
                centerY: positioned.centerY,
                height: max(positioned.height, CGFloat(model.gap.duration / 60) * 0.35),
                tintHex: nil
            )
        case .emptyState:
            return nil
        }
    }

    func clampedY(_ y: CGFloat) -> CGFloat {
        min(max(y, startY), endY)
    }

    func x(atY y: CGFloat) -> CGFloat {
        xOffset(atY: y) + baseX
    }

    func xOffset(atY y: CGFloat) -> CGFloat {
        guard let sample = interpolatedSample(atY: y) else { return 0 }
        return sample.x - baseX
    }

    func effectiveLaneHalfWidth(atY y: CGFloat) -> CGFloat {
        let clusterBreath = min(nearestAnchorWeight(atY: y, kind: .flock) * 3, 3)
        return min(laneHalfWidth + clusterBreath, laneHalfWidth + 3)
    }

    func lineWidth(atY y: CGFloat) -> CGFloat {
        interpolatedSample(atY: y)?.lineWidth ?? Self.baseLineWidth
    }

    func tintHex(atY y: CGFloat) -> String? {
        interpolatedSample(atY: y)?.tintHex
    }

    func path() -> Path {
        var path = Path()
        let points = samplePoints
        guard points.count > 1, let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x, y: first.y))

        for (previous, current) in zip(points, points.dropFirst()) {
            let midY = (previous.y + current.y) / 2
            path.addCurve(
                to: CGPoint(x: current.x, y: current.y),
                control1: CGPoint(x: previous.x, y: midY),
                control2: CGPoint(x: current.x, y: midY)
            )
        }
        return path
    }

    func samples(stride: CGFloat = Self.sampleStride) -> [TimelineStreamSample] {
        guard abs(stride - Self.sampleStride) > 0.001 else { return samplePoints }
        return Self.buildSamples(
            bodies: curvatureBodies,
            baseX: baseX,
            laneHalfWidth: laneHalfWidth,
            startY: startY,
            endY: endY,
            stride: stride
        )
    }

    static func rawAnchors(
        influences: [TimelineStreamInfluence],
        startY: CGFloat,
        endY: CGFloat,
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamAnchor] {
        let maximumStrength = max(laneHalfWidth, 0)
        let startAnchor = TimelineStreamAnchor(
            id: "range:start",
            kind: .range,
            y: startY,
            strength: 0,
            thickness: baseLineWidth,
            tintHex: nil,
            direction: .center
        )
        let endAnchor = TimelineStreamAnchor(
            id: "range:end",
            kind: .range,
            y: endY,
            strength: 0,
            thickness: baseLineWidth,
            tintHex: nil,
            direction: .center
        )

        let densityPreset = densityPreset(itemCount: influences.filter(\.kind.contributesCurvatureMass).count, clusterCount: influences.filter { $0.kind == .flock }.count)
        let semanticAnchors = curvatureBodies(from: influences).map { body in
            return TimelineStreamAnchor(
                id: body.id,
                kind: body.kind,
                y: body.centerY,
                strength: min(curvatureAmplitude(for: body) * densityPreset.multiplier, maximumStrength),
                thickness: baseLineWidth + body.kind.thicknessBonus,
                tintHex: body.tintHex,
                direction: .center
            )
        }
        return ([startAnchor] + semanticAnchors + [endAnchor]).sorted { $0.y < $1.y }
    }

    static func compositeAnchors(
        from anchors: [TimelineStreamAnchor],
        minimumDistance: CGFloat
    ) -> [TimelineStreamAnchor] {
        var composites: [TimelineStreamAnchor] = []
        var currentGroup: [TimelineStreamAnchor] = []

        func flushGroup() {
            guard currentGroup.isEmpty == false else { return }
            if currentGroup.count == 1, let only = currentGroup.first {
                composites.append(only)
            } else {
                composites.append(compositeAnchor(from: currentGroup))
            }
            currentGroup.removeAll()
        }

        for anchor in anchors.sorted(by: { $0.y < $1.y }) {
            guard anchor.kind != .range else {
                flushGroup()
                composites.append(anchor)
                continue
            }

            if let last = currentGroup.last, anchor.y - last.y < minimumDistance {
                currentGroup.append(anchor)
            } else {
                flushGroup()
                currentGroup = [anchor]
            }
        }
        flushGroup()

        return composites.sorted { lhs, rhs in
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.kind.priority < rhs.kind.priority
        }
    }

    static func directedAnchors(
        from anchors: [TimelineStreamAnchor],
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamAnchor] {
        let sorted = anchors.sorted { $0.y < $1.y }

        return sorted.map { anchor in
            let direction: TimelineStreamDirection
            switch anchor.kind {
            case .task, .meeting, .flock, .routine:
                direction = .trailing
            case .range, .sweep, .gap:
                direction = .center
            }

            let clampedStrength = min(anchor.strength, max(laneHalfWidth, 0))
            return TimelineStreamAnchor(
                id: anchor.id,
                kind: anchor.kind,
                y: anchor.y,
                strength: clampedStrength,
                thickness: anchor.thickness,
                tintHex: anchor.tintHex,
                direction: direction
            )
        }
    }

    static func segments(
        from anchors: [TimelineStreamAnchor],
        baseX: CGFloat,
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamSegment] {
        guard anchors.count > 1 else { return [] }
        return zip(anchors, anchors.dropFirst()).enumerated().map { index, pair in
            let start = pair.0
            let end = pair.1
            let startPoint = point(for: start, baseX: baseX)
            let endPoint = point(for: end, baseX: baseX)
            let height = max(end.y - start.y, 1)
            let control1 = CGPoint(
                x: startPoint.x,
                y: start.y + (height * 0.5)
            )
            let control2 = CGPoint(
                x: endPoint.x,
                y: end.y - (height * 0.5)
            )
            return TimelineStreamSegment(
                index: index,
                start: start,
                end: end,
                control1: control1,
                control2: control2
            )
        }
    }

    static func point(for anchor: TimelineStreamAnchor, baseX: CGFloat) -> CGPoint {
        CGPoint(x: baseX + (anchor.xDirection * anchor.strength), y: anchor.y)
    }

    func point(for anchor: TimelineStreamAnchor) -> CGPoint {
        Self.point(for: anchor, baseX: baseX)
    }

    private static func buildSamples(
        bodies: [CurvatureBody],
        baseX: CGFloat,
        laneHalfWidth: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        stride: CGFloat
    ) -> [TimelineStreamSample] {
        let clampedStartY = min(startY, endY)
        let clampedEndY = max(startY, endY)
        let span = max(clampedEndY - clampedStartY, 1)
        let step = max(stride, 4)
        let preset = densityPreset(
            itemCount: bodies.reduce(0) { $0 + max($1.stackCount, 1) },
            clusterCount: bodies.filter { $0.kind == .flock }.count
        )
        let maxOffset = min(preset.maxOffset, laneHalfWidth)
        var raw: [TimelineStreamSample] = []
        var index = 0
        var y = clampedStartY

        while y <= clampedEndY + 0.001 {
            let offset = min(curvatureOffset(at: y, bodies: bodies) * preset.multiplier, maxOffset)
            raw.append(TimelineStreamSample(
                index: index,
                y: min(y, clampedEndY),
                x: baseX + offset,
                lineWidth: lineWidth(at: y, bodies: bodies),
                tintHex: tintHex(at: y, bodies: bodies),
                progress: min(max((y - clampedStartY) / span, 0), 1)
            ))
            index += 1
            y += step
        }

        if raw.last?.y != clampedEndY {
            let offset = min(curvatureOffset(at: clampedEndY, bodies: bodies) * preset.multiplier, maxOffset)
            raw.append(TimelineStreamSample(
                index: index,
                y: clampedEndY,
                x: baseX + offset,
                lineWidth: lineWidth(at: clampedEndY, bodies: bodies),
                tintHex: tintHex(at: clampedEndY, bodies: bodies),
                progress: 1
            ))
        }

        return limitSlope(smoothOffsets(raw), baseX: baseX, maxOffset: maxOffset)
    }

    private static func curvatureBodies(from influences: [TimelineStreamInfluence]) -> [CurvatureBody] {
        let massInfluences = influences.filter(\.kind.contributesCurvatureMass)
        let clusterCandidates = massInfluences.filter { $0.kind == .task || $0.kind == .meeting }
            .sorted { lhs, rhs in
                if lhs.startY != rhs.startY { return lhs.startY < rhs.startY }
                return lhs.id < rhs.id
            }
        let standaloneBodies = massInfluences
            .filter { $0.kind == .routine || $0.kind == .flock }
            .map { body(from: $0, stackCount: max($0.stackCount, $0.kind == .flock ? 2 : 1)) }

        var groupedIDs = Set<String>()
        var clusterBodies: [CurvatureBody] = []
        var current: [TimelineStreamInfluence] = []

        func flushCurrent() {
            guard current.isEmpty == false else { return }
            if shouldCluster(current) {
                current.forEach { groupedIDs.insert($0.id) }
                clusterBodies.append(clusterBody(from: current))
            }
            current.removeAll()
        }

        for influence in clusterCandidates {
            guard let last = current.last else {
                current = [influence]
                continue
            }

            let gap = influence.startY - last.endY
            let overlaps = influence.startY < last.endY
            let closeEnough = gap <= clusterGapThreshold
            let denseWindow = current.count >= 2 && (influence.centerY - current[0].centerY) <= densityWindow

            if overlaps || closeEnough || denseWindow {
                current.append(influence)
            } else {
                flushCurrent()
                current = [influence]
            }
        }
        flushCurrent()

        let isolatedBodies = clusterCandidates
            .filter { groupedIDs.contains($0.id) == false }
            .map { body(from: $0, stackCount: 1) }

        return (standaloneBodies + clusterBodies + isolatedBodies).sorted { lhs, rhs in
            if lhs.centerY != rhs.centerY { return lhs.centerY < rhs.centerY }
            return lhs.id < rhs.id
        }
    }

    private static func shouldCluster(_ group: [TimelineStreamInfluence]) -> Bool {
        guard group.count > 1 else { return false }
        if group.count >= 3 { return true }
        for (previous, current) in zip(group, group.dropFirst()) {
            if current.startY < previous.endY || current.startY - previous.endY <= clusterGapThreshold {
                return true
            }
        }
        return false
    }

    private static func body(from influence: TimelineStreamInfluence, stackCount: Int) -> CurvatureBody {
        CurvatureBody(
            id: influence.id,
            kind: influence.kind,
            centerY: influence.centerY,
            height: max(40, influence.height),
            tintHex: influence.tintHex,
            stackCount: stackCount,
            isOverlapping: false
        )
    }

    private static func clusterBody(from group: [TimelineStreamInfluence]) -> CurvatureBody {
        let startY = group.map(\.startY).min() ?? 0
        let endY = group.map(\.endY).max() ?? startY + 40
        let overlaps = zip(group, group.dropFirst()).contains { previous, current in
            current.startY < previous.endY
        }
        let tintHex = group.first(where: { $0.kind == .meeting && $0.tintHex != nil })?.tintHex
            ?? group.first(where: { $0.tintHex != nil })?.tintHex

        return CurvatureBody(
            id: "cluster:\(group.map(\.id).joined(separator: "|"))",
            kind: .flock,
            centerY: (startY + endY) / 2,
            height: max(40, endY - startY),
            tintHex: tintHex,
            stackCount: group.count,
            isOverlapping: overlaps
        )
    }

    private static func itemMass(_ body: CurvatureBody) -> CGFloat {
        let durationFactor = min(1.35, 0.85 + max(40, body.height) / 180)
        let stackFactor: CGFloat = body.kind == .flock
            ? 1.0 + min(1.2, CGFloat(max(body.stackCount - 1, 0)) * 0.22)
            : 1.0
        let overlapFactor: CGFloat = body.isOverlapping ? 1.25 : 1.0
        return body.kind.baseMass * durationFactor * stackFactor * overlapFactor
    }

    private static func curvatureAmplitude(for body: CurvatureBody) -> CGFloat {
        let raw = itemMass(body) * 10
        switch body.kind {
        case .flock:
            return min(34, max(14, raw))
        case .routine:
            return 8
        case .meeting, .task:
            return min(16, max(4, raw))
        case .range, .sweep, .gap:
            return 0
        }
    }

    private static func influenceRadius(for body: CurvatureBody) -> CGFloat {
        let mass = itemMass(body)
        switch body.kind {
        case .flock:
            return max(120, body.height * 0.85 + mass * 28)
        case .routine:
            return 80
        case .meeting, .task:
            return max(55, body.height * 0.55 + mass * 16)
        case .range, .sweep, .gap:
            return 0
        }
    }

    private static func curvatureOffset(at y: CGFloat, bodies: [CurvatureBody]) -> CGFloat {
        bodies.reduce(CGFloat.zero) { total, body in
            let influence = gaussianInfluence(distance: abs(y - body.centerY), radius: influenceRadius(for: body))
            guard influence >= 0.04 else { return total }
            return total + curvatureAmplitude(for: body) * influence
        }
    }

    private static func lineWidth(at y: CGFloat, bodies: [CurvatureBody]) -> CGFloat {
        let clusterInfluence = bodies
            .filter { $0.kind == .flock }
            .map { gaussianInfluence(distance: abs(y - $0.centerY), radius: influenceRadius(for: $0)) }
            .max() ?? 0
        return baseLineWidth + min(clusterInfluence * 1.2, 1.2)
    }

    private static func tintHex(at y: CGFloat, bodies: [CurvatureBody]) -> String? {
        bodies
            .compactMap { body -> (body: CurvatureBody, influence: CGFloat)? in
                let influence = gaussianInfluence(distance: abs(y - body.centerY), radius: influenceRadius(for: body))
                guard influence >= 0.18 else { return nil }
                return (body, influence)
            }
            .max { lhs, rhs in lhs.influence < rhs.influence }?
            .body
            .tintHex
    }

    private static func gaussianInfluence(distance: CGFloat, radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let normalized = distance / radius
        return exp(-normalized * normalized)
    }

    private static func densityPreset(itemCount: Int, clusterCount: Int) -> DensityPreset {
        if itemCount >= 18 {
            return DensityPreset(multiplier: 1.10, maxOffset: 38)
        }
        if clusterCount >= 2 || itemCount >= 12 {
            return DensityPreset(multiplier: 1.0, maxOffset: 34)
        }
        if itemCount <= 7 && clusterCount == 0 {
            return DensityPreset(multiplier: 0.65, maxOffset: 18)
        }
        return DensityPreset(multiplier: 0.85, maxOffset: 28)
    }

    private static func smoothOffsets(_ points: [TimelineStreamSample]) -> [TimelineStreamSample] {
        guard points.count > 4 else { return points }
        var result = points

        for index in 2..<(points.count - 2) {
            let smoothedX =
                points[index - 2].x * 0.08 +
                points[index - 1].x * 0.18 +
                points[index].x * 0.48 +
                points[index + 1].x * 0.18 +
                points[index + 2].x * 0.08
            result[index] = TimelineStreamSample(
                index: points[index].index,
                y: points[index].y,
                x: smoothedX,
                lineWidth: points[index].lineWidth,
                tintHex: points[index].tintHex,
                progress: points[index].progress
            )
        }

        return result
    }

    private static func limitSlope(
        _ points: [TimelineStreamSample],
        baseX: CGFloat,
        maxOffset: CGFloat,
        maxDeltaX: CGFloat = maxSlopeDelta
    ) -> [TimelineStreamSample] {
        guard points.count > 1 else { return points }
        var result = points

        for index in 1..<result.count {
            let dx = result[index].x - result[index - 1].x
            let clampedDx = min(max(dx, -maxDeltaX), maxDeltaX)
            let x = min(max(result[index - 1].x + clampedDx, baseX), baseX + maxOffset)
            result[index] = TimelineStreamSample(
                index: result[index].index,
                y: result[index].y,
                x: x,
                lineWidth: result[index].lineWidth,
                tintHex: result[index].tintHex,
                progress: result[index].progress
            )
        }

        return result
    }

    private static func compositeAnchor(from anchors: [TimelineStreamAnchor]) -> TimelineStreamAnchor {
        let dominant = anchors.max { lhs, rhs in
            if lhs.kind.priority != rhs.kind.priority {
                return lhs.kind.priority < rhs.kind.priority
            }
            return lhs.strength < rhs.strength
        } ?? anchors[0]
        let totalWeight = anchors.reduce(CGFloat.zero) { partial, anchor in
            partial + max(CGFloat(anchor.kind.priority), 1)
        }
        let weightedY = anchors.reduce(CGFloat.zero) { partial, anchor in
            partial + (anchor.y * max(CGFloat(anchor.kind.priority), 1))
        } / max(totalWeight, 1)
        let maxStrength = anchors.map(\.strength).max() ?? dominant.strength
        let maxThickness = anchors.map(\.thickness).max() ?? dominant.thickness
        let tintHex = anchors.first(where: { $0.kind == dominant.kind && $0.tintHex != nil })?.tintHex
            ?? anchors.first(where: { $0.tintHex != nil })?.tintHex

        return TimelineStreamAnchor(
            id: "composite:\(anchors.map(\.id).joined(separator: "|"))",
            kind: dominant.kind,
            y: weightedY,
            strength: maxStrength,
            thickness: maxThickness,
            tintHex: tintHex,
            direction: .center
        )
    }

    private func interpolatedSample(atY y: CGFloat) -> TimelineStreamSample? {
        let clamped = clampedY(y)
        let allSamples = samplePoints
        guard allSamples.isEmpty == false else { return nil }
        guard let first = allSamples.first else { return nil }
        guard let last = allSamples.last else { return nil }
        if clamped <= first.y { return first }
        if clamped >= last.y { return last }

        guard let upperIndex = allSamples.firstIndex(where: { $0.y >= clamped }), upperIndex > 0 else {
            return first
        }
        let lower = allSamples[upperIndex - 1]
        let upper = allSamples[upperIndex]
        let span = max(upper.y - lower.y, 0.001)
        let ratio = (clamped - lower.y) / span
        return TimelineStreamSample(
            index: lower.index,
            y: clamped,
            x: interpolate(lower.x, upper.x, t: ratio),
            lineWidth: interpolate(lower.lineWidth, upper.lineWidth, t: ratio),
            tintHex: ratio < 0.5 ? lower.tintHex : upper.tintHex,
            progress: interpolate(lower.progress, upper.progress, t: ratio)
        )
    }

    private func nearestAnchorWeight(atY y: CGFloat, kind: TimelineStreamInfluenceKind) -> CGFloat {
        anchors
            .filter { $0.kind == kind }
            .map { max(0, 1 - (abs($0.y - y) / Self.minimumClusterDistance)) }
            .max() ?? 0
    }

    private static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = (uuu * start.x)
            + (3 * uu * t * control1.x)
            + (3 * u * tt * control2.x)
            + (ttt * end.x)
        let y = (uuu * start.y)
            + (3 * uu * t * control1.y)
            + (3 * u * tt * control2.y)
            + (ttt * end.y)
        return CGPoint(x: x, y: y)
    }

    private static func interpolate(_ start: CGFloat, _ end: CGFloat, t: CGFloat) -> CGFloat {
        start + ((end - start) * min(max(t, 0), 1))
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, t: CGFloat) -> CGFloat {
        Self.interpolate(start, end, t: t)
    }
}

struct TimelineStreamLayerSpec: Equatable {
    let glowLineWidth: CGFloat
    let bodyLineWidth: CGFloat
    let coreLineWidth: CGFloat
    let usesRoundedCapsAndJoins: Bool

    static let expressive = TimelineStreamLayerSpec(
        glowLineWidth: TimelineStreamGeometry.glowLineWidth,
        bodyLineWidth: TimelineStreamGeometry.baseLineWidth,
        coreLineWidth: TimelineStreamGeometry.coreLineWidth,
        usesRoundedCapsAndJoins: true
    )
}

struct TimelineNowBeadPresentation: Equatable {
    static func clampedY(_ y: CGFloat, contentHeight: CGFloat, verticalInset: CGFloat = 14) -> CGFloat {
        let upper = max(contentHeight - verticalInset, verticalInset)
        return min(max(y, verticalInset), upper)
    }

    static func shouldPulse(reduceMotion: Bool) -> Bool {
        reduceMotion == false
    }
}

struct TimelineCanvasLayoutPlan: Equatable {
    private struct Candidate {
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

    static func maxVisualColumns(for layoutClass: LifeBoardLayoutClass) -> Int {
        switch layoutClass {
        case .phone:
            return 3
        case .padCompact, .padRegular, .padExpanded:
            return 4
        }
    }

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

    private struct VisualTimeAnchor {
        let date: Date
        let y: CGFloat
    }

    private struct VisualTimeSegment {
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

    private func visualTimeY(for date: Date) -> CGFloat? {
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

    private func visualTimeSegments() -> [VisualTimeSegment] {
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

    private func visualTimeAnchors(from segments: [VisualTimeSegment]) -> [VisualTimeAnchor] {
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

    private func visualRoutineAnchorY(id: String) -> CGFloat? {
        visualElements.first { positioned in
            guard case .routineMarker(let model) = positioned.element else { return false }
            return model.anchor.id == id
        }?.centerY
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

    private static func positionedBlocks(
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

    private static func positionedVisualElements(
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

    private static func rawVisualElements(
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

    private static func visualElement(for positioned: PositionedBlock) -> VisualTimelineElement {
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

    private static func minutesBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.minute], from: start, to: end).minute ?? 0)
    }

    private static func longGapIndicatorText(for minutes: Int) -> String {
        "· · · \(TimelineFormatting.durationText(TimeInterval(minutes * 60))) free · · ·"
    }

    private static func midpointDate(from start: Date, to end: Date, calendar: Calendar) -> Date {
        let minutes = max(0, calendar.dateComponents([.minute], from: start, to: end).minute ?? 0)
        return calendar.date(byAdding: .minute, value: minutes / 2, to: start) ?? start
    }

    private static func lightPromptDate(for projection: TimelineDayProjection, blocks: [PositionedBlock], calendar: Calendar) -> Date {
        let latestEnd = blocks.map(\.block.endDate).max() ?? projection.wakeAnchor.time
        let remaining = max(0, calendar.dateComponents([.minute], from: latestEnd, to: projection.sleepAnchor.time).minute ?? 0)
        return calendar.date(byAdding: .minute, value: max(30, remaining / 2), to: latestEnd) ?? latestEnd
    }

    private static func emptyStateElement(
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

    private static func spineExtent(for elements: [PositionedVisualTimelineElement]) -> SpineExtent {
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

    private static func endMarker(
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

    private static func singleVisualHeight(
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
        layoutClass: LifeBoardLayoutClass = .phone,
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
        item.isComplete ? Color.lifeboard.textTertiary.opacity(0.68) : Color.lifeboard.textSecondary
    }

    @MainActor
    static func titleColor(for item: TimelinePlanItem) -> Color {
        item.isComplete ? Color.lifeboard.textSecondary.opacity(0.72) : Color.lifeboard.textPrimary
    }

    @MainActor
    static func accessoryColor(for item: TimelinePlanItem, isActive: Bool) -> Color {
        if item.isComplete {
            return Color.lifeboard.textSecondary.opacity(0.62)
        }
        return isActive ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary
    }
}

private enum TimelineDayRelation {
    case past
    case today
    case future
}

private struct TimelineDayStablePresentation {
    let projection: TimelineDayProjection
    let calendar: Calendar

    init(projection: TimelineDayProjection, calendar: Calendar = .current) {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineStablePresentationBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        self.projection = projection
        self.calendar = calendar
    }
}

private struct TimelineDayCurrentState {
    let now: Date
    let dayRelation: TimelineDayRelation
    let currentBoundaryDate: Date?
    let currentTintHex: String?
    let activeGapID: String?

    init(stable: TimelineDayStablePresentation, now: Date) {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineCurrentStateBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let projection = stable.projection
        let calendar = stable.calendar
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

        let sortedItems = projection.allTimedItems
        let sortedGaps = projection.actionableGaps

        let currentItem = sortedItems.first(where: { item in
            guard let start = item.startDate, let end = item.endDate, item.isComplete == false else { return false }
            return start <= now && now < end
        })

        let activeGap = currentItem == nil && dayRelation == .today
            ? sortedGaps.first(where: { $0.startDate <= now && now < $0.endDate })
            : nil

        currentBoundaryDate = dayRelation == .today ? min(max(now, projection.wakeAnchor.time), projection.sleepAnchor.time) : nil
        currentTintHex = currentItem?.tintHex
            ?? projection.allTimedItems.first(where: { $0.isComplete && $0.tintHex != nil })?.tintHex
        activeGapID = activeGap?.id
    }
}

private struct TimelineDayPresentation {
    private let current: TimelineDayCurrentState

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
    static var neutralStem: Color { Color.lifeboard.strokeHairline.opacity(0.42) }

    @MainActor
    static var gapPastStem: Color { Color.lifeboard.accentPrimary.opacity(0.18) }

    @MainActor
    static var futureCapsule: Color { Color.lifeboard.surfacePrimary.opacity(0.9) }

    @MainActor
    static var futureCapsuleStroke: Color { Color.lifeboard.strokeHairline.opacity(0.58) }

    @MainActor
    static var anchorCapsuleFill: Color { Color.lifeboard.surfacePrimary.opacity(0.94) }

    @MainActor
    static var metaText: Color { Color.lifeboard.textSecondary }

    @MainActor
    static var utilityText: Color { Color.lifeboard.textTertiary }
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

    func resolvedTimelineBottomPadding(hasNextHomeWidget: Bool) -> CGFloat {
        hasNextHomeWidget ? 0 : timelineBottomPadding
    }

    static func make(for layoutClass: LifeBoardLayoutClass) -> TimelineSurfaceMetrics {
        let bottomProtection = TimelineBottomProtectionBudget.make(for: layoutClass).timelineInset
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
                expandedTimeGutter: 68,
                expandedSpineLaneWidth: 0,
                expandedTrailingLaneWidth: 0,
                expandedContentInset: 4,
                expandedTimeToSpineGap: 3,
                expandedCapsuleMinWidth: 60,
                expandedSingleColumnTextMaxWidth: 360,
                expandedOverlappingTextMaxWidth: 300,
                expandedAnchorCircleSize: 56,
                expandedAnchorIconSize: 20,
                agendaCapsuleWidth: 56,
                agendaAnchorCircleSize: 48,
                agendaAnchorIconSize: 18,
                timelineBottomPadding: bottomProtection
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
                timelineBottomPadding: bottomProtection
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
                timelineBottomPadding: bottomProtection
            )
        }
    }
}

struct TimelineRailMetrics: Equatable {
    let labelLeadingX: CGFloat
    let labelWidth: CGFloat
    let timeToSpineGap: CGFloat
    let spineX: CGFloat
    let contentLeadingGap: CGFloat
    let contentX: CGFloat
    let routineTextGapFromIcon: CGFloat

    var labelLayerWidth: CGFloat { labelLeadingX + labelWidth }

    func routineTextLeadingX(iconSize: CGFloat) -> CGFloat {
        routineTextLeadingX(iconSize: iconSize, mountedSpineX: spineX)
    }

    func routineTextLeadingX(iconSize: CGFloat, mountedSpineX: CGFloat) -> CGFloat {
        mountedSpineX + (iconSize / 2) + routineTextGapFromIcon
    }

    static func make(
        for layoutClass: LifeBoardLayoutClass,
        surfaceMetrics: TimelineSurfaceMetrics,
        totalWidth: CGFloat = 390
    ) -> TimelineRailMetrics {
        switch layoutClass {
        case .phone:
            let labelLeadingX: CGFloat
            let labelWidth: CGFloat
            let timeToSpineGap: CGFloat
            let streamLaneWidth: CGFloat
            let contentGap: CGFloat

            if totalWidth <= 390 {
                labelLeadingX = 2
                labelWidth = 44
                timeToSpineGap = 4
                streamLaneWidth = 36
                contentGap = 8
            } else if totalWidth <= 430 {
                labelLeadingX = 3
                labelWidth = 46
                timeToSpineGap = 5
                streamLaneWidth = 38
                contentGap = 8
            } else {
                labelLeadingX = 4
                labelWidth = 48
                timeToSpineGap = 6
                streamLaneWidth = 42
                contentGap = 8
            }

            let streamLeadingX = labelLeadingX + labelWidth + timeToSpineGap
            let spineX = streamLeadingX + (streamLaneWidth / 2)
            let contentX = streamLeadingX + streamLaneWidth + contentGap
            return TimelineRailMetrics(
                labelLeadingX: labelLeadingX,
                labelWidth: labelWidth,
                timeToSpineGap: timeToSpineGap,
                spineX: spineX,
                contentLeadingGap: contentX - spineX,
                contentX: contentX,
                routineTextGapFromIcon: 14
            )
        case .padCompact, .padRegular, .padExpanded:
            let spineX = surfaceMetrics.expandedTimeGutter
                + surfaceMetrics.expandedTimeToSpineGap
                + (surfaceMetrics.expandedSpineLaneWidth / 2)
            let contentX = surfaceMetrics.expandedTimeGutter
                + surfaceMetrics.expandedTimeToSpineGap
                + surfaceMetrics.expandedSpineLaneWidth
                + surfaceMetrics.expandedContentInset
            return TimelineRailMetrics(
                labelLeadingX: 0,
                labelWidth: max(surfaceMetrics.expandedTimeGutter - 8, 44),
                timeToSpineGap: surfaceMetrics.expandedTimeToSpineGap,
                spineX: spineX,
                contentLeadingGap: max(contentX - spineX, 0),
                contentX: contentX,
                routineTextGapFromIcon: 14
            )
        }
    }
}

enum TimelineSpineMounting {
    static func centerX(for geometry: TimelineStreamGeometry, atY y: CGFloat) -> CGFloat {
        geometry.x(atY: y)
    }

    static func routineTextLeadingX(
        for geometry: TimelineStreamGeometry,
        atY y: CGFloat,
        iconSize: CGFloat,
        railMetrics: TimelineRailMetrics
    ) -> CGFloat {
        railMetrics.routineTextLeadingX(
            iconSize: iconSize,
            mountedSpineX: centerX(for: geometry, atY: y)
        )
    }
}

enum TimelineRailLabelKind: Equatable {
    case compactHour
    case exact
    case current
}

enum TimelineRailTypography {
    static let compactHourSize: CGFloat = 14
    static let exactSize: CGFloat = 14
    static let currentSize: CGFloat = 13

    static func font(for kind: TimelineRailLabelKind, isEmphasized: Bool) -> Font {
        switch kind {
        case .compactHour:
            return .system(size: compactHourSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .exact:
            return .system(size: exactSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .current:
            return .system(size: currentSize, weight: .semibold, design: .rounded)
        }
    }
}

enum TimelineRailTimeFormatter {
    static func railText(for date: Date, kind: TimelineRailLabelKind, calendar: Calendar = .current) -> String {
        switch kind {
        case .compactHour:
            return formatted(date, format: "h a", calendar: calendar)
        case .exact, .current:
            return formatted(date, format: "h:mm a", calendar: calendar)
        }
    }

    static func railText(forItemStart date: Date, calendar: Calendar = .current) -> String {
        let minute = calendar.component(.minute, from: date)
        let kind: TimelineRailLabelKind = minute == 0 ? .compactHour : .exact
        return railText(for: date, kind: kind, calendar: calendar)
    }

    private static func formatted(_ date: Date, format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

enum TimelineRoutineTextFormatter {
    static func subtitle(for anchor: TimelineAnchorItem, subtitle: String?, calendar: Calendar = .current) -> String {
        let timeText = TimelineRailTimeFormatter.railText(for: anchor.time, kind: .exact, calendar: calendar)
        guard let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              subtitle.isEmpty == false else {
            return timeText
        }
        return "\(timeText) · \(subtitle)"
    }
}

private struct TimelineBottomProtectionBudget: Equatable {
    let bottomNavHeight: CGFloat
    let floatingActionButtonHeight: CGFloat
    let reflectionBannerHeight: CGFloat
    let extraClearance: CGFloat

    var timelineInset: CGFloat {
        bottomNavHeight + floatingActionButtonHeight + reflectionBannerHeight + extraClearance
    }

    static func make(for layoutClass: LifeBoardLayoutClass) -> TimelineBottomProtectionBudget {
        switch layoutClass {
        case .phone:
            return TimelineBottomProtectionBudget(
                bottomNavHeight: 72,
                floatingActionButtonHeight: 0,
                reflectionBannerHeight: 0,
                extraClearance: 40
            )
        case .padCompact, .padRegular, .padExpanded:
            return TimelineBottomProtectionBudget(
                bottomNavHeight: 44,
                floatingActionButtonHeight: 32,
                reflectionBannerHeight: 24,
                extraClearance: 32
            )
        }
    }
}

private func timelineDisplayedNow(for projection: TimelineDayProjection, timelineDate: Date) -> Date {
    Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
}

private func timelineSuggestedAddDate(for gap: TimelineGap, now: Date, calendar: Calendar = .current) -> Date {
    guard gap.startDate <= now, now < gap.endDate else {
        return gap.startDate
    }

    let quarterHour: TimeInterval = 15 * 60
    let roundedInterval = ceil(now.timeIntervalSinceReferenceDate / quarterHour) * quarterHour
    let roundedDate = Date(timeIntervalSinceReferenceDate: roundedInterval)
    let latestInsideGap = gap.endDate.addingTimeInterval(-60)
    return min(max(roundedDate, gap.startDate), latestInsideGap)
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
        return Color.lifeboard.textTertiary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.statusWarning.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary.opacity(0.92)
    default:
        return TimelineVisualTokens.metaText
    }
}

@MainActor
private func timelineTitleColor(for row: TimelineRenderableRow, item: TimelinePlanItem? = nil) -> Color {
    switch row.temporalState {
    case .pastCompleted:
        return Color.lifeboard.textSecondary.opacity(0.72)
    case .pastIncomplete:
        return Color.lifeboard.textPrimary.opacity(0.92)
    case .currentTask:
        return Color.lifeboard.textPrimary
    default:
        if let item {
            return TimelineItemVisuals.titleColor(for: item)
        }
        return Color.lifeboard.textPrimary
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

private func timelineAccessibilityIdentifier(for item: TimelinePlanItem) -> String {
    if let eventID = item.eventID {
        return "home.timeline.event.\(eventID)"
    }
    if let taskID = item.taskID {
        return "home.timeline.task.\(taskID.uuidString)"
    }
    return "home.timeline.item.\(item.id)"
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
private func timelineGapPromptText(for gap: TimelineGap, row: TimelineRenderableRow) -> Text {
    let duration = gap.compactDurationText
    let promptSource = gap.supportingText.localizedCaseInsensitiveContains(duration)
        ? gap.supportingText
        : "\(gap.supportingText) \(duration)"
    guard let range = promptSource.range(of: duration) else {
        return Text(promptSource)
    }

    let prefix = String(promptSource[..<range.lowerBound])
    let suffix = String(promptSource[range.upperBound...])
    return Text(prefix)
        + Text(duration)
            .foregroundStyle(row.temporalState == .activeGap ? Color.lifeboard.textPrimary : gapPromptTint(for: gap))
            .font(.lifeboard(.callout).weight(.semibold))
        + Text(suffix)
}

@MainActor
private func gapPromptTint(for gap: TimelineGap) -> Color {
    switch gap.emphasis {
    case .openTime:
        return Color.lifeboard.accentPrimary
    case .prepWindow:
        return Color.lifeboard.statusWarning
    case .quietWindow:
        return Color.lifeboard.statusSuccess
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    private var rendererMode: SunriseTimelineRendererMode {
        SunriseTimelineRendererPolicy.mode(
            layoutClass: layoutClass,
            dayLayoutMode: snapshot.day.layoutMode,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

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

    private var suggestedPlacementTime: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(snapshot.selectedDate),
           snapshot.day.currentTime > snapshot.day.wakeAnchor.time,
           snapshot.day.currentTime < snapshot.day.sleepAnchor.time {
            return snapshot.day.currentTime
        }
        return snapshot.day.wakeAnchor.time
    }

    private var hasMixedTimedOverlap: Bool {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.lifeboard.accentWash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Place this in your day")
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("Drop on a time or move it to All Day.")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Back", action: onBack)
                    .font(.lifeboard(.support).weight(.semibold))
                    .disabled(candidate.isApplying)
            }

            if candidate.isApplying {
                ProgressView("Scheduling...")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            if let errorMessage = candidate.errorMessage {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(errorMessage)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Spacer(minLength: 0)
                    Button("Dismiss", action: onClearError)
                        .font(.lifeboard(.support).weight(.semibold))
                }
                .padding(10)
                .background(Color.lifeboard.surfacePrimary.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            placementActions
        }
        .padding(14)
        .background(Color.lifeboard.accentWash.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.lifeboard.accentPrimary.opacity(0.16), lineWidth: 1)
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
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        } else {
            HStack(spacing: 10) {
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        }
    }

    private func placementButton(_ title: String, systemImage: String, emphasized: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            LifeBoardFeedback.selection()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.support).weight(.semibold))
                .foregroundStyle(emphasized ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: 42)
                .padding(.horizontal, spacing.s12)
                .background(emphasized ? Color.lifeboard.actionPrimary : Color.lifeboard.surfacePrimary.opacity(0.82), in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(emphasized ? Color.lifeboard.actionPrimary.opacity(0.2) : Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .disabled(candidate.isApplying)
    }
}

private struct TimelinePlacementDock: View {
    let candidate: TimelinePlacementCandidate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityHidden(true)
            Text(candidate.title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Drag to place")
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isDragging ? Color.lifeboard.accentWash.opacity(0.9) : Color.lifeboard.surfaceSecondary, in: Capsule())
        .overlay(
            Capsule()
                .stroke(isDragging ? Color.lifeboard.accentPrimary.opacity(0.42) : Color.lifeboard.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .scaleEffect(isDragging && reduceMotion == false ? 1.018 : 1)
        .shadow(color: Color.lifeboard.accentPrimary.opacity(isDragging ? 0.16 : 0), radius: isDragging ? 14 : 0, x: 0, y: 8)
        .draggable(candidate.taskID.uuidString)
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    guard isDragging == false else { return }
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = true
                    }
                    LifeBoardFeedback.light()
                }
                .onEnded { _ in
                    withAnimation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.feedbackFast) {
                        isDragging = false
                    }
                }
        )
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
            base = Color(uiColor: UIColor(lifeboardHex: tintHex))
        } else {
            base = Color.lifeboard.accentPrimary
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

struct SunriseTimelineBar: View {
    let onSnapAnchor: (SunriseAnchor) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        Capsule()
            .fill(Color.lifeboard.textTertiary.opacity(0.24))
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

    @State private var isAllDayTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let placementCandidate {
                Button {
                    LifeBoardFeedback.selection()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isAllDayTargeted ? "calendar.badge.checkmark" : "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.lifeboard.accentWash, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAllDayTargeted ? "Drop for All Day" : "Make All Day")
                                .font(.lifeboard(.support).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(placementCandidate.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isAllDayTargeted ? Color.lifeboard.accentWash.opacity(0.82) : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isAllDayTargeted ? Color.lifeboard.accentPrimary.opacity(0.46) : Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .scaleEffect(isAllDayTargeted && reduceMotion == false ? 1.012 : 1)
                .dropDestination(for: String.self, action: { items, _ in
                    guard items.contains(placementCandidate.taskID.uuidString) else { return false }
                    LifeBoardFeedback.success()
                    onPlaceReplanAllDay(placementCandidate, selectedDate)
                    return true
                }, isTargeted: { newValue in
                    isAllDayTargeted = newValue
                })
                .onChange(of: isAllDayTargeted) { _, newValue in
                    guard newValue else { return }
                    LifeBoardFeedback.selection()
                }
                .accessibilityHint("Places the replanned task in the all-day row for this date.")
                .accessibilityIdentifier("home.needsReplan.hotZone.allDay")
            }

            if allDayItems.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All-day commitments")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)

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
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text(item.title)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                }
            }
            .frame(width: 220, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue("All-day item")
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
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
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text("Fill open time first")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("Pull something unplaced into the timeline before inspecting the rest of the day.")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Schedule Inbox") {
                    onScheduleInbox()
                }
                .buttonStyle(.plain)
                .font(.lifeboard(.buttonSmall))
                .foregroundStyle(Color.lifeboard.accentOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.lifeboard.accentPrimary, in: Capsule())
                .accessibilityHint("Starts placing inbox tasks into open time.")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inboxItems.prefix(4)) { item in
                        Button {
                            onTaskTap(item)
                        } label: {
                            Text(item.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.lifeboard.surfacePrimary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if inboxItems.count > 4 {
                        Text("+\(inboxItems.count - 4) more")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.lifeboard.surfacePrimary, in: Capsule())
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
                .fill(Color.lifeboard.surfaceSecondary)
        )
    }
}

private struct TimelineCurrentTimeRule: View {
    let startX: CGFloat
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.lifeboard.statusDanger.opacity(0.16))
            .frame(width: min(max(width - startX, 0), 92), height: 1)
            .offset(x: startX, y: -0.5)
            .frame(width: width, height: 1, alignment: .leading)
    }
}

private struct TimelineCurrentTimeMarker: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let startX: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            TimelineRailLabel(
                text: TimelineRailTimeFormatter.railText(for: time, kind: .current),
                kind: .current,
                isEmphasized: true,
                color: Color.lifeboard.statusDanger,
                metrics: railMetrics
            )
                .offset(y: -8)

            Circle()
                .fill(Color.lifeboard.statusDanger)
                .frame(width: 8, height: 8)
                .offset(x: startX - 4, y: -4)
        }
        .frame(width: startX + 4, height: 1, alignment: .leading)
    }
}

private struct TimelineRailLabel: View {
    let text: String
    let kind: TimelineRailLabelKind
    let isEmphasized: Bool
    let color: Color
    let metrics: TimelineRailMetrics
    var leadingX: CGFloat? = nil

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.trailing)
            .frame(width: metrics.labelWidth, alignment: .trailing)
            .offset(x: leadingX ?? metrics.labelLeadingX)
    }

    private var font: Font {
        TimelineRailTypography.font(for: kind, isEmphasized: isEmphasized)
    }
}

private struct TimelineSpineEndView: View {
    let extent: TimelineCanvasLayoutPlan.SpineExtent
    let lineWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(TimelineVisualTokens.neutralStem)
                .frame(width: lineWidth, height: max(extent.solidEndY - extent.startY, 0))
                .offset(y: extent.startY)

            LinearGradient(
                colors: [
                    TimelineVisualTokens.neutralStem,
                    TimelineVisualTokens.neutralStem.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: lineWidth, height: max(extent.fadeEndY - extent.fadeStartY, 0))
            .offset(y: extent.fadeStartY)
        }
    }
}

private enum TimelineStreamPalette {
    private struct Stop {
        let progress: CGFloat
        let red: Double
        let green: Double
        let blue: Double
    }

    private static let stops: [Stop] = [
        Stop(progress: 0.0, red: 0.22, green: 0.56, blue: 0.55),
        Stop(progress: 0.38, red: 0.45, green: 0.57, blue: 0.36),
        Stop(progress: 0.72, red: 0.48, green: 0.45, blue: 0.58),
        Stop(progress: 1.0, red: 0.38, green: 0.39, blue: 0.50)
    ]

    static func color(progress: CGFloat) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        guard let first = stops.first else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard let last = stops.last else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard clampedProgress > first.progress else {
            return Color(red: first.red, green: first.green, blue: first.blue)
        }
        guard clampedProgress < last.progress else {
            return Color(red: last.red, green: last.green, blue: last.blue)
        }

        let upperIndex = stops.firstIndex { $0.progress >= clampedProgress } ?? (stops.count - 1)
        let lower = stops[max(upperIndex - 1, 0)]
        let upper = stops[upperIndex]
        let span = max(upper.progress - lower.progress, 0.001)
        let ratio = (clampedProgress - lower.progress) / span
        return Color(
            red: lower.red + ((upper.red - lower.red) * Double(ratio)),
            green: lower.green + ((upper.green - lower.green) * Double(ratio)),
            blue: lower.blue + ((upper.blue - lower.blue) * Double(ratio))
        )
    }
}

struct TimelineStreamGlintPresentation: Equatable {
    static let halfLength: CGFloat = 16
    static let blurRadius: CGFloat = 3
    static let opacity: Double = 0.36
    static let extraLineWidth: CGFloat = 0.75

    static func visibleAnchorIDs(
        anchors: [TimelineStreamAnchor],
        currentY: CGFloat?,
        currentDistanceThreshold: CGFloat = 64
    ) -> Set<String> {
        let candidates = anchors
            .filter { $0.kind == .task || $0.kind == .meeting || $0.kind == .flock }
            .sorted { lhs, rhs in
                if lhs.y != rhs.y { return lhs.y < rhs.y }
                return lhs.id < rhs.id
            }
        var visible = Set(candidates.filter { $0.kind == .flock }.map(\.id))

        guard let currentY else {
            return visible
        }

        if let current = candidates.min(by: { abs($0.y - currentY) < abs($1.y - currentY) }),
           abs(current.y - currentY) <= currentDistanceThreshold {
            visible.insert(current.id)
        }

        if let next = candidates.first(where: { $0.y > currentY + 8 }) {
            visible.insert(next.id)
        }

        return visible
    }
}

private struct CurvingDayStreamView: View {
    let geometry: TimelineStreamGeometry
    let currentY: CGFloat?

    var body: some View {
        Canvas { context, _ in
            let path = geometry.path()
            let fullOpacity = currentY == nil ? 0.88 : 0.94
            let visibleGlintIDs = TimelineStreamGlintPresentation.visibleAnchorIDs(
                anchors: geometry.anchors,
                currentY: currentY
            )
            let gradient = Gradient(colors: [
                TimelineStreamPalette.color(progress: 0).opacity(0.78 * fullOpacity),
                TimelineStreamPalette.color(progress: 0.38).opacity(0.80 * fullOpacity),
                TimelineStreamPalette.color(progress: 0.72).opacity(0.78 * fullOpacity),
                TimelineStreamPalette.color(progress: 1).opacity(0.76 * fullOpacity)
            ])
            let glowGradient = Gradient(colors: [
                TimelineStreamPalette.color(progress: 0).opacity(0.18),
                TimelineStreamPalette.color(progress: 0.38).opacity(0.20),
                TimelineStreamPalette.color(progress: 0.72).opacity(0.18),
                TimelineStreamPalette.color(progress: 1).opacity(0.17)
            ])
            let startPoint = CGPoint(x: geometry.baseX, y: geometry.startY)
            let endPoint = CGPoint(x: geometry.baseX, y: geometry.endY)

            context.stroke(
                path,
                with: .linearGradient(glowGradient, startPoint: startPoint, endPoint: endPoint),
                style: StrokeStyle(
                    lineWidth: TimelineStreamGeometry.glowLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            context.stroke(
                path,
                with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint),
                style: StrokeStyle(
                    lineWidth: TimelineStreamGeometry.baseLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.58 * fullOpacity)),
                style: StrokeStyle(
                    lineWidth: TimelineStreamGeometry.coreLineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            for anchor in geometry.anchors where visibleGlintIDs.contains(anchor.id) {
                guard let glintPath = glintPath(centerY: anchor.y) else {
                    continue
                }
                let glintColor = TimelineStreamPalette.color(progress: progress(for: anchor.y))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: TimelineStreamGlintPresentation.blurRadius))
                    layer.stroke(
                        glintPath,
                        with: .color(glintColor.opacity(TimelineStreamGlintPresentation.opacity * 0.55)),
                        style: StrokeStyle(
                            lineWidth: TimelineStreamGeometry.baseLineWidth + TimelineStreamGlintPresentation.extraLineWidth + 1,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
                context.stroke(
                    glintPath,
                    with: .color(glintColor.opacity(TimelineStreamGlintPresentation.opacity)),
                    style: StrokeStyle(
                        lineWidth: TimelineStreamGeometry.baseLineWidth + TimelineStreamGlintPresentation.extraLineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }

    private func glintPath(centerY: CGFloat) -> Path? {
        let samples = geometry.samples(stride: 5).filter { abs($0.y - centerY) <= TimelineStreamGlintPresentation.halfLength }
        guard samples.count > 1 else { return nil }
        var path = Path()
        path.move(to: CGPoint(x: samples[0].x, y: samples[0].y))
        for sample in samples.dropFirst() {
            path.addLine(to: CGPoint(x: sample.x, y: sample.y))
        }
        return path
    }

    private func progress(for y: CGFloat) -> CGFloat {
        let span = max(geometry.endY - geometry.startY, 1)
        return min(max((y - geometry.startY) / span, 0), 1)
    }
}

private struct TimelineNowBeadView: View {
    let time: Date
    let railMetrics: TimelineRailMetrics
    let beadX: CGFloat
    let reduceMotion: Bool
    @State private var pulseIsExpanded = false

    var body: some View {
        ZStack(alignment: .leading) {
            Text("Now · \(TimelineRailTimeFormatter.railText(for: time, kind: .current))")
                .font(TimelineRailTypography.font(for: .current, isEmphasized: true))
                .monospacedDigit()
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.lifeboard.surfacePrimary.opacity(0.94), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.lifeboard.accentPrimary.opacity(0.36), lineWidth: 1)
                }
                .offset(x: max(railMetrics.labelLeadingX, beadX - 58), y: -14)

            if TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) {
                Circle()
                    .stroke(Color.lifeboard.accentPrimary.opacity(pulseIsExpanded ? 0 : 0.28), lineWidth: 1.4)
                    .frame(width: 25, height: 25)
                    .scaleEffect(pulseIsExpanded ? 1.28 : 1)
                    .offset(x: beadX - 12.5, y: -12.5)
            }

            Circle()
                .fill(Color.lifeboard.accentPrimary.opacity(reduceMotion ? 0.18 : 0.26))
                .frame(width: 24, height: 24)
                .offset(x: beadX - 12, y: -12)

            Circle()
                .fill(Color.lifeboard.accentPrimary)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.76), lineWidth: 1)
                }
                .offset(x: beadX - 5.5, y: -5.5)
        }
        .frame(height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current time")
        .accessibilityValue(time.formatted(date: .omitted, time: .shortened))
        .onAppear {
            guard TimelineNowBeadPresentation.shouldPulse(reduceMotion: reduceMotion) else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulseIsExpanded = true
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            if newValue {
                pulseIsExpanded = false
            } else {
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    pulseIsExpanded = true
                }
            }
        }
    }
}

private struct TimelineLongGapIndicator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct TimelineEndAddMarker: View {
    let suggestedDate: Date
    let accessibilityValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.55))
                .frame(width: TimelineCanvasLayoutPlan.endMarkerHitArea, height: TimelineCanvasLayoutPlan.endMarkerHitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task after timeline")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens Add Task with a suggested timeline time.")
        .accessibilityIdentifier("home.timeline.endAdd")
    }
}

private struct TimelineEmptyStateCard: View {
    let model: VisualTimelineElement.EmptyStateModel
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Spacer(minLength: 0)

            actionButtons
        }
        .padding(14)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(model.showsCalendarAction ? "home.timeline.calendarHidden" : "home.timeline.emptyDay")
    }

    @MainActor
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            EvaMascotView(
                placement: model.showsCalendarAction ? .timelineEmptySchedule : .restReminder,
                size: .inline
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(model.subtitle)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    @MainActor
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            actionButtonColumn
        } else {
            ViewThatFits(in: .horizontal) {
                actionButtonRow
                actionButtonColumn
            }
        }
    }

    @MainActor
    private var actionButtonRow: some View {
        HStack(spacing: 10) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    private var actionButtonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            emptyStateActionButton(
                title: model.primaryTitle,
                tone: .secondary,
                action: primaryAction
            )
            emptyStateActionButton(
                title: model.secondaryTitle,
                tone: .primary,
                action: secondaryAction
            )
        }
    }

    @MainActor
    private func emptyStateActionButton(
        title: String,
        tone: TimelineEmptyStateActionTone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.lifeboard(.buttonSmall))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 34)
                .background(tone.background, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(tone.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

@MainActor
private enum TimelineEmptyStateActionTone {
    case primary
    case secondary

    var foreground: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentOnPrimary
        case .secondary:
            return Color.lifeboard.accentPrimary
        }
    }

    var background: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary
        case .secondary:
            return Color.lifeboard.accentWash.opacity(0.76)
        }
    }

    var border: Color {
        switch self {
        case .primary:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .secondary:
            return Color.lifeboard.accentMuted.opacity(0.34)
        }
    }
}

private enum TimelineDenseTitleFormatter {
    static func displayTitles(for items: [TimelinePlanItem]) -> [String: String] {
        let basePairs = items.map { item in
            (item.id, compressedTitle(for: item.title, subtitle: item.subtitle))
        }
        let grouped = Dictionary(grouping: basePairs) { $0.1 }
        var result: [String: String] = [:]

        for (title, pairs) in grouped {
            if pairs.count == 1, let id = pairs.first?.0 {
                result[id] = title
            } else {
                for pair in pairs {
                    guard let item = items.first(where: { $0.id == pair.0 }) else {
                        result[pair.0] = title
                        continue
                    }
                    if let start = item.startDate {
                        result[pair.0] = "\(title) \(start.formatted(date: .omitted, time: .shortened))"
                    } else {
                        result[pair.0] = title
                    }
                }
            }
        }

        return result
    }

    private static func compressedTitle(for title: String, subtitle: String?) -> String {
        var value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: #"^\[[^\]]+\]\s*"#, with: "", options: .regularExpression)

        if let subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           subtitle.isEmpty == false,
           value.localizedCaseInsensitiveContains("\(subtitle):") {
            value = value.replacingOccurrences(of: "\(subtitle):", with: "", options: .caseInsensitive)
        }

        let lower = title.lowercased()
        if lower.hasPrefix("[daily]"), value.localizedCaseInsensitiveContains("daily") == false {
            value = "Daily \(value)"
        }
        if lower.hasPrefix("[fortnightly]") {
            value = value.replacingOccurrences(of: "App Review", with: "Review", options: .caseInsensitive)
        }

        value = value.replacingOccurrences(
            of: #"^(.+?)\s*[-:]\s*\1\s+"#,
            with: "$1 ",
            options: [.regularExpression, .caseInsensitive]
        )
        value = value.replacingOccurrences(of: "Consumer App Review", with: "Consumer Review", options: .caseInsensitive)
        value = value.replacingOccurrences(of: "Mobile Release Sync", with: "Mobile Release", options: .caseInsensitive)
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? title : value
    }
}

private struct TimelineNormalItemCard: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let title: String
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: item.systemImageName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.icon)
                    .frame(width: 28, height: 28)
                    .background(palette.fill.opacity(0.92), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(timelineTitleColor(for: row, item: item))
                        .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(2)

                    Text(timeText)
                        .font(.lifeboard(.caption1).weight(.medium))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.source == .task {
                    ZStack {
                        Circle()
                            .stroke(timelineRingColor(for: row, palette: palette).opacity(0.75), lineWidth: 2.5)
                        if item.isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(timelineRingColor(for: row, palette: palette))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.lifeboard.surfacePrimary.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.78))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.58), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : item.source == .calendarEvent ? "Calendar event" : "Scheduled"))
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    private var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}

enum TimelineTaskMarkerLayout {
    static let iconCenterYOffset: CGFloat = 26
}

private struct TimelineTaskMarkerRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let isEmphasized: Bool
    let spineIconCenterX: CGFloat
    let completionX: CGFloat
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    static let iconCenterYOffset: CGFloat = TimelineTaskMarkerLayout.iconCenterYOffset

    private let iconContainer: CGFloat = 24
    private let iconSize: CGFloat = 18
    private let textLeadingOffset: CGFloat = 30
    private let visibleCompletionSize: CGFloat = 24
    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if isEmphasized {
                                Image(systemName: item.taskPriority == .max ? "exclamationmark.triangle.fill" : "flag.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(palette.icon)
                                    .accessibilityHidden(true)
                            }
                            Text(item.title)
                                .font(.lifeboard(.headline).weight(isEmphasized ? .bold : .semibold))
                                .foregroundStyle(timelineTitleColor(for: row, item: item))
                                .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(2)
                        }

                        Text(timeText)
                            .font(.lifeboard(.caption1).weight(.medium))
                            .foregroundStyle(timelineMetaColor(for: row))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: spineIconCenterX + textLeadingOffset, y: 5)

            Circle()
                .fill(markerFill)
                .frame(width: iconContainer, height: iconContainer)
                .overlay {
                    Image(systemName: item.systemImageName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(markerIconColor)
                        .accessibilityHidden(true)
                }
                .overlay {
                    Circle()
                        .stroke(markerStroke, lineWidth: isEmphasized ? 1.5 : 1)
                }
                .offset(
                    x: spineIconCenterX - (iconContainer / 2),
                    y: Self.iconCenterYOffset - (iconContainer / 2)
                )
                .accessibilityHidden(true)

            TimelineCompletionRing(
                color: timelineRingColor(for: row, palette: palette),
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete()
            }
            .scaleEffect(visibleCompletionSize / 28)
            .frame(width: 44, height: 44)
            .offset(x: completionX - 22, y: 6)
        }
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))
        .accessibilityHint("Opens the task details.")
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    private var markerFill: Color {
        if row.temporalState == .currentTask {
            return palette.progress
        }
        if isEmphasized {
            return palette.fill.opacity(0.98)
        }
        return Color.lifeboard.surfacePrimary.opacity(0.96)
    }

    private var markerIconColor: Color {
        row.temporalState == .currentTask ? Color.white.opacity(0.96) : palette.icon
    }

    private var markerStroke: Color {
        isEmphasized ? palette.progress.opacity(0.8) : palette.halo.opacity(0.58)
    }

    private var timeText: String {
        guard let start = item.startDate else { return "All day" }
        guard let end = item.endDate else {
            return start.formatted(date: .omitted, time: .shortened)
        }
        return TimelineFormatting.timeRangeText(start: start, end: end)
    }
}

private struct TimelineFlockBlock: View {
    let model: TimelineFlockModel
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var accent: Color {
        if let item = model.rows.first(where: { $0.item != nil })?.item {
            return TimelinePalette.resolve(from: item.tintHex).progress
        }
        return Color.lifeboard.accentPrimary
    }

    var body: some View {
        let fallbackItem = model.rows.compactMap(\.item).first

        VStack(alignment: .leading, spacing: 6) {
            header

            VStack(alignment: .leading, spacing: TimelineFlockModel.rowSpacing) {
                ForEach(model.rows) { row in
                    TimelineFlockRowView(
                        row: row,
                        visualHeight: model.rowVisualHeight,
                        renderRow: row.item.map { presentation.row(for: $0) },
                        onTap: {
                            guard let item = row.item ?? fallbackItem else { return }
                            onTaskTap(item)
                        },
                        onToggleComplete: {
                            guard let item = row.item, item.source == .task else { return }
                            onToggleComplete(item)
                        }
                    )
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.54), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
        .zIndex(3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate)), \(model.countLabel)")
        .accessibilityIdentifier("home.timeline.flockBlock")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(TimelineFormatting.timeRangeText(start: model.startDate, end: model.endDate))
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 6)

            Text(model.countLabel)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(accent.opacity(0.16), in: Capsule())
        }
        .frame(height: 24)
    }
}

private struct TimelineFlockRowView: View {
    let row: TimelineFlockModel.Row
    let visualHeight: CGFloat
    let renderRow: TimelineRenderableRow?
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    private var item: TimelinePlanItem? { row.item }
    private var palette: TimelinePalette { .resolve(from: item?.tintHex) }

    var body: some View {
        Button(action: onTap) {
            rowContent
                .frame(maxWidth: .infinity, minHeight: visualHeight, maxHeight: visualHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let item {
                Button("Open", action: onTap)
                if item.source == .task {
                    Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(row.isSummary ? "Opens the full list." : "Opens the item details.")
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            if row.isSummary {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: item?.systemImageName ?? "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.icon)
                    .frame(width: 24, height: 24)
                    .background(palette.fill.opacity(0.9), in: Circle())
                    .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)

                    trailingStatus
                        .layoutPriority(1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(row.isCompleted, color: titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    trailingStatus
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if row.isActiveNow {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.lifeboard.statusDanger)
                    .frame(width: 5, height: 5)
                Text("Now")
                    .font(.lifeboard(.meta).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.statusDanger)
            }
            .lineLimit(1)
        } else if row.timeText.isEmpty == false {
            Text(row.timeText)
                .font(.lifeboard(.meta).weight(.medium))
                .foregroundStyle(metaColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private var rowBackground: Color {
        if row.isActiveNow {
            return Color.lifeboard.statusDanger.opacity(0.10)
        }
        return Color.lifeboard.surfacePrimary.opacity(row.isSummary ? 0.42 : 0.72)
    }

    private var titleColor: Color {
        guard let renderRow else {
            return row.isSummary ? Color.lifeboard.textSecondary : Color.lifeboard.textPrimary
        }
        return timelineTitleColor(for: renderRow, item: item)
    }

    private var metaColor: Color {
        guard let renderRow else { return TimelineVisualTokens.metaText }
        return timelineMetaColor(for: renderRow)
    }

    private var accessibilityLabel: String {
        if row.isSummary { return row.title }
        guard let item, let renderRow else { return row.title }
        return timelineAccessibilityLabel(for: renderRow, item: item)
    }

    private var accessibilityValue: String {
        if row.isSummary { return "" }
        if row.isCompleted { return "Completed" }
        if row.isActiveNow { return "Now" }
        return item?.source == .calendarEvent ? "Calendar event" : "Scheduled"
    }
}

private struct TimelineOverlapClusterCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 12
            let laneGap = TimelineTimeBlock.laneGap
            let laneCount = max(block.visualLaneCount, 1)
            let laneWidth = max(
                (proxy.size.width - (horizontalPadding * 2) - (CGFloat(laneCount - 1) * laneGap)) / CGFloat(laneCount),
                56
            )
            let titles = TimelineDenseTitleFormatter.displayTitles(for: block.items)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary.opacity(0.94))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(clusterAccent.opacity(0.82))
                    .frame(width: 4)
                    .padding(.vertical, 3)

                header
                    .padding(.leading, horizontalPadding + 4)
                    .padding(.trailing, horizontalPadding)
                    .padding(.top, 10)

                ForEach(block.lanePlacements) { placement in
                    TimelineOverlapItemCard(
                        placement: placement,
                        row: presentation.row(for: placement.item),
                        title: titles[placement.item.id] ?? placement.item.title,
                        densityMode: block.densityMode,
                        onTap: { onTaskTap(placement.item) },
                        onToggleComplete: {
                            guard placement.item.source == .task else { return }
                            onToggleComplete(placement.item)
                        }
                    )
                    .frame(width: laneWidth, height: placement.height)
                    .offset(
                        x: horizontalPadding + CGFloat(placement.laneIndex) * (laneWidth + laneGap),
                        y: TimelineTimeBlock.clusterHeaderHeight + placement.relativeY
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.compressed ? "Compressed overlap" : "Overlap"), \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.overlapCluster")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if block.compressed {
                    Label("Compressed", systemImage: "rectangle.compress.vertical")
                        .font(.lifeboard(.meta).weight(.medium))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Text(block.countLabel.lowercased())
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(clusterAccent.opacity(0.18), in: Capsule())
        }
    }

    private var clusterAccent: Color {
        if block.containsTask && block.containsCalendarEvent {
            return Color.lifeboard.accentPrimary
        }
        if let tintHex = block.items.first?.tintHex {
            return Color(uiColor: UIColor(lifeboardHex: tintHex))
        }
        return Color.lifeboard.accentPrimary
    }
}

private struct TimelineOverlapItemCard: View {
    let placement: TimelineTimeBlock.LanePlacement
    let row: TimelineRenderableRow
    let title: String
    let densityMode: TimelineTimeBlock.DensityMode
    let onTap: () -> Void
    let onToggleComplete: () -> Void

    private var item: TimelinePlanItem { placement.item }
    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var iconSize: CGFloat {
        switch densityMode {
        case .dualLane:
            return 22
        case .compactLane:
            return 18
        case .microLane, .densePacked:
            return 16
        case .normal:
            return 22
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: densityMode == .dualLane ? 7 : 5) {
                Image(systemName: item.systemImageName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(palette.icon)
                    .frame(width: iconSize + 8, height: iconSize + 8)
                    .background(palette.fill.opacity(0.9), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: densityMode == .dualLane ? 3 : 2) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(timelineTitleColor(for: row, item: item))
                        .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(timeText)
                        .font(.lifeboard(.meta).weight(.medium))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, densityMode == .dualLane ? 8 : 6)
            .padding(.vertical, densityMode == .dualLane ? 7 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.72))
                    .frame(width: 3)
                    .padding(.vertical, 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.6), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", action: onTap)
            if item.source == .task {
                Button(item.isComplete ? "Mark Incomplete" : "Mark Complete", action: onToggleComplete)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
        .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : item.source == .calendarEvent ? "Calendar event" : "Scheduled"))
        .accessibilityHint("Opens the item details.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
        .accessibilityAction(named: Text("Open")) {
            onTap()
        }
        .accessibilityAction(named: Text(item.isComplete ? "Mark Incomplete" : "Mark Complete")) {
            guard item.source == .task else { return }
            onToggleComplete()
        }
    }

    private var titleFont: Font {
        switch densityMode {
        case .dualLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .compactLane:
            return .lifeboard(.caption1).weight(.semibold)
        case .microLane, .densePacked:
            return .lifeboard(.meta).weight(.semibold)
        case .normal:
            return .lifeboard(.caption1).weight(.semibold)
        }
    }

    private var timeText: String {
        guard let start = item.startDate else { return "All day" }
        if densityMode == .dualLane, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return start.formatted(date: .omitted, time: .shortened)
    }
}

private struct TimelineTimeBlockCard: View {
    let block: TimelineTimeBlock
    let presentation: TimelineDayPresentation
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Time Block Conflict: \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate))")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text(block.countLabel)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentOnPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.lifeboard.accentPrimary.opacity(0.82), in: Capsule())
            }

            VStack(spacing: 10) {
                ForEach(block.items) { item in
                    if item.source == .calendarEvent {
                        TimelineMeetingBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            isNested: true,
                            action: { onTaskTap(item) }
                        )
                    } else {
                        TimelineTaskBlockRow(
                            item: item,
                            row: presentation.row(for: item),
                            onTaskTap: onTaskTap,
                            onToggleComplete: onToggleComplete
                        )
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.92))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.lifeboard.accentPrimary.opacity(0.82))
                .frame(width: 4)
                .padding(.vertical, 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.76), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Time block conflict, \(TimelineFormatting.timeRangeText(start: block.startDate, end: block.endDate)), \(block.countLabel)")
        .accessibilityIdentifier("home.timeline.conflictBlock")
    }
}

private struct TimelineTaskBlockRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TimelineCapsule(item: item, row: row, palette: palette)
                .frame(width: 42, height: 58)
                .accessibilityHidden(true)

            Button {
                onTaskTap(item)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TASK")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(TimelineItemVisuals.accessoryColor(for: item, isActive: row.temporalState == .currentTask))
                        .lineLimit(1)

                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(timelineTitleColor(for: row, item: item))
                        .strikethrough(item.isComplete, color: timelineTitleColor(for: row, item: item))
                        .lineLimit(2)

                    Text(timelineMetaText(for: row, item: item))
                        .font(.lifeboard(.support))
                        .foregroundStyle(timelineMetaColor(for: row))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timelineAccessibilityLabel(for: row, item: item))
            .accessibilityValue(item.isComplete ? "Completed" : (row.temporalState == .currentTask ? "In progress" : "Scheduled"))

            TimelineCompletionRing(
                color: timelineRingColor(for: row, palette: palette),
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
            .frame(width: 34, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.lifeboard.surfacePrimary.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.62), lineWidth: 1)
        }
    }
}

private struct TimelineMeetingBlockRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let isNested: Bool
    let action: () -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var accessibilityKind: String { item.isMeetingLike ? "Meeting" : "Calendar" }
    private var iconName: String { item.isMeetingLike ? "person.3.fill" : "calendar" }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: isNested ? 10 : 11) {
                Circle()
                    .fill(palette.fill.opacity(0.92))
                    .frame(width: isNested ? 34 : 38, height: isNested ? 34 : 38)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: isNested ? 14 : 15, weight: .semibold))
                            .foregroundStyle(palette.icon)
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(2)

                    Text(meetingMetadata)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .layoutPriority(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, isNested ? 10 : 11)
            .padding(.vertical, isNested ? 8 : 9)
            .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.78))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.68), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(meetingMetadata)")
        .accessibilityValue(accessibilityKind)
        .accessibilityHint("Opens the calendar item.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
    }

    private var meetingMetadata: String {
        if let start = item.startDate, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return ""
    }
}

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

    private let plan: TimelineCanvasLayoutPlan
    private let stablePresentation: TimelineDayStablePresentation
    @State private var isCanvasDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

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
    private func canvasBody(now: Date) -> some View {
        let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let railMetrics = TimelineRailMetrics.make(for: layoutClass, surfaceMetrics: metrics, totalWidth: totalWidth)
            let trailingLaneWidth = metrics.expandedTrailingLaneWidth
            let contentInset = metrics.expandedContentInset
            let labelRightX = railMetrics.labelLeadingX + railMetrics.labelWidth + railMetrics.timeToSpineGap
            let streamLane = TimelineStreamGeometry.laneMetrics(
                totalWidth: totalWidth,
                labelRightX: labelRightX,
                trailingReservedWidth: trailingLaneWidth + contentInset,
                layoutClass: layoutClass
            )
            let spineCenterX = streamLane.centerX
            let contentX = streamLane.contentX
            let contentWidth = max(totalWidth - contentX - trailingLaneWidth - contentInset, 140)
            let completionX = totalWidth - (trailingLaneWidth / 2)
            let currentY = currentBoundaryY(now: now)
            let streamGeometry = TimelineStreamGeometry.make(
                plan: plan,
                baseX: spineCenterX,
                laneHalfWidth: max(streamLane.halfWidth - 4, 1)
            )

            ZStack(alignment: .topLeading) {
                timeLabelLayer(
                    presentation: presentation,
                    railMetrics: railMetrics,
                    currentY: currentY
                )
                .zIndex(4)

                CurvingDayStreamView(
                    geometry: streamGeometry,
                    currentY: currentY
                )
                    .frame(width: totalWidth, height: plan.contentHeight)
                    .zIndex(1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                ForEach(plan.longGapIndicators) { indicator in
                    TimelineLongGapIndicator(text: indicator.text)
                        .frame(width: contentWidth, height: indicator.height)
                        .offset(x: contentX, y: indicator.y)
                    .zIndex(3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                ForEach(plan.visualElements) { positioned in
                    visualElementView(
                        positioned,
                        presentation: presentation,
                        totalWidth: totalWidth,
                        contentX: contentX,
                        contentWidth: contentWidth,
                        streamGeometry: streamGeometry,
                        completionX: completionX,
                        currentY: currentY
                    )
                }

                if let currentY {
                    TimelineNowBeadView(
                        time: now,
                        railMetrics: railMetrics,
                        beadX: streamGeometry.x(atY: currentY),
                        reduceMotion: reduceMotion
                    )
                    .offset(x: 0, y: TimelineNowBeadPresentation.clampedY(currentY, contentHeight: plan.contentHeight))
                    .zIndex(5)
                }

                TimelineEndAddMarker(
                    suggestedDate: plan.endMarker.suggestedDate,
                    accessibilityValue: plan.endMarker.accessibilityValue
                ) {
                    onAddTask(plan.endMarker.suggestedDate)
                }
                .offset(
                    x: TimelineSpineMounting.centerX(for: streamGeometry, atY: plan.endMarker.centerY)
                        - (TimelineCanvasLayoutPlan.endMarkerHitArea / 2),
                    y: plan.endMarker.centerY - (TimelineCanvasLayoutPlan.endMarkerHitArea / 2)
                )
                .zIndex(3)
            }
        }
        .frame(height: plan.contentHeight)
        .overlay(alignment: .top) {
            if placementCandidate != nil {
                HStack(spacing: 8) {
                    Image(systemName: isCanvasDropTargeted ? "clock.badge.checkmark.fill" : "clock.badge")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isCanvasDropTargeted ? "Release to schedule" : "Drop on a time")
                        .font(.lifeboard(.caption1).weight(.semibold))
                }
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.lifeboard.accentWash.opacity(isCanvasDropTargeted ? 0.92 : 0.72), in: Capsule())
                .overlay(Capsule().stroke(Color.lifeboard.accentPrimary.opacity(isCanvasDropTargeted ? 0.42 : 0.18), lineWidth: 1))
                .scaleEffect(isCanvasDropTargeted && reduceMotion == false ? 1.035 : 1)
                .padding(.top, 8)
                .accessibilityIdentifier("home.needsReplan.hotZone.timeline")
            }
        }
        .dropDestination(for: String.self, action: { items, location in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            LifeBoardFeedback.success()
            onPlaceReplanAtTime(placementCandidate, plan.date(atY: location.y))
            return true
        }, isTargeted: { newValue in
            isCanvasDropTargeted = newValue
        })
        .onChange(of: isCanvasDropTargeted) { _, newValue in
            guard newValue else { return }
            LifeBoardFeedback.selection()
        }
    }

    private func displayedNow(from timelineDate: Date) -> Date {
        Calendar.current.isDate(projection.date, inSameDayAs: timelineDate) ? timelineDate : projection.currentTime
    }

    private func currentBoundaryY(now: Date) -> CGFloat? {
        plan.currentTimeY(now: now, selectedDate: projection.date)
    }

    private func timeLabelLayer(
        presentation: TimelineDayPresentation,
        railMetrics: TimelineRailMetrics,
        currentY: CGFloat?
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.visualElements) { positioned in
                railLabelView(
                    for: positioned,
                    presentation: presentation,
                    railMetrics: railMetrics,
                    currentY: currentY
                )
            }
        }
        .frame(width: railMetrics.labelLayerWidth, height: plan.contentHeight, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func railLabelView(
        for positioned: TimelineCanvasLayoutPlan.PositionedVisualTimelineElement,
        presentation: TimelineDayPresentation,
        railMetrics: TimelineRailMetrics,
        currentY: CGFloat?
    ) -> some View {
        switch positioned.element {
        case .routineMarker:
            EmptyView()
        case .meetingCard(let model), .taskMarker(let model), .taskCard(let model):
            let row = presentation.row(for: model.item)
            TimelineRailLabel(
                text: timeLabel(for: model.item),
                kind: railLabelKind(for: model.item),
                isEmphasized: row.isCurrentRailEmphasis,
                color: row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText,
                metrics: railMetrics
            )
            .offset(y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)
        case .flock(let model):
            let primaryItem = model.block.items.first
            let row = primaryItem.map { presentation.row(for: $0) }
            TimelineRailLabel(
                text: TimelineRailTimeFormatter.railText(forItemStart: model.block.startDate),
                kind: railLabelKind(for: model.block.startDate),
                isEmphasized: row?.isCurrentRailEmphasis == true,
                color: row?.isCurrentRailEmphasis == true ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText,
                metrics: railMetrics
            )
            .offset(y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)
        case .gapPrompt, .emptyState:
            EmptyView()
        }
    }

    @ViewBuilder
    private func visualElementView(
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
                totalWidth: totalWidth
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

    @ViewBuilder
    private func anchorView(
        _ anchor: TimelineCanvasLayoutPlan.PositionedAnchor,
        row: TimelineRenderableRow,
        streamGeometry: TimelineStreamGeometry,
        totalWidth: CGFloat
    ) -> some View {
        let iconSize = metrics.expandedAnchorCircleSize
        let anchorCenterY = anchor.y
        let iconTop = max(anchorCenterY - (iconSize / 2), 0)
        let railMetrics = TimelineRailMetrics.make(for: layoutClass, surfaceMetrics: metrics, totalWidth: totalWidth)
        let mountedSpineX = TimelineSpineMounting.centerX(for: streamGeometry, atY: anchorCenterY)

        Circle()
            .fill(TimelineVisualTokens.anchorCapsuleFill)
            .frame(width: iconSize, height: iconSize)
            .overlay {
                Image(systemName: anchor.anchor.systemImageName)
                    .font(.system(size: metrics.expandedAnchorIconSize, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .accessibilityHidden(true)
            }
            .offset(x: mountedSpineX - (iconSize / 2), y: iconTop)
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
            Text(anchor.anchor.title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
            Text(TimelineRoutineTextFormatter.subtitle(for: anchor.anchor, subtitle: row.subtitle))
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .offset(
            x: railMetrics.routineTextLeadingX(iconSize: iconSize, mountedSpineX: mountedSpineX),
            y: max(anchorCenterY - 22, 0)
        )
        .accessibilityHidden(true)

        Button {
            onAnchorTap(anchor.anchor)
        } label: {
            Color.clear
                .frame(width: totalWidth, height: max(iconSize, 52))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 0, y: max(anchorCenterY - max(iconSize, 52) / 2, 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.anchor.title), \(anchor.anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityValue(anchor.anchor.id == "wake" ? "Timeline start" : "Timeline end")
        .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
    }

    private func timelineStem(
        row: TimelineRenderableRow,
        item: TimelinePlanItem,
        spineCenterX: CGFloat,
        y: CGFloat,
        height: CGFloat
    ) -> some View {
        TimelineStemSegments(
            leading: row.stemLeading,
            trailing: row.stemTrailing,
            fallbackPalette: TimelinePalette.resolve(from: item.tintHex),
            width: 2,
            height: height
        )
        .offset(x: spineCenterX - 1, y: y)
        .accessibilityHidden(true)
    }

    private func timeLabelView(
        text: String,
        row: TimelineRenderableRow,
        timeGutterWidth: CGFloat,
        y: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        Text(text)
            .font(.system(size: 13, weight: row.isCurrentRailEmphasis ? .semibold : .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(y - 2, 0))
            .opacity(shouldHideTimeLabel(at: y, currentY: currentY) ? 0 : 1)
    }

    @ViewBuilder
    private func timelineBlockView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedBlock,
        presentation: TimelineDayPresentation,
        timeGutterWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        spineCenterX: CGFloat,
        completionX: CGFloat,
        currentY: CGFloat?
    ) -> some View {
        switch positioned.block.kind {
        case .single(let item):
            let row = presentation.row(for: item)
            let title = TimelineDenseTitleFormatter.displayTitles(for: [item])[item.id] ?? item.title
            TimelineStemSegments(
                leading: row.stemLeading,
                trailing: row.stemTrailing,
                fallbackPalette: TimelinePalette.resolve(from: item.tintHex),
                width: 2,
                height: positioned.height
            )
            .offset(x: spineCenterX - 1, y: positioned.y)
            .accessibilityHidden(true)

            Text(timeLabel(for: item))
                .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                .monospacedDigit()
                .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: timeGutterWidth - 8, alignment: .trailing)
                .offset(x: 0, y: max(positioned.y - 2, 0))
                .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

            TimelineNormalItemCard(
                item: item,
                row: row,
                title: title,
                onTap: { onTaskTap(item) },
                onToggleComplete: {
                    guard item.source == .task else { return }
                    onToggleComplete(item)
                }
            )
            .frame(width: contentWidth, height: min(max(positioned.height, 64), 84), alignment: .leading)
            .offset(x: contentX, y: positioned.y)
        case .conflict:
            let primaryItem = positioned.block.items.first
            TimelineStemSegments(
                leading: primaryItem.map { presentation.row(for: $0).stemLeading } ?? .futureSegment,
                trailing: primaryItem.map { presentation.row(for: $0).stemTrailing } ?? .futureSegment,
                fallbackPalette: TimelinePalette.resolve(from: primaryItem?.tintHex),
                width: 2,
                height: positioned.height
            )
            .offset(x: spineCenterX - 1, y: positioned.y)
            .accessibilityHidden(true)

            Text(positioned.block.startDate.formatted(date: .omitted, time: .shortened))
                .font(.lifeboard(.meta).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(TimelineVisualTokens.metaText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: timeGutterWidth - 8, alignment: .trailing)
                .offset(x: 0, y: max(positioned.y - 2, 0))
                .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

            TimelineFlockBlock(
                model: TimelineFlockModel(block: positioned.block, now: presentation.now),
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
            .frame(width: contentWidth, height: positioned.height, alignment: .leading)
            .offset(x: contentX, y: positioned.y)
            .zIndex(3)
        }
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
        completionX: CGFloat,
        currentY: CGFloat?
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
            .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
            .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(positioned.y - 2, 0))
            .opacity(shouldHideTimeLabel(at: positioned.y, currentY: currentY) ? 0 : 1)

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

    private func shouldHideTimeLabel(at labelY: CGFloat, currentY: CGFloat?) -> Bool {
        guard let currentY else { return false }
        return abs(labelY - currentY) < 16
    }

    @ViewBuilder
    private func timelineItemTextContent(row: TimelineRenderableRow, item: TimelinePlanItem, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metaText(for: row, item: item))
                .font(.lifeboard(row.temporalState == .currentTask && isExpanded ? .callout : .meta).weight(row.temporalState == .currentTask ? .semibold : .medium))
                .foregroundStyle(metaColor(for: row, item: item))
                .multilineTextAlignment(.leading)
                .lineLimit(1)

            Text(item.title)
                .font(.lifeboard(isExpanded && row.temporalState == .currentTask ? .title3 : .headline))
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
        return TimelineRailTimeFormatter.railText(forItemStart: start)
    }

    private func railLabelKind(for item: TimelinePlanItem) -> TimelineRailLabelKind {
        guard let start = item.startDate else { return .exact }
        return railLabelKind(for: start)
    }

    private func railLabelKind(for date: Date) -> TimelineRailLabelKind {
        Calendar.current.component(.minute, from: date) == 0 ? .compactHour : .exact
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
            return Color.lifeboard.textTertiary.opacity(0.72)
        case .pastIncomplete:
            return Color.lifeboard.statusWarning.opacity(0.92)
        case .currentTask:
            return Color.lifeboard.textPrimary.opacity(0.92)
        default:
            return TimelineVisualTokens.metaText
        }
    }

    private func titleColor(for row: TimelineRenderableRow, item: TimelinePlanItem) -> Color {
        switch row.temporalState {
        case .pastCompleted:
            return Color.lifeboard.textSecondary.opacity(0.72)
        case .pastIncomplete:
            return Color.lifeboard.textPrimary.opacity(0.92)
        case .currentTask:
            return Color.lifeboard.textPrimary
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
    let layoutClass: LifeBoardLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onAddTask: (Date?) -> Void
    let onScheduleInbox: () -> Void

    private let plan: TimelineCompactLayoutPlan
    private let stablePresentation: TimelineDayStablePresentation
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

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
    private func rowView(for entry: TimelineCompactLayoutPlan.Entry, presentation: TimelineDayPresentation) -> some View {
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
    let layoutClass: LifeBoardLayoutClass
    let onTap: () -> Void

    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
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

private struct TimelineCompactItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let capsuleHeight: CGFloat
    let layoutClass: LifeBoardLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

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

private struct TimelineCompactGapRow: View {
    let gap: TimelineGap
    let row: TimelineRenderableRow
    let layoutClass: LifeBoardLayoutClass
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
                    .font(row.isCurrentRailEmphasis ? .lifeboard(.meta).weight(.semibold) : .lifeboard(.meta))
                    .foregroundStyle(row.isCurrentRailEmphasis ? Color.lifeboard.textPrimary : TimelineVisualTokens.metaText.opacity(0.92))
                    .frame(width: metrics.compactTimeGutter, alignment: .trailing)

                Color.clear
                    .frame(width: metrics.compactTimeToLaneGap)

                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(.system(size: 14, weight: .semibold))
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

private struct DailyTimelineAgendaView: View {
    let projection: TimelineDayProjection
    let layoutClass: LifeBoardLayoutClass
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onAddTask: (Date?) -> Void
    let onScheduleInbox: () -> Void
    private let stablePresentation: TimelineDayStablePresentation

    private enum Entry: Identifiable {
        case anchor(TimelineAnchorItem)
        case gap(TimelineGap)
        case block(TimelineTimeBlock)

        var id: String {
            switch self {
            case .anchor(let anchor):
                return "anchor:\(anchor.id)"
            case .gap(let gap):
                return "gap:\(gap.id)"
            case .block(let block):
                return "block:\(block.id)"
            }
        }
    }

    private var entries: [Entry] {
        let beforeWakeBlocks = agendaBlocks(from: projection.beforeWakeItems)
        let blocks = agendaBlocks(from: projection.timedItems)
        let afterSleepBlocks = agendaBlocks(from: projection.afterSleepItems)
        let gaps = projection.actionableGaps.sorted { $0.startDate < $1.startDate }
        var blockIndex = 0
        var gapIndex = 0
        var result = beforeWakeBlocks.map(Entry.block)
        result.append(.anchor(projection.wakeAnchor))

        while blockIndex < blocks.count || gapIndex < gaps.count {
            if blockIndex >= blocks.count {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
                continue
            }
            if gapIndex >= gaps.count {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
                continue
            }
            if gaps[gapIndex].startDate <= blocks[blockIndex].startDate {
                result.append(.gap(gaps[gapIndex]))
                gapIndex += 1
            } else {
                result.append(.block(blocks[blockIndex]))
                blockIndex += 1
            }
        }

        result.append(.anchor(projection.sleepAnchor))
        result.append(contentsOf: afterSleepBlocks.map(Entry.block))
        return result
    }

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
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timelineDisplayedNow(for: projection, timelineDate: timeline.date)
            let presentation = TimelineDayPresentation(stable: stablePresentation, now: now)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(entries) { entry in
                    switch entry {
                    case .anchor(let anchor):
                        TimelineAgendaAnchorRow(
                            anchor: anchor,
                            row: presentation.row(for: anchor),
                            onTap: { onAnchorTap(anchor) }
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .gap(let gap):
                        let suggestedDate = timelineSuggestedAddDate(for: gap, now: presentation.now)
                        TimelineGapPrompt(
                            gap: gap,
                            row: presentation.row(for: gap),
                            suggestedDate: suggestedDate,
                            onAddTask: { onAddTask(suggestedDate) },
                            onPlanBlock: onScheduleInbox
                        )
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    case .block(let block):
                        agendaBlockView(block, presentation: presentation)
                            .environment(\.lifeboardLayoutClass, layoutClass)
                    }
                }
            }
        }
    }

    private func agendaBlocks(from items: [TimelinePlanItem]) -> [TimelineTimeBlock] {
        let dayStart = Calendar.current.startOfDay(for: projection.date)
        return TimelineTimeBlock.make(from: items.compactMap { item in
            guard let startDate = item.startDate, let endDate = item.endDate else { return nil }
            let startMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: startDate).minute ?? 0)
            let endMinute = CGFloat(Calendar.current.dateComponents([.minute], from: dayStart, to: endDate).minute ?? 0)
            return TimelineTimeBlock.Input(
                item: item,
                startDate: startDate,
                endDate: endDate,
                startMinute: startMinute,
                endMinute: max(endMinute, startMinute + 1),
                y: 0,
                height: 0
            )
        })
    }

    @ViewBuilder
    private func agendaBlockView(
        _ block: TimelineTimeBlock,
        presentation: TimelineDayPresentation
    ) -> some View {
        switch block.kind {
        case .single(let item):
            TimelineAgendaItemRow(
                item: item,
                row: presentation.row(for: item),
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        case .conflict:
            TimelineTimeBlockCard(
                block: block,
                presentation: presentation,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
        }
    }
}

private struct TimelineAgendaAnchorRow: View {
    let anchor: TimelineAnchorItem
    let row: TimelineRenderableRow
    let onTap: () -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(TimelineVisualTokens.anchorCapsuleFill)
                    .frame(width: metrics.agendaAnchorCircleSize, height: metrics.agendaAnchorCircleSize)
                    .overlay {
                        Image(systemName: anchor.systemImageName)
                            .font(.system(size: metrics.agendaAnchorIconSize, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .accessibilityHidden(true)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(anchor.time.formatted(date: .omitted, time: .shortened))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text(anchor.title)
                        .font(.lifeboard(.title3))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    if let subtitle = row.subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(TimelineVisualTokens.utilityText)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityHint(TimelineAnchorSelection(anchorID: anchor.id)?.accessibilityHint ?? "Edit timeline anchor time")
    }
}

private struct TimelineAgendaItemRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }
    private var metrics: TimelineSurfaceMetrics { .make(for: layoutClass) }

    var body: some View {
        if item.source == .calendarEvent {
            TimelineMeetingBlockRow(
                item: item,
                row: row,
                isNested: false,
                action: { onTaskTap(item) }
            )
            .padding(.vertical, 10)
        } else {
            HStack(alignment: .top, spacing: 14) {
                TimelineCapsule(item: item, row: row, palette: palette)
                    .frame(width: metrics.agendaCapsuleWidth, height: 88)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(timelineMetaText(for: row, item: item))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(timelineMetaColor(for: row))
                    Button {
                        onTaskTap(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.lifeboard(row.temporalState == .currentTask ? .title3 : .headline))
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
                    isInteractive: true,
                    label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
                ) {
                    onToggleComplete(item)
                }
            }
            .padding(.vertical, 10)
        }
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
                .font(.lifeboard(.caption1))
                .foregroundStyle(TimelineVisualTokens.utilityText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.lifeboard.surfaceSecondary, in: Capsule())
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
                .font(.lifeboard(.caption1))
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
    @Environment(\.lifeboardLayoutClass) private var layoutClass

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
    let suggestedDate: Date
    let onAddTask: () -> Void
    let onPlanBlock: () -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .accessibilityHidden(true)
                timelineGapPromptText(for: gap, row: row)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Add task", systemImage: "plus", action: onAddTask)
            .buttonStyle(.plain)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(Color.lifeboard.textSecondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.lifeboard.surfaceSecondary.opacity(0.58), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.56), lineWidth: 1)
            }
            .contentShape(Capsule())
            .accessibilityLabel("Add task at \(suggestedDate.formatted(date: .omitted, time: .shortened))")
            .accessibilityHint("Opens Add Task with this timeline time.")
            .accessibilityIdentifier("home.timeline.gap.createTask")

            Menu {
                Button(TimelineGapAction.planBlock.title, action: onPlanBlock)
                Button(TimelineGapAction.dismiss.title, role: .destructive) {}
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(TimelineVisualTokens.utilityText)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Open time options")
        }
        .padding(.vertical, layoutClass.isPad ? 6 : 8)
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

    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var paletteColor: Color {
        switch day.loadLevel {
        case .light:
            return Color.lifeboard.statusSuccess
        case .balanced:
            return Color.lifeboard.accentPrimary
        case .busy:
            return Color.lifeboard.statusWarning
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
                        .font(.lifeboard(.support).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color.lifeboard.accentWash.opacity(0.72), in: Capsule())
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
                .fill(isDropTargeted ? Color.lifeboard.accentWash.opacity(0.86) : (isSelected ? Color.lifeboard.surfacePrimary : Color.lifeboard.surfacePrimary.opacity(0.85)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isDropTargeted ? Color.lifeboard.accentPrimary.opacity(0.48) : (isSelected ? Color.lifeboard.accentPrimary.opacity(0.25) : Color.lifeboard.strokeHairline.opacity(0.45)), lineWidth: isDropTargeted ? 1.5 : 1)
        )
        .overlay(alignment: .bottom) {
            if placementCandidate != nil {
                Label(isDropTargeted ? "Release" : "Drop", systemImage: isDropTargeted ? "calendar.badge.checkmark" : "calendar.badge.plus")
                    .font(.lifeboard(.caption2).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.88), in: Capsule())
                    .opacity(isDropTargeted ? 1 : 0.72)
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("home.needsReplan.hotZone.day.\(day.id)")
            }
        }
        .scaleEffect(isDropTargeted && reduceMotion == false ? 1.018 : 1)
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
        .dropDestination(for: String.self, action: { items, _ in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            LifeBoardFeedback.success()
            onDropPlacement(placementCandidate)
            return true
        }, isTargeted: { newValue in
            isDropTargeted = newValue
        })
        .onChange(of: isDropTargeted) { _, newValue in
            guard newValue else { return }
            LifeBoardFeedback.selection()
        }
    }

    private var dayContent: some View {
        VStack(spacing: isAccessibilityLayout ? 8 : 6) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                        .frame(width: 44, height: 44)
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.lifeboard(.headline))
                        .foregroundStyle(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                }

                Text(day.summaryText)
                    .font(.lifeboard(isAccessibilityLayout ? .caption1 : .meta).weight(.semibold))
                    .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : paletteColor)
                    .lineLimit(isAccessibilityLayout ? 2 : 1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    ForEach(Array(day.tintHexes.prefix(3).enumerated()), id: \.offset) { entry in
                        Circle()
                            .fill(Color(uiColor: UIColor(lifeboardHex: entry.element)).opacity(0.88))
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    if day.allDayCount > 0 {
                        Text("\(day.allDayCount)")
                            .font(.lifeboard(.caption2).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lifeboard.surfaceSecondary, in: Capsule())
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
