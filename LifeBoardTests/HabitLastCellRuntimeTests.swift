import XCTest
@testable import LifeBoard

final class HabitLastCellRuntimeTests: XCTestCase {

    func testResetHabitOccurrenceReturnsCompletedOccurrenceToPendingAndRecordsCompensation() {
        let habitID = UUID()
        let occurrenceID = UUID()
        let date = Self.date("2026-04-09")

        let habit = Self.makeHabit(id: habitID, kind: .positive)
        let occurrence = Self.makeOccurrence(
            id: occurrenceID,
            habitID: habitID,
            date: date,
            state: .completed
        )

        let habitRepository = HabitRepositoryStub(habits: [habit])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [occurrence])
        let gamificationRepository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: gamificationRepository)
        let useCase = ResetHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: engine
        )

        let result = expectation(description: "reset")
        useCase.execute(habitID: habitID, occurrenceID: occurrenceID, on: date) { resetResult in
            if case .failure(let error) = resetResult {
                XCTFail("Expected reset to succeed: \(error)")
            }
            result.fulfill()
        }
        wait(for: [result], timeout: 2)

        XCTAssertEqual(occurrenceRepository.occurrences.first?.state, .pending)
        XCTAssertEqual(gamificationRepository.events.map(\.category), [.habitPositiveCompleteUndo])
        XCTAssertEqual(gamificationRepository.events.first?.delta, -8)
    }

    func testResetHabitOccurrenceReturnsSkippedAndFailedOccurrencesToPendingAndCompensatesNegativeFailure() {
        let date = Self.date("2026-04-09")

        let skippedHabitID = UUID()
        let skippedOccurrenceID = UUID()
        let skippedHabit = Self.makeHabit(id: skippedHabitID, kind: .positive)
        let skippedOccurrence = Self.makeOccurrence(
            id: skippedOccurrenceID,
            habitID: skippedHabitID,
            date: date,
            state: .skipped
        )

        let failedHabitID = UUID()
        let failedOccurrenceID = UUID()
        let failedHabit = Self.makeHabit(id: failedHabitID, kind: .negative)
        let failedOccurrence = Self.makeOccurrence(
            id: failedOccurrenceID,
            habitID: failedHabitID,
            date: date,
            state: .failed
        )

        let habitRepository = HabitRepositoryStub(habits: [skippedHabit, failedHabit])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [skippedOccurrence, failedOccurrence])
        let gamificationRepository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: gamificationRepository)
        let useCase = ResetHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: engine
        )

        let skippedExpectation = expectation(description: "reset skipped")
        useCase.execute(habitID: skippedHabitID, occurrenceID: skippedOccurrenceID, on: date) { result in
            if case .failure(let error) = result {
                XCTFail("Expected skipped reset to succeed: \(error)")
            }
            skippedExpectation.fulfill()
        }

        let failedExpectation = expectation(description: "reset failed")
        useCase.execute(habitID: failedHabitID, occurrenceID: failedOccurrenceID, on: date) { result in
            if case .failure(let error) = result {
                XCTFail("Expected failed reset to succeed: \(error)")
            }
            failedExpectation.fulfill()
        }

        wait(for: [skippedExpectation, failedExpectation], timeout: 2)

        let statesByID = Dictionary(uniqueKeysWithValues: occurrenceRepository.occurrences.map { ($0.id, $0.state) })
        XCTAssertEqual(statesByID[skippedOccurrenceID], .pending)
        XCTAssertEqual(statesByID[failedOccurrenceID], .pending)
        XCTAssertEqual(gamificationRepository.events.map(\.category), [.habitNegativeSuccessUndo])
        XCTAssertEqual(gamificationRepository.events.first?.delta, -8)
    }

    func testResolveHabitOccurrenceMaterializesSameDayOccurrenceForRegularHabit() {
        let habitID = UUID()
        let date = Self.date("2026-04-09")
        let templateID = UUID()

        let habit = Self.makeHabit(id: habitID, kind: .positive)
        let habitRepository = HabitRepositoryStub(habits: [habit])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [])
        let scheduleRepository = ScheduleRepositoryStub()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habitID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: date,
                isActive: true,
                createdAt: date,
                updatedAt: date
            )
        ]
        let schedulingEngine = ResolvingSchedulingEngineStub(occurrenceRepository: occurrenceRepository)
        let gamificationRepository = InMemoryGamificationRepositoryStub()
        let useCase = ResolveHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository,
            scheduleEngine: schedulingEngine,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: GamificationEngine(repository: gamificationRepository)
        )

        let completion = expectation(description: "resolve complete")
        useCase.execute(
            habitID: habitID,
            action: .complete,
            on: date
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected complete to succeed for materialized occurrence: \(error)")
            }
            completion.fulfill()
        }
        wait(for: [completion], timeout: 2)

        let occurrence = try! XCTUnwrap(occurrenceRepository.occurrences.first(where: { $0.sourceID == habitID }))
        XCTAssertEqual(occurrence.state, .completed)
        XCTAssertEqual(schedulingEngine.resolvedCalls.map(\.resolution), [.completed])
        XCTAssertEqual(gamificationRepository.events.map(\.category), [.habitPositiveComplete])
    }

    func testResolveHabitOccurrenceBackdatedActionUpdatesMaterializedOccurrenceState() {
        let habitID = UUID()
        let date = Self.date("2026-04-05")
        let templateID = UUID()

        let habit = Self.makeHabit(id: habitID, kind: .positive)
        let habitRepository = HabitRepositoryStub(habits: [habit])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [])
        let scheduleRepository = ScheduleRepositoryStub()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .habit,
                sourceID: habitID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: date,
                isActive: true,
                createdAt: date,
                updatedAt: date
            )
        ]
        let schedulingEngine = ResolvingSchedulingEngineStub(occurrenceRepository: occurrenceRepository)
        let useCase = ResolveHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository,
            scheduleEngine: schedulingEngine,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: GamificationEngine(repository: InMemoryGamificationRepositoryStub())
        )

        let completion = expectation(description: "resolve skip")
        useCase.execute(
            habitID: habitID,
            action: .skip,
            on: date
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected skip to succeed for materialized backdated occurrence: \(error)")
            }
            completion.fulfill()
        }
        wait(for: [completion], timeout: 2)

        let occurrence = try! XCTUnwrap(occurrenceRepository.occurrences.first(where: { $0.sourceID == habitID }))
        XCTAssertEqual(occurrence.state, .skipped)
        XCTAssertTrue(Self.calendar.isDate(occurrence.dueAt ?? occurrence.scheduledAt, inSameDayAs: date))
        XCTAssertEqual(schedulingEngine.resolvedCalls.map(\.resolution), [.skipped])
    }

    func testResolveHabitOccurrenceUsesFetchByIDWhenOccurrenceIDProvided() {
        let habitID = UUID()
        let occurrenceID = UUID()
        let date = Self.date("2026-04-09")
        let expectedError = NSError(domain: "SchedulingEngine", code: 77)

        let habitRepository = HabitRepositoryStub(habits: [Self.makeHabit(id: habitID, kind: .positive)])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [
            Self.makeOccurrence(id: occurrenceID, habitID: habitID, date: date, state: .pending)
        ])
        let schedulingEngine = SchedulingEngineStub()
        schedulingEngine.resolveError = expectedError

        let useCase = ResolveHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            scheduleRepository: ScheduleRepositoryStub(),
            occurrenceRepository: occurrenceRepository,
            scheduleEngine: schedulingEngine,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: GamificationEngine(repository: InMemoryGamificationRepositoryStub())
        )

        let completion = expectation(description: "resolve fails after targeted lookup")
        useCase.execute(habitID: habitID, occurrenceID: occurrenceID, action: .complete, on: date) { result in
            if case .success = result {
                XCTFail("Expected resolve to fail when scheduling engine fails")
            }
            completion.fulfill()
        }
        wait(for: [completion], timeout: 2)

        XCTAssertEqual(habitRepository.fetchByIDCallCount, 1)
        XCTAssertEqual(habitRepository.fetchAllCallCount, 0)
        XCTAssertEqual(occurrenceRepository.fetchByIDCallCount, 1)
        XCTAssertEqual(occurrenceRepository.fetchLatestForHabitCallCount, 0)
        XCTAssertEqual(occurrenceRepository.fetchInRangeCallCount, 0)
    }

    func testResolveHabitOccurrenceUsesFetchLatestForHabitWhenOccurrenceIDMissing() {
        let habitID = UUID()
        let occurrenceID = UUID()
        let date = Self.date("2026-04-09")
        let expectedError = NSError(domain: "SchedulingEngine", code: 88)

        let habitRepository = HabitRepositoryStub(habits: [Self.makeHabit(id: habitID, kind: .positive)])
        let occurrenceRepository = OccurrenceRepositoryStub(occurrences: [
            Self.makeOccurrence(id: occurrenceID, habitID: habitID, date: date, state: .pending)
        ])
        let schedulingEngine = SchedulingEngineStub()
        schedulingEngine.resolveError = expectedError

        let useCase = ResolveHabitOccurrenceUseCase(
            habitRepository: habitRepository,
            scheduleRepository: ScheduleRepositoryStub(),
            occurrenceRepository: occurrenceRepository,
            scheduleEngine: schedulingEngine,
            recomputeHabitStreaksUseCase: RecomputeHabitStreaksUseCase(
                habitRepository: habitRepository,
                occurrenceRepository: occurrenceRepository
            ),
            gamificationEngine: GamificationEngine(repository: InMemoryGamificationRepositoryStub())
        )

        let completion = expectation(description: "resolve fails after latest lookup")
        useCase.execute(habitID: habitID, action: .complete, on: date) { result in
            if case .success = result {
                XCTFail("Expected resolve to fail when scheduling engine fails")
            }
            completion.fulfill()
        }
        wait(for: [completion], timeout: 2)

        XCTAssertEqual(habitRepository.fetchByIDCallCount, 1)
        XCTAssertEqual(habitRepository.fetchAllCallCount, 0)
        XCTAssertEqual(occurrenceRepository.fetchLatestForHabitCallCount, 1)
        XCTAssertEqual(occurrenceRepository.fetchByIDCallCount, 0)
        XCTAssertEqual(occurrenceRepository.fetchInRangeCallCount, 0)
    }

    func testPendingOccurrenceProjectsAsNoneInDayMarks() {
        let habitID = UUID()
        let date = Self.date("2026-04-09")
        let pendingOccurrence = Self.makeOccurrence(
            id: UUID(),
            habitID: habitID,
            date: date,
            state: .pending
        )

        let marks = HabitRuntimeSupport.dayMarks(
            from: [pendingOccurrence],
            endingOn: date,
            dayCount: 1,
            calendar: Self.calendar
        )

        XCTAssertEqual(marks.first?.state, HabitDayState.none)
    }

    func testGamificationCompensationAllowsSameDayHabitSuccessReaward() {
        let habitID = UUID()
        let date = Self.date("2026-04-09")
        let repository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: repository)

        let firstResult = expectation(description: "first award")
        engine.recordEvent(
            context: XPEventContext(
                category: .habitPositiveComplete,
                source: .habit,
                habitID: habitID,
                completedAt: date
            )
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected first award to succeed: \(error)")
            case .success(let payload):
                XCTAssertEqual(payload.awardedXP, 8)
            }
            firstResult.fulfill()
        }
        wait(for: [firstResult], timeout: 2)

        let compensationResult = expectation(description: "compensation")
        engine.recordCompensationEvent(
            context: XPEventContext(
                category: .habitPositiveCompleteUndo,
                source: .habit,
                habitID: habitID,
                completedAt: date
            )
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected compensation to succeed: \(error)")
            case .success(let payload):
                XCTAssertEqual(payload.awardedXP, -8)
            }
            compensationResult.fulfill()
        }
        wait(for: [compensationResult], timeout: 2)

        XCTAssertEqual(repository.profile?.xpTotal, 0)

        let secondResult = expectation(description: "second award")
        engine.recordEvent(
            context: XPEventContext(
                category: .habitPositiveComplete,
                source: .habit,
                habitID: habitID,
                completedAt: date
            )
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected second award to succeed: \(error)")
            case .success(let payload):
                XCTAssertEqual(payload.awardedXP, 8)
            }
            secondResult.fulfill()
        }
        wait(for: [secondResult], timeout: 2)

        XCTAssertEqual(repository.profile?.xpTotal, 8)
        XCTAssertEqual(repository.events.map(\.category), [
            .habitPositiveComplete,
            .habitPositiveCompleteUndo,
            .habitPositiveComplete
        ])
        XCTAssertTrue(repository.events[0].idempotencyKey.hasSuffix("cycle0"))
        XCTAssertTrue(repository.events[2].idempotencyKey.hasSuffix("cycle1"))
    }

    func testGamificationCompensationAllowsSameDayHabitSuccessReawardWhenIdentifiedByTaskID() {
        let taskID = UUID()
        let date = Self.date("2026-04-09")
        let repository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: repository)

        let firstResult = expectation(description: "first award by task")
        engine.recordEvent(
            context: XPEventContext(
                category: .habitPositiveComplete,
                source: .habit,
                taskID: taskID,
                completedAt: date
            )
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected first award to succeed: \(error)")
            }
            firstResult.fulfill()
        }
        wait(for: [firstResult], timeout: 2)

        let compensationResult = expectation(description: "compensation by task")
        engine.recordCompensationEvent(
            context: XPEventContext(
                category: .habitPositiveCompleteUndo,
                source: .habit,
                taskID: taskID,
                completedAt: date
            )
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected compensation to succeed: \(error)")
            }
            compensationResult.fulfill()
        }
        wait(for: [compensationResult], timeout: 2)

        let secondResult = expectation(description: "second award by task")
        engine.recordEvent(
            context: XPEventContext(
                category: .habitPositiveComplete,
                source: .habit,
                taskID: taskID,
                completedAt: date
            )
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected second award to succeed: \(error)")
            }
            secondResult.fulfill()
        }
        wait(for: [secondResult], timeout: 2)

        XCTAssertEqual(repository.profile?.xpTotal, 8)
        XCTAssertTrue(repository.events[0].idempotencyKey.hasSuffix("cycle0"))
        XCTAssertTrue(repository.events[2].idempotencyKey.hasSuffix("cycle1"))
    }

    func testHistoricalCompensationUsesHistoricalDailyAggregate() {
        let habitID = UUID()
        let historicalDate = Self.date("2026-04-09")
        let repository = InMemoryGamificationRepositoryStub()
        let engine = GamificationEngine(repository: repository)

        let historicalAward = expectation(description: "historical award")
        engine.recordEvent(
            context: XPEventContext(
                category: .habitPositiveComplete,
                source: .habit,
                habitID: habitID,
                completedAt: historicalDate
            )
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected historical award to succeed: \(error)")
            }
            historicalAward.fulfill()
        }
        wait(for: [historicalAward], timeout: 2)

        let todayAward = expectation(description: "today award")
        engine.recordEvent(
            context: XPEventContext(
                category: .focus,
                source: .manual,
                taskID: UUID(),
                completedAt: Date()
            )
        ) { result in
            if case .failure(let error) = result {
                XCTFail("Expected today award to succeed: \(error)")
            }
            todayAward.fulfill()
        }
        wait(for: [todayAward], timeout: 2)

        let compensation = expectation(description: "historical compensation")
        var resultPayload: XPEventResult?
        engine.recordCompensationEvent(
            context: XPEventContext(
                category: .habitPositiveCompleteUndo,
                source: .habit,
                habitID: habitID,
                completedAt: historicalDate
            )
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected historical compensation to succeed: \(error)")
            case .success(let payload):
                resultPayload = payload
            }
            compensation.fulfill()
        }
        wait(for: [compensation], timeout: 2)

        XCTAssertEqual(resultPayload?.dailyXPSoFar, 0)
        XCTAssertEqual(
            repository.dailyAggregates[XPCalculationEngine.periodKey(for: historicalDate)]?.totalXP,
            resultPayload?.dailyXPSoFar
        )
    }

    private static func makeMaintainHabitRuntimeUseCase(
        habitRepository: HabitRepositoryProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol
    ) -> MaintainHabitRuntimeUseCase {
        let recompute = RecomputeHabitStreaksUseCase(
            habitRepository: habitRepository,
            occurrenceRepository: occurrenceRepository
        )
        let sync = SyncHabitScheduleUseCase(
            habitRepository: habitRepository,
            scheduleRepository: ScheduleRepositoryStub(),
            scheduleEngine: SchedulingEngineStub(),
            occurrenceRepository: occurrenceRepository,
            recomputeHabitStreaksUseCase: recompute
        )
        return MaintainHabitRuntimeUseCase(syncHabitScheduleUseCase: sync)
    }

    private static func makeHabit(id: UUID, kind: HabitKind) -> HabitDefinitionRecord {
        HabitDefinitionRecord(
            id: id,
            lifeAreaID: UUID(),
            projectID: nil,
            title: kind == .positive ? "Drink water" : "No phone in bed",
            habitType: kind == .positive ? "check_in" : "quit_daily_check_in",
            kindRaw: kind.rawValue,
            trackingModeRaw: HabitTrackingMode.dailyCheckIn.rawValue,
            iconSymbolName: "star.fill",
            iconCategoryKey: "general",
            colorHex: HabitColorFamily.green.canonicalHex,
            targetConfigData: nil,
            metricConfigData: nil,
            notes: nil,
            isPaused: false,
            archivedAt: nil,
            lastGeneratedDate: nil,
            streakCurrent: 0,
            streakBest: 0,
            successMask14Raw: 0,
            failureMask14Raw: 0,
            lastHistoryRollDate: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func makeOccurrence(
        id: UUID,
        habitID: UUID,
        date: Date,
        state: OccurrenceState
    ) -> OccurrenceDefinition {
        let scheduledAt = Calendar.current.startOfDay(for: date)
        let templateID = UUID()
        return OccurrenceDefinition(
            id: id,
            occurrenceKey: OccurrenceKeyCodec.encode(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: habitID
            ),
            scheduleTemplateID: templateID,
            sourceType: .habit,
            sourceID: habitID,
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: state,
            isGenerated: true,
            generationWindow: "test",
            createdAt: scheduledAt,
            updatedAt: scheduledAt
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
}

private final class HabitRepositoryStub: HabitRepositoryProtocol {
    var habits: [HabitDefinitionRecord]
    private(set) var fetchAllCallCount = 0
    private(set) var fetchByIDCallCount = 0

    init(habits: [HabitDefinitionRecord]) {
        self.habits = habits
    }

    func fetchAll(completion: @escaping @Sendable (Result<[HabitDefinitionRecord], Error>) -> Void) {
        fetchAllCallCount += 1
        completion(.success(habits))
    }

    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<HabitDefinitionRecord?, Error>) -> Void) {
        fetchByIDCallCount += 1
        completion(.success(habits.first(where: { $0.id == id })))
    }

    func create(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        habits.removeAll { $0.id == habit.id }
        habits.append(habit)
        completion(.success(habit))
    }

    func update(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        habits.removeAll { $0.id == habit.id }
        habits.append(habit)
        completion(.success(habit))
    }

    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        habits.removeAll { $0.id == id }
        completion(.success(()))
    }
}

private final class OccurrenceRepositoryStub: OccurrenceRepositoryProtocol {
    var occurrences: [OccurrenceDefinition]
    private(set) var fetchInRangeCallCount = 0
    private(set) var fetchByIDCallCount = 0
    private(set) var fetchLatestForHabitCallCount = 0

    init(occurrences: [OccurrenceDefinition]) {
        self.occurrences = occurrences
    }

    func fetchInRange(start: Date, end: Date, completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void) {
        fetchInRangeCallCount += 1
        let filtered = occurrences.filter { occurrence in
            let occurrenceDate = occurrence.dueAt ?? occurrence.scheduledAt
            return occurrenceDate >= start && occurrenceDate <= end
        }
        completion(.success(filtered))
    }

    func fetchByID(id: UUID, completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void) {
        fetchByIDCallCount += 1
        completion(.success(occurrences.first(where: { $0.id == id })))
    }

    func fetchLatestForHabit(
        habitID: UUID,
        on date: Date,
        completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void
    ) {
        fetchLatestForHabitCallCount += 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let latest = occurrences
            .filter { occurrence in
                guard occurrence.sourceType == .habit, occurrence.sourceID == habitID else { return false }
                let occurrenceDate = occurrence.dueAt ?? occurrence.scheduledAt
                return occurrenceDate >= dayStart && occurrenceDate < dayEnd
            }
            .sorted { ($0.dueAt ?? $0.scheduledAt) < ($1.dueAt ?? $1.scheduledAt) }
            .last
        completion(.success(latest))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        for occurrence in occurrences {
            self.occurrences.removeAll { $0.id == occurrence.id }
            self.occurrences.append(occurrence)
        }
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        occurrences.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

private final class ScheduleRepositoryStub: ScheduleRepositoryProtocol {
    var templates: [ScheduleTemplateDefinition] = []
    var rulesByTemplateID: [UUID: [ScheduleRuleDefinition]] = [:]

    func fetchTemplates(completion: @escaping @Sendable (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        completion(.success(templates))
    }

    func fetchRules(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success(rulesByTemplateID[templateID] ?? []))
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping @Sendable (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        completion(.success(template))
    }

    func deleteTemplate(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func replaceRules(templateID: UUID, rules: [ScheduleRuleDefinition], completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success(rules))
    }

    func fetchExceptions(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping @Sendable (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        completion(.success(exception))
    }
}

private final class SchedulingEngineStub: SchedulingEngineProtocol {
    var resolveError: Error?

    func generateOccurrences(windowStart: Date, windowEnd: Date, sourceFilter: ScheduleSourceType?, completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func resolveOccurrence(id: UUID, resolution: OccurrenceResolutionType, actor: OccurrenceActor, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        if let resolveError {
            completion(.failure(resolveError))
            return
        }
        completion(.success(()))
    }

    func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func applyScheduleException(templateID: UUID, occurrenceKey: String, action: ScheduleExceptionAction, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class ResolvingSchedulingEngineStub: SchedulingEngineProtocol {
    struct ResolveCall {
        let id: UUID
        let resolution: OccurrenceResolutionType
        let actor: OccurrenceActor
    }

    private let occurrenceRepository: OccurrenceRepositoryStub
    private(set) var resolvedCalls: [ResolveCall] = []

    init(occurrenceRepository: OccurrenceRepositoryStub) {
        self.occurrenceRepository = occurrenceRepository
    }

    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        resolvedCalls.append(ResolveCall(id: id, resolution: resolution, actor: actor))
        guard let index = occurrenceRepository.occurrences.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "ResolvingSchedulingEngineStub", code: 404)))
            return
        }

        switch resolution {
        case .completed:
            occurrenceRepository.occurrences[index].state = .completed
        case .skipped, .deferred:
            occurrenceRepository.occurrences[index].state = .skipped
        case .missed:
            occurrenceRepository.occurrences[index].state = .missed
        case .lapsed:
            occurrenceRepository.occurrences[index].state = .failed
        }
        occurrenceRepository.occurrences[index].updatedAt = Date()
        completion(.success(()))
    }

    func rebuildFutureOccurrences(templateID: UUID, effectiveFrom: Date, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }
}

private final class InMemoryGamificationRepositoryStub: GamificationRepositoryProtocol {
    var profile: GamificationSnapshot?
    var events: [XPEventDefinition] = []
    var dailyAggregates: [String: DailyXPAggregateDefinition] = [:]

    func fetchProfile(completion: @escaping @Sendable (Result<GamificationSnapshot?, Error>) -> Void) {
        completion(.success(profile))
    }

    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        self.profile = profile
        completion(.success(()))
    }

    func fetchXPEvents(completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void) {
        completion(.success(events))
    }

    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void) {
        let filtered = events.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        completion(.success(filtered))
    }

    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        if events.contains(where: { $0.idempotencyKey == event.idempotencyKey }) {
            completion(.failure(GamificationRepositoryWriteError.idempotentReplay(idempotencyKey: event.idempotencyKey)))
            return
        }
        events.append(event)
        completion(.success(()))
    }

    func hasXPEvent(idempotencyKey: String, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        completion(.success(events.contains { $0.idempotencyKey == idempotencyKey }))
    }

    func fetchAchievementUnlocks(completion: @escaping @Sendable (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchDailyAggregate(dateKey: String, completion: @escaping @Sendable (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        completion(.success(dailyAggregates[dateKey]))
    }

    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        dailyAggregates[aggregate.dateKey] = aggregate
        completion(.success(()))
    }

    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping @Sendable (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        completion(.success(Array(dailyAggregates.values)))
    }

    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[FocusSessionDefinition], Error>) -> Void) {
        completion(.success([]))
    }
}
