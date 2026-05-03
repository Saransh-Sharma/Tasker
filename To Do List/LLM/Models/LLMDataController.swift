import Foundation
import CoreData
import SwiftData
import os

/// Singleton that holds a single ModelContainer for the LLM module so every view shares the exact same persistent store.
@MainActor
enum LLMDataController {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tasker", category: "LLMDataController")
    private(set) static var isDegradedModeActive = false
    private(set) static var degradedModeReason: String?

    enum StoreRecoveryDisposition: Equatable {
        case fallbackWithoutRecreation(reason: String)
        case recreatePersistentStore(reason: String)
    }

    /// Executes storeURL.
    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("llm-chat-history.store")
    }

    private static let schema = Schema(LLMChatSchemaV1.models)

    /// Executes makeConfiguration.
    private static func makeConfiguration() -> ModelConfiguration {
        ModelConfiguration(url: storeURL(), cloudKitDatabase: .none)
    }

    /// Executes makeInMemoryConfiguration.
    private static func makeInMemoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }

    /// Executes makeTemporaryDiskConfiguration.
    private static func makeTemporaryDiskConfiguration() -> ModelConfiguration {
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("tasker-llm-\(UUID().uuidString).store")
        return ModelConfiguration(url: temporaryURL, cloudKitDatabase: .none)
    }

    /// Executes recreateStoreAtURL.
    private static func recreateStoreAtURL(_ storeURL: URL) {
        let fileManager = FileManager.default
        let sidecars = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        for url in sidecars where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                logger.error("Failed to remove LLM store file \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated static func recoveryDisposition(for error: Error) -> StoreRecoveryDisposition {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSMigrationError,
                 NSMigrationCancelledError,
                 NSMigrationMissingSourceModelError,
                 NSMigrationMissingMappingModelError,
                 NSPersistentStoreIncompatibleVersionHashError,
                 NSPersistentStoreIncompatibleSchemaError:
                return .fallbackWithoutRecreation(reason: "persistent_store_migration_failed")
            default:
                break
            }
        }

        let description = error.localizedDescription.lowercased()
        let migrationSignals = [
            "incompatible",
            "migration",
            "schema",
            "model used to open the store",
            "unknown model version",
            "expected only arrays for relationships"
        ]
        if migrationSignals.contains(where: description.contains) {
            return .fallbackWithoutRecreation(reason: "persistent_store_migration_failed")
        }

        let corruptionSignals = [
            "malformed",
            "disk image is malformed",
            "file is not a database",
            "database disk image is malformed",
            "not a database",
            "i/o error",
            "wal"
        ]
        if corruptionSignals.contains(where: description.contains) {
            return .recreatePersistentStore(reason: "persistent_store_corrupted")
        }

        return .fallbackWithoutRecreation(reason: "persistent_store_initialization_failed")
    }

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: LLMChatMigrationPlan.self,
            configurations: [configuration]
        )
    }

    @MainActor
    static let shared: ModelContainer? = {
        @MainActor
        func activateDegradedMode(reason: String) {
            isDegradedModeActive = true
            degradedModeReason = reason
        }

        let config = makeConfiguration()
        do {
            return try makeModelContainer(configuration: config)
        } catch {
            logger.error("Initial LLM SwiftData container creation failed: \(error.localizedDescription, privacy: .public)")
            let disposition = recoveryDisposition(for: error)
            activateDegradedMode(reason: {
                switch disposition {
                case .fallbackWithoutRecreation(let reason), .recreatePersistentStore(let reason):
                    return reason
                }
            }())

            if case .recreatePersistentStore = disposition {
                let url = storeURL()
                recreateStoreAtURL(url)
                do {
                    return try makeModelContainer(configuration: makeConfiguration())
                } catch {
                    logger.fault("LLM SwiftData container recreation failed: \(error.localizedDescription, privacy: .public)")
                    activateDegradedMode(reason: "persistent_store_recovery_failed")
                }
            }

            do {
                logger.warning("Falling back to in-memory LLM SwiftData container after persistent store initialization failure.")
                return try makeModelContainer(configuration: makeInMemoryConfiguration())
            } catch {
                logger.fault("In-memory LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                activateDegradedMode(reason: "in_memory_fallback_failed")
                do {
                    logger.warning("Attempting temporary disk-backed fallback for LLM SwiftData container.")
                    return try makeModelContainer(configuration: makeTemporaryDiskConfiguration())
                } catch {
                    logger.fault("Temporary LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                    activateDegradedMode(reason: "llm_store_unavailable")
                    return nil
                }
            }
        }
    }()
}
