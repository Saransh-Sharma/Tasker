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
