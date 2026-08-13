//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

enum EvaWorkingStatusLibrary {
    static let general = [
        "Drafting a response..."
    ]

    static let dailyPlanning = [
        "Reviewing today's permitted planning context..."
    ]

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
}
