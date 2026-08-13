import Foundation

/// Domains that may publish a display-only projection into the LifeBoard app
/// group. Extensions never use these values to infer or mutate canonical data.
public enum SystemSurfaceDomain: String, Codable, CaseIterable, Hashable, Sendable {
    case journal
    case fasting
    case nutrition
    case wellness
    case lifeMoments
    case goals
    case routines
}

/// A transport-safe privacy classification shared by the app, widgets, and
/// Watch. It intentionally does not depend on the app's domain model module.
public enum SystemSurfaceSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case privateSensitive
    case privateStandard
    case shareEligible
}

/// A deliberately small, display-ready projection. It contains no canonical
/// model blobs, repository identifiers, source text, or free-form private notes.
public struct SystemSurfaceSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let primaryValue: String
    public let secondaryValue: String?
    public let systemImage: String
    public let sensitivity: SystemSurfaceSensitivity
    public let isExplicitlyAuthorized: Bool
    public let deepLinkPath: String?
    public let updatedAt: Date

    public init(
        id: UUID,
        title: String,
        primaryValue: String,
        secondaryValue: String? = nil,
        systemImage: String,
        sensitivity: SystemSurfaceSensitivity,
        isExplicitlyAuthorized: Bool,
        deepLinkPath: String? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.systemImage = systemImage
        self.sensitivity = sensitivity
        self.isExplicitlyAuthorized = isExplicitlyAuthorized
        self.deepLinkPath = deepLinkPath
        self.updatedAt = updatedAt
    }

    public var redactedForExternalDisplay: Self {
        guard sensitivity == .shareEligible || isExplicitlyAuthorized else {
            return .init(
                id: id,
                title: "LifeBoard",
                primaryValue: "Open LifeBoard to view",
                systemImage: systemImage,
                sensitivity: sensitivity,
                isExplicitlyAuthorized: false,
                deepLinkPath: deepLinkPath,
                updatedAt: updatedAt
            )
        }
        return self
    }
}

public struct SystemSnapshotEnvelope: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let domain: SystemSurfaceDomain
    public let generatedAt: Date
    public let snapshots: [SystemSurfaceSnapshot]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        domain: SystemSurfaceDomain,
        generatedAt: Date = Date(),
        snapshots: [SystemSurfaceSnapshot]
    ) {
        self.schemaVersion = schemaVersion
        self.domain = domain
        self.generatedAt = generatedAt
        var newestByID: [UUID: SystemSurfaceSnapshot] = [:]
        for snapshot in snapshots.map(\.redactedForExternalDisplay) {
            guard let existing = newestByID[snapshot.id] else {
                newestByID[snapshot.id] = snapshot
                continue
            }
            if snapshot.updatedAt > existing.updatedAt
                || (snapshot.updatedAt == existing.updatedAt && snapshot.title < existing.title) {
                newestByID[snapshot.id] = snapshot
            }
        }
        self.snapshots = newestByID.values.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

public enum SystemSnapshotStoreError: LocalizedError, Equatable, Sendable {
    case incompatibleSchema(found: Int, supported: Int)
    case domainMismatch
    case unreadablePrimaryAndBackup

    public var errorDescription: String? {
        switch self {
        case .incompatibleSchema:
            "This LifeBoard snapshot was created by an incompatible app version."
        case .domainMismatch:
            "The system snapshot did not match the requested LifeBoard area."
        case .unreadablePrimaryAndBackup:
            "LifeBoard could not recover the system snapshot."
        }
    }
}

public enum SystemSnapshotLocation {
    public static var directoryURL: URL? {
        AppGroupConstants.containerURL?
            .appendingPathComponent("SystemSurfaceSnapshots", isDirectory: true)
    }

    public static func primaryURL(for domain: SystemSurfaceDomain) -> URL? {
        directoryURL?.appendingPathComponent(
            "lifeboard-\(domain.rawValue)-snapshot-v1.json",
            isDirectory: false
        )
    }

    public static func backupURL(for domain: SystemSurfaceDomain) -> URL? {
        directoryURL?.appendingPathComponent(
            "lifeboard-\(domain.rawValue)-snapshot-v1.backup.json",
            isDirectory: false
        )
    }
}

/// Read-only extension entry point. It validates schema and domain, then falls
/// back to the last known-good envelope when an interrupted app write leaves a
/// corrupt primary file. Extensions still never open LifeBoard's main store.
public enum SystemSnapshotReader {
    public static func load(
        _ domain: SystemSurfaceDomain,
        fileManager: FileManager = .default
    ) throws -> SystemSnapshotEnvelope? {
        guard
            let primary = SystemSnapshotLocation.primaryURL(for: domain),
            let backup = SystemSnapshotLocation.backupURL(for: domain)
        else { return nil }

        guard fileManager.fileExists(atPath: primary.path)
                || fileManager.fileExists(atPath: backup.path)
        else { return nil }

        if let envelope = try? decode(primary, expectedDomain: domain) {
            return envelope
        }
        if let envelope = try? decode(backup, expectedDomain: domain) {
            return envelope
        }
        throw SystemSnapshotStoreError.unreadablePrimaryAndBackup
    }

    public static func decode(
        _ data: Data,
        expectedDomain: SystemSurfaceDomain
    ) throws -> SystemSnapshotEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let envelope = try decoder.decode(SystemSnapshotEnvelope.self, from: data)
        try validate(envelope, expectedDomain: expectedDomain)
        return envelope
    }

    private static func decode(
        _ url: URL,
        expectedDomain: SystemSurfaceDomain
    ) throws -> SystemSnapshotEnvelope {
        try decode(Data(contentsOf: url), expectedDomain: expectedDomain)
    }

    private static func validate(
        _ envelope: SystemSnapshotEnvelope,
        expectedDomain: SystemSurfaceDomain
    ) throws {
        guard envelope.schemaVersion <= SystemSnapshotEnvelope.currentSchemaVersion else {
            throw SystemSnapshotStoreError.incompatibleSchema(
                found: envelope.schemaVersion,
                supported: SystemSnapshotEnvelope.currentSchemaVersion
            )
        }
        guard envelope.domain == expectedDomain else {
            throw SystemSnapshotStoreError.domainMismatch
        }
    }
}
