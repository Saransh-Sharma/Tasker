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
        XCTAssertEqual(provider.resetStoreCallCount, 1)
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

    func testAccessActionPolicyMatchesAuthorizationState() {
        let provider = CalendarEventsProviderStub()
        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        provider.authorizationStatusValue = .notDetermined
        XCTAssertEqual(service.accessAction(), .requestPermission)

        provider.authorizationStatusValue = .denied
        XCTAssertEqual(service.accessAction(), .openSystemSettings)

        provider.authorizationStatusValue = .restricted
        XCTAssertEqual(service.accessAction(), .unavailable(.restricted))

        provider.authorizationStatusValue = .writeOnly
        XCTAssertEqual(service.accessAction(), .unavailable(.writeOnly))

        provider.authorizationStatusValue = .authorized
        XCTAssertEqual(service.accessAction(), .noneNeeded)
    }

    func testEventTitleSanitizerUsesFallbackForNilAndBlankTitles() {
        XCTAssertEqual(EventKitCalendarEventsProvider.sanitizedTitle(nil), "Untitled Event")
        XCTAssertEqual(EventKitCalendarEventsProvider.sanitizedTitle(""), "Untitled Event")
        XCTAssertEqual(EventKitCalendarEventsProvider.sanitizedTitle("   "), "Untitled Event")
        XCTAssertEqual(EventKitCalendarEventsProvider.sanitizedTitle(" Focus Block "), "Focus Block")
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

    func testNoSelectedCalendarsSkipsEventFetchAndClearsContext() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        provider.eventsResult = .success([
            event(id: "w1", calendarID: "work", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: [],
            includeDeclinedCalendarEvents: true,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: true
        ))

        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)
        service.refreshContext(referenceDate: todayDate(hour: 8), reason: "no_selected_calendars")
        waitForMainQueue(seconds: 0.2)

        XCTAssertEqual(provider.fetchCalendarsCallCount, 1)
        XCTAssertEqual(provider.fetchEventsCallCount, 0)
        XCTAssertEqual(service.snapshot.eventsInRange, [])
        XCTAssertEqual(service.snapshot.busyBlocks, [])
        XCTAssertNil(service.snapshot.nextMeeting)
        XCTAssertNil(service.snapshot.freeUntil)
    }

    func testRefreshContextPrunesUnavailableCalendarSelections() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([
            calendar(id: "work", title: "Work"),
            calendar(id: "personal", title: "Personal")
        ])
        provider.eventsResult = .success([
            event(id: "w1", calendarID: "work", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["stale", "work"]))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        service.refreshContext(referenceDate: todayDate(hour: 8), reason: "prune_stale_selection")
        waitForMainQueue(seconds: 0.2)

        XCTAssertEqual(service.snapshot.selectedCalendarIDs, ["work"])
        XCTAssertEqual(store.load().selectedCalendarIDs, ["work"])
        XCTAssertEqual(provider.lastRequestedCalendarIDs, ["work"])
        XCTAssertEqual(service.snapshot.eventsInRange.map(\.id), ["w1"])
    }

    func testRefreshContextFullyPrunesUnavailableSelectionAndSkipsEventFetch() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        provider.eventsResult = .success([
            event(id: "w1", calendarID: "work", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["stale"]))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        service.refreshContext(referenceDate: todayDate(hour: 8), reason: "fully_prune_selection")
        waitForMainQueue(seconds: 0.2)

        XCTAssertEqual(service.snapshot.selectedCalendarIDs, [])
        XCTAssertEqual(store.load().selectedCalendarIDs, [])
        XCTAssertEqual(provider.fetchEventsCallCount, 0)
        XCTAssertTrue(service.snapshot.eventsInRange.isEmpty)
        XCTAssertTrue(service.snapshot.busyBlocks.isEmpty)
    }

    func testAgendaAllDayToggleDoesNotAffectTaskFitContextPipeline() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        provider.eventsResult = .success([
            event(
                id: "all_day",
                calendarID: "work",
                start: todayDate(hour: 0),
                end: todayDate(hour: 23, minute: 59),
                isAllDay: true
            )
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeAllDayInAgenda: false,
            includeAllDayInBusyStrip: true
        ))

        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)
        let now = todayDate(hour: 9)
        let dueDate = todayDate(hour: 18)
        let task = TaskDefinition(
            title: "Deep Work Block",
            dueDate: dueDate,
            estimatedDuration: 30 * 60
        )

        service.refreshContext(referenceDate: now, reason: "all_day_pipeline_independence")
        waitForMainQueue(seconds: 0.2)

        XCTAssertTrue(service.snapshot.eventsInRange.isEmpty, "Agenda should hide all-day events when toggle is disabled.")
        let hint = service.taskFitHint(for: task, now: now)
        XCTAssertEqual(hint.classification, .conflict, "Task-fit should still use context events and include all-day busy blocks.")
    }

    func testNextMeetingExcludesAllDayEventsByDefault() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        let now = todayDate(hour: 8)
        provider.eventsResult = .success([
            event(
                id: "all_day",
                calendarID: "work",
                start: todayDate(hour: 0),
                end: todayDate(hour: 23, minute: 59),
                isAllDay: true
            ),
            event(
                id: "timed",
                calendarID: "work",
                start: todayDate(hour: 10),
                end: todayDate(hour: 11)
            )
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["work"]))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        service.refreshContext(referenceDate: now, reason: "next_meeting_timed_only")
        waitForMainQueue(seconds: 0.2)

        XCTAssertEqual(service.snapshot.nextMeeting?.event.id, "timed")
    }

    func testRefreshContextIgnoresStaleEventFetchResults() {
        let provider = CalendarEventsProviderRaceStub()
        provider.authorizationStatusValue = .authorized
        provider.calendars = [calendar(id: "work", title: "Work")]

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["work"]))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        service.refreshContext(referenceDate: todayDate(hour: 8), reason: "race_old")
        XCTAssertEqual(provider.pendingCalendarRequestCount, 1)
        provider.completeCalendarRequest(at: 0)
        waitForMainQueue(seconds: 0.05)
        XCTAssertEqual(provider.pendingEventRequestCount, 1)

        service.refreshContext(referenceDate: todayDate(hour: 8), reason: "race_new")
        XCTAssertEqual(provider.pendingCalendarRequestCount, 1)
        provider.completeCalendarRequest(at: 0)
        waitForMainQueue(seconds: 0.05)
        XCTAssertEqual(provider.pendingEventRequestCount, 2)

        provider.completeEventRequest(at: 1, events: [
            event(id: "fresh", calendarID: "work", start: todayDate(hour: 11), end: todayDate(hour: 12))
        ])
        waitForMainQueue(seconds: 0.1)
        XCTAssertEqual(service.snapshot.eventsInRange.map(\.id), ["fresh"])

        provider.completeEventRequest(at: 0, events: [
            event(id: "stale", calendarID: "work", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])
        waitForMainQueue(seconds: 0.1)
        XCTAssertEqual(service.snapshot.eventsInRange.map(\.id), ["fresh"])
    }

    func testFetchRangeUsesWeekStartAndTodayForwardWindow() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        provider.eventsResult = .success([])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(
            weekStartsOn: .sunday,
            selectedCalendarIDs: ["work"]
        ))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)
        let referenceDate = CalendarTestClock.date(year: 2026, month: 4, day: 16, hour: 9)

        service.refreshContext(referenceDate: referenceDate, reason: "range_semantics")
        waitForMainQueue(seconds: 0.2)

        let expectedStart = XPCalculationEngine.startOfWeek(for: referenceDate, startingOn: .sunday)
        let calendar = Calendar.current
        let expectedWeekEnd = calendar.date(byAdding: .day, value: 7, to: expectedStart) ?? expectedStart
        let expectedTodayForwardEnd = calendar.date(
            byAdding: .day,
            value: 7,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
        let expectedEnd = max(expectedWeekEnd, expectedTodayForwardEnd)

        XCTAssertEqual(provider.lastRequestedStartDate, expectedStart)
        XCTAssertEqual(provider.lastRequestedEndDate, expectedEnd)
    }

    func testFreeUntilIsNilWhileCurrentBlockIsInProgress() {
        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work", title: "Work")])
        let now = todayDate(hour: 10)
        provider.eventsResult = .success([
            event(id: "ongoing", calendarID: "work", start: todayDate(hour: 9, minute: 45), end: todayDate(hour: 10, minute: 45))
        ])

        let store = TaskerWorkspacePreferencesStore(defaults: defaults)
        store.save(TaskerWorkspacePreferences(selectedCalendarIDs: ["work"]))
        let service = CalendarIntegrationService(provider: provider, workspacePreferencesStore: store)

        service.refreshContext(referenceDate: now, reason: "free_until_ongoing")
        waitForMainQueue(seconds: 0.2)

        XCTAssertEqual(service.snapshot.nextMeeting?.isInProgress, true)
        XCTAssertNil(service.snapshot.freeUntil)
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

    private func todayDate(hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: (hour * 60) + minute, to: startOfToday) ?? startOfToday
    }
}

private final class CalendarEventsProviderRaceStub: CalendarEventsProviderProtocol {
    var authorizationStatusValue: TaskerCalendarAuthorizationStatus = .authorized
    var calendars: [TaskerCalendarSourceSnapshot] = []
    private var calendarCompletions: [(Result<[TaskerCalendarSourceSnapshot], Error>) -> Void] = []
    private var eventCompletions: [(Result<[TaskerCalendarEventSnapshot], Error>) -> Void] = []
    private let storeChangedSubject = PassthroughSubject<Void, Never>()

    var pendingCalendarRequestCount: Int { calendarCompletions.count }
    var pendingEventRequestCount: Int { eventCompletions.count }

    func authorizationStatus() -> TaskerCalendarAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }

    func resetStoreStateAfterPermissionChange() {}

    func fetchCalendars(completion: @escaping (Result<[TaskerCalendarSourceSnapshot], Error>) -> Void) {
        calendarCompletions.append(completion)
    }

    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping (Result<[TaskerCalendarEventSnapshot], Error>) -> Void
    ) {
        _ = startDate
        _ = endDate
        _ = calendarIDs
        eventCompletions.append(completion)
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        storeChangedSubject.eraseToAnyPublisher()
    }

    func completeCalendarRequest(at index: Int) {
        let completion = calendarCompletions.remove(at: index)
        completion(.success(calendars))
    }

    func completeEventRequest(at index: Int, events: [TaskerCalendarEventSnapshot]) {
        let completion = eventCompletions.remove(at: index)
        completion(.success(events))
    }
}
