//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitOverlayState {
    var isProcessing = false
    var statusMessage: String?
    var statusChips: [EvaDayStatusChip]?
    var actions: [EvaDayHabitAction]?
    var resolvedTodayState: HabitDayState?
}
