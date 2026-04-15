import Foundation

public enum TaskerCalendarAuthorizationStatus: String, Codable, Equatable {
    case notDetermined
    case denied
    case restricted
    case writeOnly
    case authorized

    public var isAuthorizedForRead: Bool {
        self == .authorized
    }
}

public enum TaskerCalendarEventAvailability: String, Codable, Equatable {
    case busy
    case free
    case tentative
    case unavailable
}

public enum TaskerCalendarEventParticipationStatus: String, Codable, Equatable {
    case accepted
    case tentative
    case declined
    case pending
    case unknown
}

public struct TaskerCalendarSourceSnapshot: Codable, Equatable, Identifiable, Hashable {
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

public struct TaskerCalendarEventSnapshot: Codable, Equatable, Identifiable, Hashable {
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
        self.participationStatus = participationStatus
        self.lastModifiedAt = lastModifiedAt
    }

    public var isDeclined: Bool {
        participationStatus == .declined
    }

    public var isBusy: Bool {
        availability != .free
    }
}

public struct TaskerCalendarBusyBlock: Equatable, Hashable, Identifiable {
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

public struct TaskerNextMeetingSummary: Equatable {
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

public enum TaskerTaskFitClassification: String, Codable, Equatable {
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
