import Foundation
import Combine

#if canImport(EventKit)
 import EventKit

public final class EventKitCalendarEventsProvider: CalendarEventsProviderProtocol {
    private let store: EKEventStore
    private let center: NotificationCenter
    private let workerQueue: DispatchQueue

    public init(
        store: EKEventStore = EKEventStore(),
        center: NotificationCenter = .default,
        workerQueue: DispatchQueue = DispatchQueue(
            label: "com.tasker.calendar.eventkit-provider",
            qos: .userInitiated
        )
    ) {
        self.store = store
        self.center = center
        self.workerQueue = workerQueue
    }

    public func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            case .fullAccess:
                return .authorized
            case .writeOnly:
                return .writeOnly
            @unknown default:
                return .denied
            }
        } else {
            switch status {
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            case .authorized:
                return .authorized
            case .fullAccess:
                return .authorized
            case .writeOnly:
                return .writeOnly
            @unknown default:
                return .denied
            }
        }
    }

    public func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        if #available(iOS 17.0, macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(granted))
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(granted))
                }
            }
        }
    }

    public func resetStoreStateAfterPermissionChange() {
        workerQueue.async { [store] in
            store.reset()
        }
    }

    public func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        workerQueue.async { [store] in
            let calendars = store.calendars(for: .event).map { calendar in
                TaskerCalendarSourceSnapshot(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title,
                    colorHex: calendar.cgColor.flatMap { Self.hexString(from: $0) },
                    allowsContentModifications: calendar.allowsContentModifications
                )
            }
            completion(.success(calendars))
        }
    }

    public func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        workerQueue.async { [store, self] in
            let availableCalendars = store.calendars(for: .event)
            let selectedCalendars: [EKCalendar]
            if calendarIDs.isEmpty {
                selectedCalendars = availableCalendars
            } else {
                selectedCalendars = availableCalendars.filter { calendarIDs.contains($0.calendarIdentifier) }
            }

            guard selectedCalendars.isEmpty == false else {
                completion(.success([]))
                return
            }

            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
            let events = store.events(matching: predicate)
                .map { event in
                    TaskerCalendarEventSnapshot(
                        id: event.eventIdentifier,
                        calendarID: event.calendar.calendarIdentifier,
                        calendarTitle: event.calendar.title,
                        calendarColorHex: event.calendar.cgColor.flatMap { Self.hexString(from: $0) },
                        title: Self.sanitizedTitle(event.title),
                        notes: event.notes,
                        location: event.location,
                        urlString: event.url?.absoluteString,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        availability: self.mapAvailability(event.availability),
                        eventStatus: Self.eventStatus(for: event.status),
                        participationStatus: self.participantStatus(for: event),
                        lastModifiedAt: event.lastModifiedDate
                    )
                }

            completion(.success(events))
        }
    }

    public func fetchEventSlices(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSlice], Error>) -> Void
    ) {
        workerQueue.async { [store, self] in
            let availableCalendars = store.calendars(for: .event)
            let selectedCalendars: [EKCalendar]
            if calendarIDs.isEmpty {
                selectedCalendars = availableCalendars
            } else {
                selectedCalendars = availableCalendars.filter { calendarIDs.contains($0.calendarIdentifier) }
            }

            guard selectedCalendars.isEmpty == false else {
                completion(.success([]))
                return
            }

            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
            let slices = store.events(matching: predicate).map { event in
                TaskerCalendarEventSlice(
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    isBusy: self.mapAvailability(event.availability) != .free
                )
            }

            completion(.success(slices))
        }
    }

    public func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        center.publisher(for: .EKEventStoreChanged, object: store)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func mapAvailability(_ availability: EKEventAvailability) -> TaskerCalendarEventAvailability {
        switch availability {
        case .busy:
            return .busy
        case .free:
            return .free
        case .tentative:
            return .tentative
        case .unavailable:
            return .unavailable
        case .notSupported:
            return .busy
        @unknown default:
            return .busy
        }
    }

    private func participantStatus(for event: EKEvent) -> TaskerCalendarEventParticipationStatus {
        guard let attendees = event.attendees, attendees.isEmpty == false else {
            return .unknown
        }

        if let currentUserAttendee = attendees.first(where: { $0.isCurrentUser }) {
            return mapParticipationStatus(currentUserAttendee.participantStatus)
        }

        if attendees.count == 1, let onlyAttendee = attendees.first {
            return mapParticipationStatus(onlyAttendee.participantStatus)
        }

        return .unknown
    }

    private func mapParticipationStatus(_ status: EKParticipantStatus) -> TaskerCalendarEventParticipationStatus {
        switch status {
        case .accepted:
            return .accepted
        case .tentative:
            return .tentative
        case .declined:
            return .declined
        case .pending:
            return .pending
        default:
            return .unknown
        }
    }

    static func eventStatus(for status: EKEventStatus) -> TaskerCalendarEventStatus {
        switch status {
        case .canceled:
            return .canceled
        default:
            return .unknown
        }
    }

    static func sanitizedTitle(_ title: String?) -> String {
        guard let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmedTitle.isEmpty == false else {
            return "Untitled Event"
        }
        return trimmedTitle
    }

    private static func hexString(from cgColor: CGColor) -> String? {
        guard let components = cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)?.components,
              components.count >= 3 else {
            return nil
        }

        let red = Int((components[0] * 255.0).rounded())
        let green = Int((components[1] * 255.0).rounded())
        let blue = Int((components[2] * 255.0).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
#else
public final class EventKitCalendarEventsProvider: CalendarEventsProviderProtocol {
    public init() {}

    public func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        .denied
    }

    public func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public func resetStoreStateAfterPermissionChange() {}

    public func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        completion(.success([]))
    }

    public func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        _ = startDate
        _ = endDate
        _ = calendarIDs
        completion(.success([]))
    }

    public func fetchEventSlices(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSlice], Error>) -> Void
    ) {
        _ = startDate
        _ = endDate
        _ = calendarIDs
        completion(.success([]))
    }

    public func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        Empty<Void, Never>().eraseToAnyPublisher()
    }
}
#endif
