import XCTest
@testable import To_Do_List

final class HabitBoardPresentationBuilderTests: XCTestCase {

    func testBuildCellsAssignsRunDepthAndSkipsFreezeWithoutBreaking() {
        let referenceDate = date("2026-04-05")
        let cells = HabitBoardPresentationBuilder.buildCells(
            marks: [
                HabitDayMark(date: date("2026-04-01"), state: .success),
                HabitDayMark(date: date("2026-04-02"), state: .success),
                HabitDayMark(date: date("2026-04-03"), state: .skipped),
                HabitDayMark(date: date("2026-04-04"), state: .success),
                HabitDayMark(date: date("2026-04-05"), state: .success),
            ],
            cadence: .daily(),
            referenceDate: referenceDate,
            dayCount: 5,
            calendar: Self.calendar
        )

        XCTAssertEqual(cells.map(\.state), [
            .success(runDepth: 1),
            .success(runDepth: 2),
            .skipped,
            .success(runDepth: 3),
            .success(runDepth: 4),
        ])
        XCTAssertTrue(cells.last?.isToday ?? false)
    }

    func testBuildCellsDerivesScheduledOffFromCadence() {
        let monday = date("2026-04-06")
        let wednesday = date("2026-04-08")
        let cadence = HabitCadenceDraft.weekly(
            daysOfWeek: [
                Self.calendar.component(.weekday, from: monday),
                Self.calendar.component(.weekday, from: wednesday),
            ]
        )

        let cells = HabitBoardPresentationBuilder.buildCells(
            marks: [],
            cadence: cadence,
            referenceDate: wednesday,
            dayCount: 3,
            calendar: Self.calendar
        )

        XCTAssertEqual(cells.map(\.state), [.none, .scheduledOff, .none])
        XCTAssertEqual(cells[1].date, date("2026-04-07"))
    }

    func testMetricsTreatSkipAndScheduledOffAsFrozenNotBroken() {
        let cells = [
            makeCell("2026-04-01", .success(runDepth: 1)),
            makeCell("2026-04-02", .success(runDepth: 2)),
            makeCell("2026-04-03", .skipped),
            makeCell("2026-04-04", .success(runDepth: 3)),
            makeCell("2026-04-05", .success(runDepth: 4)),
            makeCell("2026-04-06", .failure),
            makeCell("2026-04-07", .success(runDepth: 1)),
            makeCell("2026-04-08", .scheduledOff),
            makeCell("2026-04-09", .success(runDepth: 2), isToday: true),
        ]

        let metrics = HabitBoardPresentationBuilder.metrics(for: cells)

        XCTAssertEqual(metrics.currentStreak, 2)
        XCTAssertEqual(metrics.bestStreak, 4)
        XCTAssertEqual(metrics.totalCount, 6)
        XCTAssertEqual(metrics.weekCount, 4)
        XCTAssertEqual(metrics.monthCount, 6)
        XCTAssertEqual(metrics.yearCount, 6)
    }

    func testAggregateDaysSummarizesVisibleCompletionsByColumn() {
        let firstRowCells = [
            makeCell("2026-04-01", .success(runDepth: 1)),
            makeCell("2026-04-02", .success(runDepth: 2)),
            makeCell("2026-04-03", .none, isToday: true),
        ]
        let secondRowCells = [
            makeCell("2026-04-01", .none),
            makeCell("2026-04-02", .success(runDepth: 1)),
            makeCell("2026-04-03", .success(runDepth: 2)),
        ]

        let aggregate = HabitBoardPresentationBuilder.aggregateDays(
            from: [
                HabitBoardRowPresentation(
                    habitID: UUID(),
                    title: "Journal",
                    iconSymbolName: "book",
                    accentHex: "#4E9A2F",
                    currentStreak: 2,
                    bestStreak: 2,
                    cells: firstRowCells,
                    metrics: HabitBoardPresentationBuilder.metrics(for: firstRowCells)
                ),
                HabitBoardRowPresentation(
                    habitID: UUID(),
                    title: "Walk",
                    iconSymbolName: "figure.walk",
                    accentHex: "#4A86E8",
                    currentStreak: 1,
                    bestStreak: 1,
                    cells: secondRowCells,
                    metrics: HabitBoardPresentationBuilder.metrics(for: secondRowCells)
                ),
            ],
            dayCount: 3
        )

        XCTAssertEqual(aggregate.map(\.completedCount), [1, 2, 1])
        XCTAssertEqual(aggregate.map(\.habitCount), [2, 2, 2])
        XCTAssertEqual(aggregate.last?.isToday, true)
    }

    func testSplitHomeRowsSeparatesPrimaryRecoveryAndQuietTracking() {
        let split = HabitBoardPresentationBuilder.splitHomeRows([
            makeRow(title: "Stretch", state: .due, currentStreak: 5),
            makeRow(title: "Meditate", state: .due, currentStreak: 2),
            makeRow(title: "Read", state: .overdue, currentStreak: 3),
            makeRow(title: "No Sugar", state: .tracking, currentStreak: 12, trackingMode: .lapseOnly),
            makeRow(title: "Sleep", state: .due, currentStreak: 8, riskState: .atRisk),
        ])

        XCTAssertEqual(split.primary.map(\.title), ["Stretch", "Meditate"])
        XCTAssertEqual(split.recovery.map(\.title), ["Sleep", "Read"])
        XCTAssertEqual(split.quiet.map(\.title), ["No Sugar"])
    }

    private func makeRow(
        title: String,
        state: HomeHabitRowState,
        currentStreak: Int,
        trackingMode: HabitTrackingMode = .dailyCheckIn,
        riskState: HabitRiskState = .stable
    ) -> HomeHabitRow {
        HomeHabitRow(
            habitID: UUID(),
            title: title,
            kind: .positive,
            trackingMode: trackingMode,
            lifeAreaName: "Health",
            iconSymbolName: "star.fill",
            state: state,
            currentStreak: currentStreak,
            bestStreak: currentStreak,
            riskState: riskState
        )
    }

    private func makeCell(
        _ value: String,
        _ state: HabitBoardCellState,
        isToday: Bool = false
    ) -> HabitBoardCell {
        let day = date(value)
        return HabitBoardCell(
            date: day,
            state: state,
            isToday: isToday,
            isWeekend: Self.calendar.isDateInWeekend(day)
        )
    }

    private func date(_ value: String) -> Date {
        Self.date(value)
    }

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date.distantPast
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}
