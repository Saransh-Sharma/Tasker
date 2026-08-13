import Foundation

public enum JournalAttachmentKind: String, Codable, CaseIterable, Sendable {
    case image
    case video
    case audio
    case document
}

public enum JournalAttachmentAvailability: String, Codable, CaseIterable, Sendable {
    case pending
    case locallyAvailable
    case unavailable
    case restored
    case deleted
    case permanentlyMissing

    public var canRetryRecovery: Bool {
        switch self {
        case .pending, .unavailable:
            return true
        case .locallyAvailable, .restored, .deleted, .permanentlyMissing:
            return false
        }
    }

    public var shouldRetainMetadata: Bool {
        self != .deleted
    }
}

public struct JournalAttachmentSnapshot: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var entryID: UUID
    public var kind: JournalAttachmentKind
    public var availability: JournalAttachmentAvailability
    public var fileName: String
    public var mimeType: String?
    public var byteCount: Int64?
    public var checksum: String?
    public var sourceCaptureID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var duration: TimeInterval?
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public init(
        id: UUID,
        entryID: UUID,
        kind: JournalAttachmentKind,
        availability: JournalAttachmentAvailability,
        fileName: String,
        mimeType: String? = nil,
        byteCount: Int64? = nil,
        checksum: String? = nil,
        sourceCaptureID: UUID? = nil,
        createdAt: Date,
        updatedAt: Date,
        duration: TimeInterval? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.id = id
        self.entryID = entryID
        self.kind = kind
        self.availability = availability
        self.fileName = fileName
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.checksum = checksum
        self.sourceCaptureID = sourceCaptureID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public protocol JournalAttachmentSnapshotProviding: Sendable {
    func attachments(entryID: UUID?) async throws -> [JournalAttachmentSnapshot]
    func attachment(id: UUID) async throws -> JournalAttachmentSnapshot?
}

public protocol JournalAttachmentPayloadProviding: Sendable {
    func payload(attachmentID: UUID) async throws -> Data?
}
