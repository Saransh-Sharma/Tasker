import XCTest
@testable import To_Do_List

@MainActor
final class HabitBoardViewModelTests: XCTestCase {

    func testConfigureViewportMapsToViewportAndHistorySpan() {
        let viewModel = makeViewModel()

        viewModel.configureViewport(columnCount: 8, historySpan: 28)
        XCTAssertEqual(viewModel.viewportColumnCount, 8)
        XCTAssertEqual(viewModel.historySpan, 28)

        viewModel.configureViewport(columnCount: 12, historySpan: 42)
        XCTAssertEqual(viewModel.viewportColumnCount, 12)
        XCTAssertEqual(viewModel.historySpan, 42)
    }

    func testConfigureViewportKeepsHistorySpanAtLeastAsWideAsViewport() {
        let viewModel = makeViewModel()

        viewModel.configureViewport(columnCount: 10, historySpan: 7)

        XCTAssertEqual(viewModel.viewportColumnCount, 10)
        XCTAssertEqual(viewModel.historySpan, 10)
    }

    func testMoveWindowAdvancesByActiveViewportWindow() {
        let referenceDate = Self.date("2026-04-07")
        let viewModel = makeViewModel(endingOn: referenceDate)
        let calendar = Self.calendar

        viewModel.configureViewport(columnCount: 7, historySpan: 28)
        viewModel.moveWindow(byDays: viewModel.viewportColumnCount)

        XCTAssertEqual(
            calendar.startOfDay(for: viewModel.endingOn),
            calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: referenceDate))
        )
    }

    func testLayoutMetricsMapContainerWidthsToTargetColumnCounts() {
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(375, dynamicTypeSize: .medium).visibleColumns, 7)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(430, dynamicTypeSize: .medium).visibleColumns, 8)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(700, dynamicTypeSize: .medium).visibleColumns, 10)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(1024, dynamicTypeSize: .medium).visibleColumns, 12)
    }

    func testDisplayDepthRemapRampsVisibleRunFromOne() {
        let cells = [
            makeCell("2026-04-03", state: .done(depth: 5)),
            makeCell("2026-04-04", state: .done(depth: 6)),
            makeCell("2026-04-05", state: .done(depth: 7))
        ]

        let remapped = HabitBoardPresentationBuilder.remapVisibleDisplayDepths(in: cells)

        XCTAssertEqual(remapped.map(\.state), [
            .done(depth: 1),
            .done(depth: 2),
            .done(depth: 3)
        ])
    }

    func testDisplayDepthRemapPreservesContinuityAcrossBridgeCells() {
        let cells = [
            makeCell("2026-04-03", state: .done(depth: 6)),
            makeCell("2026-04-04", state: .bridge(kind: .middle, source: .skipped)),
            makeCell("2026-04-05", state: .done(depth: 7)),
            makeCell("2026-04-06", state: .done(depth: 8)),
            makeCell("2026-04-07", state: .missed),
            makeCell("2026-04-08", state: .done(depth: 1), isToday: true)
        ]

        let remapped = HabitBoardPresentationBuilder.remapVisibleDisplayDepths(in: cells)

        XCTAssertEqual(remapped[0].state, .done(depth: 1))
        XCTAssertEqual(remapped[1].state, .bridge(kind: .middle, source: .skipped))
        XCTAssertEqual(remapped[2].state, .done(depth: 2))
        XCTAssertEqual(remapped[3].state, .done(depth: 3))
        XCTAssertEqual(remapped[4].state, .missed)
        XCTAssertEqual(remapped[5].state, .done(depth: 1))
        XCTAssertEqual(
            HabitBoardPresentationBuilder.metrics(for: cells),
            HabitBoardPresentationBuilder.metrics(for: remapped)
        )
    }

    func testRefreshFiltersPausedHabitsFromBoardRows() {
        let activeHabitID = UUID()
        let pausedHabitID = UUID()
        let repository = HabitBoardReadRepositoryStub()
        repository.libraryRows = [
            makeLibraryRow(habitID: activeHabitID, title: "Active Habit", isPaused: false),
            makeLibraryRow(habitID: pausedHabitID, title: "Paused Habit", isPaused: true)
        ]
        repository.historyWindows = [
            HabitHistoryWindow(
                habitID: activeHabitID,
                marks: [HabitDayMark(date: Self.date("2026-04-08"), state: .success)]
            )
        ]
        let viewModel = HabitBoardViewModel(
            getHabitLibraryUseCase: GetHabitLibraryUseCase(readRepository: repository),
            getHabitHistoryUseCase: GetHabitHistoryUseCase(readRepository: repository),
            endingOn: Self.date("2026-04-14")
        )

        viewModel.refresh()
        waitUntil { !viewModel.libraryRows.isEmpty && !viewModel.boardRows.isEmpty }

        XCTAssertEqual(viewModel.libraryRows.map(\.title), ["Active Habit"])
        XCTAssertEqual(viewModel.boardRows.map(\.title), ["Active Habit"])
    }

    func testRefreshIgnoresStaleCallbacksFromOlderRequests() {
        let repository = HabitBoardReadRepositoryStub()
        let habitID = UUID()
        repository.libraryRows = [makeLibraryRow(habitID: habitID, title: "Hydrate", isPaused: false)]
        repository.deferLibraryCompletion = true
        repository.deferHistoryCompletion = true
        repository.queuedHistoryResults = [
            .success([
                HabitHistoryWindow(
                    habitID: habitID,
                    marks: [HabitDayMark(date: Self.date("2026-04-01"), state: .success)]
                )
            ]),
            .success([
                HabitHistoryWindow(
                    habitID: habitID,
                    marks: [HabitDayMark(date: Self.date("2026-04-08"), state: .success)]
                )
            ])
        ]
        let viewModel = HabitBoardViewModel(
            getHabitLibraryUseCase: GetHabitLibraryUseCase(readRepository: repository),
            getHabitHistoryUseCase: GetHabitHistoryUseCase(readRepository: repository),
            endingOn: Self.date("2026-04-07")
        )

        viewModel.refresh()
        viewModel.moveWindow(byDays: 7)
        XCTAssertEqual(repository.pendingLibraryCount, 2)

        repository.completePendingLibrary(at: 1)
        pumpMainQueue()
        XCTAssertEqual(repository.pendingHistoryCount, 1)
        repository.completePendingHistory(at: 0)
        pumpMainQueue()
        repository.completePendingLibrary(at: 0)
        pumpMainQueue()
        XCTAssertEqual(repository.pendingHistoryCount, 0)

        XCTAssertEqual(viewModel.endingOn, Self.date("2026-04-14"))
        XCTAssertEqual(viewModel.boardRows.count, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    private func makeViewModel(endingOn: Date = Date()) -> HabitBoardViewModel {
        let repository = HabitBoardReadRepositoryStub()
        return HabitBoardViewModel(
            getHabitLibraryUseCase: GetHabitLibraryUseCase(readRepository: repository),
            getHabitHistoryUseCase: GetHabitHistoryUseCase(readRepository: repository),
            endingOn: endingOn
        )
    }

    private func makeCell(_ value: String, state: HabitBoardCellState, isToday: Bool = false) -> HabitBoardCell {
        let date = Self.date(value)
        return HabitBoardCell(
            date: date,
            state: state,
            isToday: isToday,
            isWeekend: Self.calendar.isDateInWeekend(date)
        )
    }

    private func makeLibraryRow(
        habitID: UUID,
        title: String,
        isPaused: Bool
    ) -> HabitLibraryRow {
        HabitLibraryRow(
            habitID: habitID,
            title: title,
            kind: .positive,
            trackingMode: .dailyCheckIn,
            cadence: .daily(),
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
            isPaused: isPaused,
            isArchived: false,
            currentStreak: 3,
            bestStreak: 7,
            last14Days: []
        )
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

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.02,
        condition: @escaping () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while condition() == false && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        XCTAssertTrue(condition(), "Timed out waiting for condition")
    }

    private func pumpMainQueue(timeout: TimeInterval = 1.0) {
        let expectation = expectation(description: "main queue pump")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
}

private final class HabitBoardReadRepositoryStub: HabitRuntimeReadRepositoryProtocol {
    var libraryRows: [HabitLibraryRow] = []
    var historyWindows: [HabitHistoryWindow] = []
    var queuedHistoryResults: [Result<[HabitHistoryWindow], Error>] = []
    var deferLibraryCompletion = false
    var deferHistoryCompletion = false
    private var pendingLibraryResponses: [() -> Void] = []
    private var pendingHistoryResponses: [() -> Void] = []
    var pendingLibraryCount: Int { pendingLibraryResponses.count }
    var pendingHistoryCount: Int { pendingHistoryResponses.count }

    func fetchAgendaHabits(for date: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        let result = queuedHistoryResults.isEmpty ? Result.success(historyWindows) : queuedHistoryResults.removeFirst()
        let response = { completion(result) }
        if deferHistoryCompletion {
            pendingHistoryResponses.append(response)
        } else {
            response()
        }
    }

    func fetchSignals(start: Date, end: Date, completion: @escaping (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHabitLibrary(includeArchived: Bool, completion: @escaping (Result<[HabitLibraryRow], Error>) -> Void) {
        let response = { completion(.success(self.libraryRows)) }
        if deferLibraryCompletion {
            pendingLibraryResponses.append(response)
        } else {
            response()
        }
    }

    func completePendingLibrary(at index: Int) {
        let response = pendingLibraryResponses.remove(at: index)
        response()
    }

    func completePendingHistory(at index: Int) {
        let response = pendingHistoryResponses.remove(at: index)
        response()
    }
}
