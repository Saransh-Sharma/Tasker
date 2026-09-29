//
//  TaskEnergy.swift
//  LifeBoard
//
//  Task energy requirement levels
//

import Foundation

/// Energy levels required for tasks
public enum TaskEnergy: String, CaseIterable, Codable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        switch self {
        case .low: return String(localized: "Low energy")
        case .medium: return String(localized: "Medium energy")
        case .high: return String(localized: "High energy")
        }
    }
    
    public var description: String {
        switch self {
        case .low: return String(localized: "For when you’re tired")
        case .medium: return String(localized: "Normal focus")
        case .high: return String(localized: "Full focus")
        }
    }
    
    public var emoji: String {
        switch self {
        case .low: return "😴"
        case .medium: return "😐"
        case .high: return "⚡"
        }
    }
    
    public var scoreMultiplier: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 1.2
        case .high: return 1.5
        }
    }
}
