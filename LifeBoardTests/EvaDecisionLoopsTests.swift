import CoreData
import Foundation
import Testing
@testable import LifeBoard

@Suite("EVA decision loops")
struct EvaDecisionLoopsTests {
    @Test("Signed runtime controls independently suppress decision-loop surfaces")
    func signedRuntimeControlsAreIndependent() {
        let previous = AppRuntimeConfigurationStore.current
        defer {
            AppRuntimeConfigurationStore.accept(previous)
            V2FeatureFlags.evaMakeItFitTodayV1Enabled = true
            V2FeatureFlags.evaFrictionDetectiveV1Enabled = true
            V2FeatureFlags.evaWeeklyResetV1Enabled = true
        }

        V2FeatureFlags.evaMakeItFitTodayV1Enabled = true
        V2FeatureFlags.evaFrictionDetectiveV1Enabled = true
        V2FeatureFlags.evaWeeklyResetV1Enabled = true

        let cases = [
            (makeItFit: false, friction: true, weekly: true),
            (makeItFit: true, friction: false, weekly: true),
            (makeItFit: true, friction: true, weekly: false)
        ]

        for testCase in cases {
            AppRuntimeConfigurationStore.accept(.init(
                onboardingLifeWeaveV6Enabled: true,
                existingUserRefreshVersion: 1,
                existingUserRefreshEnabled: true,
                productEventsEnabled: true,
                evaMakeItFitTodayV1Enabled: testCase.makeItFit,
                evaFrictionDetectiveV1Enabled: testCase.friction,
                evaWeeklyResetV1Enabled: testCase.weekly
            ))

            #expect(V2FeatureFlags.evaMakeItFitTodayV1Enabled == testCase.makeItFit)
            #expect(V2FeatureFlags.evaFrictionDetectiveV1Enabled == testCase.friction)
            #expect(V2FeatureFlags.evaWeeklyResetV1Enabled == testCase.weekly)
        }
    }

    @Test("Signed runtime controls default decision loops on for legacy policy documents")
    func legacyRuntimePolicyDefaultsDecisionLoopsOn() throws {
        let legacy = """
        {
          "onboardingLifeWeaveV6Enabled": true,
          "existingUserRefreshVersion": 1,
          "existingUserRefreshEnabled": true,
          "productEventsEnabled": true
        }
        """.data(using: .utf8)!

        let runtime = try JSONDecoder().decode(
            EvaCloudRuntimeConfiguration.AppRuntimeConfiguration.self,
            from: legacy
        )

        #expect(runtime.evaMakeItFitTodayV1Enabled)
        #expect(runtime.evaFrictionDetectiveV1Enabled)
        #expect(runtime.evaWeeklyResetV1Enabled)
    }

    @Test("Friction counters are never double-counted")
    func frictionUsesDistinctEventFallback() {
        let task = TaskDefinition(
            title: "Prepare launch brief",
            estimatedDuration: 2 * 60 * 60,
            deferredCount: 3,
            replanCount: 5
        )

        let snapshot = FrictionEvidenceIndex.analyze(task: task)

        #expect(snapshot.distinctEventCount == 5)
        #expect(snapshot.isProactivelyEligible)
        #expect(snapshot.evidence.contains { $0.reason == "Replanned 5 times" })
    }

    @Test("Sparse friction history stays explicitly uncertain")
    func sparseFrictionHistory() {
        let snapshot = FrictionEvidenceIndex.analyze(task: TaskDefinition(title: "Draft outline"))

        #expect(snapshot.distinctEventCount == 0)
        #expect(snapshot.isProactivelyEligible == false)
        #expect(snapshot.evidence.contains { $0.signalKey == "missing_estimate" })
    }

    @Test("Unknown estimates never reduce overload")
    func commitmentRealismDoesNotCountUnknownWorkAsFree() {
        let day = PlanningDay(date: Date())
        let knownID = UUID()
        let unknownID = UUID()
        let known = PlanningTaskSummary(
            id: knownID,
            title: "Known work",
            estimatedDuration: 90 * 60,
            metadata: PlanningTaskMetadata(taskID: knownID, planningDay: day)
        )
        let unknown = PlanningTaskSummary(
            id: unknownID,
            title: "Unknown work",
            metadata: PlanningTaskMetadata(taskID: unknownID, planningDay: day)
        )
        let snapshot = CommitmentRealismSnapshot(
            day: day,
            usableMinutes: 180,
            plannedKnownMinutes: 300,
            overloadMinutes: 120,
            missingEstimateCount: 1,
            fixedCommitments: [],
            flexibleTasks: [known, unknown],
            anchorTaskID: knownID
        )

        #expect(CommitmentRealismEngine.remainingOverloadMinutes(
            snapshot: snapshot,
            choices: [unknownID: .later]
        ) == 120)
        #expect(CommitmentRealismEngine.remainingOverloadMinutes(
            snapshot: snapshot,
            choices: [knownID: .tomorrow, unknownID: .later]
        ) == 30)
    }

    @Test("Carry, Later, and Release have distinct planning homes", arguments: WeeklyResetDestinationCase.cases)
    func weeklyResetDestinations(_ testCase: WeeklyResetDestinationCase) {
        let line = WeeklyResetProposalLine(
            task: TaskDefinition(title: "Review proposal"),
            disposition: testCase.disposition
        )

        #expect(line.destination == testCase.expectedBucket)
    }

    @Test("Weekly review keeps legacy immediate mutation and supports record-only reset")
    func weeklyReviewMutationModes() {
        let legacy = CompleteWeeklyReviewRequest(weeklyPlanID: UUID())
        let reset = CompleteWeeklyReviewRequest(
            weeklyPlanID: UUID(),
            mutationMode: .recordOnly
        )

        #expect(legacy.mutationMode == .applyImmediately)
        #expect(reset.mutationMode == .recordOnly)
    }

    @Test("Friction findings round-trip through a content-portable export")
    func frictionFindingExportRoundTrip() throws {
        let finding = FrictionFinding(
            taskID: UUID(),
            deferredCountAtDetection: 4,
            replanCountAtDetection: 2,
            evidence: [],
            selectedReason: .interruptions,
            intervention: .moveToBetterWindow,
            reviewAfter: Date().addingTimeInterval(7 * 86_400)
        )

        let data = try JSONEncoder().encode(finding)
        let decoded = try JSONDecoder().decode(FrictionFinding.self, from: data)

        #expect(decoded == finding)
    }

    @Test("Structured daily brief fields survive client decoding")
    @MainActor
    func structuredDailyBriefDecoding() throws {
        let taskID = UUID()
        let raw = """
        {"brief":"Protect the launch review.","fixedCommitments":["10:00 review"],"nextMove":"Open the brief","tradeoff":{"drop":"Polish slides","because":"Only 45 minutes remain"},"evidenceTaskIDs":["\(taskID.uuidString)"],"isOvercommitted":true}
        """

        let output = try #require(DailyBriefService().decodeStructuredOutput(from: raw))

        #expect(output.fixedCommitments == ["10:00 review"])
        #expect(output.nextMove == "Open the brief")
        #expect(output.tradeoff == .init(drop: "Polish slides", because: "Only 45 minutes remain"))
        #expect(output.evidenceTaskIDs == [taskID])
        #expect(output.modelSaysOvercommitted == true)
    }

    @Test("Ritual restoration persists references and choices, not task snapshots")
    @MainActor
    func ritualDraftRoundTrip() throws {
        let suiteName = "EvaDecisionLoopsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = EvaRitualDraftStore(defaults: defaults)
        let taskID = UUID()
        let draft = EvaRitualDraftReference(
            kind: .makeItFitToday,
            recordIDs: [taskID],
            phaseRaw: EvaRitualPhase.previewing.rawValue,
            choices: [taskID.uuidString: MakeItFitDestination.tomorrow.rawValue]
        )

        store.save(draft)

        #expect(store.load(.makeItFitToday) == draft)
    }

    @Test("Friction findings persist locally with structured evidence")
    @MainActor
    func frictionFindingRepositoryRoundTrip() async throws {
        let model = try PersistenceTestModel.model()
        #expect(model.entitiesByName["FrictionFinding"] != nil)
        let container = NSPersistentContainer(name: "EvaDecisionLoopsTests", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }

        let repository = CoreDataFrictionFindingRepository(container: container)
        let task = TaskDefinition(title: "Untangle dependency", deferredCount: 3, replanCount: 3)
        let evidence = FrictionEvidenceIndex.analyze(task: task).evidence
        let finding = FrictionFinding(
            taskID: task.id,
            deferredCountAtDetection: task.deferredCount,
            replanCountAtDetection: task.replanCount,
            evidence: evidence,
            selectedReason: .blockedOrWaiting,
            intervention: .noteDependency,
            reviewAfter: Date().addingTimeInterval(7 * 86_400)
        )

        let saved = try await save(finding, using: repository)
        let fetched = try await fetch(using: repository)

        #expect(saved == finding)
        #expect(fetched == [finding])
        #expect(fetched.first?.distinctEventCountFallback == 3)

        try await delete(finding.id, using: repository)
        let afterDelete = try await fetch(using: repository)
        #expect(afterDelete.isEmpty)
    }

    @MainActor
    private func save(
        _ finding: FrictionFinding,
        using repository: FrictionFindingRepositoryProtocol
    ) async throws -> FrictionFinding {
        try await withCheckedThrowingContinuation { continuation in
            repository.saveFinding(finding) { continuation.resume(with: $0) }
        }
    }

    @MainActor
    private func fetch(
        using repository: FrictionFindingRepositoryProtocol
    ) async throws -> [FrictionFinding] {
        try await withCheckedThrowingContinuation { continuation in
            repository.fetchFindings(query: FrictionFindingQuery()) { continuation.resume(with: $0) }
        }
    }

    @MainActor
    private func delete(
        _ id: UUID,
        using repository: FrictionFindingRepositoryProtocol
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            repository.deleteFinding(id: id) { continuation.resume(with: $0) }
        }
    }
}

struct WeeklyResetDestinationCase: Sendable, CustomTestStringConvertible {
    let disposition: WeeklyReviewTaskDisposition
    let expectedBucket: TaskPlanningBucket

    var testDescription: String { "\(disposition.rawValue) → \(expectedBucket.rawValue)" }

    static let cases: [Self] = [
        .init(disposition: .carry, expectedBucket: .nextWeek),
        .init(disposition: .later, expectedBucket: .later),
        .init(disposition: .drop, expectedBucket: .someday)
    ]
}
