import XCTest
@testable import To_Do_List

final class QuietTrackingRailPresentationTests: XCTestCase {
    func testRailCardsPreserveStableRowOrderAndMetadata() {
        let firstRow = makeRow(
            title: "No smoking",
            iconSymbolName: "nosign",
            accentHex: "#4A86E8",
            currentStreak: 10,
            expandedCells: makeCells(count: 30, startingAt: Date(timeIntervalSince1970: 0))
        )
        let secondRow = makeRow(
            title: "No doomscrolling",
            iconSymbolName: "moon.zzz",
            accentHex: "#E94C3D",
            currentStreak: 4,
            expandedCells: makeCells(count: 30, startingAt: Date(timeIntervalSince1970: 86_400))
        )

        let cards = QuietTrackingSummaryState(stableRows: [firstRow, secondRow]).railCards

        XCTAssertEqual(cards.map(\.id), [firstRow.id, secondRow.id])
        XCTAssertEqual(cards.map(\.title), ["No smoking", "No doomscrolling"])
        XCTAssertEqual(cards.map(\.iconSymbolName), ["nosign", "moon.zzz"])
        XCTAssertEqual(cards.map(\.colorFamily), [.blue, .coral])
        XCTAssertEqual(cards.map { $0.historyCells.count }, [30, 30])
        XCTAssertEqual(cards.first?.accessibilityLabel, "No smoking")
        XCTAssertEqual(cards.first?.accessibilityValue(visibleDayCount: 12), "Current streak 10 days. Last 12 days shown.")
    }

    func testRailCardUsesExpandedHistoryPool() {
        let expandedCells = makeCells(count: 30, startingAt: Date(timeIntervalSince1970: 0))
        let row = makeRow(
            title: "No sugar",
            currentStreak: 7,
            expandedCells: expandedCells
        )

        let card = QuietTrackingSummaryState(stableRows: [row]).railCards[0]

        XCTAssertEqual(card.historyCells.count, 30)
        XCTAssertEqual(card.historyCells.map(\.date), expandedCells.map(\.date))
        XCTAssertEqual(card.visibleCells(dayCount: 9).map(\.date), Array(expandedCells.suffix(9)).map(\.date))
    }

    func testRailCardBuildsThirtyCellsWhenExpandedHistoryIsUnavailable() {
        let marks = makeMarks(count: 14, startingAt: Date(timeIntervalSince1970: 0))
        let row = makeRow(
            title: "No nicotine",
            currentStreak: 14,
            expandedCells: [],
            marks: marks
        )

        let card = QuietTrackingSummaryState(stableRows: [row]).railCards[0]
        let expectedDates = HabitBoardPresentationBuilder.buildCells(
            marks: marks,
            cadence: .daily(),
            referenceDate: marks.last?.date ?? Date(),
            dayCount: 30
        ).map(\.date)

        XCTAssertEqual(card.historyCells.count, 30)
        XCTAssertEqual(card.historyCells.map(\.date), expectedDates)
    }

    func testRailLayoutUsesFullWidthForSingleCard() {
        let spec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 1,
            historyCellCount: 30,
            interItemSpacing: 8
        )

        XCTAssertEqual(spec.visibleColumnCount, 1)
        XCTAssertEqual(spec.slotWidth, 300, accuracy: 0.001)
        XCTAssertEqual(spec.visibleDayCount, 21)
        XCTAssertFalse(spec.shouldScroll)
    }

    func testRailLayoutSplitsWidthForTwoAndThreeCards() {
        let twoCardSpec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 2,
            historyCellCount: 30,
            interItemSpacing: 8
        )
        let threeCardSpec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 3,
            historyCellCount: 30,
            interItemSpacing: 8
        )

        XCTAssertEqual(twoCardSpec.visibleColumnCount, 2)
        XCTAssertEqual(twoCardSpec.slotWidth, 146, accuracy: 0.001)
        XCTAssertEqual(twoCardSpec.visibleDayCount, 10)
        XCTAssertFalse(twoCardSpec.shouldScroll)

        XCTAssertEqual(threeCardSpec.visibleColumnCount, 3)
        XCTAssertEqual(threeCardSpec.slotWidth, 94, accuracy: 0.001)
        XCTAssertEqual(threeCardSpec.visibleDayCount, 6)
        XCTAssertFalse(threeCardSpec.shouldScroll)
    }

    func testRailLayoutKeepsThreeColumnWidthForFourPlusCards() {
        let spec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 5,
            historyCellCount: 30,
            interItemSpacing: 8
        )

        XCTAssertEqual(spec.visibleColumnCount, 3)
        XCTAssertEqual(spec.slotWidth, 94, accuracy: 0.001)
        XCTAssertEqual(spec.visibleDayCount, 6)
        XCTAssertTrue(spec.shouldScroll)
    }

    func testRailLayoutClampsVisibleDayCountToHistoryPoolAndShrinksWithWidth() {
        let clampedSpec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 1,
            historyCellCount: 4,
            interItemSpacing: 8
        )
        let wideSpec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 300,
            totalCardCount: 1,
            historyCellCount: 30,
            interItemSpacing: 8
        )
        let narrowSpec = QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: 100,
            totalCardCount: 1,
            historyCellCount: 30,
            interItemSpacing: 8
        )

        XCTAssertEqual(clampedSpec.visibleDayCount, 4)
        XCTAssertEqual(narrowSpec.visibleDayCount, 7)
        XCTAssertLessThan(narrowSpec.visibleDayCount, wideSpec.visibleDayCount)
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
