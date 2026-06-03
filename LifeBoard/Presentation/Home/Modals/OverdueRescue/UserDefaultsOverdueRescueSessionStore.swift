//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct UserDefaultsOverdueRescueSessionStore: OverdueRescueSessionStore {
    let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState? {
        try loadSync(scope: scope)
    }

    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws {
        try saveSync(session, scope: scope)
    }

    func clear(scope: OverdueRescueSessionScope) async throws {
        clearSync(scope: scope)
    }

    func loadSync(scope: OverdueRescueSessionScope) throws -> OverdueRescueSessionState? {
        guard let data = userDefaults.data(forKey: scope.storageKey) else { return nil }
        return try JSONDecoder().decode(OverdueRescueSessionState.self, from: data)
    }

    func saveSync(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) throws {
        let data = try JSONEncoder().encode(session)
        userDefaults.set(data, forKey: scope.storageKey)
    }

    func clearSync(scope: OverdueRescueSessionScope) {
        userDefaults.removeObject(forKey: scope.storageKey)
    }
}
