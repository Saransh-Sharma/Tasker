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

        let callsAfterInitialLoad = provider.fetchEventsCallCount
        provider.eventsResult = .success([
            event(id: "e1", start: todayDate(hour: 9), end: todayDate(hour: 10)),
            event(id: "e2", start: todayDate(hour: 11), end: todayDate(hour: 12))
        ])
        viewModel.refreshCalendarContext(reason: "test_manual_refresh")

        waitForMainQueue(seconds: 0.25)
        XCTAssertGreaterThan(provider.fetchEventsCallCount, callsAfterInitialLoad)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 2)

        let callsBeforeStoreChange = provider.fetchEventsCallCount
        provider.eventsResult = .success([
            event(id: "e3", start: todayDate(hour: 15), end: todayDate(hour: 16))
        ])
        provider.emitStoreChanged()

        waitForMainQueue(seconds: 0.9)
        XCTAssertGreaterThan(provider.fetchEventsCallCount, callsBeforeStoreChange)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)
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
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .active)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.eventsTodayCount, 1)

        coordinator.calendarIntegrationService.setIncludeAllDayInAgenda(false)
        waitForMainQueue(seconds: 0.25)
        XCTAssertEqual(viewModel.homeCalendarSnapshot.moduleState, .empty)

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
            availability: .busy,
            eventStatus: eventStatus,
            participationStatus: .accepted
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
