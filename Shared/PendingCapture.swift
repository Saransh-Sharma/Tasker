//
//  PendingCapture.swift
//  LifeBoard (Shared)
//
//  A task capture queued by an out-of-process surface (Control Center control,
//  interactive widget, or the Share Extension fallback path) into the App Group
//  container. The main app drains these on foreground via CaptureInboxDrain.
//

import Foundation

public struct PendingCapture: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let rawText: String
    public let createdAt: Date
    /// Origin label for analytics/debugging, e.g. "control", "widget", "share-extension".
    public let source: String
    /// Optional structured context retained by Share Extension captures.
    /// These fields are optional so every previously persisted queue decodes.
    public let sharedURL: URL?
    public let sourceTitle: String?
    /// Non-nil while an in-app capture is an interruption-recovery draft.
    public let provisionalAt: Date?

    public init(
        id: UUID = UUID(),
        rawText: String,
        createdAt: Date = Date(),
        source: String,
        sharedURL: URL? = nil,
        sourceTitle: String? = nil,
        provisionalAt: Date? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.createdAt = createdAt
        self.source = source
        self.sharedURL = sharedURL
        self.sourceTitle = sourceTitle
        self.provisionalAt = provisionalAt
    }

    public var isProvisional: Bool { provisionalAt != nil }

    public func finalized() -> PendingCapture {
        PendingCapture(
            id: id,
            rawText: rawText,
            createdAt: createdAt,
            source: source,
            sharedURL: sharedURL,
            sourceTitle: sourceTitle
        )
    }
}

/// Atomic append/read/clear helpers over the App Group `PendingCaptureInbox.json` file.
/// Safe to call from extensions (no Core Data, just a small JSON file).
public enum PendingCaptureInbox {

    @discardableResult
    public static func append(_ capture: PendingCapture) -> Bool {
        // Extension delivery is at-least-once. A retry carrying the same stable
        // identifier must update the existing row rather than create two
        // independently fileable captures.
        upsert(capture)
    }

    /// Inserts or replaces a stable capture. Used by provisional drafts so a
    /// relaunch recovers one thought rather than a row for every keystroke.
    @discardableResult
    public static func upsert(_ capture: PendingCapture) -> Bool {
        upsert([capture])
    }

    /// Atomically restores or updates a set of captures. Undo uses one
    /// coordinated transaction so it can never restore only half of a merge.
    @discardableResult
    public static func upsert(_ captures: [PendingCapture]) -> Bool {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return false }
        return upsert(captures, at: url)
    }

    @discardableResult
    static func upsert(_ captures: [PendingCapture], at url: URL) -> Bool {
        mutate(at: url) { queue in
            for capture in captures {
                if let index = queue.firstIndex(where: { $0.id == capture.id }) {
                    queue[index] = capture
                } else {
                    queue.append(capture)
                }
            }
        }
    }

    /// Removes the provisional marker without changing identity or chronology.
    @discardableResult
    public static func finalize(id: UUID) -> Bool {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return false }
        return mutate(at: url) { queue in
            guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
            queue[index] = queue[index].finalized()
        }
    }

    public static func read() -> [PendingCapture] {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return [] }
        return read(from: url)
    }

    static func read(from url: URL) -> [PendingCapture] {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: [PendingCapture] = []
        coordinator.coordinate(
            readingItemAt: url,
            options: .withoutChanges,
            error: &coordinationError
        ) { coordinatedURL in
            guard let data = try? Data(contentsOf: coordinatedURL),
                  let queue = try? JSONDecoder().decode([PendingCapture].self, from: data) else {
                return
            }
            result = queue
        }
        return result
    }

    /// Removes the given captures (by id) from the file, preserving any that arrived since.
    @discardableResult
    public static func remove(ids: Set<UUID>) -> Bool {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return false }
        return remove(ids: ids, at: url)
    }

    @discardableResult
    static func remove(ids: Set<UUID>, at url: URL) -> Bool {
        mutate(at: url) { queue in
            queue.removeAll { ids.contains($0.id) }
        }
    }

    @discardableResult
    public static func clear() -> Bool {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return false }
        return mutate(at: url) { $0.removeAll() }
    }

    /// Coordinates the complete read-modify-write transaction across the app
    /// and extensions. Atomic Data writes alone do not prevent two processes
    /// from both reading the same old queue and losing one another's append.
    private static func mutate(
        at url: URL,
        _ mutation: (inout [PendingCapture]) -> Void
    ) -> Bool {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var didWrite = false
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinatedURL in
            var queue: [PendingCapture]
            if let data = try? Data(contentsOf: coordinatedURL),
               let decoded = try? JSONDecoder().decode([PendingCapture].self, from: data) {
                queue = decoded
            } else {
                queue = []
            }
            mutation(&queue)
            didWrite = write(queue, to: coordinatedURL)
        }
        return coordinationError == nil && didWrite
    }

    private static func write(_ queue: [PendingCapture], to url: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(queue) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
