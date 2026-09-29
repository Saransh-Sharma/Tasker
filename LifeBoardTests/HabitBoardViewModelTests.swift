import XCTest
@testable import LifeBoard

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
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(430, dynamicTypeSize: .medium).visibleColumns, 7)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(700, dynamicTypeSize: .medium).visibleColumns, 7)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(1024, dynamicTypeSize: .medium).visibleColumns, 7)
    }

    func testLayoutMetricsKeepSevenColumnsForAccessibilityDynamicType() {
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(375, dynamicTypeSize: .accessibility1).visibleColumns, 7)
        XCTAssertEqual(HabitBoardLayoutMetrics.forContainerWidth(834, dynamicTypeSize: .accessibility3).visibleColumns, 7)
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
    private struct State {
        var libraryRows: [HabitLibraryRow] = []
        var historyWindows: [HabitHistoryWindow] = []
        var queuedHistoryResults: [Result<[HabitHistoryWindow], Error>] = []
        var deferLibraryCompletion = false
        var deferHistoryCompletion = false
        var pendingLibraryResponses: [@Sendable () -> Void] = []
        var pendingHistoryResponses: [@Sendable () -> Void] = []
    }

    private let state = LockedTestState(State())

    var libraryRows: [HabitLibraryRow] {
        get { state.read().libraryRows }
        set { state.withValue { $0.libraryRows = newValue } }
    }
    var historyWindows: [HabitHistoryWindow] {
        get { state.read().historyWindows }
        set { state.withValue { $0.historyWindows = newValue } }
    }
    var queuedHistoryResults: [Result<[HabitHistoryWindow], Error>] {
        get { state.read().queuedHistoryResults }
        set { state.withValue { $0.queuedHistoryResults = newValue } }
    }
    var deferLibraryCompletion: Bool {
        get { state.read().deferLibraryCompletion }
        set { state.withValue { $0.deferLibraryCompletion = newValue } }
    }
    var deferHistoryCompletion: Bool {
        get { state.read().deferHistoryCompletion }
        set { state.withValue { $0.deferHistoryCompletion = newValue } }
    }
    var pendingLibraryCount: Int { state.read().pendingLibraryResponses.count }
    var pendingHistoryCount: Int { state.read().pendingHistoryResponses.count }

    func fetchAgendaHabits(for date: Date, completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping @Sendable (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        let immediateResponse = state.withValue { state -> (@Sendable () -> Void)? in
            let result = state.queuedHistoryResults.isEmpty
                ? Result.success(state.historyWindows)
                : state.queuedHistoryResults.removeFirst()
            let response: @Sendable () -> Void = { completion(result) }
            if state.deferHistoryCompletion {
                state.pendingHistoryResponses.append(response)
                return nil
            }
            return response
        }
        immediateResponse?()
    }

    func fetchSignals(start: Date, end: Date, completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHabitLibrary(includeArchived: Bool, completion: @escaping @Sendable (Result<[HabitLibraryRow], Error>) -> Void) {
        let immediateResponse = state.withValue { state -> (@Sendable () -> Void)? in
            let rows = state.libraryRows
            let response: @Sendable () -> Void = { completion(.success(rows)) }
            if state.deferLibraryCompletion {
                state.pendingLibraryResponses.append(response)
                return nil
            }
            return response
        }
        immediateResponse?()
    }

    func completePendingLibrary(at index: Int) {
        let response = state.withValue { $0.pendingLibraryResponses.remove(at: index) }
        response()
    }

    func completePendingHistory(at index: Int) {
        let response = state.withValue { $0.pendingHistoryResponses.remove(at: index) }
        response()
    }
}

/// One first light per calendar day, persisted, shared by both boundaries.
final class FirstLightGateTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        let name = "FirstLightGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        // Re-open the suite in the teardown rather than capturing the instance;
        // UserDefaults is not Sendable under strict concurrency.
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testFirstClaimWinsAndTheSameDayNeverClaimsAgain() throws {
        let gate = FirstLightGate(defaults: try makeDefaults(), calendar: Calendar(identifier: .gregorian))
        let morning = date(2026, 9, 17, hour: 8)
        XCTAssertTrue(gate.isAvailable(now: morning))
        XCTAssertTrue(gate.claim(now: morning))
        XCTAssertFalse(gate.claim(now: morning))
        XCTAssertFalse(gate.claim(now: date(2026, 9, 17, hour: 23)))
        XCTAssertFalse(gate.isAvailable(now: date(2026, 9, 17, hour: 23)))
    }

    func testTheNextDayReArmsAndTheClaimSurvivesANewGateOverTheSameStore() throws {
        let defaults = try makeDefaults()
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertTrue(FirstLightGate(defaults: defaults, calendar: calendar).claim(now: date(2026, 9, 17)))
        // A relaunch builds a new gate over the same defaults: still claimed.
        XCTAssertFalse(FirstLightGate(defaults: defaults, calendar: calendar).claim(now: date(2026, 9, 17, hour: 20)))
        XCTAssertTrue(FirstLightGate(defaults: defaults, calendar: calendar).claim(now: date(2026, 9, 18, hour: 0)))
        XCTAssertEqual(FirstLightGate.dayKey(for: date(2026, 9, 18), calendar: calendar), "2026-9-18")
    }

    /// Only the surface that recorded the commitment sweeps: the source and
    /// token survive the shell's forwarding.
    func testCommitmentSourceAndTokenReadBackFromTheNotification() {
        let composer = Notification(name: .lifeboardFirstLightFired, object: nil, userInfo: [
            FirstLightCommitment.sourceKey: FirstLightCommitment.Source.composer.rawValue,
            FirstLightCommitment.tokenKey: "abc"
        ])
        XCTAssertEqual(FirstLightCommitment.source(of: composer), .composer)
        XCTAssertEqual(FirstLightCommitment.token(of: composer), "abc")

        let habit = Notification(name: .lifeboardFirstLightFired, object: nil, userInfo: ["source": "habit"])
        XCTAssertEqual(FirstLightCommitment.source(of: habit), .habit)
        XCTAssertNil(FirstLightCommitment.source(of: Notification(name: .lifeboardFirstLightFired)))
    }
}

/// The pure half of "Enter amount": drum ranges, unit conversion, and the
/// single `.set` the sheet commits.
final class HabitAmountEntryTests: XCTestCase {
    func testTimedTargetsEditInMinutesAndStoreSeconds() throws {
        let target = HabitTarget.timed(seconds: 20 * 60)
        let drum = try XCTUnwrap(HabitAmountEntry.drum(for: target, current: 5 * 60))
        XCTAssertEqual(drum.unit, "min")
        XCTAssertEqual(drum.range, 0...40)
        XCTAssertEqual(HabitAmountEntry.displayValue(5 * 60, target: target), 5)
        XCTAssertEqual(HabitAmountEntry.change(from: 5 * 60, toDisplay: 12, target: target), .set(12 * 60))
        XCTAssertNil(HabitAmountEntry.change(from: 5 * 60, toDisplay: 5, target: target), "No movement, no write")
        XCTAssertEqual(HabitAmountEntry.receipt(title: "Read", value: 12 * 60, target: target), "Read set to 12 of 20 minutes")
    }

    func testQuantitativeTargetsKeepTheirUnitAndClampAtZero() throws {
        let target = HabitTarget.quantitative(value: 8, unit: "glasses")
        let drum = try XCTUnwrap(HabitAmountEntry.drum(for: target, current: 10))
        XCTAssertEqual(drum.unit, "glasses")
        XCTAssertEqual(drum.range.upperBound, 16)
        XCTAssertEqual(HabitAmountEntry.change(from: 0, toDisplay: 5, target: target), .set(5))
        XCTAssertEqual(HabitAmountEntry.change(from: 3, toDisplay: -2, target: target), .set(0))
        XCTAssertEqual(HabitAmountEntry.receipt(title: "Water", value: 5, target: target), "Water set to 5 of 8 glasses")
    }

    func testCheckInTargetsHaveNoDrum() {
        XCTAssertNil(HabitAmountEntry.drum(for: .binary, current: 0))
        XCTAssertNil(HabitAmountEntry.drum(for: .avoidance, current: 0))
        XCTAssertNil(HabitAmountEntry.drum(for: .quota(count: 3, period: .week), current: 0), "Weekly quotas are not daily amounts")
    }
}

/// Per-weekday rates from day marks, with the copy rules that keep it kind.
final class HabitWeekdayStatisticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday first, so the order is testable
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day; c.hour = 12
        return calendar.date(from: c)!
    }

    func testRatesCountOnlyScheduledDaysAndOrderFollowsTheCalendar() {
        // 2026-09-17 is a Thursday. Four Tuesdays: 3 done, 1 missed. Four
        // Fridays: 1 done, 3 missed. Skips and unscheduled days are ignored.
        var marks: [HabitDayMark] = []
        for week in 0..<4 {
            let tuesday = calendar.date(byAdding: .day, value: -(2 + week * 7), to: day(2026, 9, 17))!
            let friday = calendar.date(byAdding: .day, value: -(6 + week * 7), to: day(2026, 9, 17))!
            marks.append(HabitDayMark(date: tuesday, state: week == 0 ? .failure : .success))
            marks.append(HabitDayMark(date: friday, state: week == 0 ? .success : .failure))
        }
        marks.append(HabitDayMark(date: day(2026, 9, 16), state: .skipped))
        marks.append(HabitDayMark(date: day(2026, 9, 14), state: .none))
        let stats = HabitWeekdayStatistics.make(marks: marks, now: day(2026, 9, 17), calendar: calendar)

        XCTAssertEqual(stats.weekdays.map(\.weekday), [2, 3, 4, 5, 6, 7, 1])
        let tuesday = stats.weekdays.first { $0.weekday == 3 }!
        XCTAssertEqual(tuesday.successes, 3); XCTAssertEqual(tuesday.scheduled, 4)
        let wednesday = stats.weekdays.first { $0.weekday == 4 }!
        XCTAssertEqual(wednesday.scheduled, 0, "A skip is not a scheduled day")
        XCTAssertEqual(stats.strongest?.weekday, 3)
        XCTAssertEqual(stats.weakest?.weekday, 6)
        XCTAssertEqual(stats.summary(calendar: calendar), "Most often Tuesdays · least often Fridays")
        XCTAssertEqual(HabitWeekdayStatistics.barText(tuesday), "3 of 4")
        // Four Tuesdays and four Fridays straddle five Monday-first weeks.
        XCTAssertEqual(stats.weeks.count, 5)
    }

    func testTooFewDaysMeansNoOpinion() {
        let marks = [
            HabitDayMark(date: day(2026, 9, 15), state: .success),
            HabitDayMark(date: day(2026, 9, 8), state: .success),
            HabitDayMark(date: day(2026, 9, 1), state: .failure),
        ]
        let stats = HabitWeekdayStatistics.make(marks: marks, now: day(2026, 9, 17), calendar: calendar)
        XCTAssertNil(stats.strongest)
        XCTAssertNil(stats.summary(calendar: calendar))
    }

    func testDaysOutsideTheWindowAndInTheFutureAreIgnored() {
        let marks = [
            HabitDayMark(date: day(2026, 1, 1), state: .success),
            HabitDayMark(date: day(2026, 9, 20), state: .success),
        ]
        let stats = HabitWeekdayStatistics.make(marks: marks, now: day(2026, 9, 17), calendar: calendar)
        XCTAssertTrue(stats.weekdays.allSatisfy { $0.scheduled == 0 })
        XCTAssertTrue(stats.weeks.isEmpty)
    }
}

/// The widget's queued habit command and the snapshot fields that feed its rings.
final class HabitWidgetCommandTests: XCTestCase {
    func testCommandRoundTripsAndExpires() throws {
        let command = HabitAmountActionCommand(
            habitID: UUID(), kind: .step, delta: 250,
            createdAt: Date(timeIntervalSince1970: 100), expiresAt: Date(timeIntervalSince1970: 200)
        )
        let decoded = try JSONDecoder().decode(HabitAmountActionCommand.self, from: JSONEncoder().encode(command))
        XCTAssertEqual(decoded, command)
        XCTAssertTrue(decoded.isExpired, "A 1970 expiry is long gone")
        XCTAssertFalse(HabitAmountActionCommand(habitID: UUID(), kind: .complete).isExpired)
    }

    func testOlderSnapshotsWithoutAmountsStillDecode() throws {
        let legacy = """
        {"habitID":"\(UUID().uuidString)","title":"Water","iconSymbolName":"drop","currentStreak":2,"bestStreak":5,"todayState":"empty","week":[]}
        """
        let primary = try JSONDecoder().decode(TaskListWidgetHabitPrimary.self, from: Data(legacy.utf8))
        XCTAssertNil(primary.currentAmount)
        XCTAssertNil(primary.targetValue)
        XCTAssertNil(primary.isQuitHabit)
        let legacyHabit = """
        {"date":0,"updatedAt":0,"dueCount":0,"completedTodayCount":0,"atRiskCount":0}
        """
        let snapshot = try JSONDecoder().decode(TaskListWidgetHabitSnapshot.self, from: Data(legacyHabit.utf8))
        XCTAssertNil(snapshot.today)
    }

    func testWidgetHabitIntentsNeverOpenTheApp() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("LifeBoardWidgets/LifeBoardWidgetBundle.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for intent in ["LogHabitStepFromWidgetIntent", "CompleteHabitFromWidgetIntent"] {
            let start = try XCTUnwrap(source.range(of: "public struct \(intent): AppIntent {"))
            let body = source[start.lowerBound...]
            let end = body.range(of: "\npublic struct ")?.lowerBound ?? body.endIndex
            let text = String(body[..<end])
            XCTAssertTrue(text.contains("openAppWhenRun = false"), "\(intent) must run in the background")
            XCTAssertFalse(text.contains("OpenURLIntent"), "\(intent) must not open the app through a URL")
            XCTAssertTrue(text.contains("HabitAmountActionCommand("), "\(intent) queues the shared command")
        }
    }
}

