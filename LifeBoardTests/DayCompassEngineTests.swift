import XCTest
@testable import LifeBoard

final class DayCompassEngineTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testPriorityChoosesReplanBeforeMorningRescueInboxAndResume() {
        let now = date(hour: 8)
        let taskID = UUID()
        let model = DayCompassEngine().resolve(
            signals: signals(
                now: now,
                replanCandidateCount: 2,
                replanEarliestTitle: "Carry launch",
                hasCommittedDailyPlan: false,
                todayOpenTaskCount: 4,
                rescueEligibleCount: 3,
                inboxReadyCount: 4,
                resume: DayCompassResumeSignal(title: "Draft", pausedMinutesAgo: 12, taskID: taskID)
            )
        )

        XCTAssertEqual(model?.state, .replan(count: 2, earliestTitle: "Carry launch"))
    }

    func testMorningPlanOnlyAppearsInsideMorningWindow() {
        let morning = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 8),
                hasCommittedDailyPlan: false,
                todayOpenTaskCount: 2
            )
        )
        let midday = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 12),
                hasCommittedDailyPlan: false,
                todayOpenTaskCount: 2
            )
        )

        XCTAssertEqual(morning?.state, .morningPlan(openCount: 2))
        XCTAssertNil(midday)
    }

    func testEveningReviewUsesDoneAndOpenCountsAfterEveningStart() {
        let model = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 19),
                hasOpenReflectionTarget: true,
                todayOpenTaskCount: 2,
                todayDoneTaskCount: 3
            )
        )

        XCTAssertEqual(model?.state, .eveningReview(doneCount: 3, openCount: 2))
    }

    func testQuietHoursSuppressOnlyRescueAndInbox() {
        let rescue = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 14),
                rescueEligibleCount: 1,
                isQuietHours: true
            )
        )
        let inbox = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 14),
                inboxReadyCount: 2,
                isQuietHours: true
            )
        )
        let replan = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 14),
                replanCandidateCount: 1,
                isQuietHours: true
            )
        )

        XCTAssertNil(rescue)
        XCTAssertNil(inbox)
        XCTAssertEqual(replan?.state, .replan(count: 1, earliestTitle: nil))
    }

    func testSnoozesSuppressMatchingFlowOnly() {
        let now = date(hour: 14)
        let snoozes = DayCompassSnoozeSnapshot(
            snoozedUntil: [.rescue: now.addingTimeInterval(60 * 60)],
            resumeDismissedForSession: false
        )

        let rescue = DayCompassEngine().resolve(
            signals: signals(now: now, rescueEligibleCount: 1, snoozes: snoozes)
        )
        let inbox = DayCompassEngine().resolve(
            signals: signals(now: now, inboxReadyCount: 2, snoozes: snoozes)
        )

        XCTAssertNil(rescue)
        XCTAssertEqual(inbox?.state, .inbox(count: 2))
    }

    func testOffTodayAndActiveFlowSuppressCompass() {
        let offToday = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 8),
                selectedDate: date(day: 25, hour: 8),
                hasCommittedDailyPlan: false,
                todayOpenTaskCount: 1
            )
        )
        let activeFlow = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 8),
                isAnotherFlowPresented: true,
                hasCommittedDailyPlan: false,
                todayOpenTaskCount: 1
            )
        )

        XCTAssertNil(offToday)
        XCTAssertNil(activeFlow)
    }

    func testAllClearAppearsTemporarilyWhenOtherwiseClear() {
        let now = date(hour: 14)
        let visible = DayCompassEngine().resolve(
            signals: signals(
                now: now,
                allClearFlow: .inbox,
                allClearExpiresAt: now.addingTimeInterval(2)
            )
        )
        let expired = DayCompassEngine().resolve(
            signals: signals(
                now: now,
                allClearFlow: .inbox,
                allClearExpiresAt: now.addingTimeInterval(-1)
            )
        )

        XCTAssertEqual(visible?.state, .allClear(after: .inbox))
        XCTAssertNil(expired)
    }

    func testActivationThresholdBoundaries() {
        let now = date(hour: 14)

        XCTAssertNil(
            DayCompassEngine().resolve(signals: signals(now: now, rescueEligibleCount: 0))
        )
        XCTAssertEqual(
            DayCompassEngine().resolve(signals: signals(now: now, rescueEligibleCount: 1))?.state,
            .rescue(count: 1)
        )
        XCTAssertNil(
            DayCompassEngine().resolve(signals: signals(now: now, inboxReadyCount: 1))
        )
        XCTAssertEqual(
            DayCompassEngine().resolve(signals: signals(now: now, inboxReadyCount: 2))?.state,
            .inbox(count: 2)
        )
    }

    func testMorningAndEveningWindowEdges() {
        let beforeDawn = DayCompassEngine().resolve(
            signals: signals(now: date(hour: 4), hasCommittedDailyPlan: false, todayOpenTaskCount: 1)
        )
        let atDawn = DayCompassEngine().resolve(
            signals: signals(now: date(hour: 5), hasCommittedDailyPlan: false, todayOpenTaskCount: 1)
        )
        let beforeEvening = DayCompassEngine().resolve(
            signals: signals(now: date(hour: 17), hasOpenReflectionTarget: true, todayDoneTaskCount: 1)
        )
        let atEvening = DayCompassEngine().resolve(
            signals: signals(now: date(hour: 18), hasOpenReflectionTarget: true, todayDoneTaskCount: 1)
        )

        XCTAssertNil(beforeDawn)
        XCTAssertEqual(atDawn?.state, .morningPlan(openCount: 1))
        XCTAssertNil(beforeEvening)
        XCTAssertEqual(atEvening?.state, .eveningReview(doneCount: 1, openCount: 0))
    }

    func testEveningReviewOutranksRescueAndInboxInItsWindow() {
        let model = DayCompassEngine().resolve(
            signals: signals(
                now: date(hour: 19),
                hasOpenReflectionTarget: true,
                todayDoneTaskCount: 2,
                rescueEligibleCount: 5,
                inboxReadyCount: 6
            )
        )

        XCTAssertEqual(model?.state, .eveningReview(doneCount: 2, openCount: 0))
    }

    private func signals(
        now: Date,
        selectedDate: Date? = nil,
        isViewingTodayLens: Bool = true,
        isAnotherFlowPresented: Bool = false,
        replanCandidateCount: Int = 0,
        replanEarliestTitle: String? = nil,
        hasCommittedDailyPlan: Bool = true,
        hasOpenReflectionTarget: Bool = false,
        todayOpenTaskCount: Int = 0,
        todayDoneTaskCount: Int = 0,
        rescueEligibleCount: Int = 0,
        inboxReadyCount: Int = 0,
        resume: DayCompassResumeSignal? = nil,
        isQuietHours: Bool = false,
        snoozes: DayCompassSnoozeSnapshot = DayCompassSnoozeSnapshot(),
        allClearFlow: DayCompassFlow? = nil,
        allClearExpiresAt: Date? = nil
    ) -> DayCompassSignals {
        DayCompassSignals(
            now: now,
            selectedDate: selectedDate ?? now,
            calendar: calendar,
            isViewingTodayLens: isViewingTodayLens,
            isAnotherFlowPresented: isAnotherFlowPresented,
            replanCandidateCount: replanCandidateCount,
            replanEarliestTitle: replanEarliestTitle,
            hasCommittedDailyPlan: hasCommittedDailyPlan,
            hasOpenReflectionTarget: hasOpenReflectionTarget,
            todayOpenTaskCount: todayOpenTaskCount,
            todayDoneTaskCount: todayDoneTaskCount,
            rescueEligibleCount: rescueEligibleCount,
            inboxReadyCount: inboxReadyCount,
            resume: resume,
            isQuietHours: isQuietHours,
            snoozes: snoozes,
            allClearFlow: allClearFlow,
            allClearExpiresAt: allClearExpiresAt
        )
    }

    private func date(day: Int = 24, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 2, day: day, hour: hour))!
    }
}
