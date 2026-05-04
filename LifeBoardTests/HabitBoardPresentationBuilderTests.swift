import CoreGraphics
import XCTest
@testable import LifeBoard

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
            .done(depth: 1),
            .done(depth: 2),
            .bridge(kind: .single, source: .skipped),
            .done(depth: 3),
            .done(depth: 4),
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

        XCTAssertEqual(cells.map(\.state), [.missed, .bridge(kind: .middle, source: .notScheduled), .todayPending])
        XCTAssertEqual(cells[1].date, date("2026-04-07"))
    }

    func testMetricsTreatSkipAndScheduledOffAsFrozenNotBroken() {
        let cells = [
            makeCell("2026-04-01", .done(depth: 1)),
            makeCell("2026-04-02", .done(depth: 2)),
            makeCell("2026-04-03", .bridge(kind: .single, source: .skipped)),
            makeCell("2026-04-04", .done(depth: 3)),
            makeCell("2026-04-05", .done(depth: 4)),
            makeCell("2026-04-06", .missed),
            makeCell("2026-04-07", .done(depth: 1)),
            makeCell("2026-04-08", .bridge(kind: .single, source: .notScheduled)),
            makeCell("2026-04-09", .done(depth: 2), isToday: true),
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
            makeCell("2026-04-01", .done(depth: 1)),
            makeCell("2026-04-02", .done(depth: 2)),
            makeCell("2026-04-03", .todayPending, isToday: true),
        ]
        let secondRowCells = [
            makeCell("2026-04-01", .missed),
            makeCell("2026-04-02", .done(depth: 1)),
            makeCell("2026-04-03", .done(depth: 2)),
        ]

        let aggregate = HabitBoardPresentationBuilder.aggregateDays(
            from: [
                HabitBoardRowPresentation(
                    habitID: UUID(),
                    title: "Journal",
                    iconSymbolName: "book",
                    accentHex: "#4E9A2F",
                    colorFamily: .green,
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
                    colorFamily: .blue,
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
        XCTAssertEqual(split.recovery.map(\.title), ["Read", "Sleep"])
        XCTAssertEqual(split.quiet.map(\.title), ["No Sugar"])
    }

    func testColorFamilyNormalizesExistingAccentHex() {
        XCTAssertEqual(HabitColorFamily.family(for: "#4A86E8"), .blue)
        XCTAssertEqual(HabitColorFamily.family(for: "#E94C3D"), .coral)
        XCTAssertEqual(HabitColorFamily.family(for: "#5AA7A4"), .teal)
    }

    func testBridgeKindClassifiesLongNotScheduledRun() {
        let referenceDate = date("2026-04-06")
        let cadence = HabitCadenceDraft.weekly(daysOfWeek: [1, 4])

        let cells = HabitBoardPresentationBuilder.buildCells(
            marks: [
                HabitDayMark(date: date("2026-04-01"), state: .success),
                HabitDayMark(date: date("2026-04-05"), state: .success)
            ],
            cadence: cadence,
            referenceDate: referenceDate,
            dayCount: 6,
            calendar: Self.calendar
        )

        XCTAssertEqual(cells[1].state, .bridge(kind: .start, source: .notScheduled))
        XCTAssertEqual(cells[2].state, .bridge(kind: .middle, source: .notScheduled))
        XCTAssertEqual(cells[3].state, .bridge(kind: .end, source: .notScheduled))
    }

    func testHabitDetailCalendarBuildsFullWeeksAndKeepsOffCadenceDaysEditable() {
        let row = HabitLibraryRow(
            habitID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .weekly(daysOfWeek: [2, 4, 6]),
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
            isPaused: false,
            isArchived: false,
            currentStreak: 2,
            bestStreak: 5
        )

        let weeks = HabitDetailCalendarBuilder.buildWeeks(
            row: row,
            marks: [
                HabitDayMark(date: date("2026-04-06"), state: .success),
                HabitDayMark(date: date("2026-04-08"), state: .skipped)
            ],
            referenceDate: date("2026-04-10"),
            dayCount: 14,
            calendar: Self.calendar
        )

        XCTAssertEqual(weeks.count, 3)
        XCTAssertTrue(weeks.allSatisfy { $0.cells.count == 7 })
        XCTAssertEqual(weeks[0].monthLabel, "March 2026")

        let flattenedCells = weeks.flatMap(\.cells)
        let mondayCell = try! XCTUnwrap(flattenedCells.first(where: { $0.date == date("2026-04-06") }))
        let tuesdayCell = try! XCTUnwrap(flattenedCells.first(where: { $0.date == date("2026-04-07") }))
        let wednesdayCell = try! XCTUnwrap(flattenedCells.first(where: { $0.date == date("2026-04-08") }))

        XCTAssertEqual(mondayCell.state, .success)
        XCTAssertEqual(tuesdayCell.state, .notScheduled)
        XCTAssertEqual(wednesdayCell.state, .skipped)
        XCTAssertTrue(tuesdayCell.isInteractive)
    }

    func testHabitDetailCalendarMutationCycleMatchesPositiveDailyCheckIn() {
        let row = HabitLibraryRow(
            habitID: UUID(),
            title: "Read",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Mind",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )

        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: row, state: .empty), .resolve(.complete))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: row, state: .notScheduled), .resolve(.complete))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: row, state: .success), .resolve(.skip))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: row, state: .skipped), .reset)
    }

    func testHabitDetailCalendarMutationCycleMatchesNegativeModes() {
        let dailyRow = HabitLibraryRow(
            habitID: UUID(),
            title: "No sugar",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )
        let lapseOnlyRow = HabitLibraryRow(
            habitID: UUID(),
            title: "No smoking",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )

        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: dailyRow, state: .empty), .resolve(.abstained))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: dailyRow, state: .notScheduled), .resolve(.abstained))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: dailyRow, state: .success), .resolve(.lapsed))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: dailyRow, state: .lapsed), .reset)
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: lapseOnlyRow, state: .empty), .resolve(.lapsed))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: lapseOnlyRow, state: .notScheduled), .resolve(.lapsed))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: lapseOnlyRow, state: .success), .resolve(.lapsed))
        XCTAssertEqual(HabitDetailCalendarBuilder.nextMutation(for: lapseOnlyRow, state: .lapsed), .resolve(.abstained))
    }

    func testHabitDetailCalendarMutationFeedbackLabelsTargetStateAndHaptic() {
        let positiveRow = HabitLibraryRow(
            habitID: UUID(),
            title: "Read",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Mind",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )
        let negativeRow = HabitLibraryRow(
            habitID: UUID(),
            title: "No sugar",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )
        let day = date("2026-04-20")

        let completeFeedback = HabitDetailCalendarBuilder.mutationFeedback(
            for: .resolve(.complete),
            row: positiveRow,
            date: day,
            calendar: Self.calendar
        )
        XCTAssertTrue(completeFeedback.message.contains("Marked complete"))
        XCTAssertEqual(completeFeedback.haptic, .success)

        let cleanFeedback = HabitDetailCalendarBuilder.mutationFeedback(
            for: .resolve(.abstained),
            row: negativeRow,
            date: day,
            calendar: Self.calendar
        )
        XCTAssertTrue(cleanFeedback.message.contains("Marked clean"))
        XCTAssertEqual(cleanFeedback.haptic, .success)

        let lapsedFeedback = HabitDetailCalendarBuilder.mutationFeedback(
            for: .resolve(.lapsed),
            row: negativeRow,
            date: day,
            calendar: Self.calendar
        )
        XCTAssertTrue(lapsedFeedback.message.contains("Marked lapsed"))
        XCTAssertEqual(lapsedFeedback.haptic, .warning)

        let resetFeedback = HabitDetailCalendarBuilder.mutationFeedback(
            for: .reset,
            row: positiveRow,
            date: day,
            calendar: Self.calendar
        )
        XCTAssertTrue(resetFeedback.message.contains("Cleared to empty"))
        XCTAssertEqual(resetFeedback.haptic, .selection)
    }

    func testHabitDetailCalendarViewStatePrecomputesAccessibilityStrings() {
        let row = HabitLibraryRow(
            habitID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 3,
            bestStreak: 7
        )

        let viewState = HabitDetailCalendarBuilder.buildViewState(
            row: row,
            marks: [HabitDayMark(date: date("2026-04-10"), state: .success)],
            referenceDate: date("2026-04-10"),
            dayCount: 7,
            calendar: Self.calendar
        )

        let todayCell = try! XCTUnwrap(viewState.weeks.last?.cells.last(where: { $0.cell.isToday }))
        XCTAssertEqual(viewState.helperText, "Tap a day to mark it done or skipped.")
        XCTAssertEqual(todayCell.dayNumber, "10")
        XCTAssertEqual(todayCell.accessibilityValue, "Done")
        XCTAssertEqual(todayCell.accessibilityHint, "Double-tap to mark skipped.")
        XCTAssertEqual(todayCell.accessibilityIdentifier, "habitDetail.cell.2026-04-10")
        XCTAssertTrue(todayCell.accessibilityLabel.contains("Friday"))
    }

    func testHabitDetailCalendarViewStateCarriesStreakDepthAcrossSkippedAndNotScheduledDays() {
        let row = HabitLibraryRow(
            habitID: UUID(),
            title: "Hydrate",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .weekly(daysOfWeek: [2, 4, 6]),
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )

        let viewState = HabitDetailCalendarBuilder.buildViewState(
            row: row,
            marks: [
                HabitDayMark(date: date("2026-04-06"), state: .success),
                HabitDayMark(date: date("2026-04-08"), state: .success),
                HabitDayMark(date: date("2026-04-10"), state: .success),
            ],
            referenceDate: date("2026-04-10"),
            dayCount: 7,
            calendar: Self.calendar
        )
        let cells = viewState.weeks.flatMap(\.cells)

        let monday = try! XCTUnwrap(cells.first(where: { $0.cell.date == date("2026-04-06") }))
        let tuesday = try! XCTUnwrap(cells.first(where: { $0.cell.date == date("2026-04-07") }))
        let wednesday = try! XCTUnwrap(cells.first(where: { $0.cell.date == date("2026-04-08") }))
        let thursday = try! XCTUnwrap(cells.first(where: { $0.cell.date == date("2026-04-09") }))
        let friday = try! XCTUnwrap(cells.first(where: { $0.cell.date == date("2026-04-10") }))

        XCTAssertEqual(monday.cell.state, .success)
        XCTAssertEqual(monday.streakDepth, 1)
        XCTAssertEqual(tuesday.cell.state, .notScheduled)
        XCTAssertNil(tuesday.streakDepth)
        XCTAssertEqual(wednesday.cell.state, .success)
        XCTAssertEqual(wednesday.streakDepth, 2)
        XCTAssertEqual(thursday.cell.state, .notScheduled)
        XCTAssertNil(thursday.streakDepth)
        XCTAssertEqual(friday.cell.state, .success)
        XCTAssertEqual(friday.streakDepth, 3)
    }

    func testHabitDetailCalendarViewStateResetsStreakDepthAfterLapseAndEmptyDays() {
        let negativeRow = HabitLibraryRow(
            habitID: UUID(),
            title: "No smoking",
            kind: .negative,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )

        let negativeViewState = HabitDetailCalendarBuilder.buildViewState(
            row: negativeRow,
            marks: [
                HabitDayMark(date: date("2026-04-08"), state: .success),
                HabitDayMark(date: date("2026-04-09"), state: .failure),
                HabitDayMark(date: date("2026-04-10"), state: .success),
            ],
            referenceDate: date("2026-04-10"),
            dayCount: 3,
            calendar: Self.calendar
        )
        let negativeCells = negativeViewState.weeks.flatMap(\.cells)
        let dayEight = try! XCTUnwrap(negativeCells.first(where: { $0.cell.date == date("2026-04-08") }))
        let dayNine = try! XCTUnwrap(negativeCells.first(where: { $0.cell.date == date("2026-04-09") }))
        let dayTen = try! XCTUnwrap(negativeCells.first(where: { $0.cell.date == date("2026-04-10") }))

        XCTAssertEqual(dayEight.cell.state, .success)
        XCTAssertEqual(dayEight.streakDepth, 1)
        XCTAssertEqual(dayNine.cell.state, .lapsed)
        XCTAssertNil(dayNine.streakDepth)
        XCTAssertEqual(dayTen.cell.state, .success)
        XCTAssertEqual(dayTen.streakDepth, 1)

        let positiveRow = HabitLibraryRow(
            habitID: UUID(),
            title: "Read",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: UUID(),
            lifeAreaName: "Mind",
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 0
        )
        let positiveViewState = HabitDetailCalendarBuilder.buildViewState(
            row: positiveRow,
            marks: [
                HabitDayMark(date: date("2026-04-08"), state: .success),
                HabitDayMark(date: date("2026-04-09"), state: .success),
                HabitDayMark(date: date("2026-04-11"), state: .success),
            ],
            referenceDate: date("2026-04-11"),
            dayCount: 4,
            calendar: Self.calendar
        )
        let positiveCells = positiveViewState.weeks.flatMap(\.cells)
        let dayEleven = try! XCTUnwrap(positiveCells.first(where: { $0.cell.date == date("2026-04-11") }))

        XCTAssertEqual(dayEleven.cell.state, .success)
        XCTAssertEqual(dayEleven.streakDepth, 1)
    }

    func testHabitDetailCalendarLayoutMetricsPreserveMinimumTapTarget() {
        XCTAssertGreaterThanOrEqual(HabitDetailCalendarLayoutMetrics.cellSide(for: 351), 44)
        XCTAssertLessThanOrEqual(HabitDetailCalendarLayoutMetrics.cellSide(for: 800), 52)
        XCTAssertGreaterThanOrEqual(HabitDetailCalendarLayoutMetrics.requiredWidth(for: 320), CGFloat(44 * 7))
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
