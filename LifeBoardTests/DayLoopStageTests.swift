import XCTest
@testable import LifeBoard

/// The rule that makes the loop's door reachable: loop state first, clock second.
final class DayLoopStageTests: XCTestCase {

    private func resolve(
        closed: Bool = false,
        opened: Bool = false,
        morning: Bool = false,
        evening: Bool = false,
        drift: Int = 0,
        suppressesRepair: Bool = false
    ) -> DayLoopStage {
        DayLoopStageResolver.resolve(
            closedToday: closed,
            openedToday: opened,
            isMorningWindow: morning,
            isEveningWindow: evening,
            driftCount: drift,
            suppressesRepair: suppressesRepair
        )
    }

    // MARK: - Loop state beats the clock

    func testAClosedDayRestsNoMatterWhatTimeItIs() {
        // The whole point of the resolver. The old rule asked only what time it
        // was, so a day closed at 15:00 kept being offered until midnight.
        XCTAssertEqual(resolve(closed: true, evening: true), .rest)
        XCTAssertEqual(resolve(closed: true, morning: true), .rest)
        XCTAssertEqual(resolve(closed: true, drift: 5), .rest)
        XCTAssertEqual(resolve(closed: true), .rest)
    }

    func testAnUnclosedMiddayIsActNotNothing() {
        // 11:00–18:00 previously resolved to "no ritual at all".
        XCTAssertEqual(resolve(), .act)
    }

    // MARK: - Window precedence

    func testEveningBeatsRepairBecauseTheCloseCarriesWhatIsLeft() {
        XCTAssertEqual(resolve(evening: true, drift: 4), .close)
    }

    func testMorningOffersCommitOnlyBeforeTheDayIsCommittedTo() {
        XCTAssertEqual(resolve(opened: false, morning: true), .commit)
        XCTAssertEqual(resolve(opened: true, morning: true), .act)
    }

    func testDriftRaisesRepairOutsideTheWindows() {
        XCTAssertEqual(resolve(drift: 1), .repair)
    }

    func testMorningCommitOutranksDrift() {
        // A morning that has not been committed to yet is asking a different
        // question than a day that has slipped. Yesterday's drift must not
        // pre-empt today's start — the commit is what makes the day exist.
        XCTAssertEqual(resolve(opened: false, morning: true, drift: 5), .commit)
        // Once committed, drift is free to surface again.
        XCTAssertEqual(resolve(opened: true, morning: true, drift: 5), .repair)
    }

    func testLowEnergyNeverSurfacesDrift() {
        // Repair is the one stage that asks something extra of a day that is
        // already going badly.
        XCTAssertEqual(resolve(drift: 9, suppressesRepair: true), .act)
    }

    // MARK: - The door

    func testEveryStageExceptRestOffersTheClose() {
        for stage in DayLoopStage.allCases {
            XCTAssertEqual(stage.offersClose, stage != .rest, "\(stage)")
        }
    }

    func testRestAsksForNothing() {
        // Closing a day must not open a new obligation.
        XCTAssertFalse(DayLoopStage.rest.isDemanding)
        XCTAssertFalse(DayLoopStage.act.isDemanding)
        XCTAssertTrue(DayLoopStage.close.isDemanding)
        XCTAssertTrue(DayLoopStage.commit.isDemanding)
    }
}

/// The notification-suppression cache. Not the source of truth — the applied
/// receipt is — but it must track undo, or the nudge stays silent on a day the
/// user reopened.
final class DayLoopClosureLogTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DayLoopClosureLogTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        return calendar
    }

    /// Relative to now, not a fixed instant.
    ///
    /// `write` prunes anything older than the 14-day retention window, so a
    /// hardcoded date is a time bomb: this test was pinned to 2026-07-25 and
    /// passed until that date aged out of the window, then began failing on a
    /// day nobody had touched the code.
    private var recentDay: Date { Date().addingTimeInterval(-2 * 24 * 3_600) }

    func testMarkingADayClosedRecordsItsStamp() {
        let log = DayLoopClosureLog(defaults: defaults)
        let day = recentDay

        log.markClosed(day, calendar: calendar)

        XCTAssertEqual(log.closedStamps(), [DayLoopClosureLog.stamp(for: day, calendar: calendar)])
    }

    func testUndoClearsTheStampSoTheNudgeComesBack() {
        let log = DayLoopClosureLog(defaults: defaults)
        let day = recentDay
        log.markClosed(day, calendar: calendar)

        log.clearClosed(day, calendar: calendar)

        XCTAssertTrue(log.closedStamps().isEmpty)
    }

    func testStampsAreZeroPaddedSoLexicographicOrderIsDateOrder() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 7
        let date = try? XCTUnwrap(calendar.date(from: components))

        XCTAssertEqual(DayLoopClosureLog.stamp(for: date ?? Date(), calendar: calendar), "20260307")
    }

    func testOldStampsArePrunedSoTheListCannotGrowForever() {
        let log = DayLoopClosureLog(defaults: defaults)
        let ancient = Date().addingTimeInterval(-60 * 24 * 3_600)
        let today = Date()

        log.markClosed(ancient, calendar: calendar)
        log.markClosed(today, calendar: calendar)

        let stamps = log.closedStamps()
        XCTAssertTrue(stamps.contains(DayLoopClosureLog.stamp(for: today, calendar: calendar)))
        XCTAssertFalse(stamps.contains(DayLoopClosureLog.stamp(for: ancient, calendar: calendar)))
    }
}

/// The notification stamp the router used to parse and then discard.
final class NotificationDateResolutionTests: XCTestCase {

    func testAStampResolvesToItsOwnCalendarDay() {
        let date = try? XCTUnwrap(AppRouter.notificationDate(from: "20260731"))
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date ?? Date())

        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 7)
        XCTAssertEqual(parts.day, 31)
    }

    func testAMissingOrUnparseableStampFallsBackToNow() {
        // A notification tapped after midnight previously opened whatever
        // "today" had become; falling back to now is the same behaviour, but
        // only when there is genuinely nothing to resolve.
        let before = Date().addingTimeInterval(-5)
        XCTAssertGreaterThan(AppRouter.notificationDate(from: nil), before)
        XCTAssertGreaterThan(AppRouter.notificationDate(from: ""), before)
        XCTAssertGreaterThan(AppRouter.notificationDate(from: "not-a-date"), before)
    }
}
