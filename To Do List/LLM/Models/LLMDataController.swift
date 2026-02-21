import Foundation
import SwiftData
import os

/// Singleton that holds a single ModelContainer for the LLM module so every view shares the exact same persistent store.
@MainActor
enum LLMDataController {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tasker", category: "LLMDataController")

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

    static let shared: ModelContainer = {
        let config = makeConfiguration()
        do {
            return try ModelContainer(for: Thread.self, Message.self, configurations: config)
        } catch {
            logger.error("Initial LLM SwiftData container creation failed: \(error.localizedDescription, privacy: .public)")
            let url = storeURL()
            recreateStoreAtURL(url)
            do {
                return try ModelContainer(for: Thread.self, Message.self, configurations: makeConfiguration())
            } catch {
                logger.fault("LLM SwiftData container recreation failed: \(error.localizedDescription, privacy: .public)")
                do {
                    logger.warning("Falling back to in-memory LLM SwiftData container after persistent store recovery failure.")
                    return try ModelContainer(
                        for: Thread.self,
                        Message.self,
                        configurations: makeInMemoryConfiguration()
                    )
                } catch {
                    logger.fault("In-memory LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                    fatalError("Unable to create SwiftData container for LLM module: \(error)")
                }
            }
        }
    }()
}
