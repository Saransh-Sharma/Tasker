//
//  JournalSnapshot.swift
//  JournalFoundation
//
//  Storage-agnostic journal entry values. Engines (semantic memory,
//  reflection, knowledge graph, assistant) consume these; each host app
//  adapts its own persistence (OffRecord: DiaryEntry/JournalBlock Core Data,
//  LifeBoard: LifeBoardJournalDayValue/BlockValue) behind
//  `JournalSnapshotProviding`.
//

import Foundation

/// A single content block inside a journal entry. Mirrors the multi-modal
/// block model both apps share conceptually: interleaved text, voice
/// transcripts, photos, and audio memos.
public struct JournalBlockSnapshot: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case text
        case voiceTranscript
        case photo
        case audio
        case mood
    }

    public var id: UUID
    public var kind: Kind
    /// Text content for `.text`/`.voiceTranscript` blocks; captions elsewhere.
    public var text: String?
    /// Raw mood token (e.g. "happy") — decoupled from any concrete Mood enum
    /// so JournalFoundation does not depend on mood UI packages.
    public var moodToken: String?
    /// Host-app attachment identifier for photo/audio blocks.
    public var attachmentID: UUID?
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        id: UUID,
        kind: Kind,
        text: String? = nil,
        moodToken: String? = nil,
        attachmentID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.moodToken = moodToken
        self.attachmentID = attachmentID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

/// A full journal entry as a Sendable value, decoupled from persistence.
public struct JournalSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// The journal day this entry belongs to (start-of-day semantics are the
    /// host app's responsibility; engines only order and bucket by this date).
    public var date: Date
    public var createdAt: Date
    public var updatedAt: Date
    /// Entry-level mood token, if the entry has one.
    public var moodToken: String?
    public var isStarred: Bool
    public var blocks: [JournalBlockSnapshot]
    /// Per-entry AI participation. Engines MUST honor this at ingest:
    /// semantic indexing, assistant evidence, and reflection each check the
    /// relevant permission before touching the entry.
    public var aiExclusion: JournalAIExclusion

    public init(
        id: UUID,
        date: Date,
        createdAt: Date,
        updatedAt: Date,
        moodToken: String? = nil,
        isStarred: Bool = false,
        blocks: [JournalBlockSnapshot] = [],
        aiExclusion: JournalAIExclusion = .included
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.moodToken = moodToken
        self.isStarred = isStarred
        self.blocks = blocks
        self.aiExclusion = aiExclusion
    }

    /// All readable text in block order — the canonical input for chunking,
    /// embedding, and reflection.
    public var plainText: String {
        blocks
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { block in
                guard let text = block.text, !text.isEmpty else { return nil }
                return text
            }
            .joined(separator: "\n")
    }

    public var wordCount: Int {
        plainText.split { $0.isWhitespace || $0.isNewline }.count
    }
}

/// Host-app seam: engines fetch snapshots through this, never through
/// app persistence directly.
public protocol JournalSnapshotProviding: Sendable {
    /// Snapshots whose `date` falls inside the interval, ascending by date.
    func snapshots(in interval: DateInterval) async throws -> [JournalSnapshot]
    /// A single snapshot by entry identifier.
    func snapshot(id: UUID) async throws -> JournalSnapshot?
    /// Identifiers of every entry, used for index reconciliation/eviction.
    func allSnapshotIDs() async throws -> [UUID]
}
