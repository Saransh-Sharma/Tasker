//
//  HomeSessionContextStore.swift
//  LifeBoard
//
//  Persists a small amount of "what was I just doing" context so the Home screen
//  can offer a calm, context-aware Resume surface after the user returns from a
//  break. Intentionally lightweight: a few UserDefaults keys, no Core Data.
//

import Foundation

/// What the user most recently did, used to choose a Resume affordance.
public enum HomeSessionInteraction: String, Codable, Sendable {
    case openedTask
    case startedFocus
}

/// A point-in-time snapshot of the user's last meaningful Home interaction.
public struct HomeSessionContext: Equatable, Sendable {
    public let lastActiveTaskID: UUID?
    public let lastFocusSessionTaskID: UUID?
    public let lastActiveAt: Date
    public let lastInteraction: HomeSessionInteraction?

    public init(
        lastActiveTaskID: UUID?,
        lastFocusSessionTaskID: UUID?,
        lastActiveAt: Date,
        lastInteraction: HomeSessionInteraction?
    ) {
        self.lastActiveTaskID = lastActiveTaskID
        self.lastFocusSessionTaskID = lastFocusSessionTaskID
        self.lastActiveAt = lastActiveAt
        self.lastInteraction = lastInteraction
    }
}

public enum HomeSessionContextStore {

    /// Contexts older than this are considered stale and not surfaced for Resume.
    public static let stalenessWindow: TimeInterval = 18 * 60 * 60

    private enum Key {
        static let lastActiveTaskID = "home.session.lastActiveTaskID.v1"
        static let lastFocusSessionTaskID = "home.session.lastFocusSessionTaskID.v1"
        static let lastActiveAt = "home.session.lastActiveAt.v1"
        static let lastInteraction = "home.session.lastInteraction.v1"
    }

    // MARK: - Writes

    public static func recordTaskOpened(_ taskID: UUID, now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(taskID.uuidString, forKey: Key.lastActiveTaskID)
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastActiveAt)
        defaults.set(HomeSessionInteraction.openedTask.rawValue, forKey: Key.lastInteraction)
    }

    public static func recordFocusStart(taskID: UUID?, now: Date = Date(), defaults: UserDefaults = .standard) {
        if let taskID {
            defaults.set(taskID.uuidString, forKey: Key.lastFocusSessionTaskID)
            defaults.set(taskID.uuidString, forKey: Key.lastActiveTaskID)
        }
        defaults.set(now.timeIntervalSince1970, forKey: Key.lastActiveAt)
        defaults.set(HomeSessionInteraction.startedFocus.rawValue, forKey: Key.lastInteraction)
    }

    // MARK: - Read

    /// Returns the last session context, or nil when there is none or it is stale.
    public static func load(now: Date = Date(), defaults: UserDefaults = .standard) -> HomeSessionContext? {
        let timestamp = defaults.double(forKey: Key.lastActiveAt)
        guard timestamp > 0 else { return nil }
        let lastActiveAt = Date(timeIntervalSince1970: timestamp)
        guard now.timeIntervalSince(lastActiveAt) <= stalenessWindow, now >= lastActiveAt else { return nil }

        let activeTaskID = defaults.string(forKey: Key.lastActiveTaskID).flatMap(UUID.init(uuidString:))
        let focusTaskID = defaults.string(forKey: Key.lastFocusSessionTaskID).flatMap(UUID.init(uuidString:))
        let interaction = defaults.string(forKey: Key.lastInteraction).flatMap(HomeSessionInteraction.init(rawValue:))

        return HomeSessionContext(
            lastActiveTaskID: activeTaskID,
            lastFocusSessionTaskID: focusTaskID,
            lastActiveAt: lastActiveAt,
            lastInteraction: interaction
        )
    }

    public static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.lastActiveTaskID)
        defaults.removeObject(forKey: Key.lastFocusSessionTaskID)
        defaults.removeObject(forKey: Key.lastActiveAt)
        defaults.removeObject(forKey: Key.lastInteraction)
    }
}
