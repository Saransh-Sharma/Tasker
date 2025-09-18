//
//  TaskType.swift
//  Tasker
//
//  Domain enum for Task Type
//

import Foundation

/// Represents the type/category of a task
public enum TaskType: Int32, CaseIterable {
    case morning = 1
    case evening = 2
    case upcoming = 3
    case inbox = 4
    
    /// Human-readable name for the task type
    public var displayName: String {
        switch self {
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        case .upcoming:
            return "Upcoming"
        case .inbox:
            return "Inbox"
        }
    }
    
    /// Short code for the task type
    public var code: String {
        switch self {
        case .morning:
            return "M"
        case .evening:
            return "E"
        case .upcoming:
            return "U"
        case .inbox:
            return "I"
        }
    }
    
    /// Initialize from Core Data raw value with default fallback
    public init(rawValue: Int32) {
        switch rawValue {
        case 1:
            self = .morning
        case 2:
            self = .evening
        case 3:
            self = .upcoming
        case 4:
            self = .inbox
        default:
            self = .morning // Default fallback
        }
    }
}
