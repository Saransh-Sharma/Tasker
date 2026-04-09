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

    func testLapseOnlyRowsAreNotEligible() {
        let row = HomeHabitRow(
            habitID: UUID(),
            title: "No phone in bed",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaName: "Health",
            iconSymbolName: "bed.double.fill",
            state: .tracking
        )

        XCTAssertNil(HomeHabitLastCellInteraction.resolve(for: row))
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
