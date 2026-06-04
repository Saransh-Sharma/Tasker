//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueEditDraft: Equatable {
    var dueDate: Date?
    var duration: TimeInterval?
    var projectID: UUID
    var priority: TaskPriority

    init(card: OverdueRescueCardModel) {
        dueDate = card.task.dueDate
        duration = card.task.estimatedDuration
        projectID = card.task.projectID
        priority = card.task.priority
    }
}
