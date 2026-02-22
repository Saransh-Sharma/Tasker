import XCTest
@testable import To_Do_List

final class TaskSemanticRetrievalServiceTests: XCTestCase {
    func testSearchReturnsSemanticHitsForAmbiguousQuery() {
        let service = makeService { text in
            let lower = text.lowercased()
            if lower.contains("doctor") || lower.contains("medical") {
                return [1.0, 0.0, 0.0]
            }
            if lower.contains("finance") || lower.contains("budget") {
                return [0.0, 1.0, 0.0]
            }
            if lower.contains("doctor stuff") {
                return [1.0, 0.0, 0.0]
            }
            return [0.0, 0.0, 1.0]
        }

        let medicalTask = TaskDefinition(title: "Book appointment", details: "medical follow-up")
        let financeTask = TaskDefinition(title: "Update budget", details: "finance review")

        service.rebuildIndex(tasks: [medicalTask, financeTask])
        let result = service.searchDetailed(query: "doctor stuff", topK: 2)

        XCTAssertNil(result.fallbackReason)
        XCTAssertEqual(result.hits.first?.taskID, medicalTask.id)
        XCTAssertGreaterThan((result.hits.first?.score ?? 0), (result.hits.last?.score ?? -1))
    }

    func testRemoveDeletesTaskFromSemanticIndex() {
        let service = makeService { text in
            text.lowercased().contains("doctor") ? [1.0, 0.0] : [0.0, 1.0]
        }

        let task = TaskDefinition(title: "Doctor call")
        service.index(tasks: [task])
        XCTAssertEqual(service.search(query: "doctor", topK: 3).map(\.taskID), [task.id])

        service.remove(taskID: task.id)
        XCTAssertTrue(service.search(query: "doctor", topK: 3).isEmpty)
    }

    func testSearchReturnsFallbackReasonWhenEmbeddingUnavailable() {
        let service = makeService { _ in nil }
        let task = TaskDefinition(title: "Anything")
        service.rebuildIndex(tasks: [task])

        let result = service.searchDetailed(query: "doctor stuff", topK: 5)

        XCTAssertTrue(result.hits.isEmpty)
        XCTAssertEqual(result.fallbackReason, "embedding_unavailable")
    }

    func testSearchReturnsFallbackReasonWhenIndexIsEmpty() {
        let service = makeService { _ in [1.0, 0.0] }

        let result = service.searchDetailed(query: "doctor stuff", topK: 5)

        XCTAssertTrue(result.hits.isEmpty)
        XCTAssertEqual(result.fallbackReason, "index_empty")
    }

    func testCosineSimilarityIsDeterministic() {
        let similarity = TaskEmbeddingEngine.cosineSimilarity([1, 2, 3], [1, 2, 3])
        let orthogonal = TaskEmbeddingEngine.cosineSimilarity([1, 0], [0, 1])

        XCTAssertEqual(similarity, 1.0, accuracy: 0.000_01)
        XCTAssertEqual(orthogonal, 0.0, accuracy: 0.000_01)
    }

    func testIndexMetadataPersistsAcrossStoreReload() {
        let fileName = "task-semantic-metadata-\(UUID().uuidString).bin"
        let firstService = TaskSemanticRetrievalService(
            embeddingEngine: TaskEmbeddingEngine(vectorProvider: { _ in [1.0, 0.0] }),
            indexStore: TaskSemanticIndexStore(fileName: fileName)
        )
        firstService.rebuildIndex(tasks: [TaskDefinition(title: "Doctor call")])
        firstService.persistIndex()

        let firstMetadata = firstService.indexMetadata()
        XCTAssertEqual(firstMetadata.taskCount, 1)
        XCTAssertNotNil(firstMetadata.lastIndexedAt)

        let secondService = TaskSemanticRetrievalService(
            embeddingEngine: TaskEmbeddingEngine(vectorProvider: { _ in [1.0, 0.0] }),
            indexStore: TaskSemanticIndexStore(fileName: fileName)
        )
        secondService.loadPersistedIndex()

        let secondMetadata = secondService.indexMetadata()
        XCTAssertEqual(secondMetadata.taskCount, 1)
        XCTAssertNotNil(secondMetadata.lastIndexedAt)
    }

    func testRefreshCoordinatorRebuildsStaleIndexWithoutMainThreadBlocking() async {
        let vectorProvider: TaskEmbeddingEngine.VectorProvider = { text in
            text.lowercased().contains("doctor") ? [1.0, 0.0] : [0.0, 1.0]
        }
        let service = makeService(vectorProvider: vectorProvider)
        let task = TaskDefinition(
            title: "Doctor call",
            updatedAt: Date().addingTimeInterval(3_600)
        )
        let repository = SemanticReadModelStub(tasks: [task], latestUpdatedAt: task.updatedAt)
        let coordinator = TaskSemanticIndexRefreshCoordinator(
            semanticService: service,
            debounceNanoseconds: 0
        )
        await coordinator.configure(taskReadModelRepository: repository, tagRepository: nil)

        let didRefresh = await coordinator.refreshIfStaleNow(reason: "unit_test")

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(service.search(query: "doctor", topK: 1).first?.taskID, task.id)
    }

    private func makeService(
        vectorProvider: @escaping TaskEmbeddingEngine.VectorProvider
    ) -> TaskSemanticRetrievalService {
        TaskSemanticRetrievalService(
            embeddingEngine: TaskEmbeddingEngine(vectorProvider: vectorProvider),
            indexStore: TaskSemanticIndexStore(fileName: "task-semantic-test-\(UUID().uuidString).bin")
        )
    }
}

private final class SemanticReadModelStub: TaskReadModelRepositoryProtocol {
    let tasks: [TaskDefinition]
    let latestUpdatedAt: Date?

    init(tasks: [TaskDefinition], latestUpdatedAt: Date?) {
        self.tasks = tasks
        self.latestUpdatedAt = latestUpdatedAt
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(
            tasks: tasks,
            totalCount: tasks.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(
            tasks: tasks,
            totalCount: tasks.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func fetchLatestTaskUpdatedAt(completion: @escaping (Result<Date?, Error>) -> Void) {
        completion(.success(latestUpdatedAt))
    }

    func fetchProjectTaskCounts(includeCompleted: Bool, completion: @escaping (Result<[UUID : Int], Error>) -> Void) {
        completion(.success([:]))
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }
}
