import CoreData
import XCTest
@testable import LifeBoard
import LifeBoardContracts

/// In-memory stand-in for the task repository.
///
/// An actor rather than a locked class: the protocol's methods are `async`, and
/// `NSLock.lock()` is unavailable from an async context.
private actor SpyTaskWriter: InboxTaskWriting {
    private(set) var created: [InboxCaptureCommitRequest] = []
    private(set) var deleted: [UUID] = []
    private(set) var moves: [(id: UUID, project: UUID?)] = []
    private var createResult: Result<UUID, Error> = .success(UUID())
    private var deleteError: Error?

    struct Boom: Error {}

    func setCreateResult(_ value: Result<UUID, Error>) { createResult = value }
    func setDeleteError(_ value: Error?) { deleteError = value }

    var movedProjects: [UUID?] { moves.map(\.project) }

    func createTask(_ request: InboxCaptureCommitRequest) async throws -> UUID {
        created.append(request)
        return try createResult.get()
    }

    func deleteTask(id: UUID) async throws {
        if let deleteError { throw deleteError }
        deleted.append(id)
    }

    func moveTask(id: UUID, toProject projectID: UUID?) async throws {
        moves.append((id, projectID))
    }
}

final class TaskBatchMutationCoordinatorTests: XCTestCase {

    func testMoveCompensatesEarlierDefinitionsWhenALaterWriteFails() async throws {
        let first = TaskDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "First"
        )
        let second = TaskDefinition(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Second"
        )
        let tasks = BatchFailingTaskRepository(
            seed: [first, second],
            failingUpdateAttempt: 2
        )
        let coordinator = TaskBatchMutationCoordinator(
            tasks: tasks,
            planning: BatchPlanningRepository()
        )

        do {
            _ = try await coordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [first.id, second.id],
                    mutation: .move(
                        projectID: UUID(),
                        projectName: "Destination",
                        sectionID: nil
                    )
                )
            )
            XCTFail("The second repository write should fail")
        } catch let error as TaskBatchMutationError {
            guard case .applyFailed = error else {
                return XCTFail("Expected applyFailed, received \(error)")
            }
        }

        XCTAssertEqual(tasks.snapshot()[first.id], first)
        XCTAssertEqual(tasks.snapshot()[second.id], second)
        XCTAssertEqual(tasks.updateAttemptCount, 3)
    }

    func testTagSidecarFailureRestoresTaskAndRelationshipSnapshot() async throws {
        let originalTag = UUID()
        let task = TaskDefinition(title: "Tagged", tagIDs: [originalTag])
        let tasks = BatchFailingTaskRepository(seed: [task])
        let links = BatchTagLinkRepository(
            seed: [task.id: [originalTag]],
            failingReplaceAttempt: 1
        )
        let coordinator = TaskBatchMutationCoordinator(
            tasks: tasks,
            planning: BatchPlanningRepository(),
            tagLinks: links
        )

        do {
            _ = try await coordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [task.id],
                    mutation: .addTags([UUID()])
                )
            )
            XCTFail("The first relationship write should fail")
        } catch let error as TaskBatchMutationError {
            guard case .applyFailed = error else {
                return XCTFail("Expected applyFailed, received \(error)")
            }
        }

        XCTAssertEqual(tasks.snapshot()[task.id], task)
        XCTAssertEqual(links.snapshot()[task.id], [originalTag])
        XCTAssertEqual(links.replaceAttemptCount, 2)
    }

    func testScheduleReceiptUndoRestoresDefinitionAndPlanningMetadata() async throws {
        let task = TaskDefinition(title: "Schedule me")
        let tasks = BatchFailingTaskRepository(seed: [task])
        let planning = BatchPlanningRepository()
        let coordinator = TaskBatchMutationCoordinator(tasks: tasks, planning: planning)
        let day = PlanningDay(year: 2026, month: 8, day: 4, timeZoneIdentifier: "UTC")
        let start = Date(timeIntervalSince1970: 1_775_280_400)
        let end = start.addingTimeInterval(45 * 60)

        let receipt = try await coordinator.apply(
            TaskBatchMutationRequest(
                taskIDs: [task.id],
                mutation: .schedule(planningDay: day, startAt: start, endAt: end)
            )
        )

        XCTAssertNotNil(receipt.planningReceiptID)
        XCTAssertEqual(tasks.snapshot()[task.id]?.scheduledStartAt, start)
        XCTAssertEqual(tasks.snapshot()[task.id]?.scheduledEndAt, end)
        let appliedMetadata = await planning.metadata(for: task.id)
        XCTAssertEqual(appliedMetadata?.planningDay, day)

        try await coordinator.undo(receipt)

        XCTAssertEqual(tasks.snapshot()[task.id], task)
        let restoredMetadata = await planning.metadata(for: task.id)
        XCTAssertNil(restoredMetadata?.planningDay)
    }

    func testInvalidScheduledIntervalMakesNoWrites() async throws {
        let task = TaskDefinition(title: "Invalid")
        let tasks = BatchFailingTaskRepository(seed: [task])
        let coordinator = TaskBatchMutationCoordinator(
            tasks: tasks,
            planning: BatchPlanningRepository()
        )
        let start = Date(timeIntervalSince1970: 1_775_280_400)

        do {
            _ = try await coordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [task.id],
                    mutation: .schedule(
                        planningDay: PlanningDay(
                            year: 2026,
                            month: 8,
                            day: 4,
                            timeZoneIdentifier: "UTC"
                        ),
                        startAt: start,
                        endAt: start
                    )
                )
            )
            XCTFail("An empty scheduled interval must be rejected")
        } catch let error as TaskBatchMutationError {
            XCTAssertEqual(error, .invalidSchedule)
        }

        XCTAssertEqual(tasks.updateAttemptCount, 0)
        XCTAssertEqual(tasks.snapshot()[task.id], task)
    }
}

@MainActor
final class PhaseOneRealCoreDataMutationJourneyTests: XCTestCase {

    func testEveryBatchFamilyPersistsAndUndoRestoresCanonicalRows() async throws {
        let container = try makeContainer()
        let tasks = CoreDataTaskDefinitionRepository(container: container)
        let planning = CoreDataPlanningRepository(container: container)
        let tagLinks = CoreDataTaskTagLinkRepository(container: container)
        let coordinator = TaskBatchMutationCoordinator(
            tasks: tasks,
            planning: planning,
            tagLinks: tagLinks
        )
        let originalProjectID = ProjectConstants.inboxProjectID
        let destinationProjectID = UUID()
        let destinationSectionID = UUID()
        let tagID = UUID()
        let scheduledDay = PlanningDay(
            year: 2026,
            month: 8,
            day: 4,
            timeZoneIdentifier: "UTC"
        )
        let deferredDay = PlanningDay(
            year: 2026,
            month: 8,
            day: 9,
            timeZoneIdentifier: "UTC"
        )
        let scheduledStart = Date(timeIntervalSince1970: 1_775_280_400)
        let scheduledEnd = scheduledStart.addingTimeInterval(45 * 60)
        let mutations: [TaskBatchMutation] = [
            .schedule(
                planningDay: scheduledDay,
                startAt: scheduledStart,
                endAt: scheduledEnd
            ),
            .addTags([tagID]),
            .move(
                projectID: destinationProjectID,
                projectName: "Deep Work",
                sectionID: destinationSectionID
            ),
            .deferTo(deferredDay),
            .setCompletion(true),
            .archive,
            .delete
        ]

        for (index, mutation) in mutations.enumerated() {
            let taskID = UUID()
            let original = try await createTask(
                id: taskID,
                title: "Batch \(index)",
                projectID: originalProjectID,
                repository: tasks
            )
            let receipt = try await coordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [taskID],
                    mutation: mutation,
                    source: "tests.real-core-data"
                )
            )

            let appliedTaskValue = try await fetchTask(id: taskID, repository: tasks)
            let appliedTask = try XCTUnwrap(appliedTaskValue)
            let appliedMetadataValues = try await planning.fetchTaskMetadata(taskIDs: [taskID])
            let appliedMetadata = appliedMetadataValues.first
                ?? PlanningTaskMetadata(taskID: taskID)
            switch mutation {
            case .schedule:
                XCTAssertEqual(appliedTask.scheduledStartAt, scheduledStart)
                XCTAssertEqual(appliedTask.scheduledEndAt, scheduledEnd)
                XCTAssertEqual(appliedMetadata.planningDay, scheduledDay)
            case .addTags:
                let savedTagIDs = try await fetchTagIDs(
                    taskID: taskID,
                    repository: tagLinks
                )
                XCTAssertEqual(
                    savedTagIDs,
                    [tagID]
                )
            case .move:
                XCTAssertEqual(appliedTask.projectID, destinationProjectID)
                XCTAssertEqual(appliedTask.sectionID, destinationSectionID)
            case .deferTo:
                XCTAssertEqual(appliedMetadata.planningDay, deferredDay)
                XCTAssertEqual(appliedMetadata.startDay, deferredDay)
            case .setCompletion:
                XCTAssertTrue(appliedTask.isComplete)
                XCTAssertNotNil(appliedTask.dateCompleted)
            case .archive:
                XCTAssertEqual(appliedMetadata.unscheduledDisposition, .archived)
            case .delete:
                XCTAssertEqual(appliedMetadata.unscheduledDisposition, .deleted)
            }

            try await coordinator.undo(receipt)

            let restoredTaskValue = try await fetchTask(id: taskID, repository: tasks)
            let restoredTask = try XCTUnwrap(restoredTaskValue)
            let restoredMetadataValues = try await planning.fetchTaskMetadata(taskIDs: [taskID])
            let restoredMetadata = restoredMetadataValues.first
                ?? PlanningTaskMetadata(taskID: taskID)
            XCTAssertEqual(restoredTask, original)
            // `PlanningTaskMetadata.init` defaults `updatedAt` to `Date()`, and
            // the synthesized `Equatable` compares it — so comparing a restored
            // row against a freshly constructed default compared two different
            // capture instants and could never pass, for any mutation. It hid
            // the real defect next to it: `.move` genuinely failed to restore
            // `sectionID`. Pin every field that carries meaning and normalize
            // only the write timestamp.
            var expectedMetadata = PlanningTaskMetadata(taskID: taskID)
            expectedMetadata.updatedAt = restoredMetadata.updatedAt
            XCTAssertEqual(
                restoredMetadata,
                expectedMetadata,
                "Undo must restore the absence of planning metadata for \(mutation)"
            )
            if case .addTags = mutation {
                let restoredTagIDs = try await fetchTagIDs(
                    taskID: taskID,
                    repository: tagLinks
                )
                XCTAssertEqual(
                    restoredTagIDs,
                    []
                )
            }
        }
    }

    func testPendingToTaskMergeUndoRestoresCoreDataTagRelationshipsExactly() async throws {
        let container = try makeContainer()
        let tasks = CoreDataTaskDefinitionRepository(container: container)
        let projects = CoreDataProjectRepository(container: container)
        let tags = CoreDataTagRepository(container: container)
        let tagLinks = CoreDataTaskTagLinkRepository(container: container)
        let originalTag = TagDefinition(name: "Existing", sortOrder: 0)
        _ = try await createTag(originalTag, repository: tags)
        let taskID = UUID()
        _ = try await createTask(
            id: taskID,
            title: "Original title",
            projectID: ProjectConstants.inboxProjectID,
            repository: tasks
        )
        try await replaceTagIDs(
            taskID: taskID,
            tagIDs: [originalTag.id],
            repository: tagLinks
        )

        let pending = PendingCapture(
            rawText: "Merged title #Incoming",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: "share-extension"
        )
        let queue = RealCoreDataCaptureQueue([pending])
        let coordinator = InboxCommitCoordinator(
            writer: CoreDataInboxTaskWriter(
                tasks: tasks,
                projects: projects,
                tags: tags,
                taskTagLinks: tagLinks
            ),
            queue: queue.access
        )

        let receipt = try await coordinator.merge(
            InboxCaptureCommitRequest(
                captureID: pending.id,
                title: "Merged title",
                tagNames: ["Incoming"]
            ),
            with: .task(taskID)
        )
        XCTAssertTrue(queue.values.isEmpty)
        let mergedValue = try await fetchTask(id: taskID, repository: tasks)
        let merged = try XCTUnwrap(mergedValue)
        XCTAssertEqual(merged.title, "Merged title")
        XCTAssertEqual(merged.tagIDs.count, 2)
        let mergedTagIDs = try await fetchTagIDs(taskID: taskID, repository: tagLinks)
        XCTAssertEqual(
            Set(mergedTagIDs),
            Set(merged.tagIDs)
        )

        try await coordinator.undoMerge(receipt)

        XCTAssertEqual(queue.values, [pending])
        let restoredValue = try await fetchTask(id: taskID, repository: tasks)
        let restored = try XCTUnwrap(restoredValue)
        XCTAssertEqual(restored.title, "Original title")
        XCTAssertEqual(restored.tagIDs, [originalTag.id])
        let restoredTagIDs = try await fetchTagIDs(taskID: taskID, repository: tagLinks)
        XCTAssertEqual(
            restoredTagIDs,
            [originalTag.id]
        )
    }

    private func makeContainer() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil,
              model.entitiesByName["PlanningMutationReceipt"] != nil else {
            throw NSError(
                domain: "PhaseOneRealCoreDataMutationJourneyTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3"]
            )
        }
        let container = NSPersistentContainer(
            name: "PhaseOneRealCoreDataMutationJourney",
            managedObjectModel: model
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    private func createTask(
        id: UUID,
        title: String,
        projectID: UUID,
        repository: any TaskDefinitionRepositoryProtocol
    ) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repository.create(
                request: CreateTaskDefinitionRequest(
                    id: id,
                    title: title,
                    projectID: projectID,
                    projectName: ProjectConstants.inboxProjectName,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            ) {
                continuation.resume(with: $0)
            }
        }
    }

    private func fetchTask(
        id: UUID,
        repository: any TaskDefinitionRepositoryProtocol
    ) async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            repository.fetchTaskDefinition(id: id) {
                continuation.resume(with: $0)
            }
        }
    }

    private func createTag(
        _ tag: TagDefinition,
        repository: any TagRepositoryProtocol
    ) async throws -> TagDefinition {
        try await withCheckedThrowingContinuation { continuation in
            repository.create(tag) { continuation.resume(with: $0) }
        }
    }

    private func replaceTagIDs(
        taskID: UUID,
        tagIDs: [UUID],
        repository: any TaskTagLinkRepositoryProtocol
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            repository.replaceTagLinks(taskID: taskID, tagIDs: tagIDs) {
                continuation.resume(with: $0)
            }
        }
    }

    private func fetchTagIDs(
        taskID: UUID,
        repository: any TaskTagLinkRepositoryProtocol
    ) async throws -> [UUID] {
        try await withCheckedThrowingContinuation { continuation in
            repository.fetchTagIDs(taskID: taskID) {
                continuation.resume(with: $0)
            }
        }
    }
}

private final class RealCoreDataCaptureQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [PendingCapture]

    init(_ captures: [PendingCapture]) {
        storage = captures
    }

    var values: [PendingCapture] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var access: InboxCaptureQueueAccess {
        InboxCaptureQueueAccess(
            read: { [weak self] in self?.values ?? [] },
            remove: { [weak self] ids in
                guard let self else { return }
                self.lock.lock()
                self.storage.removeAll { ids.contains($0.id) }
                self.lock.unlock()
            },
            restore: { [weak self] captures in
                guard let self else { return }
                self.lock.lock()
                for capture in captures {
                    if let index = self.storage.firstIndex(where: { $0.id == capture.id }) {
                        self.storage[index] = capture
                    } else {
                        self.storage.append(capture)
                    }
                }
                self.lock.unlock()
            }
        )
    }
}

private enum BatchMutationTestError: Error {
    case injectedUpdateFailure
    case injectedRelationshipFailure
}

private final class BatchFailingTaskRepository:
    TaskDefinitionRepositoryProtocol,
    @unchecked Sendable
{
    private struct FailureState {
        var updateAttempts = 0
        var failingUpdateAttempt: Int?
    }

    private let base: InMemoryTaskDefinitionRepositoryStub
    private let failureState: LockedTestState<FailureState>

    init(seed: [TaskDefinition], failingUpdateAttempt: Int? = nil) {
        base = InMemoryTaskDefinitionRepositoryStub(seed: seed)
        failureState = LockedTestState(
            FailureState(failingUpdateAttempt: failingUpdateAttempt)
        )
    }

    var updateAttemptCount: Int { failureState.read().updateAttempts }
    func snapshot() -> [UUID: TaskDefinition] { base.byID }

    func fetchAll(
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        base.fetchAll(completion: completion)
    }

    func fetchAll(
        query: TaskDefinitionQuery?,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        base.fetchAll(query: query, completion: completion)
    }

    func fetchTaskDefinition(
        id: UUID,
        completion: @escaping @Sendable (Result<TaskDefinition?, Error>) -> Void
    ) {
        base.fetchTaskDefinition(id: id, completion: completion)
    }

    func create(
        _ task: TaskDefinition,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        base.create(task, completion: completion)
    }

    func create(
        request: CreateTaskDefinitionRequest,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        base.create(request: request, completion: completion)
    }

    func update(
        _ task: TaskDefinition,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        let shouldFail = failureState.withValue { state in
            state.updateAttempts += 1
            if state.failingUpdateAttempt == state.updateAttempts {
                state.failingUpdateAttempt = nil
                return true
            }
            return false
        }
        guard shouldFail == false else {
            completion(.failure(BatchMutationTestError.injectedUpdateFailure))
            return
        }
        base.update(task, completion: completion)
    }

    func update(
        request: UpdateTaskDefinitionRequest,
        completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void
    ) {
        base.update(request: request, completion: completion)
    }

    func fetchChildren(
        parentTaskID: UUID,
        completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void
    ) {
        base.fetchChildren(parentTaskID: parentTaskID, completion: completion)
    }

    func delete(
        id: UUID,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        base.delete(id: id, completion: completion)
    }
}

private final class BatchTagLinkRepository:
    TaskTagLinkRepositoryProtocol,
    @unchecked Sendable
{
    private struct State {
        var links: [UUID: [UUID]]
        var replaceAttempts = 0
        var failingReplaceAttempt: Int?
    }

    private let state: LockedTestState<State>

    init(seed: [UUID: [UUID]], failingReplaceAttempt: Int? = nil) {
        state = LockedTestState(
            State(links: seed, failingReplaceAttempt: failingReplaceAttempt)
        )
    }

    var replaceAttemptCount: Int { state.read().replaceAttempts }
    func snapshot() -> [UUID: [UUID]] { state.read().links }

    func fetchTagIDs(
        taskID: UUID,
        completion: @escaping @Sendable (Result<[UUID], Error>) -> Void
    ) {
        completion(.success(state.read().links[taskID] ?? []))
    }

    func replaceTagLinks(
        taskID: UUID,
        tagIDs: [UUID],
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        let result: Result<Void, Error> = state.withValue { state in
            state.replaceAttempts += 1
            if state.failingReplaceAttempt == state.replaceAttempts {
                state.failingReplaceAttempt = nil
                return .failure(BatchMutationTestError.injectedRelationshipFailure)
            }
            state.links[taskID] = tagIDs
            return .success(())
        }
        completion(result)
    }
}

private actor BatchPlanningRepository: PlanningRepository, PlanningMutationRepository {
    private var metadataByTaskID: [UUID: PlanningTaskMetadata] = [:]
    private var mutationsByReceiptID: [UUID: PlanMutation] = [:]
    private var receipts: [UUID: PlanningReceiptRecord] = [:]

    func metadata(for taskID: UUID) -> PlanningTaskMetadata? {
        metadataByTaskID[taskID]
    }

    func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata] {
        guard let taskIDs else { return Array(metadataByTaskID.values) }
        return taskIDs.compactMap { metadataByTaskID[$0] }
    }

    func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws {
        metadataByTaskID[value.taskID] = value
    }

    func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws {
        for value in values { metadataByTaskID[value.taskID] = value }
    }

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
        mutationsByReceiptID[receipt.id] = mutation
        receipts[receipt.id] = PlanningReceiptRecord(receipt: receipt, state: .prepared)
        return receipt
    }

    func apply(receiptID: UUID) async throws {
        guard let mutation = mutationsByReceiptID[receiptID] else { return }
        applyForward(mutation)
        if var record = receipts[receiptID] {
            record.state = .applied
            record.appliedAt = Date()
            receipts[receiptID] = record
        }
    }

    func undo(receiptID: UUID) async throws {
        guard let mutation = mutationsByReceiptID[receiptID] else { return }
        applyUndo(mutation)
        if var record = receipts[receiptID] {
            record.state = .undone
            record.undoneAt = Date()
            receipts[receiptID] = record
        }
    }

    func hasAppliedReceipt(source: String) async throws -> Bool {
        receipts.values.contains {
            $0.receipt.source == source && $0.state == .applied
        }
    }

    func fetchMutationReceipts(since: Date?) async throws -> [PlanningReceiptRecord] {
        receipts.values.filter {
            guard let since else { return true }
            return $0.receipt.createdAt >= since
        }
    }

    private func applyForward(_ mutation: PlanMutation) {
        switch mutation {
        case let .saveTaskMetadata(_, after):
            metadataByTaskID[after.taskID] = after
        case let .batch(mutations):
            for mutation in mutations { applyForward(mutation) }
        case .saveTimeBlock, .deleteTimeBlock, .setTaskCompletion:
            break
        }
    }

    private func applyUndo(_ mutation: PlanMutation) {
        switch mutation {
        case let .saveTaskMetadata(before, _):
            metadataByTaskID[before.taskID] = before
        case let .batch(mutations):
            for mutation in mutations.reversed() { applyUndo(mutation) }
        case .saveTimeBlock, .deleteTimeBlock, .setTaskCompletion:
            break
        }
    }
}

final class InboxCommitCoordinatorTests: XCTestCase {

    private final class QueueBox: @unchecked Sendable {
        let lock = NSLock()
        var captures: [PendingCapture] = []
    }

    private func makeCoordinator(
        writer: SpyTaskWriter,
        seeded: [PendingCapture]
    ) -> (InboxCommitCoordinator, QueueBox) {
        let box = QueueBox()
        box.captures = seeded
        let access = InboxCaptureQueueAccess(
            read: { box.lock.lock(); defer { box.lock.unlock() }; return box.captures },
            remove: { ids in
                box.lock.lock(); defer { box.lock.unlock() }
                box.captures.removeAll { ids.contains($0.id) }
            },
            restore: { captures in
                box.lock.lock(); defer { box.lock.unlock() }
                for capture in captures {
                    if let index = box.captures.firstIndex(where: { $0.id == capture.id }) {
                        box.captures[index] = capture
                    } else {
                        box.captures.append(capture)
                    }
                }
            }
        )
        return (InboxCommitCoordinator(writer: writer, queue: access), box)
    }

    private func capture(_ text: String = "call mom") -> PendingCapture {
        PendingCapture(rawText: text, createdAt: Date(timeIntervalSince1970: 1_700_000_000), source: "widget")
    }

    // MARK: - Commit ordering

    func testCommitCreatesTaskThenClearsTheCapture() async throws {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        let mutation = try await coordinator.commit(
            InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
        )

        XCTAssertEqual(mutation, .commitCapture(captureID: pending.id, createdTaskID: taskID))
        let createdCount = await writer.created.count
        XCTAssertEqual(createdCount, 1)
        XCTAssertTrue(box.captures.isEmpty)
    }

    /// The property that matters most here: a capture is often the only copy of
    /// something the user typed once, so a failed task write must not consume it.
    func testFailedTaskWriteLeavesTheCaptureInTheQueue() async {
        let writer = SpyTaskWriter()
        await writer.setCreateResult(.failure(SpyTaskWriter.Boom()))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        do {
            _ = try await coordinator.commit(
                InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
            )
            XCTFail("expected the commit to throw")
        } catch {
            guard case InboxCommitFailure.taskWriteFailed = error else {
                return XCTFail("expected taskWriteFailed, got \(error)")
            }
        }

        XCTAssertEqual(box.captures.map(\.id), [pending.id])
    }

    func testFailedQueueFinalizationCompensatesTheCreatedTask() async {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let pending = capture()
        let queue = InboxCaptureQueueAccess(
            read: { [pending] },
            remove: { _ in throw InboxCaptureQueueFailure.writeFailed },
            restore: { _ in }
        )
        let coordinator = InboxCommitCoordinator(writer: writer, queue: queue)

        do {
            _ = try await coordinator.commit(
                InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
            )
            XCTFail("expected queue finalization to fail")
        } catch {
            guard case InboxCommitFailure.taskWriteFailed = error else {
                return XCTFail("expected taskWriteFailed, got \(error)")
            }
        }

        let deleted = await writer.deleted
        XCTAssertEqual(deleted, [taskID])
        XCTAssertEqual(queue.read(), [pending])
    }

    func testConcurrentCaptureWritesKeepEveryStableIdentityAndDeduplicateRetries() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("PendingCaptureInbox.json")
        XCTAssertNoThrow(try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        ))
        defer { try? FileManager.default.removeItem(at: directory) }

        let captures = (0..<40).map { index in
            PendingCapture(
                id: UUID(),
                rawText: "capture \(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                source: index.isMultiple(of: 2) ? "widget" : "share-extension"
            )
        }
        DispatchQueue.concurrentPerform(iterations: captures.count) { index in
            XCTAssertTrue(PendingCaptureInbox.upsert([captures[index]], at: url))
        }
        let retried = PendingCapture(
            id: captures[0].id,
            rawText: "capture 0, updated",
            createdAt: captures[0].createdAt,
            source: "app-intent"
        )
        XCTAssertTrue(PendingCaptureInbox.upsert([retried], at: url))

        let stored = PendingCaptureInbox.read(from: url)
        XCTAssertEqual(stored.count, captures.count)
        XCTAssertEqual(Set(stored.map(\.id)), Set(captures.map(\.id)))
        XCTAssertEqual(stored.first(where: { $0.id == retried.id }), retried)
    }

    /// Already committed elsewhere, or discarded on another device. Committing
    /// again would silently create a duplicate task.
    func testCommittingAnAbsentCaptureFailsRatherThanCreatingADuplicate() async {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let missing = UUID()

        do {
            _ = try await coordinator.commit(
                InboxCaptureCommitRequest(captureID: missing, title: "call mom")
            )
            XCTFail("expected the commit to throw")
        } catch {
            XCTAssertEqual(error as? InboxCommitFailure, .captureNotFound(missing))
        }
        let createdEmpty = await writer.created.isEmpty
        XCTAssertTrue(createdEmpty)
    }

    // MARK: - Undo

    func testUndoDeletesTheTaskAndRestoresTheCaptureUnchanged() async throws {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        let mutation = try await coordinator.commit(
            InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
        )
        try await coordinator.undoCommit(mutation, restoring: pending)

        let deleted = await writer.deleted
        XCTAssertEqual(deleted, [taskID])
        // Identity, text, timestamp and source all survive: a restored capture
        // must not read as a brand new one in an age-ordered Inbox.
        XCTAssertEqual(box.captures.count, 1)
        XCTAssertEqual(box.captures.first, pending)
    }

    func testUndoDoesNotRestoreTheCaptureWhenTheTaskDeleteFails() async {
        let writer = SpyTaskWriter()
        await writer.setDeleteError(SpyTaskWriter.Boom())
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [])
        let mutation = InboxTriageMutation.commitCapture(captureID: pending.id, createdTaskID: UUID())

        do {
            try await coordinator.undoCommit(mutation, restoring: pending)
            XCTFail("expected undo to throw")
        } catch {
            guard case InboxCommitFailure.taskWriteFailed = error else {
                return XCTFail("expected taskWriteFailed, got \(error)")
            }
        }
        // Otherwise the user would end up with both the task and the capture.
        XCTAssertTrue(box.captures.isEmpty)
    }

    func testPendingToPendingMergeCreatesOneTaskAndUndoRestoresBothCaptures() async throws {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let first = capture("call mom tomorrow")
        let second = capture("call mom")
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [first, second])

        let receipt = try await coordinator.merge(
            InboxCaptureCommitRequest(captureID: first.id, title: "Call Mom"),
            with: .pendingCapture(second.id)
        )

        guard case let .created(createdID, captures) = receipt else {
            return XCTFail("expected a created merge receipt")
        }
        XCTAssertEqual(createdID, taskID)
        XCTAssertEqual(Set(captures.map(\.id)), Set([first.id, second.id]))
        XCTAssertTrue(box.captures.isEmpty)

        try await coordinator.undoMerge(receipt)
        XCTAssertEqual(Set(box.captures.map(\.id)), Set([first.id, second.id]))
        let deleted = await writer.deleted
        XCTAssertEqual(deleted, [taskID])
    }

    // MARK: - Project moves

    func testMoveToProjectRecordsBeforeSoUndoIsExact() async throws {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let taskID = UUID()
        let origin = UUID()
        let destination = UUID()

        let mutation = try await coordinator.moveToProject(taskID: taskID, from: origin, to: destination)
        try await coordinator.undoMoveToProject(mutation)

        let moved = await writer.movedProjects
        XCTAssertEqual(moved, [destination, origin])
    }

    /// The regression this fixes: `after` used to be non-optional, so inverting
    /// a move for a task that had no project produced
    /// `.moveToProject(before: after, after: after)` — a no-op that left the
    /// task in the project the undo was meant to pull it out of.
    func testUndoingAMoveForATaskThatHadNoProjectRemovesItFromTheProject() async throws {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let taskID = UUID()
        let destination = UUID()

        let mutation = try await coordinator.moveToProject(taskID: taskID, from: nil, to: destination)
        try await coordinator.undoMoveToProject(mutation)

        let moved = await writer.movedProjects
        XCTAssertEqual(moved.count, 2)
        XCTAssertEqual(moved[0], destination)
        XCTAssertNil(moved[1])
    }

    func testMoveToProjectInverseRoundTrips() {
        let taskID = UUID()
        let origin = UUID()
        let destination = UUID()
        let forward = InboxTriageMutation.moveToProject(taskID: taskID, before: origin, after: destination)
        XCTAssertEqual(
            forward.inverse,
            .moveToProject(taskID: taskID, before: destination, after: origin)
        )
        XCTAssertEqual(forward.inverse.inverse, forward)
    }

    func testMoveToProjectInverseRoundTripsWithNoOriginalProject() {
        let taskID = UUID()
        let destination = UUID()
        let forward = InboxTriageMutation.moveToProject(taskID: taskID, before: nil, after: destination)
        XCTAssertEqual(forward.inverse, .moveToProject(taskID: taskID, before: destination, after: nil))
        XCTAssertEqual(forward.inverse.inverse, forward)
    }

    // MARK: - Building the request from a review

    /// The commit must carry exactly what the chips showed. Re-parsing at commit
    /// time would let a relative date resolve against a moved reference.
    func testReviewedRequestCarriesTheParsedProposalVerbatim() {
        let captureID = UUID()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let parsed = TaskCaptureParser.parse(
            "draft proposal for 90 min tomorrow 2pm +Work #writing @desk !high",
            now: reference
        )
        let request = InboxCaptureCommitRequest.reviewed(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: "raw"
        )

        XCTAssertEqual(request.title, "draft proposal")
        XCTAssertEqual(request.estimatedDuration, 90 * 60)
        XCTAssertEqual(request.projectName, "Work")
        XCTAssertEqual(request.tagNames, ["writing"])
        XCTAssertEqual(request.contextName, "desk")
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.dueDate, parsed.dueDate)
    }

    func testReviewedRequestFallsBackWhenTheParsedTitleIsEmpty() {
        let parsed = ParsedCapture(cleanTitle: "   ", dueDate: nil, isAllDay: false, matchedText: nil)
        let request = InboxCaptureCommitRequest.reviewed(
            captureID: UUID(),
            parsed: parsed,
            fallbackTitle: "tomorrow"
        )
        XCTAssertEqual(request.title, "tomorrow")
    }

    func testEditedReviewDraftIsTheOnlySourceOfTheCommitRequest() {
        let captureID = UUID()
        let parsed = TaskCaptureParser.parse(
            "draft proposal tomorrow +Work #writing @desk !high",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        var draft = InboxCaptureReviewDraft(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: "raw text that must never be reparsed"
        )
        let reviewedDate = Date(timeIntervalSince1970: 1_800_000_000)
        draft.title = "  Final reviewed title  "
        draft.dueDate = reviewedDate
        draft.isAllDay = false
        draft.estimatedDuration = 35 * 60
        draft.repeatPattern = .weekly([.monday, .thursday])
        draft.priority = .low
        draft.projectName = "  Personal "
        draft.tagNames = ["Writing", " writing ", "Deep work"]
        draft.contextName = "  home "

        XCTAssertEqual(
            draft.commitRequest,
            InboxCaptureCommitRequest(
                captureID: captureID,
                title: "Final reviewed title",
                dueDate: reviewedDate,
                isAllDay: false,
                estimatedDuration: 35 * 60,
                repeatPattern: .weekly([.monday, .thursday]),
                priority: .low,
                projectName: "Personal",
                tagNames: ["Writing", "Deep work"],
                contextName: "home"
            )
        )
    }

    func testDuplicateMergeRequiresEveryConflictingFieldToBeAcknowledged() {
        let reviewed = InboxCaptureReviewDraft(
            captureID: UUID(),
            title: "Reviewed",
            dueDate: Date(timeIntervalSince1970: 200),
            repeatPattern: .daily,
            priority: .high,
            projectName: "Personal"
        )
        let destination = InboxMergeDestinationSnapshot(
            title: "Existing",
            dueDate: Date(timeIntervalSince1970: 100),
            repeatPattern: .weekly(.friday),
            priority: .low,
            projectName: "Work"
        )
        let conflicts = DuplicateMergeResolution(
            finalTitle: "Final",
            choices: [.date: .destination]
        )

        XCTAssertEqual(conflicts.conflicts(reviewed: reviewed, destination: destination), [
            .date, .project, .priority, .recurrence
        ])
        XCTAssertFalse(conflicts.isComplete(reviewed: reviewed, destination: destination))
        XCTAssertNil(conflicts.commitRequest(reviewed: reviewed, destination: destination))
    }

    func testDuplicateMergeUsesExplicitSourcesAndUnionsTags() throws {
        let reviewedDate = Date(timeIntervalSince1970: 200)
        let destinationDate = Date(timeIntervalSince1970: 100)
        let reviewed = InboxCaptureReviewDraft(
            captureID: UUID(),
            title: "Reviewed",
            dueDate: reviewedDate,
            isAllDay: false,
            estimatedDuration: 20 * 60,
            repeatPattern: .daily,
            priority: .high,
            projectName: "Personal",
            tagNames: ["Writing", "Home"],
            contextName: "home"
        )
        let destination = InboxMergeDestinationSnapshot(
            title: "Existing",
            dueDate: destinationDate,
            isAllDay: true,
            estimatedDuration: 45 * 60,
            repeatPattern: .weekly(.friday),
            priority: .low,
            projectName: "Work",
            tagNames: ["writing", "Deep"],
            contextName: "office"
        )
        let resolution = DuplicateMergeResolution(
            finalTitle: "  Final title ",
            choices: [
                .date: .reviewed,
                .project: .destination,
                .priority: .reviewed,
                .recurrence: .destination
            ],
            acknowledgedFields: [.date, .project, .priority, .recurrence]
        )

        let request = try XCTUnwrap(
            resolution.commitRequest(reviewed: reviewed, destination: destination)
        )
        XCTAssertEqual(request.title, "Final title")
        XCTAssertEqual(request.dueDate, reviewedDate)
        XCTAssertFalse(request.isAllDay)
        XCTAssertEqual(request.estimatedDuration, 45 * 60)
        XCTAssertEqual(request.repeatPattern, .weekly(.friday))
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.projectName, "Work")
        XCTAssertEqual(request.tagNames, ["writing", "Deep", "Home"])
        XCTAssertEqual(request.contextName, "office")
    }

    func testLegacyPendingCaptureJSONDecodesWithNewOptionalShareFields() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "rawText": "Save this",
          "createdAt": 0,
          "source": "widget"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let capture = try decoder.decode(PendingCapture.self, from: Data(json.utf8))
        XCTAssertEqual(capture.id, id)
        XCTAssertNil(capture.sharedURL)
        XCTAssertNil(capture.sourceTitle)
        XCTAssertNil(capture.provisionalAt)
    }

    func testRecurrenceRuleDecodesLegacyPatternAsScheduledDateAnchor() throws {
        let legacy = try JSONEncoder().encode(TaskRepeatPattern.daily)
        let decodedLegacy = try JSONDecoder().decode(TaskRepeatPattern.self, from: legacy)
        let rule = TaskRecurrenceRule(pattern: decodedLegacy)
        XCTAssertEqual(rule.anchor, .scheduledDate)

        let newData = try JSONEncoder().encode(
            TaskRecurrenceRule(pattern: .daily, anchor: .completionDate)
        )
        let decoded = try JSONDecoder().decode(TaskRecurrenceRule.self, from: newData)
        XCTAssertEqual(decoded.anchor, .completionDate)
        XCTAssertEqual(decoded.pattern, .daily)
    }
}
