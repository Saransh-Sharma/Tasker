//
//  TaskPriority.swift
//  Tasker
//
//  Domain enum for Task Priority
//

import Foundation

/// Represents the priority level of a task
public enum TaskPriority: Int32, CaseIterable {
    case highest = 1  // P0
    case high = 2     // P1
    case medium = 3   // P2 (default)
    case low = 4      // P3
    
    /// Human-readable name for the priority
    public var displayName: String {
        switch self {
        case .highest:
            return "P0 - Highest"
        case .high:
            return "P1 - High"
        case .medium:
            return "P2 - Medium"
        case .low:
            return "P3 - Low"
        }
    }
    
    /// Short priority code
    public var code: String {
        switch self {
        case .highest:
            return "P0"
        case .high:
            return "P1"
        case .medium:
            return "P2"
        case .low:
            return "P3"
        }
    }
    
    /// Score value for gamification
    public var scoreValue: Int {
        switch self {
        case .highest:
            return 7
        case .high:
            return 4
        case .medium:
            return 3
        case .low:
            return 2
        }
    }
    
    /// Initialize from Core Data raw value with default fallback
    public init(rawValue: Int32) {
        switch rawValue {
        case 1:
            self = .highest
        case 2:
            self = .high
        case 3:
            self = .medium
        case 4:
            self = .low
        default:
            self = .medium // Default fallback
        }
    }
    
    /// Check if this is a high priority (P0 or P1)
    public var isHighPriority: Bool {
        return self == .highest || self == .high
    }
    
    /// Check if this is a medium priority
    public var isMediumPriority: Bool {
        return self == .medium
    }
    
    /// Check if this is a low priority
    public var isLowPriority: Bool {
        return self == .low
    }
}
