import SwiftUI

// What day is being shown, how it relates to today, and the week
// backdrop behind it.

// MARK: - TimelineDayCurrentState

struct TimelineDayCurrentState {
    let now: Date
    let dayRelation: TimelineDayRelation
    let currentBoundaryDate: Date?
    let currentTintHex: String?
    let activeGapID: String?

    init(stable: TimelineDayStablePresentation, now: Date) {
        let interval = PerformanceTrace.begin("HomeTimelineCurrentStateBuild")
        defer { PerformanceTrace.end(interval) }
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

// MARK: - TimelineDayPresentation

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

// MARK: - TimelineDayRelation

enum TimelineDayRelation {
    case past
    case today
    case future
}

// MARK: - TimelineDayStablePresentation

struct TimelineDayStablePresentation {
    let projection: TimelineDayProjection
    let calendar: Calendar

    init(projection: TimelineDayProjection, calendar: Calendar = .current) {
        let interval = PerformanceTrace.begin("HomeTimelineStablePresentationBuild")
        defer { PerformanceTrace.end(interval) }
        self.projection = projection
        self.calendar = calendar
    }
}

// MARK: - TimelineBackdropWeekView

struct TimelineBackdropWeekView: View {
    let snapshot: HomeTimelineSnapshot
    let onSelectDate: (Date) -> Void
    let onStartReplanForDate: (Date) -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

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

// MARK: - TimelineWeekDayCell

struct TimelineWeekDayCell: View {
    let day: TimelineWeekDaySummary
    let isSelected: Bool
    let isAccessibilityLayout: Bool
    let action: () -> Void
    let onStartReplan: () -> Void
    let placementCandidate: TimelinePlacementCandidate?
    let onDropPlacement: (TimelinePlacementCandidate) -> Void

    @State var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var paletteColor: Color {
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

    var dayContent: some View {
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

    var accessibilityLabel: String {
        let allDayText = day.allDayCount > 0 ? ", \(day.allDayCount) all-day items" : ""
        let replanText = day.replanEligibleCount > 0 ? ", \(day.replanEligibleCount) needs replan" : ""
        return "\(day.date.formatted(.dateTime.weekday(.wide).day().month())), \(day.summaryText)\(allDayText)\(replanText)"
    }

    var canStartReplan: Bool {
        let calendar = Calendar.current
        return day.replanEligibleCount > 0
            && calendar.startOfDay(for: day.date) < calendar.startOfDay(for: Date())
    }

    var replanActionTitle: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }

    var replanAccessibilityLabel: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }
}

// MARK: - TimelineBar

struct TimelineBar: View {


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
