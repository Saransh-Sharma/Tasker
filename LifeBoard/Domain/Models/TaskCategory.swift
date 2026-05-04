//
//  TaskCategory.swift
//  LifeBoard
//
//  Task category for better organization
//

import Foundation

/// Task categories for better organization and filtering
public enum TaskCategory: String, CaseIterable, Codable, Sendable {
    case general = "general"
    case work = "work"
    case personal = "personal"
    case health = "health"
    case learning = "learning"
    case creative = "creative"
    case social = "social"
    case maintenance = "maintenance"
    case shopping = "shopping"
    case finance = "finance"
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .work: return "Work"
        case .personal: return "Personal"
        case .health: return "Health & Fitness"
        case .learning: return "Learning"
        case .creative: return "Creative"
        case .social: return "Social"
        case .maintenance: return "Maintenance"
        case .shopping: return "Shopping"
        case .finance: return "Finance"
        }
    }
    
    public var emoji: String {
        switch self {
        case .general: return "📝"
        case .work: return "💼"
        case .personal: return "👤"
        case .health: return "🏃‍♂️"
        case .learning: return "📚"
        case .creative: return "🎨"
        case .social: return "👥"
        case .maintenance: return "🔧"
        case .shopping: return "🛒"
        case .finance: return "💰"
        }
    }
}
