//
//  TaskPriorityConfig.swift
//  Tasker
//
//  Centralized configuration for task priorities and scoring
//

import Foundation

/// Global configuration for task priorities and scoring system
public struct TaskPriorityConfig {

    // MARK: - Priority Definitions

    /// Available priority levels
    public enum Priority: Int32, CaseIterable, Hashable, Codable {
        case none = 1   // No priority
        case low = 2    // Low priority
        case high = 3   // High priority
        case max = 4    // Maximum priority

        /// Human-readable display name
        public var displayName: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .high: return "High"
            case .max: return "Max"
            }
        }

        /// Short code for UI
        public var code: String {
            switch self {
            case .none: return "P0"
            case .low: return "P1"
            case .high: return "P2"
            case .max: return "P3"
            }
        }

        /// Score points awarded for completing a task with this priority
        public var scorePoints: Int {
            return TaskPriorityConfig.scoreForPriority(self)
        }

        /// Hex color string for UI representation ("Four Jewels" — maximally distinct)
        public var colorHex: String {
            switch self {
            case .none: return "#B09080"  // Antique Bronze
            case .low: return "#38C8A8"   // Jade Teal
            case .high: return "#7C68D8"  // Imperial Violet
            case .max: return "#E05058"   // Scarlet Garnet
            }
        }

        /// Weight for pie chart visualization (higher = larger slice)
        public var chartWeight: Double {
            switch self {
            case .none: return 1.0
            case .low: return 1.5
            case .high: return 2.5
            case .max: return 3.5
            }
        }

        /// Initialize from Core Data raw value with default fallback
        public init(rawValue: Int32) {
            switch rawValue {
            case 1: self = .none
            case 2: self = .low
            case 3: self = .high
            case 4: self = .max
            default:
                self = .none // Default fallback
            }
        }
    }
    
    // MARK: - Scoring Configuration
    
    /// Score points for each priority level
    /// Centralized configuration - modify these values to adjust scoring system
    private static let scoringTable: [Priority: Int] = [
        .none: 2,   // None priority: 2 points
        .low: 3,    // Low priority: 3 points
        .high: 5,   // High priority: 5 points
        .max: 7     // Max priority: 7 points
    ]
    
    /// Get score points for a given priority
    public static func scoreForPriority(_ priority: Priority) -> Int {
        return scoringTable[priority] ?? 2 // Default to 2 if not found
    }
    
    /// Get score points from raw Int32 value
    public static func scoreForRawValue(_ rawValue: Int32) -> Int {
        let priority = Priority(rawValue: rawValue)
        return scoreForPriority(priority)
    }
    
    // MARK: - Validation
    
    /// Check if a raw value is valid
    public static func isValidPriority(_ rawValue: Int32) -> Bool {
        return rawValue >= 1 && rawValue <= 4
    }
    
    /// Normalize an invalid priority to a valid one
    public static func normalizePriority(_ rawValue: Int32) -> Int32 {
        if isValidPriority(rawValue) {
            return rawValue
        }
        return Priority.none.rawValue
    }
    
    // MARK: - Pie Chart Configuration

    /// Get chart color hex string for priority raw value (platform-agnostic)
    public static func chartColorHexForPriority(_ rawValue: Int32) -> String {
        let priority = Priority(rawValue: rawValue)
        return priority.colorHex
    }

    /// Get chart weight for priority raw value (for weighted visualization)
    public static func chartWeightForPriority(_ rawValue: Int32) -> Double {
        let priority = Priority(rawValue: rawValue)
        return priority.chartWeight
    }
}

// MARK: - Legacy Compatibility
// Note: TaskPriority typealias is defined in TaskPriority.swift to avoid redeclaration
