import XCTest
@testable import To_Do_List

final class HomeHabitLastCellInteractionTests: XCTestCase {

    func testPositiveHabitCyclesDoneThenSkipThenClear() {
        let due = makeRow(kind: .positive, state: .due)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: due),
            HomeHabitLastCellInteraction(action: .complete, currentStateText: "Empty", nextActionText: "Mark done")
        )

        let completed = makeRow(kind: .positive, state: .completedToday)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: completed),
            HomeHabitLastCellInteraction(action: .skip, currentStateText: "Done", nextActionText: "Mark skipped")
        )

        let skipped = makeRow(kind: .positive, state: .skippedToday)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: skipped),
            HomeHabitLastCellInteraction(action: .clear, currentStateText: "Skipped", nextActionText: "Clear to empty")
        )
    }

    func testNegativeHabitCyclesSuccessThenLapseThenClear() {
        let due = makeRow(kind: .negative, state: .due)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: due),
            HomeHabitLastCellInteraction(action: .complete, currentStateText: "Empty", nextActionText: "Mark stayed clean")
        )

        let success = makeRow(kind: .negative, state: .completedToday)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: success),
            HomeHabitLastCellInteraction(action: .lapse, currentStateText: "Stayed clean", nextActionText: "Mark lapsed")
        )

        let lapsed = makeRow(kind: .negative, state: .lapsedToday)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: lapsed),
            HomeHabitLastCellInteraction(action: .clear, currentStateText: "Lapsed", nextActionText: "Clear to empty")
        )
    }

    func testLapseOnlyHabitCyclesLapseThenClear() {
        let tracking = HomeHabitRow(
            habitID: UUID(),
            title: "No phone in bed",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaName: "Health",
            iconSymbolName: "bed.double.fill",
            state: .tracking
        )
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: tracking),
            HomeHabitLastCellInteraction(
                action: .lapse,
                currentStateText: "Tracking",
                nextActionText: "Mark lapsed"
            )
        )

        let lapsed = HomeHabitRow(
            habitID: UUID(),
            title: "No phone in bed",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaName: "Health",
            iconSymbolName: "bed.double.fill",
            state: .lapsedToday
        )
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: lapsed),
            HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Lapsed",
                nextActionText: "Clear to tracking"
            )
        )
    }

    func testDailyCheckInStatesAlwaysResolveToAnAction() {
        let positiveTracking = makeRow(kind: .positive, state: .tracking)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: positiveTracking),
            HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: "Tracking",
                nextActionText: "Mark done"
            )
        )

        let positiveLapsed = makeRow(kind: .positive, state: .lapsedToday)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: positiveLapsed),
            HomeHabitLastCellInteraction(
                action: .clear,
                currentStateText: "Lapsed",
                nextActionText: "Clear to empty"
            )
        )

        let negativeTracking = makeRow(kind: .negative, state: .tracking)
        XCTAssertEqual(
            HomeHabitLastCellInteraction.resolve(for: negativeTracking),
            HomeHabitLastCellInteraction(
                action: .complete,
                currentStateText: "Tracking",
                nextActionText: "Mark stayed clean"
            )
        )
    }

    func testHitTargetMetricsComputeTrailingVisualWidthFromCellCount() {
        let metrics = HomeHabitRowHitTargetMetrics(
            stripWidth: 210,
            cellCount: 7,
            showsLastCellDecoration: true
        )

        XCTAssertEqual(metrics.visualLastCellWidth, 30, accuracy: 0.001)
    }

    func testHitTargetMetricsScaleTrailingVisualWidthOnWideRows() {
        let metrics = HomeHabitRowHitTargetMetrics(
            stripWidth: 560,
            cellCount: 7,
            showsLastCellDecoration: true
        )

        XCTAssertEqual(metrics.visualLastCellWidth, 80, accuracy: 0.001)
    }

    func testHitTargetMetricsHideTrailingVisualWidthWhenDecorationUnavailable() {
        let metrics = HomeHabitRowHitTargetMetrics(
            stripWidth: 210,
            cellCount: 7,
            showsLastCellDecoration: false
        )

        XCTAssertEqual(metrics.visualLastCellWidth, 0, accuracy: 0.001)
    }

    private func makeRow(kind: HabitKind, state: HomeHabitRowState) -> HomeHabitRow {
        HomeHabitRow(
            habitID: UUID(),
            title: "Habit",
            kind: kind,
            trackingMode: .dailyCheckIn,
            lifeAreaName: "Health",
            iconSymbolName: "star.fill",
            state: state
        )
    }
}
