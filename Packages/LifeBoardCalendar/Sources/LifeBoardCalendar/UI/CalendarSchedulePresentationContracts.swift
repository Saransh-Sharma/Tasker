import Foundation
import LifeBoardContracts
import LifeBoardDomain

public enum CalendarScheduleTab: String, CaseIterable, Identifiable {
    case today
    case week

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today:
            return String(localized: "Today")
        case .week:
            return String(localized: "Week")
        }
    }
}

public enum CalendarScheduleSheet: Identifiable, Equatable {
    case chooser
    case event(id: String)

    public var id: String {
        switch self {
        case .chooser:
            return "chooser"
        case .event(let id):
            return "event.\(id)"
        }
    }
}

public struct CalendarSchedulePresentationState: Equatable {
    public var activeSheet: CalendarScheduleSheet?

    public init(activeSheet: CalendarScheduleSheet? = nil) {
        self.activeSheet = activeSheet
    }

    public mutating func presentChooser() {
        activeSheet = .chooser
    }

    public mutating func cancelChooser() {
        if activeSheet == .chooser {
            activeSheet = nil
        }
    }

    public mutating func commitChooser() {
        if activeSheet == .chooser {
            activeSheet = nil
        }
    }

    public mutating func selectEvent(id: String) {
        activeSheet = .event(id: id)
    }

    public mutating func dismissEventDetail() {
        if case .event = activeSheet {
            activeSheet = nil
        }
    }
}

public enum CalendarSchedulePresentationMode {
    case modal
    case embedded
}

public struct CalendarSchedulePresentation: Equatable {
    public let selectedDate: Date
    public let selectedWeekDate: Date
    public let weekStartsOn: Weekday
    public let weekDefaultSelectedDate: Date
    public let currentWeekStart: Date
    public let weekRangeLabel: String
    public let todayEvents: [CalendarEventSnapshot]
    public let weekAgenda: [CalendarDayAgenda]
    public let weekDates: [Date]
    public let selectedWeekEvents: [CalendarEventSnapshot]

    public var weekEventCount: Int {
        weekAgenda.reduce(into: 0) { result, day in
            result += day.events.count
        }
    }
}

private struct CalendarScheduleEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: CalendarEventAvailability
    let eventStatus: CalendarEventStatus
    let participationStatus: CalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: CalendarEventSnapshot) {
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

private struct CalendarSchedulePresentationCacheKey: Equatable {
    let selectedDate: Date
    let selectedWeekDate: Date
    let weekStartsOn: Weekday
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZone: TimeZone
    let authorizationStatus: CalendarAuthorizationStatus
    let selectedCalendarIDs: [String]
    let includeDeclined: Bool
    let includeCanceled: Bool
    let includeAllDayInAgenda: Bool
    let events: [CalendarScheduleEventSignature]

    init(
        snapshot: CalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar
    ) {
        self.selectedDate = calendar.startOfDay(for: selectedDate)
        self.selectedWeekDate = calendar.startOfDay(for: selectedWeekDate)
        self.weekStartsOn = weekStartsOn
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZone = calendar.timeZone
        self.authorizationStatus = snapshot.authorizationStatus
        self.selectedCalendarIDs = snapshot.selectedCalendarIDs.sorted()
        self.includeDeclined = snapshot.includeDeclined
        self.includeCanceled = snapshot.includeCanceled
        self.includeAllDayInAgenda = snapshot.includeAllDayInAgenda
        self.events = snapshot.eventsInRange.map(CalendarScheduleEventSignature.init)
    }
}

public struct CalendarSchedulePresentationCache {
    private var cachedKey: CalendarSchedulePresentationCacheKey?
    private var cachedPresentation: CalendarSchedulePresentation?
    public private(set) var buildCount = 0
    public private(set) var cacheHitCount = 0

    public init() {}

    public mutating func presentation(
        snapshot: CalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        let key = CalendarSchedulePresentationCacheKey(
            snapshot: snapshot,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
        if let cachedKey, cachedKey == key, let cachedPresentation {
            cacheHitCount += 1
            return cachedPresentation
        }
        let presentation = CalendarSchedulePresentationBuilder.build(
            snapshot: snapshot,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
        cachedKey = key
        cachedPresentation = presentation
        buildCount += 1
        return presentation
    }
}

public enum CalendarSchedulePresentationBuilder {
    public static func empty(
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        build(
            snapshot: CalendarSnapshot.empty,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
    }

    public static func build(
        snapshot: CalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        let interval = PerformanceTrace.begin("CalendarScheduleProjectionBuild")
        defer { PerformanceTrace.end(interval) }

        let weekStart = XPCalculationService.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
        let weekDefaultSelectedDate = defaultSelectedWeekDate(
            selectedDate: selectedDate,
            weekDates: weekDates,
            calendar: calendar
        )
        let weekRangeLabel = rangeLabel(weekStart: weekStart, calendar: calendar)
        let weekAgenda = weekDates.map { day in
            let dayStart = calendar.startOfDay(for: day)
            return CalendarDayAgenda(
                date: dayStart,
                events: eventsForDay(dayStart, in: snapshot.eventsInRange, calendar: calendar)
            )
        }

        return CalendarSchedulePresentation(
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            weekDefaultSelectedDate: weekDefaultSelectedDate,
            currentWeekStart: weekStart,
            weekRangeLabel: weekRangeLabel,
            todayEvents: eventsForDay(selectedDate, in: snapshot.eventsInRange, calendar: calendar),
            weekAgenda: weekAgenda,
            weekDates: weekDates,
            selectedWeekEvents: eventsForDay(selectedWeekDate, in: snapshot.eventsInRange, calendar: calendar)
        )
    }

    private static func eventsForDay(
        _ day: Date,
        in events: [CalendarEventSnapshot],
        calendar: Calendar
    ) -> [CalendarEventSnapshot] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return events
            .filter { $0.endDate > startOfDay && $0.startDate < endOfDay }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }

    public static func defaultSelectedWeekDate(
        selectedDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> Date {
        let weekStart = XPCalculationService.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
        return defaultSelectedWeekDate(selectedDate: selectedDate, weekDates: weekDates, calendar: calendar)
    }

    private static func defaultSelectedWeekDate(
        selectedDate: Date,
        weekDates: [Date],
        calendar: Calendar
    ) -> Date {
        if weekDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
            return selectedDate
        }
        return weekDates.first ?? selectedDate
    }

    private static func rangeLabel(weekStart: Date, calendar: Calendar) -> String {
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return CalendarPresentation.scheduleDateText(for: weekStart)
        }
        return "\(CalendarPresentation.compactDateText(for: weekStart))-\(CalendarPresentation.compactDateText(for: weekEnd))"
    }
}
