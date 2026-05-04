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
    private var didAttemptLoadPersisted = false
    private var isDirty = false

    /// Initializes a new instance.
    init(fileName: String = "lifeboard-semantic-index-v1.bin") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.fileURL = appSupport.appendingPathComponent(fileName)
    }

    var itemCount: Int {
        ensureLoadedIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return vectorsByTaskID.count
    }

    var hasPersistedIndex: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    var hasDirtyChanges: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isDirty
    }

    /// Executes upsert.
    func upsert(taskID: UUID, text: String, vector: [Double]) {
        ensureLoadedIfNeeded()
        lock.lock()
        vectorsByTaskID[taskID] = vector
        textByTaskID[taskID] = text
        isDirty = true
        lock.unlock()
    }

    /// Executes remove.
    func remove(taskID: UUID) {
        ensureLoadedIfNeeded()
        lock.lock()
        vectorsByTaskID.removeValue(forKey: taskID)
        textByTaskID.removeValue(forKey: taskID)
        isDirty = true
        lock.unlock()
    }

    /// Executes snapshot.
    func snapshot() -> [(taskID: UUID, text: String, vector: [Double])] {
        ensureLoadedIfNeeded()
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
        didAttemptLoadPersisted = true
        isDirty = true
        lock.unlock()
    }

    /// Executes persist.
    func persist() {
        ensureLoadedIfNeeded()
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
            lock.lock()
            didAttemptLoadPersisted = true
            isDirty = false
            lock.unlock()
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
        loadPersistedIfAvailable(forceReload: true)
    }

    func unloadFromMemory() {
        lock.lock()
        vectorsByTaskID = [:]
        textByTaskID = [:]
        didAttemptLoadPersisted = false
        lock.unlock()
    }

    private func ensureLoadedIfNeeded() {
        lock.lock()
        let shouldLoad = didAttemptLoadPersisted == false
        if shouldLoad {
            didAttemptLoadPersisted = true
        }
        lock.unlock()

        guard shouldLoad else { return }
        loadPersistedIfAvailable(forceReload: false)
    }

    private func loadPersistedIfAvailable(forceReload: Bool) {
        if forceReload {
            lock.lock()
            didAttemptLoadPersisted = true
            lock.unlock()
        }
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
        isDirty = false
        lock.unlock()
    }
}
