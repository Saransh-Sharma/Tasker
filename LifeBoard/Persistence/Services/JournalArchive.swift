import LifeBoardContracts
import LifeBoardDomain
import CryptoKit
import Foundation
import LifeBoardDomain
import LifeBoardDomain

public enum JournalArchiveConflictPolicy: String, Codable, CaseIterable, Sendable {
    case keepExisting
    case replaceExisting
    case keepNewest
}

public struct JournalArchiveManifest: Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var createdAt: Date
    public var timezoneIdentifier: String
    public var contentChecksum: String
    public var entryCount: Int
    public var attachmentCount: Int
    public var mediaPayloadCount: Int

    public init(
        schemaVersion: Int = currentSchemaVersion,
        createdAt: Date,
        timezoneIdentifier: String,
        contentChecksum: String,
        entryCount: Int,
        attachmentCount: Int,
        mediaPayloadCount: Int
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.timezoneIdentifier = timezoneIdentifier
        self.contentChecksum = contentChecksum
        self.entryCount = entryCount
        self.attachmentCount = attachmentCount
        self.mediaPayloadCount = mediaPayloadCount
    }
}

public struct JournalArchiveContent: Hashable, Codable, Sendable {
    public var entries: [JournalSnapshot]
    public var attachments: [JournalAttachmentSnapshot]
    public var savedInsights: [SavedInsight]
    public var weeklyReflections: [WeeklyReflectionReport]
    public var mediaPayloads: [UUID: Data]

    public init(
        entries: [JournalSnapshot],
        attachments: [JournalAttachmentSnapshot] = [],
        savedInsights: [SavedInsight] = [],
        weeklyReflections: [WeeklyReflectionReport] = [],
        mediaPayloads: [UUID: Data] = [:]
    ) {
        self.entries = entries
        self.attachments = attachments
        self.savedInsights = savedInsights
        self.weeklyReflections = weeklyReflections
        self.mediaPayloads = mediaPayloads
    }
}

public struct JournalArchiveEnvelope: Hashable, Codable, Sendable {
    public var manifest: JournalArchiveManifest
    public var content: JournalArchiveContent

    public init(manifest: JournalArchiveManifest, content: JournalArchiveContent) {
        self.manifest = manifest
        self.content = content
    }
}

public struct JournalRestorePreview: Hashable, Codable, Sendable {
    public var entriesToInsert: Int
    public var entriesToReplace: Int
    public var entriesToSkip: Int
    public var missingAttachmentIDs: [UUID]
    public var schemaVersion: Int

    public init(
        entriesToInsert: Int,
        entriesToReplace: Int,
        entriesToSkip: Int,
        missingAttachmentIDs: [UUID],
        schemaVersion: Int
    ) {
        self.entriesToInsert = entriesToInsert
        self.entriesToReplace = entriesToReplace
        self.entriesToSkip = entriesToSkip
        self.missingAttachmentIDs = missingAttachmentIDs
        self.schemaVersion = schemaVersion
    }
}

public enum JournalArchiveError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case integrityMismatch
    case invalidArchive

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This backup uses unsupported schema version \(version)."
        case .integrityMismatch:
            return "The backup failed its integrity check."
        case .invalidArchive:
            return "This file is not a valid journal archive."
        }
    }
}

public enum JournalArchiveCodec {
    public static func seal(
        _ content: JournalArchiveContent,
        password: String,
        createdAt: Date = Date(),
        timezone: TimeZone = .current
    ) throws -> Data {
        let contentData = try encoder.encode(content)
        let manifest = JournalArchiveManifest(
            createdAt: createdAt,
            timezoneIdentifier: timezone.identifier,
            contentChecksum: checksum(contentData),
            entryCount: content.entries.count,
            attachmentCount: content.attachments.count,
            mediaPayloadCount: content.mediaPayloads.count
        )
        let payload = try encoder.encode(JournalArchiveEnvelope(manifest: manifest, content: content))
        return try EncryptionService.encrypt(data: payload, password: password)
    }

    public static func open(_ encryptedData: Data, password: String) throws -> JournalArchiveEnvelope {
        let decrypted = try EncryptionService.decrypt(data: encryptedData, password: password)
        guard let envelope = try? decoder.decode(JournalArchiveEnvelope.self, from: decrypted) else {
            throw JournalArchiveError.invalidArchive
        }
        guard envelope.manifest.schemaVersion == JournalArchiveManifest.currentSchemaVersion else {
            throw JournalArchiveError.unsupportedSchema(envelope.manifest.schemaVersion)
        }
        let contentData = try encoder.encode(envelope.content)
        guard checksum(contentData) == envelope.manifest.contentChecksum else {
            throw JournalArchiveError.integrityMismatch
        }
        return envelope
    }

    public static func preview(
        _ envelope: JournalArchiveEnvelope,
        existingEntries: [UUID: Date],
        conflictPolicy: JournalArchiveConflictPolicy
    ) -> JournalRestorePreview {
        var inserts = 0
        var replacements = 0
        var skips = 0

        for entry in envelope.content.entries {
            guard let existingUpdatedAt = existingEntries[entry.id] else {
                inserts += 1
                continue
            }
            switch conflictPolicy {
            case .keepExisting:
                skips += 1
            case .replaceExisting:
                replacements += 1
            case .keepNewest:
                if entry.updatedAt > existingUpdatedAt { replacements += 1 } else { skips += 1 }
            }
        }

        let missing = envelope.content.attachments.compactMap { attachment -> UUID? in
            guard attachment.availability == .locallyAvailable || attachment.availability == .restored else { return nil }
            return envelope.content.mediaPayloads[attachment.id] == nil ? attachment.id : nil
        }.sorted { $0.uuidString < $1.uuidString }

        return JournalRestorePreview(
            entriesToInsert: inserts,
            entriesToReplace: replacements,
            entriesToSkip: skips,
            missingAttachmentIDs: missing,
            schemaVersion: envelope.manifest.schemaVersion
        )
    }

    private static let encoder: JSONEncoder = {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .millisecondsSince1970
        value.outputFormatting = [.sortedKeys]
        return value
    }()

    private static let decoder: JSONDecoder = {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .millisecondsSince1970
        return value
    }()

    private static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
