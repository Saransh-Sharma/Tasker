//
//  TaskPriority.swift
//  Tasker
//
//  Domain enum for Task Priority
//  UPDATED: Now uses centralized TaskPriorityConfig
//

import Foundation

/// Represents the priority level of a task
/// This is now a type alias to TaskPriorityConfig.Priority for centralized configuration
public typealias TaskPriority = TaskPriorityConfig.Priority

// MARK: - Legacy Compatibility Extensions

extension TaskPriority {
    /// Canonical UI ordering for segmented controls and chips.
    public static var uiOrder: [TaskPriority] {
        return [.none, .low, .high, .max]
    }

    /// Resolve a priority from a selected segment index using canonical ordering.
    public static func fromSegmentIndex(_ index: Int, order: [TaskPriority] = TaskPriority.uiOrder) -> TaskPriority {
        guard order.indices.contains(index) else {
            return .low
        }
        return order[index]
    }

    /// Resolve segment index for this priority using canonical ordering.
    public func segmentIndex(order: [TaskPriority] = TaskPriority.uiOrder) -> Int {
        if let index = order.firstIndex(of: self) {
            return index
        }
        return order.firstIndex(of: .low) ?? 0
    }

    /// Legacy property - use displayName instead
    @available(*, deprecated, message: "Use displayName instead")
    public var scoreValue: Int {
        return self.scorePoints
    }
    
    /// Check if this is a high priority (High or Max)
    public var isHighPriority: Bool {
        return self == .high || self == .max
    }
    
    /// Check if this is a medium priority (Low)
    public var isMediumPriority: Bool {
        return self == .low
    }
    
    /// Check if this is a low priority (None)
    public var isLowPriority: Bool {
        return self == .none
    }
}
