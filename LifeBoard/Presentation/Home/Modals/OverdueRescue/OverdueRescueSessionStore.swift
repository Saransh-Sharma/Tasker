//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

protocol OverdueRescueSessionStore {
    func load(scope: OverdueRescueSessionScope) async throws -> OverdueRescueSessionState?
    func save(_ session: OverdueRescueSessionState, scope: OverdueRescueSessionScope) async throws
    func clear(scope: OverdueRescueSessionScope) async throws
}
