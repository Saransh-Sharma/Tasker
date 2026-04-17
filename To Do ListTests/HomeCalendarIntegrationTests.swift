import XCTest
import UIKit
@testable import To_Do_List

final class HomeCalendarIntegrationTests: XCTestCase {
    private var previousWorkspacePreferences: TaskerWorkspacePreferences!

    override func setUp() {
        super.setUp()
        previousWorkspacePreferences = TaskerWorkspacePreferencesStore.shared.load()
    }

    override func tearDown() {
        if let previousWorkspacePreferences {
            TaskerWorkspacePreferencesStore.shared.save(previousWorkspacePreferences)
        }
        previousWorkspacePreferences = nil
        super.tearDown()
    }

    func testHomeViewModelRefreshesCalendarContextManuallyAndOnStoreChanges() {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "e1", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = UserDefaults(suiteName: "HomeCalendarIntegrationTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .active)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["e1"])

        let callsAfterInitialLoad = provider.fetchEventsCallCount
        provider.eventsResult = .success([
            event(id: "e1", start: todayDate(hour: 9), end: todayDate(hour: 10)),
            event(id: "e2", start: todayDate(hour: 11), end: todayDate(hour: 12))
        ])
        viewModel.refreshCalendarContext(reason: "test_manual_refresh")

        waitForMainQueue(seconds: 0.25)
        XCTAssertGreaterThan(provider.fetchEventsCallCount, callsAfterInitialLoad)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 2)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["e1", "e2"])

        let callsBeforeStoreChange = provider.fetchEventsCallCount
        provider.eventsResult = .success([
            event(id: "e3", start: todayDate(hour: 15), end: todayDate(hour: 16))
        ])
        provider.emitStoreChanged()

        waitForMainQueue(seconds: 0.9)
        XCTAssertGreaterThan(provider.fetchEventsCallCount, callsBeforeStoreChange)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["e3"])
    }

    func testSettingsToHomePropagationUpdatesCalendarModuleState() {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(
                id: "all-day",
                start: todayDate(hour: 0),
                end: todayDate(hour: 23, minute: 59),
                isAllDay: true
            )
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = UserDefaults(suiteName: "HomeCalendarSettingsPropagationTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .allDayOnly)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayEvents.map(\.id), ["all-day"])
        XCTAssertTrue(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.isEmpty)

        coordinator.calendarIntegrationService.setIncludeAllDayInAgenda(false)
        waitForMainQueue(seconds: 0.25)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .empty)
        XCTAssertTrue(viewModel.homeCalendarSnapshot.selectedDayEvents.isEmpty)

        coordinator.calendarIntegrationService.updateSelectedCalendarIDs([])
        waitForMainQueue(seconds: 0.25)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .noCalendarsSelected)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedCalendarCount, 0)
    }

    func testHomeSnapshotHidesCanceledEventsByDefault() {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "canceled", start: todayDate(hour: 9), end: todayDate(hour: 10), eventStatus: .canceled)
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = UserDefaults(suiteName: "HomeCalendarCanceledDefaultTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .empty)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 0)
    }

    func testHomeSnapshotCanIncludeCanceledEventsWhenEnabled() {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: true,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "canceled", start: todayDate(hour: 9), end: todayDate(hour: 10), eventStatus: .canceled)
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = UserDefaults(suiteName: "HomeCalendarCanceledIncludedTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .active)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
    }

    func testHomeCalendarSnapshotFollowsSelectedDateAndRefreshesCalendarReferenceDate() throws {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])

        let startOfToday = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        provider.eventsResult = .success([
            event(id: "today_event", start: startOfToday.addingTimeInterval(9 * 60 * 60), end: startOfToday.addingTimeInterval(10 * 60 * 60)),
            event(id: "tomorrow_event", start: tomorrow.addingTimeInterval(14 * 60 * 60), end: tomorrow.addingTimeInterval(15 * 60 * 60))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = UserDefaults(suiteName: "HomeCalendarSelectedDateTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["today_event"])

        let fetchCallsBeforeDateChange = provider.fetchEventsCallCount
        viewModel.selectDate(tomorrow)

        waitForMainQueue(seconds: 0.45)
        XCTAssertGreaterThan(provider.fetchEventsCallCount, fetchCallsBeforeDateChange)
        XCTAssertTrue(Calendar.current.isDate(viewModel.homeCalendarSnapshot.selectedDate, inSameDayAs: tomorrow))
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["tomorrow_event"])

        let lastRequestedStartDate = try XCTUnwrap(provider.lastRequestedStartDate)
        let lastRequestedEndDate = try XCTUnwrap(provider.lastRequestedEndDate)
        XCTAssertLessThanOrEqual(lastRequestedStartDate, tomorrow)
        XCTAssertGreaterThan(lastRequestedEndDate, tomorrow)
    }

    @MainActor
    func testHomeViewControllerRefreshesCalendarWhenAppBecomesActive() {
        TaskerWorkspacePreferencesStore.shared.save(TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false
        ))

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "e1", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let projectRepository = CalendarProjectRepositoryStub(projects: [Project.createInbox()])
        let readModelRepository = InMemoryTaskReadModelRepositoryStub()
        let coordinator = V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(),
            taskReadModelRepository: readModelRepository,
            projectRepository: projectRepository,
            calendarEventsProvider: provider
        )

        let defaults = UserDefaults(suiteName: "HomeCalendarControllerRefreshTests.\(UUID().uuidString)")!
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        let presentationContainer = PresentationDependencyContainer.shared
        presentationContainer.configure(
            taskReadModelRepository: readModelRepository,
            projectRepository: projectRepository,
            useCaseCoordinator: coordinator
        )

        let controller = HomeViewController()
        controller.viewModel = viewModel
        controller.chartCardViewModel = ChartCardViewModel(readModelRepository: readModelRepository)
        controller.radarChartCardViewModel = RadarChartCardViewModel(
            projectRepository: projectRepository,
            readModelRepository: readModelRepository
        )
        controller.presentationDependencyContainer = presentationContainer

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 420, height: 900))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        waitForMainQueue(seconds: 0.45)

        let fetchCallsBeforeActive = provider.fetchEventsCallCount
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        waitForMainQueue(seconds: 0.3)

        XCTAssertGreaterThan(provider.fetchEventsCallCount, fetchCallsBeforeActive)
        window.isHidden = true
    }

    func testHomeDayTimelineLayoutPlannerSplitsOverlappingEventsIntoLanes() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let anchorDate = CalendarTestClock.date(hour: 10)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "a", hour: 9, minute: 0, durationMinutes: 60),
                timelineEvent(id: "b", hour: 9, minute: 30, durationMinutes: 60),
                timelineEvent(id: "c", hour: 10, minute: 45, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: anchorDate,
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.positionedEvents.count, 3)

        let laneByID = Dictionary(uniqueKeysWithValues: plan.positionedEvents.map { ($0.event.id, $0) })
        XCTAssertEqual(laneByID["a"]?.laneCount, 2)
        XCTAssertEqual(laneByID["b"]?.laneCount, 2)
        XCTAssertEqual(laneByID["a"]?.columnSpan, 1)
        XCTAssertEqual(laneByID["b"]?.columnSpan, 1)
        XCTAssertNotEqual(laneByID["a"]?.lane, laneByID["b"]?.lane)
        XCTAssertEqual(laneByID["c"]?.laneCount, 1)
        XCTAssertEqual(laneByID["c"]?.columnSpan, 1)
    }

    func testHomeDayTimelineLayoutPlannerExpandsIntoFreeAdjacentColumns() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let anchorDate = CalendarTestClock.date(hour: 14, minute: 30)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "a", hour: 13, minute: 50, durationMinutes: 70),
                timelineEvent(id: "b", hour: 14, minute: 0, durationMinutes: 30),
                timelineEvent(id: "c", hour: 14, minute: 10, durationMinutes: 35),
                timelineEvent(id: "d", hour: 14, minute: 30, durationMinutes: 15),
                timelineEvent(id: "e", hour: 14, minute: 45, durationMinutes: 15)
            ],
            on: selectedDate,
            anchorDate: anchorDate,
            calendar: CalendarTestClock.calendar
        ))

        let positionedByID = Dictionary(uniqueKeysWithValues: plan.positionedEvents.map { ($0.event.id, $0) })
        XCTAssertEqual(positionedByID["a"]?.laneCount, 3)
        XCTAssertEqual(positionedByID["a"]?.columnSpan, 1)
        XCTAssertEqual(positionedByID["b"]?.columnSpan, 1)
        XCTAssertEqual(positionedByID["e"]?.lane, 1)
        XCTAssertEqual(positionedByID["e"]?.columnSpan, 2)
    }

    func testHomeDayTimelineLayoutPlannerBuildsCompactVisibleHourWindow() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let anchorDate = CalendarTestClock.date(hour: 10, minute: 42)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "focus", hour: 9, minute: 15, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: anchorDate,
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.startHour, 9)
        XCTAssertEqual(plan.endHour, 11)
    }

    func testHomeDayTimelineLayoutPlannerClampsFixedWindowNearMidnight() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "early", hour: 0, minute: 30, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: CalendarTestClock.date(hour: 0, minute: 5),
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.startHour, 0)
        XCTAssertEqual(plan.endHour, 2)
    }

    func testHomeDayTimelineLayoutPlannerClampsFixedWindowNearEndOfDay() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "late", hour: 22, minute: 30, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: CalendarTestClock.date(hour: 23, minute: 10),
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.startHour, 21)
        XCTAssertEqual(plan.endHour, 23)
    }

    func testHomeDayTimelineLayoutPlannerUsesCurrentHourOfDayForNonTodaySelectedDate() throws {
        let selectedDate = CalendarTestClock.date(day: 18, hour: 0)
        let anchorDate = CalendarTestClock.date(day: 15, hour: 10, minute: 20)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "future", day: 18, hour: 10, minute: 0, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: anchorDate,
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.startHour, 9)
        XCTAssertEqual(plan.endHour, 11)
    }

    func testHomeDayTimelineLayoutPlannerOmitsEventsOutsideViewportAndClipsCrossingEvents() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let anchorDate = CalendarTestClock.date(hour: 10)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "outside", hour: 7, minute: 30, durationMinutes: 30),
                timelineEvent(id: "crossing", hour: 8, minute: 30, durationMinutes: 90),
                timelineEvent(id: "inside", hour: 10, minute: 15, durationMinutes: 30)
            ],
            on: selectedDate,
            anchorDate: anchorDate,
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.positionedEvents.map(\.event.id), ["crossing", "inside"])
        XCTAssertEqual(plan.positionedEvents.first?.startMinute, 9 * 60)
        XCTAssertEqual(plan.positionedEvents.first?.endMinute, 10 * 60)
    }

    func testHomeDayTimelineLayoutPlannerFiltersFreeAndAllDayEventsButKeepsCanceledBusyEvents() throws {
        let selectedDate = CalendarTestClock.date(hour: 0)
        let plan = try XCTUnwrap(HomeDayTimelineLayoutPlanner.makePlan(
            for: [
                timelineEvent(id: "free", hour: 8, minute: 0, durationMinutes: 30, availability: .free),
                timelineEvent(id: "all_day", hour: 0, minute: 0, durationMinutes: 60, isAllDay: true),
                timelineEvent(id: "canceled", hour: 10, minute: 0, durationMinutes: 45, eventStatus: .canceled)
            ],
            on: selectedDate,
            anchorDate: CalendarTestClock.date(hour: 10),
            calendar: CalendarTestClock.calendar
        ))

        XCTAssertEqual(plan.positionedEvents.map(\.event.id), ["canceled"])
        XCTAssertTrue(plan.positionedEvents.first?.event.isCanceled == true)
    }

    func testChooserSectionsGroupCalendarsBySourceAndSortRows() {
        let calendars = [
            TaskerCalendarSourceSnapshot(
                id: "personal",
                title: "Personal",
                sourceTitle: "Google",
                colorHex: "#34C759",
                allowsContentModifications: false
            ),
            TaskerCalendarSourceSnapshot(
                id: "work",
                title: "Work",
                sourceTitle: "iCloud",
                colorHex: "#007AFF",
                allowsContentModifications: false
            ),
            TaskerCalendarSourceSnapshot(
                id: "errands",
                title: "Errands",
                sourceTitle: "Google",
                colorHex: "#FF9500",
                allowsContentModifications: false
            )
        ]

        let sections = TaskerCalendarPresentation.chooserSections(from: calendars)

        XCTAssertEqual(sections.map(\.title), ["Google", "iCloud"])
        XCTAssertEqual(sections.first?.calendars.map(\.title), ["Errands", "Personal"])
    }

    func testBadgesDifferentiateEventStateWithoutColorOnly() {
        let event = TaskerCalendarEventSnapshot(
            id: "event",
            calendarID: "work",
            calendarTitle: "Work",
            calendarColorHex: "#007AFF",
            title: "Review",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: true,
            availability: .busy,
            eventStatus: .canceled,
            participationStatus: .declined
        )

        let badges = TaskerCalendarPresentation.badges(for: event)

        XCTAssertEqual(badges.map(\.title), ["All Day", "Declined", "Canceled"])
    }

    private func makeCoordinator(provider: CalendarEventsProviderProtocol) -> UseCaseCoordinator {
        V3TestHarness.makeCoordinator(
            taskDefinitionRepository: InMemoryTaskDefinitionRepositoryStub(),
            taskReadModelRepository: InMemoryTaskReadModelRepositoryStub(),
            projectRepository: CalendarProjectRepositoryStub(projects: [Project.createInbox()]),
            calendarEventsProvider: provider
        )
    }

    private func calendar(id: String) -> TaskerCalendarSourceSnapshot {
        TaskerCalendarSourceSnapshot(
            id: id,
            title: "Work",
            sourceTitle: "iCloud",
            colorHex: "#007AFF",
            allowsContentModifications: true
        )
    }

    private func event(
        id: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        availability: TaskerCalendarEventAvailability = .busy,
        eventStatus: TaskerCalendarEventStatus = .unknown
    ) -> TaskerCalendarEventSnapshot {
        TaskerCalendarEventSnapshot(
            id: id,
            calendarID: "work",
            calendarTitle: "Work",
            title: id,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            availability: availability,
            eventStatus: eventStatus,
            participationStatus: .accepted
        )
    }

    private func timelineEvent(
        id: String,
        day: Int = 15,
        hour: Int,
        minute: Int,
        durationMinutes: Int,
        isAllDay: Bool = false,
        availability: TaskerCalendarEventAvailability = .busy,
        eventStatus: TaskerCalendarEventStatus = .unknown
    ) -> TaskerCalendarEventSnapshot {
        let start = CalendarTestClock.date(day: day, hour: hour, minute: minute)
        let end = CalendarTestClock.calendar.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
        return event(
            id: id,
            start: start,
            end: end,
            isAllDay: isAllDay,
            availability: availability,
            eventStatus: eventStatus
        )
    }

    private func todayDate(hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: (hour * 60) + minute, to: startOfToday) ?? startOfToday
    }
}

final class CalendarSchedulePresentationStateTests: XCTestCase {
    func testChooserCancelClearsPresentationState() {
        var state = CalendarSchedulePresentationState(showChooser: true)

        state.cancelChooser()

        XCTAssertFalse(state.showChooser)
    }

    func testChooserCommitClearsPresentationState() {
        var state = CalendarSchedulePresentationState(showChooser: true)

        state.commitChooser()

        XCTAssertFalse(state.showChooser)
    }

    func testEventDetailDismissClearsSelectedEvent() {
        var state = CalendarSchedulePresentationState()
        state.selectEvent(id: "event-1")

        state.dismissEventDetail()

        XCTAssertNil(state.selectedEvent)
    }
}
