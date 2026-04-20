import Foundation
import Combine

public protocol CalendarEventsProviderProtocol {
    func authorizationStatus() -> TaskerCalendarAuthorizationStatus
    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void)
    func resetStoreStateAfterPermissionChange()
    /// Completion queue is intentionally unspecified. Callers must hop to the queue they need.
    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void)
    /// Completion queue is intentionally unspecified. Callers must hop to the queue they need.
    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    )
    /// Completion queue is intentionally unspecified. Callers must hop to the queue they need.
    func fetchEventSlices(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSlice], Error>) -> Void
    )
    func storeChangedPublisher() -> AnyPublisher<Void, Never>
}

public extension CalendarEventsProviderProtocol {
    func fetchEventSlices(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSlice], Error>) -> Void
    ) {
        fetchEvents(startDate: startDate, endDate: endDate, calendarIDs: calendarIDs) { result in
            completion(result.map { snapshots in
                snapshots.map(TaskerCalendarEventSlice.init(snapshot:))
            })
        }
    }
}
