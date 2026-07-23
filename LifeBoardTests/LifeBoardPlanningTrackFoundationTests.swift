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

    func testFocusNotificationFallbackOnlySchedulesForAuthorizedRunningSessionsWithoutLiveActivities() {
        let now = Date(timeIntervalSince1970: 1_000)
        let running = FocusSessionV2(targetDuration: 1_800, startedAt: now.addingTimeInterval(-300))
        XCTAssertEqual(
            FocusNotificationFallbackPolicy.decision(
                for: running,
                now: now,
                liveActivitiesAvailable: false,
                notificationsAuthorized: true
            ),
            .schedule(after: 1_500)
        )
        XCTAssertEqual(
            FocusNotificationFallbackPolicy.decision(
                for: running,
                now: now,
                liveActivitiesAvailable: true,
                notificationsAuthorized: true
            ),
            .cancel
        )
        XCTAssertEqual(
            FocusNotificationFallbackPolicy.decision(
                for: running,
                now: now,
                liveActivitiesAvailable: false,
                notificationsAuthorized: false
            ),
            .cancel
        )

        var paused = running
        paused.state = .paused
        XCTAssertEqual(
            FocusNotificationFallbackPolicy.decision(
                for: paused,
                now: now,
                liveActivitiesAvailable: false,
                notificationsAuthorized: true
            ),
            .cancel
        )
    }

    func testFocusStartupRepairEndsExpiredRunningSessionsButPreservesPausedWork() {
        let now = Date(timeIntervalSince1970: 4_000)
        let expired = FocusSessionV2(targetDuration: 1_800, startedAt: now.addingTimeInterval(-1_801))
        XCTAssertEqual(FocusStartupRepairPolicy.commandKind(for: expired, now: now), .end(.completed))

        var paused = expired
        paused.state = .paused
        XCTAssertNil(FocusStartupRepairPolicy.commandKind(for: paused, now: now))

        let active = FocusSessionV2(targetDuration: 1_800, startedAt: now.addingTimeInterval(-300))
        XCTAssertNil(FocusStartupRepairPolicy.commandKind(for: active, now: now))
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

    func testHabitRecoveryReceiptOnlyUpgradesCanonicalCompletion() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14, hour: 12)))
        let habitID = UUID()
        let completedDay = PlanningDay(year: 2026, month: 7, day: 13, timeZoneIdentifier: calendar.timeZone.identifier)
        let stillDueDay = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: calendar.timeZone.identifier)
        let policy = HabitResiliencePolicy(
            habitID: habitID,
            recoveryReceipts: [
                .init(habitID: habitID, day: completedDay, previousState: .missed),
                .init(habitID: habitID, day: stillDueDay, previousState: .missed)
            ]
        )

        let snapshot = DefaultHabitGradeEngine().evaluate(
            habitID: habitID,
            occurrences: [
                .init(habitID: habitID, day: completedDay, resolution: .completed),
                .init(habitID: habitID, day: stillDueDay, resolution: .due)
            ],
            policy: policy,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.completedEligibleCount, 1)
        XCTAssertEqual(snapshot.eligibleDueCount, 2)
        XCTAssertEqual(snapshot.grade, 0.5)
        XCTAssertEqual(snapshot.recoveredDays, [completedDay])
    }

    func testHabitResiliencePolicyDecodesPreRecoveryPayload() throws {
        struct LegacyPolicy: Codable {
            var id: UUID
            var habitID: UUID
            var groupID: UUID?
            var offDays: Set<PlanningDay>
            var recoveryEnabled: Bool
            var streakPresentation: HabitStreakPresentation
            var updatedAt: Date
        }
        let habitID = UUID()
        let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")
        let legacy = LegacyPolicy(
            id: UUID(), habitID: habitID, groupID: nil, offDays: [day],
            recoveryEnabled: true, streakPresentation: .gradeAndStreak, updatedAt: .distantPast
        )
        let decoded = try JSONDecoder().decode(
            HabitResiliencePolicy.self,
            from: JSONEncoder().encode(legacy)
        )

        XCTAssertEqual(decoded.id, legacy.id)
        XCTAssertEqual(decoded.habitID, habitID)
        XCTAssertEqual(decoded.offDays, [day])
        XCTAssertTrue(decoded.recoveryReceipts.isEmpty)
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

    func testProactiveEvaPolicyHonorsFrequencyAndDisplacementGuards() {
        let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")
        let card = EvaProactiveCard(destination: .plan, localDay: day, title: "A calmer option", reason: "The day is overloaded")
        XCTAssertTrue(ProactiveCardPolicy.canPresent(
            card, existing: [], activeFocus: false,
            safetySensitiveCareRequiresAttention: false, hasPinnedCommitment: false
        ))
        XCTAssertFalse(ProactiveCardPolicy.canPresent(
            card, existing: [card], activeFocus: false,
            safetySensitiveCareRequiresAttention: false, hasPinnedCommitment: false
        ))
        XCTAssertFalse(ProactiveCardPolicy.canPresent(
            card, existing: [], activeFocus: true,
            safetySensitiveCareRequiresAttention: false, hasPinnedCommitment: false
        ))
        XCTAssertFalse(ProactiveCardPolicy.canPresent(
            card, existing: [], activeFocus: false,
            safetySensitiveCareRequiresAttention: true, hasPinnedCommitment: false
        ))

        let hero = AdaptiveHeroSnapshot(
            id: "focus", priority: .generalFocus, title: "Focus", primaryActionTitle: "Start",
            secondaryActionTitles: ["Why this?", "Later", "Extra"]
        )
        XCTAssertEqual(hero.secondaryActionTitles, ["Why this?", "Later"])
        XCTAssertEqual(HomeSignalSlot(
            id: "water", title: "Water", progress: 2, systemImage: "drop", availability: .available
        ).progress, 1)
    }

    func testCanonicalHabitProjectionUsesHistoryWithoutInventingFutureDueWork() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_720_944_000)
        let habitID = UUID()
        let repository = HabitProjectionRepositoryStub(
            rows: [.init(
                habitID: habitID, title: "Walk", kind: .positive, trackingMode: .dailyCheckIn,
                lifeAreaID: UUID(), lifeAreaName: "Health", isPaused: false, isArchived: false,
                currentStreak: 1, bestStreak: 2
            )],
            history: [.init(habitID: habitID, marks: [
                .init(date: now.addingTimeInterval(-86_400), state: .success),
                .init(date: now, state: .skipped),
                .init(date: now.addingTimeInterval(86_400), state: .future)
            ])]
        )
        let service = CanonicalTrackHabitProjectionService(repository: repository)
        let evidence = try await service.occurrenceEvidence(
            from: now.addingTimeInterval(-2 * 86_400),
            to: now.addingTimeInterval(2 * 86_400),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(evidence[habitID]?.map(\.resolution), [.completed, .manuallySkipped, .due])
        XCTAssertEqual(evidence[habitID]?.last?.isDue, false)
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
        let projectID = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
            project.setValue(projectID, forKey: "id")
            project.setValue("LifeBoard 5.0", forKey: "name")
            project.setValue(false, forKey: "isArchived")
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

        let fetchedProjects = try await planning.fetchPlanningProjects()
        XCTAssertEqual(fetchedProjects, [.init(id: projectID, name: "LifeBoard 5.0", isArchived: false)])
        let sourcePicker = ComposedTypedSourcePickerRepository(planningProjection: planning)
        let projectSources = try await sourcePicker.candidates(for: .project, query: "lifeboard")
        XCTAssertEqual(projectSources.map(\.title), ["LifeBoard 5.0"])
        XCTAssertFalse(projectSources.contains(where: { $0.title.contains(String(projectID.uuidString.prefix(8))) }))

        let before = try XCTUnwrap(fetchedMetadata.first)
        var after = before
        after.commitmentLevel = .standard
        let mutationReceipt = try await planning.prepare(
            .saveTaskMetadata(before: before, after: after),
            source: "test",
            summary: "Change commitment"
        )
        try await planning.apply(receiptID: mutationReceipt.id)
        let hasAppliedReceipt = try await planning.hasAppliedReceipt(source: "test")
        XCTAssertTrue(hasAppliedReceipt)
        let appliedMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(appliedMetadata.first?.commitmentLevel, .standard)
        try await planning.undo(receiptID: mutationReceipt.id)
        let hasAppliedReceiptAfterUndo = try await planning.hasAppliedReceipt(source: "test")
        XCTAssertFalse(hasAppliedReceiptAfterUndo)
        let undoneMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(undoneMetadata.first?.commitmentLevel, .mustDo)
        let archiveBefore = try XCTUnwrap(undoneMetadata.first)
        var archiveAfter = archiveBefore
        archiveAfter.planningDay = nil
        archiveAfter.unscheduledDisposition = .archived
        archiveAfter.updatedAt = Date()
        let archiveReceipt = try await planning.prepare(
            .saveTaskMetadata(before: archiveBefore, after: archiveAfter),
            source: "test.backlog.archive",
            summary: "Archive task"
        )
        try await planning.apply(receiptID: archiveReceipt.id)
        let archivedMetadata = try await CoreDataPlanningRepository(container: container).fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(archivedMetadata.first?.unscheduledDisposition, .archived)
        XCTAssertNil(archivedMetadata.first?.planningDay)
        try await planning.undo(receiptID: archiveReceipt.id)
        let restoredMetadata = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(restoredMetadata.first?.unscheduledDisposition, .someday)
        XCTAssertEqual(restoredMetadata.first?.planningDay, day)

        let deletionBefore = try XCTUnwrap(restoredMetadata.first)
        var deletionAfter = deletionBefore
        deletionAfter.planningDay = nil
        deletionAfter.unscheduledDisposition = .deleted
        deletionAfter.updatedAt = Date()
        let deletionReceipt = try await planning.prepare(
            .saveTaskMetadata(before: deletionBefore, after: deletionAfter),
            source: "plan.backlog.delete",
            summary: "Deleted 1 backlog item"
        )
        try await planning.apply(receiptID: deletionReceipt.id)
        try await planning.apply(receiptID: deletionReceipt.id)
        let relaunchedAfterDeletion = CoreDataPlanningRepository(container: container)
        let tombstonedMetadata = try await relaunchedAfterDeletion.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(tombstonedMetadata.first?.unscheduledDisposition, .deleted)
        XCTAssertNil(tombstonedMetadata.first?.planningDay)
        let openTasksAfterDeletion = try await relaunchedAfterDeletion.fetchOpenPlanningTasks()
        let taskSourcesAfterDeletion = try await sourcePicker.candidates(for: .task, query: "Plan me")
        XCTAssertFalse(openTasksAfterDeletion.contains(where: { $0.id == taskID }))
        XCTAssertTrue(taskSourcesAfterDeletion.isEmpty)
        let deletionReceipts = try await relaunchedAfterDeletion.fetchMutationReceipts(since: nil)
        let persistedDeletionReceipt = try XCTUnwrap(deletionReceipts.first(where: { $0.id == deletionReceipt.id }))
        XCTAssertEqual(persistedDeletionReceipt.state, .applied)
        try await relaunchedAfterDeletion.undo(receiptID: deletionReceipt.id)
        try await relaunchedAfterDeletion.undo(receiptID: deletionReceipt.id)
        let restoredAfterDeletion = try await planning.fetchTaskMetadata(taskIDs: [taskID])
        XCTAssertEqual(restoredAfterDeletion.first?.unscheduledDisposition, .someday)
        XCTAssertEqual(restoredAfterDeletion.first?.planningDay, day)
        let openTasksAfterUndo = try await planning.fetchOpenPlanningTasks()
        let taskSourcesAfterUndo = try await sourcePicker.candidates(for: .task, query: "Plan me")
        XCTAssertEqual(openTasksAfterUndo.map(\.id), [taskID])
        XCTAssertEqual(taskSourcesAfterUndo.map(\.id), [taskID])

        let relaunchedPlanning = CoreDataPlanningRepository(container: container)
        let restoredReceipts = try await relaunchedPlanning.fetchMutationReceipts(since: nil)
        let restoredReceipt = try XCTUnwrap(restoredReceipts.first(where: { $0.id == mutationReceipt.id }))
        XCTAssertEqual(restoredReceipt.state, .undone)
        XCTAssertEqual(restoredReceipt.receipt.summary, "Change commitment")
        XCTAssertNotNil(restoredReceipt.undoneAt)

        let focus = try await planning.start(taskID: taskID, timeBlockID: block.id, targetDuration: 1_500, at: Date())
        let pause = FocusSessionCommand(sessionID: focus.id, kind: .pause, occurredAt: focus.startedAt.addingTimeInterval(300))
        _ = try await planning.handle(pause)
        let duplicate = try await planning.handle(pause)
        XCTAssertEqual(duplicate.interruptionCount, 1)
        let stalePause = FocusSessionCommand(
            sessionID: focus.id,
            kind: .pause,
            occurredAt: pause.occurredAt.addingTimeInterval(1)
        )
        let ignored = try await planning.handle(stalePause)
        XCTAssertEqual(ignored.interruptionCount, 1)
        let restoredFocus = try await planning.activeSession()
        XCTAssertEqual(restoredFocus?.id, focus.id)
        let exactFocus = try await planning.session(id: focus.id)
        let missingFocus = try await planning.session(id: UUID())
        XCTAssertEqual(exactFocus?.id, focus.id)
        XCTAssertNil(missingFocus)
        let restoredSessionIDs = try await relaunchedPlanning.sessions(since: nil).map(\.id)
        XCTAssertEqual(restoredSessionIDs, [focus.id])
        let restoredFocusCommands = try await relaunchedPlanning.commandReceipts(since: nil)
        XCTAssertEqual(restoredFocusCommands.map(\.id), [stalePause.id, pause.id])
        XCTAssertEqual(restoredFocusCommands.last?.sessionID, focus.id)
        XCTAssertEqual(restoredFocusCommands.last?.kind, .pause)
        XCTAssertEqual(restoredFocusCommands.last?.resultingState, .paused)
        XCTAssertEqual(restoredFocusCommands.last?.focusedDuration, 300)
        XCTAssertEqual(restoredFocusCommands.last?.wasApplied, true)
        XCTAssertEqual(restoredFocusCommands.first?.wasApplied, false)
        let commandsAfterWindow = try await relaunchedPlanning.commandReceipts(
            since: stalePause.occurredAt.addingTimeInterval(1)
        )
        XCTAssertTrue(commandsAfterWindow.isEmpty)

        let track = CoreDataTrackFoundationRepository(container: container)
        let habitGroup = HabitGroup(title: "Morning anchors", planningContext: .personal, ordinal: 0)
        try await track.saveHabitGroup(habitGroup)
        let habitPolicyHabitID = UUID()
        var habitPolicy = HabitResiliencePolicy(
            habitID: habitPolicyHabitID,
            groupID: habitGroup.id,
            offDays: [day],
            recoveryEnabled: true,
            streakPresentation: .gradeAndStreak,
            recoveryReceipts: [
                HabitRecoveryReceipt(
                    habitID: habitPolicyHabitID,
                    day: day,
                    occurrenceID: UUID(),
                    previousState: .missed
                )
            ]
        )
        try await track.saveHabitResiliencePolicy(habitPolicy)
        habitPolicy.recoveryEnabled = false
        habitPolicy.streakPresentation = .countsOnly
        habitPolicy.updatedAt = Date()
        try await track.saveHabitResiliencePolicy(habitPolicy)
        var goal = GoalDefinition(title: "Ship", type: .completion)
        try await track.saveGoal(goal)
        let goalLink = GoalLink(goalID: goal.id, source: .task, sourceID: taskID)
        try await track.saveGoalLink(goalLink)
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            let task = try XCTUnwrap(context.fetch(request).first)
            task.setValue(true, forKey: "isComplete")
            task.setValue(Date(), forKey: "updatedAt")
            try context.save()
        }
        let goalSamples = try await CoreDataGoalSampleProvider(container: container).samples(for: [goalLink], asOf: Date())
        XCTAssertEqual(goalSamples.first?.isComplete, true)
        goal.title = "Ship LifeBoard"
        goal.updatedAt = Date()
        try await track.saveGoal(goal)

        var routine = RoutineDefinition(title: "Start", steps: [.init(title: "Begin", kind: .instruction, ordinal: 0)])
        try await track.saveRoutine(routine)
        let schedule = RoutineSchedule(routineID: routine.id, weekdays: [2, 4, 6], daypart: .morning)
        try await track.saveRoutineSchedule(schedule)
        let startedRun = DefaultRoutineExecutionService().begin(routine, at: Date().addingTimeInterval(-300))
        let completedRun = DefaultRoutineExecutionService().advance(
            run: startedRun,
            response: nil,
            skip: false,
            idempotencyKey: "roundtrip-complete",
            at: Date()
        ).run
        try await track.saveRoutineRun(completedRun)
        routine.title = "Start gently"
        routine.version = 2
        routine.steps.append(.init(title: "Continue", kind: .instruction, ordinal: 1))
        routine.updatedAt = Date()
        try await track.saveRoutine(routine)
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
        var hydration = HydrationLog(amount: 250, unit: .milliliters)
        try await track.saveHydrationLog(hydration)
        hydration.amount = 300
        hydration.correctedAt = Date()
        try await track.saveHydrationLog(hydration)
        var sleep = SleepContextRecord(
            bedtime: Date().addingTimeInterval(-8 * 3_600),
            wakeTime: Date(),
            perceivedRest: 3,
            interruptionCount: 1
        )
        try await track.saveSleepContextRecord(sleep)
        sleep.perceivedRest = 4
        sleep.notes = "Corrected after review"
        try await track.saveSleepContextRecord(sleep)
        let fetchedGoals = try await track.fetchGoals()
        let fetchedHabitPolicies = try await track.fetchHabitResiliencePolicies()
        let fetchedHabitGroups = try await track.fetchHabitGroups()
        let fetchedRoutines = try await track.fetchRoutines()
        let fetchedSchedules = try await track.fetchRoutineSchedules(routineID: routine.id)
        let fetchedHydration = try await track.fetchHydrationLogs(from: .distantPast, to: .distantFuture)
        XCTAssertEqual(fetchedGoals.map(\.id), [goal.id])
        XCTAssertEqual(fetchedHabitPolicies, [habitPolicy])
        XCTAssertEqual(fetchedHabitGroups, [habitGroup])
        XCTAssertEqual(fetchedGoals.first?.title, "Ship LifeBoard")
        XCTAssertEqual(fetchedRoutines.first?.steps.count, 2)
        XCTAssertEqual(fetchedRoutines.first?.version, 2)
        XCTAssertEqual(fetchedSchedules.first, schedule)
        let fetchedLinkedReceipt = try await track.fetchRoutineLinkedMutationReceipt(idempotencyKey: "run:step")
        let fetchedInstallations = try await track.fetchStarterPackInstallations()
        XCTAssertEqual(fetchedLinkedReceipt, linkedReceipt)
        XCTAssertEqual(fetchedInstallations.first, installation)
        XCTAssertEqual(fetchedHydration.first?.amount, 300)
        XCTAssertNotNil(fetchedHydration.first?.correctedAt)
        let fetchedSleep = try await track.fetchSleepContextRecords(from: .distantPast, to: .distantFuture)
        XCTAssertEqual(fetchedSleep.count, 1)
        XCTAssertEqual(fetchedSleep.first?.perceivedRest, 4)
        XCTAssertEqual(fetchedSleep.first?.notes, "Corrected after review")
        try await track.deleteHydrationLog(id: hydration.id)
        try await track.deleteSleepContextRecord(id: sleep.id)
        let hydrationAfterDelete = try await track.fetchHydrationLogs(from: .distantPast, to: .distantFuture)
        let sleepAfterDelete = try await track.fetchSleepContextRecords(from: .distantPast, to: .distantFuture)
        XCTAssertTrue(hydrationAfterDelete.isEmpty)
        XCTAssertTrue(sleepAfterDelete.isEmpty)

        try await track.deleteGoal(id: goal.id)
        try await track.deleteRoutine(id: routine.id)
        let goalsAfterDelete = try await track.fetchGoals()
        let linksAfterDelete = try await track.fetchGoalLinks(goalID: goal.id)
        let routinesAfterDelete = try await track.fetchRoutines()
        let schedulesAfterDelete = try await track.fetchRoutineSchedules(routineID: routine.id)
        XCTAssertTrue(goalsAfterDelete.isEmpty)
        XCTAssertTrue(linksAfterDelete.isEmpty)
        XCTAssertTrue(routinesAfterDelete.isEmpty)
        XCTAssertTrue(schedulesAfterDelete.isEmpty)
        let retainedRuns = try await track.fetchRoutineRuns(routineID: routine.id)
        XCTAssertEqual(retainedRuns.count, 1)
        XCTAssertEqual(retainedRuns.first?.versionSnapshot.version, 1)
        XCTAssertEqual(retainedRuns.first?.versionSnapshot.title, "Start")
        try await track.deleteHabitGroup(id: habitGroup.id)
        let groupsAfterDelete = try await track.fetchHabitGroups()
        let policiesAfterGroupDelete = try await track.fetchHabitResiliencePolicies()
        XCTAssertTrue(groupsAfterDelete.isEmpty)
        XCTAssertNil(policiesAfterGroupDelete.first?.groupID)
    }

    func testTrackCorrectionReceiptIsDeterministicAndPreservesExactSnapshots() throws {
        let sourceID = UUID(uuidString: "E7EAC788-E837-4B12-93B8-1A7F7252A031")!
        let appliedAt = Date(timeIntervalSinceReferenceDate: 800_000_000.125)
        let previous = HydrationLog(
            id: sourceID,
            amount: 250,
            unit: .milliliters,
            timestamp: appliedAt.addingTimeInterval(-300),
            note: "Before"
        )
        let corrected = HydrationLog(
            id: sourceID,
            amount: 300,
            unit: .milliliters,
            timestamp: previous.timestamp,
            note: "After",
            correctedAt: appliedAt
        )

        let first = try TrackCorrectionReceipt.deterministic(
            previous: .hydration(previous),
            corrected: .hydration(corrected),
            appliedAt: appliedAt
        )
        let replay = try TrackCorrectionReceipt.deterministic(
            previous: .hydration(previous),
            corrected: .hydration(corrected),
            appliedAt: appliedAt
        )

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.sourceID, sourceID)
        XCTAssertEqual(first.domain, .hydration)
        XCTAssertEqual(first.previous, .hydration(previous))
        XCTAssertEqual(first.corrected, .hydration(corrected))
        XCTAssertEqual(first.reversalState, .reversible(receiptID: first.id))
    }

    func testProtectedTrackCorrectionRepositoryRoundTripsReversalWithoutChangingReceiptIdentity() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackCorrectionReceiptTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalTrackCorrectionReceiptRepository(rootURL: root)
        let appliedAt = Date(timeIntervalSinceReferenceDate: 800_000_100)
        let previous = LifeBoardTrackerEntryValue(
            id: UUID(), trackerID: UUID(), timestamp: appliedAt.addingTimeInterval(-60), numericValue: 3
        )
        var corrected = previous
        corrected.numericValue = 4
        let receipt = try TrackCorrectionReceipt.deterministic(
            previous: .tracker(previous), corrected: .tracker(corrected), appliedAt: appliedAt
        )

        try await repository.saveTrackCorrectionReceipt(receipt)
        let storedReceipts = try await repository.fetchTrackCorrectionReceipts()
        var fetched = try XCTUnwrap(storedReceipts.first)
        XCTAssertEqual(fetched, receipt)

        fetched.reversedAt = appliedAt.addingTimeInterval(10)
        try await repository.saveTrackCorrectionReceipt(fetched)
        let reversedReceipts = try await repository.fetchTrackCorrectionReceipts()
        let reversed = try XCTUnwrap(reversedReceipts.first)
        XCTAssertEqual(reversed.id, receipt.id)
        XCTAssertEqual(reversed.reversalState, .reversed(receiptID: receipt.id))
        XCTAssertEqual(reversed.previous, receipt.previous)
        XCTAssertEqual(reversed.corrected, receipt.corrected)
    }

    func testNormalizedEventCarriesCorrectionReceiptAndReversalMetadata() throws {
        let sourceID = UUID()
        let appliedAt = Date(timeIntervalSinceReferenceDate: 800_000_200)
        let previous = LifeBoardMoodEnergyCheckInValue(id: sourceID, mood: .tired, energy: 2, createdAt: appliedAt)
        let corrected = LifeBoardMoodEnergyCheckInValue(id: sourceID, mood: .happy, energy: 4, createdAt: appliedAt)
        var receipt = try TrackCorrectionReceipt.deterministic(
            previous: .mood(previous), corrected: .mood(corrected), appliedAt: appliedAt
        )
        let projector = NormalizedLifeEventProjector(timeZone: TimeZone(secondsFromGMT: 0)!)

        let appliedEvent = projector.event(
            sourceID: sourceID,
            domain: "mood",
            kind: corrected.mood.rawValue,
            occurredAt: appliedAt,
            sensitivity: .privateSensitive,
            provenance: "LifeBoard mood and energy check-in",
            evidenceDisplay: "Mood & energy check-in",
            receipt: receipt.reference,
            reversal: receipt.reversalState,
            now: appliedAt
        )
        XCTAssertEqual(appliedEvent.receipt, receipt.reference)
        XCTAssertEqual(appliedEvent.reversal, .reversible(receiptID: receipt.id))

        receipt.reversedAt = appliedAt.addingTimeInterval(5)
        let reversedEvent = projector.event(
            sourceID: sourceID,
            domain: "mood",
            kind: previous.mood.rawValue,
            occurredAt: appliedAt,
            sensitivity: .privateSensitive,
            provenance: "LifeBoard mood and energy check-in",
            evidenceDisplay: "Mood & energy check-in",
            receipt: receipt.reference,
            reversal: receipt.reversalState,
            now: appliedAt
        )
        XCTAssertEqual(reversedEvent.reversal, .reversed(receiptID: receipt.id))
    }

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    func testFocusLiveActivityContractStaysSmallAndCommandsAreIdempotent() throws {
        let sessionID = UUID()
        let commandID = UUID()
        let url = LifeBoardFocusActivityLink.url(sessionID: sessionID, command: "pause", token: commandID)
        let command = try XCTUnwrap(FocusLiveActivityDeepLink.command(from: url))

        XCTAssertEqual(command.id, commandID)
        XCTAssertEqual(command.sessionID, sessionID)
        if case .pause = command.kind {} else { XCTFail("Expected pause command") }

        let attributes = LifeBoardFocusActivityAttributes(sessionID: sessionID, title: String(repeating: "Long focus title ", count: 20))
        let state = LifeBoardFocusActivityAttributes.ContentState(
            phase: "running",
            remainingDuration: 1_500,
            expectedEndAt: Date().addingTimeInterval(1_500),
            updatedAt: Date()
        )
        let payloadSize = try JSONEncoder().encode(attributes).count + JSONEncoder().encode(state).count
        XCTAssertLessThan(payloadSize, 2_048)
        XCTAssertEqual(attributes.title.count, 80)
    }
    #endif

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

private final class HabitProjectionRepositoryStub: HabitRuntimeReadRepositoryProtocol, @unchecked Sendable {
    let rows: [HabitLibraryRow]
    let history: [HabitHistoryWindow]

    init(rows: [HabitLibraryRow], history: [HabitHistoryWindow]) {
        self.rows = rows
        self.history = history
    }

    func fetchAgendaHabits(for date: Date, completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], any Error>) -> Void) {
        completion(.success([]))
    }

    func fetchAgendaHabit(habitID: UUID, for date: Date, completion: @escaping @Sendable (Result<HabitOccurrenceSummary?, any Error>) -> Void) {
        completion(.success(nil))
    }

    func fetchHistory(habitIDs: [UUID], endingOn date: Date, dayCount: Int, completion: @escaping @Sendable (Result<[HabitHistoryWindow], any Error>) -> Void) {
        completion(.success(history.filter { habitIDs.contains($0.habitID) }))
    }

    func fetchSignals(start: Date, end: Date, completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], any Error>) -> Void) {
        completion(.success([]))
    }

    func fetchHabitLibrary(includeArchived: Bool, completion: @escaping @Sendable (Result<[HabitLibraryRow], any Error>) -> Void) {
        completion(.success(rows))
    }

    func fetchHabitLibrary(habitIDs: [UUID]?, includeArchived: Bool, completion: @escaping @Sendable (Result<[HabitLibraryRow], any Error>) -> Void) {
        let ids = habitIDs.map(Set.init)
        completion(.success(rows.filter { ids?.contains($0.habitID) ?? true }))
    }

    func fetchHabitDetailSummary(habitID: UUID, includeArchived: Bool, completion: @escaping @Sendable (Result<HabitLibraryRow?, any Error>) -> Void) {
        completion(.success(rows.first { $0.habitID == habitID }))
    }
}
