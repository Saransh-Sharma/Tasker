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
        let hits = service.search(query: "doctor stuff", topK: 2)

        XCTAssertEqual(hits.first?.taskID, medicalTask.id)
        XCTAssertGreaterThan((hits.first?.score ?? 0), (hits.last?.score ?? -1))
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

    func testSearchReturnsEmptyWhenEmbeddingUnavailable() {
        let service = makeService { _ in nil }
        let task = TaskDefinition(title: "Anything")
        service.rebuildIndex(tasks: [task])

        XCTAssertTrue(service.search(query: "doctor stuff", topK: 5).isEmpty)
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
}
