import Foundation

public enum JournalMediaKind: String, Codable, Sendable {
    case photo
    case audio
}

public enum JournalMediaSyncPolicy: String, Codable, Sendable {
    case privateCloud
    case protectedLocalOnly
}

public struct JournalMediaAttachment: Identifiable, Codable, Hashable, Sendable {
    public enum ProcessingState: String, Codable, CaseIterable, Sendable {
        case queued
        case ready
        case transcribing
        case transcriptionComplete
        case transcriptionFailed
        case manualTranscription
        case discarded
        case missing
    }

    public let id: UUID
    public var kind: JournalMediaKind
    public var localRelativePath: String?
    public var duration: TimeInterval?
    public var transcription: String?
    public var processingState: ProcessingState
    public var syncPolicy: JournalMediaSyncPolicy
    public var createdAt: Date

    public init(
        id: UUID,
        kind: JournalMediaKind,
        localRelativePath: String?,
        duration: TimeInterval?,
        transcription: String? = nil,
        processingState: ProcessingState = .ready,
        syncPolicy: JournalMediaSyncPolicy,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.localRelativePath = localRelativePath
        self.duration = duration
        self.transcription = transcription
        self.processingState = processingState
        self.syncPolicy = syncPolicy
        self.createdAt = createdAt
    }
}

public struct JournalEntrySnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var title: String?
    public var text: String
    public var mood: JournalMood?
    public var energy: Int?
    public var isStarred: Bool
    public var attachments: [JournalMediaAttachment]
    public var updatedAt: Date
    /// Per-entry AI participation, carried into every derived surface.
    public var aiExclusion: JournalAIExclusion

    public init(
        id: UUID,
        date: Date,
        title: String?,
        text: String,
        mood: JournalMood?,
        energy: Int?,
        isStarred: Bool,
        attachments: [JournalMediaAttachment],
        updatedAt: Date,
        aiExclusion: JournalAIExclusion = .included
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.text = text
        self.mood = mood
        self.energy = energy
        self.isStarred = isStarred
        self.attachments = attachments
        self.updatedAt = updatedAt
        self.aiExclusion = aiExclusion
    }

    /// Derived payloads written before the AI-exclusion contract decode as
    /// `.included`; the derived index is rebuildable regardless.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            date: try container.decode(Date.self, forKey: .date),
            title: try container.decodeIfPresent(String.self, forKey: .title),
            text: try container.decode(String.self, forKey: .text),
            mood: try container.decodeIfPresent(JournalMood.self, forKey: .mood),
            energy: try container.decodeIfPresent(Int.self, forKey: .energy),
            isStarred: try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false,
            attachments: try container.decodeIfPresent([JournalMediaAttachment].self, forKey: .attachments) ?? [],
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            aiExclusion: try container.decodeIfPresent(JournalAIExclusion.self, forKey: .aiExclusion) ?? .included
        )
    }
}

public struct JournalEvidenceReference: Identifiable, Codable, Hashable, Sendable {
    public enum MatchReason: String, Codable, CaseIterable, Sendable {
        case exact
        case meaning
        case topic
        case recent
    }

    public let id: String
    public var entryID: UUID
    public var date: Date
    public var snippet: String
    public var score: Double
    public var matchReason: MatchReason

    public init(
        id: String,
        entryID: UUID,
        date: Date,
        snippet: String,
        score: Double,
        matchReason: MatchReason
    ) {
        self.id = id
        self.entryID = entryID
        self.date = date
        self.snippet = snippet
        self.score = min(1, max(0, score))
        self.matchReason = matchReason
    }
}

public enum JournalSearchState: Equatable, Sendable {
    case idle
    case searching
    case building(progress: Double, message: String)
    case ready([JournalEvidenceReference])
    case unavailable(String)
    case failed(String)
}

public protocol JournalDerivedIndexRepository: Sendable {
    func rebuild(entries: [JournalEntrySnapshot]) async throws
    func upsert(entry: JournalEntrySnapshot) async throws
    func remove(entryID: UUID) async throws
    func search(query: String, limit: Int) async throws -> [JournalEvidenceReference]
    func invalidate() async throws
}
