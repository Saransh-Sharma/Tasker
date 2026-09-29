//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

/// Plain, phased lines shown while Eva works. They rotate so a long wait
/// never looks frozen; `slowTurnNotice` joins them once a turn runs long.
enum EvaWorkingStatusLibrary {
    static let general = [
        String(localized: "Thinking…"),
        String(localized: "Writing…")
    ]

    static let dailyPlanning = [
        String(localized: "Reading your tasks…"),
        String(localized: "Drafting a plan…")
    ]

    /// Seconds each line stays up.
    static let rotationInterval: TimeInterval = 2.5

    /// After this long, the slow-turn line is added under the status.
    static let slowTurnThreshold: TimeInterval = 6

    static let slowTurnNotice = String(localized: "Still working…")

    static func statuses(for recentUserFragments: [String]) -> [String] {
        let combined = recentUserFragments.joined(separator: " ").lowercased()
        let planningSignals = [
            "/today",
            "today",
            "task",
            "priority",
            "priorities",
            "focus",
            "plan",
            "urgent",
            "important",
            "what should i focus"
        ]
        if planningSignals.contains(where: { combined.contains($0) }) {
            return dailyPlanning
        }
        return general
    }

    /// The line to show `elapsed` seconds into a turn. Steps through the
    /// phases once and then holds on the last one, rather than looping back
    /// to the first line as if the turn had started over.
    static func status(in statuses: [String], elapsed: TimeInterval) -> String {
        let source = statuses.isEmpty ? general : statuses
        let step = max(0, Int(elapsed / rotationInterval))
        return source[min(step, source.count - 1)]
    }
}
