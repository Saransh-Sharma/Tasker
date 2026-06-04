//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSessionState: Codable, Equatable, Sendable {
    var runID: UUID
    var accountScopeID: String
    var workspaceID: String?
    var referenceDate: Date
    var deckState: OverdueRescueDeckState
    var eligibleTaskIDs: [UUID]
    var remainingTaskIDs: [UUID]
    var resolvedTaskIDs: [UUID]
    var currentIndex: Int
    var keptCount: Int
    var movedCount: Int
    var deletedCount: Int
    var editedCount: Int
    var bulkAppliedCount: Int
    var largeStackAcknowledged: Bool
    var undoStack: [OverdueRescueUndoRecord]
    var lastRecoverableState: OverdueRescueDeckState
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    var summary: OverdueRescueSummary {
        OverdueRescueSummary(kept: keptCount, moved: movedCount, edited: editedCount, deleted: deletedCount)
    }
}
