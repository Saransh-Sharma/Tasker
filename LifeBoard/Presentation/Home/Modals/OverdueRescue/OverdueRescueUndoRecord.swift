//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueUndoRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let runID: UUID?
    let taskID: UUID
    let source: OverdueRescueDecisionSource
    let action: OverdueRescueDecisionAction
    let previousDueDate: Date?
    let previousProjectID: UUID?
    let previousDurationMinutes: Int?
    let previousPriority: TaskPriority?
    let previousCompletionState: Bool
    let previousDeletedState: Bool
    let previousRecurrenceState: RecurrenceInstanceSnapshot?
    let fullSnapshot: AssistantTaskSnapshot
    let createdAt: Date

    init(
        taskSnapshot: TaskDefinition,
        source: OverdueRescueDecisionSource,
        action: OverdueRescueDecisionAction,
        runID: UUID?
    ) {
        self.id = UUID()
        self.runID = runID
        self.taskID = taskSnapshot.id
        self.source = source
        self.action = action
        self.previousDueDate = taskSnapshot.dueDate
        self.previousProjectID = taskSnapshot.projectID
        self.previousDurationMinutes = taskSnapshot.estimatedDuration.map { Int(($0 / 60).rounded()) }
        self.previousPriority = taskSnapshot.priority
        self.previousCompletionState = taskSnapshot.isComplete
        self.previousDeletedState = false
        self.previousRecurrenceState = RecurrenceInstanceSnapshot(
            recurrenceSeriesID: taskSnapshot.recurrenceSeriesID,
            repeatPattern: taskSnapshot.repeatPattern,
            dueDate: taskSnapshot.dueDate,
            scheduledStartAt: taskSnapshot.scheduledStartAt,
            scheduledEndAt: taskSnapshot.scheduledEndAt
        )
        self.fullSnapshot = AssistantTaskSnapshot(task: taskSnapshot)
        self.createdAt = Date()
    }

    var taskSnapshot: TaskDefinition {
        fullSnapshot.toTaskDefinition()
    }
}
