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

    private func time(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
