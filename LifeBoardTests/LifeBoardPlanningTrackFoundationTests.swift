@preconcurrency import CoreData
import XCTest
import Observation
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

    func testFitsNextPairsTasksWithEveryEligibleSpecificGap() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let shortID = UUID()
        let longID = UUID()
        let short = PlanningTaskSummary(
            id: shortID,
            title: "Short",
            estimatedDuration: 20 * 60,
            metadata: PlanningTaskMetadata(taskID: shortID),
            priority: .high
        )
        let long = PlanningTaskSummary(
            id: longID,
            title: "Long",
            estimatedDuration: 50 * 60,
            metadata: PlanningTaskMetadata(taskID: longID)
        )
        let first = FreeWindow(
            startAt: now.addingTimeInterval(10 * 60),
            endAt: now.addingTimeInterval(40 * 60)
        )
        let second = FreeWindow(
            startAt: now.addingTimeInterval(2 * 60 * 60),
            endAt: now.addingTimeInterval(3 * 60 * 60)
        )

        let candidates = FitsNextService.candidates(
            tasks: [long, short],
            windows: [second, first],
            now: now
        )

        XCTAssertEqual(candidates.map(\.taskID), [shortID, shortID, longID])
        XCTAssertEqual(candidates.map(\.window), [first, second, second])
        XCTAssertEqual(Set(candidates.map(\.id)).count, candidates.count)
    }

    func testMinimumViableDayNeverAppliesAPartialThreePartPlan() {
        let day = PlanningDay(
            year: 2026,
            month: 7,
            day: 29,
            timeZoneIdentifier: "Asia/Kolkata"
        )
        let empty = PlanDaySnapshot(
            day: day,
            capacity: CapacityBudget(
                workingDuration: 0,
                fixedCalendarDuration: 0,
                internalFixedDuration: 0,
                bufferDuration: 0,
                plannedEstimatedDuration: 0,
                missingEstimateCount: 0
            ),
            commitments: [],
            blocks: [],
            plannedTasks: [],
            unscheduledTasks: [],
            generatedAt: Date()
        )

        let incomplete = MinimumViableDayScenarioBuilder.make(from: empty)

        XCTAssertFalse(incomplete.isReadyToApply)
        XCTAssertEqual(incomplete.validationIssues.count, 3)
        XCTAssertTrue(incomplete.proposedMutations.isEmpty)

        let now = Date(timeIntervalSince1970: 2_000)
        let careID = UUID()
        let outcomeID = UUID()
        var completeSnapshot = empty
        completeSnapshot.unscheduledTasks = [
            PlanningTaskSummary(
                id: careID,
                title: "Drink water",
                estimatedDuration: 15 * 60,
                metadata: PlanningTaskMetadata(taskID: careID)
            ),
            PlanningTaskSummary(
                id: outcomeID,
                title: "Send the note",
                estimatedDuration: 20 * 60,
                metadata: PlanningTaskMetadata(taskID: outcomeID)
            )
        ]
        let rest = FreeWindow(
            startAt: now.addingTimeInterval(60),
            endAt: now.addingTimeInterval(31 * 60)
        )
        completeSnapshot.freeWindows = [rest]
        let complete = MinimumViableDayScenarioBuilder.make(
            from: completeSnapshot,
            selection: MinimumViableDaySelection(
                careTaskID: careID,
                outcomeTaskID: outcomeID,
                restWindowID: rest.id
            ),
            now: now
        )

        XCTAssertTrue(complete.isReadyToApply)
        XCTAssertEqual(complete.proposedMutations.count, 3)
    }

    func testScenarioRejectsStaleVersionsAndPreservesItsReceiptSource() async throws {
        let taskID = UUID()
        let current = PlanningTaskMetadata(
            taskID: taskID,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let repository = ScenarioPlanningRepository(metadata: [current])
        let snapshot = PlanDaySnapshot(
            day: PlanningDay(
                year: 2026,
                month: 7,
                day: 29,
                timeZoneIdentifier: "UTC"
            ),
            capacity: CapacityBudget(
                workingDuration: 0,
                fixedCalendarDuration: 0,
                internalFixedDuration: 0,
                bufferDuration: 0,
                plannedEstimatedDuration: 0,
                missingEstimateCount: 0
            ),
            commitments: [],
            blocks: [],
            plannedTasks: [],
            unscheduledTasks: [],
            generatedAt: Date()
        )
        let stale = PlanningScenario(
            source: .repair,
            receiptSource: "plan.repair.test",
            touchedRecords: [
                PlanningTouchedRecord(
                    kind: "task",
                    recordID: taskID,
                    version: Date(timeIntervalSince1970: 100)
                )
            ],
            proposedMutations: [.batch([])],
            diff: [PlanningScenarioDiff(title: "Repair")],
            preview: snapshot
        )
        let coordinator = DefaultPlanningScenarioCoordinator(
            planning: repository,
            mutations: repository
        )

        do {
            _ = try await coordinator.apply(stale)
            XCTFail("A stale scenario must not apply")
        } catch let error as PlanningScenarioApplyError {
            XCTAssertEqual(error, .versionConflict(changedRecordIDs: [taskID]))
        }
        let stalePreparedSource = await repository.preparedSource()
        XCTAssertNil(stalePreparedSource)

        var currentScenario = stale
        currentScenario.touchedRecords[0].version = current.updatedAt
        _ = try await coordinator.apply(currentScenario)

        let preparedSource = await repository.preparedSource()
        let didApply = await repository.didApply()
        XCTAssertEqual(preparedSource, "plan.repair.test")
        XCTAssertTrue(didApply)
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

    func testFocusStartupRepairPausesExpiredRunningSessionsForExplicitOutcome() {
        let now = Date(timeIntervalSince1970: 4_000)
        let expired = FocusSessionV2(targetDuration: 1_800, startedAt: now.addingTimeInterval(-1_801))
        XCTAssertEqual(FocusStartupRepairPolicy.commandKind(for: expired, now: now), .pause)

        var paused = expired
        paused.state = .paused
        XCTAssertNil(FocusStartupRepairPolicy.commandKind(for: paused, now: now))

        let active = FocusSessionV2(targetDuration: 1_800, startedAt: now.addingTimeInterval(-300))
        XCTAssertNil(FocusStartupRepairPolicy.commandKind(for: active, now: now))
    }

    func testFocusCompanionRestoresInterruptionsAndPurgesSevenDaysAfterCompletion() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusCompanionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FocusSessionCompanionStore(rootURL: root, retention: 7 * 24 * 60 * 60)
        let sessionID = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let companion = FocusSessionCompanion(
            sessionID: sessionID,
            mode: .pomodoro(focus: 1_500, breakDuration: 300, rounds: 4),
            intention: "Finish the draft",
            checkedSubtaskIDs: [UUID()],
            createdAt: now,
            updatedAt: now
        )

        try await store.save(companion, now: now)
        _ = try await store.recordInterruption(
            sessionID: sessionID,
            reason: "Unexpected call",
            at: now.addingTimeInterval(60)
        )
        let restored = try await store.companion(sessionID: sessionID, now: now.addingTimeInterval(120))
        XCTAssertEqual(restored?.intention, "Finish the draft")
        XCTAssertEqual(restored?.interruptions.first?.reason, "Unexpected call")

        try await store.markCompleted(sessionID: sessionID, at: now.addingTimeInterval(180))
        let retained = try await store.companion(
            sessionID: sessionID,
            now: now.addingTimeInterval(7 * 24 * 60 * 60 - 1)
        )
        XCTAssertNotNil(retained)
        let purged = try await store.companion(
            sessionID: sessionID,
            now: now.addingTimeInterval(7 * 24 * 60 * 60 + 181)
        )
        XCTAssertNil(purged)
    }

    func testCanonicalFocusCommandsRecoverPomodoroPublishOnceAndPersistReflection() async throws {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try modelBundleURL()
                    .appendingPathComponent("TaskModelV3_BehaviorFlagship.mom")
            )
        )
        let container = NSPersistentContainer(name: "CanonicalFocusCommands", managedObjectModel: model)
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.configuration = "CloudSync"
        cloud.url = URL(fileURLWithPath: "/dev/null/focus-cloud-\(UUID().uuidString)")
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.configuration = "LocalOnly"
        local.url = URL(fileURLWithPath: "/dev/null/focus-local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [cloud, local]
        try await load(container)

        let companionRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CanonicalFocusCommands-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: companionRoot) }
        let companionStore = FocusSessionCompanionStore(rootURL: companionRoot)
        let repository = CoreDataPlanningRepository(container: container)
        let events = FocusCompletionReceiptEventStream()
        let commands = FocusSessionCommands(
            repository: repository,
            companionStore: companionStore,
            completionEvents: events
        )
        let eventStream = await events.stream()
        let startedAt = Date(timeIntervalSinceReferenceDate: 800_100_000)
        let taskID = UUID()
        let recovery = try await commands.start(.init(
            taskID: taskID,
            mode: .pomodoro(focus: 1_500, breakDuration: 300, rounds: 2),
            intention: "Make the first pass",
            startedAt: startedAt
        ))
        XCTAssertEqual(recovery.session.taskID, taskID)
        XCTAssertEqual(recovery.companion?.pomodoroPhase?.kind, .focus)
        XCTAssertEqual(recovery.companion?.pomodoroPhase?.round, 1)

        let rest = try await commands.advancePomodoro(
            sessionID: recovery.session.id,
            at: startedAt.addingTimeInterval(1_500)
        )
        XCTAssertEqual(rest.pomodoroPhase?.kind, .rest)
        let relaunchedCommands = FocusSessionCommands(
            repository: repository,
            companionStore: companionStore,
            completionEvents: events
        )
        let relaunched = try await relaunchedCommands.activeRecovery()
        XCTAssertEqual(relaunched?.companion?.pomodoroPhase, rest.pomodoroPhase)

        _ = try await commands.pause(
            sessionID: recovery.session.id,
            interruptionReason: "Unexpected call",
            at: startedAt.addingTimeInterval(1_600)
        )
        _ = try await commands.resume(
            sessionID: recovery.session.id,
            at: startedAt.addingTimeInterval(1_660)
        )
        let endCommandID = UUID()
        let receipt = try await commands.end(
            sessionID: recovery.session.id,
            outcome: .continueLater,
            at: startedAt.addingTimeInterval(1_960),
            commandID: endCommandID
        )
        XCTAssertEqual(receipt.id, endCommandID)
        XCTAssertEqual(receipt.sessionID, recovery.session.id)
        XCTAssertEqual(receipt.outcome, .continueLater)
        XCTAssertEqual(receipt.interruptionCount, 1)

        var iterator = eventStream.makeAsyncIterator()
        let published = await iterator.next()
        XCTAssertEqual(published, receipt)

        let reflected = try await commands.saveReflection(
            sessionID: recovery.session.id,
            energyAfter: 4,
            note: "The interruption changed the stopping point."
        )
        XCTAssertEqual(reflected.energyAfter, 4)
        XCTAssertEqual(reflected.reflection, "The interruption changed the stopping point.")
        let persisted = try await repository.session(id: recovery.session.id)
        XCTAssertEqual(persisted?.energyAfter, 4)
        XCTAssertEqual(persisted?.reflection, "The interruption changed the stopping point.")
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

    /// Repair proposal IDs are persisted, so their derivation is a contract.
    ///
    /// `PlanStore` records an acknowledged repair as a receipt keyed on the
    /// proposal's id. If the `stableID` seed string or the hash ever changes,
    /// every repair every existing user already resolved comes back — silently,
    /// on upgrade, with no error anywhere.
    ///
    /// The expected values below were computed from an independent
    /// reimplementation of the algorithm rather than captured from a run, so
    /// this pins the derivation itself and not merely today's output.
    func testRepairProposalIDsAreUnchangedAfterPredicateExtraction() throws {
        let day = PlanningDay(year: 2026, month: 7, day: 14, timeZoneIdentifier: "Asia/Kolkata")
        let now = Date(timeIntervalSince1970: 2_000)
        let taskID = UUID()
        let blockID = try XCTUnwrap(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let block = InternalTimeBlock(
            id: blockID,
            title: "Past",
            startAt: Date(timeIntervalSince1970: 0),
            endAt: Date(timeIntervalSince1970: 1_000),
            taskID: taskID
        )
        let snapshot = PlanDaySnapshot(
            day: day,
            capacity: .init(
                workingDuration: 3_600, fixedCalendarDuration: 0, internalFixedDuration: 0,
                bufferDuration: 0, plannedEstimatedDuration: 7_200, missingEstimateCount: 0
            ),
            commitments: [],
            blocks: [block],
            plannedTasks: [PlanningTaskSummary(id: taskID, title: "Repair", metadata: .init(taskID: taskID))],
            unscheduledTasks: [],
            generatedAt: now
        )

        let proposals = DeterministicPlanRepairService().proposals(for: snapshot, now: now)

        let missed = try XCTUnwrap(proposals.first { $0.trigger == .missedPlannedWork })
        let overloaded = try XCTUnwrap(proposals.first { $0.trigger == .overloadedWindow })
        XCTAssertEqual(missed.id.uuidString, "616B6F77-6B0B-44DE-A1DE-E8F0EBECEAF5")
        XCTAssertEqual(overloaded.id.uuidString, "B0BC6775-7074-476B-823B-3A3D423A453C")

        // Order is part of the contract too: the deck shows `proposals.first`,
        // so a changed sort silently changes which card someone is asked about.
        XCTAssertEqual(
            proposals.map(\.id.uuidString),
            proposals.map(\.id.uuidString).sorted(),
            "Proposals must stay sorted by id"
        )
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
        XCTAssertNil(
            EstimateCalibrationService.suggestion(
                taskID: taskID,
                comparableDurations: [60, 600, 900]
            ),
            "A setup-length session must not count as calibration evidence"
        )
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
        let snapshot = DefaultHabitGradeService().evaluate(
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

        let snapshot = DefaultHabitGradeService().evaluate(
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
        XCTAssertTrue(decoded.vacationRanges.isEmpty)
        XCTAssertEqual(decoded.backfillPolicy, .disabled)
        XCTAssertNil(decoded.minimumTarget)
    }

    func testHabitTypedTargetsValidateAndPreserveLegacyColumns() throws {
        let valid = HabitTargetConfig(
            target: .quota(count: 5, period: .week),
            minimumTarget: .quota(count: 2, period: .week)
        )
        XCTAssertNil(HabitTargetValidator.validate(valid))
        XCTAssertEqual(
            HabitTargetValidator.validate(.init(
                target: .timed(seconds: 10 * 60),
                minimumTarget: .timed(seconds: 15 * 60)
            )),
            .minimumExceedsTarget
        )
        XCTAssertEqual(
            HabitTargetValidator.validate(.init(
                target: .quantitative(value: 8, unit: "pages"),
                minimumTarget: .quantitative(value: 2, unit: "minutes")
            )),
            .incompatibleMinimum
        )

        var record = HabitDefinitionRecord(title: "Read", habitType: "check_in")
        record.targetConfig = valid
        XCTAssertEqual(record.quotaTargetCount, 5)
        XCTAssertEqual(record.quotaPeriodRaw, HabitQuotaPeriod.week.rawValue)
        XCTAssertNotNil(record.minimumTargetData)
        XCTAssertEqual(record.targetConfig, valid)

        let decoded = try JSONDecoder().decode(
            HabitDefinitionRecord.self,
            from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.targetConfig, valid)

        let rules = HabitRuntimeSupport.buildScheduleRules(
            templateID: UUID(),
            cadence: .interval(days: 3, hour: 8, minute: 15),
            createdAt: Date()
        )
        XCTAssertEqual(rules.first?.ruleType, "daily")
        XCTAssertEqual(rules.first?.interval, 3)
        XCTAssertEqual(HabitRuntimeSupport.cadence(from: nil, rules: rules), .interval(days: 3, hour: 8, minute: 15))
    }

    func testHabitGradeDistinguishesMissingZeroFailurePausedAndVacation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14, hour: 12)))
        let habitID = UUID()
        func day(_ value: Int) -> PlanningDay {
            PlanningDay(year: 2026, month: 7, day: value, timeZoneIdentifier: calendar.timeZone.identifier)
        }
        let vacation = HabitVacationRange(startDay: day(11), endDay: day(11), label: "Rest")
        let snapshot = DefaultHabitGradeService().evaluate(
            habitID: habitID,
            occurrences: [
                .init(habitID: habitID, day: day(8), resolution: .completed),
                .init(habitID: habitID, day: day(9), resolution: .explicitZero, recordedValue: 0),
                .init(habitID: habitID, day: day(10), resolution: .failed, failureReason: "Sync unavailable"),
                .init(habitID: habitID, day: day(11), resolution: .missing),
                .init(habitID: habitID, day: day(12), resolution: .paused),
                .init(habitID: habitID, day: day(13), resolution: .abstained),
                .init(habitID: habitID, day: day(14), resolution: .manuallySkipped)
            ],
            policy: .init(habitID: habitID, vacationRanges: [vacation]),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.eligibleDueCount, 4)
        XCTAssertEqual(snapshot.completedEligibleCount, 2)
        XCTAssertEqual(snapshot.grade, 0.5)
        XCTAssertEqual(snapshot.distribution[.explicitZero], 1)
        XCTAssertEqual(snapshot.distribution[.paused], 1)
        XCTAssertEqual(snapshot.distribution[.missing], 1)
    }

    func testHabitAutoCompletionRequiresOneUnambiguousOccurrence() {
        let occurrenceID = UUID()
        let valid = HabitAutoCompletionMapping(
            source: .tracker,
            sourceID: UUID(),
            threshold: 8,
            candidateOccurrenceIDs: [occurrenceID]
        )
        XCTAssertEqual(valid.resolvedOccurrenceID, occurrenceID)
        XCTAssertNil(HabitAutoCompletionMapping(
            source: .healthKit,
            sourceID: UUID(),
            threshold: 8,
            candidateOccurrenceIDs: [occurrenceID, UUID()]
        ).resolvedOccurrenceID)
        XCTAssertNil(HabitAutoCompletionMapping(
            source: .tracker,
            sourceID: UUID(),
            threshold: 0,
            candidateOccurrenceIDs: [occurrenceID]
        ).resolvedOccurrenceID)
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

    func testRoutineValidatorRejectsBrokenBranchesLoopsAndUnreachableSteps() {
        let choiceID = UUID()
        let forwardID = UUID()
        let unreachableID = UUID()
        let missingID = UUID()
        let routine = RoutineDefinition(title: "Broken graph", steps: [
            .init(
                id: choiceID,
                title: "Choose",
                kind: .choice,
                ordinal: 0,
                choices: ["Forward", "Missing"],
                branches: [
                    .init(
                        sourceStepID: choiceID,
                        operation: .equals,
                        expectedResponse: "Forward",
                        destinationStepID: forwardID
                    ),
                    .init(
                        sourceStepID: choiceID,
                        operation: .equals,
                        expectedResponse: "Missing",
                        destinationStepID: missingID
                    )
                ]
            ),
            .init(
                id: unreachableID,
                title: "Never selected",
                kind: .instruction,
                ordinal: 1
            ),
            .init(
                id: forwardID,
                title: "Linked task",
                kind: .task,
                ordinal: 2,
                linkedMutation: .completeTask,
                branches: [
                    .init(
                        sourceStepID: forwardID,
                        operation: .equals,
                        expectedResponse: "Again",
                        destinationStepID: choiceID
                    )
                ]
            )
        ])

        let report = RoutineValidator().validate(routine)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains(.missingBranchDestination(
            sourceStepID: choiceID,
            destinationStepID: missingID
        )))
        XCTAssertTrue(report.issues.contains(.unreachableStep(unreachableID)))
        XCTAssertTrue(report.issues.contains(.missingLinkedEntity(stepID: forwardID)))
        XCTAssertTrue(report.issues.contains {
            if case .loop = $0 { true } else { false }
        })
    }

    func testRoutineTemplatesAreDistinctCompleteAndValid() throws {
        let templates = try RoutineTemplateKind.allCases
            .filter { $0 != .custom }
            .map { kind in
                (kind, try XCTUnwrap(RoutineTemplateCatalog.definition(for: kind)))
            }
        XCTAssertEqual(Set(templates.map { $0.1.title }).count, templates.count)
        for (_, routine) in templates {
            XCTAssertFalse(routine.steps.isEmpty)
            XCTAssertTrue(RoutineValidator().validate(routine).isValid)
            XCTAssertEqual(
                routine.steps.map(\.ordinal),
                Array(routine.steps.indices)
            )
        }
        XCTAssertNil(RoutineTemplateCatalog.definition(for: .custom))
    }

    func testRoutineCommandsPauseResumeSkipWithReasonAndDecodeLegacyState() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let routine = RoutineDefinition(title: "Care", steps: [
            .init(
                title: "Take a breath",
                kind: .timer,
                ordinal: 0,
                duration: 120,
                isRequired: false,
                isSkippable: true
            )
        ])
        let service = DefaultRoutineExecutionService()
        let running = service.begin(routine, at: startedAt)
        let paused = service.apply(
            command: .pause,
            to: running,
            at: startedAt.addingTimeInterval(10)
        )
        XCTAssertEqual(paused.run.status, .paused)
        XCTAssertEqual(paused.run.pausedAt, startedAt.addingTimeInterval(10))

        let resumed = service.apply(
            command: .resume,
            to: paused.run,
            at: startedAt.addingTimeInterval(40)
        )
        XCTAssertEqual(resumed.run.status, .running)
        XCTAssertNil(resumed.run.pausedAt)
        XCTAssertEqual(resumed.run.effectivePausedDuration, 30)
        XCTAssertEqual(resumed.run.effectiveCurrentStepPausedDuration, 30)

        let skipped = service.apply(
            command: .skip(reason: "Not needed today", idempotencyKey: "skip-1"),
            to: resumed.run,
            at: startedAt.addingTimeInterval(50)
        )
        XCTAssertEqual(skipped.run.status, .completed)
        XCTAssertEqual(skipped.run.events.first?.response, "Not needed today")
        XCTAssertEqual(skipped.run.events.first?.wasSkipped, true)
        let duplicate = service.apply(
            command: .skip(reason: "Not needed today", idempotencyKey: "skip-1"),
            to: skipped.run,
            at: startedAt.addingTimeInterval(51)
        )
        XCTAssertFalse(duplicate.didApplyEvent)
        XCTAssertEqual(duplicate.run.events.count, 1)

        var encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(running)) as? [String: Any]
        )
        encoded.removeValue(forKey: "pausedAt")
        encoded.removeValue(forKey: "accumulatedPausedDuration")
        encoded.removeValue(forKey: "currentStepPausedDuration")
        let legacyData = try JSONSerialization.data(withJSONObject: encoded)
        let decoded = try JSONDecoder().decode(RoutineRun.self, from: legacyData)
        XCTAssertNil(decoded.pausedAt)
        XCTAssertEqual(decoded.effectivePausedDuration, 0)
        XCTAssertEqual(decoded.effectiveCurrentStepPausedDuration, 0)
    }

    func testPausedRoutineRunRoundTripsForInterruptionRecovery() async throws {
        let container = try await makeTrackFoundationContainer()
        let repository = CoreDataTrackFoundationRepository(container: container)
        let routine = RoutineDefinition(title: "Shutdown", steps: [
            .init(title: "Close the loop", kind: .instruction, ordinal: 0)
        ])
        try await repository.saveRoutine(routine)
        let service = DefaultRoutineExecutionService()
        let running = service.begin(routine, at: Date(timeIntervalSince1970: 1_800_000_000))
        let paused = service.apply(
            command: .pause,
            to: running,
            at: running.startedAt.addingTimeInterval(30)
        ).run
        let resumed = service.apply(
            command: .resume,
            to: paused,
            at: running.startedAt.addingTimeInterval(75)
        ).run
        let rePaused = service.apply(
            command: .interrupt,
            to: resumed,
            at: running.startedAt.addingTimeInterval(90)
        ).run
        try await repository.saveRoutineRun(rePaused)

        let runs = try await repository.fetchRoutineRuns(routineID: routine.id)
        let restored = try XCTUnwrap(runs.first)
        XCTAssertEqual(restored.status, .interrupted)
        XCTAssertEqual(restored.currentStepID, running.currentStepID)
        XCTAssertEqual(restored.pausedAt, running.startedAt.addingTimeInterval(90))
        XCTAssertEqual(restored.effectivePausedDuration, 45)
        XCTAssertEqual(restored.effectiveCurrentStepPausedDuration, 45)
        XCTAssertEqual(restored.versionSnapshot, routine)
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

    func testGoalAssessmentRequiresValidQuantitativeMeaningAndEnoughRiskEvidence() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let directional = GoalDefinition(
            title: "Feel more present",
            type: .quantity,
            targetValue: 10,
            targetDate: now.addingTimeInterval(30 * 86_400),
            createdAt: now.addingTimeInterval(-10 * 86_400),
            intent: .directional,
            baselineValue: 2
        )
        let service = GoalAssessmentService()
        let noEvidence = service.assess(
            goal: directional,
            samples: [],
            missedCheckIns: 1,
            asOf: now
        )
        XCTAssertEqual(noEvidence.presentation, .checkIns)
        XCTAssertNil(noEvidence.progressFraction)
        XCTAssertFalse(noEvidence.isAtRisk)
        XCTAssertEqual(noEvidence.missingEvidence, [
            "No linked evidence yet",
            "1 scheduled check-in missing"
        ])

        let missed = service.assess(
            goal: directional,
            samples: [],
            missedCheckIns: 2,
            asOf: now
        )
        XCTAssertTrue(missed.isAtRisk)
        XCTAssertEqual(missed.riskReason, .missedCheckIns(count: 2))

        let quantitative = GoalDefinition(
            title: "Read 40 pages",
            type: .count,
            targetValue: 40,
            targetDate: now.addingTimeInterval(20 * 86_400),
            createdAt: now.addingTimeInterval(-20 * 86_400),
            intent: .cumulative,
            baselineValue: 0
        )
        let measurements = [0, 2, 4, 5].enumerated().map { offset, value in
            GoalProgressSample(
                linkID: UUID(),
                value: Double(value),
                isComplete: nil,
                measuredAt: now.addingTimeInterval(Double(offset - 3) * 3 * 86_400)
            )
        }
        let behind = service.assess(
            goal: quantitative,
            samples: measurements,
            missedCheckIns: 0,
            asOf: now
        )
        XCTAssertEqual(behind.presentation, .percentage)
        XCTAssertEqual(behind.progressFraction, 0.125)
        XCTAssertTrue(behind.isAtRisk)
        guard case let .behindTrajectory(observed, expected) = behind.riskReason else {
            return XCTFail("Expected an evidence-backed trajectory reason")
        }
        XCTAssertEqual(observed, 5)
        XCTAssertGreaterThan(expected, observed)
    }

    func testGoalLifecyclePersistsImmutableStatusHistoryAndUndoAppendsCompensation() async throws {
        let container = try await makeTrackFoundationContainer()
        let repository = CoreDataTrackFoundationRepository(container: container)
        let service = GoalLifecycleService(repository: repository)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let goal = try await service.save(
            draft: GoalDraft(
                title: "  Ship a calmer weekly review  ",
                type: .count,
                intent: .milestone,
                targetValue: 12,
                baselineValue: 2,
                unitLabel: "reviews",
                targetDate: createdAt.addingTimeInterval(90 * 86_400),
                confidence: .possible,
                whyItMatters: "  Make progress visible  ",
                checkInCadence: .biweekly
            ),
            at: createdAt
        )
        let pauseDate = createdAt.addingTimeInterval(86_400)
        let paused = try await service.transition(
            goal,
            to: .paused,
            reason: "  Protecting recovery time  ",
            at: pauseDate
        )
        let resumed = try await service.undo(
            paused,
            at: pauseDate.addingTimeInterval(3_600)
        )

        XCTAssertEqual(resumed.after.effectiveStatus, .active)
        XCTAssertEqual(resumed.after.statusEvents?.map(\.status), [.active, .paused, .active])
        XCTAssertNil(resumed.after.statusEvents?.first?.reason)
        XCTAssertEqual(resumed.after.statusEvents?[1].reason, "Protecting recovery time")
        XCTAssertEqual(
            resumed.after.statusEvents?.last?.reason,
            "Undid paused transition"
        )

        let goals = try await repository.fetchGoals()
        let restored = try XCTUnwrap(goals.first(where: { $0.id == goal.id }))
        XCTAssertEqual(restored.title, "Ship a calmer weekly review")
        XCTAssertEqual(restored.effectiveIntent, .milestone)
        XCTAssertEqual(restored.baselineValue, 2)
        XCTAssertEqual(restored.confidenceRaw, GoalConfidence.possible.rawValue)
        XCTAssertEqual(restored.whyItMatters, "Make progress visible")
        XCTAssertEqual(restored.checkInCadenceRaw, GoalCheckInCadence.biweekly.rawValue)
        XCTAssertEqual(restored.effectiveStatus, .active)
        XCTAssertEqual(restored.statusEvents?.map(\.id), resumed.after.statusEvents?.map(\.id))
        XCTAssertEqual(restored.statusEvents?.map(\.reason), resumed.after.statusEvents?.map(\.reason))
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
        // The future day is `.unresolved`, not `.missing`. The service used to
        // report `.due` here by falling through to the initializer default,
        // which is the "invented future due work" this test is named for. But
        // `.missing` would be wrong too: the scoring paths in
        // `TrackFoundationServices` treat `.missing` as a miss and `.unresolved`
        // as not counting, so `.missing` would score a day that has not
        // happened yet against the person.
        XCTAssertEqual(
            evidence[habitID]?.map(\.resolution),
            [.completed, .manuallySkipped, .unresolved]
        )
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
        // The shipping model, not `TaskModelV3_TrackFoundations`.
        //
        // Track writes pass through the health privacy gate, and
        // `HealthMigrationCheckpoint` only exists from `TaskModelV3_HealthPrivacy`
        // onward — an older model reached the gate's fetch for an entity it does
        // not define. Migration from the earlier versions stays covered by
        // `assertLightweightMigration`.
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: try modelBundleURL().appendingPathComponent("TaskModelV3_BehaviorFlagship.mom")))
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

        // The gate refuses writes until the private local copy is checkpointed.
        let localStore = try XCTUnwrap(
            container.persistentStoreCoordinator.persistentStores.first {
                $0.configurationName == "LocalOnly"
            }
        )
        let checkpointContext = container.newBackgroundContext()
        try await checkpointContext.perform {
            let checkpoint = NSEntityDescription.insertNewObject(
                forEntityName: "HealthMigrationCheckpoint",
                into: checkpointContext
            )
            checkpointContext.assign(checkpoint, to: localStore)
            checkpoint.setValue("overall", forKey: "id")
            checkpoint.setValue("validated", forKey: "phaseRaw")
            try checkpointContext.save()
        }

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
            ],
            vacationRanges: [
                HabitVacationRange(startDay: day, endDay: day, label: "Time away")
            ],
            backfillPolicy: .window(days: 7),
            minimumTarget: .timed(seconds: 300)
        )
        try await track.saveHabitResiliencePolicy(habitPolicy)
        habitPolicy.recoveryEnabled = false
        habitPolicy.streakPresentation = .countsOnly
        habitPolicy.updatedAt = Date()
        try await track.saveHabitResiliencePolicy(habitPolicy)
        var goal = GoalDefinition(
            title: "Ship",
            type: .completion,
            intent: .milestone,
            status: .active,
            baselineValue: 0,
            confidenceRaw: "medium",
            whyItMatters: "Make daily planning calmer",
            checkInCadenceRaw: "weekly"
        )
        try await track.saveGoal(goal)
        let goalLink = GoalLink(goalID: goal.id, source: .task, sourceID: taskID)
        try await track.saveGoalLink(goalLink)
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            let task = try XCTUnwrap(context.fetch(request).first)
            // This fixture context predates the repository's seven durable
            // updates. Refresh its snapshot before simulating another writer.
            context.refresh(task, mergeChanges: false)
            task.setValue(true, forKey: "isComplete")
            task.setValue(Date(), forKey: "updatedAt")
            try context.save()
        }
        let goalSamples = try await CoreDataGoalSampleRepository(container: container).samples(for: [goalLink], asOf: Date())
        XCTAssertEqual(goalSamples.first?.isComplete, true)
        goal.title = "Ship LifeBoard"
        goal.status = .paused
        goal.pausedAt = Date()
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
        XCTAssertEqual(fetchedGoals.first?.intent, .milestone)
        XCTAssertEqual(fetchedGoals.first?.status, .paused)
        XCTAssertEqual(fetchedGoals.first?.whyItMatters, "Make daily planning calmer")
        XCTAssertEqual(fetchedGoals.first?.statusEvents?.map(\.status), [.active, .paused])
        XCTAssertEqual(
            fetchedGoals.first?.statusEvents?.sorted {
                ($0.recordedAt, $0.id.uuidString) < ($1.recordedAt, $1.id.uuidString)
            }.map(\.id),
            fetchedGoals.first?.statusEvents?.map(\.id),
            "Status history must use deterministic date-and-ID ordering"
        )
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

    func testPlanningProjectionCoalescesDuplicateProjectIDsWithoutCrashing() async throws {
        let container = try await makeTrackFoundationContainer()
        let projectID = ProjectConstants.inboxProjectID
        let taskID = UUID()
        let context = container.newBackgroundContext()

        try await context.perform {
            for (name, mode) in [("Inbox", "parallel"), ("Inbox duplicate", "sequential")] {
                let project = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
                project.setValue(projectID, forKey: "id")
                project.setValue(name, forKey: "name")
                project.setValue(mode, forKey: "executionModeRaw")
            }

            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(taskID, forKey: "id")
            task.setValue("Survive the merge window", forKey: "title")
            task.setValue(projectID, forKey: "projectID")
            task.setValue(false, forKey: "isComplete")
            try context.save()
        }

        let tasks = try await CoreDataPlanningRepository(container: container).fetchOpenPlanningTasks()

        XCTAssertEqual(tasks.map(\.id), [taskID])
        XCTAssertEqual(tasks.first?.projectExecutionMode, .sequential)
        XCTAssertTrue(tasks.first?.dependenciesReady == true)
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
        let previous = TrackerEntryValue(
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
        let previous = MoodEnergyCheckInValue(id: sourceID, mood: .tired, energy: 2, createdAt: appliedAt)
        let corrected = MoodEnergyCheckInValue(id: sourceID, mood: .happy, energy: 4, createdAt: appliedAt)
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
        let url = FocusActivityLink.url(sessionID: sessionID, command: "pause", token: commandID)
        let command = try XCTUnwrap(FocusLiveActivityDeepLink.command(from: url))

        XCTAssertEqual(command.id, commandID)
        XCTAssertEqual(command.sessionID, sessionID)
        if case .pause = command.kind {} else { XCTFail("Expected pause command") }

        let attributes = FocusActivityAttributes(sessionID: sessionID, title: String(repeating: "Long focus title ", count: 20))
        let state = FocusActivityAttributes.ContentState(
            phase: "running",
            remainingDuration: 1_500,
            expectedEndAt: Date().addingTimeInterval(1_500),
            updatedAt: Date()
        )
        let payloadSize = try JSONEncoder().encode(attributes).count + JSONEncoder().encode(state).count
        XCTAssertLessThan(payloadSize, 2_048)
        XCTAssertEqual(attributes.title.count, 80)
    }

    func testFastingLiveActivityContractUsesCanonicalSessionAndExplicitCommands() throws {
        let sessionID = UUID()
        let commandID = UUID()
        let finishURL = FastingActivityLink.url(
            sessionID: sessionID,
            command: "finish",
            token: commandID
        )
        let command = try XCTUnwrap(FastingLiveActivityDeepLink.command(from: finishURL))

        XCTAssertEqual(command.id, commandID)
        XCTAssertEqual(command.sessionID, sessionID)
        XCTAssertEqual(command.action, .finish)
        XCTAssertNil(FastingLiveActivityDeepLink.command(from: FastingActivityLink.url(
            sessionID: sessionID,
            command: "infer-finished",
            token: commandID
        )))

        let attributes = FastingActivityAttributes(
            sessionID: sessionID,
            title: String(repeating: "Personal fasting target ", count: 10)
        )
        let state = FastingActivityAttributes.ContentState(
            phase: "active",
            startedAt: Date(timeIntervalSince1970: 100),
            targetEndAt: Date(timeIntervalSince1970: 200),
            elapsedDuration: 50,
            updatedAt: Date(timeIntervalSince1970: 150)
        )
        let payloadSize = try JSONEncoder().encode(attributes).count
            + JSONEncoder().encode(state).count
        XCTAssertLessThan(payloadSize, 2_048)
        XCTAssertEqual(attributes.title.count, 80)
    }

    func testRoutineLiveActivityContractExposesOnlyIdempotentLifecycleCommands() throws {
        let runID = UUID()
        let routineID = UUID()
        let commandID = UUID()
        let pauseURL = RoutineActivityLink.url(
            runID: runID,
            command: "pause",
            token: commandID
        )
        let command = try XCTUnwrap(RoutineLiveActivityDeepLink.command(from: pauseURL))

        XCTAssertEqual(command.id, commandID)
        XCTAssertEqual(command.runID, runID)
        XCTAssertEqual(command.action, .pause)
        XCTAssertNil(RoutineLiveActivityDeepLink.command(from: RoutineActivityLink.url(
            runID: runID,
            command: "advance",
            token: commandID
        )))

        let attributes = RoutineActivityAttributes(
            runID: runID,
            routineID: routineID,
            title: String(repeating: "Morning care routine ", count: 10)
        )
        let state = RoutineActivityAttributes.ContentState(
            status: "running",
            stepTitle: String(repeating: "Prepare the next gentle step ", count: 10),
            completedStepCount: 2,
            totalStepCount: 5,
            updatedAt: Date()
        )
        let payloadSize = try JSONEncoder().encode(attributes).count
            + JSONEncoder().encode(state).count
        XCTAssertLessThan(payloadSize, 2_048)
        XCTAssertEqual(attributes.title.count, 80)
        XCTAssertEqual(state.stepTitle.count, 100)
    }
    #endif

    func testHomePublishesCoreTasksWhileOptionalCalendarIsSuspended() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let id = UUID()
        let now = Date()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Available before calendar", forKey: "title")
            task.setValue(now, forKey: "dueDate")
            try context.save()
        }
        let focus = try await planning.start(taskID: id, timeBlockID: nil,
            targetDuration: 1_800, at: now)
        let calendar = SuspendedPerformanceCalendarRepository()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, taskAgendaDate: now, calendarRepository: calendar)
        }
        let coreReady = expectation(description: "Core content publishes before calendar completes")
        await MainActor.run {
            withObservationTracking { _ = store.hasLoadedCore } onChange: { coreReady.fulfill() }
        }
        let load = _Concurrency.Task { await store.load() }
        await fulfillment(of: [coreReady], timeout: 5)
        let intermediate = await MainActor.run {
            (store.taskAgenda.tasks.map(\.id), store.planSnapshot, store.isLoading,
             store.hasLoadedCore, store.activeFocusSession?.id, store.heroSnapshot?.sourceID)
        }
        XCTAssertEqual(intermediate.0, [id])
        XCTAssertNil(intermediate.1, "Optional calendar is still suspended")
        XCTAssertTrue(intermediate.2, "Optional work remains in flight")
        XCTAssertTrue(intermediate.3, "Task controls must use core readiness")
        XCTAssertEqual(intermediate.4, focus.id)
        XCTAssertEqual(intermediate.5, focus.id, "Active focus controls remain available before calendar")
        await calendar.release()
        await load.value
        let finished = await MainActor.run { (store.planSnapshot != nil, store.isLoading) }
        XCTAssertTrue(finished.0)
        XCTAssertFalse(finished.1)
    }

    func testHomePublishesPlanWhileOptionalHealthMealReadIsSuspended() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let id = UUID()
        let now = Date()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Plan before health", forKey: "title")
            task.setValue(now, forKey: "dueDate")
            try context.save()
        }
        try await planning.saveTaskMetadata(.init(taskID: id,
            planningDay: PlanningDay(date: now, timeZone: .current)))
        let health = SuspendedPerformanceHealthReader()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, healthMetrics: health, taskAgendaDate: now,
                calendarRepository: FailingPerformanceCalendarRepository())
        }
        let planReady = expectation(description: "Plan publishes before the optional meal read completes")
        await MainActor.run {
            withObservationTracking { _ = store.planSnapshot } onChange: { planReady.fulfill() }
        }
        let load = _Concurrency.Task { await store.load() }
        await fulfillment(of: [planReady], timeout: 5)
        let intermediate = await MainActor.run {
            (store.planSnapshot?.plannedTasks.map(\.id), store.isLoading, store.focusTask?.id)
        }
        XCTAssertEqual(intermediate.0, [id])
        XCTAssertTrue(intermediate.1)
        XCTAssertEqual(intermediate.2, id)
        await health.release()
        await load.value
        let finished = await MainActor.run { store.isLoading }
        XCTAssertFalse(finished)
    }

    func testHydrationSubscriptionMergesCommittedBurstsAndFiltersOtherWrites() async throws {
        let container = try await makeTrackFoundationContainer()
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let subscription = track.sourceRevisions.subscribe(recordKinds: [.hydration])
        defer { subscription.cancel() }
        XCTAssertNotNil(subscription.takePending(), "Registration replays the current revision")
        try await phaseII.saveMoodCheckIn(.init(mood: .happy, energy: 4))
        XCTAssertNil(subscription.takePending(), "Unrelated tracking saves must not wake hydration")
        var ids: Set<UUID> = []
        for _ in 0..<12 {
            let log = HydrationLog(amount: 25, unit: .milliliters)
            ids.insert(log.id)
            try await track.saveHydrationLog(log)
        }
        let event = try XCTUnwrap(subscription.takePending())
        XCTAssertEqual(event.affectedIDs, ids)
        XCTAssertEqual(event.recordKinds, [.hydration])
        XCTAssertEqual(event.revisions, track.sourceRevisions.snapshot())
        XCTAssertNil(subscription.takePending(), "The burst occupies one merged slot")
        subscription.cancel()
        XCTAssertEqual(track.sourceRevisions.subscriptionCount, 0)
        try await track.saveHydrationLog(.init(amount: 25, unit: .milliliters))
        XCTAssertNil(subscription.takePending())
    }

    func testInvalidationMailboxBoundsIDsAndNeverRegressesRevisions() {
        let identity = NSObject()
        let mailbox = ProjectionInvalidationSubscription(recordKinds: [.hydration, .mood], onCancel: {})
        defer { mailbox.cancel() }
        var revisions = SourceRevisionVector()
        for _ in 0..<300 {
            revisions.advance([.tracking])
            mailbox.enqueue(.init(containerID: ObjectIdentifier(identity), domains: [.tracking],
                affectedIDs: [UUID()], revisions: revisions, transactionAuthor: nil, recordKinds: [.hydration]))
        }
        var old = SourceRevisionVector()
        old.advance([.wellness])
        mailbox.enqueue(.init(containerID: ObjectIdentifier(identity), domains: [.wellness],
            affectedIDs: [UUID()], revisions: old, transactionAuthor: nil, recordKinds: [.mood]))
        let event = mailbox.takePending()
        XCTAssertEqual(event?.revisions[.tracking], 300)
        XCTAssertEqual(event?.revisions[.wellness], 1)
        XCTAssertEqual(event?.domains, [.tracking, .wellness])
        XCTAssertEqual(event?.recordKinds, [.hydration, .mood])
        XCTAssertEqual(event?.requiresFullDomainRefresh, true)
        XCTAssertEqual(event?.affectedIDs.count, 0)
    }

    func testHomeObservesSharedHydrationSaveWhileCalendarAndHealthAreSuspended() async throws {
        let container = try await makeTrackFoundationContainer()
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let calendar = SuspendedPerformanceCalendarRepository()
        let health = SuspendedPerformanceHealthReader()
        let samples = SuspendedPerformanceGoalSamples()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: CoreDataPlanningRepository(container: container),
                trackRepository: track, phaseIIRepository: phaseII, goalSampleProvider: samples, healthMetrics: health,
                calendarRepository: calendar)
        }
        let initial = expectation(description: "Initial hydration catch-up")
        await MainActor.run {
            withObservationTracking { _ = store.trackSnapshot } onChange: { initial.fulfill() }
        }
        let observer = _Concurrency.Task { await store.observeCommittedHydrationChanges() }
        await fulfillment(of: [initial], timeout: 5)
        let load = _Concurrency.Task { await store.load() }
        await samples.waitUntilEntered()
        let refreshed = expectation(description: "Shared water save publishes without optional providers")
        await MainActor.run {
            withObservationTracking { _ = store.trackSnapshot } onChange: { refreshed.fulfill() }
        }
        // Same repository command used by HealthWaterLogSheet; Home does not
        // own this save and its mutationRevision does not change.
        try await track.saveHydrationLog(.init(amount: 375, unit: .milliliters))
        await fulfillment(of: [refreshed], timeout: 5)
        let visible = await MainActor.run { (store.trackSnapshot?.hydrationAmountMilliliters, store.mutationRevision) }
        XCTAssertEqual(visible.0, 375)
        XCTAssertEqual(visible.1, 0)
        observer.cancel()
        await observer.value
        XCTAssertEqual(track.sourceRevisions.subscriptionCount, 0)
        let readCount = await MainActor.run { store.hydrationReadCount }
        try await track.saveHydrationLog(.init(amount: 125, unit: .milliliters))
        let hiddenReads = await MainActor.run { store.hydrationReadCount }
        XCTAssertEqual(hiddenReads, readCount)
        let caughtUp = expectation(description: "Foreground catches up missed saves")
        await MainActor.run {
            withObservationTracking { _ = store.trackSnapshot } onChange: { caughtUp.fulfill() }
        }
        let resumed = _Concurrency.Task { await store.observeCommittedHydrationChanges() }
        await fulfillment(of: [caughtUp], timeout: 5)
        let current = await MainActor.run { store.trackSnapshot?.hydrationAmountMilliliters }
        XCTAssertEqual(current, 500)
        resumed.cancel()
        await resumed.value
        await samples.release()
        await calendar.release()
        await health.release()
        await load.value
    }

    func testHomeSaveFinishingAfterDeactivationDefersProjectionUntilActivation() async throws {
        let container = try await makeTrackFoundationContainer()
        let base = CoreDataLifeBoardPhaseIIRepository(container: container)
        let committed = expectation(description: "Durable save finished but callback is suspended")
        let saveGate = PerformanceMoodReadGate(onEnter: { committed.fulfill() })
        let readGate = PerformanceMoodReadGate(onEnter: {})
        await readGate.release()
        let repository = PerformanceUnversionedMoodRepository(base: base, gate: readGate, saveGate: saveGate)
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: repository)
        }
        let save = _Concurrency.Task { await store.saveMood(.happy, energy: 4) }
        await fulfillment(of: [committed], timeout: 5)
        await store.stopCommittedProjectionWork()
        await saveGate.release()
        let result = await save.value
        XCTAssertEqual(result, .cancelled)
        let hidden = await MainActor.run { store.latestMood }
        XCTAssertNil(hidden, "A late durable callback must not start hidden presentation work")
        let saved = try await base.fetchMoodCheckIns(from: nil, to: nil)
        XCTAssertEqual(saved.count, 1)
        await store.beginCommittedProjectionWork()
        let refreshed = await store.refreshCommittedMood()
        guard case .applied = refreshed else { return XCTFail("Activation must be able to catch up") }
        let current = await MainActor.run { store.latestMood }
        XCTAssertEqual(current?.mood, .happy)
    }

    func testHomeDeactivationRejectsLateMoodPublication() async throws {
        let container = try await makeTrackFoundationContainer()
        let base = CoreDataLifeBoardPhaseIIRepository(container: container)
        let entered = expectation(description: "Mood read suspended")
        let gate = PerformanceMoodReadGate(onEnter: { entered.fulfill() })
        let repository = PerformanceUnversionedMoodRepository(base: base, gate: gate)
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: repository)
        }
        let save = _Concurrency.Task { await store.saveMood(.tired, energy: 2) }
        await fulfillment(of: [entered], timeout: 5)
        await store.stopCommittedProjectionWork()
        let result = await save.value
        XCTAssertEqual(result, .cancelled)
        await store.beginCommittedProjectionWork()
        let newer = await store.saveMood(.happy, energy: 4)
        guard case .applied = newer else { await gate.release(); return XCTFail("New presentation must publish") }
        await gate.release()
        let latest = await MainActor.run { store.latestMood }
        XCTAssertEqual(latest?.mood, .happy)
        let saved = try await base.fetchMoodCheckIns(from: nil, to: nil)
        XCTAssertEqual(saved.count, 2, "Presentation cancellation must not undo durable saves")
    }

    func testHomeHydrationAndMoodMutationsPublishBeforeOptionalProviders() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        try await track.saveHydrationTarget(.init(id: UUID(), amount: 2_000, unit: .milliliters, updatedAt: Date()))
        let calendar = SuspendedPerformanceCalendarRepository()
        let health = SuspendedPerformanceHealthReader()
        let samples = SuspendedPerformanceGoalSamples()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: track,
                phaseIIRepository: phaseII, goalSampleProvider: samples, healthMetrics: health,
                calendarRepository: calendar)
        }
        let load = _Concurrency.Task { await store.load() }
        await samples.waitUntilEntered()
        let completed = expectation(description: "Narrow mutations finish without optional providers")
        let mutations = _Concurrency.Task {
            let hydration = await store.quickAddHydration(250)
            let mood = await store.saveMood(.happy, energy: 4)
            completed.fulfill()
            return (hydration, mood)
        }
        await fulfillment(of: [completed], timeout: 5)
        let visible = await MainActor.run {
            (store.trackSnapshot, store.latestMood, store.planSnapshot)
        }
        XCTAssertEqual(visible.0?.hydrationAmountMilliliters, 250)
        XCTAssertEqual(visible.0?.hydrationTargetMilliliters, 2_000)
        XCTAssertEqual(visible.0?.completeness, .partial)
        XCTAssertEqual(visible.1?.mood, .happy)
        XCTAssertEqual(visible.1?.energy, 4)
        XCTAssertNil(visible.2)
        await samples.release()
        await calendar.release()
        await health.release()
        await load.value
        let outcomes = await mutations.value
        guard case .applied = outcomes.0, case .applied = outcomes.1 else {
            return XCTFail("Saved values must publish before mutation completion")
        }
        let afterStaleRead = await MainActor.run { (store.trackSnapshot, store.latestMood) }
        XCTAssertEqual(afterStaleRead.0?.hydrationAmountMilliliters, 250)
        XCTAssertEqual(afterStaleRead.1?.mood, .happy)
        await store.load()
        let commits = await MainActor.run { store.loadCommitCount }
        _ = await store.refreshCommittedHydration()
        _ = await store.refreshCommittedMood()
        let noOpCommits = await MainActor.run { store.loadCommitCount }
        XCTAssertEqual(noOpCommits, commits, "Narrow no-op reads must not commit presentation")
    }

    func testHomeTrackRejectsReadBeforeExternalHydrationCommit() async throws {
        let container = try await makeTrackFoundationContainer()
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let samples = SuspendedPerformanceGoalSamples()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: track,
                phaseIIRepository: phaseII, goalSampleProvider: samples)
        }
        let load = _Concurrency.Task { await store.load() }
        await samples.waitUntilEntered()
        // This save bypasses Home's mutation counter. Publication must check
        // the committed source dependency, not only the screen generation.
        try await track.saveHydrationLog(.init(amount: 500, unit: .milliliters))
        await samples.release()
        await load.value
        let rejected = await MainActor.run { store.trackSnapshot }
        XCTAssertNil(rejected)
        await store.load()
        let refreshed = await MainActor.run { store.trackSnapshot?.hydrationAmountMilliliters }
        XCTAssertEqual(refreshed, 500)
    }

    func testHomeMoodMutationPublishesWithoutTrackRepository() async throws {
        let container = try await makeTrackFoundationContainer()
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: phaseII)
        }
        let outcome = await store.saveMood(.tired, energy: 2)
        guard case .applied(let revision) = outcome else { return XCTFail("Mood projection must be independent of Track") }
        XCTAssertTrue(revision.represents(phaseII.sourceRevisions.snapshot(), domains: [.wellness]))
        let value = await MainActor.run { store.latestMood }
        XCTAssertEqual(value?.mood, .tired)
        XCTAssertEqual(value?.energy, 2)
    }

    func testHomeProtocolMoodProviderRejectsOlderReadDuringSecondSave() async throws {
        let container = try await makeTrackFoundationContainer()
        let base = CoreDataLifeBoardPhaseIIRepository(container: container)
        let entered = expectation(description: "First mood snapshot suspended")
        let gate = PerformanceMoodReadGate(onEnter: { entered.fulfill() })
        let repository = PerformanceUnversionedMoodRepository(base: base, gate: gate)
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: repository)
        }
        let first = _Concurrency.Task { await store.saveMood(.tired, energy: 2) }
        await fulfillment(of: [entered], timeout: 5)
        let saved = expectation(description: "Second durable mood save returned to Home")
        await MainActor.run {
            withObservationTracking { _ = store.mutationRevision } onChange: { saved.fulfill() }
        }
        let second = _Concurrency.Task { await store.saveMood(.happy, energy: 4) }
        await fulfillment(of: [saved], timeout: 5)
        await gate.release()
        let outcomes = await (first.value, second.value)
        guard case .applied(let firstRevision) = outcomes.0,
              case .applied(let secondRevision) = outcomes.1 else {
            return XCTFail("Both committed mood saves must reach a current projection")
        }
        XCTAssertEqual(firstRevision[.wellness], 2)
        XCTAssertEqual(secondRevision[.wellness], 2)
        let value = await MainActor.run { store.latestMood }
        XCTAssertEqual(value?.mood, .happy)
        XCTAssertEqual(value?.energy, 4)
    }

    func testHomeConcurrentHydrationSavesPreserveCommittedTotals() async throws {
        let container = try await makeTrackFoundationContainer()
        let track = CoreDataTrackFoundationRepository(container: container)
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: track, phaseIIRepository: nil)
        }
        async let first = store.quickAddHydration(250)
        async let second = store.quickAddHydration(500)
        let outcomes = await (first, second)
        guard case .applied = outcomes.0, case .applied = outcomes.1 else {
            return XCTFail("Concurrent hydration callers must receive their projected commits")
        }
        let amount = await MainActor.run { store.trackSnapshot?.hydrationAmountMilliliters }
        XCTAssertEqual(amount, 750)
    }

    func testHomeTrackAndFastPublishBeforeSuspendedCalendarAndHealth() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        try await track.saveHydrationLog(.init(amount: 250, unit: .milliliters))
        let fast = FastingSessionValue(startedAt: Date().addingTimeInterval(-600), targetDuration: 3_600)
        try await phaseII.saveFastingSession(fast)
        let calendar = SuspendedPerformanceCalendarRepository()
        let health = SuspendedPerformanceHealthReader()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: track,
                phaseIIRepository: phaseII, healthMetrics: health, calendarRepository: calendar)
        }
        let trackReady = expectation(description: "Track does not wait for Plan or health")
        let fastReady = expectation(description: "Fast does not wait for Plan or health")
        await MainActor.run {
            withObservationTracking { _ = store.trackSnapshot } onChange: { trackReady.fulfill() }
            withObservationTracking { _ = store.activeFast } onChange: { fastReady.fulfill() }
        }
        let load = _Concurrency.Task { await store.load() }
        await fulfillment(of: [trackReady, fastReady], timeout: 5)
        let intermediate = await MainActor.run {
            (store.trackSnapshot?.hydrationAmountMilliliters, store.activeFast?.id,
             store.planSnapshot, store.isLoading)
        }
        XCTAssertEqual(intermediate.0, 250)
        XCTAssertEqual(intermediate.1, fast.id)
        XCTAssertNil(intermediate.2)
        XCTAssertTrue(intermediate.3)
        await calendar.release()
        await health.release()
        await load.value
        let commits = await MainActor.run { store.loadCommitCount }
        await store.load()
        let refreshed = await MainActor.run { store.loadCommitCount }
        XCTAssertEqual(refreshed, commits, "Unchanged populated domain callbacks must not add presentation commits")
    }

    func testHomeRejectsOptionalPublicationAfterSelectionChanges() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let calendar = SuspendedPerformanceCalendarRepository()
        let (store, selection) = await MainActor.run {
            (HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, calendarRepository: calendar), PerformanceHomeSelection())
        }
        let coreReady = expectation(description: "Core read reached the current selection")
        await MainActor.run {
            withObservationTracking { _ = store.hasLoadedCore } onChange: { coreReady.fulfill() }
        }
        let load = _Concurrency.Task { await store.load(isCurrent: { selection.isCurrent }) }
        await fulfillment(of: [coreReady], timeout: 5)
        await MainActor.run { selection.isCurrent = false }
        await calendar.release()
        await load.value
        let rejected = await MainActor.run { store.planSnapshot }
        XCTAssertNil(rejected, "A calendar completion from the previous selection must not publish")
        await MainActor.run { selection.isCurrent = true }
        await store.load(isCurrent: { selection.isCurrent })
        let reactivated = await MainActor.run { store.planSnapshot }
        XCTAssertNotNil(reactivated, "Reactivation can publish a new current read")

        let rejectedStore = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, calendarRepository: calendar)
        }
        await rejectedStore.load(isCurrent: { false })
        let invalid = await MainActor.run { (rejectedStore.hasLoadedCore, rejectedStore.planSnapshot) }
        XCTAssertFalse(invalid.0, "The early core callback uses the same selection barrier")
        XCTAssertNil(invalid.1)
    }

    func testPopulatedHomeRefreshDoesNotCommitUnchangedTaskProjection() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        try await planning.saveWorkingHoursProfile(PlanStore.defaultWorkingProfile())
        let id = UUID()
        let context = container.newBackgroundContext()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Stable Home task", forKey: "title")
            try context.save()
        }
        try await planning.saveTaskMetadata(.init(taskID: id,
            planningDay: PlanningDay(date: Date(), timeZone: .current)))
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil, phaseIIRepository: nil)
        }
        await store.load()
        let initial = await MainActor.run { (store.planSnapshot, store.loadCommitCount) }
        XCTAssertEqual(initial.0?.plannedTasks.map(\.id), [id])
        let commits = initial.1
        await store.load()
        let refreshed = await MainActor.run { (store.planSnapshot, store.loadCommitCount) }
        XCTAssertEqual(refreshed.1, commits)
        XCTAssertEqual(refreshed.0?.plannedTasks.first?.title, "Stable Home task")
        let reader = HomeProjectionReader(planning: planning, track: nil, phaseII: nil,
            goalSamples: nil, calendarRepository: FailingPerformanceCalendarRepository())
        let withoutCalendar = await reader.read(now: Date())
        XCTAssertEqual(withoutCalendar.plan?.plannedTasks.map(\.id), [id],
            "An optional calendar failure must not discard canonical tasks")
        guard case .failed = withoutCalendar.plan?.calendarState else {
            return XCTFail("Calendar failure must remain visible in the projection")
        }
    }

    func testHomeCardCompletionPublishesIndependentlyAndCannotUndoPrivacyRevocation() async throws {
        let gate = PerformanceCardGate()
        let registry = try HomeCardProviderRegistry(providers: [
            PerformanceCardSource(kind: .tasks, gate: nil),
            PerformanceCardSource(kind: .journal, gate: gate)
        ])
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: nil, trackRepository: nil, phaseIIRepository: nil)
        }
        let firstCard = expectation(description: "Fast card publishes while journal is suspended")
        await MainActor.run {
            withObservationTracking { _ = store.cardSnapshots } onChange: { firstCard.fulfill() }
        }
        let refresh = _Concurrency.Task {
            await store.refreshCardSnapshots(requests: [(.tasks, .standard), (.journal, .standard)],
                permitsSensitive: true, providerRegistry: registry)
        }
        await fulfillment(of: [firstCard], timeout: 5)
        let partial = await MainActor.run { store.cardSnapshots.values.map(\.title) }
        XCTAssertEqual(partial, ["tasks"])
        await MainActor.run { store.invalidateCardPrivacy() }
        await gate.release()
        await refresh.value
        let revoked = await MainActor.run { (store.cardSnapshots.isEmpty, store.cardResolutions.isEmpty) }
        XCTAssertTrue(revoked.0)
        XCTAssertTrue(revoked.1, "Old authorized providers must not repopulate cleared navigation metadata")
        await store.refreshCardSnapshots(requests: [(.tasks, .standard), (.journal, .standard)],
            permitsSensitive: false, providerRegistry: registry)
        let current = await MainActor.run { Array(store.cardSnapshots.values) }
        XCTAssertEqual(current.first { $0.title == "journal" }?.availability, .redacted)
        XCTAssertEqual(current.first { $0.title == "tasks" }?.availability, .ready)
    }

    func testHomeMutationRemovesCompletedTaskFromStalePlanRecommendations() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let context = container.newBackgroundContext()
        let id = UUID()
        let now = Date()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Current must-do", forKey: "title")
            task.setValue(now, forKey: "dueDate")
            try context.save()
        }
        try await planning.saveTaskMetadata(.init(taskID: id,
            planningDay: PlanningDay(date: now, timeZone: .current), commitmentLevel: .mustDo))
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, calendarRepository: FailingPerformanceCalendarRepository())
        }
        await store.load()
        let initial = await MainActor.run { (store.taskAgenda.tasks.first, store.heroSnapshot?.sourceID) }
        XCTAssertEqual(initial.1, id)
        let task = try XCTUnwrap(initial.0)
        let saved = await store.setTaskCompletion(task, to: true)
        XCTAssertTrue(saved)
        let completed = await MainActor.run {
            (store.planSnapshot?.plannedTasks.map(\.id), store.focusTask?.id, store.heroSnapshot?.sourceID)
        }
        XCTAssertEqual(completed.0, [id], "Full optional Plan refresh has not run yet")
        XCTAssertNil(completed.1)
        XCTAssertNotEqual(completed.2, id, "Home must not recommend a task its core projection knows is complete")
        await store.undoLastTaskCompletion()
        let restored = await MainActor.run { store.heroSnapshot?.sourceID }
        XCTAssertEqual(restored, id)
    }

    func testHomeTaskMutationWaitsForAgendaWithoutWaitingForCalendar() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let context = container.newBackgroundContext()
        let id = UUID()
        let now = Date()
        try await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Complete while calendar is suspended", forKey: "title")
            task.setValue(now, forKey: "dueDate")
            try context.save()
        }
        let calendar = SuspendedPerformanceCalendarRepository()
        let store = await MainActor.run {
            HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                phaseIIRepository: nil, taskAgendaDate: now, calendarRepository: calendar)
        }
        let ready = expectation(description: "Initial task agenda")
        await MainActor.run {
            withObservationTracking { _ = store.hasLoadedCore } onChange: { ready.fulfill() }
        }
        let load = _Concurrency.Task { await store.load() }
        await fulfillment(of: [ready], timeout: 5)
        let task = await MainActor.run { store.taskAgenda.tasks.first }
        let value = try XCTUnwrap(task)
        let completed = expectation(description: "Mutation returns before optional calendar")
        let mutation = _Concurrency.Task {
            let saved = await store.setTaskCompletion(value, to: true)
            completed.fulfill()
            return saved
        }
        await fulfillment(of: [completed], timeout: 5)
        let visible = await MainActor.run { (store.taskAgenda.tasks.isEmpty, store.lastTaskMutationRefreshOutcome) }
        XCTAssertTrue(visible.0)
        guard case .applied = visible.1 else {
            await calendar.release()
            await load.value
            return XCTFail("Mutation must report its projected commit")
        }
        await store.undoLastTaskCompletion()
        let restored = await MainActor.run { store.taskAgenda.tasks.map(\.id) }
        XCTAssertEqual(restored, [id])
        await calendar.release()
        await load.value
        let saved = await mutation.value
        XCTAssertTrue(saved)
    }

    func testHomePlanPublicationChecksOnlyRelevantCommittedDomains() async throws {
        let container = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let track = CoreDataTrackFoundationRepository(container: container)
        for changesTasks in [false, true] {
            let calendar = SuspendedPerformanceCalendarRepository()
            let store = await MainActor.run {
                HomeLifeOSProjectionStore(planningRepository: planning, trackRepository: nil,
                    phaseIIRepository: nil, calendarRepository: calendar)
            }
            let coreReady = expectation(description: "Core read before external mutation")
            await MainActor.run {
                withObservationTracking { _ = store.hasLoadedCore } onChange: { coreReady.fulfill() }
            }
            let load = _Concurrency.Task { await store.load() }
            await fulfillment(of: [coreReady], timeout: 5)
            if changesTasks {
                let context = container.newBackgroundContext()
                try await context.perform {
                    let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
                    task.setValue(UUID(), forKey: "id")
                    task.setValue("External task during calendar read", forKey: "title")
                    try context.save()
                }
            } else {
                try await track.saveHydrationLog(.init(amount: 100, unit: .milliliters))
            }
            await calendar.release()
            await load.value
            let hasPlan = await MainActor.run { store.planSnapshot != nil }
            XCTAssertEqual(hasPlan, !changesTasks,
                "Hydration must not invalidate Plan; an external task save must reject the older Plan")
            if changesTasks {
                await store.load()
                let refreshed = await MainActor.run { store.planSnapshot != nil }
                XCTAssertTrue(refreshed)
            }
        }
    }

    func testProjectionRevisionLedgerDoesNotLoseConcurrentCommits() async throws {
        let container = try await makeTrackFoundationContainer()
        let track = CoreDataTrackFoundationRepository(container: container)
        let before = track.sourceRevisions.snapshot()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { try await track.saveHydrationLog(.init(amount: 100, unit: .milliliters)) }
            }
            try await group.waitForAll()
        }
        let after = track.sourceRevisions.snapshot()
        XCTAssertEqual(after[.tracking], before[.tracking] + 20)
        XCTAssertTrue(after.matches(before, domains: [.tasks, .planning, .focus, .fasting]))
    }

    func testProjectionRevisionsAdvanceBeforeSaveReturnsAndAreContainerScoped() async throws {
        let container = try await makeTrackFoundationContainer()
        let other = try await makeTrackFoundationContainer()
        let planning = CoreDataPlanningRepository(container: container)
        let track = CoreDataTrackFoundationRepository(container: container)
        let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
        let isolated = CoreDataPlanningRepository(container: other)
        XCTAssertTrue(planning.sourceRevisions === track.sourceRevisions)
        XCTAssertTrue(track.sourceRevisions === phaseII.sourceRevisions)
        let before = planning.sourceRevisions.snapshot()
        let context = container.newBackgroundContext()
        let id = UUID()
        let committed = try await context.perform {
            context.transactionAuthor = "performance.revision-test"
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(id, forKey: "id")
            task.setValue("Committed before callback", forKey: "title")
            try context.save()
            return planning.sourceRevisions.snapshot()
        }
        XCTAssertEqual(committed[.tasks], before[.tasks] + 1)
        XCTAssertEqual(committed[.planning], before[.planning] + 1)
        XCTAssertTrue(committed.matches(before, domains: [.tracking, .fasting, .journal]))
        XCTAssertEqual(isolated.sourceRevisions.snapshot()[.tasks], 0)
        let event = try XCTUnwrap(planning.sourceRevisions.latestInvalidation())
        XCTAssertEqual(event.affectedIDs, [id])
        XCTAssertEqual(event.transactionAuthor, "performance.revision-test")
        XCTAssertEqual(event.revisions, committed)
        try await track.saveHydrationLog(.init(amount: 200, unit: .milliliters))
        let afterHydration = planning.sourceRevisions.snapshot()
        XCTAssertTrue(afterHydration.matches(committed, domains: [.tasks, .planning, .focus]))
        XCTAssertEqual(afterHydration[.tracking], committed[.tracking] + 1)
        XCTAssertTrue(afterHydration.represents(committed, domains: Set(ProjectionDomain.allCases)))
        await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            task.setValue(UUID(), forKey: "id")
            context.rollback()
        }
        XCTAssertEqual(planning.sourceRevisions.snapshot(), afterHydration, "Rolled-back work must not advance durable revisions")
    }

    func testMaintenanceRegistrySharesLiveOwnersAndReleasesUnusedContainers() async throws {
        let container = try await makeTrackFoundationContainer()
        let otherContainer = try await makeTrackFoundationContainer()
        await MainActor.run {
            let root = CompositionRoot.shared
            let planning = CoreDataPlanningRepository(container: container)
            let track = CoreDataTrackFoundationRepository(container: container)
            let phaseII = CoreDataLifeBoardPhaseIIRepository(container: container)
            var first: FoundationDomainMaintenance? = root.domainMaintenance(container: container,
                planning: planning, track: track, phaseII: phaseII, focusCommands: nil)
            weak var released = first
            var second: FoundationDomainMaintenance? = root.domainMaintenance(container: container,
                planning: planning, track: track, phaseII: phaseII, focusCommands: nil)
            XCTAssertTrue(first === second)
            let separate = root.domainMaintenance(container: otherContainer,
                planning: CoreDataPlanningRepository(container: otherContainer),
                track: CoreDataTrackFoundationRepository(container: otherContainer),
                phaseII: CoreDataLifeBoardPhaseIIRepository(container: otherContainer), focusCommands: nil)
            XCTAssertFalse(first === separate)
            first = nil
            XCTAssertNotNil(released, "Another scene still owns the service")
            second = nil
            XCTAssertNil(released, "The dependency registry must not retain an unused service")
        }
    }

    func testMaintenanceInvalidationCarriesContainerAndAffectedDomainOnly() async throws {
        let container = try await makeTrackFoundationContainer()
        let context = container.newBackgroundContext()
        let event = await context.perform {
            let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
            let id = UUID()
            task.setValue(id, forKey: "id")
            let notification = Notification(name: .NSManagedObjectContextDidSave, object: context,
                userInfo: [NSUpdatedObjectsKey: Set([task])])
            return FoundationDomainMaintenance.invalidation(notification)
        }
        let value = try XCTUnwrap(event)
        XCTAssertEqual(value.containerID, ObjectIdentifier(container.persistentStoreCoordinator))
        XCTAssertEqual(value.domains, [.focus])
        XCTAssertEqual(value.affectedIDs.count, 1)
        let unrelated = await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
            return FoundationDomainMaintenance.invalidation(.init(name: .NSManagedObjectContextDidSave,
                object: context, userInfo: [NSUpdatedObjectsKey: Set([object])]))
        }
        XCTAssertNil(unrelated, "Unrelated writes must not trigger medication, routine or focus reads")
    }

    func testFocusTitleProjectionReadsOnlyRequestedTask() async throws {
        let container = try await makeTrackFoundationContainer()
        let context = container.newBackgroundContext()
        let id = UUID()
        try await context.perform {
            for (taskID, title) in [(id, "Focused title"), (UUID(), "Unrelated title")] {
                let task = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
                task.setValue(taskID, forKey: "id")
                task.setValue(title, forKey: "title")
            }
            try context.save()
        }
        let repository = CoreDataPlanningRepository(container: container)
        let title = try await repository.focusTaskTitle(taskID: id)
        let missing = try await repository.focusTaskTitle(taskID: UUID())
        XCTAssertEqual(title, "Focused title")
        XCTAssertNil(missing)
    }

    private func modelBundleURL() throws -> URL {
        try PersistenceTestModel.url()
    }

    private func makeTrackFoundationContainer() async throws -> NSPersistentContainer {
        let model = try XCTUnwrap(
            NSManagedObjectModel(
                contentsOf: try modelBundleURL()
                    .appendingPathComponent("TaskModelV3_BehaviorFlagship.mom")
            )
        )
        let container = NSPersistentContainer(
            name: "GoalLifecycle-\(UUID().uuidString)",
            managedObjectModel: model
        )
        let cloud = NSPersistentStoreDescription()
        cloud.type = NSInMemoryStoreType
        cloud.configuration = "CloudSync"
        cloud.url = URL(fileURLWithPath: "/dev/null/cloud-\(UUID().uuidString)")
        let local = NSPersistentStoreDescription()
        local.type = NSInMemoryStoreType
        local.configuration = "LocalOnly"
        local.url = URL(fileURLWithPath: "/dev/null/local-\(UUID().uuidString)")
        container.persistentStoreDescriptions = [cloud, local]
        try await load(container)

        let localStore = try XCTUnwrap(
            container.persistentStoreCoordinator.persistentStores.first {
                $0.configurationName == "LocalOnly"
            }
        )
        let context = container.newBackgroundContext()
        try await context.perform {
            let checkpoint = NSEntityDescription.insertNewObject(
                forEntityName: "HealthMigrationCheckpoint",
                into: context
            )
            context.assign(checkpoint, to: localStore)
            checkpoint.setValue("overall", forKey: "id")
            checkpoint.setValue("validated", forKey: "phaseRaw")
            checkpoint.setValue(Date(), forKey: "completedAt")
            checkpoint.setValue(Date(), forKey: "updatedAt")
            try context.save()
        }
        return container
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

private actor ScenarioPlanningRepository:
    PlanningRepository,
    InternalTimeBlockRepository,
    PlanningMutationRepository
{
    private var metadata: [UUID: PlanningTaskMetadata]
    private var blocks: [UUID: InternalTimeBlock] = [:]
    private var prepared: PlanMutationReceipt?
    private var applied = false

    init(metadata: [PlanningTaskMetadata]) {
        self.metadata = Dictionary(
            uniqueKeysWithValues: metadata.map { ($0.taskID, $0) }
        )
    }

    func preparedSource() -> String? { prepared?.source }
    func didApply() -> Bool { applied }

    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata] {
        guard let taskIDs else { return Array(metadata.values) }
        return taskIDs.compactMap { metadata[$0] }
    }

    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws {
        metadata[value.taskID] = value
    }

    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws {
        for value in values { metadata[value.taskID] = value }
    }

    func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock] {
        Array(blocks.values)
    }

    func saveTimeBlock(_ value: InternalTimeBlock) async throws {
        blocks[value.id] = value
    }

    func deleteTimeBlock(id: UUID) async throws {
        blocks.removeValue(forKey: id)
    }

    func fetchWorkingHoursProfiles() async throws -> [WorkingHoursProfile] { [] }
    func saveWorkingHoursProfile(_ value: WorkingHoursProfile) async throws {}

    func prepare(
        _ mutation: PlanMutation,
        source: String,
        summary: String
    ) async throws -> PlanMutationReceipt {
        let receipt = PlanMutationReceipt(
            id: UUID(),
            source: source,
            summary: summary,
            forwardData: Data(),
            undoData: Data(),
            createdAt: Date()
        )
        prepared = receipt
        return receipt
    }

    func apply(receiptID: UUID) async throws {
        applied = prepared?.id == receiptID
    }

    func undo(receiptID: UUID) async throws {
        if prepared?.id == receiptID { applied = false }
    }

    func hasAppliedReceipt(source: String) async throws -> Bool {
        applied && prepared?.source == source
    }

    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord] {
        guard let prepared else { return [] }
        return [
            PlanningReceiptRecord(
                receipt: prepared,
                state: applied ? .applied : .prepared
            )
        ]
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

private struct FailingPerformanceCalendarRepository: PlanningCalendarContextRepository {
    func authorization() async -> PlanningCalendarAuthorization { .authorized }
    func requestAccess() async -> PlanningCalendarAuthorization { .authorized }
    func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        throw NSError(domain: "PerformanceCalendar", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Calendar unavailable during refresh"])
    }
}

private actor SuspendedPerformanceCalendarRepository: PlanningCalendarContextRepository {
    private var released = false
    private var waiter: CheckedContinuation<Void, Never>?
    func authorization() async -> PlanningCalendarAuthorization { .authorized }
    func requestAccess() async -> PlanningCalendarAuthorization { .authorized }
    func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        if !released { await withCheckedContinuation { waiter = $0 } }
        return .init(authorization: .authorized)
    }
    func release() {
        released = true
        waiter?.resume()
        waiter = nil
    }
}

@MainActor
private final class PerformanceHomeSelection {
    var isCurrent = true
}

private actor SuspendedPerformanceHealthReader: HealthMetricsReading {
    private var released = false
    private var waiter: CheckedContinuation<Void, Never>?
    func currentSnapshot(now: Date) async -> HealthMetricsSnapshot {
        if !released { await withCheckedContinuation { waiter = $0 } }
        return .init()
    }
    func cachedHistory(domain: HealthInsightDomain, range: HealthHistoryRange,
                       now: Date) async -> [HealthMetric: [HealthAggregateValue]] { [:] }
    func requestAutomaticRefresh() async {}
    func updates() async -> AsyncStream<HealthSyncEvent> { AsyncStream { $0.finish() } }
    func release() {
        released = true
        waiter?.resume()
        waiter = nil
    }
}

private actor PerformanceCardGate {
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if !released { await withCheckedContinuation { continuation = $0 } }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}

private struct PerformanceCardSource: HomeCardSource {
    let definition: HomeCardDefinition
    let gate: PerformanceCardGate?
    var primaryDestination: Destination { .home }
    var privacyClassification: DataSensitivity { definition.sensitivity }
    init(kind: DashboardWidgetKind, gate: PerformanceCardGate?) {
        self.gate = gate
        definition = .init(kind: kind, title: kind.rawValue, category: .reflect,
            supportedSizes: [.standard], multiplicity: .singleton,
            sensitivity: kind == .journal ? .privateSensitive : .privateStandard)
    }
    func snapshot(configuration: HomeCardConfiguration, size: HomeCardSize,
                  at date: Date) async -> HomeCardSnapshot {
        await gate?.wait()
        return .init(availability: .ready, title: definition.title, value: "Current", updatedAt: date)
    }
}

private actor SuspendedPerformanceGoalSamples: GoalSampleRepository {
    private var entered = false
    private var released = false
    private var entryWaiter: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    func samples(for links: [GoalLink], asOf date: Date) async throws -> [GoalProgressSample] {
        entered = true
        entryWaiter?.resume()
        entryWaiter = nil
        if !released { await withCheckedContinuation { waiter = $0 } }
        return []
    }
    func waitUntilEntered() async {
        if !entered { await withCheckedContinuation { entryWaiter = $0 } }
    }
    func release() {
        released = true
        waiter?.resume()
        waiter = nil
    }
}

private actor PerformanceMoodReadGate {
    let onEnter: @Sendable () -> Void
    private var didEnter = false
    private var released = false
    private var waiter: CheckedContinuation<Void, Never>?
    init(onEnter: @escaping @Sendable () -> Void) { self.onEnter = onEnter }
    func suspendOnce() async {
        guard !didEnter else { return }
        didEnter = true
        onEnter()
        if !released { await withCheckedContinuation { waiter = $0 } }
    }
    func release() {
        released = true
        waiter?.resume()
        waiter = nil
    }
}

/// Delegates persistence but intentionally exposes only the public repository
/// contract, as alternate Home hosts do. The first mood read retains old values.
private struct PerformanceUnversionedMoodRepository: PhaseIIRepository {
    let base: CoreDataLifeBoardPhaseIIRepository
    let gate: PerformanceMoodReadGate
    var saveGate: PerformanceMoodReadGate? = nil
    func fetchMoodCheckIns(from: Date?, to: Date?) async throws -> [MoodEnergyCheckInValue] {
        let values = try await base.fetchMoodCheckIns(from: from, to: to)
        await gate.suspendOnce()
        return values
    }
    func fetchTrackers() async throws -> [TrackerDefinitionValue] { try await base.fetchTrackers() }
    func saveTracker(_ value: TrackerDefinitionValue) async throws { try await base.saveTracker(value) }
    func deleteTracker(id: UUID) async throws { try await base.deleteTracker(id: id) }
    func fetchTrackerEntries(trackerID: UUID?) async throws -> [TrackerEntryValue] { try await base.fetchTrackerEntries(trackerID: trackerID) }
    func fetchTrackerEntries(trackerID: UUID?, from: Date, to: Date) async throws -> [TrackerEntryValue] { try await base.fetchTrackerEntries(trackerID: trackerID, from: from, to: to) }
    func fetchJournalDays(from: Date, to: Date) async throws -> [JournalDayValue] { try await base.fetchJournalDays(from: from, to: to) }
    func fetchJournalEvidence(from: Date, to: Date) async throws -> [JournalEvidenceSummary] { try await base.fetchJournalEvidence(from: from, to: to) }
    func saveTrackerEntry(_ value: TrackerEntryValue) async throws { try await base.saveTrackerEntry(value) }
    func deleteTrackerEntry(id: UUID) async throws { try await base.deleteTrackerEntry(id: id) }
    func saveMoodCheckIn(_ value: MoodEnergyCheckInValue) async throws {
        try await base.saveMoodCheckIn(value)
        await saveGate?.suspendOnce()
    }
    func deleteMoodCheckIn(id: UUID) async throws { try await base.deleteMoodCheckIn(id: id) }
    func fetchMedications() async throws -> [MedicationDefinitionValue] { try await base.fetchMedications() }
    func saveMedication(_ value: MedicationDefinitionValue) async throws { try await base.saveMedication(value) }
    func deleteMedication(id: UUID) async throws { try await base.deleteMedication(id: id) }
    func fetchMedicationSchedules(medicationID: UUID?) async throws -> [MedicationScheduleValue] { try await base.fetchMedicationSchedules(medicationID: medicationID) }
    func saveMedicationSchedule(_ value: MedicationScheduleValue) async throws { try await base.saveMedicationSchedule(value) }
    func fetchMedicationEvents(from: Date, to: Date) async throws -> [MedicationEventValue] { try await base.fetchMedicationEvents(from: from, to: to) }
    func saveMedicationEvent(_ value: MedicationEventValue) async throws { try await base.saveMedicationEvent(value) }
    func fetchFastingSessions(limit: Int) async throws -> [FastingSessionValue] { try await base.fetchFastingSessions(limit: limit) }
    func saveFastingSession(_ value: FastingSessionValue) async throws { try await base.saveFastingSession(value) }
    func fetchFastingTemplates(includeArchived: Bool) async throws -> [FastingTemplateValue] { try await base.fetchFastingTemplates(includeArchived: includeArchived) }
    func saveFastingTemplate(_ value: FastingTemplateValue) async throws { try await base.saveFastingTemplate(value) }
    func fetchJournalDays(search: String?, starredOnly: Bool, mood: JournalMood?) async throws -> [JournalDayValue] { try await base.fetchJournalDays(search: search, starredOnly: starredOnly, mood: mood) }
    func fetchJournalDay(containing date: Date) async throws -> JournalDayValue? { try await base.fetchJournalDay(containing: date) }
    func saveJournalDay(_ value: JournalDayValue) async throws { try await base.saveJournalDay(value) }
    func deleteJournalDay(id: UUID) async throws { try await base.deleteJournalDay(id: id) }
    func fetchJournalDraft(dayID: UUID?) async throws -> JournalDraftValue? { try await base.fetchJournalDraft(dayID: dayID) }
    func saveJournalDraft(_ value: JournalDraftValue) async throws { try await base.saveJournalDraft(value) }
    func deleteJournalDraft(id: UUID) async throws { try await base.deleteJournalDraft(id: id) }
    func fetchKnowledgeSpaces() async throws -> [KnowledgeSpaceValue] { try await base.fetchKnowledgeSpaces() }
    func saveKnowledgeSpace(_ value: KnowledgeSpaceValue) async throws { try await base.saveKnowledgeSpace(value) }
    func fetchKnowledgeFolders(spaceID: UUID?) async throws -> [KnowledgeFolderValue] { try await base.fetchKnowledgeFolders(spaceID: spaceID) }
    func saveKnowledgeFolder(_ value: KnowledgeFolderValue) async throws { try await base.saveKnowledgeFolder(value) }
    func fetchKnowledgeNotes(search: String?, spaceID: UUID?) async throws -> [KnowledgeNoteValue] { try await base.fetchKnowledgeNotes(search: search, spaceID: spaceID) }
    func saveKnowledgeNote(_ value: KnowledgeNoteValue) async throws { try await base.saveKnowledgeNote(value) }
    func deleteKnowledgeNote(id: UUID) async throws { try await base.deleteKnowledgeNote(id: id) }
    func fetchKnowledgeTags() async throws -> [KnowledgeTagValue] { try await base.fetchKnowledgeTags() }
    func saveKnowledgeTag(_ value: KnowledgeTagValue) async throws { try await base.saveKnowledgeTag(value) }
    func fetchKnowledgeLinks() async throws -> [KnowledgeLinkValue] { try await base.fetchKnowledgeLinks() }
    func saveKnowledgeLink(_ value: KnowledgeLinkValue) async throws { try await base.saveKnowledgeLink(value) }
    func deleteKnowledgeLink(id: UUID) async throws { try await base.deleteKnowledgeLink(id: id) }
    func fetchKnowledgeAttachments(noteID: UUID) async throws -> [KnowledgeAttachmentValue] { try await base.fetchKnowledgeAttachments(noteID: noteID) }
    func saveKnowledgeAttachment(_ value: KnowledgeAttachmentValue) async throws { try await base.saveKnowledgeAttachment(value) }
    func deleteKnowledgeAttachment(id: UUID) async throws { try await base.deleteKnowledgeAttachment(id: id) }
    func fetchKnowledgeNotes(query: KnowledgeNoteQuery) async throws -> [KnowledgeNoteValue] { try await base.fetchKnowledgeNotes(query: query) }
    func fetchKnowledgeSmartCollections(spaceID: UUID?) async throws -> [KnowledgeSmartCollectionValue] { try await base.fetchKnowledgeSmartCollections(spaceID: spaceID) }
    func saveKnowledgeSmartCollection(_ value: KnowledgeSmartCollectionValue) async throws { try await base.saveKnowledgeSmartCollection(value) }
    func deleteKnowledgeSmartCollection(id: UUID) async throws { try await base.deleteKnowledgeSmartCollection(id: id) }
    func fetchKnowledgeDraft(noteID: UUID) async throws -> KnowledgeNoteDraftValue? { try await base.fetchKnowledgeDraft(noteID: noteID) }
    func saveKnowledgeDraft(_ value: KnowledgeNoteDraftValue) async throws { try await base.saveKnowledgeDraft(value) }
    func deleteKnowledgeDraft(noteID: UUID) async throws { try await base.deleteKnowledgeDraft(noteID: noteID) }
    func fetchKnowledgeRevisions(noteID: UUID) async throws -> [KnowledgeNoteRevisionValue] { try await base.fetchKnowledgeRevisions(noteID: noteID) }
    func saveKnowledgeRevision(_ value: KnowledgeNoteRevisionValue) async throws { try await base.saveKnowledgeRevision(value) }
    func pruneKnowledgeRecovery(now: Date) async throws { try await base.pruneKnowledgeRecovery(now: now) }
}
