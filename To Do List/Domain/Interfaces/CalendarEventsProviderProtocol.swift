import Foundation
import Combine

public protocol CalendarEventsProviderProtocol {
    func authorizationStatus() -> TaskerCalendarAuthorizationStatus
    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void)
    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void)
    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    )
    func storeChangedPublisher() -> AnyPublisher<Void, Never>
}
