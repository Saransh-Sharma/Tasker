import XCTest
import Combine
@testable import To_Do_List

final class CalendarIntegrationServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CalendarIntegrationServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        cancellables.removeAll()
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPermissionTransitionDeniedToAuthorizedLoadsContext() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .denied
        provider.authorizationStatusAfterAccess = .authorized
        provider.requestAccessResult = .success(true)
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        provider.eventsResult = .success([
            event(id: "e1", calendarID: "work", start: CalendarTestClock.date(hour: 10), end: CalendarTestClock.date(hour: 11))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["work"]))

        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        let expectation = expectation(description: "Authorized snapshot")
        expectation.assertForOverFulfill = false
        var didFulfill = false
        service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if didFulfill == false &&
                    snapshot.authorizationStatus == .authorized &&
                    snapshot.eventsInRange.count == 1 {
                    didFulfill = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.requestAccess()

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(service.snapshot.authorizationStatus, .authorized)
        XCTAssertEqual(provider.fetchCalendarsCallCount, 1)
        XCTAssertEqual(provider.fetchEventsCallCount, 1)
    }

    func testPermissionRequestDeniedKeepsDeniedState() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .notDetermined
        provider.authorizationStatusAfterAccess = .denied
        provider.requestAccessResult = .success(false)

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        let expectation = expectation(description: "Denied completion")
        service.requestAccess { granted in
            XCTAssertFalse(granted)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(service.snapshot.authorizationStatus, .denied)
        XCTAssertEqual(provider.fetchCalendarsCallCount, 0)
        XCTAssertEqual(provider.fetchEventsCallCount, 0)
    }

    func testWorkspacePreferenceReloadUpdatesFiltering() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([
            calendar(id: "work", title: "Work"),
            calendar(id: "personal", title: "Personal")
        ])
        provider.eventsResult = .success([
            event(id: "w1", calendarID: "work", start: CalendarTestClock.date(hour: 9), end: CalendarTestClock.date(hour: 10)),
            event(id: "w2", calendarID: "work", start: CalendarTestClock.date(hour: 11), end: CalendarTestClock.date(hour: 12), isAllDay: true),
            event(id: "w3", calendarID: "work", start: CalendarTestClock.date(hour: 13), end: CalendarTestClock.date(hour: 14), participationStatus: .declined),
            event(id: "p1", calendarID: "personal", start: CalendarTestClock.date(hour: 15), end: CalendarTestClock.date(hour: 16))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: true,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        let initialExpectation = expectation(description: "Initial filter")
        initialExpectation.assertForOverFulfill = false
        var didFulfillInitial = false
        service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if didFulfillInitial == false &&
                    snapshot.eventsInRange.count == 3 &&
                    snapshot.selectedCalendarIDs == ["work"] {
                    didFulfillInitial = true
                    initialExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        service.refreshContext(reason: "test_initial")
        wait(for: [initialExpectation], timeout: 2.0)

        XCTAssertEqual(service.snapshot.eventsInRange.map(\.id).sorted(), ["w1", "w2", "w3"])
        XCTAssertEqual(store.load().selectedCalendarIDs, ["work"])

        let updatedExpectation = expectation(description: "Updated filter from store notification")
        updatedExpectation.assertForOverFulfill = false
        var didFulfillUpdated = false
        service.$snapshot
            .dropFirst()
            .sink { snapshot in
                if didFulfillUpdated == false &&
                    snapshot.selectedCalendarIDs == ["personal"] &&
                    snapshot.includeDeclined == false &&
                    snapshot.includeAllDayInAgenda == false &&
                    snapshot.eventsInRange.map(\.id) == ["p1"] {
                    didFulfillUpdated = true
                    updatedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        store.update { preferences in
            preferences.selectedCalendarIDs = ["personal"]
            preferences.includeDeclinedCalendarEvents = false
            preferences.includeAllDayInAgenda = false
            preferences.includeAllDayInBusyStrip = true
        }

        wait(for: [updatedExpectation], timeout: 2.0)
        XCTAssertEqual(store.load().selectedCalendarIDs, ["personal"])
    }

    private func calendar(id: String, title: String) -> TaskerCalendarSourceSnapshot {
        TaskerCalendarSourceSnapshot(
            id: id,
            title: title,
            sourceTitle: "iCloud",
            colorHex: "#007AFF",
            allowsContentModifications: true
        )
    }

    private func event(
        id: String,
        calendarID: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        participationStatus: TaskerCalendarEventParticipationStatus = .accepted
    ) -> TaskerCalendarEventSnapshot {
        TaskerCalendarEventSnapshot(
            id: id,
            calendarID: calendarID,
            calendarTitle: calendarID.capitalized,
            title: id,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            availability: .busy,
            participationStatus: participationStatus
        )
    }
}
