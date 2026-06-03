//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueDeckState: String, Codable, Equatable, Sendable {
    case notStarted
    case loading
    case active
    case editing
    case confirmingDelete
    case paused
    case applyingBulk
    case completed
    case error
}
