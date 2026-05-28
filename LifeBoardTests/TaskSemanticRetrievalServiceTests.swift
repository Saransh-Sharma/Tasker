import XCTest
@testable import LifeBoard

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

    func testIndexIncludesTagNamesWhenLookupProvided() {
        let service = makeService { text in
            text.lowercased().contains("urgent") ? [1.0, 0.0] : [0.0, 1.0]
        }

        let tagID = UUID()
        var task = TaskDefinition(title: "Prepare deck")
        task.tagIDs = [tagID]

        service.index(tasks: [task], tagNameLookup: [tagID: "Urgent"])

        let result = service.searchDetailed(query: "urgent", topK: 3)
        XCTAssertEqual(result.hits.first?.taskID, task.id)
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

    func testConcurrentIndexAndSearchUseSynchronizedState() {
        let service = makeService { text in
            text.lowercased().contains("alpha") ? [1.0, 0.0] : [0.0, 1.0]
        }

        let tasks = (0..<50).map { index in
            TaskDefinition(title: "Alpha task \(index)")
        }

        DispatchQueue.concurrentPerform(iterations: tasks.count) { index in
            service.index(tasks: [tasks[index]])
            _ = service.search(query: "alpha", topK: 5)
        }

        let hits = service.search(query: "alpha", topK: tasks.count)
        XCTAssertEqual(Set(hits.map(\.taskID)), Set(tasks.map(\.id)))
    }

    func testCleanActiveSemanticIndexCanBeReleasedForBackgrounding() async {
        let service = makeService { _ in [1.0, 0.0] }
        service.rebuildIndex(tasks: [TaskDefinition(title: "Plan tomorrow")])
        service.persistIndex()

        await service.activateIfNeeded {}

        XCTAssertTrue(service.isActivated)
        XCTAssertFalse(service.shouldPersistOnBackgroundTransition)

        service.releaseInMemoryResources()

        XCTAssertFalse(service.isActivated)
        XCTAssertFalse(service.shouldPersistOnBackgroundTransition)
    }

    func testPersistedSemanticIndexLoadsIntoFreshStore() {
        let fileName = "task-semantic-persisted-\(UUID().uuidString).bin"
        removeSemanticIndexFile(named: fileName)
        defer { removeSemanticIndexFile(named: fileName) }

        let taskID = UUID()
        let writer = TaskSemanticIndexStore(fileName: fileName)
        writer.upsert(taskID: taskID, text: "Book doctor", vector: [1.0, 0.0])
        writer.persist()

        let reader = TaskSemanticIndexStore(fileName: fileName)
        let snapshot = reader.snapshot()

        XCTAssertEqual(snapshot.map(\.taskID), [taskID])
        XCTAssertEqual(snapshot.first?.text, "Book doctor")
        XCTAssertEqual(snapshot.first?.vector, [1.0, 0.0])
    }

    func testFirstLoadConcurrentUpsertPreservesNewerWrite() {
        let fileName = "task-semantic-upsert-race-\(UUID().uuidString).bin"
        removeSemanticIndexFile(named: fileName)
        defer { removeSemanticIndexFile(named: fileName) }

        let persistedID = UUID()
        let newID = UUID()
        let writer = TaskSemanticIndexStore(fileName: fileName)
        writer.upsert(taskID: persistedID, text: "Persisted", vector: [1.0, 0.0])
        writer.persist()

        let store = TaskSemanticIndexStore(fileName: fileName)
        DispatchQueue.concurrentPerform(iterations: 2) { index in
            if index == 0 {
                _ = store.snapshot()
            } else {
                store.upsert(taskID: newID, text: "New", vector: [0.0, 1.0])
            }
        }

        let taskIDs = Set(store.snapshot().map(\.taskID))
        XCTAssertEqual(taskIDs, [persistedID, newID])
    }

    func testFirstLoadConcurrentRemoveDoesNotResurrectPersistedItem() {
        let fileName = "task-semantic-remove-race-\(UUID().uuidString).bin"
        removeSemanticIndexFile(named: fileName)
        defer { removeSemanticIndexFile(named: fileName) }

        let removedID = UUID()
        let keptID = UUID()
        let writer = TaskSemanticIndexStore(fileName: fileName)
        writer.upsert(taskID: removedID, text: "Remove", vector: [1.0, 0.0])
        writer.upsert(taskID: keptID, text: "Keep", vector: [0.0, 1.0])
        writer.persist()

        let store = TaskSemanticIndexStore(fileName: fileName)
        DispatchQueue.concurrentPerform(iterations: 2) { index in
            if index == 0 {
                _ = store.snapshot()
            } else {
                store.remove(taskID: removedID)
            }
        }

        let taskIDs = Set(store.snapshot().map(\.taskID))
        XCTAssertEqual(taskIDs, [keptID])
    }

    func testCosineSimilarityIsDeterministic() {
        let similarity = TaskEmbeddingEngine.cosineSimilarity([1, 2, 3], [1, 2, 3])
        let orthogonal = TaskEmbeddingEngine.cosineSimilarity([1, 0], [0, 1])

        XCTAssertEqual(similarity, 1.0, accuracy: 0.000_01)
        XCTAssertEqual(orthogonal, 0.0, accuracy: 0.000_01)
    }

    private func makeService(
        vectorProvider: @escaping TaskEmbeddingEngine.VectorProvider
    ) -> TaskSemanticRetrievalService {
        TaskSemanticRetrievalService(
            embeddingEngine: TaskEmbeddingEngine(vectorProvider: vectorProvider),
            indexStore: TaskSemanticIndexStore(fileName: "task-semantic-test-\(UUID().uuidString).bin")
        )
    }

    private func removeSemanticIndexFile(named fileName: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(fileName))
    }
}
