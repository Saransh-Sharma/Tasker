import XCTest
import UIKit
@testable import To_Do_List

final class HomeCalendarIntegrationTests: XCTestCase {
    private var workspaceSuiteName: String!
    private var workspaceStore: TaskerWorkspacePreferencesStore!
    private var ephemeralSuiteNames: [String] = []

    override func setUp() {
        super.setUp()
        workspaceSuiteName = "HomeCalendarIntegrationTests.Workspace.\(UUID().uuidString)"
        let workspaceDefaults = UserDefaults(suiteName: workspaceSuiteName)!
        workspaceStore = TaskerWorkspacePreferencesStore(defaults: workspaceDefaults)
        ephemeralSuiteNames = []
    }

    override func tearDown() {
        for suiteName in ephemeralSuiteNames {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        if let workspaceSuiteName {
            UserDefaults().removePersistentDomain(forName: workspaceSuiteName)
        }
        workspaceSuiteName = nil
        workspaceStore = nil
        ephemeralSuiteNames = []
        super.tearDown()
    }

    func testHomeViewModelRefreshesCalendarContextManuallyAndOnStoreChanges() {
        workspaceStore.save(TaskerWorkspacePreferences(
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
        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarIntegrationTests")
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
        workspaceStore.save(TaskerWorkspacePreferences(
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
        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarSettingsPropagationTests")
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
        workspaceStore.save(TaskerWorkspacePreferences(
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
        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarCanceledDefaultTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .empty)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 0)
    }

    func testHomeSnapshotCanIncludeCanceledEventsWhenEnabled() {
        workspaceStore.save(TaskerWorkspacePreferences(
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
        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarCanceledIncludedTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .active)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
    }

    func testHomeCalendarSnapshotFollowsSelectedDateAndRefreshesCalendarReferenceDate() throws {
        workspaceStore.save(TaskerWorkspacePreferences(
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
        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarSelectedDateTests")
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

    func testHomeTimelineSnapshotHidesCalendarEventsWhenTimelineSettingIsDisabled() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let timelineHiddenPreferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: false
        )
        workspaceStore.save(timelineHiddenPreferences)
        sharedStore.save(timelineHiddenPreferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "all_day", start: todayDate(hour: 0), end: todayDate(hour: 23, minute: 59), isAllDay: true),
            event(id: "timed", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineCalendarToggleOffTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayEvents.map(\.id), ["all_day", "timed"])
        XCTAssertEqual(viewModel.homeCalendarSnapshot.selectedDayTimelineEvents.map(\.id), ["timed"])

        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertFalse(timeline.day.allDayItems.contains { $0.source == .calendarEvent })
        XCTAssertFalse(timeline.day.timedItems.contains { $0.source == .calendarEvent })
        XCTAssertTrue(timeline.week.days.allSatisfy { $0.allDayCount == 0 && $0.timedMarkers.isEmpty })
    }

    func testHomeTimelineSnapshotIncludesCalendarEventsWhenTimelineSettingIsEnabled() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let timelineVisiblePreferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true
        )
        workspaceStore.save(timelineVisiblePreferences)
        sharedStore.save(timelineVisiblePreferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "all_day", start: todayDate(hour: 0), end: todayDate(hour: 23, minute: 59), isAllDay: true),
            event(id: "timed", start: todayDate(hour: 9), end: todayDate(hour: 10))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineCalendarToggleOnTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.45)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertTrue(timeline.day.allDayItems.contains { $0.source == .calendarEvent && $0.eventID == "all_day" })
        XCTAssertTrue(timeline.day.timedItems.contains { $0.source == .calendarEvent && $0.eventID == "timed" })
        XCTAssertTrue(timeline.week.days.contains { $0.allDayCount > 0 || $0.timedMarkers.isEmpty == false })
    }

    func testHomeTimelineSnapshotUsesWorkspaceTimelineAnchorTimes() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true,
            timelineRiseAndShineHour: 6,
            timelineRiseAndShineMinute: 30,
            timelineWindDownHour: 21,
            timelineWindDownMinute: 45
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineAnchorWorkspacePreferencesTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: timeline.day.wakeAnchor.time), 6)
        XCTAssertEqual(calendar.component(.minute, from: timeline.day.wakeAnchor.time), 30)
        XCTAssertEqual(calendar.component(.hour, from: timeline.day.sleepAnchor.time), 21)
        XCTAssertEqual(calendar.component(.minute, from: timeline.day.sleepAnchor.time), 45)
    }

    func testHomeTimelineSnapshotIgnoresQuietHoursForTimelineAnchors() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let notificationStore = TaskerNotificationPreferencesStore.shared
        let originalNotificationPreferences = notificationStore.load()
        defer { notificationStore.save(originalNotificationPreferences) }
        var customNotificationPreferences = originalNotificationPreferences
        customNotificationPreferences.quietHoursEnabled = true
        customNotificationPreferences.quietHoursStartHour = 1
        customNotificationPreferences.quietHoursStartMinute = 15
        customNotificationPreferences.quietHoursEndHour = 5
        customNotificationPreferences.quietHoursEndMinute = 45
        notificationStore.save(customNotificationPreferences)

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true,
            timelineRiseAndShineHour: 9,
            timelineRiseAndShineMinute: 10,
            timelineWindDownHour: 20,
            timelineWindDownMinute: 40
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineAnchorQuietHoursIndependenceTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: timeline.day.wakeAnchor.time), 9)
        XCTAssertEqual(calendar.component(.minute, from: timeline.day.wakeAnchor.time), 10)
        XCTAssertEqual(calendar.component(.hour, from: timeline.day.sleepAnchor.time), 20)
        XCTAssertEqual(calendar.component(.minute, from: timeline.day.sleepAnchor.time), 40)
    }

    func testHomeTimelineSnapshotRollsWindDownToNextDayWhenItIsEarlierThanRiseAndShine() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true,
            timelineRiseAndShineHour: 22,
            timelineRiseAndShineMinute: 30,
            timelineWindDownHour: 6,
            timelineWindDownMinute: 15
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineAnchorOvernightTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        let calendar = Calendar.current
        XCTAssertTrue(timeline.day.sleepAnchor.time > timeline.day.wakeAnchor.time)
        XCTAssertFalse(calendar.isDate(timeline.day.wakeAnchor.time, inSameDayAs: timeline.day.sleepAnchor.time))
        XCTAssertGreaterThan(timeline.day.sleepAnchor.time.timeIntervalSince(timeline.day.wakeAnchor.time), 0)
    }

    func testHomeTimelineSnapshotUsesCompactLayoutForEmptyDay() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineCompactEmptyTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertEqual(timeline.day.layoutMode, .compact)
        XCTAssertTrue(timeline.day.timedItems.isEmpty)
    }

    func testHomeTimelineSnapshotUsesCompactLayoutForSparseDay() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "morning", start: todayDate(hour: 9), end: todayDate(hour: 10)),
            event(id: "evening", start: todayDate(hour: 17), end: todayDate(hour: 18))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineCompactSparseTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertEqual(timeline.day.layoutMode, .compact)
        XCTAssertEqual(timeline.day.timedItems.count, 2)
    }

    func testHomeTimelineSnapshotKeepsExpandedLayoutForBusyDay() {
        let sharedStore = TaskerWorkspacePreferencesStore.shared
        let originalSharedPreferences = sharedStore.load()
        defer { sharedStore.save(originalSharedPreferences) }

        let preferences = TaskerWorkspacePreferences(
            selectedCalendarIDs: ["work"],
            includeDeclinedCalendarEvents: false,
            includeCanceledCalendarEvents: false,
            includeAllDayInAgenda: true,
            includeAllDayInBusyStrip: false,
            showCalendarEventsInTimeline: true
        )
        workspaceStore.save(preferences)
        sharedStore.save(preferences)

        let provider = CalendarEventsProviderStub()
        provider.authorizationStatusValue = .authorized
        provider.calendarsResult = .success([calendar(id: "work")])
        provider.eventsResult = .success([
            event(id: "morning", start: todayDate(hour: 8), end: todayDate(hour: 12)),
            event(id: "afternoon", start: todayDate(hour: 12, minute: 30), end: todayDate(hour: 16, minute: 30)),
            event(id: "evening", start: todayDate(hour: 17), end: todayDate(hour: 21))
        ])

        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineExpandedBusyTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.35)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertEqual(timeline.day.layoutMode, .expanded)
        XCTAssertEqual(timeline.day.timedItems.count, 3)
    }

    func testTimelineGapsGeneratePlanningActionsAndCopyForOpenWindows() {
        let provider = CalendarEventsProviderStub()
        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineGapCopyTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        let wake = CalendarTestClock.date(hour: 8, minute: 0)
        let sleep = CalendarTestClock.date(hour: 22, minute: 0)
        let morningTask = TimelinePlanItem(
            id: "task:morning",
            source: .task,
            taskID: UUID(),
            eventID: nil,
            title: "Morning block",
            subtitle: nil,
            startDate: CalendarTestClock.date(hour: 10, minute: 0),
            endDate: CalendarTestClock.date(hour: 11, minute: 0),
            isAllDay: false,
            isComplete: false,
            tintHex: ProjectColor.blue.hexString,
            systemImageName: "briefcase.fill",
            accessoryText: nil
        )
        let noonTask = TimelinePlanItem(
            id: "task:noon",
            source: .task,
            taskID: UUID(),
            eventID: nil,
            title: "Noon block",
            subtitle: nil,
            startDate: CalendarTestClock.date(hour: 11, minute: 30),
            endDate: CalendarTestClock.date(hour: 12, minute: 0),
            isAllDay: false,
            isComplete: false,
            tintHex: ProjectColor.green.hexString,
            systemImageName: "leaf.fill",
            accessoryText: nil
        )

        let gaps = viewModel.timelineGaps(
            between: [morningTask, noonTask],
            wakeAnchor: TimelineAnchorItem(id: "wake", title: "Rise and shine", time: wake, systemImageName: "alarm.fill"),
            sleepAnchor: TimelineAnchorItem(id: "sleep", title: "Wind down", time: sleep, systemImageName: "moon.fill"),
            inboxCount: 3
        )

        XCTAssertEqual(gaps.count, 3)
        XCTAssertEqual(gaps.first?.primaryAction, .addTask)
        XCTAssertEqual(gaps.first?.secondaryAction, .planBlock)
        XCTAssertEqual(gaps.first?.emphasis, .openTime)
        XCTAssertEqual(gaps.first?.headline, "Open time")
        XCTAssertEqual(gaps[1].emphasis, .prepWindow)
        XCTAssertEqual(gaps.last?.emphasis, .quietWindow)
        XCTAssertEqual(gaps.last?.headline, "Evening buffer")
    }

    func testHomeTimelineSnapshotBuildsStableWeekDayKeysAndOpenSummaries() {
        let provider = CalendarEventsProviderStub()
        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineWeekSummaryTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        waitForMainQueue(seconds: 0.2)
        let timeline = viewModel.buildTimelineSnapshot(
            calendarSnapshot: viewModel.homeCalendarSnapshot,
            foredropAnchor: .collapsed
        )

        XCTAssertEqual(timeline.week.days.count, 7)
        XCTAssertTrue(timeline.week.days.allSatisfy { $0.dayKey.count == 10 })
        XCTAssertTrue(timeline.week.days.allSatisfy { $0.summaryText.isEmpty == false })
        XCTAssertTrue(timeline.week.days.contains { $0.summaryText == "Open" })
    }

    func testTimelineSummaryHelpersPromoteBusyDaysAndMeaningfulCounts() {
        let provider = CalendarEventsProviderStub()
        let coordinator = makeCoordinator(provider: provider)
        let defaults = makeUserDefaultsSuite(prefix: "HomeTimelineSummaryHelperTests")
        let viewModel = HomeViewModel(useCaseCoordinator: coordinator, userDefaults: defaults)

        XCTAssertEqual(viewModel.timelineLoadLevel(for: 1), .light)
        XCTAssertEqual(viewModel.timelineLoadLevel(for: 3), .balanced)
        XCTAssertEqual(viewModel.timelineLoadLevel(for: 6), .busy)
        XCTAssertEqual(viewModel.timelineWeekSummaryText(taskCount: 2, eventCount: 1, allDayCount: 0), "2 tasks · 1 event")
        XCTAssertEqual(viewModel.timelineWeekSummaryText(taskCount: 0, eventCount: 0, allDayCount: 0), "Open")
    }

    @MainActor
    func testHomeViewControllerRefreshesCalendarWhenAppBecomesActive() {
        workspaceStore.save(TaskerWorkspacePreferences(
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
            calendarEventsProvider: provider,
            workspacePreferencesStore: workspaceStore
        )

        let defaults = makeUserDefaultsSuite(prefix: "HomeCalendarControllerRefreshTests")
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
        window.rootViewController = nil
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

        XCTAssertEqual(plan.startMinute, 9 * 60)
        XCTAssertEqual(plan.endMinute, (11 * 60) + 15)
        XCTAssertEqual(plan.startHour, 9)
        XCTAssertEqual(plan.endHour, 11)
        XCTAssertEqual(plan.hourMarkers, [9, 10, 11])
        XCTAssertEqual(plan.endMinute - plan.startMinute, 135)
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

        XCTAssertEqual(plan.startMinute, 0)
        XCTAssertEqual(plan.endMinute, (2 * 60) + 15)
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

        XCTAssertEqual(plan.startMinute, 21 * 60)
        XCTAssertEqual(plan.endMinute, (23 * 60) + 15)
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

        XCTAssertEqual(plan.startMinute, 9 * 60)
        XCTAssertEqual(plan.endMinute, (11 * 60) + 15)
        XCTAssertEqual(plan.startHour, 9)
        XCTAssertEqual(plan.endHour, 11)
        XCTAssertEqual(plan.endMinute - plan.startMinute, 135)
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
            calendarEventsProvider: provider,
            workspacePreferencesStore: workspaceStore
        )
    }

    private func makeUserDefaultsSuite(prefix: String) -> UserDefaults {
        let suiteName = "\(prefix).\(UUID().uuidString)"
        ephemeralSuiteNames.append(suiteName)
        return UserDefaults(suiteName: suiteName)!
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
        var state = CalendarSchedulePresentationState(activeSheet: .chooser)

        state.cancelChooser()

        XCTAssertNil(state.activeSheet)
    }

    func testChooserCommitClearsPresentationState() {
        var state = CalendarSchedulePresentationState(activeSheet: .chooser)

        state.commitChooser()

        XCTAssertNil(state.activeSheet)
    }

    func testEventDetailDismissClearsSelectedEvent() {
        var state = CalendarSchedulePresentationState()
        state.selectEvent(id: "event-1")

        state.dismissEventDetail()

        XCTAssertNil(state.activeSheet)
    }
}
