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

    public init(id: UUID = UUID(), rawText: String, createdAt: Date = Date(), source: String) {
        self.id = id
        self.rawText = rawText
        self.createdAt = createdAt
        self.source = source
    }
}

/// Atomic append/read/clear helpers over the App Group `PendingCaptureInbox.json` file.
/// Safe to call from extensions (no Core Data, just a small JSON file).
public enum PendingCaptureInbox {

    public static func append(_ capture: PendingCapture) {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return }
        var queue = read()
        queue.append(capture)
        write(queue, to: url)
    }

    public static func read() -> [PendingCapture] {
        guard let url = AppGroupConstants.pendingCaptureInboxURL,
              let data = try? Data(contentsOf: url),
              let queue = try? JSONDecoder().decode([PendingCapture].self, from: data) else {
            return []
        }
        return queue
    }

    /// Removes the given captures (by id) from the file, preserving any that arrived since.
    public static func remove(ids: Set<UUID>) {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return }
        let remaining = read().filter { ids.contains($0.id) == false }
        write(remaining, to: url)
    }

    public static func clear() {
        guard let url = AppGroupConstants.pendingCaptureInboxURL else { return }
        write([], to: url)
    }

    private static func write(_ queue: [PendingCapture], to url: URL) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
