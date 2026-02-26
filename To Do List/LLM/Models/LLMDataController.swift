import Foundation
import SwiftData
import os

/// Singleton that holds a single ModelContainer for the LLM module so every view shares the exact same persistent store.
enum LLMDataController {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tasker", category: "LLMDataController")
    private(set) static var isDegradedModeActive = false
    private(set) static var degradedModeReason: String?

    /// Executes storeURL.
    private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("llm-chat-history.store")
    }

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

    static let shared: ModelContainer? = {
        func activateDegradedMode(reason: String) {
            isDegradedModeActive = true
            degradedModeReason = reason
        }

        let config = makeConfiguration()
        do {
            return try ModelContainer(for: Thread.self, Message.self, configurations: config)
        } catch {
            logger.error("Initial LLM SwiftData container creation failed: \(error.localizedDescription, privacy: .public)")
            activateDegradedMode(reason: "persistent_store_initialization_failed")
            let url = storeURL()
            recreateStoreAtURL(url)
            do {
                return try ModelContainer(for: Thread.self, Message.self, configurations: makeConfiguration())
            } catch {
                logger.fault("LLM SwiftData container recreation failed: \(error.localizedDescription, privacy: .public)")
                activateDegradedMode(reason: "persistent_store_recovery_failed")
                do {
                    logger.warning("Falling back to in-memory LLM SwiftData container after persistent store recovery failure.")
                    return try ModelContainer(
                        for: Thread.self,
                        Message.self,
                        configurations: makeInMemoryConfiguration()
                    )
                } catch {
                    logger.fault("In-memory LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                    activateDegradedMode(reason: "in_memory_fallback_failed")
                    do {
                        logger.warning("Attempting temporary disk-backed fallback for LLM SwiftData container.")
                        return try ModelContainer(
                            for: Thread.self,
                            Message.self,
                            configurations: makeTemporaryDiskConfiguration()
                        )
                    } catch {
                        logger.fault("Temporary LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                        activateDegradedMode(reason: "llm_store_unavailable")
                        return nil
                    }
                }
            }
        }
    }()
}
