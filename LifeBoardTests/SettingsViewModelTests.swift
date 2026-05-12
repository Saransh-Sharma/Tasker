import Combine
import XCTest
@testable import LifeBoard

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsViewModelTests.\(UUID().uuidString)"
    }

    override func tearDown() {
        if let suiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        super.tearDown()
    }

    func testTimelineAnchorTimeBindingsPersistWorkspacePreferences() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let notificationStore = LifeBoardNotificationPreferencesStore(defaults: defaults)
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let calendarService = CalendarIntegrationService(
            provider: nil,
            workspacePreferencesStore: workspaceStore
        )
        let viewModel = SettingsViewModel(
            notificationPreferencesStore: notificationStore,
            workspacePreferencesStore: workspaceStore,
            calendarIntegrationService: calendarService
        )

        viewModel.timelineRiseAndShineTime = time(hour: 6, minute: 20)
        viewModel.timelineWindDownTime = time(hour: 23, minute: 5)

        let loaded = workspaceStore.load()
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 6)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 20)
        XCTAssertEqual(loaded.timelineWindDownHour, 23)
        XCTAssertEqual(loaded.timelineWindDownMinute, 5)
    }

    func testTimelineAnchorSelectionPersistsWakePreference() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)

        TimelineAnchorSelection.wake.save(time: time(hour: 5, minute: 45), to: workspaceStore)

        let loaded = workspaceStore.load()
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 5)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 45)
        XCTAssertEqual(loaded.timelineWindDownHour, 22)
        XCTAssertEqual(loaded.timelineWindDownMinute, 0)
    }

    func testTimelineAnchorSelectionPersistsWindDownPreference() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)

        TimelineAnchorSelection.windDown.save(time: time(hour: 23, minute: 30), to: workspaceStore)

        let loaded = workspaceStore.load()
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 8)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 0)
        XCTAssertEqual(loaded.timelineWindDownHour, 23)
        XCTAssertEqual(loaded.timelineWindDownMinute, 30)
    }

    func testTimelineAnchorDraftDoesNotPersistUntilCommitted() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.save(LifeBoardWorkspacePreferences())

        var draft = TimelineAnchorDraft(preferences: workspaceStore.load())
        draft.setTime(time(hour: 5, minute: 45), for: .wake)

        let loadedBeforeCommit = workspaceStore.load()
        XCTAssertEqual(loadedBeforeCommit.timelineRiseAndShineHour, 8)
        XCTAssertEqual(loadedBeforeCommit.timelineRiseAndShineMinute, 0)

        draft.commitIfNeeded(for: .wake, to: workspaceStore)

        let loadedAfterCommit = workspaceStore.load()
        XCTAssertEqual(loadedAfterCommit.timelineRiseAndShineHour, 5)
        XCTAssertEqual(loadedAfterCommit.timelineRiseAndShineMinute, 45)
    }

    func testTimelineAnchorDraftSkipsNoopCommitAndDoesNotEmitDidChange() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.save(LifeBoardWorkspacePreferences())

        var draft = TimelineAnchorDraft(preferences: workspaceStore.load())
        draft.setTime(time(hour: 5, minute: 45), for: .wake)
        draft.setTime(time(hour: 8, minute: 0), for: .wake)

        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: LifeBoardWorkspacePreferencesStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        draft.commitIfNeeded(for: .wake, to: workspaceStore)
        waitForMainQueue(seconds: 0.05)

        XCTAssertEqual(notificationCount, 0)
        XCTAssertEqual(workspaceStore.load().timelineRiseAndShineHour, 8)
        XCTAssertEqual(workspaceStore.load().timelineRiseAndShineMinute, 0)
    }

    func testCommitTimelineAnchorDraftPersistsSettingsChangesWithSingleNotification() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let notificationStore = LifeBoardNotificationPreferencesStore(defaults: defaults)
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let calendarService = CalendarIntegrationService(
            provider: nil,
            workspacePreferencesStore: workspaceStore
        )
        let viewModel = SettingsViewModel(
            notificationPreferencesStore: notificationStore,
            workspacePreferencesStore: workspaceStore,
            calendarIntegrationService: calendarService
        )

        var draft = TimelineAnchorDraft(preferences: viewModel.workspacePreferences)
        draft.setTime(time(hour: 6, minute: 20), for: .wake)
        draft.setTime(time(hour: 23, minute: 5), for: .windDown)

        XCTAssertEqual(workspaceStore.load().timelineRiseAndShineHour, 8)
        XCTAssertEqual(workspaceStore.load().timelineWindDownHour, 22)

        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: LifeBoardWorkspacePreferencesStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.commitTimelineAnchorDraft(draft)
        waitForMainQueue(seconds: 0.05)

        let loaded = workspaceStore.load()
        XCTAssertEqual(notificationCount, 1)
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 6)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 20)
        XCTAssertEqual(loaded.timelineWindDownHour, 23)
        XCTAssertEqual(loaded.timelineWindDownMinute, 5)
        XCTAssertEqual(viewModel.workspacePreferences.timelineRiseAndShineHour, 6)
        XCTAssertEqual(viewModel.workspacePreferences.timelineWindDownHour, 23)
    }

    func testTimelineAnchorSelectionTreatsEarlyMorningWindDownAsNextDay() {
        let preferences = LifeBoardWorkspacePreferences(
            timelineRiseAndShineHour: 8,
            timelineRiseAndShineMinute: 0,
            timelineWindDownHour: 1,
            timelineWindDownMinute: 15
        )

        let windDown = TimelineAnchorSelection.windDown.date(from: preferences)
        let wake = TimelineAnchorSelection.wake.date(from: preferences)

        XCTAssertEqual(Calendar.current.component(.hour, from: windDown), 1)
        XCTAssertEqual(Calendar.current.component(.minute, from: windDown), 15)
        XCTAssertGreaterThan(windDown, wake)
        XCTAssertFalse(Calendar.current.isDate(wake, inSameDayAs: windDown))
    }

    func testTimelineWindDownSummaryMarksEarlyMorningAsNextDay() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let notificationStore = LifeBoardNotificationPreferencesStore(defaults: defaults)
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.save(
            LifeBoardWorkspacePreferences(
                timelineRiseAndShineHour: 8,
                timelineRiseAndShineMinute: 0,
                timelineWindDownHour: 1,
                timelineWindDownMinute: 15
            )
        )
        let calendarService = CalendarIntegrationService(
            provider: nil,
            workspacePreferencesStore: workspaceStore
        )
        let viewModel = SettingsViewModel(
            notificationPreferencesStore: notificationStore,
            workspacePreferencesStore: workspaceStore,
            calendarIntegrationService: calendarService
        )

        XCTAssertTrue(viewModel.timelineWindDownSummary.contains("next day"))
    }

    func testWorkspacePreferencesDefaultMascotIsEva() throws {
        let data = Data("""
        {
          "weekStartsOn": "monday",
          "selectedCalendarIDs": [],
          "includeDeclinedCalendarEvents": false,
          "includeCanceledCalendarEvents": false,
          "includeAllDayInAgenda": true,
          "includeAllDayInBusyStrip": false,
          "showCalendarEventsInTimeline": false,
          "timelineRiseAndShineHour": 8,
          "timelineRiseAndShineMinute": 0,
          "timelineWindDownHour": 22,
          "timelineWindDownMinute": 0
        }
        """.utf8)

        let preferences = try JSONDecoder().decode(LifeBoardWorkspacePreferences.self, from: data)

        XCTAssertEqual(preferences.chiefOfStaffMascotID, .eva)
    }

    func testMascotSelectionPersistsAndPostsWorkspaceChange() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let expectation = expectation(
            forNotification: LifeBoardWorkspacePreferencesStore.didChangeNotification,
            object: nil,
            handler: nil
        )

        workspaceStore.update { preferences in
            preferences.chiefOfStaffMascotID = .sato
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(workspaceStore.load().chiefOfStaffMascotID, .sato)
    }

    func testAssistantIdentityModelPublishesWorkspacePreferenceChanges() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let model = AssistantIdentityModel(workspacePreferencesStore: workspaceStore)
        var cancellables = Set<AnyCancellable>()
        let expectation = expectation(description: "identity model publishes selected mascot")

        model.$snapshot
            .dropFirst()
            .sink { snapshot in
                if snapshot.mascotID == .sato, snapshot.displayName == "Sato" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        workspaceStore.update { preferences in
            preferences.chiefOfStaffMascotID = .sato
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(model.snapshot.displayName, "Sato")
    }

    func testSettingsViewModelSelectChiefOfStaffMascotPersistsSelection() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let notificationStore = LifeBoardNotificationPreferencesStore(defaults: defaults)
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let calendarService = CalendarIntegrationService(
            provider: nil,
            workspacePreferencesStore: workspaceStore
        )
        let viewModel = SettingsViewModel(
            notificationPreferencesStore: notificationStore,
            workspacePreferencesStore: workspaceStore,
            calendarIntegrationService: calendarService
        )

        viewModel.selectChiefOfStaffMascot(.maddie)

        XCTAssertEqual(viewModel.selectedMascotID, .maddie)
        XCTAssertEqual(viewModel.selectedMascotPersona.displayName, "Maddie")
        XCTAssertEqual(workspaceStore.load().chiefOfStaffMascotID, .maddie)
    }

    func testOnboardingFlowModelSelectChiefOfStaffMascotPersistsSelection() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = LifeBoardWorkspacePreferencesStore(defaults: defaults)
        let flowModel = OnboardingFlowModel(
            workspacePreferencesStore: workspaceStore,
            isEvaBackgroundPreparationEnabled: false
        )

        flowModel.selectChiefOfStaffMascot(.theo)

        XCTAssertEqual(flowModel.selectedMascotID, .theo)
        XCTAssertEqual(flowModel.selectedMascotPersona.displayName, "Theo")
        XCTAssertEqual(workspaceStore.load().chiefOfStaffMascotID, .theo)
    }

    private func time(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
