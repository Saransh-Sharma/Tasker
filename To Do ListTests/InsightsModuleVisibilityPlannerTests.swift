import XCTest
@testable import To_Do_List

final class InsightsModuleVisibilityPlannerTests: XCTestCase {
    func testTodayReturnsSingleEmptyStateWhenNoSignalExists() {
        let state = InsightsTodayState()

        XCTAssertEqual(
            InsightsModuleVisibilityPlanner.visibility(for: "pressure", today: state),
            .empty(message: "Not enough signal yet. Complete a few tasks or log one recovery action to build today’s board.")
        )
        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "focus", today: state), .hidden)
        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "completion", today: state), .hidden)
        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "recovery", today: state), .hidden)
    }

    func testWeekShowsPatternAndHidesEmptyMixesWhenPartialSignalExists() {
        let state = InsightsWeekState(
            weeklyBars: [
                WeeklyBarData(
                    dateKey: "2026-03-23",
                    dayIndex: 1,
                    label: "Mo",
                    xp: 12,
                    completionCount: 1,
                    intensity: 0.6,
                    isToday: false,
                    isFuture: false
                )
            ],
            projectLeaderboard: [],
            priorityMix: [],
            taskTypeMix: []
        )

        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "pattern", week: state), .visible)
        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "leaderboard", week: state), .hidden)
        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "priority_mix", week: state), .hidden)
    }

    func testSystemsShowsReminderModuleWhenDeliveriesExist() {
        let reminderState = InsightsReminderResponseState(
            totalDeliveries: 3,
            acknowledgedDeliveries: 2,
            snoozedDeliveries: 1,
            pendingDeliveries: 0,
            responseRate: 1.0,
            statusItems: []
        )
        let state = InsightsSystemsState(reminderResponse: reminderState)

        XCTAssertEqual(InsightsModuleVisibilityPlanner.visibility(for: "reminders", systems: state), .visible)
    }
}
