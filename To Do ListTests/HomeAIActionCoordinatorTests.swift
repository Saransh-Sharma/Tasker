import XCTest
@testable import To_Do_List

final class HomeAIActionCoordinatorTests: XCTestCase {
    func testAskModeBuildsReadOnlyWeeklyPreview() {
        let pipeline = AssistantActionPipelineUseCase(
            repository: InMemoryAssistantActionRepositoryStub(),
            taskRepository: InMemoryTaskDefinitionRepositoryStub()
        )
        let coordinator = HomeAIActionCoordinator(
            pipeline: pipeline,
            contextServiceFactory: { nil }
        )

        let outcomeID = UUID()
        let task = TaskDefinition(
            id: UUID(),
            title: "Draft launch note",
            planningBucket: .nextWeek
        )
        let change = HomeWeeklyTaskProposalChange(
            task: task,
            targetPlanningBucket: .thisWeek,
            targetWeeklyOutcomeID: outcomeID
        )

        let expectation = expectation(description: "weekly-ask-preview")
        coordinator.proposeWeeklyPlan(
            mode: .ask,
            weekStartDate: Date(timeIntervalSince1970: 1_700_000_000),
            taskChanges: [change],
            threadID: "weekly_thread",
            weeklyOutcomeTitlesByID: [outcomeID: "Ship launch prep"],
            rationale: { _ in "Review weekly draft" }
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected ask preview, got error: \(error)")
            case .success(let preview):
                XCTAssertEqual(preview.mode, .ask)
                XCTAssertNil(preview.run)
                XCTAssertEqual(preview.commands.count, 1)
                XCTAssertEqual(preview.affectedTaskCount, 1)
                XCTAssertTrue(preview.diffLines.contains(where: { $0.text == "Move 'Draft launch note' to This Week" }))
                XCTAssertTrue(preview.diffLines.contains(where: { $0.text == "Link 'Draft launch note' to outcome 'Ship launch prep'" }))

                guard case .restoreTaskSnapshot(let snapshot) = preview.commands[0] else {
                    return XCTFail("Expected restoreTaskSnapshot command")
                }
                XCTAssertEqual(snapshot.id, task.id)
                XCTAssertEqual(snapshot.planningBucket, .thisWeek)
                XCTAssertEqual(snapshot.weeklyOutcomeID, outcomeID)
                XCTAssertNotNil(preview.contextJSON)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testSuggestModePersistsPendingRunWithWeeklySnapshotCommands() throws {
        let actionRepository = InMemoryAssistantActionRepositoryStub()
        let pipeline = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: InMemoryTaskDefinitionRepositoryStub()
        )
        let coordinator = HomeAIActionCoordinator(
            pipeline: pipeline,
            contextServiceFactory: { nil }
        )

        let task = TaskDefinition(
            id: UUID(),
            title: "Clean backlog",
            planningBucket: .thisWeek,
            weeklyOutcomeID: UUID()
        )
        let change = HomeWeeklyTaskProposalChange(
            task: task,
            targetPlanningBucket: .later
        )

        let expectation = expectation(description: "weekly-suggest-preview")
        coordinator.proposeWeeklyPlan(
            mode: .suggest,
            weekStartDate: Date(timeIntervalSince1970: 1_700_050_000),
            taskChanges: [change],
            threadID: "weekly_thread",
            rationale: { _ in "Suggest later cleanup" }
        ) { result in
            switch result {
            case .failure(let error):
                XCTFail("Expected suggest preview, got error: \(error)")
            case .success(let preview):
                XCTAssertEqual(preview.mode, .suggest)
                XCTAssertNotNil(preview.run)
                XCTAssertEqual(preview.run?.status, .pending)
                XCTAssertEqual(preview.destructiveCount, 2)
                XCTAssertEqual(preview.rationale, "Suggest later cleanup")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        let storedRun = try unwrap(actionRepository.runs.values.first)
        let payload = try unwrap(storedRun.proposalData)
        let envelope = try JSONDecoder().decode(AssistantCommandEnvelope.self, from: payload)
        XCTAssertEqual(envelope.schemaVersion, 2)
        XCTAssertEqual(envelope.rationaleText, "Suggest later cleanup")
        XCTAssertEqual(envelope.commands.count, 1)

        guard case .restoreTaskSnapshot(let snapshot) = envelope.commands[0] else {
            return XCTFail("Expected restoreTaskSnapshot command")
        }
        XCTAssertEqual(snapshot.id, task.id)
        XCTAssertEqual(snapshot.planningBucket, .later)
        XCTAssertNil(snapshot.weeklyOutcomeID)
    }

    private func unwrap<T>(_ value: T?) throws -> T {
        try XCTUnwrap(value)
    }
}

private final class InMemoryAssistantActionRepositoryStub: AssistantActionRepositoryProtocol {
    var runs: [UUID: AssistantActionRunDefinition] = [:]

    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        runs[run.id] = run
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        runs[run.id] = run
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(runs[id]))
    }

    func fetchPendingRuns(threadID: String?, completion: @escaping (Result<[AssistantActionRunDefinition], Error>) -> Void) {
        let filtered = runs.values.filter { run in
            run.status == .pending && (threadID == nil || run.threadID == threadID)
        }
        completion(.success(filtered.sorted { $0.createdAt < $1.createdAt }))
    }
}
