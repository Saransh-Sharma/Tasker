//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueStateMachine {
    static func canTransition(from current: OverdueRescueDeckState, to next: OverdueRescueDeckState) -> Bool {
        if next == .error {
            return current != .completed
        }
        switch (current, next) {
        case (.notStarted, .loading),
             (.loading, .active),
             (.loading, .completed),
             (.loading, .error),
             (.active, .editing),
             (.editing, .active),
             (.active, .confirmingDelete),
             (.confirmingDelete, .active),
             (.active, .paused),
             (.editing, .paused),
             (.confirmingDelete, .paused),
             (.paused, .active),
             (.active, .applyingBulk),
             (.applyingBulk, .active),
             (.active, .completed),
             (.editing, .completed),
             (.confirmingDelete, .completed),
             (.paused, .completed),
             (.applyingBulk, .completed),
             (.completed, .loading),
             (.completed, .active),
             (.error, .active),
             (.error, .editing),
             (.error, .confirmingDelete),
             (.error, .paused),
             (.error, .applyingBulk):
            return true
        default:
            return current == next
        }
    }

    static func isRecoverable(_ state: OverdueRescueDeckState) -> Bool {
        switch state {
        case .active, .editing, .confirmingDelete, .paused, .applyingBulk:
            return true
        case .notStarted, .loading, .completed, .error:
            return false
        }
    }
}
