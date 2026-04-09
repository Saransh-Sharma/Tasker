import XCTest
@testable import To_Do_List

final class QuietTrackingRailPresentationTests: XCTestCase {
    func testRailCardsPreserveStableRowOrderAndMetadata() {
        let firstRow = makeRow(
            title: "No smoking",
            iconSymbolName: "nosign",
            accentHex: "#4A86E8",
            currentStreak: 10,
            expandedCells: makeCells(count: 10, startingAt: Date(timeIntervalSince1970: 0))
        )
        let secondRow = makeRow(
            title: "No doomscrolling",
            iconSymbolName: "moon.zzz",
            accentHex: "#E94C3D",
            currentStreak: 4,
            expandedCells: makeCells(count: 10, startingAt: Date(timeIntervalSince1970: 86_400))
        )

        let cards = QuietTrackingSummaryState(stableRows: [firstRow, secondRow]).railCards

        XCTAssertEqual(cards.map(\.id), [firstRow.id, secondRow.id])
        XCTAssertEqual(cards.map(\.title), ["No smoking", "No doomscrolling"])
        XCTAssertEqual(cards.map(\.iconSymbolName), ["nosign", "moon.zzz"])
        XCTAssertEqual(cards.map(\.colorFamily), [.blue, .coral])
        XCTAssertEqual(cards.first?.accessibilityLabel, "No smoking")
        XCTAssertEqual(cards.first?.accessibilityValue, "Current streak 10 days. Last 7 days shown.")
    }

    func testRailCardUsesMostRecentSevenExpandedCells() {
        let expandedCells = makeCells(count: 12, startingAt: Date(timeIntervalSince1970: 0))
        let row = makeRow(
            title: "No sugar",
            currentStreak: 7,
            expandedCells: expandedCells
        )

        let card = QuietTrackingSummaryState(stableRows: [row]).railCards[0]

        XCTAssertEqual(card.cells.count, 7)
        XCTAssertEqual(card.cells.map(\.date), Array(expandedCells.suffix(7)).map(\.date))
    }

    func testRailCardBuildsSevenCellsWhenExpandedHistoryIsUnavailable() {
        let marks = makeMarks(count: 14, startingAt: Date(timeIntervalSince1970: 0))
        let row = makeRow(
            title: "No nicotine",
            currentStreak: 14,
            expandedCells: [],
            marks: marks
        )

        let card = QuietTrackingSummaryState(stableRows: [row]).railCards[0]
        let expectedDates = Array(marks.suffix(7)).map { Calendar.current.startOfDay(for: $0.date) }

        XCTAssertEqual(card.cells.count, 7)
        XCTAssertEqual(card.cells.map(\.date), expectedDates)
    }

    private func makeRow(
        title: String,
        iconSymbolName: String = "flame.fill",
        accentHex: String? = "#4E9A2F",
        currentStreak: Int,
        expandedCells: [HabitBoardCell],
        marks: [HabitDayMark] = []
    ) -> HomeHabitRow {
        HomeHabitRow(
            habitID: UUID(),
            title: title,
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            projectID: nil,
            projectName: nil,
            iconSymbolName: iconSymbolName,
            accentHex: accentHex,
            cadence: .daily(),
            cadenceLabel: "Every day",
            dueAt: expandedCells.last?.date ?? marks.last?.date,
            state: .tracking,
            currentStreak: currentStreak,
            bestStreak: currentStreak,
            last14Days: marks,
            boardCellsCompact: [],
            boardCellsExpanded: expandedCells,
            riskState: .stable,
            helperText: nil
        )
    }

    private func makeCells(count: Int, startingAt startDate: Date) -> [HabitBoardCell] {
        let calendar = Calendar.current
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return HabitBoardCell(
                date: calendar.startOfDay(for: date),
                state: .done(depth: min(offset + 1, 8)),
                isToday: offset == count - 1,
                isWeekend: calendar.isDateInWeekend(date)
            )
        }
    }

    private func makeMarks(count: Int, startingAt startDate: Date) -> [HabitDayMark] {
        let calendar = Calendar.current
        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return HabitDayMark(date: date, state: .success)
        }
    }
}
