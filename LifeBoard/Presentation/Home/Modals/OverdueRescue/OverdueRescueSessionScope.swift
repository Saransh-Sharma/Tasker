//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSessionScope: Codable, Equatable, Hashable, Sendable {
    var accountScopeID: String
    var workspaceID: String?
    var rescueDay: Date

    var storageKey: String {
        let dayStamp = Int(Calendar.current.startOfDay(for: rescueDay).timeIntervalSince1970)
        return "overdueRescue.session.v1.\(accountScopeID).\(workspaceID ?? "default").\(dayStamp)"
    }
}
