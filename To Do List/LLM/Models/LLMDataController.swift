import SwiftData

/// Singleton that holds a single ModelContainer for the LLM module so every view shares the exact same persistent store.
@MainActor
enum LLMDataController {
    static let shared: ModelContainer = {
        // Persistent SQLite store (default) with CloudKit disabled so that the model
        // is not validated against CloudKit requirements.
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: Thread.self, Message.self, configurations: config)
        } catch {
            fatalError("Unable to create SwiftData container for LLM module: \(error)")
        }
    }()
}
