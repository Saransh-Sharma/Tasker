//
//  HomeTimelineSnapshotRenderCache.swift
//  LifeBoard
//
//  Render cache for Home timeline snapshots.
//

import Combine
import Foundation

@MainActor
final class HomeTimelineSnapshotRenderCache: ObservableObject {
    private static let capacity = 4

    struct Key: Equatable {
        let timelineRevision: UInt64
        let calendarSnapshot: HomeCalendarSnapshot
        let selectedDate: Date
        let sunriseAnchor: SunriseAnchor
    }

    private var entries: [(key: Key, snapshot: HomeTimelineSnapshot)] = []

    func snapshot(for key: Key, build: () -> HomeTimelineSnapshot) -> HomeTimelineSnapshot {
        if let index = entries.firstIndex(where: { $0.key == key }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.snapshot
        }

        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineSnapshotRenderCacheMiss")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let snapshot = build()
        entries.append((key, snapshot))
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
        return snapshot
    }
}
