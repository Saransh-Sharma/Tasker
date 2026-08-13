import Foundation

/// Actor-isolated, atomic app-group projection storage. WidgetKit and Watch
/// renderers consume these envelopes instead of opening the main Core Data
/// stores, preserving separate rendering lifecycles and privacy boundaries.
public actor SystemSnapshotStore {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    public static func appGroup() -> SystemSnapshotStore? {
        guard let directoryURL = SystemSnapshotLocation.directoryURL else { return nil }
        return SystemSnapshotStore(directoryURL: directoryURL)
    }

    public func write(_ envelope: SystemSnapshotEnvelope) throws {
        let interval = PerformanceOperation.systemSurfaceRefresh.begin()
        defer { PerformanceOperation.systemSurfaceRefresh.end(interval) }
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let primary = primaryURL(for: envelope.domain)
        let backup = backupURL(for: envelope.domain)
        if fileManager.fileExists(atPath: primary.path) {
            if fileManager.fileExists(atPath: backup.path) {
                try fileManager.removeItem(at: backup)
            }
            try fileManager.copyItem(at: primary, to: backup)
        }
        try encoder.encode(envelope).write(to: primary, options: [.atomic, .completeFileProtection])
    }

    public func load(_ domain: SystemSurfaceDomain) throws -> SystemSnapshotEnvelope? {
        let primary = primaryURL(for: domain)
        let backup = backupURL(for: domain)
        guard fileManager.fileExists(atPath: primary.path) || fileManager.fileExists(atPath: backup.path) else {
            return nil
        }
        if let envelope = try? decode(primary, expectedDomain: domain) {
            return envelope
        }
        if let envelope = try? decode(backup, expectedDomain: domain) {
            return envelope
        }
        throw SystemSnapshotStoreError.unreadablePrimaryAndBackup
    }

    private func decode(
        _ url: URL,
        expectedDomain: SystemSurfaceDomain
    ) throws -> SystemSnapshotEnvelope {
        let envelope = try decoder.decode(SystemSnapshotEnvelope.self, from: Data(contentsOf: url))
        guard envelope.schemaVersion <= SystemSnapshotEnvelope.currentSchemaVersion else {
            throw SystemSnapshotStoreError.incompatibleSchema(
                found: envelope.schemaVersion,
                supported: SystemSnapshotEnvelope.currentSchemaVersion
            )
        }
        guard envelope.domain == expectedDomain else {
            throw SystemSnapshotStoreError.domainMismatch
        }
        return envelope
    }

    private func primaryURL(for domain: SystemSurfaceDomain) -> URL {
        directoryURL.appendingPathComponent("lifeboard-\(domain.rawValue)-snapshot-v1.json", isDirectory: false)
    }

    private func backupURL(for domain: SystemSurfaceDomain) -> URL {
        directoryURL.appendingPathComponent("lifeboard-\(domain.rawValue)-snapshot-v1.backup.json", isDirectory: false)
    }
}
