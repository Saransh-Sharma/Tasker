import XCTest
@testable import LifeBoard

// MARK: - Fakes

/// Records every read and write so the tests can assert that swiping a card
/// touches persistence *zero* times.
private actor FakeDayCloseReader: DayCloseReading {
    var tasks: [PlanningTaskSummary] = []
    var blocks: [InternalTimeBlock] = []
    var focusSessions: [FocusSessionV2] = []
    var closed = false
    private(set) var undoneReceipts: [UUID] = []
    var loadError: Error?

    struct Boom: Error {}

    func setTasks(_ value: [PlanningTaskSummary]) { tasks = value }
    func setSessions(_ value: [FocusSessionV2]) { focusSessions = value }
    func setBlocks(_ value: [InternalTimeBlock]) { blocks = value }
    func setClosed(_ value: Bool) { closed = value }
    func setLoadError(_ value: Error?) { loadError = value }

    func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary] {
        if let loadError { throw loadError }
        return tasks
    }

    func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock] { blocks }
    func sessions(since: Date?) async throws -> [FocusSessionV2] { focusSessions }
    func hasAppliedReceipt(source: String) async throws -> Bool { closed }

    var receipts: [PlanningReceiptRecord] = []
    func setReceipts(_ value: [PlanningReceiptRecord]) { receipts = value }
    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord] { receipts }

    func undo(receiptID: UUID) async throws {
        undoneReceipts.append(receiptID)
        closed = false
    }
}

private actor FakeScenarioCoordinator: PlanningScenarioCoordinating {
    private(set) var applied: [PlanningScenario] = []
    var error: Error?

    func setError(_ value: Error?) { error = value }
    var appliedCount: Int { applied.count }
    var lastScenario: PlanningScenario? { applied.last }

    func apply(_ scenario: PlanningScenario) async throws -> PlanMutationReceipt {
        if let error {
            // One-shot: the retry after a conflict should succeed.
            self.error = nil
            throw error
        }
        applied.append(scenario)
        return PlanMutationReceipt(
            id: UUID(),
            source: scenario.receiptSource ?? "test",
            summary: "test",
            forwardData: Data(),
            undoData: Data(),
            createdAt: Date()
        )
    }
}

// MARK: - Tests

@MainActor
final class DayCloseStoreTests: XCTestCase {

    private let day = PlanningDay(year: 2026, month: 7, day: 31, timeZoneIdentifier: "Asia/Kolkata")

    private func task(_ title: String, mustDo: Bool = false) -> PlanningTaskSummary {
        let id = UUID()
        return PlanningTaskSummary(
            id: id,
            title: title,
            metadata: PlanningTaskMetadata(
                taskID: id,
                planningDay: day,
                commitmentLevel: mustDo ? .mustDo : .standard,
                updatedAt: Date(timeIntervalSince1970: 500_000)
            )
        )
    }

    private func makeStore(
        tasks: [PlanningTaskSummary],
        reader: FakeDayCloseReader = FakeDayCloseReader(),
        coordinator: FakeScenarioCoordinator = FakeScenarioCoordinator()
    ) async -> (DayCloseStore, FakeDayCloseReader, FakeScenarioCoordinator) {
        await reader.setTasks(tasks)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        let store = DayCloseStore(
            reader: reader,
            completions: nil,
            scenarios: coordinator,
            day: day,
            calendar: calendar
        )
        return (store, reader, coordinator)
    }

    // MARK: - Loading

    func testOnlyTodaysActionableCommitmentsEnterTheDeck() async {
        var elsewhere = task("Tomorrow's problem")
        elsewhere.metadata.planningDay = PlanningDay(
            year: 2026, month: 8, day: 1, timeZoneIdentifier: "Asia/Kolkata"
        )
        var waiting = task("Blocked on someone else")
        waiting.metadata.availability = .waiting
        var removed = task("Deleted")
        removed.metadata.unscheduledDisposition = .deleted

        let (store, _, _) = await makeStore(tasks: [task("Real"), elsewhere, waiting, removed])
        await store.load()

        XCTAssertEqual(store.unfinished.map(\.title), ["Real"])
    }

    func testMustDoCommitmentsComeFirst() async {
        let (store, _, _) = await makeStore(
            tasks: [task("Ordinary"), task("Promised", mustDo: true)]
        )
        await store.load()

        XCTAssertEqual(store.unfinished.first?.title, "Promised")
    }

    func testAFailedLoadIsDistinctFromAnEmptyDay() async {
        let reader = FakeDayCloseReader()
        await reader.setLoadError(FakeDayCloseReader.Boom())
        let (store, _, _) = await makeStore(tasks: [], reader: reader)
        await store.load()

        // Never `.empty`: the app must not congratulate someone for a fetch that
        // did not complete.
        guard case .failed = store.loadState else {
            return XCTFail("Expected .failed, got \(store.loadState)")
        }
    }

    func testAGenuinelyClearDayReportsEmptyNotFailed() async {
        let (store, _, _) = await makeStore(tasks: [])
        await store.load()

        XCTAssertEqual(store.loadState, .empty)
    }

    // MARK: - The deferred-commit contract

    func testSwipingCardsWritesNothingUntilTheDayIsClosed() async {
        let tasks = [task("One"), task("Two"), task("Three")]
        let (store, _, coordinator) = await makeStore(tasks: tasks)
        await store.load()

        store.record(.tomorrow, for: tasks[0].id)
        store.record(.release, for: tasks[1].id)
        store.record(.doneAnyway, for: tasks[2].id)

        // The whole point of the design: three decisions, zero writes.
        let count = await coordinator.appliedCount
        XCTAssertEqual(count, 0)
        XCTAssertEqual(store.decidedCount, 3)

        await store.close()

        let afterCount = await coordinator.appliedCount
        XCTAssertEqual(afterCount, 1, "one act must produce exactly one receipt")
    }

    func testDecidedCardsLeaveTheDeckImmediatelyEvenThoughNothingIsWritten() async throws {
        let tasks = [task("One"), task("Two")]
        let (store, _, _) = await makeStore(tasks: tasks)
        await store.load()

        XCTAssertEqual(store.remainingCount, 2)
        // Capture the card actually in hand. The deck is ordered must-do first
        // then by UUID, so assuming it is `tasks[0]` made this pass or fail on
        // the luck of randomly generated identifiers.
        let decided = try XCTUnwrap(store.currentCard?.id)
        store.record(.tomorrow, for: decided)

        XCTAssertEqual(store.remainingCount, 1)
        XCTAssertNotEqual(store.currentCard?.id, decided)
    }

    func testBringBackTheLastCardPopsExactlyOneDecision() async {
        let tasks = [task("One"), task("Two")]
        let (store, _, _) = await makeStore(tasks: tasks)
        await store.load()

        let first = store.currentCard!.id
        store.record(.release, for: first)
        let second = store.currentCard!.id
        store.record(.release, for: second)
        XCTAssertEqual(store.remainingCount, 0)

        let returned = store.bringBackLastCard()

        XCTAssertEqual(returned, second)
        XCTAssertEqual(store.decidedCount, 1)
        XCTAssertEqual(store.currentCard?.id, second)
    }

    func testBringBackOnAnUntouchedDeckIsHarmless() async {
        let (store, _, _) = await makeStore(tasks: [task("One")])
        await store.load()

        XCTAssertNil(store.bringBackLastCard())
        XCTAssertEqual(store.decidedCount, 0)
    }

    func testReSwipingACardReplacesRatherThanDuplicatesItsDecision() async {
        let tasks = [task("One")]
        let (store, _, _) = await makeStore(tasks: tasks)
        await store.load()

        store.record(.release, for: tasks[0].id)
        store.bringBackLastCard()
        store.record(.tomorrow, for: tasks[0].id)

        XCTAssertEqual(store.decidedCount, 1)
        XCTAssertEqual(store.decisionOrder.count, 1)
        XCTAssertEqual(store.makeScenario()?.proposedMutations.count, 1)
    }

    // MARK: - Anchor

    func testReleasingTheAnchoredTaskClearsTheAnchor() async {
        let tasks = [task("One"), task("Two")]
        let (store, _, _) = await makeStore(tasks: tasks)
        await store.load()

        store.setAnchor(tasks[0].id)
        XCTAssertEqual(store.anchorTaskID, tasks[0].id)

        store.record(.release, for: tasks[0].id)

        // Tomorrow must not open pointing at something just let go.
        XCTAssertNil(store.anchorTaskID)
    }

    func testFiledAwayTasksDropOutOfTheAnchorCandidates() async {
        let tasks = [task("One"), task("Two")]
        let (store, _, _) = await makeStore(tasks: tasks)
        await store.load()

        store.record(.someday, for: tasks[0].id)

        XCTAssertEqual(store.anchorCandidates.map(\.id), [tasks[1].id])
    }

    // MARK: - Closing

    func testAnEmptyReconciliationStillWritesTheReceiptThatMarksTheDayClosed() async {
        let (store, _, coordinator) = await makeStore(tasks: [])
        await store.load()

        await store.close()

        // Without a receipt for a nothing-to-do day, the ritual would re-offer
        // itself forever.
        let count = await coordinator.appliedCount
        XCTAssertEqual(count, 1)
        XCTAssertTrue(store.alreadyClosed)
    }

    func testClosingIsNotOfferedTwice() async {
        let (store, _, coordinator) = await makeStore(tasks: [])
        await store.load()
        await store.close()
        await store.close()

        let count = await coordinator.appliedCount
        XCTAssertEqual(count, 1)
    }

    func testReEnteringAnAlreadyClosedDayShowsItAsClosed() async {
        let reader = FakeDayCloseReader()
        await reader.setClosed(true)
        let (store, _, _) = await makeStore(tasks: [task("One")], reader: reader)
        await store.load()

        XCTAssertTrue(store.alreadyClosed)
    }

    func testUndoRestoresTheDayToOpen() async {
        let (store, reader, _) = await makeStore(tasks: [task("One")])
        await store.load()
        await store.close()
        XCTAssertTrue(store.alreadyClosed)

        await store.undoClose()

        // The receipt's state flips back, so the ritual reopens — exactly the
        // semantics `hasAppliedReceipt` already provides.
        XCTAssertFalse(store.alreadyClosed)
        XCTAssertNil(store.closedAt)
        let undone = await reader.undoneReceipts
        XCTAssertEqual(undone.count, 1)
    }

    // MARK: - Version conflict

    func testAVersionConflictNamesTheStaleCardsAndKeepsTheRest() async {
        let tasks = [task("One"), task("Two"), task("Three")]
        let coordinator = FakeScenarioCoordinator()
        let (store, _, _) = await makeStore(tasks: tasks, coordinator: coordinator)
        await store.load()

        store.record(.tomorrow, for: tasks[0].id)
        store.record(.release, for: tasks[1].id)
        store.record(.someday, for: tasks[2].id)

        await coordinator.setError(
            PlanningScenarioApplyError.versionConflict(changedRecordIDs: [tasks[1].id])
        )
        await store.close()

        XCTAssertFalse(store.alreadyClosed)
        XCTAssertEqual(store.staleTaskIDs, [tasks[1].id])
        guard case .recoverableFailure = store.applyPhase else {
            return XCTFail("Expected a recoverable failure, got \(store.applyPhase)")
        }

        await store.reviewAfterConflict()

        // The evening's work survives: only the card that actually moved is
        // dropped for re-review.
        XCTAssertEqual(store.decidedCount, 2)
        XCTAssertNil(store.decisions[tasks[1].id])
        XCTAssertEqual(store.decisions[tasks[0].id], .tomorrow)
        XCTAssertEqual(store.decisions[tasks[2].id], .someday)
    }

    // MARK: - The carry (day-open mode)

    private func makeOpenStore(
        tasks: [PlanningTaskSummary],
        receipts: [PlanningReceiptRecord]
    ) async -> DayCloseStore {
        let reader = FakeDayCloseReader()
        await reader.setTasks(tasks)
        await reader.setReceipts(receipts)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .current
        let yesterday = PlanningDay(year: 2026, month: 7, day: 30, timeZoneIdentifier: "Asia/Kolkata")
        return DayCloseStore(
            reader: reader,
            completions: nil,
            scenarios: FakeScenarioCoordinator(),
            day: day,
            retrospectiveDay: yesterday,
            calendar: calendar,
            closureLog: DayLoopClosureLog(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
    }

    private func anchorReceipt(taskID: UUID, applied: Bool = true) -> PlanningReceiptRecord {
        let yesterday = PlanningDay(year: 2026, month: 7, day: 30, timeZoneIdentifier: "Asia/Kolkata")
        var after = PlanningTaskMetadata(taskID: taskID)
        after.planningDay = day
        after.commitmentLevel = .mustDo
        after.pinOrder = 0
        let forward = PlanMutation.batch([
            .saveTaskMetadata(before: PlanningTaskMetadata(taskID: taskID), after: after)
        ])
        return PlanningReceiptRecord(
            receipt: PlanMutationReceipt(
                id: UUID(),
                source: DayCloseScenarioBuilder.receiptSource(for: yesterday),
                summary: "close",
                forwardData: (try? JSONEncoder().encode(forward)) ?? Data(),
                undoData: Data(),
                createdAt: Date()
            ),
            state: applied ? .applied : .undone,
            appliedAt: applied ? Date() : nil
        )
    }

    func testTheMorningNamesTheTaskLastNightChose() async {
        let carried = task("Ship the thing")
        let other = task("Something else")
        let store = await makeOpenStore(
            tasks: [carried, other],
            receipts: [anchorReceipt(taskID: carried.id)]
        )

        await store.load()

        XCTAssertEqual(store.carriedAnchorTaskID, carried.id)
        XCTAssertEqual(store.carriedAnchor?.title, "Ship the thing")
        XCTAssertTrue(store.retrospectiveDayWasClosed)
    }

    func testADayThatWasNeverClosedCarriesNothingDeliberately() async {
        let open = task("Still open")
        let store = await makeOpenStore(tasks: [open], receipts: [])

        await store.load()

        // The screen must not claim "last night's decisions" when there were
        // none — it still lists today's open work, but says why.
        XCTAssertNil(store.carriedAnchorTaskID)
        XCTAssertFalse(store.retrospectiveDayWasClosed)
        XCTAssertEqual(store.unfinished.map(\.title), ["Still open"])
    }

    func testAnUndoneCloseCarriesNothing() async {
        let carried = task("Ship the thing")
        let store = await makeOpenStore(
            tasks: [carried],
            receipts: [anchorReceipt(taskID: carried.id, applied: false)]
        )

        await store.load()

        XCTAssertNil(store.carriedAnchorTaskID)
        XCTAssertFalse(store.retrospectiveDayWasClosed)
    }

    // MARK: - Receipt identity

    func testTheReceiptSourceIsScopedToTheDayBeingClosed() async {
        let (store, _, coordinator) = await makeStore(tasks: [])
        await store.load()
        await store.close()

        let scenario = await coordinator.lastScenario
        XCTAssertEqual(scenario?.receiptSource, "planning.scenario.dayClose.2026-07-31")
        XCTAssertEqual(store.receiptSource, "planning.scenario.dayClose.2026-07-31")
    }

    // MARK: - Ribbon honesty

    func testTheRibbonReportsNilRatherThanZeroWhenTheDayHadNoShape() async {
        let (store, _, _) = await makeStore(tasks: [])
        await store.load()

        XCTAssertNil(store.ribbon?.summary.plannedMinutes)
        XCTAssertNil(store.ribbon?.summary.focusedMinutes)
        XCTAssertEqual(store.ribbon?.summary.hasNothingToReport, true)
    }

    func testFocusedTimeIsWallClockMinusPausesNotTheTarget() async {
        let start = day.startDate(calendar: .current)!.addingTimeInterval(9 * 3_600)
        let session = FocusSessionV2(
            id: UUID(),
            taskID: nil,
            timeBlockID: nil,
            // Targeted 50 minutes, ran 20, of which 5 were paused.
            targetDuration: 50 * 60,
            state: .ended,
            startedAt: start,
            endedAt: start.addingTimeInterval(20 * 60),
            accumulatedPauseDuration: 5 * 60
        )
        let reader = FakeDayCloseReader()
        await reader.setSessions([session])
        let (store, _, _) = await makeStore(tasks: [], reader: reader)
        await store.load()

        // Crediting the 50-minute target would be the flattering lie this screen
        // exists not to tell.
        XCTAssertEqual(store.ribbon?.summary.focusedMinutes, 15)
    }

    func testStillRunningSessionsContributeNoMeasuredTime() async {
        let start = day.startDate(calendar: .current)!.addingTimeInterval(9 * 3_600)
        let running = FocusSessionV2(
            id: UUID(),
            taskID: nil,
            timeBlockID: nil,
            targetDuration: 25 * 60,
            state: .running,
            startedAt: start,
            endedAt: nil,
            accumulatedPauseDuration: 0
        )
        let reader = FakeDayCloseReader()
        await reader.setSessions([running])
        let (store, _, _) = await makeStore(tasks: [], reader: reader)
        await store.load()

        XCTAssertNil(store.ribbon?.summary.focusedMinutes)
    }
}
