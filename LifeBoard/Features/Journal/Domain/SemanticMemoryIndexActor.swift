//
//  SemanticMemoryIndexActor.swift
//  SemanticMemoryKit
//
//  Serialized index maintenance and hybrid search over the SQLite sidecar.
//  Host apps own the store location and feed IndexableEntry values; entries
//  excluded from AI must be filtered by the caller before ingest.
//

import Foundation
import LifeBoardDomain
import NaturalLanguage
import os

private let journalSemanticMemoryLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "LifeBoard.JournalFeature",
    category: "SemanticMemory"
)

public actor SemanticMemoryIndexActor {
    private var chunks: [MemoryChunk] = []
    private let preferredProvider: any EmbeddingProvider
    private let fallbackProvider: any EmbeddingProvider
    private let store: LocalSemanticIndexStore

    /// - Parameter storeURL: host-app-owned location for the local index
    ///   sidecar (never synced; each app supplies its own directory).
    public init(
        storeURL: URL,
        preferredProvider: any EmbeddingProvider = NLSentenceEmbeddingProvider(),
        fallbackProvider: any EmbeddingProvider = UnavailableEmbeddingProvider()
    ) {
        self.preferredProvider = preferredProvider
        self.fallbackProvider = fallbackProvider
        self.store = try! LocalSemanticIndexStore(url: storeURL)
    }

    public func load() throws -> MemoryIndexSnapshot? {
        let snapshot = try store.loadChunks()
        chunks = snapshot?.chunks ?? []
        return snapshot
    }

    public func needsRebuild(records: [IndexableEntry], forceRemoteReconcile: Bool) -> Bool {
        if forceRemoteReconcile { return true }
        guard currentIndexUsesSupportedProvider else { return true }
        let expectedHashes = Dictionary(uniqueKeysWithValues: records.map { ($0.id, TextSignals.hash($0.text)) })
        let expectedIDs = Set(expectedHashes.keys)
        let indexedIDs = Set(chunks.map(\.entryID))
        guard indexedIDs == expectedIDs else { return true }
        let indexedHashes = Dictionary(grouping: chunks, by: \.entryID).mapValues { Set($0.map(\.entryTextHash)) }
        return !expectedHashes.allSatisfy { entryID, hash in
            indexedHashes[entryID]?.contains(hash) == true
        }
    }

    public func rebuildAll(records: [IndexableEntry], progress: @Sendable @escaping (SemanticIndexProgress) async -> Void) async throws -> MemoryIndexSnapshot {
        try Task.checkCancellation()
        await progress(SemanticIndexProgress(progress: 0, message: "Building semantic memory..."))
        guard !records.isEmpty else {
            try store.deleteAll()
            chunks = []
            return MemoryIndexSnapshot(
                schemaVersion: MemoryIndexSnapshot.currentSchemaVersion,
                chunkingVersion: MemoryIndexSnapshot.currentChunkingVersion,
                embeddingModelID: "",
                embeddingRevision: 0,
                embeddingDimension: 0,
                updatedAt: Date(),
                chunks: []
            )
        }

        let provider = await selectedProvider(sampleText: records.first?.text ?? "")
        journalSemanticMemoryLogger.notice(
            "Rebuilding semantic memory records=\(records.count, privacy: .public) provider=\(String(describing: type(of: provider)), privacy: .public)"
        )
        var builtChunks: [MemoryChunk] = []
        var textByChunkID: [String: String] = [:]
        let total = max(records.count, 1)

        for (entryIndex, record) in records.enumerated() {
            try Task.checkCancellation()
            if ProcessInfo.processInfo.arguments.contains("-SemanticMemorySlowIndexingUITest") {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if shouldPauseForSystemConditions {
                await progress(SemanticIndexProgress(progress: Double(entryIndex) / Double(total), message: "Semantic memory paused to save power."))
                try await Task.sleep(nanoseconds: 800_000_000)
            }

            let (entryChunks, entryTexts) = try await chunksForEntry(record, provider: provider)
            builtChunks.append(contentsOf: entryChunks)
            textByChunkID.merge(entryTexts) { _, new in new }

            await progress(SemanticIndexProgress(progress: Double(entryIndex + 1) / Double(total), message: "Indexed \(entryIndex + 1) of \(records.count) entries..."))
        }

        try store.replaceAll(chunks: builtChunks, textByChunkID: textByChunkID)
        chunks = builtChunks
        return try store.loadChunks() ?? MemoryIndexSnapshot(
            schemaVersion: MemoryIndexSnapshot.currentSchemaVersion,
            chunkingVersion: MemoryIndexSnapshot.currentChunkingVersion,
            embeddingModelID: builtChunks.first?.embeddingModelID ?? "",
            embeddingRevision: builtChunks.first?.embeddingRevision ?? 0,
            embeddingDimension: builtChunks.first?.embeddingDimension ?? 0,
            updatedAt: Date(),
            chunks: builtChunks
        )
    }

    public func upsertEntry(_ record: IndexableEntry) async throws -> MemoryIndexSnapshot {
        let provider = await selectedProvider(sampleText: record.text)
        let (entryChunks, textByChunkID) = try await chunksForEntry(record, provider: provider)
        try store.upsert(entryID: record.id, chunks: entryChunks, textByChunkID: textByChunkID)
        chunks.removeAll { $0.entryID == record.id }
        chunks.append(contentsOf: entryChunks)
        return try store.loadChunks() ?? snapshotFallback()
    }

    public func deleteEntry(id: UUID) throws -> MemoryIndexSnapshot {
        try store.deleteEntry(id)
        chunks.removeAll { $0.entryID == id }
        return try store.loadChunks() ?? snapshotFallback()
    }

    public func deleteAll() throws {
        try store.deleteAll()
        chunks = []
    }

    public func search(query: String, records: [IndexableEntry], limit: Int) async -> SemanticMemorySearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ready([]) }
        guard !chunks.isEmpty else { return .unavailable("Semantic memory is not indexed yet.") }

        let provider = providerForCurrentIndex()
        let language = NLLanguageRecognizer.dominantLanguage(for: trimmed)
        let embedded: EmbeddedText
        do {
            embedded = try await provider.embedding(for: trimmed, language: language)
        } catch {
            return .failed(error.localizedDescription)
        }

        let recordByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let lexicalIDs: [String]
        do {
            lexicalIDs = try store.lexicalSearch(query: trimmed, limit: max(limit * 3, 24))
        } catch {
            return .failed(error.localizedDescription)
        }

        let lexicalCandidateIDs = Set(lexicalIDs)
        let textByChunkID = Dictionary(uniqueKeysWithValues: chunks.compactMap { chunk -> (String, String)? in
            guard lexicalCandidateIDs.contains(chunk.id), let record = recordByID[chunk.entryID] else { return nil }
            return (chunk.id, TextSignals.slice(record.text, start: chunk.characterStart, end: chunk.characterEnd))
        })
        let lexicalHits = HybridMemorySearchService.lexicalHits(query: trimmed, chunks: chunks, textByChunkID: textByChunkID, rankedChunkIDs: lexicalIDs)
        let results = HybridMemorySearchService.search(query: trimmed, chunks: chunks, queryVector: embedded.vector, lexicalHits: lexicalHits, limit: limit)
        journalSemanticMemoryLogger.notice(
            "Search queryLength=\(trimmed.count, privacy: .public) chunks=\(self.chunks.count, privacy: .public) lexicalIDs=\(lexicalIDs.count, privacy: .public) lexicalHits=\(lexicalHits.count, privacy: .public) results=\(results.count, privacy: .public) provider=\(embedded.metadata.modelID, privacy: .public)"
        )

        let evidence = results.compactMap { result -> EvidenceReference? in
            guard let record = recordByID[result.chunk.entryID] else { return nil }
            let chunkText = TextSignals.slice(record.text, start: result.chunk.characterStart, end: result.chunk.characterEnd)
            guard !chunkText.isEmpty else { return nil }
            return EvidenceReference(
                id: result.chunk.id,
                entryID: result.chunk.entryID,
                date: result.chunk.date,
                mood: result.chunk.mood,
                snippet: TextSignals.snippet(from: chunkText, query: trimmed),
                chunkText: chunkText,
                score: result.score,
                matchReason: result.reason
            )
        }
        return .ready(evidence)
    }

    private func selectedProvider(sampleText: String) async -> any EmbeddingProvider {
        if ProcessInfo.processInfo.arguments.contains("-SemanticMemoryUseFallbackEmbeddings") {
            return fallbackProvider
        }
        guard !sampleText.isEmpty else { return fallbackProvider }
        do {
            _ = try await preferredProvider.embedding(for: sampleText, language: NLLanguageRecognizer.dominantLanguage(for: sampleText))
            journalSemanticMemoryLogger.notice("Selected sentence embedding provider for semantic memory.")
            return preferredProvider
        } catch {
            journalSemanticMemoryLogger.error("Sentence embedding provider unavailable; using lexical fallback. error=\(error.localizedDescription, privacy: .public)")
            return fallbackProvider
        }
    }

    private func providerForCurrentIndex() -> any EmbeddingProvider {
        guard let first = chunks.first else { return fallbackProvider }
        let fallbackMetadata = UnavailableEmbeddingProvider().metadata
        return first.embeddingModelID == fallbackMetadata.modelID ? fallbackProvider : preferredProvider
    }

    private func chunksForEntry(_ record: IndexableEntry, provider: any EmbeddingProvider) async throws -> ([MemoryChunk], [String: String]) {
        let drafts = MemoryChunker.chunks(for: record.text)
        var result: [MemoryChunk] = []
        var textByChunkID: [String: String] = [:]
        let entryTextHash = TextSignals.hash(record.text)

        for (chunkIndex, draft) in drafts.enumerated() {
            let language = NLLanguageRecognizer.dominantLanguage(for: draft.text)
            let embedded = try await provider.embedding(for: draft.text, language: language)
            let textHash = TextSignals.hash(draft.text)
            let chunkID = "\(record.id.uuidString)-\(chunkIndex)-\(textHash.prefix(12))"
            result.append(
                MemoryChunk(
                    id: chunkID,
                    entryID: record.id,
                    chunkIndex: chunkIndex,
                    date: record.date,
                    mood: record.mood,
                    textHash: textHash,
                    entryTextHash: entryTextHash,
                    characterStart: draft.characterStart,
                    characterEnd: draft.characterEnd,
                    entities: TextSignals.extractEntities(from: draft.text),
                    topics: TextSignals.extractTopics(from: draft.text),
                    embeddingModelID: embedded.metadata.modelID,
                    embeddingRevision: embedded.metadata.revision,
                    embeddingDimension: embedded.vector.count,
                    language: embedded.metadata.language,
                    vector: embedded.vector,
                    isStarred: record.isStarred
                )
            )
            textByChunkID[chunkID] = draft.text
        }
        return (result, textByChunkID)
    }

    private func snapshotFallback() -> MemoryIndexSnapshot {
        let first = chunks.first
        return MemoryIndexSnapshot(
            schemaVersion: MemoryIndexSnapshot.currentSchemaVersion,
            chunkingVersion: MemoryIndexSnapshot.currentChunkingVersion,
            embeddingModelID: first?.embeddingModelID ?? "",
            embeddingRevision: first?.embeddingRevision ?? 0,
            embeddingDimension: first?.embeddingDimension ?? 0,
            updatedAt: Date(),
            chunks: chunks
        )
    }

    private var shouldPauseForSystemConditions: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
    }

    private var currentIndexUsesSupportedProvider: Bool {
        chunks.allSatisfy { chunk in
            chunk.embeddingModelID.hasPrefix(NLSentenceEmbeddingProvider.modelIDPrefix)
            || chunk.embeddingModelID == UnavailableEmbeddingProvider().metadata.modelID
        }
    }
}
