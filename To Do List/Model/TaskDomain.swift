//
//  TaskDomain.swift
//  To Do List
//
//  Extracted domain enums for tasks.
//

import Foundation

/// Defines the type of task in the system
/// Used to categorize tasks into morning, evening, or upcoming
enum TaskType: Int32, CaseIterable {
    case morning = 1
    case evening = 2
    case upcoming = 3
    
    var description: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        case .upcoming: return "Upcoming"
        }
    }
}

/// Defines the priority level of a task
/// Higher values indicate higher priority
enum TaskPriority: Int32, CaseIterable {
    case low = 1          // P0 – Highest priority
    case medium = 2       // P1
    case high = 3         // P2
    case veryLow = 4      // P3 – Lowest priority
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryLow: return "Very Low"
        }
    }
    
    var scoreValue: Int {
        // Provide a basic score value (higher priority ⇒ higher score)
        switch self {
        case .high:      return 3
        case .medium:    return 2
        case .low:       return 1
        case .veryLow:   return 0
        }
    }
}
