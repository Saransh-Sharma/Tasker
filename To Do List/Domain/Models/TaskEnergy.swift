//
//  TaskEnergy.swift
//  Tasker
//
//  Task energy requirement levels
//

import Foundation

/// Energy levels required for tasks
public enum TaskEnergy: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        switch self {
        case .low: return "Low Energy"
        case .medium: return "Medium Energy"
        case .high: return "High Energy"
        }
    }
    
    public var description: String {
        switch self {
        case .low: return "Simple tasks that can be done when tired"
        case .medium: return "Tasks requiring normal focus and energy"
        case .high: return "Complex tasks requiring full focus and energy"
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