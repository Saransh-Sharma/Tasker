//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct RecurrenceInstanceSnapshot: Codable, Equatable, Sendable {
    let recurrenceSeriesID: UUID?
    let repeatPattern: TaskRepeatPattern?
    let dueDate: Date?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
}
