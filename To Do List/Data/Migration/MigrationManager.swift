//
//  MigrationManager.swift
//  Tasker
//
//  Service for tracking and managing migration versions
//

import Foundation

/// Enum representing different stages of data migration
public enum MigrationVersion: Int {
    case legacy = 0                 // Original app with no UUIDs
    case uuidIntroduced = 1          // UUIDs added to schema but not assigned
    case uuidAssigned = 2            // All entities have UUIDs assigned
    case referenceMigrated = 3       // All task→project references use UUIDs
    case stringDeprecated = 4        // String fields marked deprecated (future)

    /// Human-readable description of the migration version
    public var description: String {
        switch self {
        case .legacy:
            return "Legacy (no UUIDs)"
        case .uuidIntroduced:
            return "UUID Schema Added"
        case .uuidAssigned:
            return "UUIDs Assigned"
        case .referenceMigrated:
            return "References Migrated to UUIDs"
        case .stringDeprecated:
            return "String Fields Deprecated"
        }
    }
}

/// Manager responsible for tracking migration progress and determining what migrations need to run
public final class MigrationManager {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private static let migrationVersionKey = "com.tasker.migration.version"
    private static let lastMigrationDateKey = "com.tasker.migration.lastDate"
    private static let migrationHistoryKey = "com.tasker.migration.history"

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Get the current migration version
    public func currentVersion() -> MigrationVersion {
        let rawValue = userDefaults.integer(forKey: Self.migrationVersionKey)
        return MigrationVersion(rawValue: rawValue) ?? .legacy
    }

    /// Set the current migration version
    public func setCurrentVersion(_ version: MigrationVersion) {
        userDefaults.set(version.rawValue, forKey: Self.migrationVersionKey)
        userDefaults.set(Date(), forKey: Self.lastMigrationDateKey)

        // Add to migration history
        addToHistory(version: version, date: Date())

        print("✅ Migration version updated to: \(version.description)")
    }

    /// Check if migration is needed
    public func needsMigration() -> Bool {
        let current = currentVersion()
        return current.rawValue < MigrationVersion.referenceMigrated.rawValue
    }

    /// Get the target migration version (latest available)
    public func targetVersion() -> MigrationVersion {
        return .referenceMigrated
    }

    /// Check if a specific migration step is needed
    public func needsMigration(to targetVersion: MigrationVersion) -> Bool {
        return currentVersion().rawValue < targetVersion.rawValue
    }

    /// Get the date of the last migration
    public func lastMigrationDate() -> Date? {
        return userDefaults.object(forKey: Self.lastMigrationDateKey) as? Date
    }

    /// Get migration history
    public func getMigrationHistory() -> [MigrationHistoryEntry] {
        guard let data = userDefaults.data(forKey: Self.migrationHistoryKey),
              let history = try? JSONDecoder().decode([MigrationHistoryEntry].self, from: data) else {
            return []
        }
        return history
    }

    /// Reset migration state (for debugging/testing only)
    public func resetMigrationState() {
        userDefaults.removeObject(forKey: Self.migrationVersionKey)
        userDefaults.removeObject(forKey: Self.lastMigrationDateKey)
        userDefaults.removeObject(forKey: Self.migrationHistoryKey)
        print("⚠️ Migration state reset to legacy")
    }

    /// 🔥 EMERGENCY: Force reset migration state to handle corrupted migration state
    /// This should be called when migration claims completion but data still shows legacy format
    public func forceResetMigration() {
        userDefaults.removeObject(forKey: Self.migrationVersionKey)
        userDefaults.removeObject(forKey: Self.lastMigrationDateKey)
        userDefaults.removeObject(forKey: Self.migrationHistoryKey)
        print("🚨 EMERGENCY: Migration state reset - will force re-run")
    }

    /// Generate a migration plan based on current version
    public func generateMigrationPlan() -> MigrationPlan {
        let current = currentVersion()
        let target = targetVersion()

        var stepsNeeded: [MigrationStep] = []

        // Determine which steps are needed
        if current.rawValue < MigrationVersion.uuidIntroduced.rawValue {
            stepsNeeded.append(.addUUIDSchema)
        }

        if current.rawValue < MigrationVersion.uuidAssigned.rawValue {
            stepsNeeded.append(.assignUUIDs)
        }

        if current.rawValue < MigrationVersion.referenceMigrated.rawValue {
            stepsNeeded.append(.migrateReferences)
        }

        return MigrationPlan(
            currentVersion: current,
            targetVersion: target,
            stepsNeeded: stepsNeeded,
            estimatedDuration: estimateDuration(for: stepsNeeded)
        )
    }

    // MARK: - Private Methods

    private func addToHistory(version: MigrationVersion, date: Date) {
        var history = getMigrationHistory()
        let entry = MigrationHistoryEntry(
            version: version.rawValue,
            versionDescription: version.description,
            date: date
        )
        history.append(entry)

        // Keep only last 20 entries
        if history.count > 20 {
            history = Array(history.suffix(20))
        }

        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: Self.migrationHistoryKey)
        }
    }

    private func estimateDuration(for steps: [MigrationStep]) -> TimeInterval {
        // Rough estimates in seconds
        var total: TimeInterval = 0
        for step in steps {
            switch step {
            case .addUUIDSchema:
                total += 1 // Fast schema update
            case .assignUUIDs:
                total += 5 // Depends on data size
            case .migrateReferences:
                total += 10 // More complex, involves lookups
            }
        }
        return total
    }
}

// MARK: - Supporting Types

/// Represents a single entry in migration history
public struct MigrationHistoryEntry: Codable {
    public let version: Int
    public let versionDescription: String
    public let date: Date

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

/// Represents a specific migration step
public enum MigrationStep {
    case addUUIDSchema
    case assignUUIDs
    case migrateReferences

    public var description: String {
        switch self {
        case .addUUIDSchema:
            return "Add UUID fields to Core Data schema"
        case .assignUUIDs:
            return "Assign UUIDs to all projects and tasks"
        case .migrateReferences:
            return "Migrate task→project references to use UUIDs"
        }
    }

    public var estimatedDuration: TimeInterval {
        switch self {
        case .addUUIDSchema: return 1
        case .assignUUIDs: return 5
        case .migrateReferences: return 10
        }
    }
}

/// Represents a complete migration plan
public struct MigrationPlan {
    public let currentVersion: MigrationVersion
    public let targetVersion: MigrationVersion
    public let stepsNeeded: [MigrationStep]
    public let estimatedDuration: TimeInterval

    public var needsMigration: Bool {
        return !stepsNeeded.isEmpty
    }

    public var description: String {
        if !needsMigration {
            return "✅ No migration needed. Current version: \(currentVersion.description)"
        }

        var desc = """
        📋 Migration Plan
        Current: \(currentVersion.description)
        Target: \(targetVersion.description)
        Estimated duration: \(String(format: "%.1f", estimatedDuration))s

        Steps needed:
        """

        for (index, step) in stepsNeeded.enumerated() {
            desc += "\n  \(index + 1). \(step.description)"
        }

        return desc
    }
}
