import Foundation
import CoreData
import Combine
import SwiftData
import os

/// Builds the shared LLM store without performing file or migration work from
/// a SwiftUI body or view-controller initializer.
@MainActor
enum LLMDataController {
    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "LifeBoard",
        category: "LLMDataController"
    )

    static var shared: ModelContainer? { LLMStoreBootstrap.shared.container }
    static var isDegradedModeActive: Bool { LLMStoreBootstrap.shared.isDegraded }
    static var degradedModeReason: String? { LLMStoreBootstrap.shared.degradedReason }

    enum StoreRecoveryDisposition: Equatable, Sendable {
        case fallbackWithoutRecreation(reason: String)
        case recreatePersistentStore(reason: String)
    }

    enum LoadResult: Sendable {
        case ready(ModelContainer)
        case degraded(container: ModelContainer?, reason: String)

        var container: ModelContainer? {
            switch self {
            case .ready(let container):
                container
            case .degraded(let container, _):
                container
            }
        }
    }

    static func load() async -> ModelContainer? {
        await LLMStoreBootstrap.shared.load()
    }

    /// Executes storeURL.
    nonisolated private static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return appSupport.appendingPathComponent("llm-chat-history.store")
    }

    /// Executes makeConfiguration.
    nonisolated private static func makeConfiguration() -> ModelConfiguration {
        ModelConfiguration(url: storeURL(), cloudKitDatabase: .none)
    }

    /// Executes makeInMemoryConfiguration.
    nonisolated private static func makeInMemoryConfiguration() -> ModelConfiguration {
        ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }

    /// Executes makeTemporaryDiskConfiguration.
    nonisolated private static func makeTemporaryDiskConfiguration() -> ModelConfiguration {
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("lifeboard-llm-\(UUID().uuidString).store")
        return ModelConfiguration(url: temporaryURL, cloudKitDatabase: .none)
    }

    /// Executes recreateStoreAtURL.
    nonisolated private static func recreateStoreAtURL(_ storeURL: URL) {
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

    nonisolated private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(LLMChatSchemaV1.models),
            migrationPlan: LLMChatMigrationPlan.self,
            configurations: [configuration]
        )
    }

    nonisolated static func loadStore() -> LoadResult {
        let config = makeConfiguration()
        do {
            return .ready(try makeModelContainer(configuration: config))
        } catch {
            logger.error("Initial LLM SwiftData container creation failed: \(error.localizedDescription, privacy: .public)")
            let disposition = recoveryDisposition(for: error)
            var degradedReason = {
                switch disposition {
                case .fallbackWithoutRecreation(let reason), .recreatePersistentStore(let reason):
                    return reason
                }
            }()

            if case .recreatePersistentStore = disposition {
                let url = storeURL()
                recreateStoreAtURL(url)
                do {
                    return .degraded(
                        container: try makeModelContainer(configuration: makeConfiguration()),
                        reason: degradedReason
                    )
                } catch {
                    logger.fault("LLM SwiftData container recreation failed: \(error.localizedDescription, privacy: .public)")
                    degradedReason = "persistent_store_recovery_failed"
                }
            }

            do {
                logger.warning("Falling back to in-memory LLM SwiftData container after persistent store initialization failure.")
                return .degraded(
                    container: try makeModelContainer(configuration: makeInMemoryConfiguration()),
                    reason: degradedReason
                )
            } catch {
                logger.fault("In-memory LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                degradedReason = "in_memory_fallback_failed"
                do {
                    logger.warning("Attempting temporary disk-backed fallback for LLM SwiftData container.")
                    return .degraded(
                        container: try makeModelContainer(configuration: makeTemporaryDiskConfiguration()),
                        reason: degradedReason
                    )
                } catch {
                    logger.fault("Temporary LLM SwiftData container fallback failed: \(error.localizedDescription, privacy: .public)")
                    return .degraded(container: nil, reason: "llm_store_unavailable")
                }
            }
        }
    }
}

/// Main-actor observable facade around the utility-priority store load.
///
/// `ModelContainer` is `@unchecked Sendable` in SwiftData, so the completed
/// container can safely cross back to the main actor where all UI consumers
/// access its `mainContext`.
@MainActor
final class LLMStoreBootstrap: ObservableObject {
    enum State {
        case idle
        case loading
        case ready(ModelContainer)
        case degraded(container: ModelContainer?, reason: String)
    }

    static let shared = LLMStoreBootstrap()

    @Published private(set) var state: State = .idle
    private var loadingTask: Task<LLMDataController.LoadResult, Never>?

    var container: ModelContainer? {
        switch state {
        case .ready(let container):
            container
        case .degraded(let container, _):
            container
        case .idle, .loading:
            nil
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isDegraded: Bool {
        if case .degraded = state { return true }
        return false
    }

    var degradedReason: String? {
        if case .degraded(_, let reason) = state { return reason }
        return nil
    }

    func start() {
        guard case .idle = state else { return }
        state = .loading
        let task = Task.detached(priority: .utility) {
            LLMDataController.loadStore()
        }
        loadingTask = task
        Task { [weak self] in
            let result = await task.value
            self?.publish(result)
        }
    }

    func load() async -> ModelContainer? {
        if let container {
            return container
        }
        start()
        guard let loadingTask else {
            return container
        }
        let result = await loadingTask.value
        publish(result)
        return result.container
    }

    private func publish(_ result: LLMDataController.LoadResult) {
        guard case .loading = state else { return }
        loadingTask = nil
        switch result {
        case .ready(let container):
            state = .ready(container)
        case .degraded(let container, let reason):
            state = .degraded(container: container, reason: reason)
        }
    }
}
