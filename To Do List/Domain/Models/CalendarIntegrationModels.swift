import Foundation

public enum TaskerCalendarAuthorizationStatus: String, Codable, Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case authorized

    public var isAuthorizedForRead: Bool {
        self == .authorized
    }
}

public enum TaskerCalendarEventAvailability: String, Codable, Equatable, Sendable {
    case busy
    case free
    case tentative
    case unavailable
}

public enum TaskerCalendarEventParticipationStatus: String, Codable, Equatable, Sendable {
    case accepted
    case tentative
    case declined
    case pending
    case unknown
}

public enum TaskerCalendarEventStatus: String, Codable, Equatable, Sendable {
    case unknown
    case canceled
}

public struct TaskerCalendarSourceSnapshot: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let colorHex: String?
    public let allowsContentModifications: Bool

    public init(
        id: String,
        title: String,
        sourceTitle: String,
        colorHex: String? = nil,
        allowsContentModifications: Bool
    ) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.colorHex = colorHex
        self.allowsContentModifications = allowsContentModifications
    }
}

public struct TaskerCalendarEventSnapshot: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: String
    public let calendarID: String
    public let calendarTitle: String
    public let calendarColorHex: String?
    public let title: String
    public let notes: String?
    public let location: String?
    public let urlString: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let availability: TaskerCalendarEventAvailability
    public let eventStatus: TaskerCalendarEventStatus
    public let participationStatus: TaskerCalendarEventParticipationStatus
    public let lastModifiedAt: Date?

    public init(
        id: String,
        calendarID: String,
        calendarTitle: String,
        calendarColorHex: String? = nil,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        urlString: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        availability: TaskerCalendarEventAvailability = .busy,
        eventStatus: TaskerCalendarEventStatus = .unknown,
        participationStatus: TaskerCalendarEventParticipationStatus = .unknown,
        lastModifiedAt: Date? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.title = title
        self.notes = notes
        self.location = location
        self.urlString = urlString
        self.startDate = startDate
        self.endDate = max(endDate, startDate)
        self.isAllDay = isAllDay
        self.availability = availability
        self.eventStatus = eventStatus
        self.participationStatus = participationStatus
        self.lastModifiedAt = lastModifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case calendarID
        case calendarTitle
        case calendarColorHex
        case title
        case notes
        case location
        case urlString
        case startDate
        case endDate
        case isAllDay
        case availability
        case eventStatus
        case participationStatus
        case lastModifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            calendarID: try container.decode(String.self, forKey: .calendarID),
            calendarTitle: try container.decode(String.self, forKey: .calendarTitle),
            calendarColorHex: try container.decodeIfPresent(String.self, forKey: .calendarColorHex),
            title: try container.decode(String.self, forKey: .title),
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            location: try container.decodeIfPresent(String.self, forKey: .location),
            urlString: try container.decodeIfPresent(String.self, forKey: .urlString),
            startDate: try container.decode(Date.self, forKey: .startDate),
            endDate: try container.decode(Date.self, forKey: .endDate),
            isAllDay: try container.decode(Bool.self, forKey: .isAllDay),
            availability: try container.decode(TaskerCalendarEventAvailability.self, forKey: .availability),
            eventStatus: try container.decode(TaskerCalendarEventStatus.self, forKey: .eventStatus),
            participationStatus: try container.decode(TaskerCalendarEventParticipationStatus.self, forKey: .participationStatus),
            lastModifiedAt: try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt)
        )
    }

    public var isDeclined: Bool {
        participationStatus == .declined
    }

    public var isCanceled: Bool {
        eventStatus == .canceled
    }

    public var isBusy: Bool {
        availability != .free
    }
}

struct HomeTimelineHiddenCalendarEventKey: Codable, Equatable, Hashable, Sendable, Comparable {
    let eventID: String
    let dayStamp: String

    init(eventID: String, dayStamp: String) {
        self.eventID = eventID
        self.dayStamp = dayStamp
    }

    init(eventID: String, day: Date, calendar: Calendar = .current) {
        self.init(eventID: eventID, dayStamp: Self.dayStamp(for: day, calendar: calendar))
    }

    static func < (lhs: HomeTimelineHiddenCalendarEventKey, rhs: HomeTimelineHiddenCalendarEventKey) -> Bool {
        if lhs.dayStamp != rhs.dayStamp {
            return lhs.dayStamp < rhs.dayStamp
        }
        return lhs.eventID.localizedStandardCompare(rhs.eventID) == .orderedAscending
    }

    static func dayStamp(for day: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

final class HomeTimelineHiddenCalendarEventStore {
    private struct Payload: Codable, Equatable {
        var hiddenEvents: [HomeTimelineHiddenCalendarEventKey]
    }

    private let defaults: UserDefaults
    private let key = "tasker.home.timeline.hiddenCalendarEvents.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<HomeTimelineHiddenCalendarEventKey> {
        guard let data = defaults.data(forKey: key),
              let payload = try? decoder.decode(Payload.self, from: data) else {
            return []
        }
        return Set(payload.hiddenEvents)
    }

    func save(_ hiddenEvents: Set<HomeTimelineHiddenCalendarEventKey>) {
        let payload = Payload(hiddenEvents: hiddenEvents.sorted())
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    @discardableResult
    func hide(eventID: String, on day: Date, calendar: Calendar = .current) -> Set<HomeTimelineHiddenCalendarEventKey> {
        var hiddenEvents = load()
        hiddenEvents.insert(HomeTimelineHiddenCalendarEventKey(eventID: eventID, day: day, calendar: calendar))
        save(hiddenEvents)
        return hiddenEvents
    }

    func isHidden(eventID: String, on day: Date, calendar: Calendar = .current) -> Bool {
        load().contains(HomeTimelineHiddenCalendarEventKey(eventID: eventID, day: day, calendar: calendar))
    }
}

public struct TaskerCalendarEventSlice: Codable, Equatable, Hashable, Sendable {
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let isBusy: Bool

    public init(
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isBusy: Bool
    ) {
        self.startDate = startDate
        self.endDate = max(endDate, startDate)
        self.isAllDay = isAllDay
        self.isBusy = isBusy
    }

    public init(snapshot: TaskerCalendarEventSnapshot) {
        self.init(
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            isAllDay: snapshot.isAllDay,
            isBusy: snapshot.isBusy
        )
    }
}

public struct TaskerCalendarBusyBlock: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let startDate: Date
    public let endDate: Date

    public init(startDate: Date, endDate: Date) {
        self.startDate = min(startDate, endDate)
        self.endDate = max(startDate, endDate)
        self.id = "\(self.startDate.timeIntervalSince1970)-\(self.endDate.timeIntervalSince1970)"
    }

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

public struct TaskerNextMeetingSummary: Equatable, Sendable {
    public let event: TaskerCalendarEventSnapshot
    public let isInProgress: Bool
    public let minutesUntilStart: Int

    public init(
        event: TaskerCalendarEventSnapshot,
        isInProgress: Bool,
        minutesUntilStart: Int
    ) {
        self.event = event
        self.isInProgress = isInProgress
        self.minutesUntilStart = minutesUntilStart
    }
}

public enum TaskerTaskFitClassification: String, Codable, Equatable, Sendable {
    case fit
    case tight
    case conflict
    case unknown
}

public struct TaskerTaskFitHintResult: Equatable {
    public let classification: TaskerTaskFitClassification
    public let message: String
    public let freeWindowStart: Date?
    public let freeWindowEnd: Date?

    public init(
        classification: TaskerTaskFitClassification,
        message: String,
        freeWindowStart: Date? = nil,
        freeWindowEnd: Date? = nil
    ) {
        self.classification = classification
        self.message = message
        self.freeWindowStart = freeWindowStart
        self.freeWindowEnd = freeWindowEnd
    }

    public static let unknown = TaskerTaskFitHintResult(
        classification: .unknown,
        message: "Add a due time and duration to evaluate fit."
    )
}

public struct TaskerCalendarDayAgenda: Equatable, Identifiable {
    public let date: Date
    public let events: [TaskerCalendarEventSnapshot]

    public init(date: Date, events: [TaskerCalendarEventSnapshot]) {
        self.date = date
        self.events = events.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return lhs.endDate < rhs.endDate
        }
    }

    public var id: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

public struct TaskerCalendarSnapshot: Equatable {
    public var authorizationStatus: TaskerCalendarAuthorizationStatus
    public var availableCalendars: [TaskerCalendarSourceSnapshot]
    public var selectedCalendarIDs: [String]
    public var includeDeclined: Bool
    public var includeCanceled: Bool
    public var includeAllDayInAgenda: Bool
    public var includeAllDayInBusyStrip: Bool
    public var eventsInRange: [TaskerCalendarEventSnapshot]
    public var busyBlocks: [TaskerCalendarBusyBlock]
    public var nextMeeting: TaskerNextMeetingSummary?
    public var freeUntil: Date?
    public var isLoading: Bool
    public var errorMessage: String?

    public init(
        authorizationStatus: TaskerCalendarAuthorizationStatus,
        availableCalendars: [TaskerCalendarSourceSnapshot],
        selectedCalendarIDs: [String],
        includeDeclined: Bool,
        includeCanceled: Bool,
        includeAllDayInAgenda: Bool,
        includeAllDayInBusyStrip: Bool,
        eventsInRange: [TaskerCalendarEventSnapshot],
        busyBlocks: [TaskerCalendarBusyBlock],
        nextMeeting: TaskerNextMeetingSummary?,
        freeUntil: Date?,
        isLoading: Bool,
        errorMessage: String?
    ) {
        self.authorizationStatus = authorizationStatus
        self.availableCalendars = availableCalendars
        self.selectedCalendarIDs = selectedCalendarIDs
        self.includeDeclined = includeDeclined
        self.includeCanceled = includeCanceled
        self.includeAllDayInAgenda = includeAllDayInAgenda
        self.includeAllDayInBusyStrip = includeAllDayInBusyStrip
        self.eventsInRange = eventsInRange
        self.busyBlocks = busyBlocks
        self.nextMeeting = nextMeeting
        self.freeUntil = freeUntil
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }

    public static let empty = TaskerCalendarSnapshot(
        authorizationStatus: .notDetermined,
        availableCalendars: [],
        selectedCalendarIDs: [],
        includeDeclined: false,
        includeCanceled: false,
        includeAllDayInAgenda: true,
        includeAllDayInBusyStrip: false,
        eventsInRange: [],
        busyBlocks: [],
        nextMeeting: nil,
        freeUntil: nil,
        isLoading: false,
        errorMessage: nil
    )
}

enum TaskerCalendarBadgeTone: String, Equatable {
    case accent
    case warning
    case danger
    case neutral
}

struct TaskerCalendarEventBadge: Equatable, Identifiable {
    let title: String
    let systemImage: String
    let tone: TaskerCalendarBadgeTone

    var id: String { title }
}

struct TaskerCalendarChooserSection: Equatable, Identifiable {
    let title: String
    let calendars: [TaskerCalendarSourceSnapshot]

    var id: String { title }
}

enum TaskerCalendarPresentation {
    static func chooserSections(from calendars: [TaskerCalendarSourceSnapshot]) -> [TaskerCalendarChooserSection] {
        let grouped = Dictionary(grouping: calendars) { calendar in
            let sourceTitle = calendar.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return sourceTitle.isEmpty ? "Other" : sourceTitle
        }

        return grouped.keys
            .sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
            .map { sourceTitle in
                let sortedCalendars = (grouped[sourceTitle] ?? [])
                    .sorted { lhs, rhs in
                        let titleCompare = lhs.title.localizedStandardCompare(rhs.title)
                        if titleCompare != .orderedSame {
                            return titleCompare == .orderedAscending
                        }
                        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
                    }
                return TaskerCalendarChooserSection(title: sourceTitle, calendars: sortedCalendars)
            }
    }

    static func timeRangeText(for event: TaskerCalendarEventSnapshot, includeDate: Bool = false) -> String {
        if event.isAllDay {
            if includeDate {
                return event.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) + " · All day"
            }
            return "All day"
        }

        let start = includeDate
            ? event.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            : event.startDate.formatted(date: .omitted, time: .shortened)
        let end = includeDate
            ? event.endDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
            : event.endDate.formatted(date: .omitted, time: .shortened)

        return "\(start) - \(end)"
    }

    static func scheduleDateText(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func compactDateText(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func badges(for event: TaskerCalendarEventSnapshot) -> [TaskerCalendarEventBadge] {
        var badges: [TaskerCalendarEventBadge] = []

        if event.isAllDay {
            badges.append(TaskerCalendarEventBadge(title: "All Day", systemImage: "sun.max", tone: .neutral))
        }

        switch event.participationStatus {
        case .declined:
            badges.append(TaskerCalendarEventBadge(title: "Declined", systemImage: "person.crop.circle.badge.xmark", tone: .danger))
        case .tentative:
            badges.append(TaskerCalendarEventBadge(title: "Tentative", systemImage: "questionmark.circle", tone: .warning))
        default:
            break
        }

        if event.isCanceled {
            badges.append(TaskerCalendarEventBadge(title: "Canceled", systemImage: "nosign", tone: .danger))
        }

        if event.availability == .free {
            badges.append(TaskerCalendarEventBadge(title: "Free", systemImage: "circle.dotted", tone: .accent))
        }

        return badges
    }
}
