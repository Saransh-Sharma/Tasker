import SwiftUI

enum LifeBoardCalendarTimelineDensity: Equatable {
    case compact
    case expanded
}

struct LifeBoardCalendarTimelineLayoutPlan: Equatable {
    struct PositionedEvent: Equatable, Identifiable {
        let event: LifeBoardCalendarEventSnapshot
        let lane: Int
        let laneCount: Int
        let columnSpan: Int
        let startMinute: Int
        let endMinute: Int

        var id: String { event.id }
    }

    let startMinute: Int
    let endMinute: Int
    let positionedEvents: [PositionedEvent]

    var startHour: Int { startMinute / 60 }

    var endHour: Int {
        let inclusiveEndMinute = max(startMinute, endMinute - 1)
        return max(startHour, inclusiveEndMinute / 60)
    }

    var hourMarkers: [Int] {
        Array(startHour...endHour)
    }
}

enum LifeBoardCalendarTimelinePlanner {
    static let defaultWorkdayStartHour = 8
    static let defaultWorkdayEndHour = 18
    private static let compactWindowDurationMinutes = 135

    private struct ClippedEvent {
        let event: LifeBoardCalendarEventSnapshot
        let startMinute: Int
        let endMinute: Int
    }

    static func makePlan(
        for events: [LifeBoardCalendarEventSnapshot],
        on date: Date,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> LifeBoardCalendarTimelineLayoutPlan? {
        makePlan(
            for: events,
            on: date,
            density: .compact,
            anchorDate: anchorDate,
            calendar: calendar
        )
    }

    static func makePlan(
        for events: [LifeBoardCalendarEventSnapshot],
        on date: Date,
        density: LifeBoardCalendarTimelineDensity,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> LifeBoardCalendarTimelineLayoutPlan? {
        let selectedDayEvents = events
            .filter { !$0.isAllDay && $0.isBusy }
            .compactMap { clip($0, to: date, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.startMinute != rhs.startMinute {
                    return lhs.startMinute < rhs.startMinute
                }
                return lhs.endMinute < rhs.endMinute
            }

        guard selectedDayEvents.isEmpty == false else { return nil }

        let visibleRange = visibleRange(
            for: selectedDayEvents,
            density: density,
            anchorDate: anchorDate,
            calendar: calendar
        )

        let visibleEvents = selectedDayEvents.compactMap { event in
            clip(event, visibleStartMinute: visibleRange.startMinute, visibleEndMinute: visibleRange.endMinute)
        }

        let clusters = overlapClusters(for: visibleEvents)
        let positionedEvents = clusters.flatMap { cluster -> [LifeBoardCalendarTimelineLayoutPlan.PositionedEvent] in
            var laneEndMinutes: [Int] = []
            var positionedCluster: [LifeBoardCalendarTimelineLayoutPlan.PositionedEvent] = []

            for event in cluster {
                if let reusableLane = laneEndMinutes.firstIndex(where: { $0 <= event.startMinute }) {
                    laneEndMinutes[reusableLane] = event.endMinute
                    positionedCluster.append(
                        LifeBoardCalendarTimelineLayoutPlan.PositionedEvent(
                            event: event.event,
                            lane: reusableLane,
                            laneCount: 0,
                            columnSpan: 1,
                            startMinute: event.startMinute,
                            endMinute: event.endMinute
                        )
                    )
                } else {
                    laneEndMinutes.append(event.endMinute)
                    positionedCluster.append(
                        LifeBoardCalendarTimelineLayoutPlan.PositionedEvent(
                            event: event.event,
                            lane: laneEndMinutes.count - 1,
                            laneCount: 0,
                            columnSpan: 1,
                            startMinute: event.startMinute,
                            endMinute: event.endMinute
                        )
                    )
                }
            }

            let laneCount = max(1, laneEndMinutes.count)
            return positionedCluster.map { positioned in
                let columnSpan = maxColumnSpan(
                    for: positioned,
                    in: positionedCluster,
                    laneCount: laneCount
                )
                return LifeBoardCalendarTimelineLayoutPlan.PositionedEvent(
                    event: positioned.event,
                    lane: positioned.lane,
                    laneCount: laneCount,
                    columnSpan: columnSpan,
                    startMinute: positioned.startMinute,
                    endMinute: positioned.endMinute
                )
            }
        }

        return LifeBoardCalendarTimelineLayoutPlan(
            startMinute: visibleRange.startMinute,
            endMinute: visibleRange.endMinute,
            positionedEvents: positionedEvents
        )
    }

    static func initialExpandedHour(
        for events: [LifeBoardCalendarEventSnapshot],
        on date: Date,
        anchorDate: Date = Date(),
        workdayStartHour: Int = defaultWorkdayStartHour,
        workdayEndHour: Int = defaultWorkdayEndHour,
        calendar: Calendar = .current
    ) -> Int {
        let selectedDayEvents = events
            .filter { !$0.isAllDay && $0.isBusy }
            .compactMap { clip($0, to: date, calendar: calendar) }
            .sorted { $0.startMinute < $1.startMinute }

        let isToday = calendar.isDate(anchorDate, inSameDayAs: date)
        let currentHour = isToday
            ? calendar.component(.hour, from: anchorDate)
            : calendar.component(.hour, from: date)
        let earliestHour = selectedDayEvents.map { $0.startMinute / 60 }.min()
        let nextOrLaterHour = selectedDayEvents
            .map { $0.startMinute / 60 }
            .filter { $0 >= currentHour }
            .min()

        guard isToday else {
            if let earliestHour {
                return min(23, max(0, earliestHour))
            }
            return workdayStartHour
        }

        if currentHour < workdayStartHour {
            if let earliestHour, earliestHour < workdayStartHour {
                return max(0, earliestHour)
            }
            return workdayStartHour
        }

        if currentHour <= workdayEndHour {
            return currentHour
        }

        if let nextOrLaterHour {
            return min(23, nextOrLaterHour)
        }

        return min(23, currentHour)
    }

    private static func visibleRange(
        for events: [ClippedEvent],
        density: LifeBoardCalendarTimelineDensity,
        anchorDate: Date,
        calendar: Calendar
    ) -> (startMinute: Int, endMinute: Int) {
        switch density {
        case .expanded:
            return (0, 24 * 60)
        case .compact:
            let anchorMinute = calendar.component(.hour, from: anchorDate) * 60
                + calendar.component(.minute, from: anchorDate)
            let defaultStart = max(0, anchorMinute - 60)
            let defaultEnd = min(24 * 60, defaultStart + compactWindowDurationMinutes)
            let defaultWindowContainsEvent = events.contains { event in
                event.endMinute > defaultStart && event.startMinute < defaultEnd
            }

            if defaultWindowContainsEvent {
                return alignedCompactWindow(startMinute: defaultStart)
            }

            if let nextEvent = events.first(where: { $0.startMinute >= anchorMinute }) {
                return alignedCompactWindow(startMinute: max(0, nextEvent.startMinute - 60))
            }

            if let lastEvent = events.last {
                return alignedCompactWindow(startMinute: max(0, lastEvent.startMinute - 60))
            }

            return alignedCompactWindow(startMinute: defaultStart)
        }
    }

    private static func alignedCompactWindow(startMinute: Int) -> (startMinute: Int, endMinute: Int) {
        let latestAllowedStartHour = Int(floor(Double((24 * 60) - compactWindowDurationMinutes) / 60.0))
        let roundedStartHour = max(0, min(latestAllowedStartHour, Int(floor(Double(startMinute) / 60.0))))
        let visibleStartMinute = roundedStartHour * 60
        let visibleEndMinute = min(24 * 60, visibleStartMinute + compactWindowDurationMinutes)
        return (visibleStartMinute, visibleEndMinute)
    }

    private static func overlapClusters(for events: [ClippedEvent]) -> [[ClippedEvent]] {
        var clusters: [[ClippedEvent]] = []
        var currentCluster: [ClippedEvent] = []
        var currentClusterEndMinute = 0

        for event in events {
            if currentCluster.isEmpty {
                currentCluster = [event]
                currentClusterEndMinute = event.endMinute
                continue
            }

            if event.startMinute < currentClusterEndMinute {
                currentCluster.append(event)
                currentClusterEndMinute = max(currentClusterEndMinute, event.endMinute)
            } else {
                clusters.append(currentCluster)
                currentCluster = [event]
                currentClusterEndMinute = event.endMinute
            }
        }

        if currentCluster.isEmpty == false {
            clusters.append(currentCluster)
        }

        return clusters
    }

    private static func maxColumnSpan(
        for event: LifeBoardCalendarTimelineLayoutPlan.PositionedEvent,
        in cluster: [LifeBoardCalendarTimelineLayoutPlan.PositionedEvent],
        laneCount: Int
    ) -> Int {
        guard laneCount > 1 else { return 1 }

        var span = 1

        for candidateLane in (event.lane + 1)..<laneCount {
            let hasOverlapInLane = cluster.contains { other in
                other.lane == candidateLane
                    && other.id != event.id
                    && intervalsOverlap(
                        lhsStart: event.startMinute,
                        lhsEnd: event.endMinute,
                        rhsStart: other.startMinute,
                        rhsEnd: other.endMinute
                    )
            }

            if hasOverlapInLane {
                break
            }

            span += 1
        }

        return span
    }

    private static func intervalsOverlap(
        lhsStart: Int,
        lhsEnd: Int,
        rhsStart: Int,
        rhsEnd: Int
    ) -> Bool {
        lhsStart < rhsEnd && rhsStart < lhsEnd
    }

    private static func clip(
        _ event: LifeBoardCalendarEventSnapshot,
        to date: Date,
        calendar: Calendar
    ) -> ClippedEvent? {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let clippedStart = max(event.startDate, dayStart)
        let clippedEnd = min(event.endDate, dayEnd)
        guard clippedEnd > clippedStart else { return nil }

        let startMinute = max(0, Int(clippedStart.timeIntervalSince(dayStart) / 60.0))
        let endMinute = min(24 * 60, max(startMinute + 1, Int(ceil(clippedEnd.timeIntervalSince(dayStart) / 60.0))))
        return ClippedEvent(event: event, startMinute: startMinute, endMinute: endMinute)
    }

    private static func clip(
        _ event: ClippedEvent,
        visibleStartMinute: Int,
        visibleEndMinute: Int
    ) -> ClippedEvent? {
        let clippedStart = max(event.startMinute, visibleStartMinute)
        let clippedEnd = min(event.endMinute, visibleEndMinute)
        guard clippedEnd > clippedStart else { return nil }

        return ClippedEvent(
            event: event.event,
            startMinute: clippedStart,
            endMinute: clippedEnd
        )
    }
}

typealias HomeDayTimelineLayoutPlanner = LifeBoardCalendarTimelinePlanner

enum LifeBoardCalendarTimelineVisibleWindowPolicy: Equatable {
    case fixed(anchorDate: Date)

    var anchorDate: Date {
        switch self {
        case .fixed(let anchorDate):
            return anchorDate
        }
    }

    static func fixedToCurrentMinute(_ date: Date = Date()) -> LifeBoardCalendarTimelineVisibleWindowPolicy {
        let minuteStamp = floor(date.timeIntervalSinceReferenceDate / 60.0) * 60.0
        return .fixed(anchorDate: Date(timeIntervalSinceReferenceDate: minuteStamp))
    }
}

struct LifeBoardCalendarTimelinePlanEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: LifeBoardCalendarEventAvailability
    let eventStatus: LifeBoardCalendarEventStatus
    let participationStatus: LifeBoardCalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: LifeBoardCalendarEventSnapshot) {
        id = event.id
        calendarID = event.calendarID
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        availability = event.availability
        eventStatus = event.eventStatus
        participationStatus = event.participationStatus
        lastModifiedAt = event.lastModifiedAt
    }
}

struct LifeBoardCalendarTimelinePlanCacheKey: Equatable {
    let date: Date
    let density: LifeBoardCalendarTimelineDensity
    let visibleWindowPolicy: LifeBoardCalendarTimelineVisibleWindowPolicy
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZone: TimeZone
    let events: [LifeBoardCalendarTimelinePlanEventSignature]

    init(
        events: [LifeBoardCalendarEventSnapshot],
        date: Date,
        density: LifeBoardCalendarTimelineDensity,
        visibleWindowPolicy: LifeBoardCalendarTimelineVisibleWindowPolicy,
        calendar: Calendar = .current
    ) {
        self.date = calendar.startOfDay(for: date)
        self.density = density
        self.visibleWindowPolicy = visibleWindowPolicy
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZone = calendar.timeZone
        self.events = events.map(LifeBoardCalendarTimelinePlanEventSignature.init)
    }
}

struct LifeBoardCalendarTimelinePlanCache {
    private var cachedKey: LifeBoardCalendarTimelinePlanCacheKey?
    private var cachedPlan: LifeBoardCalendarTimelineLayoutPlan?
    private(set) var buildCount = 0
    private(set) var cacheHitCount = 0

    mutating func plan(
        for events: [LifeBoardCalendarEventSnapshot],
        on date: Date,
        density: LifeBoardCalendarTimelineDensity,
        visibleWindowPolicy: LifeBoardCalendarTimelineVisibleWindowPolicy,
        calendar: Calendar = .current
    ) -> LifeBoardCalendarTimelineLayoutPlan? {
        let key = LifeBoardCalendarTimelinePlanCacheKey(
            events: events,
            date: date,
            density: density,
            visibleWindowPolicy: visibleWindowPolicy,
            calendar: calendar
        )

        if cachedKey == key {
            cacheHitCount += 1
            return cachedPlan
        }

        let plan = LifeBoardCalendarTimelinePlanner.makePlan(
            for: events,
            on: date,
            density: density,
            anchorDate: visibleWindowPolicy.anchorDate,
            calendar: calendar
        )
        cachedKey = key
        cachedPlan = plan
        buildCount += 1
        return plan
    }
}

struct LifeBoardCalendarTimelineView: View {
    let date: Date
    let events: [LifeBoardCalendarEventSnapshot]
    let density: LifeBoardCalendarTimelineDensity
    let showsDateLabel: Bool
    let emptyText: String
    let accessibilityIdentifier: String?
    let accessibilityLabelText: String?
    let initialVisibleHour: Int?
    let eventAccessibilityIdentifierPrefix: String
    let onSelectEvent: ((LifeBoardCalendarEventSnapshot) -> Void)?

    @State private var layoutPlanCache = LifeBoardCalendarTimelinePlanCache()
    @State private var layoutPlan: LifeBoardCalendarTimelineLayoutPlan?

    init(
        date: Date,
        events: [LifeBoardCalendarEventSnapshot],
        density: LifeBoardCalendarTimelineDensity = .compact,
        showsDateLabel: Bool = true,
        emptyText: String = "Nothing in this window",
        accessibilityIdentifier: String? = nil,
        accessibilityLabelText: String? = nil,
        initialVisibleHour: Int? = nil,
        eventAccessibilityIdentifierPrefix: String = "schedule.event",
        onSelectEvent: ((LifeBoardCalendarEventSnapshot) -> Void)? = nil
    ) {
        self.date = date
        self.events = events
        self.density = density
        self.showsDateLabel = showsDateLabel
        self.emptyText = emptyText
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabelText = accessibilityLabelText
        self.initialVisibleHour = initialVisibleHour
        self.eventAccessibilityIdentifierPrefix = eventAccessibilityIdentifierPrefix
        self.onSelectEvent = onSelectEvent
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            content(anchorDate: timeline.date)
                .task(id: LifeBoardCalendarTimelinePlanCacheKey(
                    events: events,
                    date: date,
                    density: density,
                    visibleWindowPolicy: .fixedToCurrentMinute(timeline.date)
                )) {
                    refreshLayoutPlan(anchorDate: timeline.date)
                }
        }
    }

    @ViewBuilder
    private func content(anchorDate: Date) -> some View {
        VStack(alignment: .leading, spacing: density == .compact ? 8 : 12) {
            if showsDateLabel {
                Text(LifeBoardCalendarPresentation.scheduleDateText(for: date))
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .accessibilityIdentifier(accessibilityIdentifier.map { "\($0).date" } ?? "calendar.timeline.date")
            }

            if let layoutPlan, layoutPlan.positionedEvents.isEmpty == false {
                timelineRows(for: layoutPlan, anchorDate: anchorDate)
            } else {
                Text(emptyText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, density == .compact ? 10 : 16)
                    .accessibilityIdentifier(accessibilityIdentifier.map { "\($0).empty" } ?? "calendar.timeline.empty")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "calendar.timeline")
        .accessibilityLabel(accessibilityLabelText ?? "Calendar timeline")
        .onAppear { refreshLayoutPlan(anchorDate: anchorDate) }
        .onChange(of: events) { refreshLayoutPlan(anchorDate: anchorDate) }
        .onChange(of: date) { refreshLayoutPlan(anchorDate: anchorDate) }
    }

    private func timelineRows(
        for plan: LifeBoardCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: density == .compact ? 6 : 8) {
            ForEach(plan.hourMarkers, id: \.self) { hour in
                let hourEvents = events(in: hour, plan: plan)
                HStack(alignment: .top, spacing: density == .compact ? 8 : 12) {
                    Text(hourLabel(hour))
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .frame(width: density == .compact ? 44 : 54, alignment: .trailing)

                    VStack(alignment: .leading, spacing: density == .compact ? 5 : 7) {
                        if calendarHour(anchorDate) == hour, Calendar.current.isDate(anchorDate, inSameDayAs: date) {
                            currentTimeMarker(anchorDate)
                        }

                        if hourEvents.isEmpty {
                            Rectangle()
                                .fill(Color.lifeboard.strokeHairline.opacity(0.45))
                                .frame(height: 1)
                                .padding(.vertical, density == .compact ? 8 : 12)
                        } else {
                            ForEach(hourEvents) { item in
                                eventButton(item.event)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func eventButton(_ event: LifeBoardCalendarEventSnapshot) -> some View {
        Button {
            onSelectEvent?(event)
        } label: {
            LifeBoardCalendarTimelineEventRow(event: event, density: density)
        }
        .buttonStyle(.plain)
        .disabled(onSelectEvent == nil)
        .accessibilityIdentifier("\(eventAccessibilityIdentifierPrefix).\(event.id)")
        .accessibilityLabel("\(event.title), \(LifeBoardCalendarPresentation.timeRangeText(for: event))")
    }

    private func currentTimeMarker(_ date: Date) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.lifeboard.accentPrimary)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.lifeboard.accentPrimary.opacity(0.42))
                .frame(height: 1)
            Text(date.formatted(date: .omitted, time: .shortened))
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.accentPrimary)
        }
        .accessibilityHidden(true)
    }

    private func refreshLayoutPlan(anchorDate: Date) {
        let policy = LifeBoardCalendarTimelineVisibleWindowPolicy.fixedToCurrentMinute(anchorDate)
        layoutPlan = layoutPlanCache.plan(
            for: events,
            on: date,
            density: density,
            visibleWindowPolicy: policy
        )
    }

    private func events(
        in hour: Int,
        plan: LifeBoardCalendarTimelineLayoutPlan
    ) -> [LifeBoardCalendarTimelineLayoutPlan.PositionedEvent] {
        let startMinute = hour * 60
        let endMinute = startMinute + 60
        return plan.positionedEvents.filter { item in
            item.startMinute < endMinute && item.endMinute > startMinute
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: date)
        return calendar.date(byAdding: components, to: reference)?
            .formatted(date: .omitted, time: .shortened)
            ?? "\(hour):00"
    }

    private func calendarHour(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

private struct LifeBoardCalendarTimelineEventRow: View {
    let event: LifeBoardCalendarEventSnapshot
    let density: LifeBoardCalendarTimelineDensity

    private var accentColor: Color {
        LifeBoardHexColor.color(event.calendarColorHex, fallback: Color.lifeboard.accentPrimary)
    }

    var body: some View {
        HStack(alignment: .top, spacing: density == .compact ? 8 : 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accentColor)
                .frame(width: event.isCanceled ? 4 : 3)

            VStack(alignment: .leading, spacing: density == .compact ? 2 : 4) {
                Text(event.title)
                    .font(density == .compact ? .lifeboard(.caption1) : .lifeboard(.bodyStrong))
                    .foregroundStyle(event.isCanceled ? Color.lifeboard.textSecondary : Color.lifeboard.textPrimary)
                    .strikethrough(event.isCanceled, color: Color.lifeboard.textSecondary)
                    .lineLimit(density == .compact ? 1 : 2)
                    .minimumScaleFactor(0.88)

                Text(LifeBoardCalendarPresentation.timeRangeText(for: event))
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)

                if density == .expanded, let supportingLine {
                    Text(supportingLine)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, density == .compact ? 8 : 10)
        .padding(.vertical, density == .compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: density == .compact ? 9 : 11, style: .continuous)
                .fill(event.isCanceled ? Color.lifeboard.surfaceSecondary.opacity(0.58) : accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: density == .compact ? 9 : 11, style: .continuous)
                .stroke(event.isCanceled ? Color.lifeboard.strokeHairline.opacity(0.6) : accentColor.opacity(0.28), lineWidth: 1)
        )
        .opacity(event.isCanceled ? 0.74 : 1)
    }

    private var supportingLine: String? {
        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), location.isEmpty == false {
            return location
        }
        return event.calendarTitle
    }
}
