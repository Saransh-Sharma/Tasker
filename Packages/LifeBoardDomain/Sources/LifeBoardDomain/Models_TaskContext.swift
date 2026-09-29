//
//  TaskContext.swift
//  LifeBoard
//
//  Task context for location/situation-based organization
//

import Foundation

/// Context where tasks can be performed
public enum TaskContext: String, CaseIterable, Codable, Sendable {
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
        case .anywhere: return String(localized: "Anywhere")
        case .home: return String(localized: "At home")
        case .office: return String(localized: "At the office")
        case .computer: return String(localized: "At a computer")
        case .phone: return String(localized: "Calls")
        case .errands: return String(localized: "Errands")
        case .outdoor: return String(localized: "Outdoors")
        case .gym: return String(localized: "At the gym")
        case .commute: return String(localized: "Commuting")
        case .meeting: return String(localized: "In a meeting")
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
        case .anywhere: return String(localized: "No location needed")
        case .home: return String(localized: "Needs you at home")
        case .office: return String(localized: "Needs you at the office")
        case .computer: return String(localized: "Needs a computer")
        case .phone: return String(localized: "Calls and messages")
        case .errands: return String(localized: "While you’re out")
        case .outdoor: return String(localized: "Outside")
        case .gym: return String(localized: "Workouts and training")
        case .commute: return String(localized: "While traveling")
        case .meeting: return String(localized: "With other people")
        }
    }
}
