import XCTest
@testable import To_Do_List

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
        let notificationStore = TaskerNotificationPreferencesStore(defaults: defaults)
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)
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
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)

        TimelineAnchorSelection.wake.save(time: time(hour: 5, minute: 45), to: workspaceStore)

        let loaded = workspaceStore.load()
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 5)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 45)
        XCTAssertEqual(loaded.timelineWindDownHour, 22)
        XCTAssertEqual(loaded.timelineWindDownMinute, 0)
    }

    func testTimelineAnchorSelectionPersistsWindDownPreference() {
        let defaults = UserDefaults(suiteName: suiteName)!
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)

        TimelineAnchorSelection.windDown.save(time: time(hour: 23, minute: 30), to: workspaceStore)

        let loaded = workspaceStore.load()
        XCTAssertEqual(loaded.timelineRiseAndShineHour, 8)
        XCTAssertEqual(loaded.timelineRiseAndShineMinute, 0)
        XCTAssertEqual(loaded.timelineWindDownHour, 23)
        XCTAssertEqual(loaded.timelineWindDownMinute, 30)
    }

    private func time(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
