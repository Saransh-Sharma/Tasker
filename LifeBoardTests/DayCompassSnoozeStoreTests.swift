import XCTest
@testable import LifeBoard

final class DayCompassSnoozeStoreTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private let legacyNeedsReplanDismissedDayKey = "home.needsReplan.dismissedDayKey.v1"

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "DayCompassSnoozeStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        calendar = nil
        super.tearDown()
    }

    func testSnoozeUntilEndOfDayPersistsFlowUntilTomorrowStart() {
        let now = date(hour: 10)
        let store = DayCompassSnoozeStore(userDefaults: defaults)

        store.snoozeUntilEndOfDay(flow: .inbox, now: now, calendar: calendar)

        let beforeEndOfDay = store.load(
            now: date(hour: 23),
            calendar: calendar
        )
        let afterEndOfDay = store.load(
            now: date(day: 25, hour: 1),
            calendar: calendar
        )
        XCTAssertTrue(beforeEndOfDay.isSnoozed(.inbox, at: date(hour: 23)))
        XCTAssertFalse(afterEndOfDay.isSnoozed(.inbox, at: date(day: 25, hour: 1)))
    }

    func testExpiredSnoozeIsPrunedOnLoad() {
        let now = date(hour: 12)
        let store = DayCompassSnoozeStore(userDefaults: defaults)
        store.snooze(flow: .rescue, until: now.addingTimeInterval(-60))

        let snapshot = store.load(now: now, calendar: calendar)

        XCTAssertFalse(snapshot.isSnoozed(.rescue, at: now))
        XCTAssertTrue(snapshot.snoozedUntil.isEmpty)
    }

    func testLegacyNeedsReplanDismissalMigratesToCompassReplanSnooze() {
        let now = date(hour: 9)
        defaults.set("2026-2-24", forKey: legacyNeedsReplanDismissedDayKey)
        let store = DayCompassSnoozeStore(userDefaults: defaults)

        let snapshot = store.load(now: now, calendar: calendar)

        XCTAssertTrue(snapshot.isSnoozed(.replan, at: now))
        XCTAssertNil(defaults.string(forKey: legacyNeedsReplanDismissedDayKey))
    }

    func testResumeDismissedForSessionIsSnapshotOnly() {
        let now = date(hour: 13)
        let store = DayCompassSnoozeStore(userDefaults: defaults)

        let dismissed = store.load(
            now: now,
            calendar: calendar,
            resumeDismissedForSession: true
        )
        let nextLoad = store.load(
            now: now,
            calendar: calendar,
            resumeDismissedForSession: false
        )

        XCTAssertTrue(dismissed.isSnoozed(.resumeTask, at: now))
        XCTAssertFalse(nextLoad.isSnoozed(.resumeTask, at: now))
    }

    private func date(day: Int = 24, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 2, day: day, hour: hour))!
    }
}
