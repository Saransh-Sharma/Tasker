//
//  SemanticMemoryModels.swift
//  SemanticMemoryKit
//
//  Local-only semantic memory: evidence model, stored chunks, indexable
//  entries, and embedding providers. Derived embeddings never sync; each
//  device rebuilds them from journal entries.
//

import Foundation
import NaturalLanguage
import CryptoKit
import os
#if canImport(Accelerate)
import Accelerate
#endif

let semanticMemoryLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "SemanticMemoryKit",
    category: "SemanticMemory"
)

// MARK: - Evidence Model

public struct EvidenceReference: Identifiable, Codable, Equatable, Sendable {
    public enum MatchReason: String, Codable, Sendable {
        case meaning = "Meaning match"
        case exact = "Exact match"
        case entity = "Person or topic match"
        case recent = "Recent related entry"
    }

    public let id: String
    public let entryID: UUID
    public let date: Date
    public let mood: String?
    public let snippet: String
    public let chunkText: String
    public let score: Double
    public let matchReason: MatchReason

    public init(
        id: String,
        entryID: UUID,
        date: Date,
        mood: String?,
        snippet: String,
        chunkText: String,
        score: Double,
        matchReason: MatchReason
    ) {
        self.id = id
        self.entryID = entryID
        self.date = date
        self.mood = mood
        self.snippet = snippet
        self.chunkText = chunkText
        self.score = score
        self.matchReason = matchReason
    }
}

public struct EvidenceObservation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let evidenceIDs: [String]

    public init(text: String, evidenceIDs: [String]) {
        self.id = TextSignals.hash(text + evidenceIDs.joined()).prefix(16).description
        self.text = text
        self.evidenceIDs = evidenceIDs
    }
}

public enum SemanticMemorySearchResult: Equatable, Sendable {
    case ready([EvidenceReference])
    case building(progress: Double, message: String)
    case unavailable(String)
    case failed(String)
}

public struct SemanticIndexProgress: Sendable {
    public let progress: Double
    public let message: String

    public init(progress: Double, message: String) {
        self.progress = progress
        self.message = message
    }
}

// MARK: - Stored Index

public struct MemoryChunk: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let entryID: UUID
    public let chunkIndex: Int
    public let date: Date
    public let mood: String?
    public let textHash: String
    public let entryTextHash: String
    public let characterStart: Int
    public let characterEnd: Int
    public let entities: [String]
    public let topics: [String]
    public let embeddingModelID: String
    public let embeddingRevision: Int
    public let embeddingDimension: Int
    public let language: String
    public let vector: [Float]
    public let isStarred: Bool

    public init(
        id: String,
        entryID: UUID,
        chunkIndex: Int,
        date: Date,
        mood: String?,
        textHash: String,
        entryTextHash: String,
        characterStart: Int,
        characterEnd: Int,
        entities: [String],
        topics: [String],
        embeddingModelID: String,
        embeddingRevision: Int,
        embeddingDimension: Int,
        language: String,
        vector: [Float],
        isStarred: Bool
    ) {
        self.id = id
        self.entryID = entryID
        self.chunkIndex = chunkIndex
        self.date = date
        self.mood = mood
        self.textHash = textHash
        self.entryTextHash = entryTextHash
        self.characterStart = characterStart
        self.characterEnd = characterEnd
        self.entities = entities
        self.topics = topics
        self.embeddingModelID = embeddingModelID
        self.embeddingRevision = embeddingRevision
        self.embeddingDimension = embeddingDimension
        self.language = language
        self.vector = vector
        self.isStarred = isStarred
    }
}

public struct MemoryIndexSnapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let chunkingVersion: Int
    public let embeddingModelID: String
    public let embeddingRevision: Int
    public let embeddingDimension: Int
    public let updatedAt: Date
    public let chunks: [MemoryChunk]

    public static let currentSchemaVersion = 4
    public static let currentChunkingVersion = 2

    public init(
        schemaVersion: Int,
        chunkingVersion: Int,
        embeddingModelID: String,
        embeddingRevision: Int,
        embeddingDimension: Int,
        updatedAt: Date,
        chunks: [MemoryChunk]
    ) {
        self.schemaVersion = schemaVersion
        self.chunkingVersion = chunkingVersion
        self.embeddingModelID = embeddingModelID
        self.embeddingRevision = embeddingRevision
        self.embeddingDimension = embeddingDimension
        self.updatedAt = updatedAt
        self.chunks = chunks
    }
}

// MARK: - Entry Snapshot

public struct IndexableEntry: Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let mood: String?
    public let text: String
    public let isStarred: Bool
    public let updatedAt: Date?

    public init(id: UUID, date: Date, mood: String?, text: String, isStarred: Bool, updatedAt: Date? = nil) {
        self.id = id
        self.date = date
        self.mood = mood
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isStarred = isStarred
        self.updatedAt = updatedAt
    }
}

// MARK: - Embeddings

public struct EmbeddingMetadata: Equatable, Codable, Sendable {
    public let modelID: String
    public let revision: Int
    public let dimension: Int
    public let language: String

    public init(modelID: String, revision: Int, dimension: Int, language: String) {
        self.modelID = modelID
        self.revision = revision
        self.dimension = dimension
        self.language = language
    }
}

public struct EmbeddedText: Sendable {
    public let vector: [Float]
    public let metadata: EmbeddingMetadata

    public init(vector: [Float], metadata: EmbeddingMetadata) {
        self.vector = vector
        self.metadata = metadata
    }
}

public protocol EmbeddingProvider: Sendable {
    func embedding(for text: String, language: NLLanguage?) async throws -> EmbeddedText
}

public enum EmbeddingProviderError: LocalizedError {
    case unavailable
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Semantic embedding assets are unavailable on this device."
        case .emptyResult:
            return "The semantic embedding model returned no vectors."
        }
    }
}

public actor NLSentenceEmbeddingProvider: EmbeddingProvider {
    public static let modelIDPrefix = "apple.nl-sentence"

    private let canonicalLanguage: NLLanguage
    private var embeddings: [String: NLEmbedding] = [:]

    public init(canonicalLanguage: NLLanguage = .english) {
        self.canonicalLanguage = canonicalLanguage
    }

    public func embedding(for text: String, language: NLLanguage?) async throws -> EmbeddedText {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EmbeddingProviderError.emptyResult }

        let detectedLanguage = language ?? NLLanguageRecognizer.dominantLanguage(for: trimmed)
        let (embedding, resolvedLanguage) = try sentenceEmbedding(preferredLanguage: detectedLanguage)
        guard let vector = embedding.vector(for: trimmed), !vector.isEmpty else {
            throw EmbeddingProviderError.emptyResult
        }

        let metadata = EmbeddingMetadata(
            modelID: "\(Self.modelIDPrefix).\(resolvedLanguage.rawValue)",
            revision: embedding.revision,
            dimension: embedding.dimension,
            language: resolvedLanguage.rawValue
        )
        return EmbeddedText(vector: VectorMath.normalized(vector.map(Float.init)), metadata: metadata)
    }

    private func sentenceEmbedding(preferredLanguage: NLLanguage?) throws -> (NLEmbedding, NLLanguage) {
        var candidates = [canonicalLanguage]
        if let preferredLanguage, preferredLanguage != canonicalLanguage {
            candidates.append(preferredLanguage)
        }

        for candidate in candidates {
            let key = candidate.rawValue
            if let cached = embeddings[key] {
                return (cached, candidate)
            }
            if let embedding = NLEmbedding.sentenceEmbedding(for: candidate) {
                embeddings[key] = embedding
                semanticMemoryLogger.notice(
                    "Using sentence embedding language=\(candidate.rawValue, privacy: .public) revision=\(embedding.revision, privacy: .public) dimension=\(embedding.dimension, privacy: .public)"
                )
                return (embedding, candidate)
            }
        }

        semanticMemoryLogger.error(
            "No sentence embedding available for canonical=\(self.canonicalLanguage.rawValue, privacy: .public) detected=\(preferredLanguage?.rawValue ?? "nil", privacy: .public)"
        )
        throw EmbeddingProviderError.unavailable
    }
}

public struct UnavailableEmbeddingProvider: EmbeddingProvider {
    public let metadata = EmbeddingMetadata(modelID: "offrecord.lexical-fallback", revision: 1, dimension: 128, language: "und")

    public init() {}

    public func embedding(for text: String, language: NLLanguage?) async throws -> EmbeddedText {
        let tokens = TextSignals.tokens(in: text)
        var vector = Array(repeating: Float(0), count: metadata.dimension)
        for token in tokens {
            let digest = SHA256.hash(data: Data(token.utf8))
            let bucket = digest.withUnsafeBytes { bytes in
                let first = Int(bytes[0])
                let second = Int(bytes[1]) << 8
                return (first | second) % metadata.dimension
            }
            vector[bucket] += 1
        }
        return EmbeddedText(vector: VectorMath.normalized(vector), metadata: metadata)
    }
}

public enum VectorMath {
    public static func normalized(_ vector: [Float]) -> [Float] {
        guard !vector.isEmpty else { return vector }
        #if canImport(Accelerate)
        let magnitude = sqrt(vDSP.sumOfSquares(vector))
        guard magnitude > 0 else { return vector }
        return vDSP.divide(vector, magnitude)
        #else
        let magnitude = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
        #endif
    }

    public static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        #if canImport(Accelerate)
        return Double(vDSP.dot(lhs, rhs))
        #else
        var sum = Float(0)
        for index in lhs.indices {
            sum += lhs[index] * rhs[index]
        }
        return Double(sum)
        #endif
    }
}
