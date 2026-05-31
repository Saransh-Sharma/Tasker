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
    struct Key: Equatable {
        let timelineRevision: UInt64
        let calendarSnapshot: HomeCalendarSnapshot
        let selectedDate: Date
        let sunriseAnchor: SunriseAnchor
    }

    private var cachedKey: Key?
    private var cachedSnapshot: HomeTimelineSnapshot?

    func snapshot(for key: Key, build: () -> HomeTimelineSnapshot) -> HomeTimelineSnapshot {
        if cachedKey == key, let cachedSnapshot {
            return cachedSnapshot
        }

        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineSnapshotRenderCacheMiss")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let snapshot = build()
        cachedKey = key
        cachedSnapshot = snapshot
        return snapshot
    }
}
