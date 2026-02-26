import Foundation
import NaturalLanguage

struct TaskEmbeddingEngine {
    typealias VectorProvider = (String) -> [Double]?

    private let vectorProvider: VectorProvider

    /// Initializes a new instance.
    init(vectorProvider: VectorProvider? = nil) {
        if let vectorProvider {
            self.vectorProvider = vectorProvider
            return
        }
        self.vectorProvider = { text in
            NLEmbedding.sentenceEmbedding(for: .english)?.vector(for: text)
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
