//
//  SemanticJournalDerivedIndexRepository.swift
//  LifeBoard
//
//  Phase V journal parity: journal search backed by the shared
//  SemanticMemoryKit hybrid engine (sentence embeddings + FTS lexical
//  fusion), replacing the purely lexical derived index when
//  `journalParityV1Enabled` is on.
//
//  Privacy: the SQLite sidecar lives in local Application Support, is never
//  synced, and is rebuilt per device. Entries whose `aiExclusion` forbids
//  semantic indexing are never ingested; changing an entry's exclusion
//  evicts it on the next upsert.
//

import Foundation
import JournalFoundation
import SemanticMemoryKit

public final class SemanticJournalDerivedIndexRepository: JournalDerivedIndexRepository, @unchecked Sendable {

    public typealias SnapshotProvider = @Sendable () async throws -> [JournalEntrySnapshot]

    private let worker: SemanticMemoryIndexActor
    private let snapshotProvider: SnapshotProvider

    /// Default sidecar location: local Application Support, LocalOnly
    /// doctrine (rebuildable, never synced, protected by file protection).
    public static var defaultStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("LifeBoardJournalIndex", isDirectory: true)
            .appendingPathComponent("semantic-memory.sqlite")
    }

    public init(
        storeURL: URL = SemanticJournalDerivedIndexRepository.defaultStoreURL,
        snapshotProvider: @escaping SnapshotProvider
    ) {
        self.worker = SemanticMemoryIndexActor(storeURL: storeURL)
        self.snapshotProvider = snapshotProvider
    }

    // MARK: Exclusion gate

    /// The single ingest gate: entries that do not permit semantic indexing
    /// never become records.
    static func indexableRecord(_ snapshot: JournalEntrySnapshot) -> IndexableEntry? {
        guard snapshot.aiExclusion.permitsSemanticIndexing else { return nil }
        let text = snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return IndexableEntry(
            id: snapshot.id,
            date: snapshot.date,
            mood: snapshot.mood?.rawValue,
            text: text,
            isStarred: snapshot.isStarred,
            updatedAt: snapshot.updatedAt
        )
    }

    // MARK: JournalDerivedIndexRepository

    public func rebuild(entries: [JournalEntrySnapshot]) async throws {
        let records = entries.compactMap(Self.indexableRecord)
        _ = try await worker.rebuildAll(records: records) { _ in }
    }

    public func upsert(entry: JournalEntrySnapshot) async throws {
        if let record = Self.indexableRecord(entry) {
            _ = try await worker.upsertEntry(record)
        } else {
            // Excluded (or emptied) entries are evicted immediately.
            _ = try await worker.deleteEntry(id: entry.id)
        }
    }

    public func remove(entryID: UUID) async throws {
        _ = try await worker.deleteEntry(id: entryID)
    }

    public func search(query: String, limit: Int) async throws -> [JournalEvidenceReference] {
        _ = try? await worker.load()
        let snapshots = try await snapshotProvider()
        let records = snapshots.compactMap(Self.indexableRecord)

        if await worker.needsRebuild(records: records, forceRemoteReconcile: false) {
            _ = try await worker.rebuildAll(records: records) { _ in }
        }

        let result = await worker.search(query: query, records: records, limit: limit)
        switch result {
        case .ready(let evidence):
            return evidence.map(Self.journalReference)
        case .building:
            return []
        case .unavailable(let message), .failed(let message):
            throw SemanticJournalIndexError.unavailable(message)
        }
    }

    public func invalidate() async throws {
        try await worker.deleteAll()
    }

    // MARK: Mapping

    private static func journalReference(_ evidence: SemanticMemoryKit.EvidenceReference) -> JournalEvidenceReference {
        let reason: JournalEvidenceReference.MatchReason
        switch evidence.matchReason {
        case .exact: reason = .exact
        case .meaning: reason = .meaning
        case .entity: reason = .topic
        case .recent: reason = .recent
        }
        return JournalEvidenceReference(
            id: evidence.id,
            entryID: evidence.entryID,
            date: evidence.date,
            snippet: evidence.snippet,
            // RRF scores live around ~0.02–0.04; scale into the 0…1 band the
            // journal UI expects while preserving ordering.
            score: min(1, evidence.score * 24),
            matchReason: reason
        )
    }
}

public enum SemanticJournalIndexError: LocalizedError {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        }
    }
}
