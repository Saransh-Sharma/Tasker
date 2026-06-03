//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

enum EvaWorkingStatusLibrary {
    static let general = [
        "Reviewing your context...",
        "Looking at what matters...",
        "Pulling the key signals...",
        "Organizing the big picture...",
        "Working through the details...",
        "Sorting the important pieces...",
        "Checking the strongest path...",
        "Building a clear answer...",
        "Turning this into a plan...",
        "Pulling this into focus...",
        "Structuring the next steps...",
        "Tightening the recommendation...",
        "Comparing the options...",
        "Simplifying the decision...",
        "Getting this into shape...",
        "Finding the clearest path...",
        "Breaking this down carefully...",
        "Preparing a focused response...",
        "Lining up the next steps...",
        "Refining the plan..."
    ]

    static let dailyPlanning = [
        "Reviewing your tasks...",
        "Checking today's priorities...",
        "Finding the highest-leverage task...",
        "Looking for what matters most today...",
        "Sorting urgent from important...",
        "Narrowing today's focus...",
        "Building today's plan...",
        "Pulling out your top priorities...",
        "Checking where momentum is strongest...",
        "Looking for the best next move...",
        "Trimming the list down...",
        "Turning today into a clear plan...",
        "Looking for quick wins...",
        "Balancing urgency and impact...",
        "Picking what deserves focus first...",
        "Reducing the noise...",
        "Aligning today's priorities...",
        "Building a realistic plan for today...",
        "Deciding what can wait...",
        "Protecting your focus window..."
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
