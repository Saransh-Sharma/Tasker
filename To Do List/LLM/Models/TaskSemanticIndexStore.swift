import Foundation

final class TaskSemanticIndexStore {
    private struct PersistedIndex: Codable {
        var vectorsByTaskID: [String: [Double]]
        var textByTaskID: [String: String]
        var updatedAt: Date
    }

    private var vectorsByTaskID: [UUID: [Double]] = [:]
    private var textByTaskID: [UUID: String] = [:]
    private let lock = NSLock()
    private let fileURL: URL

    /// Initializes a new instance.
    init(fileName: String = "tasker-semantic-index-v1.bin") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.fileURL = appSupport.appendingPathComponent(fileName)
    }

    /// Executes upsert.
    func upsert(taskID: UUID, text: String, vector: [Double]) {
        lock.lock()
        vectorsByTaskID[taskID] = vector
        textByTaskID[taskID] = text
        lock.unlock()
    }

    /// Executes remove.
    func remove(taskID: UUID) {
        lock.lock()
        vectorsByTaskID.removeValue(forKey: taskID)
        textByTaskID.removeValue(forKey: taskID)
        lock.unlock()
    }

    /// Executes snapshot.
    func snapshot() -> [(taskID: UUID, text: String, vector: [Double])] {
        lock.lock()
        defer { lock.unlock() }
        return vectorsByTaskID.compactMap { taskID, vector in
            guard let text = textByTaskID[taskID] else { return nil }
            return (taskID, text, vector)
        }
    }

    /// Executes replaceAll.
    func replaceAll(_ items: [(taskID: UUID, text: String, vector: [Double])]) {
        lock.lock()
        vectorsByTaskID = Dictionary(uniqueKeysWithValues: items.map { ($0.taskID, $0.vector) })
        textByTaskID = Dictionary(uniqueKeysWithValues: items.map { ($0.taskID, $0.text) })
        lock.unlock()
    }

    /// Executes persist.
    func persist() {
        lock.lock()
        let payload = PersistedIndex(
            vectorsByTaskID: Dictionary(uniqueKeysWithValues: vectorsByTaskID.map { ($0.key.uuidString, $0.value) }),
            textByTaskID: Dictionary(uniqueKeysWithValues: textByTaskID.map { ($0.key.uuidString, $0.value) }),
            updatedAt: Date()
        )
        lock.unlock()

        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logWarning(
                event: "assistant_semantic_index_persist_failed",
                message: "Failed persisting semantic index",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    /// Executes loadPersisted.
    func loadPersisted() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? JSONDecoder().decode(PersistedIndex.self, from: data) else { return }

        lock.lock()
        vectorsByTaskID = payload.vectorsByTaskID.reduce(into: [:]) { partial, pair in
            if let id = UUID(uuidString: pair.key) {
                partial[id] = pair.value
            }
        }
        textByTaskID = payload.textByTaskID.reduce(into: [:]) { partial, pair in
            if let id = UUID(uuidString: pair.key) {
                partial[id] = pair.value
            }
        }
        lock.unlock()
    }
}
