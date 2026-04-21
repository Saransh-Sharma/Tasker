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
        let roundedMinutes = Int((rawMinutes / 15).rounded() * 15)
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
        anchorHeight: CGFloat = 62,
        itemHeight: CGFloat = 78,
        gapHeight: CGFloat = 90,
        connectorHeight: CGFloat = 12,
        topInset: CGFloat = 4,
        bottomInset: CGFloat = 12
    ) {
        self.connectorHeight = connectorHeight
        self.topInset = topInset
        self.bottomInset = bottomInset

        let sortedItems = projection.timedItems.sorted {
            ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
        }
        let sortedGaps = projection.gaps.sorted { $0.startDate < $1.startDate }

        var itemIndex = 0
        var gapIndex = 0
        var resolvedEntries: [Entry] = [
            .anchor(.init(anchor: projection.wakeAnchor, rowHeight: anchorHeight))
        ]

        while itemIndex < sortedItems.count || gapIndex < sortedGaps.count {
            if itemIndex >= sortedItems.count {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: gapHeight)))
                gapIndex += 1
                continue
            }
            if gapIndex >= sortedGaps.count {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: itemHeight))
                itemIndex += 1
                continue
            }

            if sortedGaps[gapIndex].startDate <= (sortedItems[itemIndex].startDate ?? .distantFuture) {
                resolvedEntries.append(.gap(.init(gap: sortedGaps[gapIndex], rowHeight: gapHeight)))
                gapIndex += 1
            } else {
                resolvedEntries.append(Self.itemEntry(for: sortedItems[itemIndex], minimumRowHeight: itemHeight))
                itemIndex += 1
            }
        }

        resolvedEntries.append(.anchor(.init(anchor: projection.sleepAnchor, rowHeight: anchorHeight)))
        self.entries = resolvedEntries
    }

    var contentHeight: CGFloat {
        let rowsHeight = entries.reduce(CGFloat.zero) { $0 + $1.rowHeight }
        let connectorsHeight = CGFloat(max(entries.count - 1, 0)) * connectorHeight
        return topInset + rowsHeight + connectorsHeight + bottomInset
    }

    private static func itemEntry(for item: TimelinePlanItem, minimumRowHeight: CGFloat) -> Entry {
        let capsuleHeight = compactCapsuleHeight(for: item.duration)
        return .item(.init(
            item: item,
            rowHeight: max(minimumRowHeight, capsuleHeight + 20),
            capsuleHeight: capsuleHeight
        ))
    }

    private static func compactCapsuleHeight(for duration: TimeInterval?) -> CGFloat {
        let minutes = max(1, CGFloat((duration ?? 30 * 60) / 60))
        if minutes <= 15 {
            return 56
        }
        if minutes <= 30 {
            return 56 + ((minutes - 15) / 15) * 8
        }
        if minutes <= 90 {
            return 64 + ((minutes - 30) / 60) * 48
        }
        return min(132, 112 + ((minutes - 90) / 60) * 20)
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

struct TimelineRailPresentationSpec: Equatable {
    let lineWidth: CGFloat
    let opacity: Double
    let isDashed: Bool

    static let compactConnector = TimelineRailPresentationSpec(
        lineWidth: 2,
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

            if dynamicTypeSize.isAccessibilitySize {
                DailyTimelineAgendaView(
                    projection: snapshot.day,
                    onTaskTap: onTaskTap,
                    onToggleComplete: onToggleComplete,
                    onAddTask: onAddTask,
                    onScheduleInbox: onScheduleInbox
                )
            } else {
                switch snapshot.day.layoutMode {
                case .compact:
                    DailyTimelineCompactView(
                        projection: snapshot.day,
                        onTaskTap: onTaskTap,
                        onToggleComplete: onToggleComplete,
                        onAddTask: onAddTask,
                        onScheduleInbox: onScheduleInbox
                    )
                case .expanded:
                    DailyTimelineCanvas(
                        projection: snapshot.day,
                        placementCandidate: snapshot.placementCandidate,
                        onTaskTap: onTaskTap,
                        onToggleComplete: onToggleComplete,
                        onAddTask: onAddTask,
                        onScheduleInbox: onScheduleInbox,
                        onPlaceReplanAtTime: onPlaceReplanAtTime
                    )
                }
            }

            if let candidate = snapshot.placementCandidate {
                TimelinePlacementDock(candidate: candidate)
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.top, showsRevealHandle ? spacing.s8 : 0)
        .padding(.bottom, spacing.s20)
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
    let placementCandidate: TimelinePlacementCandidate?
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void
    let onPlaceReplanAtTime: (TimelinePlacementCandidate, Date) -> Void

    @ScaledMetric(relativeTo: .body) private var timeGutterWidth: CGFloat = 70
    @ScaledMetric(relativeTo: .body) private var spineLaneWidth: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var trailingLaneWidth: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var contentInset: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var capsuleMinWidth: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var timeToSpineGap: CGFloat = 12

    private let plan: TimelineCanvasLayoutPlan

    init(
        projection: TimelineDayProjection,
        placementCandidate: TimelinePlacementCandidate?,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAddTask: @escaping () -> Void,
        onScheduleInbox: @escaping () -> Void,
        onPlaceReplanAtTime: @escaping (TimelinePlacementCandidate, Date) -> Void
    ) {
        self.projection = projection
        self.placementCandidate = placementCandidate
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.onPlaceReplanAtTime = onPlaceReplanAtTime
        self.plan = TimelineCanvasLayoutPlan(projection: projection)
    }

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let spineCenterX = timeGutterWidth + timeToSpineGap + (spineLaneWidth / 2)
            let contentX = timeGutterWidth + timeToSpineGap + spineLaneWidth + contentInset
            let contentWidth = max(totalWidth - contentX - trailingLaneWidth - contentInset, 140)
            let completionX = totalWidth - (trailingLaneWidth / 2)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.tasker.strokeHairline.opacity(0.46))
                    .frame(width: 2, height: plan.contentHeight)
                    .offset(x: spineCenterX - 1)
                    .accessibilityHidden(true)

                ForEach(plan.gaps) { gap in
                    TimelineGapPrompt(gap: gap.gap, onAddTask: onAddTask, onScheduleInbox: onScheduleInbox)
                        .frame(width: contentWidth, alignment: .leading)
                        .offset(
                            x: contentX,
                            y: gap.startY + min(max(14, gap.height * 0.18), max(gap.height - 72, 14))
                        )
                }

                anchorView(plan.wakeAnchor, spineCenterX: spineCenterX, contentX: contentX, completionX: completionX)

                ForEach(plan.items) { positioned in
                    let columnSpacing: CGFloat = 10
                    let widthForColumns = max(contentWidth - CGFloat(max(positioned.columnCount - 1, 0)) * columnSpacing, capsuleMinWidth)
                    let columnWidth = widthForColumns / CGFloat(positioned.columnCount)
                    let itemX = contentX + CGFloat(positioned.columnIndex) * (columnWidth + columnSpacing)

                    timelineItemView(
                        positioned,
                        itemX: itemX,
                        itemWidth: columnWidth,
                        contentX: contentX,
                        contentWidth: contentWidth,
                        spineCenterX: spineCenterX,
                        completionX: completionX
                    )
                }

                anchorView(plan.sleepAnchor, spineCenterX: spineCenterX, contentX: contentX, completionX: completionX)
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

    @ViewBuilder
    private func anchorView(
        _ anchor: TimelineCanvasLayoutPlan.PositionedAnchor,
        spineCenterX: CGFloat,
        contentX: CGFloat,
        completionX: CGFloat
    ) -> some View {
        let iconSize: CGFloat = 70
        let anchorCenterY = anchor.y
        let iconTop = max(anchorCenterY - (iconSize / 2), 0)

        Text(anchor.anchor.time.formatted(date: .omitted, time: .shortened))
            .font(.tasker(.meta))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(anchorCenterY - 12, 0))

        Circle()
            .fill(Color.tasker.surfaceSecondary)
            .frame(width: iconSize, height: iconSize)
            .overlay {
                Image(systemName: anchor.anchor.systemImageName)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .accessibilityHidden(true)
            }
            .offset(x: spineCenterX - (iconSize / 2), y: iconTop)
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
            Text(anchor.anchor.title)
                .font(.tasker(.title3))
                .foregroundStyle(Color.tasker.textPrimary)
            Text(anchor.anchor.id == "wake" ? "Start shaping your day on the timeline." : "Let the rest of the day taper out.")
                .font(.tasker(.support))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .offset(x: contentX, y: max(anchorCenterY - 22, 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.anchor.title), \(anchor.anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityValue(anchor.anchor.id == "wake" ? "Timeline start" : "Timeline end")

        Circle()
            .stroke(Color.tasker.textQuaternary.opacity(0.32), lineWidth: 2)
            .frame(width: 30, height: 30)
            .frame(width: 44, height: 44)
            .offset(x: completionX - 22, y: max(anchorCenterY - 22, 0))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func timelineItemView(
        _ positioned: TimelineCanvasLayoutPlan.PositionedItem,
        itemX: CGFloat,
        itemWidth: CGFloat,
        contentX: CGFloat,
        contentWidth: CGFloat,
        spineCenterX: CGFloat,
        completionX: CGFloat
    ) -> some View {
        let item = positioned.item
        let isActive = item.isActive(at: projection.currentTime)
        let palette = TimelinePalette.resolve(from: item.tintHex)
        let capsuleWidth = max(min(itemWidth * 0.24, 62), capsuleMinWidth)
        let overlapCapsuleOffset = CGFloat(positioned.columnIndex) * min(itemWidth * 0.18, 18)
        let capsuleX = spineCenterX - (capsuleWidth / 2) + overlapCapsuleOffset
        let textX = max(itemX, capsuleX + capsuleWidth + 14)
        let textWidth = max(min((itemX + itemWidth) - textX, contentWidth + contentX - textX), 84)

        Text(timeLabel(for: item))
            .font(isActive ? .tasker(.meta).weight(.semibold) : .tasker(.meta))
            .foregroundStyle(isActive ? Color.tasker.textPrimary : Color.tasker.textSecondary)
            .frame(width: timeGutterWidth - 8, alignment: .trailing)
            .offset(x: 0, y: max(positioned.y - 2, 0))

        TimelineCapsule(item: item, currentTime: projection.currentTime, palette: palette)
            .frame(width: capsuleWidth, height: positioned.height)
            .offset(x: capsuleX, y: positioned.y)

        Button {
            onTaskTap(item)
        } label: {
            timelineItemTextContent(item, isActive: isActive)
                .frame(width: textWidth, alignment: .leading)
                .frame(minHeight: positioned.height, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: textX, y: positioned.y)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityValue(item.isComplete ? "Completed" : (isActive ? "In progress" : "Scheduled"))
        .accessibilityHint("Opens the task details.")

        TimelineCompletionRing(
            color: palette.ring,
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
    private func timelineItemTextContent(_ item: TimelinePlanItem, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metaText(for: item))
                .font(.tasker(.meta))
                .foregroundStyle(TimelineItemVisuals.metaColor(for: item))
                .multilineTextAlignment(.leading)

            Text(item.title)
                .font(.tasker(isActive ? .title3 : .headline))
                .foregroundStyle(TimelineItemVisuals.titleColor(for: item))
                .strikethrough(item.isComplete, color: TimelineItemVisuals.titleColor(for: item))
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if let accessory = item.accessoryText, accessory.isEmpty == false {
                Text(accessory)
                    .font(.tasker(.support))
                    .foregroundStyle(TimelineItemVisuals.accessoryColor(for: item, isActive: isActive))
                    .lineLimit(1)
            }
        }
    }

    private func timeLabel(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate else { return "All day" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    private func metaText(for item: TimelinePlanItem) -> String {
        guard let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened)) (\(durationText))"
    }

    private func accessibilityLabel(for item: TimelinePlanItem) -> String {
        var parts = [item.title]
        parts.append(metaText(for: item))
        if let accessory = item.accessoryText, accessory.isEmpty == false {
            parts.append(accessory)
        }
        return parts.joined(separator: ", ")
    }
}

private struct DailyTimelineCompactView: View {
    let projection: TimelineDayProjection
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    @ScaledMetric(relativeTo: .body) private var timeGutterWidth: CGFloat = 68
    @ScaledMetric(relativeTo: .body) private var laneWidth: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var trailingLaneWidth: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var timeToLaneGap: CGFloat = 12

    private let plan: TimelineCompactLayoutPlan

    init(
        projection: TimelineDayProjection,
        onTaskTap: @escaping (TimelinePlanItem) -> Void,
        onToggleComplete: @escaping (TimelinePlanItem) -> Void,
        onAddTask: @escaping () -> Void,
        onScheduleInbox: @escaping () -> Void
    ) {
        self.projection = projection
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onAddTask = onAddTask
        self.onScheduleInbox = onScheduleInbox
        self.plan = TimelineCompactLayoutPlan(projection: projection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.entries.indices, id: \.self) { index in
                rowView(for: plan.entries[index])

                if index < plan.entries.count - 1 {
                    connector
                }
            }
        }
        .padding(.top, plan.topInset)
        .padding(.bottom, plan.bottomInset)
        .frame(minHeight: plan.contentHeight, alignment: .top)
    }

    @ViewBuilder
    private func rowView(for entry: TimelineCompactLayoutPlan.Entry) -> some View {
        switch entry {
        case .anchor(let anchor):
            TimelineCompactAnchorRow(
                anchor: anchor.anchor,
                timeGutterWidth: timeGutterWidth,
                timeToLaneGap: timeToLaneGap,
                laneWidth: laneWidth,
                trailingLaneWidth: trailingLaneWidth
            )
            .frame(minHeight: anchor.rowHeight, alignment: .center)
        case .item(let item):
            TimelineCompactItemRow(
                item: item.item,
                currentTime: projection.currentTime,
                capsuleHeight: item.capsuleHeight,
                timeGutterWidth: timeGutterWidth,
                timeToLaneGap: timeToLaneGap,
                laneWidth: laneWidth,
                trailingLaneWidth: trailingLaneWidth,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete
            )
            .frame(minHeight: item.rowHeight, alignment: .center)
        case .gap(let gap):
            TimelineCompactGapRow(
                gap: gap.gap,
                timeGutterWidth: timeGutterWidth,
                timeToLaneGap: timeToLaneGap,
                laneWidth: laneWidth,
                onAddTask: onAddTask,
                onScheduleInbox: onScheduleInbox
            )
            .frame(minHeight: gap.rowHeight, alignment: .center)
        }
    }

    private var connector: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: timeGutterWidth + timeToLaneGap, height: plan.connectorHeight)

            TimelineCompactConnector(laneWidth: laneWidth, height: plan.connectorHeight)

            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
}

private struct TimelineCompactAnchorRow: View {
    let anchor: TimelineAnchorItem
    let timeGutterWidth: CGFloat
    let timeToLaneGap: CGFloat
    let laneWidth: CGFloat
    let trailingLaneWidth: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(anchor.time.formatted(date: .omitted, time: .shortened))
                .font(.tasker(.meta))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: timeGutterWidth, alignment: .trailing)

            Color.clear
                .frame(width: timeToLaneGap)

            Circle()
                .fill(Color.tasker.surfaceSecondary)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: anchor.systemImageName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(width: laneWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(anchor.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text(anchor.id == "wake" ? "Start shaping your day." : "Let the day taper out.")
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            Spacer(minLength: 12)

            Circle()
                .stroke(Color.tasker.textQuaternary.opacity(0.3), lineWidth: 2)
                .frame(width: 28, height: 28)
                .frame(width: trailingLaneWidth, alignment: .center)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityValue(anchor.id == "wake" ? "Timeline start" : "Timeline end")
    }
}

private struct TimelineCompactItemRow: View {
    let item: TimelinePlanItem
    let currentTime: Date
    let capsuleHeight: CGFloat
    let timeGutterWidth: CGFloat
    let timeToLaneGap: CGFloat
    let laneWidth: CGFloat
    let trailingLaneWidth: CGFloat
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(timeText)
                .font(.tasker(.meta))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: timeGutterWidth, alignment: .trailing)

            Color.clear
                .frame(width: timeToLaneGap)

            TimelineCapsule(item: item, currentTime: currentTime, palette: palette)
                .frame(width: 42, height: capsuleHeight)
                .frame(width: laneWidth)
                .accessibilityHidden(true)

            Button {
                onTaskTap(item)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metaText)
                        .font(.tasker(.meta))
                        .foregroundStyle(TimelineItemVisuals.metaColor(for: item))
                    Text(item.title)
                        .font(.tasker(item.isActive(at: currentTime) ? .headline : .callout).weight(.semibold))
                        .foregroundStyle(TimelineItemVisuals.titleColor(for: item))
                        .strikethrough(item.isComplete, color: TimelineItemVisuals.titleColor(for: item))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if let accessory = item.accessoryText, accessory.isEmpty == false {
                        Text(accessory)
                            .font(.tasker(.support))
                            .foregroundStyle(TimelineItemVisuals.accessoryColor(for: item, isActive: item.isActive(at: currentTime)))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.title), \(metaText)")
            .accessibilityValue(item.isComplete ? "Completed" : (item.isActive(at: currentTime) ? "In progress" : "Scheduled"))
            .accessibilityHint("Opens the task details.")

            TimelineCompletionRing(
                color: palette.ring,
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
            .frame(width: trailingLaneWidth, alignment: .center)
        }
    }

    private var timeText: String {
        guard let start = item.startDate else { return "All day" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    private var metaText: String {
        guard let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened)) (\(durationText))"
    }
}

private struct TimelineCompactGapRow: View {
    let gap: TimelineGap
    let timeGutterWidth: CGFloat
    let timeToLaneGap: CGFloat
    let laneWidth: CGFloat
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    private var emphasisColor: Color {
        switch gap.emphasis {
        case .openTime:
            return Color.tasker.accentPrimary
        case .prepWindow:
            return Color.tasker.statusWarning
        case .quietWindow:
            return Color.tasker.statusSuccess
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(gap.startDate.formatted(date: .omitted, time: .shortened))
                .font(.tasker(.meta))
                .foregroundStyle(Color.tasker.textSecondary.opacity(0.82))
                .frame(width: timeGutterWidth, alignment: .trailing)

            Color.clear
                .frame(width: timeToLaneGap)

            Image(systemName: gap.compactIconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: laneWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(gap.compactDurationText)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(emphasisColor)
                    Text(gap.compactSupportingText)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                TimelineGapActionButton(
                    title: gap.primaryAction.title,
                    isPrimary: true,
                    tint: emphasisColor
                ) {
                    perform(gap.primaryAction)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private func perform(_ action: TimelineGapAction) {
        switch action {
        case .addTask:
            onAddTask()
        case .scheduleInbox:
            onScheduleInbox()
        }
    }
}

private struct TimelineCompactConnector: View {
    let laneWidth: CGFloat
    let height: CGFloat
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
        }
        .frame(width: laneWidth, height: height)
    }
}

private struct DailyTimelineAgendaView: View {
    let projection: TimelineDayProjection
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
        VStack(alignment: .leading, spacing: 16) {
            ForEach(entries) { entry in
                switch entry {
                case .anchor(let anchor):
                    TimelineAgendaAnchorRow(anchor: anchor)
                case .gap(let gap):
                    TimelineGapPrompt(gap: gap, onAddTask: onAddTask, onScheduleInbox: onScheduleInbox)
                case .item(let item):
                    TimelineAgendaItemRow(item: item, currentTime: projection.currentTime, onTaskTap: onTaskTap, onToggleComplete: onToggleComplete)
                }
            }
        }
    }
}

private struct TimelineAgendaAnchorRow: View {
    let anchor: TimelineAnchorItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.tasker.surfaceSecondary)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: anchor.systemImageName)
                        .font(.system(size: 18, weight: .semibold))
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
                Text(anchor.id == "wake" ? "Start shaping your day." : "Close the day without forcing more tasks in.")
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(anchor.title), \(anchor.time.formatted(date: .omitted, time: .shortened))")
    }
}

private struct TimelineAgendaItemRow: View {
    let item: TimelinePlanItem
    let currentTime: Date
    let onTaskTap: (TimelinePlanItem) -> Void
    let onToggleComplete: (TimelinePlanItem) -> Void

    private var palette: TimelinePalette { .resolve(from: item.tintHex) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TimelineCapsule(item: item, currentTime: currentTime, palette: palette)
                .frame(width: 56, height: 88)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(metaText)
                    .font(.tasker(.meta))
                    .foregroundStyle(TimelineItemVisuals.metaColor(for: item))
                Button {
                    onTaskTap(item)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.tasker(item.isActive(at: currentTime) ? .title3 : .headline))
                            .foregroundStyle(TimelineItemVisuals.titleColor(for: item))
                            .strikethrough(item.isComplete, color: TimelineItemVisuals.titleColor(for: item))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        if let accessory = item.accessoryText, accessory.isEmpty == false {
                            Text(accessory)
                                .font(.tasker(.support))
                                .foregroundStyle(TimelineItemVisuals.accessoryColor(for: item, isActive: item.isActive(at: currentTime)))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.title), \(metaText)")
                .accessibilityValue(item.isComplete ? "Completed" : (item.isActive(at: currentTime) ? "In progress" : "Scheduled"))
                .accessibilityHint("Opens the task details.")
            }

            TimelineCompletionRing(
                color: palette.ring,
                isCompleted: item.isComplete,
                isInteractive: item.source == .task,
                label: item.isComplete ? "\(item.title) completed" : "Mark \(item.title) complete"
            ) {
                onToggleComplete(item)
            }
        }
        .padding(.vertical, 10)
    }

    private var metaText: String {
        guard let start = item.startDate, let end = item.endDate else { return "All day" }
        let durationText = TimelineFormatting.durationText(max(0, end.timeIntervalSince(start)))
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened)) (\(durationText))"
    }
}

private struct TimelineCapsule: View {
    let item: TimelinePlanItem
    let currentTime: Date
    let palette: TimelinePalette

    var body: some View {
        GeometryReader { proxy in
            let progress = itemProgress
            let fillColor = item.isComplete ? palette.fill.opacity(0.54) : palette.fill
            let progressColor = item.isComplete ? palette.progress.opacity(0.42) : palette.progress
            let iconColor = item.isComplete ? palette.icon.opacity(0.52) : palette.icon
            let haloColor = item.isComplete ? palette.halo.opacity(0.58) : palette.halo

            ZStack {
                RoundedRectangle(cornerRadius: proxy.size.width / 2, style: .continuous)
                    .fill(fillColor)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if progress > 0 {
                        RoundedRectangle(cornerRadius: proxy.size.width / 2, style: .continuous)
                            .fill(progressColor)
                            .frame(height: proxy.size.height * progress)
                    }
                }
                Image(systemName: item.systemImageName)
                    .font(.system(size: proxy.size.width > 52 ? 20 : 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: proxy.size.width / 2, style: .continuous)
                    .stroke(haloColor, lineWidth: 1)
            }
        }
    }

    private var itemProgress: CGFloat {
        guard item.isActive(at: currentTime),
              let start = item.startDate,
              let end = item.endDate
        else { return 0 }
        let total = max(end.timeIntervalSince(start), 1)
        let elapsed = max(0, min(currentTime.timeIntervalSince(start), total))
        return CGFloat(elapsed / total)
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
    let onAddTask: () -> Void
    let onScheduleInbox: () -> Void

    private var emphasisColor: Color {
        switch gap.emphasis {
        case .openTime:
            return Color.tasker.accentPrimary
        case .prepWindow:
            return Color.tasker.statusWarning
        case .quietWindow:
            return Color.tasker.statusSuccess
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: gap.emphasis == .quietWindow ? "moon.zzz" : "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .accessibilityHidden(true)
                Text(gap.compactDurationText)
                    .font(.tasker(.callout).weight(.semibold))
                    .foregroundStyle(emphasisColor)
                Text(gap.supportingText)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                TimelineGapActionButton(
                    title: gap.primaryAction.title,
                    isPrimary: true,
                    tint: emphasisColor
                ) {
                    perform(gap.primaryAction)
                }

                if let secondaryAction = gap.secondaryAction {
                    TimelineGapActionButton(
                        title: secondaryAction.title,
                        isPrimary: false,
                        tint: emphasisColor
                    ) {
                        perform(secondaryAction)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    private func perform(_ action: TimelineGapAction) {
        switch action {
        case .addTask:
            onAddTask()
        case .scheduleInbox:
            onScheduleInbox()
        }
    }
}

private struct TimelineGapActionButton: View {
    let title: String
    let isPrimary: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.tasker(.buttonSmall))
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                Group {
                    if isPrimary {
                        Capsule().fill(tint.opacity(0.12))
                    } else {
                        Capsule().stroke(tint.opacity(0.28), lineWidth: 1)
                    }
                }
            )
            .frame(minHeight: 44)
    }
}

private extension TimelineGap {
    var compactDurationText: String {
        TimelineFormatting.durationText(duration)
    }

    var compactSupportingText: String {
        switch emphasis {
        case .openTime:
            return "A canvas for ideas."
        case .prepWindow:
            return "Room for one focused block."
        case .quietWindow:
            return "Leave space to wind down."
        }
    }

    var compactIconName: String {
        switch emphasis {
        case .quietWindow:
            return "moon.zzz"
        case .openTime, .prepWindow:
            return "clock"
        }
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
                    Label("Replan \(day.replanEligibleCount)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.tasker(.support).weight(.semibold))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color.tasker.accentWash.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Replan \(day.replanEligibleCount) tasks")
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
                Button("Replan \(day.replanEligibleCount) tasks", systemImage: "arrow.triangle.2.circlepath") {
                    onStartReplan()
                }
            }
        }
        .accessibilityAction(named: Text("Replan \(day.replanEligibleCount) tasks")) {
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
}
