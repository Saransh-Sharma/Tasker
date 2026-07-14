import CoreData
import XCTest
@testable import LifeBoard

final class LifeBoardPlanningTrackFoundationTests: XCTestCase {
    func testPlanningDayPreservesIntendedLocalDayAcrossTravelAndDST() throws {
        let kolkata = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let losAngeles = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let absolute = Date(timeIntervalSince1970: 1_762_041_600)
        let planned = PlanningDay(date: absolute, timeZone: kolkata)

        XCTAssertEqual(planned.timeZoneIdentifier, "Asia/Kolkata")
        XCTAssertEqual(PlanningDay(date: try XCTUnwrap(planned.startDate()), timeZone: kolkata), planned)
        XCTAssertNotEqual(PlanningDay(date: absolute, timeZone: losAngeles), planned)
    }

    func testCapacityUnionsOverlapsAndDoesNotTreatMissingEstimateAsZeroConfidence() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let budget = CapacityBudgetService.calculate(
            workingIntervals: [DateInterval(start: start, duration: 8 * 3_600)],
            fixedCalendarCommitments: [
                DateInterval(start: start.addingTimeInterval(3_600), duration: 2 * 3_600),
                DateInterval(start: start.addingTimeInterval(2 * 3_600), duration: 2 * 3_600)
            ],
            internalFixedBlocks: [DateInterval(start: start.addingTimeInterval(5 * 3_600), duration: 3_600)],
            userBuffer: 30 * 60,
            plannedEstimates: [2 * 3_600, nil]
        )

        XCTAssertEqual(budget.fixedCalendarDuration, 3 * 3_600)
        XCTAssertEqual(budget.usableDuration, 3.5 * 3_600)
        XCTAssertEqual(budget.plannedEstimatedDuration, 2 * 3_600)
        XCTAssertEqual(budget.missingEstimateCount, 1)
        XCTAssertTrue(budget.isEstimateIncomplete)
        XCTAssertLessThan(budget.confidence, 1)
    }

    func testCapacityDoesNotDoubleCountInternalBlocksOverCalendarContext() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let budget = CapacityBudgetService.calculate(
            workingIntervals: [DateInterval(start: start, duration: 8 * 3_600)],
            fixedCalendarCommitments: [DateInterval(start: start.addingTimeInterval(3_600), duration: 2 * 3_600)],
            internalFixedBlocks: [DateInterval(start: start.addingTimeInterval(2 * 3_600), duration: 2 * 3_600)],
            userBuffer: 0,
            plannedEstimates: []
        )

        XCTAssertEqual(budget.fixedCalendarDuration, 2 * 3_600)
        XCTAssertEqual(budget.internalFixedDuration, 1 * 3_600)
        XCTAssertEqual(budget.usableDuration, 5 * 3_600)
    }

    func testFreeWindowsSubtractOverlappingCalendarAndLifeBoardBlocksExactlyOnce() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let windows = FreeWindowService.calculate(
            workingIntervals: [DateInterval(start: start, duration: 8 * 3_600)],
            occupiedIntervals: [
                DateInterval(start: start.addingTimeInterval(60 * 60), duration: 2 * 60 * 60),
                DateInterval(start: start.addingTimeInterval(2 * 60 * 60), duration: 2 * 60 * 60),
                DateInterval(start: start.addingTimeInterval(6 * 60 * 60), duration: 30 * 60)
            ]
        )

        XCTAssertEqual(windows.count, 3)
        let durations: [TimeInterval] = windows.map(\.duration)
        let expected: [TimeInterval] = [3_600, 7_200, 5_400]
        XCTAssertEqual(durations, expected)
    }

    func testFocusSessionCommandsAreIdempotentAndNeverCreateNegativeDuration() {
        let sessionID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let pauseID = UUID()
        var session = FocusSessionV2(id: sessionID, targetDuration: 1_800, startedAt: startedAt)
        let pause = FocusSessionCommand(
            id: pauseID,
            sessionID: sessionID,
            kind: .pause,
            occurredAt: startedAt.addingTimeInterval(300)
        )
        session = FocusSessionStateMachine.applying(pause, to: session)
        session = FocusSessionStateMachine.applying(pause, to: session)
        XCTAssertEqual(session.interruptionCount, 1)
        XCTAssertEqual(session.state, .paused)

        session = FocusSessionStateMachine.applying(.init(
            sessionID: sessionID,
            kind: .resume,
            occurredAt: startedAt.addingTimeInterval(420)
        ), to: session)
        session = FocusSessionStateMachine.applying(.init(
            sessionID: sessionID,
            kind: .end(.interrupted),
            occurredAt: startedAt.addingTimeInterval(900)
        ), to: session)
        XCTAssertEqual(session.state, .ended)
        XCTAssertEqual(session.focusedDuration(), 780)
        XCTAssertGreaterThanOrEqual(session.focusedDuration(), 0)
    }

    func testDependencyCycleAndReadinessAreDeterministic() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let dependencies: [UUID: Set<UUID>] = [first: [second], second: [third], third: [first]]

        XCTAssertEqual(PlanningDependencyService.cycle(taskIDs: [first, second, third], dependencies: dependencies), [first, second, third, first])
        XCTAssertFalse(PlanningDependencyService.dependencyReady(taskID: first, dependencies: dependencies, completedTaskIDs: []))
        XCTAssertTrue(PlanningDependencyService.dependencyReady(taskID: first, dependencies: dependencies, completedTaskIDs: [second]))
    }

    func testFocusRankingUsesLockedWeightsExclusionsAndStableTieBreak() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pinned = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highScore = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let blocked = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let candidates = [
            FocusRankCandidate(id: pinned, title: "Pinned", pinOrder: 0, priority: .low),
            FocusRankCandidate(
                id: highScore,
                title: "Perfect fit",
                commitmentLevel: .mustDo,
                priority: .urgent,
                dueDate: now.addingTimeInterval(-300),
                estimatedDuration: 30 * 60,
                requiredEnergy: 3,
                planningContext: .work,
                alignsWithWeeklyOutcome: true
            ),
            FocusRankCandidate(id: blocked, title: "Waiting", availability: .waiting)
        ]
        let context = FocusRankContext(
            now: now,
            freeWindowDuration: 45 * 60,
            availableEnergy: 3,
            planningContext: .work
        )
        let results = DeterministicFocusRankingService().rank(candidates, context: context)

        XCTAssertEqual(results.map(\.candidateID), [pinned, highScore, blocked])
        let perfect = try! XCTUnwrap(results.first(where: { $0.candidateID == highScore }))
        XCTAssertEqual(perfect.totalScore, 100)
        XCTAssertEqual(perfect.componentScores[.urgency], 25)
        XCTAssertEqual(perfect.componentScores[.priority], 20)
        XCTAssertEqual(perfect.componentScores[.freeWindowFit], 15)
        XCTAssertEqual(perfect.componentScores[.durationFit], 10)
        XCTAssertEqual(perfect.componentScores[.energyFit], 10)
        XCTAssertEqual(perfect.componentScores[.contextFit], 10)
        XCTAssertEqual(perfect.componentScores[.dependencyReadiness], 5)
        XCTAssertEqual(perfect.componentScores[.weeklyOutcomeAlignment], 5)
        XCTAssertEqual(results.last?.eligibilityExclusions, [.waiting])
    }

    func testMissingFocusSignalsAreNeutralAndReduceConfidence() throws {
        let id = UUID()
        let result = try XCTUnwrap(DeterministicFocusRankingService().rank(
            [.init(id: id, title: "Unknown fit")],
            context: .init()
        ).first)
        XCTAssertEqual(result.componentScores[.freeWindowFit], 8)
        XCTAssertEqual(result.componentScores[.durationFit], 5)
        XCTAssertEqual(result.componentScores[.energyFit], 5)
        XCTAssertEqual(result.componentScores[.contextFit], 5)
        XCTAssertTrue(result.missingInformation.contains("task estimate"))
        XCTAssertLessThan(result.confidence, 1)
    }

    func testPlanRepairAndEstimateCalibrationRequireDeterministicEvidence() throws {
        let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")
        let now = Date(timeIntervalSince1970: 2_000)
        let taskID = UUID()
        let block = InternalTimeBlock(title: "Past", startAt: Date(timeIntervalSince1970: 0), endAt: Date(timeIntervalSince1970: 1_000), taskID: taskID)
        let task = PlanningTaskSummary(id: taskID, title: "Repair", projectID: UUID(), metadata: .init(taskID: taskID))
        let snapshot = PlanDaySnapshot(
            day: day,
            capacity: .init(
                workingDuration: 3_600, fixedCalendarDuration: 0, internalFixedDuration: 0,
                bufferDuration: 0, plannedEstimatedDuration: 7_200, missingEstimateCount: 0
            ),
            commitments: [], blocks: [block], plannedTasks: [task], unscheduledTasks: [], generatedAt: now
        )
        let proposals = DeterministicPlanRepairService().proposals(for: snapshot, now: now)
        XCTAssertEqual(Set(proposals.map(\.trigger)), [.missedPlannedWork, .overloadedWindow])
        XCTAssertNil(EstimateCalibrationService.suggestion(taskID: taskID, comparableDurations: [600, 900]))
        let suggestion = try XCTUnwrap(EstimateCalibrationService.suggestion(taskID: taskID, comparableDurations: [600, 920, 1_200]))
        XCTAssertEqual(suggestion.evidenceSessionCount, 3)
        XCTAssertEqual(suggestion.suggestedDuration, 900)
    }

    func testHabitGradeOffDaysSkipAndRecoveryRules() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14, hour: 12)))
        let habitID = UUID()
        let day12 = PlanningDay(year: 2026, month: 7, day: 12, timeZoneIdentifier: calendar.timeZone.identifier)
        let day13 = PlanningDay(year: 2026, month: 7, day: 13, timeZoneIdentifier: calendar.timeZone.identifier)
        let day14 = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: calendar.timeZone.identifier)
        let policy = HabitResiliencePolicy(habitID: habitID, offDays: [day13])
        let snapshot = DefaultHabitGradeEngine().evaluate(
            habitID: habitID,
            occurrences: [
                .init(habitID: habitID, day: day12, resolution: .recovered),
                .init(habitID: habitID, day: day13, resolution: .due),
                .init(habitID: habitID, day: day14, resolution: .completed)
            ],
            policy: policy,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(snapshot.eligibleDueCount, 2)
        XCTAssertEqual(snapshot.completedEligibleCount, 2)
        XCTAssertEqual(snapshot.grade, 1)
        XCTAssertEqual(snapshot.streak, 2)
        XCTAssertEqual(snapshot.recoveredDays, [day12])
    }

    func testRoutineBranchingSnapshotAndRepeatedTapAreIdempotent() throws {
        let choiceID = UUID()
        let lowID = UUID()
        let normalID = UUID()
        let routine = RoutineDefinition(title: "Adaptive morning", steps: [
            .init(
                id: choiceID, title: "How is your energy?", kind: .choice, ordinal: 0,
                choices: ["Low", "Normal"],
                branches: [.init(sourceStepID: choiceID, operation: .equals, expectedResponse: "Low", destinationStepID: lowID)]
            ),
            .init(id: normalID, title: "Normal plan", kind: .instruction, ordinal: 1),
            .init(id: lowID, title: "Recovery plan", kind: .instruction, ordinal: 2)
        ])
        let service = DefaultRoutineExecutionService()
        let run = service.begin(routine, at: .distantPast)
        let first = service.advance(run: run, response: "Low", skip: false, idempotencyKey: "tap-1", at: Date())
        XCTAssertEqual(first.run.currentStepID, lowID)
        let duplicate = service.advance(run: first.run, response: "Low", skip: false, idempotencyKey: "tap-1", at: Date())
        XCTAssertFalse(duplicate.didApplyEvent)
        XCTAssertEqual(duplicate.run.events.count, 1)

        var edited = routine
        edited.steps.removeAll()
        XCTAssertEqual(first.run.versionSnapshot.steps.count, 3)
        XCTAssertTrue(edited.steps.isEmpty)
    }

    func testGoalProgressReportsIncompleteDataWithoutInferringCompletion() throws {
        let goal = GoalDefinition(title: "Read", type: .count, targetValue: 10)
        let first = GoalLink(goalID: goal.id, source: .trackerMeasure, sourceID: UUID())
        let second = GoalLink(goalID: goal.id, source: .trackerMeasure, sourceID: UUID())
        let snapshot = DefaultGoalProgressService().progress(
            for: goal,
            links: [first, second],
            samples: [.init(linkID: first.id, value: 4, isComplete: nil, measuredAt: Date())]
        )
        XCTAssertEqual(snapshot.currentValue, 4)
        XCTAssertEqual(snapshot.progressFraction, 0.4)
        XCTAssertEqual(snapshot.confidence, 0.5)
        XCTAssertEqual(snapshot.missingLinkCount, 1)
    }

    func testHydrationConversionAndSleepPrivacy() {
        XCTAssertEqual(HydrationMeasurementService.convert(1, from: .liters, to: .milliliters), 1_000)
        XCTAssertEqual(HydrationMeasurementService.convert(1_000, from: .milliliters, to: .liters), 1)
        XCTAssertEqual(HydrationMeasurementService.milliliters(1, unit: .fluidOunces), 29.573_529_562_5, accuracy: 0.000_001)
        let sleep = SleepContextRecord(bedtime: Date(), wakeTime: Date().addingTimeInterval(8 * 3_600))
        XCTAssertEqual(sleep.sensitivity, .privateSensitive)
    }

    func testPlanningAndTrackModelsAreSerializedAndCorrectlyConfigured() throws {
        let momd = try modelBundleURL()
        let knowledge = try XCTUnwrap(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("TaskModelV3_KnowledgeNotes.mom")))
        let planning = try XCTUnwrap(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("TaskModelV3_PlanningCore.mom")))
        let track = try XCTUnwrap(NSManagedObjectModel(contentsOf: momd.appendingPathComponent("TaskModelV3_TrackFoundations.mom")))
        _ = try NSMappingModel.inferredMappingModel(forSourceModel: knowledge, destinationModel: planning)
        _ = try NSMappingModel.inferredMappingModel(forSourceModel: planning, destinationModel: track)

        let task = try XCTUnwrap(planning.entitiesByName["TaskDefinition"])
        XCTAssertNotNil(task.attributesByName["planningDayTimeZoneIdentifier"])
        XCTAssertNotNil(task.attributesByName["unscheduledDispositionRaw"])
        XCTAssertNotNil(task.indexes.first(where: { $0.name == "byPlanningDayAvailability" }))
        XCTAssertNotNil(planning.entitiesByName["InternalTimeBlock"])
        XCTAssertNotNil(track.entitiesByName["GoalDefinition"])
        XCTAssertNotNil(track.entitiesByName["RoutineRun"])
        XCTAssertNotNil(track.entitiesByName["HydrationLog"])
        XCTAssertNotNil(track.entitiesByName["SleepContextRecord"])
        XCTAssertNotNil(track.entitiesByName["RoutineSchedule"])
        XCTAssertNotNil(track.entitiesByName["RoutineLinkedMutationReceipt"])

        let cloud = Set(try XCTUnwrap(track.entities(forConfigurationName: "CloudSync")).compactMap(\.name))
        for name in ["InternalTimeBlock", "WorkingHoursProfile", "GoalDefinition", "HabitResiliencePolicy", "RoutineRun", "HydrationLog", "SleepContextRecord"] {
            XCTAssertTrue(cloud.contains(name), "\(name) must be private CloudSync data")
        }
    }

    func testPlanningAndTrackRepositoriesRoundTripAdditiveData() async throws {
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: try modelBundleURL().appendingPathComponent("TaskModelV3_TrackFoundations.mom")))
        let container = NSPersistentContainer(name: "PlanningTrackRoundTrip", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.configuration = "CloudSync"
        description.url = URL(fileURLWithPath: "/dev/null/cloud-\(UUID().uuidString)")
        let localDescription = NSPersistentStoreDescription()
        localDescription.type = NSInMemoryStoreType
        localDescription.configuration = "LocalOnly"
        localDescription.url = URL(fileURLWithPath: "/dev/null/local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [description, localDescription]
        try await load(container)

        let taskID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Plan me", forKey: "title")
            try context.save()
        }
        let planning = CoreDataPlanningRepository(container: container)
        let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")
        try await planning.saveTaskMetadata(.init(
            taskID: taskID,
            planningDay: day,
            commitmentLevel: .mustDo,
            unscheduledDisposition: .someday
        ))
        let block = InternalTimeBlock(title: "Deep work", startAt: Date(), endAt: Date().addingTimeInterval(3_600), taskID: taskID)
        try await planning.saveTimeBlock(block)
        let fetchedMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        let fetchedBlocks = try await planning.fetchTimeBlocks(from: .distantPast, to: .distantFuture)
        let fetchedTasks = try await planning.fetchOpenPlanningTasks()
        XCTAssertEqual(fetchedMetadata.first?.planningDay, day)
        XCTAssertEqual(fetchedMetadata.first?.unscheduledDisposition, .someday)
        XCTAssertEqual(fetchedBlocks.map(\.id), [block.id])
        XCTAssertEqual(fetchedTasks.map(\.id), [taskID])
        XCTAssertEqual(fetchedTasks.first?.title, "Plan me")
        XCTAssertTrue(fetchedTasks.first?.dependenciesReady == true)

        let before = try XCTUnwrap(fetchedMetadata.first)
        var after = before
        after.commitmentLevel = .standard
        let mutationReceipt = try await planning.prepare(
            .saveTaskMetadata(before: before, after: after),
            source: "test",
            summary: "Change commitment"
        )
        try await planning.apply(receiptID: mutationReceipt.id)
        let appliedMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(appliedMetadata.first?.commitmentLevel, .standard)
        try await planning.undo(receiptID: mutationReceipt.id)
        let undoneMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(undoneMetadata.first?.commitmentLevel, .mustDo)

        let focus = try await planning.start(taskID: taskID, timeBlockID: block.id, targetDuration: 1_500, at: Date())
        let pause = FocusSessionCommand(sessionID: focus.id, kind: .pause, occurredAt: focus.startedAt.addingTimeInterval(300))
        _ = try await planning.handle(pause)
        let duplicate = try await planning.handle(pause)
        XCTAssertEqual(duplicate.interruptionCount, 1)
        let restoredFocus = try await planning.activeSession()
        XCTAssertEqual(restoredFocus?.id, focus.id)

        let track = CoreDataTrackFoundationRepository(container: container)
        let goal = GoalDefinition(title: "Ship", type: .completion)
        try await track.saveGoal(goal)
        let routine = RoutineDefinition(title: "Start", steps: [.init(title: "Begin", kind: .instruction, ordinal: 0)])
        try await track.saveRoutine(routine)
        let schedule = RoutineSchedule(routineID: routine.id, weekdays: [2, 4, 6], daypart: .morning)
        try await track.saveRoutineSchedule(schedule)
        let linkedReceipt = RoutineLinkedMutationReceipt(
            runID: UUID(),
            stepID: routine.steps[0].id,
            mutation: .completeTask,
            targetID: taskID,
            idempotencyKey: "run:step"
        )
        try await track.saveRoutineLinkedMutationReceipt(linkedReceipt)
        let installation = StarterPackInstallation(pack: .workdayReset, createdIDs: [.routine: [routine.id]])
        try await track.saveStarterPackInstallation(installation)
        let hydration = HydrationLog(amount: 250, unit: .milliliters)
        try await track.saveHydrationLog(hydration)
        let fetchedGoals = try await track.fetchGoals()
        let fetchedRoutines = try await track.fetchRoutines()
        let fetchedSchedules = try await track.fetchRoutineSchedules(routineID: routine.id)
        let fetchedHydration = try await track.fetchHydrationLogs(from: .distantPast, to: .distantFuture)
        XCTAssertEqual(fetchedGoals.map(\.id), [goal.id])
        XCTAssertEqual(fetchedRoutines.first?.steps.count, 1)
        XCTAssertEqual(fetchedSchedules.first, schedule)
        let fetchedLinkedReceipt = try await track.fetchRoutineLinkedMutationReceipt(idempotencyKey: "run:step")
        let fetchedInstallations = try await track.fetchStarterPackInstallations()
        XCTAssertEqual(fetchedLinkedReceipt, linkedReceipt)
        XCTAssertEqual(fetchedInstallations.first, installation)
        XCTAssertEqual(fetchedHydration.first?.amount, 250)
    }

    private func modelBundleURL() throws -> URL {
        for bundle in [Bundle.main, Bundle(for: Self.self)] {
            if let url = bundle.url(forResource: "TaskModelV3", withExtension: "momd") { return url }
        }
        throw NSError(domain: "LifeBoardPlanningTrackFoundationTests", code: 1)
    }

    private func load(_ container: NSPersistentContainer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let lock = NSLock()
            var remaining = container.persistentStoreDescriptions.count
            var firstError: (any Error)?
            container.loadPersistentStores { _, error in
                lock.lock()
                if firstError == nil { firstError = error }
                remaining -= 1
                let isFinished = remaining == 0
                let resolvedError = firstError
                lock.unlock()

                guard isFinished else { return }
                if let resolvedError { continuation.resume(throwing: resolvedError) }
                else { continuation.resume() }
            }
        }
    }
}
