//
//  TaskContext.swift
//  Tasker
//
//  Task context for location/situation-based organization
//

import Foundation

/// Context where tasks can be performed
public enum TaskContext: String, CaseIterable, Codable {
    case anywhere = "anywhere"
    case home = "home"
    case office = "office"
    case computer = "computer"
    case phone = "phone"
    case errands = "errands"
    case outdoor = "outdoor"
    case gym = "gym"
    case commute = "commute"
    case meeting = "meeting"
    
    public var displayName: String {
        switch self {
        case .anywhere: return "Anywhere"
        case .home: return "At Home"
        case .office: return "At Office"
        case .computer: return "At Computer"
        case .phone: return "Phone Calls"
        case .errands: return "Running Errands"
        case .outdoor: return "Outdoors"
        case .gym: return "At Gym"
        case .commute: return "While Commuting"
        case .meeting: return "In Meeting"
        }
    }
    
    public var emoji: String {
        switch self {
        case .anywhere: return "🌍"
        case .home: return "🏠"
        case .office: return "🏢"
        case .computer: return "💻"
        case .phone: return "📞"
        case .errands: return "🏃‍♂️"
        case .outdoor: return "🌳"
        case .gym: return "🏋️‍♂️"
        case .commute: return "🚗"
        case .meeting: return "👥"
        }
    }
    
    public var description: String {
        switch self {
        case .anywhere: return "Can be done from any location"
        case .home: return "Requires being at home"
        case .office: return "Requires being at the office"
        case .computer: return "Requires access to a computer"
        case .phone: return "Phone call or communication task"
        case .errands: return "Tasks to do while out and about"
        case .outdoor: return "Outdoor activity or task"
        case .gym: return "Fitness or gym-related task"
        case .commute: return "Tasks that can be done while traveling"
        case .meeting: return "Discussion or collaboration task"
        }
    }
}