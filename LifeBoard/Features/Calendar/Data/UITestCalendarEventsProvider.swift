import Foundation
import Combine
import CoreData

// The scripted calendar used by UI tests. It lived inside the dependency
// container purely because that is where it was first needed; it is a
// calendar provider, not composition.
final class UITestCalendarEventsProvider: CalendarEventsProviderProtocol, @unchecked Sendable {
    private let mode: UITestCalendarMode
    private let storeChangedSubject = PassthroughSubject<Void, Never>()
    private var authStatus: CalendarAuthorizationStatus

    init(mode: UITestCalendarMode) {
        self.mode = mode
        switch mode {
        case .permission:
            self.authStatus = .notDetermined
        case .writeOnly:
            self.authStatus = .writeOnly
        case .denied, .deniedAfterAttempt:
            self.authStatus = .denied
        case .active, .allDayOnly, .noCalendars, .empty, .error:
            self.authStatus = .authorized
        }
    }

    func authorizationStatus() -> CalendarAuthorizationStatus {
        authStatus
    }

    func requestAccess(completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        switch mode {
        case .denied, .deniedAfterAttempt:
            completion(.success(false))
        default:
            authStatus = .authorized
            completion(.success(true))
        }
    }

    func resetStoreStateAfterPermissionChange() {}

    func fetchCalendars(completion: @escaping @Sendable (Result<[CalendarSourceSnapshot], Error>) -> Void) {
        switch mode {
        case .error:
            completion(.failure(NSError(
                domain: "UITestCalendarEventsProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load test calendars."]
            )))
        case .noCalendars:
            completion(.success([]))
        default:
            completion(.success([
                CalendarSourceSnapshot(
                    id: "work",
                    title: "Work",
                    sourceTitle: "iCloud",
                    colorHex: "#007AFF",
                    allowsContentModifications: false
                ),
                CalendarSourceSnapshot(
                    id: "personal",
                    title: "Personal",
                    sourceTitle: "iCloud",
                    colorHex: "#34C759",
                    allowsContentModifications: false
                )
            ]))
        }
    }

    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping @Sendable (Result<[CalendarEventSnapshot], Error>) -> Void
    ) {
        switch mode {
        case .permission, .writeOnly, .denied, .deniedAfterAttempt, .noCalendars, .empty:
            completion(.success([]))
        case .error:
            completion(.failure(NSError(
                domain: "UITestCalendarEventsProvider",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load test events."]
            )))
        case .active:
            let calendar = Calendar.current
            let screenshotSeed = ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_APP_STORE_SCREENSHOTS")
            let now = screenshotSeed ? AppStoreScreenshotTestConfiguration.referenceDate : Date()
            let dayStart = calendar.startOfDay(for: now)
            let morningStart = calendar.date(byAdding: .hour, value: 9, to: dayStart) ?? now
            let latestVisibleStart = calendar.date(byAdding: .hour, value: 17, to: dayStart) ?? morningStart
            let upcomingStart = calendar.date(byAdding: .minute, value: 30, to: now) ?? now
            let deterministicTimelineSeed = screenshotSeed
                || ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE")
            let firstStart = deterministicTimelineSeed
                ? (calendar.date(byAdding: .hour, value: 10, to: dayStart) ?? morningStart)
                : min(max(upcomingStart, morningStart), latestVisibleStart)
            let firstEnd = calendar.date(byAdding: .minute, value: 30, to: firstStart) ?? firstStart
            let secondStart = calendar.date(byAdding: .minute, value: 60, to: firstEnd) ?? firstEnd
            let secondEnd = calendar.date(byAdding: .minute, value: 30, to: secondStart) ?? secondStart
            let thirdStart = calendar.date(byAdding: .minute, value: 60, to: secondEnd) ?? secondEnd
            let thirdEnd = calendar.date(byAdding: .minute, value: 30, to: thirdStart) ?? thirdStart
            let allEvents = [
                CalendarEventSnapshot(
                    id: "test_meeting_1",
                    calendarID: "work",
                    calendarTitle: "Work",
                    calendarColorHex: "#007AFF",
                    title: screenshotSeed ? "Launch Readiness Review" : "Design Review",
                    location: screenshotSeed ? "Zoom - Partner Room" : "Zoom",
                    startDate: firstStart,
                    endDate: firstEnd,
                    isAllDay: false,
                    availability: .busy,
                    participationStatus: .accepted
                ),
                CalendarEventSnapshot(
                    id: "test_meeting_2",
                    calendarID: "work",
                    calendarTitle: "Work",
                    calendarColorHex: "#007AFF",
                    title: screenshotSeed ? "Customer Notes Debrief" : "Sprint Standup",
                    location: "Room A",
                    startDate: secondStart,
                    endDate: secondEnd,
                    isAllDay: false,
                    availability: .busy,
                    participationStatus: .accepted
                ),
                CalendarEventSnapshot(
                    id: "test_meeting_3",
                    calendarID: "work",
                    calendarTitle: "Work",
                    calendarColorHex: "#007AFF",
                    title: screenshotSeed ? "1:1 with Maya" : "Roadmap Check-in",
                    location: screenshotSeed ? "Huddle 2" : "Room B",
                    startDate: thirdStart,
                    endDate: thirdEnd,
                    isAllDay: false,
                    availability: .busy,
                    participationStatus: .accepted
                )
            ]
            let inWindowEvents = allEvents.filter { event in
                event.endDate > startDate && event.startDate < endDate
            }
            let filteredEvents = calendarIDs.isEmpty
                ? inWindowEvents
                : inWindowEvents.filter { calendarIDs.contains($0.calendarID) }
            completion(.success(filteredEvents))
        case .allDayOnly:
            let calendar = Calendar.current
            let now = Date()
            let clampedAnchor = min(max(now, startDate), endDate.addingTimeInterval(-60))
            let allDayStart = calendar.startOfDay(for: clampedAnchor)
            let allDayEnd = calendar.date(byAdding: .day, value: 1, to: allDayStart) ?? allDayStart
            let event = CalendarEventSnapshot(
                id: "test_all_day",
                calendarID: "work",
                calendarTitle: "Work",
                calendarColorHex: "#007AFF",
                title: "All-Day Offsite",
                location: nil,
                startDate: allDayStart,
                endDate: allDayEnd,
                isAllDay: true,
                availability: .busy,
                participationStatus: .accepted
            )
            let inWindow = event.endDate > startDate && event.startDate < endDate
            let matchesCalendar = calendarIDs.isEmpty || calendarIDs.contains(event.calendarID)
            completion(.success(inWindow && matchesCalendar ? [event] : []))
        }
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        storeChangedSubject.eraseToAnyPublisher()
    }
}
