import Foundation
 import NaturalLanguage

private final class TaskEmbeddingVectorBox: NSObject {
    let vector: [Double]

    init(vector: [Double]) {
        self.vector = vector
    }
}

private final class TaskEmbeddingStorage: @unchecked Sendable {
    private let lock = NSLock()
    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private let vectorCache: NSCache<NSString, TaskEmbeddingVectorBox> = {
        let cache = NSCache<NSString, TaskEmbeddingVectorBox>()
        cache.countLimit = 512
        return cache
    }()

    func vector(for text: String) -> [Double]? {
        let key = text as NSString
        lock.lock()
        if let cached = vectorCache.object(forKey: key) {
            lock.unlock()
            return cached.vector
        }
        let vector = sentenceEmbedding?.vector(for: text)
        if let vector {
            vectorCache.setObject(TaskEmbeddingVectorBox(vector: vector), forKey: key)
        }
        lock.unlock()
        return vector
    }
}

struct TaskEmbeddingEngine {
    typealias VectorProvider = (String) -> [Double]?

    private static let storage = TaskEmbeddingStorage()

    private let vectorProvider: VectorProvider

    /// Initializes a new instance.
    init(vectorProvider: VectorProvider? = nil) {
        if let vectorProvider {
            self.vectorProvider = vectorProvider
            return
        }
        self.vectorProvider = { text in
            Self.storage.vector(for: text)
        }
    }

    /// Executes vector.
    func vector(for text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return vectorProvider(trimmed)
    }

    /// Executes cosineSimilarity.
    static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, lhs.isEmpty == false else { return 0 }

        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for index in lhs.indices {
            let a = lhs[index]
            let b = rhs[index]
            dot += a * b
            normA += a * a
            normB += b * b
        }

        guard normA > 0, normB > 0 else { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }
}
